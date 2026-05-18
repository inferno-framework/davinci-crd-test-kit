require_relative '../../../cross_suite/tags'
require_relative '../../tagged_request_load_helper'

module DaVinciCRDTestKit
  module V221
    class ClientLocationAddressPropagationTest < Inferno::Test
      include TaggedRequestLoadHelper

      title 'Client propagates addresses to child Location resources'
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

        prefetched_location_hash.each_value do |location|
          check_location_address_propagation(location)
        end

        assert_no_error_messages('Address propagation issues found. See Messages for details.')
      end

      # checks that the location has an address if a parent also has an address
      def check_location_address_propagation(location, root_id = location.id)
        return if location.address.present?
        return unless location.partOf.present? && location.partOf.reference.present?

        parent = prefetched_location_hash[location.partOf.reference]
        parent = fetched_location_hash[location.partOf.reference] unless parent.present?
        if parent.present?
          check_location_conformance(parent, root_id)
          if parent.address.present?
            add_message('error', "Address missing on prefetched 'Location/#{root_id}': " \
                                 "parent 'Location/#{parent.id}' has an address.")
          else
            check_location_address_propagation(parent, root_id)
          end
        else
          add_message('error', "Unable to check address propagation prefetched 'Location/#{root_id}': " \
                               "`partOf` reference '#{location.partOf.reference}' could not be fetched.")
        end

        nil
      end

      # skip profile check if in the prefetch hash (done elsewhere) or already checked
      def check_location_conformance(location, root_id)
        key = "Location/#{location.id}"
        return if prefetched_location_hash.key?(key) || fetched_locations_checked_for_conformance.key?(key)

        fetched_locations_checked_for_conformance[key] = location
        validator_response_details = []
        return if resource_is_valid?(resource: location, profile_url: 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-location|2.2.1',
                                     add_messages_to_runnable: false, validator_response_details:)

        message_prefix = "Parent of prefetched 'Location/#{root_id}'"
        add_message('error', "Location/#{location.id}: #{message_prefix} does not conform to the CRD Location profile.")
        validator_response_details.each { |issue| add_message(issue.severity, "(#{message_prefix}) #{issue.message}") }
      end

      def fetched_locations_checked_for_conformance
        @fetched_locations_checked_for_conformance ||= {}
      end

      def loaded_requests
        @loaded_requests ||= requests_to_analyze
      end

      def prefetched_location_hash
        @prefetched_location_hash ||= build_prefetched_locations_hash
      end

      def build_prefetched_locations_hash
        loaded_requests.each_with_object({}) do |request, location_hash|
          request_body = JSON.parse(request.request_body)
          next unless request_body.is_a?(Hash)

          prefetched_location_bundle = extract_prefetched_location_bundle(request_body)
          next unless prefetched_location_bundle.present?

          prefetched_location_bundle.entry.each do |entry|
            add_location_to_hash(entry.resource, location_hash)
          end
        rescue JSON::ParserError
          next
        end
      end

      def extract_prefetched_location_bundle(request_body)
        locations_data = request_body.dig('prefetch', 'locations') || request_body.dig('prefetch', 'locs')
        locations = FHIR.from_contents(locations_data.to_json) if locations_data.present?
        return locations if locations.is_a?(FHIR::Bundle)
        return nil unless locations.is_a?(FHIR::Location)

        FHIR::Bundle.new({ entry: [FHIR::Bundle::Entry.new({ resource: locations })] })
      end

      def fetched_location_hash
        @fetched_location_hash ||= build_fetched_locations_hash
      end

      def build_fetched_locations_hash
        load_tagged_requests(PARENT_LOCATION_FETCH_TAG, DATA_FETCH_TAG).each_with_object({}) do |request, location_hash|
          add_location_to_hash(FHIR.from_contents(request.response_body), location_hash)
        rescue JSON::ParserError
          next
        end
      end

      def add_location_to_hash(location, location_hash)
        return unless location.is_a?(FHIR::Location) && location.id.present?

        relative_reference = "#{location.resourceType}/#{location.id}"
        return if location_hash.key?(relative_reference)

        location_hash[relative_reference] = location
      end
    end
  end
end
