class Ruby_process
  #Calls a static method on the process-side.
  #===Examples
  # rp.static(:File, :open, "/tmp/somefile", "w") do |fp|
  #   fp.write("Test")
  # end
  def static(classname, method, *args, &block)
    debug "Args-before: #{args} (#{@my_pid})\n" if @debug
    real_args = parse_args(args)
    debug "Real-args: #{real_args}\n" if @debug
    
    return send(:cmd => :static, :classname => classname, :method => method, :args => real_args, &block)
  end
  
  #Process-method for the 'static'-method.
  def cmd_static(obj)
    if obj.key?(:block)
      real_block = proc{|*args|
        debug "Block called! #{args}\n" if @debug
        send(:cmd => :block_call, :block_id => obj[:block][:id], :answer_id => obj[:send_id], :args => handle_return_args(args))
      }
      
      block = block_with_arity(:arity => obj[:block][:arity], &real_block)
    else
      block = nil
    end
    
    debug "Static-args-before: #{obj[:args]}\n" if @debug
    real_args = read_args(obj[:args])
    debug "Static-args-after: #{real_args}\n" if @debug
    
    const = obj[:classname].to_s.split("::").inject(Object, :const_get)
    retobj = const.__send__(obj[:method], *real_args, &block)
    return handle_return_object(retobj)
  end
end