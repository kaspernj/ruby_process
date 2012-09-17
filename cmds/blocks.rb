class Ruby_process
  #Calls a block by its block-ID with given arguments.
  def cmd_block_call(obj)
    raise "Invalid block-ID: '#{obj}'." if obj[:block_id].to_i <= 0
    block_ele = @objects[obj[:block_id]]
    raise "No block by that ID: '#{obj[:block_id]}'." if !block_ele
    raise "Not a block? '#{block_ele.class.name}'." if !block_ele.respond_to?(:call)
    debug "Calling block #{obj[:block_id]}: #{obj}\n" if @debug
    block_ele.call(*read_args(obj[:args]))
    return nil
  end
  
  #Spawns a block and returns its ID.
  def cmd_spawn_proxy_block(obj)
    block = proc{
      send(:cmd => :block_call, :block_id => obj[:id])
    }
    
    id = block.__id__
    raise "ID already exists: '#{id}'." if @objects.key?(id)
    @objects[id] = block
    
    return {:id => id}
  end
  
  #Dynamically creates a block with a certain arity. If sub-methods measure arity, they will get the correct one from the other process.
  def block_with_arity(args, &block)
    eval_str = "proc{"
    eval_argsarr = "\t\tblock.call("
    
    if args[:arity] > 0
      eval_str << "|"
      1.upto(args[:arity]) do |i|
        if i > 1
          eval_str << ","
          eval_argsarr << ","
        end
        
        eval_str << "arg#{i}"
        eval_argsarr << "arg#{i}"
      end
      
      eval_str << "|\n"
      eval_argsarr << ")\n"
    end
    
    eval_full = eval_str + eval_argsarr
    eval_full << "}"
    
    debug "Block eval: #{eval_full}\n" if @debug
    dynamic_proc = eval(eval_full)
    
    return dynamic_proc
  end
end