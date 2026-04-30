require_relative 'hook_request_field_validation'

module DaVinciCRDTestKit
  module PrefetchProfileValidation
    include HookRequestFieldValidation

    def check_prefetch_profiles(prefetch)
      prefetch.each do |key, prefetched_resource|
        next unless prefetched_resource.present? # prefetch must be null if no data matches the template

        @prefetch_template = key
        @bundle_entry_index = nil
        check_resource_profile(prefetched_resource)
      end
    end

    private

    def check_resource_profile(prefetched_resource)
      if prefetched_resource['resourceType'] == 'Bundle'
        prefetched_resource['entry']&.each_with_index do |entry, bundle_entry_index|
          @bundle_entry_index = bundle_entry_index
          check_resource_profile(entry['resource']) if entry['resource'].present?
        end
        @bundle_entry_index = nil
      elsif prefetched_resource['resourceType'].present?
        check_non_bundle_resource_profile(prefetched_resource)
      end
    end

    def check_non_bundle_resource_profile(prefetched_resource)
      target_crd_profile = structure_definition_map('v221')[prefetched_resource['resourceType']]
      return unless target_crd_profile.present?

      validation_details = []
      resource_is_valid?(resource: FHIR.from_contents(prefetched_resource.to_json),
                         profile_url: target_crd_profile,
                         validator_response_details: validation_details, add_messages_to_runnable: false)
      validation_details.each do |issue|
        add_message(issue.severity, "#{prefetch_profile_error_prefix}#{issue.message}")
      end
    end

    def prefetch_profile_error_prefix
      prefix = "(Request #{@request_index + 1}) Prefetch Template '#{@prefetch_template}'"
      prefix = " #{prefix} Bundle entry #{@bundle_entry_index + 1}" if @bundle_entry_index.present?
      "#{prefix} validation issue - "
    end
  end
end
