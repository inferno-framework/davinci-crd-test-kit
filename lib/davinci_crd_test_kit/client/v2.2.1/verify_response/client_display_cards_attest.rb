require_relative '../client_urls'
require_relative '../../../cross_suite/cards_identification'
require_relative '../../tagged_request_load_helper'

module DaVinciCRDTestKit
  module V221
    class ClientCardDisplayAttest < Inferno::Test
      include ClientURLs
      include CardsIdentification
      include DaVinciCRDTestKit::TaggedRequestLoadHelper

      id :crd_v221_card_display_attest_test
      title 'Client displays returned decision support details to the user'
      description %(
        During this test, the tester will confirm that the received cards and actions in the
        hook responses have been displayed or otherwise made available to users of the client system
        in an appopriate way that allows for consideration and action if warranted.
      )
      attestation

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@resp-49'

      def responded_card_types
        @responded_card_types ||= list_card_types_in_requests(requests)
      end

      def format_responded_response_types(response_types = responded_card_types)
        response_types
          .map do |response_type|
            DaVinciCRDTestKit::CardsIdentification.humanize_response_type(response_type)
              .prepend('- ')
              .sub(' Card', '')
              .sub(' Action', '')
          end.join("\n")
      end

      def format_responded_card_types
        @format_responded_card_types ||=
          format_responded_response_types(responded_card_types.select do |type|
            type.end_with?('_card')
          end)
      end

      def format_responded_system_action_types
        @format_responded_system_action_types ||=
          format_responded_response_types(responded_card_types.select do |type|
            type.end_with?('_action')
          end)
      end

      CARD_AND_SYSTEM_ACTION_DISPLAY_PREFIX = "\n\n By attesting true, ".freeze
      CARD_AND_SYSTEM_ACTION_DISPLAY_CLAUSE_PREFIX = 'you confirm that the following '.freeze
      CARD_AND_SYSTEM_ACTION_DISPLAY_CLAUSE_CONNECTOR = "\n\n Additionally, ".freeze
      CARD_AND_SYSTEM_ACTION_DISPLAY_CARD_CLAUSE =
        'card types observed in Inferno\'s responses were displayed to users:'.freeze
      CARD_AND_SYSTEM_ACTION_DISPLAY_SYSTEM_ACTION_CLAUSE =
        'system action types observed in Inferno\'s responses were displayed to users ' \
        'through standard card display, icons, flyovers, or another alternate mechanism:'.freeze

      def card_and_system_action_details_display
        if format_responded_card_types.present? && format_responded_system_action_types.present?
          "#{CARD_AND_SYSTEM_ACTION_DISPLAY_PREFIX}#{CARD_AND_SYSTEM_ACTION_DISPLAY_CLAUSE_PREFIX}" \
            "#{CARD_AND_SYSTEM_ACTION_DISPLAY_CARD_CLAUSE}\n#{format_responded_card_types}" \
            "#{CARD_AND_SYSTEM_ACTION_DISPLAY_CLAUSE_CONNECTOR}#{CARD_AND_SYSTEM_ACTION_DISPLAY_CLAUSE_PREFIX}" \
            "#{CARD_AND_SYSTEM_ACTION_DISPLAY_SYSTEM_ACTION_CLAUSE}\n#{format_responded_system_action_types}"
        elsif format_responded_card_types.present?
          "#{CARD_AND_SYSTEM_ACTION_DISPLAY_PREFIX}#{CARD_AND_SYSTEM_ACTION_DISPLAY_CLAUSE_PREFIX}" \
            "#{CARD_AND_SYSTEM_ACTION_DISPLAY_CARD_CLAUSE}\n#{format_responded_card_types}"
        else
          "#{CARD_AND_SYSTEM_ACTION_DISPLAY_PREFIX}#{CARD_AND_SYSTEM_ACTION_DISPLAY_CLAUSE_PREFIX}" \
            "#{CARD_AND_SYSTEM_ACTION_DISPLAY_SYSTEM_ACTION_CLAUSE}\n#{format_responded_system_action_types}"
        end
      end

      output :attest_true_url
      output :attest_false_url

      run do
        load_interaction_group_requests
        skip_if responded_card_types.blank?, 'No responses sent to the client.'

        identifier = SecureRandom.hex(32)
        attest_true_url = "#{resume_pass_url}?token=#{identifier}"
        attest_false_url = "#{resume_fail_url}?token=#{identifier}"
        output(attest_true_url:)
        output(attest_false_url:)
        wait(
          identifier:,
          message: <<~MESSAGE
            **Card Display Attestation**:

            I attest that the simulated CRD responses returned by Inferno during this
            group were successfully processed by the client system and that they were
            made available to users of the system in an appropriate way that allowed for
            user review and action if warranted.

            #{card_and_system_action_details_display}

            [Click here](#{attest_true_url}) if the above statement is **true**.

            [Click here](#{attest_false_url}) if the above statement is **false**.
          MESSAGE
        )
      end
    end
  end
end
