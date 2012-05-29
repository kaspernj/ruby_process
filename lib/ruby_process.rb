require "rubygems"
require "base64"
require "wref"
require "tsafe"

#This class can communicate with another Ruby-process. It tries to integrate the work in the other process as seamless as possible by using proxy-objects.
class Ruby_process
  #Require all the different commands.
  dir = "#{File.dirname(__FILE__)}/../cmds"
  Dir.foreach(dir) do |file|
    require "#{dir}/#{file}" if file =~ /\.rb$/
  end
  
  #Constructor.
  #===Examples
  # Ruby_process.new.spawn_process do |rp|
  #   str = rp.new(:String, "Kasper")
  # end
  def initialize(args = {})
    @args = args
    @debug = @args[:debug]
    
    #These classes are allowed in call-arguments. They can be marshalled without any errors.
    @args_allowed = [FalseClass, Fixnum, Integer, NilClass, String, Symbol, TrueClass]
    
    #Set IO variables if given.
    @io_out = Tsafe::Proxy.new(:obj => @args[:out]) if @args[:out]
    @io_in = @args[:in] if @args[:in]
    @io_err = @args[:err] if @args[:err]
    
    #This hash holds answers coming from the subprocess.
    @answers = Tsafe::MonHash.new
    
    #This hash holds objects that are referenced in the process.
    @objects = Tsafe::MonHash.new
    
    #This weak-map holds all proxy objects.
    @proxy_objs = Wref_map.new
    @proxy_objs_ids = Tsafe::MonHash.new
    @proxy_objs_unsets = Tsafe::MonArray.new
    @flush_mutex = Mutex.new
    
    #Send ID is used to identify the correct answers.
    @send_mutex = Mutex.new
    @send_count = 0
  end
  
  #Spawns a new process in the same Ruby-inteterpeter as the current one.
  #===Examples
  # rp = Ruby_process.new.spawn_process
  # rp.str_eval("return 10").__rp_marshal #=> 10
  # rp.destroy
  def spawn_process(args = nil)
    if args and args[:exec]
      cmd = "#{args[:exec]}"
    else
      cmd = "ruby"
    end
    
    cmd << " \"#{File.dirname(__FILE__)}/../scripts/ruby_process_script.rb\""
    
    if @args[:debug]
      cmd << " --debug"
    end
    
    #Start process and set IO variables.
    @io_out, @io_in, @io_err = Open3.popen3(cmd)
    @io_out = Tsafe::Proxy.new(:obj => @io_out)
    @io_out.sync = true
    @io_in.sync = true
    @io_err.sync = true
    
    started = false
    @io_in.each_line do |str|
      if str == "ruby_process_started\n"
        started = true
        break
      end
      
      $stderr.print "Ruby-process-debug from stdout before started: #{str}" if @debug
    end
    
    raise "Ruby-sub-process couldnt start: '#{@io_err.read}'." if !started
    self.listen
    
    #Start by getting the PID of the process.
    begin
      @pid = self.static(:Process, :pid).__rp_marshal
      raise "Unexpected PID: '#{@pid}'." if !@pid.is_a?(Fixnum) and !@pid.is_a?(Integer)
    rescue => e
      self.destroy
      raise e
    end
    
    if block_given?
      begin
        yield(self)
      ensure
        self.destroy
      end
      
      return nil
    else
      return self
    end
  end
  
  #Starts listening on the given IO's. It is useally not needed to call this method manually.
  def listen
    #Start listening for input.
    start_listen
    
    #Start listening for errors.
    start_listen_errors
  end
  
  #First tries to make the sub-process exit gently. Then kills it with "TERM" and 9 afterwards to make sure its dead. If 'spawn_process' is given a block, this method is automatically ensured after the block is run.
  def destroy
    begin
      send(:cmd => :exit) if alive?
    rescue => e
      raise e if e.message != "Process is dead." and e.message != "Not listening."
    end
    
    #Kill it and make sure its dead...
    begin
      Process.kill("TERM", @pid)
      Process.kill(9, @pid)
    rescue Errno::ESRCH
      #Process is already dead - ignore.
    end
  end
  
  #Joins the listen thread and error-thread. This is useually only called on the sub-process side, but can also be useful, if you are waiting for a delayed callback from the subprocess.
  def join
    $stderr.print "Joining listen-thread.\n" if @debug
    @thr_listen.join if @thr_listen
    raise @listen_err if @listen_err
    
    $stderr.print "Joining error-thread.\n" if @debug
    @thr_err.join if @thr_join
    raise @listen_err_err if @listen_err_err
  end
  
  #Sends a command to the other process. This should not be called manually, but is used by various other parts of the framework.
  def send(obj, &block)
    raise "Ruby-process is dead." if !alive?
    
    #Parse block.
    if block
      block_proxy_res = self.send(:cmd => :spawn_proxy_block, :id => block.__id__)
      raise "No block ID was returned?" if !block_proxy_res[:id]
      raise "Invalid block-ID: '#{block_proxy_res[:id]}'." if block_proxy_res[:id].to_i <= 0
      @proxy_objs[block_proxy_res[:id]] = block
      @proxy_objs_ids[block.__id__] = block_proxy_res[:id]
      @objects[block_proxy_res[:id]] = block
      ObjectSpace.define_finalizer(block_proxy_res, self.method(:proxyobj_finalizer))
      obj[:block] = {
        :id => block_proxy_res[:id],
        :arity => block.arity
      }
    end
    
    flush_finalized if obj[:cmd] != :flush_finalized
    
    #Sync ID stuff so they dont get mixed up.
    id = nil
    @send_mutex.synchronize do
      id = @send_count
      @send_count += 1
    end
    
    $stderr.print "Ruby-process-debug: Sending(#{id}): #{obj}\n" if @debug
    line = Base64.strict_encode64(Marshal.dump(
      :id => id,
      :type => :send,
      :obj => obj
    ))
    @io_out.puts(line)
    sleep 0.001
    return answer_read(id)
  end
  
  private
  
  #Returns a special hash instead of an actual object. Some objects will be returned in their normal form (true, false and nil).
  def handle_return_object(obj)
    #Dont proxy these objects.
    if obj.is_a?(TrueClass) or obj.is_a?(FalseClass) or obj.is_a?(NilClass)
      return obj
    end
    
    id = obj.__id__
    if !@objects.key?(id)
      @objects[id] = obj
    end
    
    return {:type => :proxy_obj, :id => id}
  end
  
  #Parses an argument array to proxy-object-hashes.
  def handle_return_args(arr)
    newa = []
    arr.each do |obj|
      newa << handle_return_object(obj)
    end
    
    return newa
  end
  
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
      return args
    else
      return handle_return_object(args)
    end
  end
  
  #Recursivly scans arrays and hashes for proxy-object-hashes and replaces them with actual proxy-objects.
  def read_args(args)
    if args.is_a?(Array)
      newarr = []
      args.each do |val|
        newarr << read_args(val)
      end
      
      return newarr
    elsif args.is_a?(Hash) and args.length == 2 and args[:type] == :proxy_obj and args.key?(:id)
      return proxyobj_get(args[:id])
    elsif args.is_a?(Hash)
      newh = {}
      newh.each do |key, val|
        newh[read_args(key)] = read_args(val)
      end
      
      return newh
    end
    
    return args
  end
  
  #Returns true if the child process is still running. Otherwise false.
  def alive?
    return false if !@io_out or !@io_in or @io_in.closed?
    return true
  end
  
  #Raises an error if the subprocess is no longer alive.
  def alive_check!
    raise "Process is dead." unless alive?
    return nil
  end
  
  #Registers an object ID as a proxy-object on the host-side.
  def proxyobj_get(id)
    if proxy_obj = @proxy_objs.get!(id)
      return proxy_obj
    end
    
    @proxy_objs_unsets.delete(id)
    proxy_obj = Ruby_process::Proxyobj.new(:rp => self, :id => id)
    @proxy_objs[id] = proxy_obj
    @proxy_objs_ids[proxy_obj.__id__] = id
    ObjectSpace.define_finalizer(proxy_obj, self.method(:proxyobj_finalizer))
    
    return proxy_obj
  end
  
  #Method used for detecting garbage-collected proxy-objects. This way we can also free references to them in the other process, so it doesnt run out of memory.
  def proxyobj_finalizer(id)
    $stderr.print "Ruby-process-debug: Finalized #{id}\n" if @debug
    proxy_id = @proxy_objs_ids[id]
    
    if !proxy_id
      $stderr.print "No such ID in proxy objects IDs hash: '#{id}'.\n" if @debug
    else
      @proxy_objs_unsets << proxy_id
      $stderr.print "Done finalizing #{id}\n" if @debug
    end
    
    return nil
  end
  
  #Waits for an answer to appear in the answers-hash. Then deletes it from hash and returns it.
  def answer_read(id)
    $stderr.print "Ruby-process-debug: Waiting for answer #{id}\n" if @debug
    
    loop do
      if @answers.key?(id)
        $stderr.print "Ruby-process-debug: Returning answer #{id}\n" if @debug
        answer = @answers[id]
        @answers.delete(id)
        
        if answer.is_a?(Hash) and answer[:type] == :error and answer.key?(:class) and answer.key?(:msg) and answer.key?(:bt)
          begin
            raise "#{answer[:class]}: #{answer[:msg]}"
          rescue => e
            bt = []
            answer[:bt].each do |btline|
              bt << "Ruby-subprocess: #{btline}"
            end
            
            bt += e.backtrace
            e.set_backtrace(bt)
            raise e
          end
        elsif answer.is_a?(Hash) and answer[:type] == :proxy_obj and answer.key?(:id)
          return proxyobj_get(answer[:id])
        end
        
        return answer
      end
      
      $stderr.print "No answer by ID #{id} - sleeping...\n" if @debug
      sleep 0.01
      alive_check!
      raise @listen_err if @listen_err
      raise "Not listening." if !@thr_listen or !@thr_listen.alive?
    end
  end
  
  #Starts the listen-thread that listens for, and executes, commands.
  def start_listen
    @thr_listen = Thread.new do
      begin
        @io_in.each_line do |line|
          raise "No line?" if !line or line.to_s.strip.length <= 0
          alive_check!
          $stderr.print "Ruby-process-debug: Received: #{line}" if @debug
          
          begin
            obj = Marshal.load(Base64.strict_decode64(line.strip))
            $stderr.print "Ruby-process-debug: Object received: #{obj}\n" if @debug
          rescue => e
            $stderr.puts "Base64Str: #{line}" if @debug
            $stderr.puts e.inspect if @debug
            $stderr.puts e.backtrace if @debug
            
            raise e
          end
          
          if obj[:type] == :send
            Thread.new do
              begin
                raise "Object was not a hash." if !obj.is_a?(Hash)
                raise "No ID was given?" if !obj.key?(:id)
                res = self.__send__("cmd_#{obj[:obj][:cmd]}", obj[:obj])
              rescue => e
                res = {:type => :error, :class => e.class.name, :msg => e.message, :bt => e.backtrace}
              end
              
              data = Base64.strict_encode64(Marshal.dump(:type => :answer, :id => obj[:id], :answer => res))
              @io_out.puts(data)
            end
          elsif obj[:type] == :answer
            $stderr.print "Ruby-process-debug: Answer #{obj[:id]} saved.\n" if @debug
            @answers[obj[:id]] = obj[:answer]
          else
            raise "Unknown object: '#{obj}'."
          end
        end
      rescue => e
        @listen_err = e
      end
    end
  end
  
  #Starts the listen thread that outputs the 'stderr' for the other process on this process's 'stderr'.
  def start_listen_errors
    return nil if !@io_err
    
    @thr_err = Thread.new do
      begin
        @io_err.each_line do |str|
          $stderr.print "Ruby-process-err: #{str}" if @debug
        end
      rescue => e
        @listen_err_err = e
      end
    end
  end
end

#This class handels the calling of methods on objects in the other process seamlessly.
class Ruby_process::Proxyobj
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
  
  #Proxies all calls to the process-object.
  #===Examples
  # str = rp.new(:String, "Kasper") #=> <Ruby_process::Proxyobj::1>
  # length_int = str.length #=> <Ruby_process::Proxyobj::2>
  # length_int.__rp_marshal #=> 6
  def method_missing(method, *args, &block)
    return @args[:rp].send(:cmd => :obj_method, :id => @args[:id], :method => method, :args => args, &block)
  end
end