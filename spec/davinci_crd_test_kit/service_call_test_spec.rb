RSpec.describe DaVinciCRDTestKit::ServiceCallTest do
  let(:suite_id) { 'crd_server' }
  let(:runnable) do
    Class.new(DaVinciCRDTestKit::ServiceCallTest) do
      input :inferno_base_url
    end
  end
  let(:base_url) { 'http://example.com' }
  let(:discovery_url) { 'http://example.com/cds-services' }
  let(:inferno_base_url) { 'http://inferno.com' }
  let(:service_ids) { 'service_ids' }
  let(:service_request_body) do
    json = File.read(File.join(__dir__, '..', 'fixtures', 'appointment_book_hook_request.json'))
    JSON.parse(json)
  end
  let(:service_request_bodies) { [service_request_body].to_json }

  let(:encryption_method) { 'ES384' }

  describe 'when testing a specific hook' do
    before do
      allow_any_instance_of(runnable).to receive(:tested_hook_name).and_return('appointment-book')
    end

    it 'passes when the server returns a 200 HTTP response' do
      stub_request(:post, "#{discovery_url}/#{service_ids}")
        .with(
          body: service_request_body
        )
        .to_return(status: 200, body: {}.to_json)

      result = run(runnable, base_url:, inferno_base_url:, service_ids:, encryption_method:, service_request_bodies:)
      expect(result.result).to eq('pass')
    end

    it 'skips when the service_ids is not provided' do
      result = run(runnable, base_url:, inferno_base_url:, service_ids: '', encryption_method:,
                             service_request_bodies:)
      expect(result.result).to eq('skip')
      expect(result.result_message).to match(/No service id provided or discovered for the/)
    end

    it 'skips when the service_request_bodies is not provided' do
      result = run(runnable, base_url:, inferno_base_url:, service_ids:, encryption_method:)
      expect(result.result).to eq('skip')
      expect(result.result_message).to match(/Request body not provided/)
    end

    it 'fails when the server does not return a 200 HTTP response' do
      stub_request(:post, "#{discovery_url}/#{service_ids}")
        .with(
          body: service_request_body
        )
        .to_return(status: 400, body: {}.to_json)

      result = run(runnable, base_url:, inferno_base_url:, service_ids:, encryption_method:, service_request_bodies:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/Unexpected response status: expected 200/)
    end

    it 'fails when the request body is an invalid json' do
      stub_request(:post, "#{discovery_url}/#{service_ids}")
        .with(
          body: 'body'
        )
        .to_return(status: 200, body: {}.to_json)

      result = run(runnable, base_url:, inferno_base_url:, service_ids:, encryption_method:,
                             service_request_bodies: 'body')
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/Invalid JSON/)
    end

    it 'fails when the response body is an invalid json' do
      stub_request(:post, "#{discovery_url}/#{service_ids}")
        .with(
          body: service_request_body
        )
        .to_return(status: 200, body: 'response')

      result = run(runnable, base_url:, inferno_base_url:, service_ids:, encryption_method:, service_request_bodies:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/Invalid JSON/)
    end

    it 'makes multiple requests when there are multiple bodies' do
      hook_invocation = stub_request(:post, "#{discovery_url}/#{service_ids}")
        .to_return(status: 200, body: {}.to_json)

      multiple_bodies = [service_request_body, service_request_body]

      result = run(runnable, base_url:, inferno_base_url:, service_ids:, encryption_method:,
                             service_request_bodies: multiple_bodies.to_json)
      expect(result.result).to eq('pass')
      expect(hook_invocation).to have_been_made.times(2)
    end
  end

  describe 'when testing any hook' do
    let(:result) { repo_create(:result, test_session_id: test_session.id) }
    let(:discovery_response) do
      File.read(File.join(__dir__, '..', '..', 'lib', 'davinci_crd_test_kit', 'routes', 'cds-services.json'))
    end

    before do
      allow_any_instance_of(runnable).to receive(:tested_hook_name).and_return('any')
    end

    it 'only allows a single request' do
      multiple_bodies = [service_request_body, service_request_body]

      result = run(runnable, base_url:, inferno_base_url:, service_ids:, encryption_method:,
                             service_request_bodies: multiple_bodies.to_json)
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

      stub_request(:post, "#{discovery_url}/appointment-book-service")
        .to_return(status: 200, body: {}.to_json)

      result = run(runnable, base_url:, inferno_base_url:, service_ids: '', encryption_method:,
                             service_request_bodies:)
      expect(result.result).to eq('pass')

      expect(session_data_repo.load(test_session_id: test_session.id, name: :invoked_hook)).to eq('appointment-book')
    end
  end
end
