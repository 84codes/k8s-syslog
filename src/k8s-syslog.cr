require "./k8s-syslog/shipper"

module K8sSyslog
  VERSION = "0.1.0"
end

uri = ENV["SYSLOG_ADDRESS"]? || abort "Missing SYSLOG_ADDRESS environment variable"
K8sSyslog::Shipper.new(uri).run
