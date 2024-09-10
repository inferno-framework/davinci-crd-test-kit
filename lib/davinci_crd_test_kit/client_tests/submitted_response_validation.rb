module DaVinciCRDTestKit
  class SubmittedResponseValidationTest < Inferno::Test
    include CardsValidation

    title 'Custom CDS Service Response is valid'
    id :crd_submitted_response_validation

    input :custom_response, optional: true

    def hook_name
      config.options[:hook_name]
    end

    def response_label(_index = nil)
      'Custom response'
    end

    def valid_cards
      @valid_cards ||= []
    end

    def validate_system_actions(system_actions)
      return if system_actions.blank?

      system_actions.each do |action|
        action_fields_validation(action)
      end
    end

    run do
      omit_if custom_response.blank?, 'Custom response was not provided'

      assert_valid_json custom_response

      custom_response_hash = JSON.parse(custom_response)

      perform_cards_validation(custom_response_hash['cards'])

      validate_system_actions(custom_response_hash['systemActions'])
    end
  end
end
