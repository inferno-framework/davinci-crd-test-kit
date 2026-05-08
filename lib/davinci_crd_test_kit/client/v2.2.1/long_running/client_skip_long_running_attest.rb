require_relative '../client_urls'
require_relative '../../tagged_request_load_helper'

module DaVinciCRDTestKit
  module V221
    class ClientSkipLongRunningAttestationTest < Inferno::Test
      include ClientURLs
      include DaVinciCRDTestKit::TaggedRequestLoadHelper

      id :crd_v221_client_skip_long_running_attestation_test
      title 'Attest that the user was able to skip the long-running request'
      description %(
        Since Inferno has no way to evaluate the client's UI, testers must manually
        verify and atttest that users of the system had an option to continue with their
        workflow while the system was waiting for a long-running hook
        request to return.
      )

      output :attest_true_url
      output :attest_false_url

      run do
        long_running_requests = load_hook_requests
        skip_if long_running_requests.blank?, 'Long-running requests not demonstrated: ' \
                                              'no hook requests sent during the previous wait.'

        identifier = SecureRandom.hex(32)
        attest_true_url = "#{resume_pass_url}?token=#{identifier}"
        attest_false_url = "#{resume_fail_url}?token=#{identifier}"
        output(attest_true_url:)
        output(attest_false_url:)
        wait(
          identifier:,
          message: <<~MESSAGE
            **Long Running Request Attestation**:

            I attest that the user had the option to continue their workflow
            instead of waiting for the long-running hook request to complete:

            [Click here](#{attest_true_url}) if the above statement is **true**.

            [Click here](#{attest_false_url}) if the above statement is **false**.
          MESSAGE
        )
      end
    end
  end
end
