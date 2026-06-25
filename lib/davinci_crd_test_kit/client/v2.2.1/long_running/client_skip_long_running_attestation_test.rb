require_relative '../client_urls'
require_relative '../../tagged_request_load_helper'

module DaVinciCRDTestKit
  module V221
    class ClientSkipLongRunningAttestationTest < Inferno::Test
      include ClientURLs
      include DaVinciCRDTestKit::TaggedRequestLoadHelper

      id :crd_v221_client_skip_long_running_attestation_test
      title 'Client allows the user to continue their workflow during long-running requests'
      description %(
        The CRD IG [requires](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/foundation.html#ci-c-found-6)
        that client systems not block their users while waiting for long-running CRD Hook calls.
        During this test, the tester will confirm that the client system allows users to continue
        with their workflow when a hook request is long-running. This could be accomplished,
        for example, by providing a bypass/continue mechanism when a CRD server is taking too long
        to respond, or by always running hooks requests in the background and notifying users when they
        return pertinent information.
      )
      attestation

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@found-6'

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

            I attest that the user was able to continue their workflow
            while waiting for the long-running hook request to return a response:

            [Click here](#{attest_true_url}) if the above statement is **true**.

            [Click here](#{attest_false_url}) if the above statement is **false**.
          MESSAGE
        )
      end
    end
  end
end
