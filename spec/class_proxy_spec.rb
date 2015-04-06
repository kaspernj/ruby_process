require "spec_helper"

describe "RubyProcess" do
  it "should be able to do quick in-and-outs without leaking" do
    ts = []

    1.upto(2) do |tcount|
      ts << Thread.new do
        1.upto(10) do
          RubyProcess::ClassProxy.run do
            str = RubyProcess::ClassProxy.subproc.new(:String, "Wee")
            str.__rp_marshal.should eq "Wee"
          end
        end
      end
    end

    ts.each do |thread|
      thread.join
    end
  end

  it "should be able to do basic stuff" do
    require "stringio"

    RubyProcess::ClassProxy.run do
      RubyProcess::ClassProxy.subproc.static(:Object, :require, "rubygems")
      RubyProcess::ClassProxy.subproc.static(:Object, :require, "rexml/document")

      doc = RubyProcess::ClassProxy::REXML::Document.new
      doc.add_element("test")

      strio = StringIO.new
      doc.write(strio)

      Kernel.const_defined?(:REXML).should eq false
      strio.string.should eq "<test/>"
    end
  end

  it "prepares for leak test by spawning a ton of string objects" do
    str = nil

    1000.times do
      str = "#{Digest::MD5.hexdigest(Time.now.to_f.to_s)}".clone
      str = nil
    end

    sleep 0.1
    GC.enable
    GC.start
    sleep 0.1
  end

  it "has cleaned up and process objects" do
    sleep 0.1
    GC.enable
    GC.start
    sleep 0.1

    count_processes = 0
    ObjectSpace.each_object(RubyProcess) do |obj|
      puts "Found RubyProcess: (destroyed: #{obj.destroyed?})"
      count_processes += 1
    end

    count_processes.should eq 0

    count_proxy_objs = 0
    ObjectSpace.each_object(RubyProcess::ProxyObject) do |obj|
      count_proxy_objs += 1
    end

    count_proxy_objs.should eq 0

    RubyProcess::ClassProxy.constants.empty?.should eq true
  end
end
