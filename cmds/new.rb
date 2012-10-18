class Ruby_process
  #Spawns a new object in the process and returns a proxy-object for it.
  def new(classname, *args, &block)
    return send(:cmd => :new, :classname => classname, :args => parse_args(args), &block)
  end
  
  #This command spawns a new object of a given class and returns its hash-handle, so a proxy-object can be spawned on the other side.
  def cmd_new(obj)
    const = obj[:classname].to_s.split("::").inject(Object, :const_get)
    
    debug "New-args-before: #{obj[:args]}\n" if @debug
    real_args = read_args(obj[:args])
    debug "New-args-after: #{real_args}\n" if @debug
    
    retobj = const.new(*real_args)
    return handle_return_object(retobj)
  end
  
  #Calls a method on an object.
  def cmd_obj_method(obj)
    myobj = @objects[obj[:id]]
    raise "Object by that ID does not exist: '#{obj[:id]}' '(#{@objects.keys.sort.join(",")})." if !myobj
    
    if obj.key?(:block)
      real_block = proc{|*args|
        debug "Block called! #{args}\n" if @debug
        send(:cmd => :block_call, :block_id => obj[:block][:id], :answer_id => obj[:send_id], :args => handle_return_args(args))
      }
      
      block = block_with_arity(:arity => obj[:block][:arity], &real_block)
      debug "Spawned fake block with arity: #{block.arity}\n" if @debug
    else
      block = nil
    end
    
    debug "Obj-method-args-before: #{obj[:args]}\n" if @debug
    real_args = read_args(obj[:args])
    debug "Obj-methods-args-after: #{real_args}\n" if @debug
    
    debug "Calling #{myobj.class.name}.#{obj[:method]}(*#{obj[:args]}, &#{block})\n" if @debug
    res = myobj.__send__(obj[:method], *real_args, &block)
    return handle_return_object(res)
  end
end