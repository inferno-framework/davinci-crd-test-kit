require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.2.1/long_running/client_long_running_receive_request_test' # rubocop:disable Layout/LineLength

RSpec.describe DaVinciCRDTestKit::V221::ClientLongRunningReceiveRequestTest, :request do
  let(:suite_id) { 'crd_client_v221' }
  let(:test) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:jwt_helper) { Class.new(DaVinciCRDTestKit::JwtHelper) }

  let(:example_client_url) { 'https://cds.example.org' }
  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client_v221" }
  let(:appointment_book_url) { "#{base_url}/cds-services/appointment-book-service" }

  let(:server_endpoint) { '/custom/crd_client_v221/cds-services/appointment-book-service' }
  let(:body) do
    JSON.parse(File.read(File.join(
                           __dir__, '..', '..', '..', '..', 'fixtures', 'appointment_book_hook_request.json'
                         )))
  end
  let(:crd_coverage) do
    JSON.parse(File.read(File.join(
                           __dir__, '..', '..', '..', '..', 'fixtures', 'crd_coverage_example.json'
                         )))
  end

  before do
    allow_any_instance_of(DaVinciCRDTestKit::HookRequestEndpoint).to receive(:request_additional_fhir_data)
    allow_any_instance_of(DaVinciCRDTestKit::HookRequestEndpoint).to receive(:long_running_group?).and_return(true)
  end

  it 'fails when long_running_pause_time is less than 5 seconds' do
    result = run(test, cds_jwt_iss: example_client_url, long_running_pause_time: '3')

    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/Long-running Request Pause Time/)
  end

  it 'enters wait state when long_running_pause_time is at least 5 seconds' do
    allow_any_instance_of(DaVinciCRDTestKit::HookRequestEndpoint).to receive(:sleep)

    result = run(test, cds_jwt_iss: example_client_url, long_running_pause_time: '5')

    expect(result.result).to eq('wait')
  end

  it 'passes automatically after a valid hook request and sleeps for the configured pause time' do
    expect_any_instance_of(DaVinciCRDTestKit::HookRequestEndpoint).to receive(:sleep).with(5)

    token = jwt_helper.build(
      aud: appointment_book_url,
      iss: example_client_url,
      jku: "#{example_client_url}/jwks.json",
      encryption_method: 'RS384'
    )

    result = run(test, cds_jwt_iss: example_client_url, long_running_pause_time: '5')
    expect(result.result).to eq('wait')

    body['prefetch'] = { 'coverage' => crd_coverage }
    header('Authorization', "Bearer #{token}")
    post_json(server_endpoint, body)

    expect(last_response).to be_ok
    result = results_repo.find(result.id)
    expect(result.result).to eq('pass')
  end

  it 'sleeps for the duration specified by long_running_pause_time input' do
    expect_any_instance_of(DaVinciCRDTestKit::HookRequestEndpoint).to receive(:sleep).with(10)

    token = jwt_helper.build(
      aud: appointment_book_url,
      iss: example_client_url,
      jku: "#{example_client_url}/jwks.json",
      encryption_method: 'RS384'
    )

    run(test, cds_jwt_iss: example_client_url, long_running_pause_time: '10')

    body['prefetch'] = { 'coverage' => crd_coverage }
    header('Authorization', "Bearer #{token}")
    post_json(server_endpoint, body)
  end

  it 'waits and responds with 500 if jwt `iss` claim mismatches the given `iss`' do
    allow_any_instance_of(DaVinciCRDTestKit::HookRequestEndpoint).to receive(:sleep)

    token = jwt_helper.build(
      aud: appointment_book_url,
      iss: example_client_url,
      jku: "#{example_client_url}/jwks.json",
      encryption_method: 'RS384'
    )

    result = run(test, cds_jwt_iss: 'different.example.com', long_running_pause_time: '5')
    expect(result.result).to eq('wait')

    body['prefetch'] = { 'coverage' => crd_coverage }
    header('Authorization', "Bearer #{token}")
    post_json(server_endpoint, body.to_json)

    expect(last_response).to be_server_error
    expect(last_response.body).to match(/find test run with identifier/)
    result = results_repo.find(result.id)
    expect(result.result).to eq('wait')
  end
end
