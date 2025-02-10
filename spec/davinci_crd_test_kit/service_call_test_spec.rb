RSpec.describe DaVinciCRDTestKit::ServiceCallTest do
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:results_repo) { Inferno::Repositories::Results.new }
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

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(
        test_session_id: test_session.id,
        name:,
        value:,
        type: runnable.config.input_type(name)
      )
    end
    Inferno::TestRunner.new(test_session:, test_run:).run(runnable)
  end

  before do
    allow_any_instance_of(runnable).to receive(:hook_name).and_return('appointment-book')
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
    expect(result.result_message).to match(/'service_ids' is nil, skipping test/)
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
end
