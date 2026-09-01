require 'inferno'

module DaVinciCRDTestKit
  # Must support metadata for a single CRD profile, loaded from the YAML under `cross_suite/generated`
  # that {DaVinciCRDTestKit::Generator::MustSupportMetadataGenerator} writes.
  class ProfileMetadata < Inferno::DSL::ProfileMetadata
    attribute :name
    attribute :version
    attribute :reformatted_version
    attribute :title

    GENERATED_DIRECTORY = File.join(__dir__, 'generated').freeze

    class << self
      def cache
        @cache ||= {}
      end

      def for(ig_version, profile_key)
        cache[[ig_version, profile_key]] ||=
          from_file(File.join(GENERATED_DIRECTORY, ig_version, profile_key, 'metadata.yml'))
      end

      def merged(ig_version, profile_keys)
        parts = profile_keys.map { |profile_key| self.for(ig_version, profile_key) }
        return parts.first if parts.one?

        resources = parts.map(&:resource).uniq
        raise "Cannot merge metadata for differing resource types: #{resources.join(', ')}" if resources.length > 1

        new(
          resource: resources.first,
          profile_name: parts.map(&:profile_name).join(' / '),
          must_supports: union_of(parts)
        )
      end

      private

      # Elements are identified by path and fixed value together, so that two different fixed
      # values required at the same path both survive when combined.
      def union_of(parts)
        {
          extensions: union_by(parts, :extensions) { |extension| extension[:id] },
          slices: union_by(parts, :slices) { |slice| slice[:slice_id] },
          elements: union_by(parts, :elements) { |element| [element[:path], element[:fixed_value]] },
          recursive_elements: parts.flat_map { |part| Array(part.must_supports[:recursive_elements]) }.uniq
        }
      end

      def union_by(parts, key, &)
        parts.flat_map { |part| Array(part.must_supports[key]) }.uniq(&)
      end
    end
  end
end
