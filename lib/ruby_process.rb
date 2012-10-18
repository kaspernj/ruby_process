require "rubygems"
require "base64"
require "wref" if !Kernel.const_defined?(:Wref)
require "tsafe" if !Kernel.const_defined?(:Tsafe)
require "thread"

#This class can communicate with another Ruby-process. It tries to integrate the work in the other process as seamless as possible by using proxy-objects.
class Ruby_process
  attr_reader :finalize_count, :pid
  
  #Require all the different commands.
  dir = "#{File.dirname(__FILE__)}/../cmds"
  Dir.foreach(dir) do |file|
    require "#{dir}/#{file}" if file =~ /\.rb$/
  end
  
  #Methods for handeling arguments and proxy-objects in arguments.
  require "#{File.dirname(__FILE__)}/../include/args_handeling.rb"
  
  #Autoloader for subclasses.
  def self.const_missing(name)
    require "#{File.realpath(File.dirname(__FILE__))}/ruby_process_#{name.to_s.downcase}.rb"
    raise "Still not defined: '#{name}'." if !self.const_defined?(name)
    return self.const_get(name)
  end
  
  #Constructor.
  #===Examples
  # Ruby_process.new.spawn_process do |rp|
  #   str = rp.new(:String, "Kasper")
  # end
  def initialize(args = {})
    @args = args
    @debug = @args[:debug]
    @pid = @args[:pid]
    
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
    @finalize_count = 0
    
    #Send ID is used to identify the correct answers.
    @send_mutex = Mutex.new
    @send_count = 0
    
    #The PID is used to know which process proxy-objects belongs to.
    @my_pid = Process.pid
  end
  
  #Spawns a new process in the same Ruby-inteterpeter as the current one.
  #===Examples
  # rp = Ruby_process.new.spawn_process
  # rp.str_eval("return 10").__rp_marshal #=> 10
  # rp.destroy
  def spawn_process(args = nil)
    #Used for printing debug-stuff.
    @main = true
    
    if args and args[:exec]
      cmd = "#{args[:exec]}"
    else
      if !ENV["rvm_ruby_string"].to_s.empty?
        cmd = "#{ENV["rvm_ruby_string"]}"
      else
        cmd = "ruby"
      end
    end
    
    cmd << " \"#{File.realpath(File.dirname(__FILE__))}/../scripts/ruby_process_script.rb\" --pid=#{@my_pid}"
    cmd << " --debug" if @args[:debug]
    cmd << " \"--title=#{@args[:title]}\"" if !@args[:title].to_s.strip.empty?
    
    #Start process and set IO variables.
    require "open3"
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
      
      debug "Ruby-process-debug from stdout before started: '#{str}'\n" if @debug
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
      
      return self
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
    return nil if self.destroyed?
    debug "Destroying Ruby-process (#{caller}).\n" if @debug
    
    begin
      #Send exit-command to sub-process.
      send(:cmd => :exit) if alive?
    rescue => e
      raise e if e.message != "Process is dead." and e.message != "Not listening."
    ensure
      #Make main kill it and make sure its dead...
      begin
        if @main and @pid
          Process.kill("TERM", @pid)
          Process.kill(9, @pid)
        end
      rescue Errno::ESRCH
        #Process is already dead - ignore.
      ensure
        @pid = nil
        @io_out = nil
        @io_in = nil
        @io_err = nil
        @main = nil
      end
    end
  end
  
  #Returns true if the Ruby process has been destroyed.
  def destroyed?
    return true if !@pid and !@io_out and !@io_in and !@io_err and @main == nil
    return false
  end
  
  #Joins the listen thread and error-thread. This is useually only called on the sub-process side, but can also be useful, if you are waiting for a delayed callback from the subprocess.
  def join
    debug "Joining listen-thread.\n" if @debug
    @thr_listen.join if @thr_listen
    raise @listen_err if @listen_err
    
    debug "Joining error-thread.\n" if @debug
    @thr_err.join if @thr_join
    raise @listen_err_err if @listen_err_err
  end
  
  #Sends a command to the other process. This should not be called manually, but is used by various other parts of the framework.
  def send(obj, &block)
    alive_check!
    
    #Sync ID stuff so they dont get mixed up.
    id = nil
    @send_mutex.synchronize do
      id = @send_count
      @send_count += 1
    end
    
    #Parse block.
    if block
      block_proxy_res = self.send(:cmd => :spawn_proxy_block, :id => block.__id__, :answer_id => id)
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
    
    debug "Sending(#{id}): #{obj}\n" if @debug
    line = Base64.strict_encode64(Marshal.dump(
      :id => id,
      :type => :send,
      :obj => obj
    ))
    @answers[id] = Queue.new
    @io_out.puts(line)
    
    return answer_read(id)
  end
  
  #Returns true if the child process is still running. Otherwise false.
  def alive?
    begin
      alive_check!
      return true
    rescue
      return false
    end
  end
  
  private
  
  #Raises an error if the subprocess is no longer alive.
  def alive_check!
    raise "Has been destroyed." if self.destroyed?
    raise "No 'io_out'." if !@io_out
    raise "No 'io_in'." if !@io_in
    raise "'io_in' was closed." if @io_in.closed?
    raise "No listen thread." if !@thr_listen
    #raise "Listen thread wasnt alive?" if !@thr_listen.alive?
    
    return nil
  end
  
  #Prints the given string to stderr. Raises error if debugging is not enabled.
  def debug(str_full)
    raise "Debug not enabled?" if !@debug
    
    str_full.each_line do |str|
      if @main
        $stderr.print "(M#{@my_pid}) #{str}"
      else
        $stderr.print "(S#{@my_pid}) #{str}"
      end
    end
  end
  
  #Registers an object ID as a proxy-object on the host-side.
  def proxyobj_get(id, pid = @my_pid)
    if proxy_obj = @proxy_objs.get!(id)
      debug "Reuse proxy-obj (ID: #{id}, PID: #{pid}, fID: #{proxy_obj.args[:id]}, fPID: #{proxy_obj.args[:pid]})\n" if @debug
      return proxy_obj
    end
    
    @proxy_objs_unsets.delete(id)
    proxy_obj = Ruby_process::Proxyobj.new(:rp => self, :id => id, :pid => pid)
    @proxy_objs[id] = proxy_obj
    @proxy_objs_ids[proxy_obj.__id__] = id
    ObjectSpace.define_finalizer(proxy_obj, self.method(:proxyobj_finalizer))
    
    return proxy_obj
  end
  
  #Returns the saved proxy-object by the given ID. Raises error if it doesnt exist.
  def proxyobj_object(id)
    obj = @objects[id]
    raise "No object by that ID: '#{id}' (#{@objects})." if !obj
    return obj
  end
  
  #Method used for detecting garbage-collected proxy-objects. This way we can also free references to them in the other process, so it doesnt run out of memory.
  def proxyobj_finalizer(id)
    debug "Finalized #{id}\n" if @debug
    proxy_id = @proxy_objs_ids[id]
    
    if !proxy_id
      debug "No such ID in proxy objects IDs hash: '#{id}'.\n" if @debug
    else
      @proxy_objs_unsets << proxy_id
      debug "Done finalizing #{id}\n" if @debug
    end
    
    return nil
  end
  
  #Waits for an answer to appear in the answers-hash. Then deletes it from hash and returns it.
  def answer_read(id)
    begin
      loop do
        debug "Waiting for answer #{id}\n" if @debug
        answer = @answers[id].pop
        debug "Returning answer #{id}\n" if @debug
        
        if answer.is_a?(Hash)
          if answer[:type] == :error and answer.key?(:class) and answer.key?(:msg) and answer.key?(:bt)
            begin
              raise "#{answer[:class]}: #{answer[:msg]}"
            rescue => e
              bt = []
              answer[:bt].each do |btline|
                bt << "(#{@pid}): #{btline}"
              end
              
              bt += e.backtrace
              e.set_backtrace(bt)
              raise e
            end
          elsif answer[:type] == :proxy_obj and answer.key?(:id) and answer.key?(:pid)
            return proxyobj_get(answer[:id], answer[:pid])
          elsif answer[:type] == :proxy_block_call
            answer[:block].call(*answer[:args])
          else
            return answer
          end
        else
          return answer
        end
      end
    ensure
      @answers.delete(id)
    end
    
    raise "This should never be reached."
  end
  
  #Starts the listen-thread that listens for, and executes, commands.
  def start_listen
    @thr_listen = Thread.new do
      begin
        @io_in.each_line do |line|
          raise "No line?" if !line or line.to_s.strip.empty?
          alive_check!
          debug "Received: #{line}" if @debug
          
          begin
            obj = Marshal.load(Base64.strict_decode64(line.strip))
            debug "Object received: #{obj}\n" if @debug
          rescue => e
            $stderr.puts "Base64Str: #{line}" if @debug
            $stderr.puts e.inspect if @debug
            $stderr.puts e.backtrace if @debug
            
            raise e
          end
          
          id = obj[:id]
          
          if obj[:type] == :send
            obj[:obj][:send_id] = id
            
            Thread.new do
              begin
                raise "Object was not a hash." if !obj.is_a?(Hash)
                raise "No ID was given?" if !id
                res = self.__send__("cmd_#{obj[:obj][:cmd]}", obj[:obj])
              rescue Exception => e
                raise e if e.is_a?(SystemExit) or e.is_a?(Interrupt)
                res = {:type => :error, :class => e.class.name, :msg => e.message, :bt => e.backtrace}
              end
              
              data = Base64.strict_encode64(Marshal.dump(:type => :answer, :id => id, :answer => res))
              @io_out.puts(data)
            end
          elsif obj[:type] == :answer
            debug "Answer #{id} saved.\n" if @debug
            @answers[id] << obj[:answer]
          else
            raise "Unknown object: '#{obj}'."
          end
        end
      rescue => e
        if @debug
          debug "Error while listening: #{e.inspect}"
          debug e.backtrace.join("\n") + "\n"
        end
        
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
          $stderr.print str if @debug
        end
      rescue => e
        @listen_err_err = e
      end
    end
  end
end