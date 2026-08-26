module DaVinciCRDTestKit
  # Serve a fixed coverage information response carrying content that clients are not expected to recognize
  module UnknownContentServiceResponse
    def build_unknown_content_hook_response
      response_body = { 'cards' => [] }
      system_actions = coverage_information_system_actions

      if system_actions.present?
        response_body['systemActions'] = system_actions
        add_unknown_action_element(response_body)
      else
        create_missing_coverage_information_message
      end

      add_unknown_extension(response_body)
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
