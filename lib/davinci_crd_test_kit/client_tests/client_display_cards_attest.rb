require_relative '../urls'

module DaVinciCRDTestKit
  class ClientCardDisplayAttest < Inferno::Test
    include URLs

    id :crd_card_display_attest_test
    title 'Check that Cards returned are displayed to the user'

    input :selected_response_types,
          type: 'checkbox'

    def format_selected_response_types
      selected_response_types
        .map do |response_type|
        response_type_string =
          response_type.split('_')
            .map(&:capitalize)
            .join(' ')
            .prepend('- ')
            .sub('Smart', 'SMART')
            .sub('Create Update', 'Create/Update')
            .sub('Companions Prerequisites', 'Companions/Prerequisites')
        response_type_string
      end
        .join("\n")
    end

    run do
      identifier = SecureRandom.hex(32)
      wait(
        identifier:,
        message: <<~MESSAGE
          **Card Display Attestation**:

          I attest that the following CDS response types were returned and that the client system displays
          each of the CDS Service Cards to the user:

          #{format_selected_response_types}

          [Click here](#{resume_pass_url}?token=#{identifier}) if the above statement is **true**.

          [Click here](#{resume_fail_url}?token=#{identifier}) if the above statement is **false**.
        MESSAGE
      )
    end
  end
end
