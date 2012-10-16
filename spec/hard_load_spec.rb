require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "RubyProcess" do
  it "should be able to do basic stuff" do
    Ruby_process::Cproxy.run do |data|
      sp = data[:subproc]
      sp.new(:String, "Wee")
      
      ts = []
      
      1.upto(50) do |tcount|
        ts << Thread.new do
          1.upto(250) do
            str = sp.new(:String, "Kasper Johansen")
            
            res1 = str.include?("Kasper")
            str << " More"
            
            res2 = str.include?("Johansen")
            str << " Even more"
            
            res3 = str.include?("Christina")
            str << " Much more"
            
            raise "Expected res1 to be true but it wasnt: '#{res1}'." if res1 != true
            raise "Expected res2 to be true but it wasnt: '#{res2}'." if res2 != true
            raise "Expected res3 to be false but it wasnt: '#{res3}'." if res3 != false
            
            print "."
          end
        end
      end
      
      ts.each do |t|
        t.join
      end
    end
  end
end