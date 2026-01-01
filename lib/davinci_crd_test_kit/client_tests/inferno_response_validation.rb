module DaVinciCRDTestKit
  class InfernoResponseValidationTest < Inferno::Test
    include CardsValidation

    title 'Inferno CDS Service Response is Valid'
    description %(
      This test verifies that each service response built by Inferno and returned to the client is conformant.
      These responses must be conformant for the client to demonstrate its ability to accept CDS Service responses.

      If this test fails when a custom response was provided, adjust the custom response template
      and the submitted requests so that the response built by Inferno is conformant. See
      the documentation for details on how Inferno builds a response from the provided
      custom template.

      If this test fails when Inferno mocked the response based on selected card types, please
      report this failure to the Inferno team via github issues.
    )
    id :crd_inferno_response_validation

    input :custom_response_template, optional: true

    def hook_name
      config.options[:hook_name]
    end

    def crd_test_group
      config.options[:crd_test_group]
    end

    def tags_to_load
      crd_test_group.present? ? [hook_name, crd_test_group] : [hook_name]
    end

    def response_label(index = nil)
      response_type = (custom_response_template.present? ? 'Custom built' : 'Mocked')
      "#{response_type} response#{index.present? ? " #{index}" : ''}"
    end

    def valid_cards
      @valid_cards ||= []
    end

    def validate_system_actions(system_actions)
      return if system_actions.nil?

      system_actions.each do |action|
        action_fields_validation(action)
      end
    end

    run do
      load_tagged_requests(*tags_to_load)

      skip_if request.blank?, "No #{response_label.downcase}s to verify."

      entity_validated = false
      requests.each_with_index do |request, index|
        response_hash = JSON.parse(request.response_body)

        next unless response_hash['cards'].present? || response_hash['systemActions'].present?

        entity_validated = true
        perform_cards_validation(response_hash['cards'], response_hash['systemActions'].present?, index)
        validate_system_actions(response_hash['systemActions'])
      rescue JSON::ParserError
        next
      end

      skip_if !entity_validated, "No #{response_label.downcase} cards or system actions to verify returned by Inferno."

      no_error_validation("Invalid Inferno #{response_label.downcase}(s). Check messages for issues found.")
    end
  end
end
