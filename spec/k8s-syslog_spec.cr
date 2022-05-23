require "./spec_helper"
require "../src/k8s-syslog/syslog"

describe K8sSyslog::Syslog do
  it "produces a line" do
    line = K8sSyslog::Syslog.line "hostname", "component", "message", Time.unix(0)
    line.should eq "<142>1 1970-01-01T00:00:00Z hostname component - - - message\n"
  end

  it "prints as is to io" do
    io = IO::Memory.new
    syslog = K8sSyslog::Syslog.new(io)
    syslog.print "hello world"
    io.to_s.should eq "hello world"
  end
end
