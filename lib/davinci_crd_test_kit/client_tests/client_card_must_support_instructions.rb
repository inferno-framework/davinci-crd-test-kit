require_relative '../cards_identification'

module DaVinciCRDTestKit
  class ClientCardMustSupportInstructionsTest < Inferno::Test
    include CardsIdentification

    title 'Instructions Card Support'
    id :crd_client_card_must_support_instructions
    description <<~DESCRIPTION
      Checks that the client demonstrated support for the [Instructions](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#external-reference)
      card type. At least one hook invocation performed during this test session must have returned an Instructions card.

      If this test fails, adjust the [cards returned by Inferno's simulated CRD Server](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses)
      and the hook requests made by the client such that an Instructions card is returned and support for it is demonstrated.
    DESCRIPTION

    ALL_HOOKS = [
      APPOINTMENT_BOOK_TAG,
      ENCOUNTER_START_TAG,
      ENCOUNTER_DISCHARGE_TAG,
      ORDER_DISPATCH_TAG,
      ORDER_SELECT_TAG,
      ORDER_SIGN_TAG
    ].freeze

    def configured_hook_name
      config.options[:hook_name]
    end

    def crd_test_group
      config.options[:crd_test_group]
    end

    def tags_to_load(hook_name)
      crd_test_group.present? ? [hook_name, crd_test_group] : [hook_name]
    end

    def requests_to_analyze
      if configured_hook_name.present?
        load_requests_for_tags(tags_to_load(configured_hook_name))
      else
        ALL_HOOKS.each_with_object([]) do |hook_name, request_list|
          request_list.concat(load_requests_for_tags(tags_to_load(hook_name)))
        end
      end
    end

    def load_requests_for_tags(tags_to_load)
      load_tagged_requests(*tags_to_load)
    end

    run do
      loaded_requests = requests_to_analyze
      sorted_cards = sorted_cards_from_requests(loaded_requests)

      assert sorted_cards['cards'][INSTRUCTIONS_RESPONSE_TYPE].present?,
             'Instructions card support not demonstrated.'
    end
  end
end
