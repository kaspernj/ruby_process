# RubyProcess

Start another Ruby process and manipulate it almost seamlessly.

## Install

Add to your Gemfile and bundle.

```ruby
gem "ruby_process"
```

## Usage

As a block.

```ruby
Ruby_process::Cproxy.run do |data|
  sp = data[:subproc]

  string_in_process = sp.new(:String, "Test")
  string_in_process.__rp_marshall #=> "Test"
end
```

As a variable.

```ruby
rp = Ruby_process.new(debug: false)
rp.spawn_process
test_string = rp.new(:String, "Test")
```


## Contributing to ruby_process

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

