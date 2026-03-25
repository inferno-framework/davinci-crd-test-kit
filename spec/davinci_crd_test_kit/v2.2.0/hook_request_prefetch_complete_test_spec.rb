RSpec.describe DaVinciCRDTestKit::V220::HookRequestPrefetchCompleteTest do
  let(:suite_id) { 'crd_client' }
  let(:runnable) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }
  let(:example_client_url) { 'https://cds.example.org' }
  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client" }
  let(:order_sign_url) { "#{base_url}/cds-services/order-sign-service" }
  let(:fhirpath_url) { 'https://example.com/fhirpath/evaluate' }
  let(:test) do
    Class.new(described_class) do
      config(
        options: { hook_name: 'order-sign' }
      )
    end
  end

  let(:order_sign_request) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', '..', 'fixtures', 'order_sign_hook_request.json'
                ))
    )
  end
  let(:crd_patient_example) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', '..', 'fixtures', 'crd_patient_example.json'
                ))
    )
  end
  let(:crd_patient_example_bundle) do
    { 'resourceType' => 'Bundle', 'entry' => [{ 'resource' => crd_patient_example }] }
  end
  let(:crd_coverage_example) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', '..', 'fixtures', 'crd_coverage_example.json'
                ))
    )
  end
  let(:crd_coverage_example_bundle) do
    { 'resourceType' => 'Bundle', 'entry' => [{ 'resource' => crd_coverage_example }] }
  end
  let(:crd_practitioner_example) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', '..', 'fixtures', 'crd_practitioner_example.json'
                ))
    )
  end
  let(:crd_practitioner_example_bundle) do
    { 'resourceType' => 'Bundle', 'entry' => [{ 'resource' => crd_practitioner_example }] }
  end
  let(:crd_practitioner_role_example) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', '..', 'fixtures', 'crd_practitioner_role_example.json'
                ))
    )
  end
  let(:crd_practitioner_role_example_bundle) do
    { 'resourceType' => 'Bundle', 'entry' => [{ 'resource' => crd_practitioner_role_example }] }
  end

  def store_hook_request(hook_type, url: order_sign_url, body: nil, status: 200, headers: nil, auth_header: nil)
    if auth_header.present?
      headers ||= [
        {
          type: 'request',
          name: 'Authorization',
          value: auth_header
        }
      ]
    end
    repo_create(
      :request,
      direction: 'incoming',
      url:,
      result:,
      test_session_id: test_session.id,
      request_body: body.is_a?(Hash) ? body.to_json : body,
      status:,
      headers:,
      tags: [hook_type]
    )
  end

  def entity_result_message(runnable)
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .map(&:message)
      .join(' ')
  end

  describe 'when validating a read prefetch template' do
    let(:read_prefetch) do
      {
        'patient' => 'Patient/{{context.patientId}}'
      }
    end

    before do
      allow_any_instance_of(DaVinciCRDTestKit::V220::HookRequestPrefetchCompleteTest::PrefetchChecker)
        .to receive(:hook_prefetch_templates).and_return(read_prefetch)
    end

    it 'passes when the indicated resource is in the prefetch' do
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('pass')
    end

    it 'passes when no resource requested and none provided' do
      order_sign_request['prefetch'] = { 'patient' => nil }
      order_sign_request['context'].delete('patientId')
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('pass')
    end

    it 'fails when no prefetch data provided' do
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to eq('(Request 1) ' \
               'No prefetch data provided.')
    end

    it 'fails when the template key is not present in the prefetch' do
      order_sign_request['prefetch'] = {}
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to eq('(Request 1) Prefetch Template patient - ' \
               'No prefetch data provided.')
    end

    it 'fails when requested resource not provided' do
      order_sign_request['prefetch'] = { 'patient' => nil }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to eq('(Request 1) Prefetch Template patient - ' \
               "requested resource 'Patient/example' not provided.")
    end

    it 'fails when the prefetched value is not a FHIR resource (no resourceType)' do
      crd_patient_example.delete('resourceType')
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)
      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to eq('(Request 1) Prefetch Template patient - ' \
               'prefetched value is not a FHIR resource (no resourceType).')
    end

    it 'fails when the prefetched value has the wrong resource type' do
      crd_patient_example['resourceType'] = 'NotPatient'
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to eq('(Request 1) Prefetch Template patient - ' \
               'prefetched value has unexpected resourceType: expected Patient, got NotPatient.')
    end

    it 'fails when the prefetched value has no id' do
      crd_patient_example.delete('id')
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to eq('(Request 1) Prefetch Template patient - ' \
               'prefetched Patient is missing an id.')
    end

    it 'fails when the prefetched value has the wrong id' do
      crd_patient_example['id'] = 'wrong'
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to eq('(Request 1) Prefetch Template patient - ' \
               'prefetched Patient has unexpected id: expected example, got wrong.')
    end

    it 'if both resourceType and id are wrong, returns both errors' do
      crd_patient_example['resourceType'] = 'NotPatient'
      crd_patient_example['id'] = 'wrong'
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to eq('(Request 1) Prefetch Template patient - ' \
               'prefetched value has unexpected resourceType: expected Patient, got NotPatient. ' \
               '(Request 1) Prefetch Template patient - ' \
               'prefetched Patient has unexpected id: expected example, got wrong.')
    end

    it 'uses different prefixes when multiple requests' do
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      crd_patient_example['id'] = 'wrong'
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to eq('(Request 2) Prefetch Template patient - ' \
               'prefetched Patient has unexpected id: expected example, got wrong.')
    end

    it 'fails when an extra prefetch key is provided' do
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example, 'extra' => crd_patient_example }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to eq('(Request 1) Extra prefetch data provided in unrequested template \'extra\'.')
    end
  end

  describe 'when validating an _id search prefetch template' do
    let(:id_search_prefetch) do
      {
        'patient' => 'Patient?_id={{context.patientId}}'
      }
    end

    before do
      allow_any_instance_of(DaVinciCRDTestKit::V220::HookRequestPrefetchCompleteTest::PrefetchChecker)
        .to receive(:hook_prefetch_templates).and_return(id_search_prefetch)
    end

    it 'passes when the prefetch contains a Bundle with the right resource' do
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example_bundle }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('pass')
    end

    it 'fails when the prefetched value is not a FHIR resource (no resourceType)' do
      crd_patient_example_bundle.delete('resourceType')
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example_bundle }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to eq('(Request 1) Prefetch Template patient - ' \
               'prefetched value is not a FHIR resource (no resourceType).')
    end

    it 'fails when the prefetched value is not a Bundle' do
      crd_patient_example_bundle['resourceType'] = 'NotBundle'
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example_bundle }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to eq('(Request 1) Prefetch Template patient - ' \
               'prefetched value has unexpected resourceType: expected Bundle, got NotBundle.')
    end

    it 'fails when a prefetched Bundle entry has the wrong resource type' do
      crd_patient_example_bundle['entry'][0]['resource']['resourceType'] = 'NotPatient'
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example_bundle }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to eq('(Request 1) Prefetch Template patient - prefetched Bundle entry 1 has an unexpected resourceType: ' \
               'expected Patient, got NotPatient. ' \
               '(Request 1) Prefetch Template patient - prefetched Bundle missing expected entries: ' \
               'Patient/example. ' \
               '(Request 1) Prefetch Template patient - prefetched Bundle includes unrequested entries: ' \
               'NotPatient/example.')
    end

    it 'fails there are duplicate entries' do
      crd_patient_example_bundle['entry'] << { 'resource' => crd_patient_example }
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example_bundle }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to eq('(Request 1) Prefetch Template patient - ' \
               'prefetched Bundle has multiple entries with the same resource id.')
    end

    it 'fails when the wrong id is present (missing and extra)' do
      crd_patient_example_bundle['entry'][0]['resource']['id'] = 'wrong'
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example_bundle }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to eq('(Request 1) Prefetch Template patient - ' \
               'prefetched Bundle missing expected entries: Patient/example. ' \
               '(Request 1) Prefetch Template patient - ' \
               'prefetched Bundle includes unrequested entries: Patient/wrong.')
    end

    it 'fails when no prefetch provided and ids requested' do
      order_sign_request['prefetch'] = { 'patient' => nil }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to eq('(Request 1) Prefetch Template patient - ' \
               'requested resources not provided: Patient/example.')
    end

    it 'fails when an empty Bundle provided and ids requested' do
      order_sign_request['prefetch'] = { 'patient' => { 'resourceType' => 'Bundle' } }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to eq('(Request 1) Prefetch Template patient - ' \
               'prefetched Bundle missing expected entries: Patient/example.')
    end

    it 'passes when no prefetch provided and no ids requested' do
      order_sign_request['prefetch'] = { 'patient' => nil }
      order_sign_request['context'].delete('patientId')
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('pass')
    end

    it 'passes when an empty Bundle provided and no ids requested' do
      order_sign_request['prefetch'] = { 'patient' => { 'resourceType' => 'Bundle' } }
      order_sign_request['context'].delete('patientId')
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('pass')
    end
  end

  describe 'when validating an coverage search prefetch template' do
    let(:coverage_search_prefetch) do
      {
        'coverage' => 'Coverage?patient={{context.patientId}}&status=active'
      }
    end

    before do
      allow_any_instance_of(DaVinciCRDTestKit::V220::HookRequestPrefetchCompleteTest::PrefetchChecker)
        .to receive(:hook_prefetch_templates).and_return(coverage_search_prefetch)
    end

    it 'passes when the prefetch contains a Bundle with the right resource' do
      order_sign_request['prefetch'] = { 'coverage' => crd_coverage_example_bundle }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('pass')
    end

    it 'fails when the Bundle contains multiple entries' do
      crd_coverage_example_bundle['entry'] << { 'resource' => crd_coverage_example }
      order_sign_request['prefetch'] = { 'coverage' => crd_coverage_example_bundle }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to eq('(Request 1) Prefetch Template coverage - ' \
               'exactly one Coverage must be provided.')
    end

    it 'fails when the prefetched value is not a FHIR resource (no resourceType)' do
      crd_coverage_example_bundle.delete('resourceType')
      order_sign_request['prefetch'] = { 'coverage' => crd_coverage_example_bundle }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to eq('(Request 1) Prefetch Template coverage - ' \
               'prefetched value is not a FHIR resource (no resourceType).')
    end

    it 'fails when the prefetched value is not a Bundle' do
      crd_coverage_example_bundle['resourceType'] = 'NotBundle'
      order_sign_request['prefetch'] = { 'coverage' => crd_coverage_example_bundle }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)
      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to eq('(Request 1) Prefetch Template coverage - ' \
               'prefetched value has unexpected resourceType: expected Bundle, got NotBundle.')
    end

    it 'fails when a prefetched Bundle entry has the wrong resource type' do
      crd_coverage_example_bundle['entry'][0]['resource']['resourceType'] = 'NotCoverage'
      order_sign_request['prefetch'] = { 'coverage' => crd_coverage_example_bundle }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to eq('(Request 1) Prefetch Template coverage - ' \
               'entry in prefetched Coverage Bundle has an unexpected type: ' \
               'expected Coverage, got NotCoverage.')
    end

    it 'fails when a prefetched Coverage references the wrong patient' do
      crd_coverage_example_bundle['entry'][0]['resource']['beneficiary']['reference'] = 'Patient/wrong'
      order_sign_request['prefetch'] = { 'coverage' => crd_coverage_example_bundle }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to eq('(Request 1) Prefetch Template coverage - ' \
               'prefetched Coverage has an unexpected beneficiary reference: ' \
               'expected Patient/example, got Patient/wrong.')
    end

    it 'fails when a prefetched Coverage has the wrong status' do
      crd_coverage_example_bundle['entry'][0]['resource']['status'] = 'wrong'
      order_sign_request['prefetch'] = { 'coverage' => crd_coverage_example_bundle }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to eq('(Request 1) Prefetch Template coverage - ' \
               'prefetched Coverage has an unexpected status: ' \
               'expected active, got wrong.')
    end

    it 'fails when no prefetch provided' do
      order_sign_request['prefetch'] = { 'coverage' => nil }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to eq('(Request 1) Prefetch Template coverage - ' \
               'requested Coverage not provided.')
    end
  end

  describe 'when validating a non-Coverage search prefetch' do
    let(:bad_search_prefetch) do
      {
        'unsupported' => 'Patient?birthdate=20200101'
      }
    end

    before do
      allow_any_instance_of(DaVinciCRDTestKit::V220::HookRequestPrefetchCompleteTest::PrefetchChecker)
        .to receive(:hook_prefetch_templates).and_return(bad_search_prefetch)
    end

    it 'fails a non-_id search on a resource other than Coverageed' do
      order_sign_request['prefetch'] = { 'unsupported' => crd_coverage_example_bundle }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to match('unexpected search template')
    end
  end

  describe 'when resolving references in prefetch tokens' do
    let(:resolving_prefetch) do
      {
        'patient' => 'Patient?_id={{context.draftOrders.entry.resource.patient.resolve().id}}'
      }
    end

    before do
      allow_any_instance_of(DaVinciCRDTestKit::V220::HookRequestPrefetchCompleteTest::PrefetchChecker)
        .to receive(:hook_prefetch_templates).and_return(resolving_prefetch)
    end

    it 'succeeds when the target resource to resolve is in the prefetch set' do
      fhirpath_result_one = [{ type: 'Reference', element: { 'reference' => 'Patient/example' } }]
      stub_request(:post, "#{fhirpath_url}?path=entry.resource.patient")
        .with(body: /"resourceType":"Bundle"/)
        .to_return(status: 200, body: fhirpath_result_one.to_json)
      fhirpath_result_two = [{ type: 'id', element: 'example' }]
      stub_request(:post, "#{fhirpath_url}?path=id")
        .with(body: /"resourceType":"Patient"/)
        .to_return(status: 200, body: fhirpath_result_two.to_json)

      order_sign_request['context']['draftOrders']['entry'][0]['resource']['patient']['reference'] = 'Patient/example'
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example_bundle }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('pass')
    end

    it 'fails when the target resource to resolve is not in the prefetch set' do
      fhirpath_result_one = [{ type: 'Reference', element: { 'reference' => 'Patient/example' } }]
      stub_request(:post, "#{fhirpath_url}?path=entry.resource.patient")
        .with(body: /"resourceType":"Bundle"/)
        .to_return(status: 200, body: fhirpath_result_one.to_json)
      fhirpath_result_two = [{ type: 'id', element: 'example' }]
      stub_request(:post, "#{fhirpath_url}?path=id")
        .with(body: /"resourceType":"Patient"/)
        .to_return(status: 200, body: fhirpath_result_two.to_json)

      order_sign_request['context']['draftOrders']['entry'][0]['resource']['patient']['reference'] = 'Patient/example'
      order_sign_request['prefetch'] = { 'patient' => { 'resourceType' => 'Bundle' } }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to eq('(Request 1) Prefetch Template patient - ' \
               "resource 'Patient/example' needed to instantiate the query " \
               'was not provided in the prefetched values.')
    end

    it 'fails when the target resource to resolve is in the prefetch set without a resourceType' do
      fhirpath_result_one = [{ type: 'Reference', element: { 'reference' => 'Patient/example' } }]
      stub_request(:post, "#{fhirpath_url}?path=entry.resource.patient")
        .with(body: /"resourceType":"Bundle"/)
        .to_return(status: 200, body: fhirpath_result_one.to_json)
      fhirpath_result_two = [{ type: 'id', element: 'example' }]
      stub_request(:post, "#{fhirpath_url}?path=id")
        .with(body: /"resourceType":"Patient"/)
        .to_return(status: 200, body: fhirpath_result_two.to_json)

      crd_patient_example_bundle['entry'][0]['resource'].delete('resourceType')
      order_sign_request['context']['draftOrders']['entry'][0]['resource']['patient']['reference'] = 'Patient/example'
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example_bundle }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to eq('(Request 1) Prefetch Template patient - ' \
               "resource 'Patient/example' needed to instantiate the query " \
               'was not provided in the prefetched values. ' \
               '(Request 1) Prefetch Template patient - ' \
               'prefetched Bundle entry 1 is not a FHIR resource (no resourceType).')
    end

    it 'fails when the target resource to resolve is in the prefetch set without an id' do
      fhirpath_result_one = [{ type: 'Reference', element: { 'reference' => 'Patient/example' } }]
      stub_request(:post, "#{fhirpath_url}?path=entry.resource.patient")
        .with(body: /"resourceType":"Bundle"/)
        .to_return(status: 200, body: fhirpath_result_one.to_json)
      fhirpath_result_two = [{ type: 'id', element: 'example' }]
      stub_request(:post, "#{fhirpath_url}?path=id")
        .with(body: /"resourceType":"Patient"/)
        .to_return(status: 200, body: fhirpath_result_two.to_json)

      crd_patient_example_bundle['entry'][0]['resource'].delete('id')
      order_sign_request['context']['draftOrders']['entry'][0]['resource']['patient']['reference'] = 'Patient/example'
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example_bundle }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message(test))
        .to eq('(Request 1) Prefetch Template patient - ' \
               "resource 'Patient/example' needed to instantiate the query " \
               'was not provided in the prefetched values.')
    end
  end

  describe 'when chaining prefetches' do
    let(:resolving_prefetch) do
      {
        'practitionerRoles' =>
          'PractitionerRole?_id={{context.draftOrders.entry.resource.orderer.resolve().ofType(PractitionerRole).id}}',
        'practitioners' => 'Practitioner?_id={{%practitionerRoles.entry.resource.practitioner.resolve().id}}'
      }
    end

    before do
      allow_any_instance_of(DaVinciCRDTestKit::V220::HookRequestPrefetchCompleteTest::PrefetchChecker)
        .to receive(:hook_prefetch_templates).and_return(resolving_prefetch)
    end

    it 'succeeds when just the referenced instances are in the set' do
      fhirpath_result_one = [{ type: 'Reference', element: { 'reference' => 'PractitionerRole/example' } }]
      stub_request(:post, "#{fhirpath_url}?path=entry.resource.orderer")
        .to_return(status: 200, body: fhirpath_result_one.to_json)
      fhirpath_result_two = [{ type: 'Reference', element: { 'reference' => 'Practitioner/example' } }]
      stub_request(:post, "#{fhirpath_url}?path=entry.resource.practitioner")
        .to_return(status: 200, body: fhirpath_result_two.to_json)
      fhirpath_result_three = [{ type: 'id', element: 'example' }]
      stub_request(:post, "#{fhirpath_url}?path=id")
        .to_return(status: 200, body: fhirpath_result_three.to_json)
      stub_request(:post, "#{fhirpath_url}?path=ofType(PractitionerRole).id")
        .to_return(status: 200, body: fhirpath_result_three.to_json)

      order_sign_request['context']['draftOrders']['entry'][0]['resource']['orderer']['reference'] =
        'PractitionerRole/example'
      order_sign_request['prefetch'] = { 'practitionerRoles' => crd_practitioner_role_example_bundle,
                                         'practitioners' => crd_practitioner_example_bundle }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('pass')
    end
  end
end
