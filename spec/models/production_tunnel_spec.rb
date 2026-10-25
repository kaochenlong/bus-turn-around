require "rails_helper"

RSpec.describe ProductionTunnel, type: :model do
  let(:spawned) { [] }
  let(:port) { TCPServer.open("127.0.0.1", 0) { it.addr[1] } }

  # Stand-ins for ssh, run with Ruby with the local port of the forward as
  # their argument: one listens on it the way the forward does, one fails the
  # way ssh fails without the key, and one neither listens nor exits.
  def listens = 'server = TCPServer.new("127.0.0.1", Integer(ARGV[0])); loop { server.accept.close }'
  def refused = 'warn "root@203.0.113.5: Permission denied (publickey)."; exit 255'
  def hangs = "sleep 30"

  # A spawner that runs `script` in place of ssh and records the argv it was
  # given and the pid.
  def fake_ssh(script)
    lambda do |argv, err:|
      local_port = argv[argv.index("-L") + 1].split(":")[1]
      Process.spawn(RbConfig.ruby, "-rsocket", "-e", script, local_port, err:).tap { spawned << [ argv, it ] }
    end
  end

  # Opens the forward with `script` as ssh; returns what the block returned,
  # or the message of the error.
  def attempt(script, local_port: port, timeout: 20, &block)
    block ||= -> { :ran }
    described_class.open(host: "203.0.113.5", user: "root", local_port:, spawner: fake_ssh(script), timeout:, &block)
  rescue described_class::Error => e
    e.message
  end

  def alive?(pid)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
  end

  # Raises inside the block; returns whether ssh is still running afterwards.
  def alive_after_failing_block
    attempt(listens) { raise "載入失敗" }
  rescue RuntimeError
    alive?(spawned.sole.last)
  end

  it "轉送的參數：BatchMode、ExitOnForwardFailure、不開遠端指令，把本機 127.0.0.1:15432 轉到主機的 127.0.0.1:5432" do
    attempt(listens, local_port: 15432)
    expect(spawned.map(&:first)).to eq([ %w[ssh -o BatchMode=yes -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -N -L 127.0.0.1:15432:127.0.0.1:5432 root@203.0.113.5] ])
  end

  it "本機埠接受連線之後才執行區塊、回傳區塊的值，結束後 ssh 已經不在" do
    result = attempt(listens) { Socket.tcp("127.0.0.1", port) { :connected } }
    expect([ result, alive?(spawned.sole.last) ]).to eq([ :connected, false ])
  end

  it "區塊丟出錯誤時也關掉 ssh" do
    expect(alive_after_failing_block).to be(false)
  end

  it "ssh 在埠開好之前就結束：丟出帶 ssh 的 stderr 的錯誤，區塊沒執行" do
    expect(attempt(refused)).to include("Permission denied (publickey).")
  end

  it "等太久本機埠還是連不上：丟出錯誤、說等了幾秒，ssh 已經不在" do
    message = attempt(hangs, timeout: 0.5)
    expect([ message, alive?(spawned.sole.last) ]).to match([ a_string_including("0.5 秒"), false ])
  end

  it "本機埠已經有別的程式在聽：不起 ssh，錯誤點名那個埠與 TUNNEL_PORT" do
    message = TCPServer.open("127.0.0.1", port) { attempt(listens) }
    expect([ message, spawned ]).to match([ a_string_including("127.0.0.1:#{port}", "TUNNEL_PORT"), [] ])
  end
end
