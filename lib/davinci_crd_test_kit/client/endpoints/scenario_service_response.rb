module DaVinciCRDTestKit
  # Serve fixed coverage information responses for hook requests made during scenario groups
  module ScenarioServiceResponse
    # coverage information carrying content that clients are not expected to recognize
    def build_unknown_content_hook_response
      response_body = build_coverage_information_hook_response
      add_unknown_action_element(response_body) if response_body['systemActions'].present?
      add_unknown_extension(response_body)
      response_body
    end

    def build_self_pay_hook_response
      build_coverage_information_hook_response
    end

    def build_coverage_information_hook_response
      response_body = { 'cards' => [] }
      system_actions = coverage_information_system_actions

      if system_actions.present?
        response_body['systemActions'] = system_actions
      else
        create_missing_coverage_information_message
      end

      response_body
    end

    def coverage_information_system_actions
      return if context.blank? || patient_coverage.blank?

      create_coverage_extension_system_actions(patient_coverage.id)
    end

    def random_element_name
      ('a'..'z').to_a.sample(16).join
    end

    # an element that is not part of the CDS Hooks action definition
    def add_unknown_action_element(response_body)
      element_name = random_element_name
      response_body['systemActions'].each { |action| action[element_name] = random_element_name }
    end

    # a CDS Hooks extension whose key is not defined by CRD or CDS Hooks
    def add_unknown_extension(response_body)
      response_body['extension'] = { random_element_name => random_element_name }
    end

    def create_missing_coverage_information_message
      Inferno::Repositories::Messages.new.create(
        result_id: result.id,
        type: 'warning',
        message: %(Unable to return a coverage information system action for the #{requested_hook} hook)
      )
    end
  end
end
