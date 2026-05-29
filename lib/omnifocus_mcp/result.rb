# frozen_string_literal: true

module OmnifocusMcp
  # Success/disjoint-error ADT. {#and_then} does not rescue: the block must return another Result and
  # should not raise for domain failures (use {#map} or return Result.error).
  # Programmer bugs and invariant violations should use +raise+, not Result.error.
  Result = Data.define(:value, :error_message, :creation_location) do
    def self.ok(value)
      new(value: value, error_message: nil, creation_location: caller_locations(1, 1).first)
    end

    # @param message [Object] user-facing String or other user-facing error payload.
    def self.error(message)
      new(value: nil, error_message: message, creation_location: caller_locations(1, 1).first)
    end

    # Pair two results; first error wins. Values become a two-element Array on success.
    def self.zip(left, right)
      return left if left.error?
      return right if right.error?

      Result.ok([left.ok, right.ok])
    end

    # Sequence a +Hash+ or +Array+ of Results into a single Result. Fail-fast: the first error in
    # iteration order wins (insertion order for Hashes). On success the wrapped value mirrors the
    # input container's shape: array-in → array-of-values-out, hash-in → hash-of-values-out.
    def self.all(results)
      case results
      when Array
        first_error = results.find(&:error?)
        first_error || Result.ok(results.map(&:ok))
      when Hash
        first_error = results.each_value.find(&:error?)
        first_error || Result.ok(results.transform_values(&:ok))
      else
        raise ArgumentError, "Result.all expects an Array or Hash, got #{results.class}"
      end
    end

    def ok? = !value.nil?

    def error? = !error_message.nil?

    def ok
      raise "Cannot get value from error result: #{error_message}, #{creation_location}" if error?

      value
    end

    def ok_or(default_value) = ok? ? value : default_value

    def error
      raise "Cannot get error from ok result" if ok?

      error_message
    end

    def map
      return self if error?

      Result.ok(yield(ok))
    rescue StandardError => e
      Result.error(e.message)
    end

    def and_then
      return self if error?

      yield(ok)
    end

    def or_else
      return self if ok?

      yield(error)
    end

    # Collapses the +if ok? ... else ... end+ shape into a single expression. The chosen branch is
    # called with the wrapped value (or error message) and its return value is passed through verbatim;
    # this is a terminator, not a chainable Result-returning combinator.
    def fold(on_ok:, on_error:) = ok? ? on_ok.call(ok) : on_error.call(error)

    def where = creation_location

    def deconstruct = [value, error_message]

    def deconstruct_keys(keys)
      if keys.nil?
        return error? ? { error_message: error_message } : { value: value }
      end

      keys.filter_map do |key|
        val = public_send(key)
        [key, val] unless val.nil?
      end.to_h
    end

    private

    def initialize(value:, error_message:, creation_location:)
      raise ArgumentError, "Cannot have both value and error" unless value.nil? || error_message.nil?
      raise ArgumentError, "Must provide either value or error" if value.nil? && error_message.nil?

      super
    end
  end
end
