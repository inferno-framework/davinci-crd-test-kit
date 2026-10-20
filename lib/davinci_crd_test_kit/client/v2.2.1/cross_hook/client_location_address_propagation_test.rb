require_relative '../../../cross_suite/resource_identity'
require_relative '../../../cross_suite/tags'
require_relative '../../tagged_request_load_helper'

module DaVinciCRDTestKit
  module V221
    class ClientLocationAddressPropagationTest < Inferno::Test
      include TaggedRequestLoadHelper

      title 'CRD client propagates addresses to child Location resources'
      id :crd_v221_client_location_address_propagation
      description <<~DESCRIPTION
        The CRD IG requires that ([prof-13](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-location.html#ci-c-prof-13))
        > If a Location is a fine-grained location such as a bed or room,
        > the address SHALL be propagated from the higher-level location it is part of.

        During this test, Inferno will verify that for all locations provided as a prefetched resource
        and their parents (via the `partOf` element), if the Location has a parent Location (`partOf`) and
        that parent Location's `address` element is populated, then the child Location's `address` element
        must also be populated. The test will not verify the details of the address because Inferno cannot
        easily determine whether a particular location is "fine-grained" so as to need the same address.
        By requiring just population, this check allows for refinement of the address in the child
        in addition to straight propagation.
      DESCRIPTION

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@prof-13'

      run do
        skip_if loaded_requests.blank?, 'No hook requests received.'
        pass_if prefetched_location_hash.blank?, 'No Location resources in use, so verification not needed.'

        prefetched_location_hash.each do |identity, location|
          check_location_address_propagation(location, identity)
        end

        assert_no_error_messages('Address propagation issues found. See Messages for details.')
      end

      # checks that the location has an address if a parent also has an address
      def check_location_address_propagation(location, identity, root_id = location.id)
        return if location.address.present?
        return unless location.partOf.present? && location.partOf.reference.present?

        parent_identity = parent_identity(location.partOf.reference, identity)
        parent = prefetched_location_hash[parent_identity] || fetched_location_hash[parent_identity]
        if parent.present?
          check_location_conformance(parent, parent_identity, root_id)
          if parent.address.present?
            add_message('error', "Address missing on prefetched 'Location/#{root_id}': " \
                                 "parent 'Location/#{parent.id}' has an address.")
          else
            check_location_address_propagation(parent, parent_identity, root_id)
          end
        else
          add_message('error', "Unable to check address propagation prefetched 'Location/#{root_id}': " \
                               "`partOf` reference '#{location.partOf.reference}' could not be fetched.")
        end

        nil
      end

      # The identity of the Location a `partOf` reference names, resolved against the base of the
      # Location holding it, following the FHIR rules for resolving references. As when Inferno read
      # the parent during the hook request, a prefetched Location whose identity is not a RESTful URL,
      # such as a `urn:uuid:` fullUrl, falls back to its request's FHIR server. A reference with no
      # absolute form is used as given.
      def parent_identity(reference, child_identity)
        base = ResourceIdentity.base_for(child_identity) || prefetched_location_fhir_servers[child_identity]
        ResourceIdentity.normalized_url(ResourceIdentity.absolute_reference(reference, base)) || reference
      end

      # skip profile check if in the prefetch hash (done elsewhere) or already checked
      def check_location_conformance(location, identity, root_id)
        return if prefetched_location_hash.key?(identity) || fetched_locations_checked_for_conformance.key?(identity)

        fetched_locations_checked_for_conformance[identity] = location
        validator_response_details = []
        return if resource_is_valid?(resource: location, profile_url: 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-location|2.2.1',
                                     add_messages_to_runnable: false, validator_response_details:)

        message_prefix = "Parent of prefetched 'Location/#{root_id}'"
        add_message('error', "Location/#{location.id}: #{message_prefix} does not conform to the CRD Location profile.")
        validator_response_details.each do |issue|
          next if issue.filtered

          add_message(issue.severity, "(#{message_prefix}) #{issue.message}")
        end
      end

      def fetched_locations_checked_for_conformance
        @fetched_locations_checked_for_conformance ||= {}
      end

      def loaded_requests
        @loaded_requests ||= load_requests_for_cross_hook_analysis
      end

      # The prefetched Locations of every hook request, keyed by the normalized absolute URL identifying each (see
      # ResourceIdentity), or by `Location/id` when the request gives nothing to make one from.
      def prefetched_location_hash
        @prefetched_location_hash ||= build_prefetched_locations_hash
      end

      def build_prefetched_locations_hash
        loaded_requests.each_with_object({}) do |request, location_hash|
          request_body = JSON.parse(request.request_body)
          next unless request_body.is_a?(Hash)

          add_prefetched_locations(request_body, location_hash)
        rescue JSON::ParserError
          next
        end
      end

      def add_prefetched_locations(request_body, location_hash)
        fhir_server = ResourceIdentity.fhir_server_base(request_body)
        extract_prefetched_location_bundle(request_body)&.entry&.each do |entry|
          location = entry.resource
          next unless location.is_a?(FHIR::Location) && location.id.present?

          add_prefetched_location(location_hash, prefetched_location_identity(entry, fhir_server), location,
                                  fhir_server)
        end
      end

      def add_prefetched_location(location_hash, identity, location, fhir_server)
        location_hash[identity] ||= location
        prefetched_location_fhir_servers[identity] ||= fhir_server
      end

      # The FHIR server of the hook request that carried each prefetched Location, by identity.
      def prefetched_location_fhir_servers
        @prefetched_location_fhir_servers ||= {}
      end

      # A Location given without a fullUrl is taken to be on the request's FHIR server.
      def prefetched_location_identity(entry, fhir_server)
        identity = entry.fullUrl.presence || ResourceIdentity.restful_identity(entry.resource, fhir_server)
        ResourceIdentity.normalized_url(identity) || "Location/#{entry.resource.id}"
      end

      def extract_prefetched_location_bundle(request_body)
        locations_data = request_body.dig('prefetch', 'locations') || request_body.dig('prefetch', 'locs')
        locations = FHIR.from_contents(locations_data.to_json) if locations_data.present?
        return locations if locations.is_a?(FHIR::Bundle)
        return nil unless locations.is_a?(FHIR::Location)

        FHIR::Bundle.new({ entry: [FHIR::Bundle::Entry.new({ resource: locations })] })
      end

      # The parent Locations read during hook requests, keyed by the normalized URL each was read from. A read
      # only counts when it returned the Location that URL names.
      def fetched_location_hash
        @fetched_location_hash ||= build_fetched_locations_hash
      end

      def build_fetched_locations_hash
        load_tagged_requests(PARENT_LOCATION_FETCH_TAG).each_with_object({}) do |request, location_hash|
          location = FHIR.from_contents(request.response_body)
          next unless location.is_a?(FHIR::Location) && ResourceIdentity.names?(request.url, location)

          location_hash[ResourceIdentity.normalized_url(request.url)] ||= location
        rescue JSON::ParserError
          next
        end
      end
    end
  end
end
