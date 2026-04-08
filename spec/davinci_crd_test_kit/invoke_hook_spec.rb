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
    json = File.read(File.join(__dir__, '..', 'fixtures', 'appointment_book_hook_request.json'))
    JSON.parse(json)
  end
  let(:service_request_bodies) { [service_request_body] }
  let(:service_endpoint) { "#{discovery_url}/#{service_ids}" }
  let(:encryption_method) { 'ES384' }
  let(:invoked_hook) { 'appointment-book' }
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
        nil, encryption_method, invoked_hook, continuation_url, failure_url, false
      )

      expect(hook_request).to have_been_made.once
      expect(continuation_request).to have_been_made.once
    end

    it 'does not invoke the continuation url after successful hook invocations if acknowledgement required' do
      hook_request = stub_request(:post, service_endpoint).to_return(status: 200)
      continuation_request = stub_request(:get, continuation_url).to_return(status: 200)
      expect_any_instance_of(Inferno::Repositories::Requests) # rubocop:disable RSpec/StubbedMock
        .to receive(:create)
        .and_return(nil)

      described_class.new.perform(
        test_session_id, service_request_bodies, service_endpoint, inferno_base_url,
        nil, encryption_method, invoked_hook, continuation_url, failure_url, true
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
        nil, encryption_method, invoked_hook, continuation_url, failure_url, false
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
        nil, encryption_method, invoked_hook, continuation_url, failure_url, false
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
        nil, encryption_method, invoked_hook, continuation_url, failure_url, false
      )

      expect(hook_request).to_not have_been_made
      expect(continuation_request).to_not have_been_made
    end
  end
end
