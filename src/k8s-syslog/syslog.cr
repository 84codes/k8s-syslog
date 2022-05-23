require "socket"

module K8sSyslog
  class Syslog
    def initialize(@io : IO)
    end

    def self.line(hostname, component, message, ts = Time.utc, severity = :info)
      facility_nr = 17 # local1
      severity_nr = SEVERITES[severity]
      pri = facility_nr * 8 + severity_nr
      line = String.build do |io|
        io << "<" << pri << ">1 "
        ts.to_rfc3339(io)
        io << " " << hostname << " " << component
        io << " - - - " << message << "\n"
      end
    end

    def print(line)
      @io.print line
    end

    SEVERITES = {emergency: 0, alert: 1, critical: 2, error: 3, warning: 4, notice: 5, info: 6, debug: 7}
  end

  class UDPSyslog < Syslog
    def initialize(host, port : Int32)
      io = UDPSocket.new
      io.connect host, port
      io.sync = true
      super(io)
    end
  end

  class TLSSyslog < Syslog
    def initialize(host, port : Int32)
      tcp = TCPSocket.new(host, port)
      tcp.tcp_keepalive_idle = 20
      tcp.tcp_keepalive_count = 2
      tcp.tcp_keepalive_interval = 5
      tls = OpenSSL::SSL::Socket::Client.new(tcp, sync_close: true, hostname: host)
      tls.sync = true
      tls.write_timeout = 30
      super(tls)
    end
  end
end
