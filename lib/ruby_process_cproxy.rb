require "monitor"

#This class is used to seamlessly use leaky classes without working through 'Ruby_process'.
#===Examples
#  Ruby_process::Cproxy.run do |data|
#    data[:subproc].static(:Object, :require, "rubygems")
#    data[:subproc].static(:Object, :require, "rexml/document")
#    
#    doc = Ruby_process::Cproxy::REXML::Document.new("test")
#    strio = StringIO.new
#    doc.write(strio)
#    puts strio.string #=> "<test/>"
#    raise "REXML shouldnt be defined?" if Kernel.const_defined?(:REXML)
class Ruby_process::Cproxy
  #Lock is used to to create new Ruby-process-instances and not doing double-counts.
  @@lock = Monitor.new
  
  #Counts how many instances are using the Cproxy-module. This way it can be safely unset once no-body is using it again.
  @@instances = 0
  
  #This variable will hold the 'Ruby_process'-object where sub-objects will be created.
  @@subproc = nil
  
  #All use should go through this method to automatically destroy sub-processes and keep track of ressources.
  def self.run
    #Increase count of instances that are using Cproxy and set the subproc-object if not already set.
    @@lock.synchronize do
      #Check if the sub-process is alive.
      if @@subproc and (!@@subproc.alive? or @@subproc.destroyed?)
        raise "Cant destroy sub-process because instances are running: '#{@@instances}'." if @@instances > 0
        @@subproc.destroy
        @@subproc = nil
      end
      
      #Start a new subprocess if none is defined and active.
      if !@@subproc
        subproc = Ruby_process.new(:title => "ruby_process_cproxy", :debug => false)
        subproc.spawn_process
        @@subproc = subproc
      end
      
      @@instances += 1
    end
    
    begin
      yield(:subproc => @@subproc)
      raise "'run'-caller destroyed sub-process. This shouldn't happen." if @@subproc.destroyed?
    ensure
      @@lock.synchronize do
        @@instances -= 1
        
        if @@instances <= 0
          begin
            @@subproc.destroy
          ensure
            @@subproc = nil
          end
        end
      end
    end
  end
  
  #Returns the 'Ruby_process'-object or raises an error if it has not been set.
  def self.subproc
    raise "CProxy process not set for some reason?" if !@@subproc
    return @@subproc
  end
  
  #Creates the new constant under the 'Ruby_process::Cproxy'-namespace.
  def self.const_missing(name)
    Ruby_process::Cproxy.load_class(self, name) if !self.const_defined?(name)
    raise "Still not created on const: '#{name}'." if !self.const_defined?(name)
    return self.const_get(name)
  end
  
  #Loads a new class to the given constants namespace for recursive creating of missing classes.
  def self.load_class(const, name)
    const.const_set(name, Class.new{
      #Use 'const_missing' to auto-create missing sub-constants recursivly.
      def self.const_missing(name)
        Ruby_process::Cproxy.load_class(self, name) if !self.const_defined?(name)
        raise "Still not created on const: '#{name}'." if !self.const_defined?(name)
        return self.const_get(name)
      end
      
      #Manipulate 'new'-method return proxy-objects instead of real objects.
      def self.new(*args, &blk)
        name_match = self.name.to_s.match(/^Ruby_process::Cproxy::(.+)$/)
        class_name = name_match[1]
        
        subproc = Ruby_process::Cproxy.subproc
        obj = subproc.new(class_name, *args, &blk)
        
        return obj
      end
      
      def self.method_missing(method_name, *args, &blk)
        name_match = self.name.to_s.match(/^Ruby_process::Cproxy::(.+)$/)
        class_name = name_match[1]
        
        subproc = Ruby_process::Cproxy.subproc
        
        return subproc.static(class_name, method_name, *args, &blk)
      end
    })
  end
end