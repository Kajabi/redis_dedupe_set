# frozen_string_literal: true

require "mock_redis"
require "spec_helper"

require "redis_dedupe/helpers"

RSpec.describe RedisDedupe::Helpers do
  let(:redis)     { MockRedis.new }
  let(:instance)  { RedisDedupeSpecStubbedClass.new }

  before do
    allow(RedisDedupe).to receive(:client).and_return(redis)
  end

  describe "#dedupe" do
    subject { instance.test_call }

    it { expect(subject).to eq(2) }

    it "uses the correct redis key" do
      subject
      expect(redis.smembers("RedisDedupeSpecStubbedClass:just_a_test")).to match_array(%w[5 7])
    end
  end
end

# :nodoc:
class RedisDedupeSpecStubbedClass
  include RedisDedupe::Helpers

  def test_call
    counter = 0

    dedupe.check(5) { counter += 1 }
    dedupe.check(5) { counter += 1 }
    dedupe.check(7) { counter += 1 }

    counter
  end

  def dedupe_id
    "just_a_test"
  end
end
