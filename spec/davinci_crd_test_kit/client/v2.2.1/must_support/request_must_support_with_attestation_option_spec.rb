require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.2.1/client_cross_hook_must_support_group'
require_relative '../../../../../lib/davinci_crd_test_kit/generator/must_support_test_generator'
require_relative 'complete_resources'

RSpec.describe DaVinciCRDTestKit::V221::RequestMustSupportWithAttestationOption, :request do
  let(:suite_id) { 'crd_client_v221' }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite_id) }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:ig_version) { 'v2.2.1' }

  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client_v221" }
  let(:known_token) { 'abc123' }
  let(:attest_true_url) { "#{base_url}/resume_pass?token=#{known_token}" }
  let(:decline_message) { CGI.escape('Not all must support elements demonstrated. See messages for details.') }
  let(:attest_false_url) { "#{base_url}/resume_fail?token=#{known_token}&message=#{decline_message}" }
  let(:receiving_result) { repo_create(:result, test_session_id: test_session.id) }
  let(:complete_service_request) { DaVinciCRDTestKit::CompleteResources::SERVICE_REQUEST }
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

  def all_types_selected(inputs = {})
    generator = DaVinciCRDTestKit::Generator::MustSupportTestGenerator
    {
      order_types_supported: generator::ORDER_TYPE_OPTIONS.to_json,
      supporting_types_supported: generator::SUPPORTING_TYPE_OPTIONS.to_json
    }.merge(inputs)
  end

  describe 'when no requests have been received' do
    it 'skips' do
      result = run(service_request_test, all_types_selected)

      expect(result.result).to eq('skip')
      expect(result.result_message).to include('No hook requests received')
    end
  end

  describe 'when every must support element is observed' do
    before { create_request(hook_request_body(context: draft_orders(complete_service_request))) }

    it 'passes without waiting for an attestation' do
      result = run(service_request_test, all_types_selected)

      expect(result.result).to eq('pass')
      expect(result.result_message).to include('All must support elements were observed')
    end

    it 'records no unobserved element messages' do
      result = run(service_request_test, all_types_selected)
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
      result = run(service_request_test, all_types_selected)

      expect(result.result).to eq('wait')
      expect(result.result_message).to include('reasonReference')
      expect(result.result_message).to include('locationReference')
      expect(result.result_message).to include('does not capture')
    end

    it 'reports the number of instances it looked at' do
      result = run(service_request_test, all_types_selected)

      expect(result.result_message).to include('observed 1 `ServiceRequest` instance')
    end

    it 'logs each unobserved element as an info message' do
      run(service_request_test, all_types_selected)
      messages = results_repo.current_results_for_test_session_and_runnables(
        test_session.id, [service_request_test]
      ).first.messages

      expect(messages.map(&:message)).to include(
        a_string_matching(/Unobserved must support element for CRD Service Request: reasonReference/)
      )
    end

    it 'offers both attestation links as outputs' do
      result = run(service_request_test, all_types_selected)
      outputs = result.outputs.to_h { |output| [output['name'], output['value']] }

      expect(outputs['attest_true_url']).to eq(attest_true_url)
      expect(outputs['attest_false_url']).to eq(attest_false_url)
    end

    it 'passes when the tester follows the attestation link' do
      result = run(service_request_test, all_types_selected)
      expect(result.result).to eq('wait')

      get(attest_true_url)

      expect(results_repo.find(result.id).result).to eq('pass')
    end

    it 'fails with a result message when the tester declines the attestation' do
      result = run(service_request_test, all_types_selected)
      expect(result.result).to eq('wait')

      get(attest_false_url)

      declined = results_repo.find(result.id)
      expect(declined.result).to eq('fail')
      expect(declined.result_message).to eq('Not all must support elements demonstrated. See messages for details.')
    end
  end

  describe 'when the resource type is not present at all' do
    before { create_request(hook_request_body(context: draft_orders(complete_service_request))) }

    it 'fails when the tester selected the type as supported' do
      profiles = [{ resource_type: 'VisionPrescription', profile_keys: ['vision_prescription'] }]

      result = run(test_for(profiles), all_types_selected)

      expect(result.result).to eq('fail')
      expect(result.result_message).to include('No `VisionPrescription` instances were observed')
    end

    it 'passes when the tester did not select the type as supported' do
      profiles = [{ resource_type: 'VisionPrescription', profile_keys: ['vision_prescription'] }]

      result = run(test_for(profiles), all_types_selected(order_types_supported: ['ServiceRequest'].to_json))

      expect(result.result).to eq('pass')
      expect(result.result_message).to include('No instances of VisionPrescription observed')
    end
  end

  describe 'resource location within the request' do
    it 'finds resources carried only in prefetch' do
      create_request(hook_request_body(prefetch: { orders: complete_service_request }))

      expect(run(service_request_test, all_types_selected).result).to eq('pass')
    end

    it 'finds resources carried only in context' do
      create_request(hook_request_body(context: draft_orders(complete_service_request)))

      expect(run(service_request_test, all_types_selected).result).to eq('pass')
    end

    it 'pools instances across several requests so coverage can accumulate' do
      create_request(hook_request_body(context: draft_orders(complete_service_request.except(:reasonReference))))
      create_request(hook_request_body(context: draft_orders(complete_service_request.except(:performer))))

      expect(run(service_request_test, all_types_selected).result).to eq('pass')
    end
  end

  describe 'a test covering several profiles at once' do
    before { create_request(hook_request_body(context: draft_orders(complete_service_request))) }

    it 'fails on the absent type rather than attesting for it' do
      result = run(test_for([
                              { resource_type: 'ServiceRequest', profile_keys: ['service_request'] },
                              { resource_type: 'Location', profile_keys: ['location'] }
                            ]), all_types_selected)

      expect(result.result).to eq('fail')
      expect(result.result_message).to include('No `Location` instances were observed')
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

      result = run(appointment_test, all_types_selected)

      expect(result.result).to eq('wait')
      expect(result.result_message).to include('basedOn')
    end
  end

  describe 'request association' do
    before { create_request(hook_request_body(context: draft_orders(complete_service_request))) }

    it 'does not attach the cross hook requests to its own result' do
      result = run(service_request_test, all_types_selected)

      expect(Inferno::Repositories::Requests.new.tagged_requests(
        test_session.id, [DaVinciCRDTestKit::CROSS_HOOK_ANALYSIS_TAG]
      ).length).to eq(1)
      expect(result.requests).to be_empty
    end
  end

  describe 'every resource type the group checks' do
    let(:complete_resources) do
      resources = DaVinciCRDTestKit::CompleteResources
      {
        'ServiceRequest' => [resources::SERVICE_REQUEST],
        'VisionPrescription' => [resources::VISION_PRESCRIPTION],
        'NutritionOrder' => [resources::NUTRITION_ORDER],
        'MedicationRequest' => resources::MEDICATION_REQUESTS,
        'DeviceRequest' => resources::DEVICE_REQUESTS,
        'CommunicationRequest' => [resources::COMMUNICATION_REQUEST],
        'Encounter' => [resources::ENCOUNTER],
        'Coverage' => [resources::COVERAGE],
        'Location' => [resources::LOCATION],
        'Organization' => [resources::ORGANIZATION],
        'Patient' => [resources::PATIENT],
        'Practitioner' => [resources::PRACTITIONER],
        'PractitionerRole' => [resources::PRACTITIONER_ROLE],
        'Appointment' => [resources::APPOINTMENT]
      }
    end

    DaVinciCRDTestKit::Generator::MustSupportTestGenerator::TEST_DEFINITIONS.each do |definition|
      it "passes when every #{definition[:profiles].first[:resource_type]} must support element is observed" do
        resource_type = definition[:profiles].first[:resource_type]
        complete_resources.fetch(resource_type).each do |resource|
          create_request(hook_request_body(prefetch: { resource: }))
        end

        result = run(test_for(definition[:profiles]), all_types_selected)

        expect(result.result).to eq('pass'), "#{resource_type}: #{result.result_message}"
      end
    end
  end

  # Attestations are only worth a tester's time where the resource type was actually expected.
  describe 'resource types that were not expected' do
    let(:appointment_test) do
      test_for([{ resource_type: 'Appointment', title: 'CRD Appointment', supporting_profile: true,
                  profile_keys: %w[appointment_with_order appointment_without_order] }])
    end
    let(:location_test) { test_for([{ resource_type: 'Location', profile_keys: ['location'] }]) }

    def hook_request(hook_tag)
      repo_create(:request, test_session_id: test_session.id, result: receiving_result,
                            request_body: hook_request_body(prefetch: { patient: { resourceType: 'Patient' } }),
                            tags: [DaVinciCRDTestKit::CROSS_HOOK_ANALYSIS_TAG, hook_tag])
    end

    it 'passes without an attestation when no hook requiring the type was invoked' do
      hook_request(DaVinciCRDTestKit::ORDER_SIGN_TAG)

      result = run(appointment_test, all_types_selected)

      expect(result.result).to eq('pass')
      expect(result.result_message).to include('No instances of Appointment observed')
      expect(result.result_message).to include('appointment-book')
    end

    it 'fails when the hook requiring the type was invoked but the type never appeared' do
      hook_request(DaVinciCRDTestKit::APPOINTMENT_BOOK_TAG)

      result = run(appointment_test, all_types_selected)

      expect(result.result).to eq('fail')
      expect(result.result_message).to include('No `Appointment` instances were observed')
    end

    it 'still checks a hook gated type that turned up in another hook request' do
      create_request(hook_request_body(prefetch: { appointment: { resourceType: 'Appointment', id: 'a1',
                                                                  status: 'booked' } }))

      expect(run(appointment_test, all_types_selected).result).to eq('wait')
    end

    it 'passes without an attestation when the tester did not select the type' do
      create_request(hook_request_body(context: draft_orders(complete_service_request)))

      result = run(location_test,
                   all_types_selected(supporting_types_supported: %w[Organization Practitioner].to_json))

      expect(result.result).to eq('pass')
      expect(result.result_message).to include('No instances of Location observed')
      expect(result.result_message).to include('did not select it as supported')
    end

    it 'fails when a type the tester did not select was observed anyway' do
      create_request(hook_request_body(prefetch: { resource: DaVinciCRDTestKit::CompleteResources::LOCATION }))

      result = run(location_test,
                   all_types_selected(supporting_types_supported: %w[Organization Practitioner].to_json))

      expect(result.result).to eq('fail')
      expect(result.result_message).to include('Observed 1 `Location` instance')
      expect(result.result_message).to include('did not select it as supported')
    end

    # A client need not support any of these types, so clearing the input expects none of them.
    it 'expects no types when the tester cleared the input' do
      create_request(hook_request_body(context: draft_orders(complete_service_request)))

      result = run(location_test, all_types_selected(supporting_types_supported: [].to_json))

      expect(result.result).to eq('pass')
      expect(result.result_message).to include('No instances of Location observed')
    end
  end

  # Every test in the group analyzes the same pooled requests, so the extraction is done once and
  # shared through scratch rather than repeated by each test instance.
  describe 'extraction reuse across tests' do
    let(:scratch) { {} }
    let(:location_test) { test_for([{ resource_type: 'Location', profile_keys: ['location'] }]) }

    before { create_request(hook_request_body(context: draft_orders(complete_service_request))) }

    it 'parses the requests once for several tests' do
      run(service_request_test, {}, scratch)
      extraction = scratch[:must_support_extraction]

      run(location_test, {}, scratch)

      expect(scratch[:must_support_extraction]).to be(extraction)
    end

    it 'reaches the same verdicts whether or not the extraction is shared' do
      expect(run(service_request_test, all_types_selected, scratch).result).to eq('pass')
      expect(run(service_request_test, all_types_selected, {}).result).to eq('pass')
    end

    it 're-extracts once further hook requests arrive' do
      expect(run(service_request_test, all_types_selected, scratch).result).to eq('pass')

      create_request(hook_request_body(prefetch: { resource: DaVinciCRDTestKit::CompleteResources::LOCATION }))

      expect(run(location_test, all_types_selected, scratch).result).to eq('pass')
    end
  end
end
