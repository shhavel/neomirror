# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'neomirror/version'

Gem::Specification.new do |spec|
  spec.name          = "neomirror"
  spec.version       = Neomirror::VERSION
  spec.authors       = ["Alex Avoyants"]
  spec.email         = ["shhavel@gmail.com"]
  spec.summary       = %q{Lightweight but flexible gem that allows reflect some of data from relational database into neo4j.}
  spec.description   = %q{Lightweight but flexible gem that allows reflect some of data from relational database into neo4j. This allows to perform faster and easier search of your models ids or it can be first step of migrating application data to neo4j.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "neography", ">= 1.5.2"
  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 2.11"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "activerecord"
  spec.add_development_dependency "activesupport"
  spec.add_development_dependency "factory_girl"
  spec.add_development_dependency "database_cleaner", ">= 1.2.0"
end
