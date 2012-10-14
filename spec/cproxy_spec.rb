require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "RubyProcess" do
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
end
