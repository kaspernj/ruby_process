# RubyProcess

Start another Ruby process and manipulate it almost seamlessly.

## Example

The CSV lib will not be loaded in the main process and the writing of the file will also take place in another process.

```ruby
require "rubygems"
require "ruby_process"

RubyProcess.new.spawn_process do |rp|
  rp.static(:Object, :require, "csv")

  rp.static(:CSV, :open, "test.csv", "w") do |csv|
    csv << ["ID", "Name"]
    csv << [1, "Kasper"]
  end
end
```


## Install

Add to your Gemfile and bundle.

```ruby
gem "ruby_process"
```

## Usage

### Start a sub process.

With a block.

```ruby
RubyProcess.new.spawn_process do |rp|
  rp.static(:File, :open, "some_file", "w") do |fp|
    fp.write("Test!")
  end
end
```

Almost seamless mode with ClassProxy.

```ruby
RubyProcess::ClassProxy.run do |data|
  sp = data[:subproc]
  sp.static(:Object, :require, "tempfile")

  # Tempfile will be created in the subprocess and not in the current process.
  temp_file = RubyProcess::ClassProxy::Tempfile("temp")
end
```

As a variable.

```ruby
rp = RubyProcess.new(debug: false)
rp.spawn_process
test_string = rp.new(:String, "Test")
```

### Static methods.
Calling static methods on classes.

```ruby
rp.static(:File, :open, "file_path", "w")
```

### Spawning objects.

Spawning new objects.

```ruby
file = rp.new(:File, "file_path", "r")
```

### Serializing objects back to the main process.

```ruby
rp.static(:File, :size, "file_path") #=> RubyProcess::ProxyObject
rp.static(:File, :size, "file_path").__rp_marshall #=> 2048
```

### Making subprocess yield and loop in main process.

```ruby
array = rp.str_eval("[1, 3, 5, 7]")
array.class.name #=> "RubyProcess::ProxyObject"

array.each do |number|
  number.class.name #=> "RubyProcess::ProxyObject"
  number.__rp_marshal #=> 1 | 3 | 5 | 7
end
```


## Contributing to RubyProcess

* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (c) 2012 Kasper Johansen. See LICENSE.txt for
further details.

