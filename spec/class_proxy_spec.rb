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

  it "should be able to do multiple calls at once" do
    ts = []

    0.upto(9) do |tcount|
      ts << Thread.new do
        RubyProcess::ClassProxy.run do |data|
          sp = data[:subproc]
          sp.new(:String, "Wee")

          1.upto(250) do
            str = sp.new(:String, "Kasper Johansen")

            str.__rp_marshal.should include "Kasper"
            str << " More"

            str.__rp_marshal.should include "Johansen"
            str << " Even more"

            str.__rp_marshal.should_not include "Christina"
            str << " Much more"
          end
        end
      end
    end

    count = 0
    ts.each do |t|
      count += 1
      #puts "Thread #{count}"
      t.join
    end
  end

  it "should not leak" do
    str = "kasper"
    str = nil
    sleep 0.1
    GC.start
    sleep 0.1

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
