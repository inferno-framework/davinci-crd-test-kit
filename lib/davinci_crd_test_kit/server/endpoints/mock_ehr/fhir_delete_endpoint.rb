require_relative 'fhir_request_handler'

module DaVinciCRDTestKit
  module MockEHR
    class FHIRDeleteEndpoint < Inferno::DSL::SuiteEndpoint
      include FHIRRequestHandler

      def make_response
        prepare_response
        return unless mock_ehr_bundle_present?
        return unless resource_type_present?
        return unless resource_id_present?

        remove_target_resource_from_bundle

        response.status = 204 # NO CONTENT
      rescue StandardError => e
        return_unhandled_error(e)
      end
    end
  end
end
