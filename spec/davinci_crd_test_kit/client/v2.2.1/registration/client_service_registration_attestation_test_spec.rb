require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.2.1/registration/client_service_registration_attestation_test' # rubocop:disable Layout/LineLength

RSpec.describe DaVinciCRDTestKit::V221::CRDClientServiceRegistrationAttestation, :request do
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
  let(:token) do
    jwt_helper.build(
      aud: appointment_book_url,
      iss: example_client_url,
      jku: "#{example_client_url}/jwks.json",
      encryption_method: 'RS384'
    )
  end

  def run_attestation
    run(test, cds_jwt_iss: example_client_url, complete_prefetch_service_organization_id: 'complete-org',
              subset_prefetch_service_organization_id: 'subset-org')
  end

  it 'waits on the JWT issuer and passes when the url-encoded issuer is used to attest' do
    result = run_attestation
    expect(result.result).to eq('wait')

    get("/custom/crd_client_v221/resume_pass?token=#{ERB::Util.url_encode(example_client_url)}")

    expect(results_repo.find(result.id).result).to eq('pass')
  end

  it 'responds to hook requests with an error confirming registration and keeps waiting' do
    expect_any_instance_of(DaVinciCRDTestKit::HookRequestEndpoint).to_not receive(:request_additional_fhir_data)

    result = run_attestation
    expect(result.result).to eq('wait')

    header('Authorization', "Bearer #{token}")
    post_json(server_endpoint, body)

    expect(last_response.status).to eq(422)
    outcome = FHIR.from_contents(last_response.body)
    expect(outcome).to be_a(FHIR::OperationOutcome)
    expect(outcome.issue.first.code).to eq('business-rule')
    expect(outcome.issue.first.details.text).to include('successfully associated')
    expect(outcome.issue.first.details.text).to include(example_client_url)
    expect(results_repo.find(result.id).result).to eq('wait')
  end

  it 'does not tag hook requests received during registration' do
    result = run_attestation

    header('Authorization', "Bearer #{token}")
    post_json(server_endpoint, body)

    persisted_requests = Inferno::Repositories::Requests::Model.where(result_id: result.id).all
    expect(persisted_requests.length).to eq(1)
    expect(persisted_requests.first.tags).to be_empty
  end
end
