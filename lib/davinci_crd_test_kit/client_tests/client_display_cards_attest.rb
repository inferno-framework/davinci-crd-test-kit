require_relative '../urls'
require_relative '../cards_identification'

module DaVinciCRDTestKit
  class ClientCardDisplayAttest < Inferno::Test
    include URLs
    include CardsIdentification

    id :crd_card_display_attest_test
    title 'Check that returned decision support details are displayed to the user'
    description %(
      Since Inferno has no way to evaluate the client's UI, testers must manually
      verify that the cards and system actions returned by Inferno are presented
      to the user in an appopriate way that allows for consideration and action
      if warranted.
    )

    def hook_name
      config.options[:hook_name]
    end

    def crd_test_group
      config.options[:crd_test_group]
    end

    def tags_to_load
      crd_test_group.present? ? [hook_name, crd_test_group] : [hook_name]
    end

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

    run do
      load_tagged_requests(*tags_to_load)

      skip_if request.blank?, 'No reponses sent to the client.'

      identifier = SecureRandom.hex(32)
      wait(
        identifier:,
        message: <<~MESSAGE
          **Approval Workflow Test**:

          I attest that the following CDS response types returned were processed by the
          client system and displayed to the user:

          #{format_responded_response_types}

          [Click here](#{resume_pass_url}?token=#{identifier}) if the above statement is **true**.

          [Click here](#{resume_fail_url}?token=#{identifier}) if the above statement is **false**.
        MESSAGE
      )
    end
  end
end
