#This class handels the calling of methods on objects in the other process seamlessly.
class Ruby_process::Proxyobj
  #Hash that contains various information about the proxyobj.
  attr_reader :args
  
  #Constructor. This should not be called manually but through a running 'Ruby_process'.
  #===Examples
  # proxy_obj = rp.new(:String, "Kasper") #=> <Ruby_process::Proxyobj>
  # proxy_obj = rp.static(:File, :open, "/tmp/somefile") #=> <Ruby_process::Proxyobj>
  def initialize(args)
    @args = args
  end
  
  #Returns the object as the real object transfered by using the marshal-lib.
  #===Examples
  # str = rp.new(:String, "Kasper") #=> <Ruby_process::Proxyobj>
  # str.__rp_marshal #=> "Kasper"
  def __rp_marshal
    return Marshal.load(@args[:rp].send(:cmd => :obj_marshal, :id => @args[:id]))
  end
  
  #Unsets all data on the object.
  def __rp_destroy
    @args = nil
  end
  
  #Overwrite certain convert methods.
  RUBY_METHODS = [:to_i, :to_s, :to_str, :to_f]
  RUBY_METHODS.each do |method_name|
    define_method(method_name) do |*args, &blk|
      return @args[:rp].send(:cmd => :obj_method, :id => @args[:id], :method => method_name, :args => args, &blk).__rp_marshal
    end
  end
  
  #Overwrite certain methods.
  PROXY_METHODS = [:send]
  PROXY_METHODS.each do |method_name|
    define_method(method_name) do |*args, &blk|
      self.method_missing(method_name, *args, &blk)
    end
  end
  
  #Proxies all calls to the process-object.
  #===Examples
  # str = rp.new(:String, "Kasper") #=> <Ruby_process::Proxyobj::1>
  # length_int = str.length #=> <Ruby_process::Proxyobj::2>
  # length_int.__rp_marshal #=> 6
  def method_missing(method, *args, &block)
    debug "Method-missing-args-before: #{args} (#{@my_pid})\n" if @debug
    real_args = @args[:rp].parse_args(args)
    debug "Method-missing-args-after: #{real_args}\n" if @debug
    
    return @args[:rp].send(:cmd => :obj_method, :id => @args[:id], :method => method, :args => real_args, &block)
  end
end