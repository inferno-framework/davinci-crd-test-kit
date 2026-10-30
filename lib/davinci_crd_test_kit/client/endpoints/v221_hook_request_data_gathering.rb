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
    # not used for response generation, but verified later, so a failure in one step is logged and
    # the others still run (see #continue_after_failure)
    def request_additional_fhir_data
      continue_after_failure('reading the Coverage payer') { request_coverage_payer }
      continue_after_failure('reading parent Locations') { request_parent_locations }
      return unless include_in_cross_hook_analysis?

      continue_after_failure('reading must support references') { request_must_support_references }
    end

    # Reads the resources referenced from the must support Reference elements of the resources in
    # the request, so that the must support reference tests can later check that they resolved.
    # Inferno cannot reach the CRD client's FHIR server once the hook request is over, so they have
    # to be read now. Must support requirements are satisfied by the resources the request carries,
    # so references within the resources read are not followed.
    #
    # Resources and references are compared by normalized absolute URL (see ResourceIdentity), so a
    # resource the request already carries, or that was already read for it, is not read again. A reference
    # to a server other than the `fhirServer` is read from that server without the access token.
    # Once a server has timed out, further reads from it would likely time out too, so no more are
    # attempted from that server.
    def request_must_support_references
      carried = Set.new
      to_read = []
      ResourceIdentity.each_identified_resource(request_body) do |identity, raw_resource|
        carried << ResourceIdentity.normalized_url(identity)
        to_read.concat(must_support_references_to_read(HookRequestResourceExtraction.to_fhir_resource(raw_resource),
                                                       identity))
      end

      to_read.each do |url|
        next if carried.include?(url) || fetched_references.include?(normalize_reference(url))
        next if server_timed_out?(url)

        fetch_reference(url)
      end
    end

    # The absolute URLs of the readable references in the must support Reference elements of a
    # resource identified by the given URL.
    def must_support_references_to_read(resource, identity)
      return [] unless resource.respond_to?(:resourceType)

      base = ResourceIdentity.base_for(identity)
      metadata = ProfileMetadata.for_resource_type(MUST_SUPPORT_IG_VERSION, resource.resourceType)
      navigator = MustSupportReferences::Navigator.new(metadata)
      MustSupportReferences.reference_elements(metadata).flat_map do |element|
        navigator.literal_references(resource, element[:path]).filter_map do |reference|
          url = ResourceIdentity.normalized_url(ResourceIdentity.absolute_reference(reference.reference, base))
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
        prefetched_coverage_entry&.resource
      elsif prefetched_coverage.is_a?(FHIR::Coverage)
        prefetched_coverage
      end
    end

    # A search Bundle can hold entries other than Coverages, such as an OperationOutcome, so the
    # first Coverage is used rather than the first entry.
    def prefetched_coverage_entry
      prefetched_coverage.entry.find { |entry| entry.resource.is_a?(FHIR::Coverage) }
    end

    def request_coverage_payer
      return unless prefetched_coverage.present?

      coverage_resource = prefetched_coverage_resource
      return unless coverage_resource.present? && coverage_resource.payor.first&.reference.present?

      payer_reference = resolved_reference(coverage_resource.payor.first.reference, prefetched_coverage_identity)
      fetch_reference(payer_reference, additional_tag: PAYER_ORG_FETCH_TAG) if payer_reference.present?
    end

    # The absolute URL identifying the prefetched Coverage (see ResourceIdentity), nil for a Bundle
    # entry without a fullUrl.
    def prefetched_coverage_identity
      return prefetched_coverage_entry&.fullUrl.presence if prefetched_coverage.is_a?(FHIR::Bundle)

      ResourceIdentity.restful_identity(prefetched_coverage_resource, fhir_server_base)
    end

    # The normalized absolute form of a reference held by the resource identified by the given URL,
    # following the FHIR rules for resolving references, or the reference as given when it has no
    # absolute form. nil for a reference that is not a string, or a relative one held by a resource
    # whose identity is not a RESTful URL, neither of which can be read.
    def resolved_reference(reference, holder_identity)
      return unless reference.is_a?(String)

      base = ResourceIdentity.base_for(holder_identity)
      return if base.blank? && !ResourceIdentity.absolute_url?(reference)

      ResourceIdentity.normalized_url(ResourceIdentity.absolute_reference(reference, base)) || reference
    end

    def fhir_server_base
      ResourceIdentity.fhir_server_base(request_body)
    end

    def request_parent_locations
      prefetched_locations_and_parents_hash
    end

    def prefetched_location_bundle
      locations_data = request_body.dig('prefetch', 'locations') || request_body.dig('prefetch', 'locs')
      locations = FHIR.from_contents(locations_data.to_json) if locations_data.present?
      return locations if locations.is_a?(FHIR::Bundle)
      return nil unless locations.is_a?(FHIR::Location)

      # a Location given outside a Bundle is on the request's FHIR server
      full_url = ResourceIdentity.restful_identity(locations, fhir_server_base)
      FHIR::Bundle.new({ entry: [FHIR::Bundle::Entry.new({ fullUrl: full_url, resource: locations })] })
    end

    # The prefetched Locations and their ancestors, keyed by the normalized absolute URL identifying each (see
    # ResourceIdentity), or by `Location/id` when the request gives nothing to make one from.
    def prefetched_locations_and_parents_hash
      prefetched_location_bundle&.entry&.each_with_object({}) do |entry, hash|
        add_location_to_hash(entry.resource, hash, entry.fullUrl.presence)
      end
    end

    # A parent is identified by the URL it was read from, so its own `partOf` resolves against the
    # server it came from.
    def add_location_to_hash(location, location_hash, identity = nil)
      return unless location.is_a?(FHIR::Location) && location.id.present?

      identity = ResourceIdentity.normalized_url(identity || location_identity(location))
      return if location_hash.key?(identity)

      location_hash[identity] = location
      parent_reference = resolved_reference(location.partOf&.reference, identity)
      return if parent_reference.blank?

      parent_location = fetch_reference(parent_reference,
                                        additional_tag: PARENT_LOCATION_FETCH_TAG,
                                        parse_as_fhir: true)
      add_location_to_hash(parent_location, location_hash, parent_reference)
    end

    # A Location given without a fullUrl has no identity, so it is keyed by `Location/id`.
    def location_identity(location)
      "Location/#{location.id}"
    end
  end
end
