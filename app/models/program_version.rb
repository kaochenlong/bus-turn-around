require "open3"

# The short commit of the running program, as a printed card names it, so that a
# number can be traced to the code that computed it. Kamal sets KAMAL_VERSION in
# the container; elsewhere it comes from the checkout. Read once: it cannot change
# while the program runs.
module ProgramVersion
  LENGTH = 7
  UNKNOWN = "unknown".freeze

  def self.current = @current ||= read(ENV.to_h)

  def self.read(env) = env["KAMAL_VERSION"]&.first(LENGTH) || checkout_head

  def self.checkout_head
    stdout, status = Open3.capture2("git", "rev-parse", "--short=#{LENGTH}", "HEAD", chdir: Rails.root.to_s, err: File::NULL)
    status.success? ? stdout.strip : UNKNOWN
  rescue Errno::ENOENT
    UNKNOWN
  end
  private_class_method :checkout_head
end
