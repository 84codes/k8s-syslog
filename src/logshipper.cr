require "socket"

lib LibC
  fun setsid : PidT
  fun setpgid(pid : PidT, pgid : PidT) : LibC::Int
end

module Logshipper
  VERSION = "0.1.0"

  class Syslog
    def initialize(host, port : Int32, @hostname = System.hostname, @component = "app")
      @socket = UDPSocket.new
      @socket.connect host, port
    end

    def log(message, severity = :info)
      facility_nr = 17 # local1
      severity_nr = SEVERITES[severity]
      pri = facility_nr * 8 + severity_nr
      line = String.build do |io|
        io << "<" << pri << ">1 "
        Time.utc.to_rfc3339(io)
        io << " " << @hostname << " " << @component
        io << " " << "- - -" << message
      end
      @socket.send line
    end

    SEVERITES = {emergency: 0, alert: 1, critical: 2, error: 3, warning: 4, notice: 5, info: 6, debug: 7}
  end
end

# ret = LibC.setsid
# raise RuntimeError.from_errno("setsid") if ret < 0
# ret = LibC.setpgid(0, 0)
# raise RuntimeError.from_errno("setpgid") if ret < 0
syslog = Logshipper::Syslog.new ENV.fetch("SYSLOG_HOST"), ENV.fetch("SYSLOG_PORT").to_i
sr, sw = IO.pipe
er, ew = IO.pipe
p = Process.new(ARGV.shift, ARGV, output: sw, error: ew)
Signal::TERM.trap do
  Process.signal(Signal::TERM, 0) # send to all process in the process group
  spawn do
    sleep 25
    Process.signal(Signal::KILL, 0) # send to all process in the process group
  end
  exit p.wait.exit_code
end
spawn do
  while message = sr.gets
    STDOUT.puts message
    next if message.empty?
    syslog.log(message, :info)
  end
rescue IO::Error
end
spawn do
  while message = er.gets
    STDERR.puts message
    next if message.empty?
    syslog.log(message, :error)
  end
rescue IO::Error
end
exit p.wait.exit_code
