require "http/client"
require "json"

module K8sSyslog
  abstract class K8s
    # TLS contexts are memory heavy so reuse between all clients
    TLS_CTX = OpenSSL::SSL::Context::Client.new.tap do |ctx|
      if File.exists? "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
        ctx.ca_certificates = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
      end
    end

    # https://kubernetes.io/docs/tasks/run-application/access-api-from-pod/
    def initialize
      if File.exists? "/var/run/secrets/kubernetes.io/serviceaccount/token"
        token = File.read("/var/run/secrets/kubernetes.io/serviceaccount/token")
        @client = HTTP::Client.new "kubernetes.default.svc", tls: TLS_CTX
        @client.before_request do |request|
          request.headers["Authorization"] = "Bearer #{token}"
        end
      else # kubectl proxy
        @client = HTTP::Client.new "127.0.0.1", 8001
      end
    end
  end

  class Pods < K8s
    # https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.19/#list-all-namespaces-pod-v1-core
    def each(&)
      @client.get("/api/v1/pods?watch&fieldSelector=status.phase=Running") do |resp|
        raise Error.new(resp.body_io.gets_to_end) if resp.status_code != 200

        while json = resp.body_io.gets
          data = JSON.parse(json)
          type = data["type"].as_s
          pod_name = data.dig("object", "metadata", "name").as_s
          namespace = data.dig("object", "metadata", "namespace").as_s
          case type
          when "ADDED"
            containers = data.dig("object", "spec", "containers").as_a
            containers.each do |c|
              container_name = c["name"].as_s
              yield Pod.new(container_name, pod_name, namespace)
            end
          when "MODIFIED"
          when "DELETED"
          end
        end
      end
    end
  end

  class Pod < K8s
    def initialize(@container : String, @pod : String, @namespace : String)
      super()
    end

    getter container, pod, namespace

    # https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.19/#read-log-pod-v1-core
    def follow_logs(&)
      @client.get("/api/v1/namespaces/#{@namespace}/pods/#{@pod}/log?follow&tailLines=0&container=#{@container}") do |response|
        case response.status_code
        when 200
          puts "follow_logs started pod=#{@pod} container=#{@container}"
          while message = response.body_io.gets
            yield message unless message.empty?
          end
        else
          puts "[ERROR] follow_logs pod=#{@pod} container=#{@container} error=#{response.body_io.gets_to_end}"
        end
      end
    ensure
      puts "follow_logs stopped pod=#{@pod} container=#{@container}"
    end
  end

  class Error < Exception; end
end
