require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "RubyProcess" do
  it "should be able to clean up after itself when timeout" do
    require "timeout"
    
    Ruby_process::Cproxy.run do |data|
      sp = data[:subproc]
      
      begin
        Timeout.timeout(1) do
          sp.static(:Object, :sleep, 2)
        end
        
        raise "Expected timeout to be raised."
      rescue Timeout::Error
        #ignore.
      end
      
      answers = sp.instance_variable_get(:@answers)
      raise "'answers'-variable should be empty but wasnt: '#{answers}'." if !answers.empty?
    end
  end
end