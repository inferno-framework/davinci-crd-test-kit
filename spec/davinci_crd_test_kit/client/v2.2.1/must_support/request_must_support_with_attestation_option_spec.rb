require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.2.1/client_cross_hook_must_support_group'

RSpec.describe DaVinciCRDTestKit::V221::RequestMustSupportWithAttestationOption, :request do
  let(:suite_id) { 'crd_client_v221' }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite_id) }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:ig_version) { 'v2.2.1' }

  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client_v221" }
  let(:known_token) { 'abc123' }
  let(:attest_true_url) { "#{base_url}/resume_pass?token=#{known_token}" }
  let(:attest_false_url) { "#{base_url}/resume_fail?token=#{known_token}" }
  let(:receiving_result) { repo_create(:result, test_session_id: test_session.id) }
  let(:complete_service_request) do
    {
      resourceType: 'ServiceRequest',
      id: 'sr1',
      status: 'draft',
      intent: 'order',
      subject: { reference: 'Patient/p1' },
      identifier: [{ system: 'http://example.org', value: 'sr-1' }],
      doNotPerform: false,
      basedOn: [{ reference: 'ServiceRequest/sr0' }],
      contained: [{ resourceType: 'Practitioner', id: 'pr1' }],
      quantityQuantity: { value: 1 },
      reasonReference: [{ reference: 'Condition/c1' }],
      locationReference: [{ reference: 'Location/l1' }],
      performer: [{ reference: 'Practitioner/pr1' }],
      extension: [
        { url: 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information',
          extension: [{ url: 'coverage', valueReference: { reference: 'Coverage/c1' } }] }
      ],
      code: {
        coding: [{ system: 'http://snomed.info/sct', code: '1234' }],
        extension: [
          { url: 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-billing-options',
            valueCodeableConcept: { coding: [{ code: 'x' }] } }
        ]
      },
      performerType: {
        coding: [{ system: 'http://nucc.org/provider-taxonomy', code: '207Q00000X' }],
        extension: [
          { url: 'http://hl7.org/fhir/StructureDefinition/codeOptions',
            valueCodeableConcept: { coding: [{ code: 'y' }] } }
        ]
      },
      locationCode: [{ coding: [{ system: 'https://www.cms.gov/Medicare/Coding/place-of-service-codes',
                                  code: '11' }] }],
      reasonCode: [{ coding: [{ system: 'http://hl7.org/fhir/sid/icd-10-cm', code: 'A00' }] }]
    }
  end
  let(:service_request_test) { test_for([{ resource_type: 'ServiceRequest', profile_keys: ['service_request'] }]) }

  before { allow(SecureRandom).to receive(:hex).and_return(known_token) }

  def hook_request_body(context: {}, prefetch: {})
    { hook: 'order-sign', hookInstance: SecureRandom.uuid, context:, prefetch: }.to_json
  end

  def draft_orders(*resources)
    { draftOrders: { resourceType: 'Bundle', entry: resources.map { |one| { resource: one } } } }
  end

  def create_request(body)
    repo_create(:request, test_session_id: test_session.id, request_body: body, result: receiving_result,
                          tags: [DaVinciCRDTestKit::CROSS_HOOK_ANALYSIS_TAG])
  end

  def test_for(profiles)
    Class.new(described_class) do
      config(options: { ig_version: 'v2.2.1', profiles: })
    end
  end

  describe 'when no requests have been received' do
    it 'skips' do
      result = run(service_request_test)

      expect(result.result).to eq('skip')
      expect(result.result_message).to include('No hook requests received')
    end
  end

  describe 'when every must support element is observed' do
    before { create_request(hook_request_body(context: draft_orders(complete_service_request))) }

    it 'passes without waiting for an attestation' do
      result = run(service_request_test)

      expect(result.result).to eq('pass')
      expect(result.result_message).to include('All must support elements were observed')
    end

    it 'records no unobserved element messages' do
      result = run(service_request_test)
      messages = results_repo.current_results_for_test_session_and_runnables(
        test_session.id, [service_request_test]
      ).first.messages

      expect(messages.map(&:message)).to all(satisfy { |text| !text.match?(/Unobserved must support element/) })
      expect(result.result).to eq('pass')
    end
  end

  describe 'when some must support elements are unobserved' do
    let(:partial_service_request) { complete_service_request.except(:reasonReference, :locationReference) }

    before { create_request(hook_request_body(context: draft_orders(partial_service_request))) }

    it 'waits for an attestation naming the missing elements' do
      result = run(service_request_test)

      expect(result.result).to eq('wait')
      expect(result.result_message).to include('reasonReference')
      expect(result.result_message).to include('locationReference')
      expect(result.result_message).to include('does not capture')
    end

    it 'reports the number of instances it looked at' do
      result = run(service_request_test)

      expect(result.result_message).to include('observed 1 `ServiceRequest` instance')
    end

    it 'logs each unobserved element as an info message' do
      run(service_request_test)
      messages = results_repo.current_results_for_test_session_and_runnables(
        test_session.id, [service_request_test]
      ).first.messages

      expect(messages.map(&:message)).to include(
        a_string_matching(/Unobserved must support element for CRD Service Request: reasonReference/)
      )
    end

    it 'offers both attestation links as outputs' do
      result = run(service_request_test)
      outputs = result.outputs.to_h { |output| [output['name'], output['value']] }

      expect(outputs['attest_true_url']).to eq(attest_true_url)
      expect(outputs['attest_false_url']).to eq(attest_false_url)
    end

    it 'passes when the tester follows the attestation link' do
      result = run(service_request_test)
      expect(result.result).to eq('wait')

      get(attest_true_url)

      expect(results_repo.find(result.id).result).to eq('pass')
    end

    it 'fails when the tester declines the attestation' do
      result = run(service_request_test)
      expect(result.result).to eq('wait')

      get(attest_false_url)

      expect(results_repo.find(result.id).result).to eq('fail')
    end
  end

  describe 'when the resource type is not present at all' do
    before { create_request(hook_request_body(context: draft_orders(complete_service_request))) }

    it 'asks the tester to attest that the request type is unsupported' do
      result = run(test_for([{ resource_type: 'VisionPrescription', profile_keys: ['vision_prescription'] }]))

      expect(result.result).to eq('wait')
      expect(result.result_message).to include('did not observe any `VisionPrescription` resources')
      expect(result.result_message).to include('does **not** support')
    end
  end

  describe 'resource location within the request' do
    it 'finds resources carried only in prefetch' do
      create_request(hook_request_body(prefetch: { orders: complete_service_request }))

      expect(run(service_request_test).result).to eq('pass')
    end

    it 'finds resources carried only in context' do
      create_request(hook_request_body(context: draft_orders(complete_service_request)))

      expect(run(service_request_test).result).to eq('pass')
    end

    it 'pools instances across several requests so coverage can accumulate' do
      create_request(hook_request_body(context: draft_orders(complete_service_request.except(:reasonReference))))
      create_request(hook_request_body(context: draft_orders(complete_service_request.except(:performer))))

      expect(run(service_request_test).result).to eq('pass')
    end
  end

  describe 'a test covering several profiles at once' do
    before { create_request(hook_request_body(context: draft_orders(complete_service_request))) }

    it 'reports an absent type and an incomplete type in the same message' do
      result = run(test_for([
                              { resource_type: 'ServiceRequest', profile_keys: ['service_request'] },
                              { resource_type: 'Location', profile_keys: ['location'] }
                            ]))

      expect(result.result).to eq('wait')
      expect(result.result_message).to include('did not observe any `Location` resources')
    end
  end

  describe 'Appointment, which is checked against both profiles at once' do
    let(:appointment_test) do
      test_for([{ resource_type: 'Appointment', title: 'CRD Appointment',
                  profile_keys: %w[appointment_with_order appointment_without_order] }])
    end

    it 'reports elements required only by the with-order profile as unobserved' do
      appointment = { resourceType: 'Appointment', id: 'a1', status: 'booked',
                      participant: [{ status: 'accepted' }] }
      create_request(hook_request_body(context: { appointments: { resourceType: 'Bundle',
                                                                  entry: [{ resource: appointment }] } }))

      result = run(appointment_test)

      expect(result.result).to eq('wait')
      expect(result.result_message).to include('basedOn')
    end
  end

  describe 'request association' do
    before { create_request(hook_request_body(context: draft_orders(complete_service_request))) }

    it 'does not attach the cross hook requests to its own result' do
      result = run(service_request_test)

      expect(Inferno::Repositories::Requests.new.tagged_requests(
        test_session.id, [DaVinciCRDTestKit::CROSS_HOOK_ANALYSIS_TAG]
      ).length).to eq(1)
      expect(result.requests).to be_empty
    end
  end
end
