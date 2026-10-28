require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.0.1/registration/client_service_registration_attestation_test' # rubocop:disable Layout/LineLength

RSpec.describe DaVinciCRDTestKit::V201::CRDClientServiceRegistrationAttestation, :request do
  let(:suite_id) { 'crd_client' }
  let(:test) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:jwt_helper) { Class.new(DaVinciCRDTestKit::JwtHelper) }

  let(:example_client_url) { 'https://cds.example.org' }
  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client" }
  let(:appointment_book_url) { "#{base_url}/cds-services/appointment-book-service" }
  let(:server_endpoint) { '/custom/crd_client/cds-services/appointment-book-service' }
  let(:body) do
    JSON.parse(File.read(File.join(
                           __dir__, '..', '..', '..', '..', 'fixtures', 'appointment_book_hook_request.json'
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

  it 'waits on the JWT issuer and passes when the url-encoded issuer is used to attest' do
    result = run(test, cds_jwt_iss: example_client_url)
    expect(result.result).to eq('wait')

    get("/custom/crd_client/resume_pass?token=#{ERB::Util.url_encode(example_client_url)}")

    expect(results_repo.find(result.id).result).to eq('pass')
  end

  it 'responds to hook requests with an error confirming registration and keeps waiting' do
    expect_any_instance_of(DaVinciCRDTestKit::HookRequestEndpoint).to_not receive(:request_coverage)

    result = run(test, cds_jwt_iss: example_client_url)
    expect(result.result).to eq('wait')

    header('Authorization', "Bearer #{token}")
    post_json(server_endpoint, body)

    expect(last_response.status).to eq(422)
    outcome = FHIR.from_contents(last_response.body)
    expect(outcome).to be_a(FHIR::OperationOutcome)
    expect(outcome.issue.first.code).to eq('business-rule')
    expect(outcome.issue.first.details.text).to include('successfully associated')
    expect(results_repo.find(result.id).result).to eq('wait')
  end
end
