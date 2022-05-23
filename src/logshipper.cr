require "socket"
require "http/client"
require "json"
require "./logshipper/syslog"
require "./logshipper/k8s"

module Logshipper
  VERSION = "0.1.0"

  class Shipper
    @ch = Channel(String).new(1024 * 1024)

    def run
      Signal::INT.trap { @ch.closed? ? exit(1) : @ch.close }
      Signal::TERM.trap { @ch.closed? ? exit(1) : @ch.close }

      spawn watch_pods
      loop do
        send_syslogs
      rescue ex : Channel::ClosedError
        exit 1
      rescue ex : KeyError
        puts ex.message
        exit 1
      rescue ex # retry
        STDERR.puts ex.inspect
        sleep 1
      end
    end

    def send_syslogs
      syslog = TLSSyslog.new ENV.fetch("SYSLOG_HOST"), ENV.fetch("SYSLOG_PORT").to_i
      # syslog = Syslog.new(STDOUT)
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

    def watch_pods
      pods = Pods.new
      pods.each do |pod|
        spawn stream_logs(pod)
      end
      @ch.close # should not happen so empty buffer and exit
    end

    def stream_logs(pod)
      pod.logs do |message|
        @ch.send(Syslog.line(pod.name, :app, message))
      end
    rescue Channel::ClosedError
    end
  end
end

Logshipper::Shipper.new.run
