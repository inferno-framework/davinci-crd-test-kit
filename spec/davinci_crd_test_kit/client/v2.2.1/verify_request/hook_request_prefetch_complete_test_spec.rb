RSpec.describe DaVinciCRDTestKit::V221::HookRequestPrefetchCompleteTest do
  let(:suite_id) { 'crd_client' }
  let(:runnable) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }
  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client" }
  let(:order_sign_url) { "#{base_url}/cds-services/order-sign-service" }
  let(:test) do
    Class.new(described_class) do
      config(options: { hook_name: 'order-sign' })
    end
  end

  let(:order_sign_request) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', '..', 'fixtures', 'order_sign_hook_request.json')))
  end
  let(:crd_patient_example) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', '..', '..', 'fixtures', 'crd_patient_example.json')))
  end

  def store_hook_request(hook_type, url: order_sign_url, body: nil, status: 200)
    repo_create(
      :request,
      direction: 'incoming',
      url:,
      result:,
      test_session_id: test_session.id,
      request_body: body.is_a?(Hash) ? body.to_json : body,
      status:,
      tags: [hook_type]
    )
  end

  def entity_result_message(runnable)
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first.messages.map(&:message).join(' ')
  end

  before do
    allow_any_instance_of(DaVinciCRDTestKit::PrefetchCompletenessChecker)
      .to receive(:hook_prefetch_templates).and_return({ 'patient' => 'Patient/{{context.patientId}}' })
  end

  it 'skips when no hook requests have been received' do
    expect(run(test).result).to eq('skip')
  end

  it 'passes when prefetch is valid' do
    order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
    store_hook_request('order-sign', body: order_sign_request)
    expect(run(test).result).to eq('pass')
  end

  it 'fails and surfaces PrefetchCompletenessChecker errors as test messages' do
    store_hook_request('order-sign', body: order_sign_request)
    results = run(test)
    expect(results.result).to eq('fail')
    expect(entity_result_message(test)).to include('No prefetch data provided')
  end

  it 'processes multiple requests independently with correct indices' do
    order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
    store_hook_request('order-sign', body: order_sign_request)
    crd_patient_example['id'] = 'wrong'
    store_hook_request('order-sign', body: order_sign_request)
    results = run(test)
    expect(results.result).to eq('fail')
    expect(entity_result_message(test)).to include('(Request 2)')
  end

  describe 'services file selection based on request URL' do
    let(:subset_url) do
      "#{Inferno::Application['base_url']}/custom/crd_client/prefetch-subset/cds-services/order-sign-subset"
    end

    it 'uses the standard services file for cds-services endpoint requests' do
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      store_hook_request('order-sign', body: order_sign_request)
      allow(DaVinciCRDTestKit::PrefetchCompletenessChecker).to receive(:new).and_call_original
      run(test)
      expect(DaVinciCRDTestKit::PrefetchCompletenessChecker).to have_received(:new)
        .with(anything, anything, a_string_including('cds-services-v221.json'))
    end

    it 'uses the prefetch-subset services file for prefetch-subset endpoint requests' do
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      store_hook_request('order-sign', url: subset_url, body: order_sign_request)
      allow(DaVinciCRDTestKit::PrefetchCompletenessChecker).to receive(:new).and_call_original
      run(test)
      expect(DaVinciCRDTestKit::PrefetchCompletenessChecker).to have_received(:new)
        .with(anything, anything, a_string_including('cds-services-prefetch-subset-v221.json'))
    end

    it 'selects the correct file independently for each request when both endpoint types are present' do
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      store_hook_request('order-sign', body: order_sign_request)
      store_hook_request('order-sign', url: subset_url, body: order_sign_request)
      allow(DaVinciCRDTestKit::PrefetchCompletenessChecker).to receive(:new).and_call_original
      run(test)
      expect(DaVinciCRDTestKit::PrefetchCompletenessChecker).to have_received(:new)
        .with(anything, 0, a_string_including('cds-services-v221.json'))
      expect(DaVinciCRDTestKit::PrefetchCompletenessChecker).to have_received(:new)
        .with(anything, 1, a_string_including('cds-services-prefetch-subset-v221.json'))
    end
  end

  describe 'demonstrates_fhirpath_collection_as_comma_delimited_string output' do
    let(:id_search_template) { { 'patient' => 'Patient?_id={{context.patientId|context.secondPatientId}}' } }
    let(:crd_patient_example_bundle) do
      { 'resourceType' => 'Bundle', 'entry' => [{ 'resource' => crd_patient_example }] }
    end

    it 'does not set the output when no request demonstrates collection behavior' do
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      store_hook_request('order-sign', body: order_sign_request)
      result = run(test)
      expect(result.result).to eq('pass')
      output = result.outputs.find { |o| o['name'] == 'demonstrates_fhirpath_collection_as_comma_delimited_string' }
      expect(output&.dig('value')).to be_blank
    end

    it 'sets the output to true when a request demonstrates collection behavior' do
      allow_any_instance_of(DaVinciCRDTestKit::PrefetchCompletenessChecker)
        .to receive(:hook_prefetch_templates).and_return(id_search_template)
      order_sign_request['context']['secondPatientId'] = 'other'
      order_sign_request['prefetch'] = { 'patient' => {
        'resourceType' => 'Bundle',
        'entry' => [
          { 'resource' => crd_patient_example },
          { 'resource' => crd_patient_example.merge('id' => 'other') }
        ]
      } }
      store_hook_request('order-sign', body: order_sign_request)
      result = run(test)
      expect(result.result).to eq('pass')
      output = result.outputs.find { |o| o['name'] == 'demonstrates_fhirpath_collection_as_comma_delimited_string' }
      expect(output['value']).to eq('true')
    end

    it 'sets the output to true when any one of multiple requests demonstrates collection behavior' do
      allow_any_instance_of(DaVinciCRDTestKit::PrefetchCompletenessChecker)
        .to receive(:hook_prefetch_templates)
        .and_return({ 'patient' => 'Patient?_id={{context.patientId|context.secondPatientId}}' })

      order_sign_request['prefetch'] = { 'patient' => crd_patient_example_bundle }
      store_hook_request('order-sign', body: order_sign_request)

      second_request = JSON.parse(order_sign_request.to_json)
      second_request['context']['secondPatientId'] = 'other'
      second_request['prefetch'] = { 'patient' => {
        'resourceType' => 'Bundle',
        'entry' => [
          { 'resource' => crd_patient_example },
          { 'resource' => crd_patient_example.merge('id' => 'other') }
        ]
      } }
      store_hook_request('order-sign', body: second_request)

      result = run(test)
      expect(result.result).to eq('pass')
      output = result.outputs.find { |o| o['name'] == 'demonstrates_fhirpath_collection_as_comma_delimited_string' }
      expect(output['value']).to eq('true')
    end
  end

  describe 'demonstrates_prefetch_subset_distinct_from_complete output' do
    let(:subset_url) do
      "#{Inferno::Application['base_url']}/custom/crd_client/prefetch-subset/cds-services/order-sign-subset"
    end

    it 'does not set the output when the primary (subset) check fails' do
      store_hook_request('order-sign', url: subset_url, body: order_sign_request)
      result = run(test)
      expect(result.result).to eq('fail')
      output = result.outputs.find { |o| o['name'] == 'demonstrates_prefetch_subset_distinct_from_complete' }
      expect(output&.dig('value')).to be_blank
    end

    it 'does not set the output when data sets are not distinct' do
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      store_hook_request('order-sign', url: subset_url, body: order_sign_request)
      allow_any_instance_of(DaVinciCRDTestKit::PrefetchCompletenessChecker)
        .to receive(:data_set_different_with_alternate_service?).and_return(false)
      result = run(test)
      expect(result.result).to eq('pass')
      output = result.outputs.find { |o| o['name'] == 'demonstrates_prefetch_subset_distinct_from_complete' }
      expect(output&.dig('value')).to be_blank
    end

    it 'sets the output when the primary check passes and data sets are distinct' do
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      store_hook_request('order-sign', url: subset_url, body: order_sign_request)
      allow_any_instance_of(DaVinciCRDTestKit::PrefetchCompletenessChecker)
        .to receive(:data_set_different_with_alternate_service?).and_return(true)
      result = run(test)
      expect(result.result).to eq('pass')
      output = result.outputs.find { |o| o['name'] == 'demonstrates_prefetch_subset_distinct_from_complete' }
      expect(output['value']).to eq('true')
    end
  end

  describe 'demonstrates_prefetch_complete_distinct_from_subset output' do
    it 'does not set the output when the primary (complete) check fails' do
      store_hook_request('order-sign', body: order_sign_request)
      result = run(test)
      expect(result.result).to eq('fail')
      output = result.outputs.find { |o| o['name'] == 'demonstrates_prefetch_complete_distinct_from_subset' }
      expect(output&.dig('value')).to be_blank
    end

    it 'does not set the output when data sets are not distinct' do
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      store_hook_request('order-sign', body: order_sign_request)
      allow_any_instance_of(DaVinciCRDTestKit::PrefetchCompletenessChecker)
        .to receive(:data_set_different_with_alternate_service?).and_return(false)
      result = run(test)
      expect(result.result).to eq('pass')
      output = result.outputs.find { |o| o['name'] == 'demonstrates_prefetch_complete_distinct_from_subset' }
      expect(output&.dig('value')).to be_blank
    end

    it 'sets the output when the primary check passes and data sets are distinct' do
      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      store_hook_request('order-sign', body: order_sign_request)
      allow_any_instance_of(DaVinciCRDTestKit::PrefetchCompletenessChecker)
        .to receive(:data_set_different_with_alternate_service?).and_return(true)
      result = run(test)
      expect(result.result).to eq('pass')
      output = result.outputs.find { |o| o['name'] == 'demonstrates_prefetch_complete_distinct_from_subset' }
      expect(output['value']).to eq('true')
    end
  end
end
