#!/usr/bin/env ruby

require "rubygems"
require "ruby_process"

fpath = "/tmp/somefile"
RubyProcess.new.spawn_process do |rp|
  #Opens file in subprocess.
  rp.static(:File, :open, fpath, "w") do |fp|
    #Writes to file in subprocess.
    fp.write("Test!")
  end
end

print "Content of '#{fpath}': #{File.read(fpath)}\n"
