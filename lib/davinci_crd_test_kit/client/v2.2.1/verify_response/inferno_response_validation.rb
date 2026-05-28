require_relative '../../../cross_suite/cards_validation'
require_relative '../../../cross_suite/response_logical_model_validation'
require_relative '../../tagged_request_load_helper'

module DaVinciCRDTestKit
  module V221
    class InfernoResponseValidationTest < Inferno::Test
      include CardsValidation
      include ResponseLogicalModelValidation
      include DaVinciCRDTestKit::TaggedRequestLoadHelper

      title 'Hook responses have the correct structure and content'
      description %(
        During this test, Inferno will verify that each hook response built by Inferno's simulated CRD servers
        and returned to the client conforms to CDS Hooks and CRD requirements. These responses must be conformant
        for the client to demonstrate its ability to accept and process valid CRD responses.

        If this test fails when the tester provided a custom response template, adjust the
        provided template and the submitted requests so that the response built by Inferno
        is conformant. If this test fails when Inferno mocked the response based on selected
        card types, first ensure that the client's request is conformant. If the request is conformant
        but Inferno's response(s) are still not conformant, please report this failure to the
        Inferno team via [GitHub Issues](https://github.com/inferno-framework/davinci-crd-test-kit/issues).
        For more details on how Inferno builds responses, see the
        [Controlling Simulated Responses](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses)
        section of the [CRD Test Kit Wiki](https://github.com/inferno-framework/davinci-crd-test-kit/wiki).
      )
      id :crd_v221_inferno_response_validation
      simulation_verification

      verifies_requirements 'cds-hooks_3.0.0-ballot@3', 'cds-hooks_3.0.0-ballot@222', 'cds-hooks_3.0.0-ballot@223',
                            'cds-hooks_3.0.0-ballot@224'

      input :custom_response_template, optional: true

      def response_label(index = nil)
        response_type = (custom_response_template.present? ? 'Custom built' : 'Mocked')
        "#{response_type} response#{" #{index}" if index.present?}"
      end

      def validate_card_summaries(cards)
        return unless cards.is_a?(Array)

        cards.each { |card| card_summary_check(card) if card.is_a?(Hash) }
      end

      run do
        load_hook_requests

        skip_if request.blank?, "No #{response_label.downcase}s to verify."

        entity_validated = false
        requests.each_with_index do |request, index|
          response_hash = JSON.parse(request.response_body)
          request_hash = JSON.parse(request.request_body)

          next unless response_hash['cards'].present? || response_hash['systemActions'].present?

          entity_validated = true
          validate_card_summaries(response_hash['cards'])
          perform_response_logical_model_validation(response_hash['cards'],
                                                    response_hash['systemActions'],
                                                    request_hash,
                                                    index,
                                                    '2.2.1')
        rescue JSON::ParserError
          next
        end

        skip_if !entity_validated,
                "No #{response_label.downcase} cards or system actions to verify returned by Inferno."

        no_error_validation("Invalid Inferno #{response_label.downcase}(s). See Messages for details.")
      end
    end
  end
end
