class Ruby_process
  #Calls a static method on the process-side.
  #===Examples
  # rp.static(:File, :open, "/tmp/somefile", "w") do |fp|
  #   fp.write("Test")
  # end
  def static(classname, method, *args, &block)
    return send(:cmd => :static, :classname => classname, :method => method, :args => args, &block)
  end
  
  #Process-method for the 'static'-method.
  def cmd_static(obj)
    if obj.key?(:block)
      real_block = proc{|*args|
        $stderr.print "Block called! #{args}\n" if @debug
        send(:cmd => :block_call, :block_id => obj[:block][:id], :args => handle_return_args(args))
      }
      
      block = block_with_arity(:arity => obj[:block][:arity], &real_block)
    else
      block = nil
    end
    
    const = obj[:classname].to_s.split("::").inject(Object, :const_get)
    retobj = const.__send__(obj[:method], *obj[:args], &block)
    return handle_return_object(retobj)
  end
end