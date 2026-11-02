# What bin/nightly-load and bin/monthly-cards share on the way to the production
# database: one lock, so that neither runs while the other does, and the ssh port
# forward with the check that production has the migrations of this checkout, which
# may be an hour behind or ahead of the deployed image. One lock because a manual
# --recompute can run for half an hour: a card printed meanwhile would read route
# days being replaced, and both commands use the same local port anyway.
class ProductionSession
  PORT = /\A[1-9]\d{0,4}\z/
  MAX_PORT = 65_535

  # A reason to stop; the message is what to print.
  class Failure < StandardError; end

  # The port a text names, nil when it names none.
  def self.local_port(text) = (Integer(text) if PORT.match?(text.to_s) && Integer(text) <= MAX_PORT)

  attr_reader :lock_path

  # `action` is the verb of the command, for what it says it will not do.
  def initialize(action:, out:, tunnel: ProductionTunnel, lock_path: Rails.root.join("tmp/nightly-load.lock"),
                 checkout_versions: ActiveRecord::Base.connection_pool.migration_context.migrations.map(&:version),
                 deploy: DerivedPushCommand.deploy_config)
    @action = action
    @out = out
    @tunnel = tunnel
    @lock_path = lock_path.to_s
    @checkout_versions = checkout_versions
    @deploy = deploy
  end

  # Runs the block holding the lock, released when the file is closed; does nothing
  # and returns 0 when another run holds it.
  def with_lock
    FileUtils.mkdir_p(File.dirname(@lock_path))
    File.open(@lock_path, File::RDWR | File::CREAT, 0o644) do |lock|
      unless lock.flock(File::LOCK_EX | File::LOCK_NB)
        @out.puts("另一個 bin/nightly-load 或 bin/monthly-cards 還在跑，這次不做")
        return 0
      end

      yield
    end
  end

  # Runs the block inside the forward once the migration versions agree, and returns
  # what it returns.
  def open(local_port:)
    @tunnel.open(host: ssh_host, user: ssh_user, local_port:) do
      check_migration_versions
      yield
    end
  rescue ProductionTunnel::Error => e
    raise Failure, "開不了到正式站的轉送：#{e.message}"
  end

  private

  # Prints the target with whether the migration versions agree; stops when they do
  # not, because the command reads and writes the columns of this checkout.
  def check_migration_versions
    target = "正式站：#{ssh_user}@#{ssh_host} 的 #{ActiveRecord::Base.connection_db_config.database}"
    database = ActiveRecord::Base.connection_pool.migration_context.get_all_versions
    only_database, only_checkout = (database - @checkout_versions).sort, (@checkout_versions - database).sort
    return @out.puts("#{target}，migration 版本一致") if only_database.empty? && only_checkout.empty?

    lines = [ ("  只在正式站：#{only_database.join('、')}" if only_database.any?), ("  只在這份 checkout：#{only_checkout.join('、')}" if only_checkout.any?) ]
    raise Failure, [ "#{target}，migration 版本不一致，這次不#{@action}：", *lines.compact,
                     "正式站多的要等這份 checkout 跟上 origin/main，checkout 多的要等正式站 deploy；兩邊一樣才#{@action}。" ].join("\n")
  end

  def ssh_user = @deploy.dig("ssh", "user") || "root"

  def ssh_host
    @deploy.dig("accessories", "db", "host") or raise Failure, "config/deploy.yml 沒有 accessories 的 db.host"
  end
end
