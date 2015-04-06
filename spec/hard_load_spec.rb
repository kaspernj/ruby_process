require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "RubyProcess" do
  it "should be able to do basic stuff" do
    RubyProcess::ClassProxy.run do |data|
      sp = data[:subproc]
      sp.new(:String, "Wee")

      ts = []

      1.upto(50) do |tcount|
        ts << Thread.new do
          1.upto(250) do
            str = sp.new(:String, "Kasper Johansen")

            str.__rp_marshal.should eq "Kasper Johansen"
            str << " More"

            str.__rp_marshal.should include "Johansen"
            str << " Even more"

            str.__rp_marshal.should_not include "Christina"
            str << " Much more"

            str.__rp_marshal.should eq "Kasper Johansen More Even more Much more"
          end
        end
      end

      ts.each do |t|
        t.join
      end
    end
  end
end
