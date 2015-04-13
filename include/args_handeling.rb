class RubyProcess
  #Recursivly parses arrays and hashes into proxy-object-hashes.
  def parse_args(args)
    if args.is_a?(Array)
      newarr = []
      args.each do |val|
        newarr << parse_args(val)
      end

      return newarr
    elsif args.is_a?(Hash)
      newh = {}
      args.each do |key, val|
        newh[parse_args(key)] = parse_args(val)
      end

      return newh
    elsif @args_allowed.index(args.class) != nil
      debug "Allowing type '#{args.class}' as an argument: '#{args}'.\n" if @debug
      return args
    else
      debug "Not allowing type '#{args.class}' as an argument - proxy object will be used.\n" if @debug
      return handle_return_object(args)
    end
  end

private

  #Returns a special hash instead of an actual object. Some objects will be returned in their normal form (true, false and nil).
  def handle_return_object(obj, pid = @my_pid)
    #Dont proxy these objects.
    return obj if obj.is_a?(TrueClass) || obj.is_a?(FalseClass) || obj.is_a?(NilClass)

    #The object is a proxy-obj - just return its arguments that contains the true 'my_pid'.
    if obj.is_a?(RubyProcess::ProxyObject)
      debug "Returning from proxy-obj: (ID: #{obj.args.fetch(:id)}, PID: #{obj.__rp_pid}).\n" if @debug
      return {type: :proxy_obj, id: obj.__rp_id, pid: obj.__rp_pid}
    end

    #Check if object has already been spawned. If not: spawn id. Then returns hash for it.
    id = obj.__id__
    @objects[id] = obj unless @objects.key?(id)

    debug "Proxy-object spawned (ID: #{id}, PID: #{pid}).\n" if @debug
    return {type: :proxy_obj, id: id, pid: pid}
  end

  #Parses an argument array to proxy-object-hashes.
  def handle_return_args(arr)
    newa = []
    arr.each do |obj|
      newa << handle_return_object(obj)
    end

    return newa
  end

  #Recursivly scans arrays and hashes for proxy-object-hashes and replaces them with actual proxy-objects.
  def read_args(args)
    if args.is_a?(Array)
      newarr = []
      args.each do |val|
        newarr << read_args(val)
      end

      return newarr
    elsif args.is_a?(Hash) && args.length == 3 && args[:type] == :proxy_obj && args.key?(:id) && args.key?(:pid)
      debug "Comparing PID (#{args[:pid]}, #{@my_pid}).\n" if @debug

      if args[:pid] == @my_pid
        debug "Same!\n" if @debug
        return proxyobj_object(args[:id])
      else
        debug "Not same!\n" if @debug
        return proxyobj_get(args[:id], args[:pid])
      end
    elsif args.is_a?(Hash)
      newh = {}
      args.each do |key, val|
        newh[read_args(key)] = read_args(val)
      end

      return newh
    end

    return args
  end
end
