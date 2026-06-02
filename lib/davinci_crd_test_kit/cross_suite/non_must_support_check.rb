require_relative 'hook_request_field_validation'

module DaVinciCRDTestKit
  # Reusable helper for the "client requests SHALL NOT contain non-must-support
  # elements" check defined by Da Vinci CRD conf-10 / conf-13 (and PAS conf-12).
  #
  # Builds on the inferno-core DSL method `non_must_support_elements_present`
  # added in ID-119. For each prefetched resource (Bundles flattened) we look up
  # the CRD profile via {HookRequestFieldValidation#structure_definition_map}
  # and report any non-must-support element paths or unexpected extension URLs.
  module NonMustSupportCheck
    include HookRequestFieldValidation

    # Base FHIR Resource / DomainResource fields. Every FHIR profile inherits them
    # and few profiles bother to mark them must-support, but clients legitimately
    # populate them on every resource they send (e.g., `id` is needed for cross-
    # resource references, `meta.profile` declares conformance). We strip them
    # from the non-MS report so the check focuses on profile-specific elements
    # the client actually has a choice about.
    BASE_RESOURCE_FIELDS = %w[id meta implicitRules language text contained].freeze

    def check_hook_request_non_must_support(prefetch, request_index)
      prefetch.each do |key, prefetched_resource|
        next if prefetched_resource.blank?

        @prefetch_template = key
        check_resource_non_must_support(prefetched_resource, request_index, nil)
      end
    end

    private

    def check_resource_non_must_support(prefetched_resource, request_index, bundle_entry_index)
      if prefetched_resource['resourceType'] == 'Bundle'
        prefetched_resource['entry']&.each_with_index do |entry, entry_index|
          next if entry['resource'].blank?

          check_resource_non_must_support(entry['resource'], request_index, entry_index)
        end
      elsif prefetched_resource['resourceType'].present?
        check_non_bundle_resource_non_must_support(prefetched_resource, request_index, bundle_entry_index)
      end
    end

    def check_non_bundle_resource_non_must_support(prefetched_resource, request_index, bundle_entry_index)
      target_crd_profile = structure_definition_map('v221')[prefetched_resource['resourceType']]
      return unless target_crd_profile.present?

      # structure_definition_map returns canonical URLs like ".../profile-patient|2.2.1".
      # The external HL7 validator accepts that form, but inferno-core's
      # `profile_by_url` does an exact match against the unversioned URL stored in
      # the loaded IG, so we strip the canonical version before the lookup.
      profile_url = target_crd_profile.split('|').first

      resource = FHIR.from_contents(prefetched_resource.to_json)
      violations =
        begin
          non_must_support_elements_present([resource], profile_url) do |metadata|
            metadata.must_supports[:elements].reject! do |entry|
              entry[:must_support] == false && BASE_RESOURCE_FIELDS.include?(entry[:path])
            end
          end
        rescue StandardError => e
          add_message(
            'warning',
            "#{non_must_support_error_prefix(request_index, bundle_entry_index)}" \
            "skipped non-must-support check for #{prefetched_resource['resourceType']}: #{e.message}"
          )
          []
        end

      violations.each do |violation|
        prefix = non_must_support_error_prefix(request_index, bundle_entry_index)
        add_message('error', "#{prefix}non-must-support element present: #{violation}")
      end
    end

    def non_must_support_error_prefix(request_index, bundle_entry_index)
      prefix = "(Request #{request_index + 1}) Prefetch Template '#{@prefetch_template}'"
      prefix = "#{prefix} Bundle entry #{bundle_entry_index + 1}" if bundle_entry_index.present?
      "#{prefix} - "
    end
  end
end
