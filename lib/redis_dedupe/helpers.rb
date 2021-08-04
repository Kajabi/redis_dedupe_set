# frozen_string_literal: true

# :nodoc:
module RedisDedupe
  #
  # Include `RedisDedupe::Helpers` to use +RedisDedupe::Set+
  #
  # class MyClass
  #   include RedisDedupe::Helpers
  #
  #   private
  #
  #   def dedupe_id
  #     "my_unique_set_key"
  #   end
  # end
  #
  module Helpers
    private

    def dedupe
      @dedupe ||= RedisDedupe::Set.new(RedisDedupe.client, key)
    end

    def key
      [dedupe_namespace, dedupe_id].join(":")
    end

    # Implement in class, should return an integer or string:
    #
    # Ex.
    #
    #   def dedupe_id
    #     @announcement.id # => 42
    #   end
    #
    def dedupe_id
      raise NotImplementedError
    end

    def dedupe_namespace
      self.class.name
    end
  end
end
