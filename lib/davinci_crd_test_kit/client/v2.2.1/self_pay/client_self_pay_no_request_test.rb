require_relative '../../tagged_request_load_helper'

module DaVinciCRDTestKit
  module V221
    class ClientSelfPayNoRequestTest < Inferno::Test
      include DaVinciCRDTestKit::TaggedRequestLoadHelper

      id :crd_v221_client_self_pay_no_request
      title 'Client does not invoke hooks during self-pay workflows'
      description %(
        The CRD IG [requires](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/deviations.html#ci-c-dev-26)
        that client systems only invoke hooks on payer services where the patient record indicates
        active coverage with the payer associated with the service and where there is no recorded
        indication the patient intends to bypass insurance coverage, i.e., the service or product
        is not flagged as 'self-pay'. During this test, Inferno verifies that the client did not
        make any hook requests when the tester performed a self-pay workflow during the
        previous test.
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@dev-26'

      run do
        self_pay_requests = load_interaction_group_requests

        assert self_pay_requests.blank?,
               'Inferno incorrectly received a hook request for a service marked as self-pay.'
      end
    end
  end
end
