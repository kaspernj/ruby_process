#!/usr/bin/env ruby1.9

require "base64"
require "#{File.dirname(__FILE__)}/../lib/ruby_process.rb"

$stdin.sync = true
$stdout.sync = true
$stderr.sync = true

debug = false
pid = nil

ARGV.each do |arg|
  if arg == "--debug"
    debug = true
  elsif match = arg.match(/--pid=(\d+)$/)
    pid = match[1].to_i
  elsif match = arg.match(/--title=(.+)$/)
    #ignore - its for finding process via 'ps aux'.
  else
    raise "Unknown argument: '#{arg}'."
  end
end

debug = true if ARGV.index("--debug") != nil
raise "No PID given of parent process." unless pid

rps = RubyProcess.new(
  in: $stdin,
  out: $stdout,
  err: $stderr,
  debug: debug,
  pid: pid
)
rps.listen
$stdout.puts("ruby_process_started")
rps.join
