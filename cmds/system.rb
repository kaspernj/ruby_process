class Ruby_process
  #Closes the process by executing exit.
  def cmd_exit(obj)
    exit
  end
  
  #Flushes various collected object-IDs to the subprocess, where they will be garbage-collected.
  def flush_finalized
    @flush_mutex.synchronize do
      $stderr.print "Ruby-process-debug: Checking finalized\n" if @debug
      ids = @proxy_objs_unsets.shift(500)
      $stderr.print "IDS: #{ids} #{@proxy_objs_unsets}\n" if @debug
      return nil if ids.empty?
      
      $stderr.print "Ruby-process-debug: Finalizing (#{ids}).\n" if @debug
      send(:cmd => :flush_finalized, :ids => ids)
      @finalize_count += ids.length
      return nil
    end
  end
  
  #Flushes references to the given object IDs.
  def cmd_flush_finalized(obj)
    $stderr.print "Command-flushing finalized: '#{obj[:ids]}'.\n" if @debug
    obj[:ids].each do |id|
      raise "Unknown ID: '#{id}' (#{id.class.name})." if !@objects.key?(id)
      @objects.delete(id)
    end
    
    return nil
  end
end