require "socket"
require "tempfile"

# An ssh port forward from 127.0.0.1:<local port> on this machine to
# 127.0.0.1:5432 on the production host, where the database accessory's port
# is bound, so bin/nightly-load writes the production database through it.
# open runs the block once the local port accepts a connection and terminates
# ssh when the block finishes, whatever the outcome. ssh runs in batch mode,
# so a missing key or an unknown host key fails instead of prompting, and
# exits when it cannot bind the local port. A local port that already accepts
# connections before ssh starts belongs to another program, so the forward is
# not opened at all: the block would otherwise talk to that program.
module ProductionTunnel
  REMOTE_PORT = 5432
  # How long to wait between tries of the local port while ssh starts.
  POLL_SECONDS = 0.1

  # The forward could not be opened; the message says why, with what ssh
  # printed.
  class Error < StandardError; end

  # The default spawner: starts argv with standard error written to the file
  # at `err` and returns its pid.
  SPAWNER = ->(argv, err:) { Process.spawn(*argv, in: File::NULL, out: File::NULL, err:) }

  def self.argv(host:, user:, local_port:)
    [ "ssh", "-o", "BatchMode=yes", "-o", "ExitOnForwardFailure=yes", "-o", "ServerAliveInterval=30",
      "-N", "-L", "127.0.0.1:#{local_port}:127.0.0.1:#{REMOTE_PORT}", "#{user}@#{host}" ]
  end

  # Returns what the block returns.
  def self.open(host:, user:, local_port:, spawner: SPAWNER, timeout: 20)
    raise Error, "127.0.0.1:#{local_port} 已經有別的程式在聽，用 TUNNEL_PORT 換一個埠" if accepting?(local_port)

    Tempfile.create("production-tunnel") do |stderr|
      pid = spawner.call(argv(host:, user:, local_port:), err: stderr.path)
      begin
        wait_until_accepting(pid, local_port, stderr.path, timeout)
        yield
      ensure
        stop(pid)
      end
    end
  end

  def self.wait_until_accepting(pid, local_port, stderr_path, timeout)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until accepting?(local_port)
      _, status = Process.wait2(pid, Process::WNOHANG)
      raise Error, "ssh 在轉送開好之前就結束了（#{status}）：#{File.read(stderr_path).strip}" if status
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        raise Error, "等了 #{timeout} 秒，127.0.0.1:#{local_port} 還是連不上：#{File.read(stderr_path).strip}"
      end

      sleep POLL_SECONDS
    end
  end

  def self.accepting?(port)
    Socket.tcp("127.0.0.1", port, connect_timeout: 1, &:close)
    true
  rescue SystemCallError, IO::TimeoutError
    false
  end

  # Terminates ssh unless it has already exited, and reaps it. A pid reaped
  # while waiting for the port is never signalled, since it may belong to
  # another process by now.
  def self.stop(pid)
    return if Process.wait2(pid, Process::WNOHANG)

    Process.kill("TERM", pid)
    Process.wait(pid)
  rescue Errno::ECHILD
    nil
  end
  private_class_method :wait_until_accepting, :accepting?, :stop
end
