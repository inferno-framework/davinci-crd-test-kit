RSpec.describe DaVinciCRDTestKit::Jobs::InvokeHook do
  let(:test_session_id) { '12345' }
  let(:test_run_id) { '12345' }
  let(:result_id) { '12345' }
  let(:suite_id) { 'crd_server' }

  let(:base_url) { 'http://example.com' }
  let(:discovery_url) { 'http://example.com/cds-services' }
  let(:inferno_base_url) { 'http://inferno.com' }
  let(:service_ids) { 'service_ids' }
  let(:service_request_body) do
    json = File.read(File.join(__dir__, '..', '..', '..', 'fixtures', 'appointment_book_hook_request.json'))
    JSON.parse(json)
  end
  let(:service_request_bodies) { [service_request_body] }
  let(:service_endpoint) { "#{discovery_url}/#{service_ids}" }
  let(:encryption_method) { 'ES384' }
  let(:invoked_hook) { 'appointment-book' }
  let(:coverage_info_response) do
    {
      cards: [
        {
          summary: 'Coverage information',
          indicator: 'info',
          source: { topic: { code: DaVinciCRDTestKit::CardsIdentification::COVERAGE_INFO_CONFIGURATION_CODE } }
        }
      ]
    }
  end
  let(:filtered_response) { { cards: [] } }
  let(:continuation_url) do
    "#{inferno_base_url}/custom/#{suite_id}/resume_pass?token=#{test_session_id}"
  end
  let(:failure_url) do
    "#{inferno_base_url}/custom/#{suite_id}/resume_fail?token=#{test_session_id}" \
      '&message=Hook%20invocation%20failed:%20bad'
  end

  before do
    allow_any_instance_of(Inferno::Repositories::TestRuns)
      .to receive(:last_test_run)
      .and_return(instance_double(
                    Inferno::Entities::TestRun, id: test_run_id
                  ))
    allow_any_instance_of(Inferno::Repositories::TestRuns)
      .to receive(:status_for_test_run)
      .and_return('waiting')
    allow_any_instance_of(Inferno::Repositories::Results)
      .to receive(:find_waiting_result)
      .and_return(instance_double(
                    Inferno::Entities::Result, id: result_id
                  ))
    allow_any_instance_of(Inferno::Repositories::Requests)
      .to receive(:create)
      .and_return(nil)
  end

  describe 'when continuing after the invoke hooks job' do
    it 'invokes the continuation url after successful hook invocations' do
      hook_request = stub_request(:post, service_endpoint).to_return(status: 200)
      continuation_request = stub_request(:get, continuation_url).to_return(status: 200)
      expect_any_instance_of(Inferno::Repositories::Requests) # rubocop:disable RSpec/StubbedMock
        .to receive(:create)
        .and_return(nil)

      described_class.new.perform(
        test_session_id, service_request_bodies, service_endpoint, inferno_base_url,
        nil, encryption_method, invoked_hook, continuation_url, failure_url, false, false
      )

      expect(hook_request).to have_been_made.once
      expect(continuation_request).to have_been_made.once
    end

    it 'updates hook request details before invoking the service' do
      original_hook_instance = service_request_body['hookInstance']
      hook_request = stub_request(:post, service_endpoint)
        .with do |request|
          request_body = JSON.parse(request.body)
          token = request_body.dig('fhirAuthorization', 'access_token')
          token_body = JSON.parse(Base64.urlsafe_decode64(token))

          request_body['hookInstance'] != original_hook_instance &&
            request_body['fhirServer'] == "#{inferno_base_url}/fhir" &&
            token_body['session_id'] == test_session_id
        end
        .to_return(status: 200)
      stub_request(:get, continuation_url).to_return(status: 200)

      described_class.new.perform(
        test_session_id, service_request_bodies, service_endpoint, inferno_base_url,
        nil, encryption_method, invoked_hook, continuation_url, failure_url, false, false
      )

      expect(hook_request).to have_been_made.once
    end

    it 'sends follow-up requests when coverage-info content is returned' do
      job = described_class.new

      random_key = 'RANDOM_KEY'
      allow(job).to receive(:random_key).and_return(random_key)

      original_request =
        stub_request(:post, service_endpoint)
          .with do |request|
            JSON.parse(request.body).dig('extension', 'davinci-crd.configuration', 'coverage-info').nil? &&
              JSON.parse(request.body).dig('extension', 'davinci-crd.configuration', random_key).nil? &&
              JSON.parse(request.body).dig('context', random_key).nil? &&
              JSON.parse(request.body)[random_key].nil?
          end
          .to_return(status: 200, body: coverage_info_response.to_json)

      coverage_info_disabled_request =
        stub_request(:post, service_endpoint)
          .with do |request|
            JSON.parse(request.body).dig('extension', 'davinci-crd.configuration', 'coverage-info') == false
          end
          .to_return(status: 200, body: filtered_response.to_json)

      unknown_configuration_request =
        stub_request(:post, service_endpoint)
          .with do |request|
            JSON.parse(request.body).dig('extension', 'davinci-crd.configuration', random_key) == true
          end
          .to_return(status: 200, body: filtered_response.to_json)

      unknown_context_request =
        stub_request(:post, service_endpoint)
          .with do |request|
            JSON.parse(request.body).dig('context', random_key).present?
          end
          .to_return(status: 200, body: filtered_response.to_json)

      unknown_element_request =
        stub_request(:post, service_endpoint)
          .with do |request|
            JSON.parse(request.body)[random_key].present?
          end
          .to_return(status: 200, body: filtered_response.to_json)

      stub_request(:get, continuation_url).to_return(status: 200)

      job.perform(
        test_session_id, service_request_bodies, service_endpoint, inferno_base_url,
        nil, encryption_method, invoked_hook, continuation_url, failure_url, false, true
      )

      expect(original_request).to have_been_made.once
      expect(coverage_info_disabled_request).to have_been_made.once
      expect(unknown_configuration_request).to have_been_made.once
      expect(unknown_context_request).to have_been_made.once
      expect(unknown_element_request).to have_been_made.once
    end

    it 'sends only one coverage-info disabled follow-up request per job' do
      request_bodies = [service_request_body, service_request_body.deep_dup]
      original_request = stub_request(:post, service_endpoint)
        .with do |request|
          JSON.parse(request.body).dig('extension', 'davinci-crd.configuration', 'coverage-info').nil?
        end
        .to_return(status: 200, body: coverage_info_response.to_json)
      coverage_info_disabled_request = stub_request(:post, service_endpoint)
        .with do |request|
          JSON.parse(request.body).dig('extension', 'davinci-crd.configuration', 'coverage-info') == false
        end
        .to_return(status: 200, body: filtered_response.to_json)
      stub_request(:get, continuation_url).to_return(status: 200)

      job = described_class.new
      job.instance_variable_set(:@unknown_configuration_invoked, true)
      job.instance_variable_set(:@unknown_context_invoked, true)
      job.instance_variable_set(:@unknown_cds_hooks_element_invoked, true)

      job.perform(
        test_session_id, request_bodies, service_endpoint, inferno_base_url,
        nil, encryption_method, invoked_hook, continuation_url, failure_url, false, true
      )

      expect(original_request).to have_been_made.twice
      expect(coverage_info_disabled_request).to have_been_made.once
    end

    it 'does not invoke the continuation url after successful hook invocations if acknowledgement required' do
      hook_request = stub_request(:post, service_endpoint).to_return(status: 200)
      continuation_request = stub_request(:get, continuation_url).to_return(status: 200)
      expect_any_instance_of(Inferno::Repositories::Requests) # rubocop:disable RSpec/StubbedMock
        .to receive(:create)
        .and_return(nil)

      described_class.new.perform(
        test_session_id, service_request_bodies, service_endpoint, inferno_base_url,
        nil, encryption_method, invoked_hook, continuation_url, failure_url, true, false
      )

      expect(hook_request).to have_been_made.once
      expect(continuation_request).to_not have_been_made
    end

    it 'invokes the failure url after failed hook invocations' do
      fake_connection = instance_double(Faraday::Connection)
      allow(fake_connection).to receive(:post).and_raise(Faraday::ConnectionFailed.new('bad'))
      allow_any_instance_of(described_class)
        .to receive(:service_connection).and_return(fake_connection)
      failure_request = stub_request(:get, failure_url).to_return(status: 200)

      described_class.new.perform(
        test_session_id, service_request_bodies, service_endpoint, inferno_base_url,
        nil, encryption_method, invoked_hook, continuation_url, failure_url, false, false
      )
      expect(failure_request).to have_been_made.once
    end

    it 'ends without invoking the continuation url if the test was cancelled before all invocations sent' do
      call_count = 0
      allow_any_instance_of(Inferno::Repositories::Results)
        .to receive(:find_waiting_result) do
          call_count += 1
          if call_count < 4
            instance_double(
              Inferno::Entities::Result, id: result_id
            )
          end
        end

      hook_request = stub_request(:post, service_endpoint).to_return(status: 200)
      continuation_request = stub_request(:get, continuation_url).to_return(status: 200)
      expect_any_instance_of(Inferno::Repositories::Requests) # rubocop:disable RSpec/StubbedMock
        .to receive(:create)
        .and_return(nil)

      described_class.new.perform(
        test_session_id, service_request_bodies, service_endpoint, inferno_base_url,
        nil, encryption_method, invoked_hook, continuation_url, failure_url, false, false
      )

      expect(hook_request).to have_been_made.once
      expect(continuation_request).to_not have_been_made
    end

    it 'ends without doing anything if the test is done at the start' do
      allow_any_instance_of(Inferno::Repositories::TestRuns)
        .to receive(:status_for_test_run)
        .and_return('done')
      allow_any_instance_of(Inferno::Repositories::Results)
        .to receive(:find_waiting_result)
        .and_return(nil)

      hook_request = stub_request(:post, service_endpoint).to_return(status: 200)
      continuation_request = stub_request(:get, continuation_url).to_return(status: 200)

      described_class.new.perform(
        test_session_id, service_request_bodies, service_endpoint, inferno_base_url,
        nil, encryption_method, invoked_hook, continuation_url, failure_url, false, false
      )

      expect(hook_request).to_not have_been_made
      expect(continuation_request).to_not have_been_made
    end
  end
end
