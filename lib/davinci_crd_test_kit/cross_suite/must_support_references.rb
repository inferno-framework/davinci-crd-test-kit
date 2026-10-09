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

      # Only literal references can be resolved, so those carrying just an identifier or a display
      # are left out.
      def literal_references(resource, path)
        resolve_path(resource, path).select { |value| value.is_a?(FHIR::Reference) && value.reference.present? }
      end
    end

    module_function

    def reference_elements(metadata)
      Array(metadata&.must_supports&.dig(:elements)).select { |element| Array(element[:types]).include?('Reference') }
    end
  end
end
