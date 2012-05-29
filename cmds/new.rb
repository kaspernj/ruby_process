class Ruby_process
  #Spawns a new object in the process and returns a proxy-object for it.
  def new(classname, *args, &block)
    return send(:cmd => :new, :classname => classname, :args => args, &block)
  end
  
  #This command spawns a new object of a given class and returns its hash-handle, so a proxy-object can be spawned on the other side.
  def cmd_new(obj)
    const = obj[:classname].to_s.split("::").inject(Object, :const_get)
    retobj = const.new(*obj[:args])
    return handle_return_object(retobj)
  end
  
  def cmd_obj_method(obj)
    myobj = @objects[obj[:id]]
    raise "Object by that ID does not exist: '#{obj[:id]}'." if !myobj
    
    if obj.key?(:block)
      real_block = proc{|*args|
        $stderr.print "Block called! #{args}\n" if @debug
        send(:cmd => :block_call, :block_id => obj[:block][:id], :args => handle_return_args(args))
      }
      
      block = block_with_arity(:arity => obj[:block][:arity], &real_block)
      $stderr.print "Spawned fake block with arity: #{block.arity}\n"
    else
      block = nil
    end
    
    $stderr.print "Calling #{myobj.class.name}.#{obj[:method]}(*#{obj[:args]}, &#{block})\n" if @debug
    res = myobj.__send__(obj[:method], *obj[:args], &block)
    return handle_return_object(res)
  end
end