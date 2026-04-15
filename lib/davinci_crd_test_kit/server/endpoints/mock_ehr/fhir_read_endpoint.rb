require_relative 'fhir_request_handler'

module DaVinciCRDTestKit
  module MockEHR
    class FHIRReadEndpoint < Inferno::DSL::SuiteEndpoint
      include FHIRRequestHandler

      def make_response
        prepare_response
        return unless mock_ehr_bundle_present?
        return unless resource_type_present?
        return unless resource_id_present?
        return unless target_resource_present?

        return_target_resource
      rescue StandardError => e
        return_unhandled_error(e)
      end
    end
  end
end
