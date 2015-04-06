class RubyProcess
  #Closes the process by executing exit.
  def cmd_exit(obj)
    exit
  end

  #Flushes various collected object-IDs to the subprocess, where they will be garbage-collected.
  def flush_finalized
    @flush_mutex.synchronize do
      debug "Ruby-process-debug: Checking finalized\n" if @debug
      ids = @proxy_objs_unsets.shift(500)
      debug "IDS: #{ids} #{@proxy_objs_unsets}\n" if @debug
      return nil if ids.empty?

      debug "Ruby-process-debug: Finalizing (#{ids}).\n" if @debug
      send(cmd: :flush_finalized, ids: ids)
      @finalize_count += ids.length
      return nil
    end
  end

  #Flushes references to the given object IDs.
  def cmd_flush_finalized(obj)
    debug "Command-flushing finalized: '#{obj[:ids]}'.\n" if @debug
    obj[:ids].each do |id|
      raise "Unknown ID: '#{id}' (#{id.class.name})." unless @objects.key?(id)
      @objects.delete(id)
    end

    return nil
  end

  #Starts garbage-collecting and then flushes the finalized objects to the sub-process. Does the same thing in the sub-process.
  def garbage_collect
    GC.start
    self.flush_finalized
    send(cmd: :garbage_collect)
    return nil
  end

  #The sub-process-side execution of 'garbage_collect'.
  def cmd_garbage_collect(obj)
    GC.start
    self.flush_finalized
    return nil
  end
end
