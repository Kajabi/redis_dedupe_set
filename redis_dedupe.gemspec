# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "redis_dedupe/version"

Gem::Specification.new do |spec|
  spec.name                   = "redis_dedupe"
  spec.version                = RedisDedupe::VERSION
  spec.required_ruby_version  = ">= 2.6.0"
  spec.authors                = ["Andy Huynh"]
  spec.email                  = ["andy4thehuynh@gmail.com"]
  spec.summary                = "A weak deduper to make things like bulk email run safer."
  spec.homepage               = ""
  spec.license                = "MIT"
  spec.files                  = Dir["lib/**/*.rb"] + ["lib/redis_dedupe.rb"]
  spec.executables            = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths          = ["lib"]
  spec.description            = <<~EO_DESC
    This is a weak deduper to make things like bulk email run safer. It is not a lock safe for financial/security needs
    because it uses a weak redis locking pattern that can have race conditions. However, imagine a bulk email job that
    loops over 100 users, and enqueues a background email for each user. If the job fails at iteration 50, a retry
    would enqueue all the users again and many will receive dupes. This would continue multiple times as the parent
    job continued to rerun. By marking that a subjob has been enqueued, we can let that isolated job handle its own
    failures, and the batch enqueue job can run multiple times without re-enqueueing the same subjobs.
  EO_DESC

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "mock_redis"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "timecop"
end
