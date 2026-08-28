require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.2.1/self_pay/client_self_pay_workflow_test'

RSpec.describe DaVinciCRDTestKit::V221::ClientSelfPayWorkflowTest, :request do
  let(:suite_id) { 'crd_client_v221' }
  let(:test) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:jwt_helper) { Class.new(DaVinciCRDTestKit::JwtHelper) }

  let(:example_client_url) { 'https://cds.example.org' }
  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client_v221" }
  let(:appointment_book_url) { "#{base_url}/cds-services/appointment-book-service" }
  let(:continuation_url) { "#{base_url}/resume_pass?token=#{example_client_url}" }

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
    allow_any_instance_of(DaVinciCRDTestKit::HookRequestEndpoint).to receive(:self_pay_group?).and_return(true)
  end

  it 'enters wait state' do
    result = run(test, cds_jwt_iss: example_client_url)

    expect(result.result).to eq('wait')
  end

  it 'passes when the tester clicks the continuation link' do
    result = run(test, cds_jwt_iss: example_client_url)
    expect(result.result).to eq('wait')

    get(continuation_url)

    result = results_repo.find(result.id)
    expect(result.result).to eq('pass')
  end

  it 'passes automatically after a hook request is received' do
    result = run(test, cds_jwt_iss: example_client_url)
    expect(result.result).to eq('wait')

    post_hook_request

    expect(last_response).to be_ok
    result = results_repo.find(result.id)
    expect(result.result).to eq('pass')
  end

  it 'tags requests with the self-pay group tag even when the request is invalid' do
    allow_any_instance_of(DaVinciCRDTestKit::HookRequestEndpoint)
      .to receive(:hook_instance_already_used?).and_return(true)
    allow_any_instance_of(DaVinciCRDTestKit::HookRequestEndpoint)
      .to receive(:interaction_group_tag).and_return(DaVinciCRDTestKit::SELF_PAY_GROUP_TAG)

    result = run(test, cds_jwt_iss: example_client_url)
    expect(result.result).to eq('wait')

    post_hook_request

    expect(last_response.status).to eq(400)
    result = results_repo.find(result.id)
    expect(result.result).to eq('pass')

    tagged_requests = Inferno::Repositories::Requests.new
      .tagged_requests(test_session.id, [DaVinciCRDTestKit::SELF_PAY_GROUP_TAG])
    expect(tagged_requests.length).to eq(1)
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

  it 'waits and responds with 500 if jwt `iss` claim mismatches the given `iss`' do
    result = run(test, cds_jwt_iss: 'different.example.com')
    expect(result.result).to eq('wait')

    post_hook_request

    expect(last_response).to be_server_error
    expect(last_response.body).to match(/Unable to find test run/)
    result = results_repo.find(result.id)
    expect(result.result).to eq('wait')
  end
end
