require_relative '../../cross_suite/hook_request_resource_extraction'
require_relative '../../cross_suite/must_support_references'
require_relative '../../cross_suite/resource_identity'
require_relative 'hook_request_data_access'

module DaVinciCRDTestKit
  # CRD v2.2.1: reads data not provided in the prefetch that tests verify later, namely the payer,
  # parent locations, the resources referenced from must support elements, and the access level
  # target.
  module V221HookRequestDataGathering
    include HookRequestDataAccess

    MUST_SUPPORT_IG_VERSION = 'v2.2.1'.freeze

    # gather additional fhir resources not requested via prefetch
    # not used for response generation, but verified later
    def request_additional_fhir_data
      request_coverage_payer
      request_parent_locations
      request_must_support_references if include_in_cross_hook_analysis?
    end

    # Reads the resources referenced from the must support Reference elements of the resources in
    # the request, so that the must support reference tests can later check that they resolved.
    # Inferno cannot reach the CRD client's FHIR server once the hook request is over, so they have
    # to be read now. Must support requirements are satisfied by the resources the request carries,
    # so references within the resources read are not followed.
    #
    # Resources and references are compared by absolute URL (see ResourceIdentity), so a resource
    # the request already carries, or that was already read for it, is not read again. A reference
    # to a server other than the `fhirServer` is read from that server without the access token.
    # Once a server has timed out, further reads from it would likely time out too, so no more are
    # attempted from that server.
    def request_must_support_references
      carried = Set.new
      to_read = []
      ResourceIdentity.each_identified_resource(request_body) do |identity, raw_resource|
        carried << identity
        to_read.concat(must_support_references_to_read(HookRequestResourceExtraction.to_fhir_resource(raw_resource),
                                                       identity))
      end

      to_read.each do |url|
        next if carried.include?(url) || fetched_references.include?(normalize_reference(url))
        next if server_timed_out?(url)

        fetch_reference(url, additional_tag: MUST_SUPPORT_REFERENCE_FETCH_TAG)
      end
    end

    # The absolute URLs of the readable references in the must support Reference elements of a
    # resource identified by the given URL.
    def must_support_references_to_read(resource, identity)
      return [] unless resource.respond_to?(:resourceType)

      base = ResourceIdentity.base_for(identity) || ResourceIdentity.fhir_server_base(request_body)
      metadata = ProfileMetadata.for_resource_type(MUST_SUPPORT_IG_VERSION, resource.resourceType)
      navigator = MustSupportReferences::Navigator.new(metadata)
      MustSupportReferences.reference_elements(metadata).flat_map do |element|
        navigator.literal_references(resource, element[:path]).filter_map do |reference|
          url = ResourceIdentity.absolute_reference(reference.reference, base)
          url if ResourceIdentity.readable?(url)
        end
      end.uniq
    end

    def request_access_level_target
      return if access_level_target_reference.blank?

      fetch_reference(access_level_target_reference, additional_tag: ACCESS_LEVEL_TARGET_FETCH_TAG)
    end

    def access_level_target_reference
      JSON.parse(result.input_json)
        .find { |input| input['name'].include?('access_level_target_reference') }
        &.dig('value')
    end

    def prefetched_coverage_resource
      if prefetched_coverage.is_a?(FHIR::Bundle)
        prefetched_coverage.entry.first&.resource
      else
        prefetched_coverage
      end
    end

    def request_coverage_payer
      return unless prefetched_coverage.present?

      coverage_resource = prefetched_coverage_resource
      return unless coverage_resource.present? && coverage_resource.payor.first&.reference.present?

      fetch_reference(coverage_resource.payor.first.reference, additional_tag: PAYER_ORG_FETCH_TAG)
    end

    def request_parent_locations
      prefetched_locations_and_parents_hash
    end

    def prefetched_location_bundle
      locations_data = request_body.dig('prefetch', 'locations') || request_body.dig('prefetch', 'locs')
      locations = FHIR.from_contents(locations_data.to_json) if locations_data.present?
      return locations if locations.is_a?(FHIR::Bundle)
      return nil unless locations.is_a?(FHIR::Location)

      FHIR::Bundle.new({ entry: [FHIR::Bundle::Entry.new({ resource: locations })] })
    end

    def prefetched_locations_and_parents_hash
      prefetched_location_bundle&.entry&.each_with_object({}) do |entry, hash|
        add_location_to_hash(entry.resource, hash)
      end
    end

    def add_location_to_hash(location, location_hash)
      return unless location.is_a?(FHIR::Location) && location.id.present?

      relative_reference = "#{location.resourceType}/#{location.id}"
      return if location_hash.key?(relative_reference)

      location_hash[relative_reference] = location
      return unless location.partOf&.reference.present?

      parent_location = fetch_reference(location.partOf.reference,
                                        additional_tag: PARENT_LOCATION_FETCH_TAG,
                                        parse_as_fhir: true)
      add_location_to_hash(parent_location, location_hash)
    end
  end
end
