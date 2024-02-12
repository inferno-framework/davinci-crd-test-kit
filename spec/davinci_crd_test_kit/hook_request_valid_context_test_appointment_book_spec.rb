require_relative '../../lib/davinci_crd_test_kit/client_tests/hook_request_valid_context_test'
require_relative '../../lib/davinci_crd_test_kit/jwt_helper'

RSpec.describe DaVinciCRDTestKit::HookRequestValidContextTest do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('crd_client') }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: 'crd_client') }
  let(:jwt_helper) { Class.new(DaVinciCRDTestKit::JwtHelper) }

  let(:example_client_url) { 'https://cds.example.org' }
  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client" }
  let(:appointment_book_url) { "#{base_url}/cds-services/appointment-book-service" }
  let(:client_fhir_server) { 'https://example/r4' }
  let(:client_access_token) { 'SAMPLE_TOKEN' }

  let(:appointment_book_hook_request) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'appointment_book_hook_request.json'
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
        type: runnable.config.input_type(name) || 'text'
      )
    end
    Inferno::TestRunner.new(test_session:, test_run:).run(runnable)
  end

  def create_appointment_hook_request(url: appointment_book_url, body: nil, status: 200)
    auth_token = jwt_helper.build(
      aud: appointment_book_url,
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
      name: 'appointment_book',
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

  describe 'Appointment Book Hook Valid Context' do
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
          options: { hook_name: 'appointment-book' },
          requests: {
            hook_request: { name: :appointment_book }
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

      create_appointment_hook_request(body: appointment_book_hook_request)
      result = run(test, client_fhir_server:, client_access_token:)
      expect(result.result).to eq('pass')
      expect(validation_request).to have_been_made.times(4)
      expect(patient_resource_request).to have_been_made
      expect(practitioner_resource_request).to have_been_made
    end

    it 'skips if no client fhir server url is found' do
      create_appointment_hook_request(body: appointment_book_hook_request)

      result = run(test)

      expect(result.result).to eq('skip')
      expect(result.result_message).to match("Input 'client_fhir_server' is nil, skipping test.")
    end

    it 'fails if request body is not a valid json' do
      create_appointment_hook_request(body: 'invalid_request')

      result = run(test, client_fhir_server:, client_access_token:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Invalid JSON. ')
    end

    it 'fails if request body is does not contain the `context` field' do
      invalid_hook_request = appointment_book_hook_request.except('context')
      create_appointment_hook_request(body: invalid_hook_request)

      result = run(test, client_fhir_server:, client_access_token:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Hook request does not contain required `context` field')
    end

    it 'fails if context does not contain all required fields' do
      appointment_book_hook_request['context'].delete('patientId')
      stub_request(:get, "#{client_fhir_server}/Practitioner/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_practitioner.to_json)
      create_appointment_hook_request(body: appointment_book_hook_request)
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
      result = run(test, client_fhir_server:, client_access_token:)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(/context does not contain required field `patientId`/)
    end

    it 'fails if resource type and id cannot be extracted from context `userId` field' do
      appointment_book_hook_request['context']['userId'] = '/'
      stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)

      create_appointment_hook_request(body: appointment_book_hook_request)
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)

      result = run(test, client_fhir_server:, client_access_token:)
      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(/Invalid `userId` format/)
    end

    it 'fails if context `userId` field resource type is not valid' do
      appointment_book_hook_request['context']['userId'] = 'Observation/example'
      stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)

      create_appointment_hook_request(body: appointment_book_hook_request)
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)

      result = run(test, client_fhir_server:, client_access_token:)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(/Unsupported resource type: `userId` type should be/)
    end

    it 'fails if client fhir server returns non 200 response' do
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
        .to_return(status: 404)

      create_appointment_hook_request(body: appointment_book_hook_request)

      result = run(test,
                   client_fhir_server:,
                   client_access_token:)

      messages = Inferno::Repositories::Messages.new.messages_for_result(result.id)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match('Context is not valid')
      expect(messages.length).to eq(1)
      expect(messages.first.message).to match('expected 200, but received 404')
      expect(validation_request).to have_been_made.at_least_once
      expect(patient_resource_request).to have_been_made
      expect(practitioner_resource_request).to have_been_made
    end

    it 'fails if returned fhir resource fails validation' do
      validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_failure.to_json)
      practitioner_resource_request = stub_request(:get, "#{client_fhir_server}/Practitioner/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_practitioner.to_json)
      patient_resource_request = stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)

      create_appointment_hook_request(body: appointment_book_hook_request)

      result = run(test, client_fhir_server:, client_access_token:)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match('Resource does not conform to profile')
      expect(validation_request).to have_been_made.times(4)
      expect(practitioner_resource_request).to have_been_made
      expect(patient_resource_request).to have_been_made
    end

    it 'passes if context contains optional `encounterId` field' do
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

      appointment_book_hook_request['context']['encounterId'] = 'example'

      create_appointment_hook_request(body: appointment_book_hook_request)

      result = run(test,
                   client_fhir_server:,
                   client_access_token:)

      expect(result.result).to eq('pass')
      expect(validation_request).to have_been_made.times(5)
      expect(patient_resource_request).to have_been_made
      expect(practitioner_resource_request).to have_been_made
      expect(encounter_resource_request).to have_been_made
    end

    it 'fails if context `appointments` is not a bundle' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
      stub_request(:get, "#{client_fhir_server}/Practitioner/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_practitioner.to_json)

      stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)

      appointment_book_hook_request['context']['appointments'] = crd_patient

      create_appointment_hook_request(body: appointment_book_hook_request)

      result = run(test, client_fhir_server:, client_access_token:)
      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(/Wrong context resource type: Expected `Bundle`, got `Patient`/)
    end

    it 'fails if there are no appointment resources in context `appointments` field' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
      stub_request(:get, "#{client_fhir_server}/Practitioner/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_practitioner.to_json)

      stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)

      appointment_book_hook_request['context']['appointments']['entry'].each do |entry|
        entry['resource'] = crd_patient
      end

      create_appointment_hook_request(body: appointment_book_hook_request)

      result = run(test, client_fhir_server:, client_access_token:)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(
        /`appointments` bundle must contain at least one of the expected resource types:/
      )
    end

    it 'fails if all appointments in context `appointments` field not in proposed state' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
      stub_request(:get, "#{client_fhir_server}/Practitioner/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_practitioner.to_json)

      stub_request(:get, "#{client_fhir_server}/Patient/example")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_patient.to_json)

      appointment_book_hook_request['context']['appointments']['entry'][0]['resource']['status'] = 'confirmed'

      create_appointment_hook_request(body: appointment_book_hook_request)

      result = run(test, client_fhir_server:, client_access_token:)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(
        /All Appointment resources in `appointments` bundle must have a `proposed` status./
      )
    end
  end
end
