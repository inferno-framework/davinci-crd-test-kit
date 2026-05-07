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
    JSON.parse(File.read(File.join(__dir__, '..', '..', 'fixtures', 'order_sign_hook_request.json')))
  end
  let(:crd_patient_example) do
    JSON.parse(File.read(File.join(__dir__, '..', '..', 'fixtures', 'crd_patient_example.json')))
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
end
