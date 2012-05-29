#!/usr/bin/env ruby1.9

require "base64"
require "#{File.dirname(__FILE__)}/../lib/ruby_process.rb"

$stdin.sync = true
$stdout.sync = true
$stderr.sync = true

debug = true if ARGV.index("--debug") != nil

rps = Ruby_process.new(
  :in => $stdin,
  :out => $stdout,
  :err => $stderr,
  :debug => debug
)
rps.listen
$stdout.puts("ruby_process_started")
rps.join