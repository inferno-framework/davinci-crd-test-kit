RSpec.describe DaVinciCRDTestKit::V201::ServerInvokeHookTest do
  let(:suite_id) { 'crd_server' }
  let(:runnable) do
    Class.new(described_class) do
      input :inferno_base_url
    end
  end
  let(:base_url) { 'http://example.com' }
  let(:discovery_url) { 'http://example.com/cds-services' }
  let(:inferno_base_url) { 'http://inferno.com' }
  let(:service_ids) { 'appointment-book-service' }
  let(:service_request_body) do
    json = File.read(File.join(__dir__, '..', '..', '..', '..', 'fixtures', 'appointment_book_hook_request.json'))
    JSON.parse(json)
  end
  let(:service_request_bodies) { [service_request_body].to_json }
  let(:encryption_method) { 'ES384' }
  let(:mock_ehr_bundle) { FHIR::Bundle.new(type: 'collection').to_json }

  before do
    allow_any_instance_of(DaVinciCRDTestKit::Jobs::InvokeHook) # hook invocations
      .to receive(:perform).and_return(nil)
  end

  describe 'when testing a specific hook' do
    before do
      allow_any_instance_of(runnable).to receive(:tested_hook_name).and_return('appointment-book')
    end

    it 'waits when provided details are sufficient' do
      result = run(runnable, base_url:, inferno_base_url:, service_ids:, encryption_method:,
                             service_request_bodies:, mock_ehr_bundle:)
      expect(result.result).to eq('wait')
    end

    it 'skips when the service_ids is not provided' do
      result = run(runnable, base_url:, inferno_base_url:, service_ids: '', encryption_method:,
                             service_request_bodies:, mock_ehr_bundle:)
      expect(result.result).to eq('skip')
      expect(result.result_message).to match(/No service id provided or discovered for the/)
    end

    it 'skips when the service_request_bodies is not provided' do
      result = run(runnable, base_url:, inferno_base_url:, service_ids:, encryption_method:,
                             mock_ehr_bundle:)
      expect(result.result).to eq('skip')
      expect(result.result_message).to match(/Request body not provided/)
    end

    it 'fails when the request body is an invalid json' do
      stub_request(:post, "#{discovery_url}/#{service_ids}")
        .with(
          body: 'body'
        )
        .to_return(status: 200, body: {}.to_json)

      result = run(runnable, base_url:, inferno_base_url:, service_ids:, encryption_method:,
                             service_request_bodies: 'body', mock_ehr_bundle:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/Invalid JSON/)
    end

    describe 'mock_ehr_bundle validation' do
      it 'skips when mock_ehr_bundle is blank' do
        result = run(runnable, base_url:, inferno_base_url:, service_ids:, encryption_method:,
                               service_request_bodies:, mock_ehr_bundle: '')
        expect(result.result).to eq('skip')
        expect(result.result_message).to match(/mock_ehr_bundle input must be a FHIR Bundle/)
      end

      it 'skips when mock_ehr_bundle is not valid JSON' do
        result = run(runnable, base_url:, inferno_base_url:, service_ids:, encryption_method:,
                               service_request_bodies:, mock_ehr_bundle: 'not-json')
        expect(result.result).to eq('skip')
        expect(result.result_message).to match(/mock_ehr_bundle input must be a FHIR Bundle/)
      end

      it 'skips when mock_ehr_bundle is valid JSON but not a FHIR Bundle' do
        result = run(runnable, base_url:, inferno_base_url:, service_ids:, encryption_method:,
                               service_request_bodies:,
                               mock_ehr_bundle: FHIR::Patient.new(id: 'p1').to_json)
        expect(result.result).to eq('skip')
        expect(result.result_message).to match(/mock_ehr_bundle input must be a FHIR Bundle/)
      end

      it 'proceeds past bundle validation when mock_ehr_bundle is a valid Bundle' do
        result = run(runnable, base_url:, inferno_base_url:, service_ids:, encryption_method:,
                               service_request_bodies:, mock_ehr_bundle:)
        expect(result.result).to eq('wait')
      end
    end
  end

  describe 'when testing any hook' do
    let(:result) { repo_create(:result, test_session_id: test_session.id) }
    let(:discovery_response) do
      File.read(File.join(__dir__, '..', '..', '..', '..', '..', 'lib', 'davinci_crd_test_kit', 'client', 'v2.0.1',
                          'cds-services-v201.json'))
    end

    before do
      allow_any_instance_of(runnable).to receive(:tested_hook_name).and_return(DaVinciCRDTestKit::ANY_HOOK_TAG)
    end

    it 'only allows a single request' do
      multiple_bodies = [service_request_body, service_request_body]

      result = run(runnable, base_url:, inferno_base_url:, service_ids:, encryption_method:,
                             service_request_bodies: multiple_bodies.to_json, mock_ehr_bundle:)
      expect(result.result).to eq('skip')
      expect(result.result_message).to match(/supports only one request body/)
    end

    it 'infers the hook type and service id from the request' do
      repo_create(
        :request,
        name: 'hook_invocation',
        direction: 'outgoing',
        url: discovery_url,
        result:,
        test_session_id: test_session.id,
        response_body: discovery_response,
        status: 200,
        headers: nil,
        tags: [DaVinciCRDTestKit::DISCOVERY_TAG]
      )

      expect_any_instance_of(DaVinciCRDTestKit::Jobs::InvokeHook) # rubocop:disable RSpec/StubbedMock
        .to receive(:perform)
        .with(anything, anything, "#{discovery_url}/#{service_ids}", anything, anything, anything,
              DaVinciCRDTestKit::ANY_HOOK_TAG, anything, anything, anything, false)
        .and_return(nil)

      result = run(runnable, base_url:, inferno_base_url:, service_ids: '', encryption_method:,
                             service_request_bodies:, mock_ehr_bundle:)
      expect(result.result).to eq('wait')
    end
  end
end
