require_relative 'fhir_request_handler'

module DaVinciCRDTestKit
  module MockEHR
    class FHIRCreateEndpoint < Inferno::DSL::SuiteEndpoint
      include FHIRRequestHandler

      def make_response
        prepare_response
        return unless mock_ehr_bundle_present?
        return unless resource_type_present?
        return unless provided_resource_valid?

        assign_id_to_provided_resource
        add_provided_resource_to_mock_ehr_bundle

        return_provided_resource
      rescue StandardError => e
        return_unhandled_error(e)
      end
    end
  end
end
