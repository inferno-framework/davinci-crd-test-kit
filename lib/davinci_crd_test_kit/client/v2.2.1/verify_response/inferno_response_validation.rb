require_relative '../../../cross_suite/cards_validation'
require_relative '../../../cross_suite/cards_logical_model_validation'
require_relative '../../tagged_request_load_helper'

module DaVinciCRDTestKit
  module V221
    class InfernoResponseValidationTest < Inferno::Test
      include CardsValidation
      include CardsLogicalModelValidation
      include DaVinciCRDTestKit::TaggedRequestLoadHelper

      title 'Inferno CDS Service Response is Conformant'
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
      id :crd_v221_inferno_response_validation
      simulation_verification

      verifies_requirements 'cds-hooks_3.0.0-ballot@3', 'cds-hooks_3.0.0-ballot@222', 'cds-hooks_3.0.0-ballot@223',
                            'cds-hooks_3.0.0-ballot@224'

      input :custom_response_template, optional: true

      def response_label(index = nil)
        response_type = (custom_response_template.present? ? 'Custom built' : 'Mocked')
        "#{response_type} response#{index.present? ? " #{index}" : ''}"
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

          next unless response_hash['cards'].present? || response_hash['systemActions'].present?

          entity_validated = true
          validate_card_summaries(response_hash['cards'])
          perform_cards_logical_model_validation(response_hash['cards'], response_hash['systemActions'], index)
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
