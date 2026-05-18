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
      title 'Client displays returned decision support details to the user (Attestation)'
      description %(
        During this test, the tester will confirm that the received cards and actions in the
        hook responses have been displayed or otherwise made available to users of the client system
        in an appopriate way that allows for consideration and action if warranted.
      )

      def responded_card_types
        list_card_types_in_requests(requests)
      end

      def format_responded_response_types
        responded_card_types
          .map do |response_type|
          response_type_string =
            response_type.split('_')
              .map(&:capitalize)
              .join(' ')
              .prepend('- ')
              .sub('Smart', 'SMART')
              .sub('Create Update', 'Create/Update')
              .sub('Companions Prerequisites', 'Companions/Prerequisites')
              .sub('Card', '(card)')
              .sub('Action', '(systemAction)')
          response_type_string
        end
          .join("\n")
      end

      output :attest_true_url
      output :attest_false_url

      run do
        load_hook_requests
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

            I attest that the following CRD response types returned by Inferno's simulated
            CRD servers were processed by the client system and displayed or otherwise made
            available to users of the client system in an appropriate way that allows for
            consideration and action if warranted:

            #{format_responded_response_types}

            [Click here](#{attest_true_url}) if the above statement is **true**.

            [Click here](#{attest_false_url}) if the above statement is **false**.
          MESSAGE
        )
      end
    end
  end
end
