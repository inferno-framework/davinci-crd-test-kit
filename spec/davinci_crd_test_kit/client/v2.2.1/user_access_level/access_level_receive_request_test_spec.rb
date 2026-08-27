require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.2.1/user_access_level/access_level_receive_request_test' # rubocop:disable Layout/LineLength
require_relative '../../../../../lib/davinci_crd_test_kit/cross_suite/tags'

RSpec.describe DaVinciCRDTestKit::V221::AccessLevelReceiveRequestTest, :request do
  let(:suite_id) { 'crd_client_v221' }
  let(:test) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:requests_repo) { Inferno::Repositories::Requests.new }
  let(:jwt_helper) { Class.new(DaVinciCRDTestKit::JwtHelper) }

  let(:example_client_url) { 'https://cds.example.org' }
  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client_v221" }
  let(:appointment_book_url) { "#{base_url}/cds-services/appointment-book-service" }
  let(:server_endpoint) { '/custom/crd_client_v221/cds-services/appointment-book-service' }
  let(:target_reference) { 'Observation/123' }

  let(:token) do
    jwt_helper.build(
      aud: appointment_book_url,
      iss: example_client_url,
      jku: "#{example_client_url}/jwks.json",
      encryption_method: 'RS384'
    )
  end

  let(:crd_coverage) do
    JSON.parse(File.read(File.join(
                           __dir__, '..', '..', '..', '..', 'fixtures', 'crd_coverage_example.json'
                         )))
  end

  # includes prefetched coverage by default so building the mocked response never needs a live query
  let(:body) do
    fixture = JSON.parse(File.read(File.join(
                                     __dir__, '..', '..', '..', '..', 'fixtures', 'appointment_book_hook_request.json'
                                   )))
    fixture['prefetch'] = { 'coverage' => crd_coverage }
    fixture
  end

  before do
    # this scenario doesn't gather payer/location data - only the target-resource read matters here
    allow_any_instance_of(DaVinciCRDTestKit::HookRequestEndpoint).to receive(:request_additional_fhir_data)
    allow_any_instance_of(DaVinciCRDTestKit::HookRequestEndpoint).to receive(:user_access_level_group?)
      .and_return(true)
    stub_request(:get, 'https://example/r4/Observation/123')
      .to_return(status: 200, body: { resourceType: 'Observation', id: '123' }.to_json)
  end

  def run_and_post(cds_jwt_iss: example_client_url)
    result = run(test, cds_jwt_iss:, access_level_target_reference: target_reference)
    header('Authorization', "Bearer #{token}")
    post_json(server_endpoint, body)
    result
  end

  it 'enters wait state when run' do
    result = run(test, cds_jwt_iss: example_client_url, access_level_target_reference: target_reference)
    expect(result.result).to eq('wait')
  end

  it 'passes immediately after a single valid hook request, without pausing' do
    expect_any_instance_of(DaVinciCRDTestKit::HookRequestEndpoint).to_not receive(:sleep)

    result = run_and_post

    expect(last_response).to be_ok
    result = results_repo.find(result.id)
    expect(result.result).to eq('pass')
  end

  it 'does not transition to pass if the jwt `iss` claim does not match the given `iss`' do
    result = run(test, cds_jwt_iss: 'different.example.com', access_level_target_reference: target_reference)
    expect(result.result).to eq('wait')

    header('Authorization', "Bearer #{token}")
    post_json(server_endpoint, body.to_json)

    expect(last_response).to be_server_error
    expect(last_response.body).to match(/find test run with identifier/)
    result = results_repo.find(result.id)
    expect(result.result).to eq('wait')
  end

  it 'reads the target resource reference using the access token in the hook request' do
    result = run_and_post

    fetch_requests = requests_repo.tagged_requests(
      result.test_session_id,
      [DaVinciCRDTestKit::TagMethods.hook_instance_data_fetch_tag(body['hookInstance']),
       DaVinciCRDTestKit::ACCESS_LEVEL_TARGET_FETCH_TAG]
    )
    expect(fetch_requests.size).to eq(1)
    expect(fetch_requests.first.url).to eq('https://example/r4/Observation/123')
    expect(fetch_requests.first.status.to_i).to eq(200)
  end

  it 'returns a mocked coverage-information system action and never returns cards' do
    run_and_post

    parsed_response = JSON.parse(last_response.body)
    expect(parsed_response['cards']).to eq([])
    expect(parsed_response['systemActions']).to be_present
    system_action = parsed_response['systemActions'].first
    expect(system_action['type']).to eq('update')
    extension_urls = system_action['resource']['extension'].map { |ext| ext['url'] }
    expect(extension_urls).to include('http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information')
  end
end
