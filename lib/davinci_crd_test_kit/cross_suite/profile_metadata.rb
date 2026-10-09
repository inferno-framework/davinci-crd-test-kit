require 'inferno'

module DaVinciCRDTestKit
  # Must support metadata for a single CRD profile, loaded from the YAML under `cross_suite/generated`
  # that {DaVinciCRDTestKit::Generator::MustSupportMetadataGenerator} writes.
  class ProfileMetadata < Inferno::DSL::ProfileMetadata
    GENERATED_DIRECTORY = File.join(__dir__, 'generated').freeze

    class << self
      def cache
        @cache ||= {}
      end

      def for(ig_version, profile_key)
        cache[[ig_version, profile_key]] ||=
          from_file(File.join(GENERATED_DIRECTORY, ig_version, profile_key, 'metadata.yml'))
      end

      # Every generated profile for the given resource type, merged, or nil when CRD defines none.
      # Stubs written only so a target profile can be looked up carry no must supports, so they are
      # left out.
      def for_resource_type(ig_version, resource_type)
        profile_keys = profile_keys(ig_version).select do |key|
          metadata = self.for(ig_version, key)
          metadata.resource == resource_type && metadata.must_supports.present?
        end
        merged(ig_version, profile_keys) if profile_keys.present?
      end

      # The metadata, possibly a stub, for the profile a target profile names. Any `|version`
      # suffix on the target profile is ignored.
      def for_profile_url(ig_version, target_profile)
        url = target_profile.to_s.split('|').first
        profile_keys(ig_version).lazy.map { |key| self.for(ig_version, key) }.find { |one| one.profile_url == url }
      end

      def profile_keys(ig_version)
        directory = File.join(GENERATED_DIRECTORY, ig_version)
        Dir.children(directory).select { |key| File.exist?(File.join(directory, key, 'metadata.yml')) }.sort
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
          choices: union_by(parts, :choices) { |choice| choice[:paths] },
          recursive_elements: parts.flat_map { |part| Array(part.must_supports[:recursive_elements]) }.uniq
        }
      end

      def union_by(parts, key, &)
        parts.flat_map { |part| Array(part.must_supports[key]) }.uniq(&)
      end
    end
  end
end
