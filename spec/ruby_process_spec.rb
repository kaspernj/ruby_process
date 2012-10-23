require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "RubyProcess" do
  it "should be able to do basic stuff" do
    $rp = Ruby_process.new(:debug => false)
    $rp.spawn_process
    
    proxyarr = $rp.new(:Array)
    proxyarr << 1
    proxyarr << 3
    proxyarr << 5
    arr = proxyarr.__rp_marshal
    
    raise "Not an array." if !arr.is_a?(Array)
    raise "Expected three elements." if arr.length != 3
    raise "Expected 1" if arr[0] != 1
    raise "Expected 3" if arr[1] != 3
    raise "Expected 5" if arr[2] != 5
  end
  
  it "should be able to pass proxy-objects as arguments." do
    str = $rp.new(:String, "/tmp/somefile")
    thread_id = Thread.current.__id__
    write_called = false
    
    $rp.static(:File, :open, str, "w") do |fp|
      raise "Expected 'thread_id' to be the same but it wasnt: '#{thread_id}', '#{Thread.current.__id__}'." if thread_id != Thread.current.__id__
      fp.write("Test!")
      write_called = true
    end
    
    raise "Expected 'write' on file-pointer to be called, but it wasnt." if !write_called
    read = File.read(str.__rp_marshal)
    raise "Unexpected content of file: '#{read}'." if read != "Test!"
  end
  
  it "should be able to write files" do
    fpath = "/tmp/ruby_process_file_write_test"
    fp = $rp.static(:File, :open, fpath, "w")
    fp.write("Test!")
    fp.close
    
    raise "Expected 'Test!'" if File.read(fpath) != "Test!"
  end
  
  it "should do garbage collection" do
    GC.start
  end
  
  it "should be able to do static calls" do
    pid = $rp.static(:Process, :pid).__rp_marshal
    raise "Expected stuff to be finalized but it wasnt." if $rp.finalize_count <= 0 if RUBY_ENGINE != "jruby"
    raise "Unexpcted" if !pid.is_a?(Fixnum) and !pid.is_a?(Integer)
  end
  
  it "should be able to handle blocking blocks" do
    run_count = 0
    fpath = "/tmp/ruby_process_file_write_test"
    $rp.static(:File, :open, fpath, "w") do |fp|
      sleep 0.1
      run_count += 1
      fp.write("Test!!!")
    end
    
    raise "Expected run-count to be 1 but it wasnt: '#{run_count}'." if run_count <= 0
    raise "Expected 'Test!'" if File.read(fpath) != "Test!!!"
  end
  
  it "should be able to do slow block-results in JRuby." do
    $rp.str_eval("
      class ::Kaspertest
        def self.kaspertest
          8.upto(12) do |i|
            yield(i)
            sleep 0.5
          end
        end
      end
      
      nil
    ")
    
    require "timeout"
    Timeout.timeout(10) do
      expect = 8
      $rp.static("Kaspertest", "kaspertest") do |count|
        raise "Expected '#{expect}' but got: '#{count.__rp_marshal}'." if expect != count.__rp_marshal
        expect += 1
      end
      
      raise "Expected '13' but got: '#{expect}'." if expect != 13
    end
  end
  
  it "should be able to handle large block-runs" do
    #Try to define an integer and run upto with a block.
    proxy_int = $rp.numeric(5)
    
    expect = 5
    proxy_int.upto(250) do |i|
      raise "Expected '#{expect}' but got: '#{i.__rp_marshal}'." if i.__rp_marshal != expect
      expect += 1
    end
    
    #Ensure the expected has actually been increased by running the block.
    raise "Expected end-result of 1001 but got: '#{expect}'." if expect != 251
  end
  
  it "should handle stressed operations" do
    #Spawn a test-object - a string - with a variable-name.
    proxy_obj = $rp.new(:String, "Kasper")
    raise "to_s should return 'Kasper' but didnt: '#{proxy_obj.__rp_marshal}'." if proxy_obj.__rp_marshal != "Kasper"
    
    #Stress it a little by doing 500 calls.
    0.upto(500) do
      res = proxy_obj.slice(0, 3).__rp_marshal
      raise "Expected output was: 'Kas' but wasnt: '#{res}'." if res != "Kas"
    end
  end
  
  it "should be thread-safe" do
    #Do a lot of calls at the same time to test thread-safety.
    proxy_obj = $rp.new(:String, "Kasper")
    threads = []
    0.upto(5) do |thread_i|
      should_return = "Kasper".slice(0, thread_i)
      thread = Thread.new do
        begin
          0.upto(250) do |num_i|
            res = proxy_obj.slice(0, thread_i).__rp_marshal
            raise "Should return: '#{should_return}' but didnt: '#{res}'." if res != should_return
          end
        rescue => e
          Thread.current[:error] = e
        end
      end
      
      threads << thread
    end
    
    threads.each do |thread|
      thread.join
      raise thread[:error] if thread[:error]
    end
  end
  
  it "should be able to do evals" do
    res = $rp.str_eval("return 10").__rp_marshal
    raise "Unexpected: #{res}" if res != 10
  end
  
  it "should clean itself" do
    $rp.garbage_collect
    GC.start
    $rp.flush_finalized
    GC.start
    $rp.flush_finalized
  end
  
  it "should be clean and not leaking" do
    GC.start
    $rp.flush_finalized
    GC.start
    $rp.flush_finalized
    
    answers = $rp.instance_variable_get(:@answers)
    raise "Expected 0 answers to be present: #{answers}" if !answers.empty?
    
    objects = $rp.instance_variable_get(:@objects)
    raise "Expected 0 objects to be present: #{objects}" if !objects.empty?
  end
  
  it "should be able to destroy itself" do
    $rp.destroy
  end
end
