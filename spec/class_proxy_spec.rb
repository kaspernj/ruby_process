require "spec_helper"

describe "RubyProcess" do
  it "should be able to do quick in-and-outs without leaking" do
    ts = []

    1.upto(2) do |tcount|
      ts << Thread.new do
        1.upto(10) do
          RubyProcess::ClassProxy.run do |data|
            sp = data[:subproc]
            str = sp.new(:String, "Wee")
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

    RubyProcess::ClassProxy.run do |data|
      data[:subproc].static(:Object, :require, "rubygems")
      data[:subproc].static(:Object, :require, "rexml/document")

      doc = RubyProcess::ClassProxy::REXML::Document.new
      doc.add_element("test")

      strio = StringIO.new
      doc.write(strio)

      Kernel.const_defined?(:REXML).should eq false
      strio.string.should eq "<test/>"
    end
  end

  it "should not leak" do
    str = "kasper"
    str = nil
    sleep 0.2
    GC.enable
    GC.start
    sleep 0.2

    count_objs = 0
    ObjectSpace.each_object(RubyProcess) do |obj|
      count_objs += 1
    end

    count_proxy_objs = 0
    ObjectSpace.each_object(RubyProcess::ProxyObject) do |obj|
      count_proxy_objs += 1
    end

    count_objs.should be <= 1
    RubyProcess::ClassProxy.constants.empty?.should eq true
  end
end
