require_relative 'fhir_request_handler'

module DaVinciCRDTestKit
  module MockEHR
    class FHIRUpdateEndpoint < Inferno::DSL::SuiteEndpoint
      include FHIRRequestHandler

      def make_response
        prepare_response
        return unless mock_ehr_bundle_present?
        return unless resource_type_present?
        return unless resource_id_present?
        return unless provided_resource_valid?

        assign_id_to_provided_resource(target_id: resource_id)
        update_target_resource_in_mock_ehr_bundle

        return_provided_resource(status: nil) # status set in update_target_resource_in_mock_ehr_bundle
      rescue StandardError => e
        return_unhandled_error(e)
      end
    end
  end
end
