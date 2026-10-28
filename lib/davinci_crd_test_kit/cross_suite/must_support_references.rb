require 'inferno'
require_relative 'must_support_slice_matching'
require_relative 'profile_metadata'

module DaVinciCRDTestKit
  # Finds the references held in the must support Reference elements of a CRD profile. Used both
  # while a hook request is being processed, to read the referenced resources from the CRD client's
  # FHIR server, and afterwards, to check that those references resolved.
  module MustSupportReferences
    # Walks a resource with the navigation the must support assessment uses, so that slice paths
    # such as `participant:Patient.actor` pick out the same elements here as they do there.
    class Navigator
      include Inferno::DSL::FHIRResourceNavigation
      include MustSupportSliceMatching

      attr_reader :metadata

      def initialize(metadata)
        @metadata = metadata
      end

      # Every reference at the path, including logical ones carrying just an identifier or a display.
      def references(resource, path)
        resolve_path(resource, path).select { |value| value.is_a?(FHIR::Reference) }
      end

      # Only literal references can be resolved, so those carrying just an identifier or a display
      # are left out.
      def literal_references(resource, path)
        references(resource, path).select { |reference| reference.reference.present? }
      end
    end

    BASE_DEFINITION_PREFIX = 'http://hl7.org/fhir/StructureDefinition/'.freeze

    module_function

    def reference_elements(metadata)
      Array(metadata&.must_supports&.dig(:elements)).select { |element| Array(element[:types]).include?('Reference') }
    end

    # The resource type a base FHIR resource definition describes, or nil for any other profile.
    # Base definitions have no generated metadata, so their type is read from the URL.
    def base_resource_type(target_profile)
      url = target_profile.to_s.split('|').first.to_s
      url.delete_prefix(BASE_DEFINITION_PREFIX) if url.start_with?(BASE_DEFINITION_PREFIX)
    end
  end
end
