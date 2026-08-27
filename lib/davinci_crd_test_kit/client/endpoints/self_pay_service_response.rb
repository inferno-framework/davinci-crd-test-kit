module DaVinciCRDTestKit
  # Serve a fixed coverage information response for hook requests that self-pay workflows should not make
  module SelfPayServiceResponse
    def build_self_pay_hook_response
      response_body = { 'cards' => [] }
      system_actions = self_pay_coverage_system_actions

      if system_actions.present?
        response_body['systemActions'] = system_actions
      else
        create_self_pay_missing_coverage_message
      end

      response_body
    end

    def self_pay_coverage_system_actions
      return if context.blank? || patient_coverage.blank?

      create_coverage_extension_system_actions(patient_coverage.id)
    end

    def create_self_pay_missing_coverage_message
      Inferno::Repositories::Messages.new.create(
        result_id: result.id,
        type: 'warning',
        message: %(Unable to return a coverage information system action for the #{requested_hook} hook)
      )
    end
  end
end
