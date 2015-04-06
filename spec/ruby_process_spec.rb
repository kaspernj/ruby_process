require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "RubyProcess" do
  let(:rp) do
    rp = Ruby_process.new(debug: false)
    rp.spawn_process
    rp
  end

  after do
    rp.destroy unless rp.destroyed?
  end

  it "should be able to do basic stuff" do
    proxyarr = rp.new(:Array)
    proxyarr << 1
    proxyarr << 3
    proxyarr << 5

    proxyarr.__rp_marshal.should eq [1, 3, 5]
  end

  it "should be able to pass proxy-objects as arguments." do
    str = rp.new(:String, "/tmp/somefile")
    thread_id = Thread.current.__id__
    write_called = false

    rp.static(:File, :open, str, "w") do |fp|
      thread_id.should eq Thread.current.__id__
      fp.write("Test!")
      write_called = true
    end

    write_called.should eq true
    File.read(str.__rp_marshal).should eq "Test!"
  end

  it "should be able to write files" do
    fpath = "/tmp/ruby_process_file_write_test"
    fp = rp.static(:File, :open, fpath, "w")
    fp.write("Test!")
    fp.close

    File.read(fpath).should eq "Test!"
  end

  it "should do garbage collection" do
    GC.start
  end

  it "should be able to do static calls" do
    pid = rp.static(:Process, :pid).__rp_marshal
    rp.finalize_count.should be <= 0 unless RUBY_ENGINE == "jruby"
    raise "Not a number" if !pid.is_a?(Fixnum) && !pid.is_a?(Integer)
  end

  it "should be able to handle blocking blocks" do
    run_count = 0
    fpath = "/tmp/ruby_process_file_write_test"
    rp.static(:File, :open, fpath, "w") do |fp|
      sleep 0.1
      run_count += 1
      fp.write("Test!!!")
    end

    run_count.should > 0
    File.read(fpath).should eq "Test!!!"
  end

  it "should be able to do slow block-results in JRuby." do
    rp.str_eval("
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
      rp.static("Kaspertest", "kaspertest") do |count|
        expect.should eq count.__rp_marshal
        expect += 1
      end

      expect.should eq 13
    end
  end

  it "should be able to handle large block-runs" do
    #Try to define an integer and run upto with a block.
    proxy_int = rp.numeric(5)

    expect = 5
    proxy_int.upto(250) do |i|
      i.__rp_marshal.should eq expect
      expect += 1
    end

    #Ensure the expected has actually been increased by running the block.
    expect.should eq 251
  end

  it "should handle stressed operations" do
    #Spawn a test-object - a string - with a variable-name.
    proxy_obj = rp.new(:String, "Kasper")
    proxy_obj.__rp_marshal.should eq "Kasper"

    #Stress it a little by doing 500 calls.
    0.upto(500) do
      res = proxy_obj.slice(0, 3).__rp_marshal
      res.should eq "Kas"
    end
  end

  it "should be thread-safe" do
    #Do a lot of calls at the same time to test thread-safety.
    proxy_obj = rp.new(:String, "Kasper")
    threads = []
    0.upto(5) do |thread_i|
      should_return = "Kasper".slice(0, thread_i)
      thread = Thread.new do
        begin
          0.upto(250) do |num_i|
            res = proxy_obj.slice(0, thread_i).__rp_marshal
            res.should eq should_return
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
    res = rp.str_eval("return 10").__rp_marshal
    res.should eq 10
  end

  it "should clean itself" do
    rp.garbage_collect
    GC.start
    rp.flush_finalized
    GC.start
    rp.flush_finalized
  end

  it "should be clean and not leaking" do
    GC.start
    rp.flush_finalized
    GC.start
    rp.flush_finalized

    answers = rp.instance_variable_get(:@answers)
    answers.should be_empty

    objects = rp.instance_variable_get(:@objects)
    objects.should be_empty
  end

  it "should be able to destroy itself" do
    rp.destroy
    rp.destroyed?.should eq true
  end
end
