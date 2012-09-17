#!/usr/bin/env ruby

#This example shows how to dump a database using 10 processes to do so (and effectivly use 10 cores).

require "rubygems"
require "knjrbfw"
require "ruby_process"

#Holds the 'db_settings'-global-variable.
require "#{Knj::Os.homedir}/example_knj_db_dump_settings.rb"

#Create database-connection.
db = Knj::Db.new($db_settings)

#Get list of databases.
tables = db.tables.list.values

tables_per_thread = (tables.length.to_f / 10.0).ceil
print "Tables per thread: #{tables_per_thread}\n"

threads = []
1.upto(1) do |i|
  threads << Thread.new do
    begin
      thread_tables = tables.shift(tables_per_thread)
      
      Ruby_process.new(:debug => true).spawn_process do |rp|
        rp.static(:Object, :require, "rubygems")
        rp.static(:Object, :require, "knjrbfw")
        
        fpath = "/tmp/dbdump_#{i}.sql"
        
        thread_tables.each do |thread_db|
          rp_db = rp.new("Knj::Db", $db_settings)
          rp_dump = rp.new("Knj::Db::Dump", :db => rp_db, :tables => thread_tables)
          
          rp.static(:File, :open, fpath, "w") do |rp_fp|
            print "#{i} dumping #{thread_db}\n"
            rp_dump.dump(rp_fp)
          end
        end
      end
    rescue => e
      puts e.inspect
      puts e.backtrace
    end
  end
end

threads.each do |thread|
  thread.join
end