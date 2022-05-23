require "./k8s"
require "./syslog"

module K8sSyslog
  class Shipper
    @ch = Channel(String).new(1024)

    def initialize(syslog_address)
      @syslog_uri = URI.parse syslog_address
      Signal::INT.trap { @ch.closed? ? exit(1) : @ch.close }
      Signal::TERM.trap { @ch.closed? ? exit(1) : @ch.close }
    end

    def run
      spawn watch_pods
      loop do
        syslog_loop
      rescue ex : Channel::ClosedError
        exit 1  # closed by INT/TERM
      rescue ex # retry on all other errors
        STDERR.puts "ERROR syslog: #{ex.message}"
        sleep 1
      end
    end

    private def syslog_loop
      syslog = open_syslog_connection
      loop do
        line = @ch.receive
        begin
          syslog.print(line)
        rescue ex
          @ch.send(line) rescue nil # try requeue
          raise ex
        end
      end
    end

    private def open_syslog_connection
      case @syslog_uri.scheme
      when "udp"
        Syslog::UDP.new @syslog_uri.host || "localhost", @syslog_uri.port || 514
      when "tcp+tls", "tls"
        Syslog::TLS.new @syslog_uri.host || "localhost", @syslog_uri.port || 514
      when "file"
        Syslog.new(File.new(@syslog_uri.path, "w").tap(&.sync = true))
      else abort "Invalid syslog address: #{@syslog_uri}"
      end
    end

    private def watch_pods
      pods = Pods.new
      pods.each do |pod|
        spawn stream_logs(pod)
      end
    rescue ex
      STDERR.puts "ERROR while watching pods", ex.inspect_with_backtrace
    ensure
      @ch.close # should not happen so empty buffer and exit
    end

    private def stream_logs(pod)
      pod.logs do |message|
        @ch.send(Syslog.line(pod.pod, pod.container, message))
      end
    rescue Channel::ClosedError
      # closed by TERM/INT
    end
  end
end
