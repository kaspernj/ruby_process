require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "RubyProcess" do
  it "should be able to do quick in-and-outs without leaking" do
    ts = []
    
    1.upto(2) do |tcount|
      ts << Thread.new do
        1.upto(10) do
          Ruby_process::Cproxy.run do |data|
            sp = data[:subproc]
            str = sp.new(:String, "Wee")
            res1 = str.include?("Kasper")
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
    
    Ruby_process::Cproxy.run do |data|
      data[:subproc].static(:Object, :require, "rubygems")
      data[:subproc].static(:Object, :require, "rexml/document")
      
      doc = Ruby_process::Cproxy::REXML::Document.new
      doc.add_element("test")
      
      strio = StringIO.new
      doc.write(strio)
      
      raise "Didnt expect REXML to be defined in host process." if Kernel.const_defined?(:REXML)
      raise "Expected strio to contain '<test/>' but it didnt: '#{strio.string}'." if strio.string != "<test/>"
    end
  end
  
  it "should be able to do multiple calls at once" do
    ts = []
    
    0.upto(9) do |tcount|
      ts << Thread.new do
        Ruby_process::Cproxy.run do |data|
          sp = data[:subproc]
          sp.new(:String, "Wee")
          
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
            
            #print tcount
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
    ObjectSpace.each_object(Ruby_process) do |obj|
      count_objs += 1
    end
    
    count_proxy_objs = 0
    ObjectSpace.each_object(Ruby_process::Proxyobj) do |obj|
      count_proxy_objs += 1
    end
    
    raise "Expected 1 or less 'Ruby_process' to be left but it wasnt like that: #{count_objs} (proxy objects: #{count_proxy_objs})" if count_objs > 1
    raise "Expected 0 constants to be left on cproxy." if !Ruby_process::Cproxy.constants.empty?
  end
end
