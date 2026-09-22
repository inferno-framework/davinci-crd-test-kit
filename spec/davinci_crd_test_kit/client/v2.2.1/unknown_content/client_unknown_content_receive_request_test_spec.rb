require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.2.1/unknown_content/client_unknown_content_receive_request_test' # rubocop:disable Layout/LineLength

RSpec.describe DaVinciCRDTestKit::V221::ClientUnknownContentReceiveRequestTest, :request do
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
  let(:token) do
    jwt_helper.build(
      aud: appointment_book_url,
      iss: example_client_url,
      jku: "#{example_client_url}/jwks.json",
      encryption_method: 'RS384'
    )
  end

  def post_hook_request
    body['prefetch'] = { 'coverage' => crd_coverage }
    header('Authorization', "Bearer #{token}")
    post_json(server_endpoint, body)
  end

  before do
    allow_any_instance_of(DaVinciCRDTestKit::HookRequestEndpoint).to receive(:request_additional_fhir_data)
    allow_any_instance_of(DaVinciCRDTestKit::HookRequestEndpoint).to receive(:unknown_content_group?).and_return(true)
  end

  it 'enters wait state' do
    result = run(test, cds_jwt_iss: example_client_url)

    expect(result.result).to eq('wait')
  end

  it 'passes automatically after a hook request is received' do
    result = run(test, cds_jwt_iss: example_client_url)
    expect(result.result).to eq('wait')

    post_hook_request

    expect(last_response).to be_ok
    result = results_repo.find(result.id)
    expect(result.result).to eq('pass')
  end

  it 'returns coverage information system actions and no cards' do
    run(test, cds_jwt_iss: example_client_url)
    post_hook_request

    response_body = JSON.parse(last_response.body)
    expect(response_body['cards']).to eq([])
    expect(response_body['systemActions']).to be_present
    response_body['systemActions'].each do |action|
      coverage_extensions = action.dig('resource', 'extension').select do |extension|
        extension['url'] == DaVinciCRDTestKit::CardsIdentification::COVERAGE_INFO_EXT_URL
      end
      expect(coverage_extensions).to be_present
    end
  end

  it 'adds an unknown element to the system actions and an unknown extension to the response' do
    run(test, cds_jwt_iss: example_client_url)
    post_hook_request

    response_body = JSON.parse(last_response.body)
    unknown_elements = response_body['systemActions'].map do |action|
      action.keys - DaVinciCRDTestKit::V221::ClientUnknownContentAttestationTest::KNOWN_ACTION_ELEMENTS
    end

    expect(unknown_elements).to all(match([/\A[a-z]{16}\z/]))
    expect(unknown_elements.uniq.length).to eq(1)
    expect(response_body['extension'].keys).to match([/\A[a-z]{16}\z/])
  end

  it 'does not add unknown content within the FHIR resources in the response' do
    run(test, cds_jwt_iss: example_client_url)
    post_hook_request

    response_body = JSON.parse(last_response.body)
    response_body['systemActions'].each do |action|
      resource = action['resource']
      expect(FHIR.from_contents(resource.to_json).to_hash.keys).to match_array(resource.keys)
      expect(resource['extension'].map { |extension| extension['url'] })
        .to eq([DaVinciCRDTestKit::CardsIdentification::COVERAGE_INFO_EXT_URL])
    end
  end

  it 'waits and responds with 500 if jwt `iss` claim mismatches the given `iss`' do
    result = run(test, cds_jwt_iss: 'different.example.com')
    expect(result.result).to eq('wait')

    post_hook_request

    expect(last_response).to be_server_error
    expect(last_response.body).to include('is not associated with a waiting session')
    result = results_repo.find(result.id)
    expect(result.result).to eq('wait')
  end
end
