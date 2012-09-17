#!/usr/bin/env ruby

require "rubygems"
require "ruby_process"

Ruby_process.new.spawn_process do |rp|
  #Spawns string in the subprocess.
  str = rp.new(:String, "Kasper is 26 years old")
  
  #Scans with regex in subprocess, but yields proxy-objects in the current process.
  str.scan(/is (\d+) years old/) do |match|
    puts match.__rp_marshal
  end
end