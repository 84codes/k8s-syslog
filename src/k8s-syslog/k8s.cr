require "http/client"
require "json"

module K8sSyslog
  abstract class K8s
    def initialize
      if File.exists? "/var/run/secrets/kubernetes.io/serviceaccount/token"
        token = File.read("/var/run/secrets/kubernetes.io/serviceaccount/token")
        @namespace = File.read("/var/run/secrets/kubernetes.io/serviceaccount/namespace")
        ctx = OpenSSL::SSL::Context::Client.new
        ctx.ca_certificates = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
        @client = HTTP::Client.new "kubernetes.default.svc", tls: ctx
        @client.before_request do |request|
          request.headers["Authorization"] = "Bearer #{token}"
        end
      else # kubectl proxy
        @client = HTTP::Client.new "127.0.0.1", 8001
        @namespace = "default"
      end
    end
  end

  class Pods < K8s
    def each(&)
      loop do
        @client.get("/api/v1/namespaces/#{@namespace}/pods?watch&fieldSelector=status.phase=Running") do |resp|
          raise Exception.new if resp.status_code != 200

          while json = resp.body_io.gets
            data = JSON.parse(json)
            type = data["type"].as_s
            name = data.dig("object", "metadata", "name").as_s
            namespace = data.dig("object", "metadata", "namespace").as_s
            puts "pod=#{name} type=#{type}"
            # next unless name.starts_with? "neg-"
            case type
            when "ADDED"
              yield Pod.new(name, namespace)
            when "MODIFIED"
            when "DELETED"
            end
          end
        end
      rescue ex : IO::EOFError
        # ignore, just retry
      rescue ex
        STDERR.puts "ERROR while watching pods", ex.inspect_with_backtrace
      end
    end
  end

  class Pod < K8s
    def initialize(@name : String, @namespace : String)
      super()
    end

    getter name, namespace

    def logs(&)
      @client.get("/api/v1/namespaces/#{@namespace}/pods/#{@name}/log?follow&tailLines=0") do |response|
        case response.status_code
        when 200
          while message = response.body_io.gets
            yield message unless message.empty?
          end
        else
          puts "pod=#{@name} broken-stream #{JSON.parse(response.body_io)}"
        end
      end
    end
  end
end
