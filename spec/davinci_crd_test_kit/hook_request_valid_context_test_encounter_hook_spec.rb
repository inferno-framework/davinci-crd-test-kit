require_relative '../../lib/davinci_crd_test_kit/client_tests/hook_request_valid_context_test'
require_relative '../../lib/davinci_crd_test_kit/jwt_helper'

RSpec.describe DaVinciCRDTestKit::HookRequestValidContextTest do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('crd_client') }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: 'crd_client') }
  let(:klass) { Class.new(DaVinciCRDTestKit::JwtHelper) }

  let(:example_client_url) { 'https://cds.example.org' }
  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client" }
  let(:encounter_start_url) { "#{base_url}/cds-services/encounter-start-service" }
  let(:client_fhir_server) { 'https://example/r4' }
  let(:client_bearer_token) { 'SAMPLE_TOKEN' }

  let(:encounter_start_hook_request) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'encounter_start_hook_request.json'
                ))
    )
  end

  let(:crd_patient) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'crd_patient_example.json'
                ))
    )
  end

  let(:crd_practitioner) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'crd_practitioner_example.json'
                ))
    )
  end

  let(:crd_encounter) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'crd_encounter_example.json'
                ))
    )
  end

  let(:operation_outcome_success) do
    {
      outcomes: [{
        issues: []
      }],
      sessionId: 'b8cf5547-1dc7-4714-a797-dc2347b93fe2'
    }
  end

  let(:operation_outcome_failure) do
    {
      outcomes: [{
        issues: [{
          level: 'ERROR',
          message: 'Resource does not conform to profile'
        }]
      }],
      sessionId: 'b8cf5547-1dc7-4714-a797-dc2347b93fe2'
    }
  end

  let(:validator_url) { ENV.fetch('CRD_FHIR_RESOURCE_VALIDATOR_URL') }

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

  def create_encounter_start_request(url: encounter_start_url, body: nil, status: 200)
    auth_token = klass.build(
      aud: encounter_start_url,
      iss: example_client_url,
      jku: "#{example_client_url}/jwks.json",
      encryption_method: 'RS384'
    )

    headers = [
      {
        type: 'request',
        name: 'Authorization',
        value: "Bearer #{auth_token}"
      }
    ]

    repo_create(
      :request,
      name: 'encounter_start',
      direction: 'incoming',
      url:,
      test_session_id: test_session.id,
      request_body: body.is_a?(Hash) ? body.to_json : body,
      status:,
      headers:
    )
  end

  def entity_result_message(runnable)
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .map(&:message)
      .join(' ')
  end

  describe 'Encounter Start Hook Valid Context' do
    let(:test) do
      Class.new(DaVinciCRDTestKit::HookRequestValidContextTest) do
        fhir_resource_validator do
          url ENV.fetch('CRD_FHIR_RESOURCE_VALIDATOR_URL')

          cli_context do
            txServer nil
            displayWarnings true
            disableDefaultResourceFetcher true
          end

          igs('hl7.fhir.us.davinci-crd', 'hl7.fhir.us.core')
        end
        config(
          options: { hook_name: 'encounter-start' },
          requests: {
            hook_request: { name: :encounter_start }
          }
        )
      end
    end

    it 'passes if hook request `context` contains all required fields and fhir resources are valid' do
      validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_success.to_json)
      patient_resource_request = stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)
      practitioner_resource_request = stub_request(:get, "#{client_fhir_server}/Practitioner/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_practitioner.to_json)
      encounter_resource_request = stub_request(:get, "#{client_fhir_server}/Encounter/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter.to_json)
      create_encounter_start_request(body: encounter_start_hook_request)

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token)

      expect(result.result).to eq('pass')
      expect(validation_request).to have_been_made.times(3)
      expect(patient_resource_request).to have_been_made
      expect(practitioner_resource_request).to have_been_made
      expect(encounter_resource_request).to have_been_made
    end

    it 'skips if no client fhir server url is found' do
      create_encounter_start_request(body: encounter_start_hook_request)

      result = run(test)

      expect(result.result).to eq('skip')
      expect(result.result_message).to eq(
        "Input 'client_fhir_server' is nil, skipping test."
      )
    end

    it 'fails if request body is not a valid json' do
      create_encounter_start_request(body: 'invalid_request')

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Invalid JSON. ')
    end

    it 'fails if request body is does not contain the `context` field' do
      invalid_hook_request = encounter_start_hook_request.except('context')
      create_encounter_start_request(body: invalid_hook_request)

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Hook request does not contain required `context` field')
    end

    it 'fails if context does not contain all required fields' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
      stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)
      stub_request(:get, "#{client_fhir_server}/Practitioner/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_practitioner.to_json)
      encounter_start_hook_request['context'].delete('encounterId')
      create_encounter_start_request(body: encounter_start_hook_request)

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(
        /encounter-start request context does not contain required field `encounterId`/
      )
    end

    it 'fails if resource type and id cannot be extracted from context `userId` field' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
      stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)
      stub_request(:get, "#{client_fhir_server}/Encounter/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter.to_json)

      encounter_start_hook_request['context']['userId'] = '/'
      create_encounter_start_request(body: encounter_start_hook_request)

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(/Invalid `userId` format./)
    end

    it 'fails if context `userId` field resource type is not valid' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
      stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)
      stub_request(:get, "#{client_fhir_server}/Encounter/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter.to_json)

      encounter_start_hook_request['context']['userId'] = 'Observation/example'
      create_encounter_start_request(body: encounter_start_hook_request)

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(/Unsupported resource type: `userId` type should be/)
    end

    it 'fails if client fhir server returns non 200 response' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
      patient_resource_request = stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)
      practitioner_resource_request = stub_request(:get, "#{client_fhir_server}/Practitioner/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 404)
      encounter_resource_request = stub_request(:get, "#{client_fhir_server}/Encounter/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter.to_json)

      create_encounter_start_request(body: encounter_start_hook_request)

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(/Unexpected response status: expected 200, but received 404/)
      expect(patient_resource_request).to have_been_made
      expect(practitioner_resource_request).to have_been_made
      expect(encounter_resource_request).to have_been_made
    end

    it 'fails if returned fhir resource fails validation' do
      validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_failure.to_json)
      patient_resource_request = stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)
      encounter_resource_request = stub_request(:get, "#{client_fhir_server}/Encounter/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter.to_json)
      practitioner_resource_request = stub_request(:get, "#{client_fhir_server}/Practitioner/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_practitioner.to_json)

      create_encounter_start_request(body: encounter_start_hook_request)

      result = run(test,
                   client_fhir_server:,
                   client_access_token: client_bearer_token)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(/Resource does not conform to/)
      expect(validation_request).to have_been_made.times(3)
      expect(practitioner_resource_request).to have_been_made
      expect(patient_resource_request).to have_been_made
      expect(encounter_resource_request).to have_been_made
    end
  end
end
