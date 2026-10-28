module DaVinciCRDTestKit
  # Finds the coverage data a hook request prefetched, under the key requested by either of Inferno's
  # simulated CRD servers: `coverage` by the complete prefetch server and `cov` by the subset prefetch
  # server. A value that is not a JSON object does not hide a valid value under the other key.
  module PrefetchedCoverageValue
    KEYS = ['coverage', 'cov'].freeze

    def self.find(prefetch)
      return unless prefetch.is_a?(Hash)

      prefetch.values_at(*KEYS).find { |value| value.is_a?(Hash) && value.present? }
    end
  end
end
