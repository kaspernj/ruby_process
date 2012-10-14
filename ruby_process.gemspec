# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{ruby_process}
  s.version = "0.0.5"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Kasper Johansen"]
  s.date = %q{2012-10-14}
  s.description = %q{A framework for spawning and communicating with other Ruby-processes}
  s.email = %q{k@spernj.org}
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.rdoc"
  ]
  s.files = [
    ".document",
    ".rspec",
    "Gemfile",
    "LICENSE.txt",
    "README.rdoc",
    "Rakefile",
    "VERSION",
    "cmds/blocks.rb",
    "cmds/marshal.rb",
    "cmds/new.rb",
    "cmds/numeric.rb",
    "cmds/static.rb",
    "cmds/str_eval.rb",
    "cmds/system.rb",
    "examples/example_file_write.rb",
    "examples/example_knj_db_dump.rb",
    "examples/example_strscan.rb",
    "include/args_handeling.rb",
    "lib/ruby_process.rb",
    "lib/ruby_process_cproxy.rb",
    "ruby_process.gemspec",
    "scripts/ruby_process_script.rb",
    "spec/cproxy_spec.rb",
    "spec/ruby_process_spec.rb",
    "spec/spec_helper.rb"
  ]
  s.homepage = %q{http://github.com/kaspernj/ruby_process}
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.6.2}
  s.summary = %q{A framework for spawning and communicating with other Ruby-processes}

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<wref>, [">= 0"])
      s.add_runtime_dependency(%q<tsafe>, [">= 0"])
      s.add_development_dependency(%q<rspec>, ["~> 2.8.0"])
      s.add_development_dependency(%q<rdoc>, ["~> 3.12"])
      s.add_development_dependency(%q<bundler>, [">= 1.0.0"])
      s.add_development_dependency(%q<jeweler>, ["~> 1.8.3"])
      s.add_development_dependency(%q<rcov>, [">= 0"])
    else
      s.add_dependency(%q<wref>, [">= 0"])
      s.add_dependency(%q<tsafe>, [">= 0"])
      s.add_dependency(%q<rspec>, ["~> 2.8.0"])
      s.add_dependency(%q<rdoc>, ["~> 3.12"])
      s.add_dependency(%q<bundler>, [">= 1.0.0"])
      s.add_dependency(%q<jeweler>, ["~> 1.8.3"])
      s.add_dependency(%q<rcov>, [">= 0"])
    end
  else
    s.add_dependency(%q<wref>, [">= 0"])
    s.add_dependency(%q<tsafe>, [">= 0"])
    s.add_dependency(%q<rspec>, ["~> 2.8.0"])
    s.add_dependency(%q<rdoc>, ["~> 3.12"])
    s.add_dependency(%q<bundler>, [">= 1.0.0"])
    s.add_dependency(%q<jeweler>, ["~> 1.8.3"])
    s.add_dependency(%q<rcov>, [">= 0"])
  end
end

