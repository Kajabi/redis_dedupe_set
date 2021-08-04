# frozen_string_literal: true

require "mock_redis"
require "spec_helper"
require "timecop"

require "redis_dedupe/set"

RSpec.describe RedisDedupe::Set do
  let(:redis) { MockRedis.new }
  let(:key)   { "Module::Class::#{Time.now.utc.to_i}" }

  let(:member) do
    [
      [1, 2, 3].sample,
      %w[key1 key2 key3].sample,
      %i[key1 key2 key3].sample
    ].sample
  end

  describe "#initialize #new" do
    subject(:dedupe) { described_class.new(redis, key) }

    it { expect(dedupe.key).to eq(key) }
    it { expect(dedupe.expires_in.to_i).to eq(7 * 24 * 60 * 60) } # 7 days

    context "when given the optional arg :expires_in" do
      subject(:dedupe) { described_class.new(redis, key, expires_in) }

      # 30s, 1m, 2m, 3m, 5m, 1d, 3d, 30d
      let(:expires_in) { [30, 60, 120, 180, 300, 86_400, 259_200, 2_592_000].sample }

      it { expect(dedupe.key).to eq(key) }
      it { expect(dedupe.expires_in.to_i).to eq(expires_in) }
    end
  end

  describe "#check" do
    let(:dedupe1) { described_class.new(redis, key, 120) }
    let(:dedupe2) { described_class.new(redis, "Some::Other::Key") }
    let(:dedupe3) { described_class.new(redis, "Another::Strange::Key") }
    let(:results) { [] }

    context "when no block is given" do
      it { expect { dedupe1.check(member) }.to raise_error(ArgumentError, "passing a block is required") }
    end

    context "when an empty block is given" do
      it { expect(dedupe1.check(member) {}).to eq(nil) }
    end

    context "when calling multiple times for the same member" do
      before do
        dedupe1.check(member) { results << "A" }
        dedupe2.check(member) { results << "B" }
        dedupe1.check(member) { results << "C" }
        dedupe3.check(member) { results << "D" }
        dedupe2.check(member) { results << "E" }

        Timecop.travel(Time.now + 110)
      end

      after do
        Timecop.return
      end

      it "only calls the block once per member" do
        expect(results).to eq(%w[A B D])
      end

      it "resets the redis ttl" do
        expect(redis.ttl(key)).to be_within(1).of(10) # 120 - 110 => 10
        dedupe1.check("another_member") {}
        expect(redis.ttl(key)).to be_within(1).of(120)
      end
    end

    context "when the yielded block raises an error" do
      subject do
        dedupe1.check("a") {}
        dedupe1.check("b") {}
        dedupe1.check("c") { raise "foobar" }
      end

      it "removes the member from Redis and re-raises the error" do
        expect { subject }.to raise_error(RuntimeError, "foobar")
        expect(redis.smembers(key)).to match_array(%w[a b])
      end
    end
  end

  describe "#finish" do
    let(:dedupe) { described_class.new(redis, key) }

    it "removes the entire set for the specified key" do
      dedupe.check(member) {}
      expect(redis.exists?(key)).to eq(true)
      dedupe.finish
      expect(redis.exists?(key)).to eq(false)
    end
  end

  describe "#max_member" do
    subject { dedupe.max_member }

    let(:dedupe) { described_class.new(redis, key) }

    context "when member is input as an integer" do
      before do
        dedupe.check(3) {}
        dedupe.check(5) {}
        dedupe.check(4) {}
        dedupe.check(2) {}
        dedupe.check(1) {}
      end

      it { is_expected.to eq("5") }
    end

    context "when member is input as a string representation of an integer" do
      before do
        dedupe.check("3") {}
        dedupe.check("5") {}
        dedupe.check("4") {}
        dedupe.check("2") {}
        dedupe.check("1") {}
      end

      it { is_expected.to eq("5") }
    end
  end
end
