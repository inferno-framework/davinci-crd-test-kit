RSpec.describe DaVinciCRDTestKit::V221::InvokeHookSingleTest do
  let(:suite_id) { 'crd_server' }
  let(:runnable) do
    Class.new(described_class) do
      input :inferno_base_url
    end
  end
  let(:base_url) { 'http://example.com' }
  let(:inferno_base_url) { 'http://inferno.com' }
  let(:service_ids) { 'order-sign-service' }
  let(:encryption_method) { 'ES384' }
  let(:mock_ehr_bundle) { FHIR::Bundle.new(type: 'collection').to_json }
  let(:service_request_body) do
    {
      'hookInstance' => 'd1577c69-dfbe-44ad-ba6d-3e05e953b2ea',
      'fhirServer' => 'https://example/r4',
      'hook' => 'order-sign',
      'context' => {
        'userId' => 'Practitioner/example',
        'patientId' => '123'
      }
    }
  end
  let(:service_request_bodies) { [service_request_body].to_json }

  before do
    allow_any_instance_of(runnable).to receive(:tested_hook_name).and_return('order-sign')
  end

  it 'skips when multiple request bodies are provided' do
    request_bodies = [service_request_body, service_request_body.deep_dup].to_json

    result = run(runnable, base_url:, inferno_base_url:, service_ids:, encryption_method:,
                           service_request_bodies: request_bodies, mock_ehr_bundle:)

    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/supports only one request body/)
  end
end
