# frozen_string_literal: true

module Tyto
  # Shannon-entropy estimator. Used by password contracts to reject
  # weak-but-long passwords (e.g. "aaaaaaaa", entropy < 1.0).
  # See week-13 deck slide 8 for the worked examples.
  module StringSecurity
    module_function

    def entropy(string)
      return 0.0 if string.nil? || string.empty?

      counts = string.each_char.tally
      length = string.length.to_f
      counts.values.sum do |count|
        probability = count / length
        -probability * Math.log2(probability)
      end
    end
  end
end
