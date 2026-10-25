require "erb"
require "open3"
require "shellwords"
require "yaml"

# bin/push-derived: replaces the derived tables of the production database with
# those of the database this runs on, the development database of the laptop.
# The production host has no raw files and no DuckDB, so the derived tables are
# computed here with bin/rails derived:load and pushed (docs/decisions.md, 12).
# The derived tables are route_days and every table that references it by
# foreign key, directly or through another of them, so a derived table added
# later is pushed without editing this file.
#
# Without --push it only prints what would be pushed. With --push it stops
# before touching production unless this database has route days, the dump's
# PostgreSQL major version is not newer than production's, both databases
# are at the same schema version, and production stores no route day this
# database lacks: bin/nightly-load writes route days straight into
# production, and replacing the tables would delete them (docs/decisions.md,
# 14). Then it dumps this database with the
# pg_dump of the development PostgreSQL container, saves a dump of the
# production tables on the host, replaces them in one transaction, and
# compares every table's row count and id sequence with this database.
# Production is reached over ssh as config/deploy.yml names it, inside the
# database accessory's container.
class DerivedPushCommand
  USAGE = <<~TEXT.freeze
    用法：bin/push-derived          印出要推上正式站的衍生表，不動正式站
          bin/push-derived --push   備份正式站的衍生表，換成這台的這一份，再比對列數
    開發資料庫的 PostgreSQL 容器預設叫 postgres，不是的話用 DEV_POSTGRES_CONTAINER 給。
  TEXT

  # A reason to stop; the message is what to print.
  class Failure < StandardError; end

  # The default runner: runs argv with the content of the file `input`, if
  # any, on standard input. With `output`, standard output is written to that
  # file and the text returned is standard error. Returns [succeeded, text].
  module Runner
    def self.call(argv, input: nil, output: nil)
      stdout, stderr, status = Open3.capture3(*argv, stdin_data: input ? File.binread(input) : "", binmode: true)
      File.binwrite(output, stdout) if output
      [ status.success?, output ? stderr : stdout + stderr ]
    end
  end

  # route_days first, then each table that references one already found, in
  # name order within each round.
  def self.derived_tables(connection = ActiveRecord::Base.connection)
    tables = [ "route_days" ]
    loop do
      added = (connection.tables - tables).select { |table| connection.foreign_keys(table).any? { tables.include?(it.to_table) } }
      return tables if added.empty?

      tables.concat(added.sort)
    end
  end

  def self.deploy_config(path = Rails.root.join("config/deploy.yml")) = YAML.safe_load(ERB.new(File.read(path)).result)

  def initialize(argv, out: $stdout, runner: Runner, deploy: self.class.deploy_config, dump_dir: Rails.root.join("tmp/derived-push"),
                 now: Time.current, env: ENV)
    @argv = argv
    @out = out
    @runner = runner
    @deploy = deploy
    @dump_dir = dump_dir.to_s
    @stamp = now.strftime("%Y%m%d-%H%M%S")
    @dev_container = env.fetch("DEV_POSTGRES_CONTAINER", "postgres")
  end

  # Returns the exit status: 0 when nothing was asked to be pushed or the push
  # was verified.
  def run
    push = parse
    print_plan
    return 0 unless push

    check
    replace
    verify
    0
  rescue Failure => e
    @out.puts(e.message)
    1
  end

  private

  def parse
    case @argv
    in [] then false
    in [ "--push" ] then true
    else raise Failure, USAGE
    end
  end

  def connection = ActiveRecord::Base.connection

  def tables = @tables ||= self.class.derived_tables(connection)

  def counts = @counts ||= tables.to_h { [ it, connection.select_value("SELECT count(*) FROM #{connection.quote_table_name(it)}") ] }

  def print_plan
    @out.puts("要推上正式站的衍生表：這台的 #{dev_config[:database]} → #{ssh_target} 上 #{container} 容器裡的 #{production_config[:database]}")
    tables.each { @out.puts("  #{it} #{counts.fetch(it)} 列") }
    @out.puts("路線與日子：")
    route_days.each { |route_id, first, last, days| @out.puts("  #{route_id}：#{first.iso8601} 到 #{last.iso8601}，#{days} 天") }
    @out.puts("沒有動正式站；上面就是正式站該有的內容時，再加 --push。") unless @argv.include?("--push")
  end

  def route_days = RouteDay.group(:route_id).order(:route_id).pluck(:route_id, Arel.sql("min(day)"), Arel.sql("max(day)"), Arel.sql("count(*)"))

  # Everything that would make the push wrong is checked before production is
  # touched. Production's route days are read in the same psql call as its
  # versions, one "<route Id>|<day>" line each.
  def check
    raise Failure, "這台沒有任何路線日，不推：正式站的衍生表會被清空" if counts.fetch("route_days").zero?

    dump_major = run!([ "docker", "exec", @dev_container, "pg_dump", "--version" ], "讀不到 #{@dev_container} 容器的 pg_dump 版本")[/(\d+)\.\d+/, 1].to_i
    server, schema, *production_route_days = run!(remote_psql("-c", "show server_version_num", "-c", "select max(version) from schema_migrations",
                                                              "-c", "select route_id, day from route_days"), "讀不到正式站的版本").split("\n")
    server_major = server.to_i / 10_000
    if dump_major > server_major
      raise Failure, "#{@dev_container} 容器的 pg_dump 是 #{dump_major}、正式站的 PostgreSQL 是 #{server_major}：新版匯出的檔舊版收不了，" \
                     "用 DEV_POSTGRES_CONTAINER 給一個 #{server_major} 版的容器"
    end
    unless schema.to_s.strip == dev_schema_version
      raise Failure, "正式站的 schema 版本是 #{schema.to_s.strip}、這台是 #{dev_schema_version}：先 deploy，或在這台跑 bin/rails db:migrate，兩邊一樣再推"
    end

    check_production_route_days(production_route_days)
  end

  # A route day only production stores was written there by bin/nightly-load;
  # replacing the tables would delete it, so the push stops. A line that is
  # not a route day stops it too, because a route day not read is one the
  # push would delete.
  def check_production_route_days(lines)
    production = lines.map do |line|
      match = /\A(\d+)\|(\d{4}-\d{2}-\d{2})\z/.match(line) or raise Failure, "讀不懂正式站 route_days 的這一行，不推：#{line}"

      [ Integer(match[1]), Date.iso8601(match[2]) ]
    end
    missing = production - RouteDay.pluck(:route_id, :day)
    return if missing.empty?

    per_route = missing.group_by(&:first).sort.map do |route_id, pairs|
      first, last = pairs.map(&:last).minmax
      "  #{route_id}：#{first.iso8601} 到 #{last.iso8601}，#{pairs.size} 天"
    end
    raise Failure, [ "正式站有這台沒有的路線日，不推：", *per_route,
                     "這些是 bin/nightly-load 每晚寫進正式站的路線日，整份推會把它們刪掉；要重算請在放原始檔的 Mac mini 上跑 bin/nightly-load --recompute。" ].join("\n")
  end

  def dev_schema_version = connection.select_value("SELECT max(version) FROM schema_migrations").to_s

  # The dump starts with the TRUNCATE, so the one transaction that loads it
  # first empties every derived table.
  def replace
    FileUtils.mkdir_p(@dump_dir)
    @out.puts("== 匯出這台的衍生表：#{dump_path}")
    run!([ "docker", "exec", @dev_container, "pg_dump", "-U", dev_config[:username], "-d", dev_config[:database], *dump_options ], "匯出失敗", output: dump_path)
    File.binwrite(dump_path, "#{truncate_sql}\n".b + File.binread(dump_path))
    @out.puts("== 備份正式站的衍生表：#{backup_path}")
    run!(remote("docker", "exec", container, "pg_dump", "-U", production_config[:username], "-d", production_config[:database], *dump_options,
                redirect: backup_path), "備份正式站失敗")
    @out.puts("== 在一個交易裡換掉正式站的衍生表")
    run!(remote(*restore_argv), "換掉正式站的衍生表失敗，交易已經退回，正式站照舊", input: dump_path)
  end

  def verify
    rows = run!(remote_psql("-F", " ", "-c", verify_sql), "讀不到正式站換完的列數").split("\n").to_h { it.split(" ").then { |table, count, sequence| [ table, [ count.to_i, sequence ] ] } }
    problems = tables.filter_map do |table|
      count, sequence = rows.fetch(table, [ nil, nil ])
      next "#{table}：正式站 #{count.inspect} 列、這台 #{counts.fetch(table)} 列" unless count == counts.fetch(table)

      "#{table}：id 序號落在最大的 id 之前" unless sequence == "t"
    end
    raise Failure, "正式站換完跟這台對不上：\n#{problems.map { "  #{it}" }.join("\n")}\n要退回就跑：#{rollback_command}" if problems.any?

    @out.puts("== 比對：#{tables.size} 張表的列數都跟這台相同，id 序號都不小於最大的 id")
    @out.puts("要退回就跑：#{rollback_command}")
  end

  def verify_sql
    tables.map { "select '#{it}', count(*), (select last_value from #{it}_id_seq) >= coalesce(max(id), 0) from #{it}" }.join(" union all ")
  end

  def run!(argv, failure, **options)
    succeeded, text = @runner.call(argv, **options)
    raise Failure, "#{failure}：#{text.strip}" unless succeeded

    text
  end

  def dump_options = [ "--data-only", "--disable-triggers", *tables.flat_map { [ "-t", it ] } ]

  def truncate_sql = "TRUNCATE #{tables.join(', ')};"

  def restore_argv = [ "docker", "exec", "-i", container, "psql", "-U", production_config[:username], "-d", production_config[:database],
                       "-v", "ON_ERROR_STOP=1", "--single-transaction", "-q" ]

  # The remote shell reads one command line; every argument is quoted for it.
  def remote(*argv, redirect: nil)
    command = Shellwords.join(argv)
    command += " > #{Shellwords.escape(redirect)}" if redirect
    [ "ssh", "-o", "BatchMode=yes", ssh_target, command ]
  end

  def remote_psql(*options) = remote("docker", "exec", container, "psql", "-U", production_config[:username], "-d", production_config[:database], "-At", *options)

  # For a person to paste: every part is a name from the configuration, so it is written without quoting.
  def rollback_command = "ssh #{ssh_target} \"( echo '#{truncate_sql}'; cat #{backup_path} ) | #{restore_argv.join(' ')}\""

  def dump_path = File.join(@dump_dir, "derived-#{@stamp}.sql")

  def backup_path = File.join(ssh_user == "root" ? "/root" : "/home/#{ssh_user}", "derived-before-#{@stamp}.sql")

  def ssh_user = @deploy.dig("ssh", "user") || "root"

  def ssh_target
    host = @deploy.dig("accessories", "db", "host") or raise Failure, "config/deploy.yml 沒有 accessories 的 db.host"

    "#{ssh_user}@#{host}"
  end

  # Kamal names an accessory's container after the service and the accessory.
  def container = "#{@deploy.fetch('service')}-db"

  def dev_config = connection.pool.db_config.configuration_hash

  def production_config = ActiveRecord::Base.configurations.configs_for(env_name: "production", name: "primary").configuration_hash
end
