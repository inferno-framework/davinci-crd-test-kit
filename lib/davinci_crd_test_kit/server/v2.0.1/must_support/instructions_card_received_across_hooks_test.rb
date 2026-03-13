require_relative '../../server_test_helper'

module DaVinciCRDTestKit
  module V201
    class InstructionsCardReceivedAcrossHooksTest < Inferno::Test
      include DaVinciCRDTestKit::ServerTestHelper

      title 'Valid Instructions cards received across all hooks'
      id :crd_v201_valid_instructions_card_received_across_hooks
      description %(
        This test validates that a valid [Instructions card](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#instructions)
        was received across all hooks responses.

        The test will be skipped if no valid Instructions cards are returned across all hooks.
      )

      run do
        verify_at_least_one_test_passes(
          self.class.parent.parent.groups,
          'crd_valid_instructions_card_received',
          'None of the hooks invoked returned a valid Instructions card.',
          'across_hooks'
        )
      end
    end
  end
end
