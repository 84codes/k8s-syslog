require "socket"

module K8sSyslog
  # Implements https://datatracker.ietf.org/doc/html/rfc5424
  class Syslog
    def initialize(@io : IO)
    end

    def self.line(pod, container, message, ts = Time.utc, severity = :info) : String
      facility_nr = 17 # local1
      severity_nr = SEVERITES[severity]
      pri = facility_nr * 8 + severity_nr
      podname = pod.lchop("#{container}-")
      capacity = 37 + container.bytesize + podname.bytesize + message.bytesize
      String.build(capacity) do |io|
        io << "<" << pri << ">1 "
        ts.to_rfc3339(io)
        io << " " << container << " " << podname
        io << " - - - " << message << "\n"
      end
    end

    def print(line : String) : Nil
      @io.print line
    end

    SEVERITES = {emergency: 0, alert: 1, critical: 2, error: 3, warning: 4, notice: 5, info: 6, debug: 7}

    class UDP < Syslog
      def initialize(host, port : Int32)
        io = UDPSocket.new
        io.connect host, port
        io.sync = true
        super(io)
      end
    end

    class TLS < Syslog
      def initialize(host, port : Int32)
        tcp = TCPSocket.new(host, port, connect_timeout: 60)
        tcp.tcp_keepalive_idle = 20
        tcp.tcp_keepalive_count = 2
        tcp.tcp_keepalive_interval = 5
        tls = OpenSSL::SSL::Socket::Client.new(tcp, sync_close: true, hostname: host)
        tls.write_timeout = 30
        tls.sync = true
        super(tls)
      end
    end
  end
end
