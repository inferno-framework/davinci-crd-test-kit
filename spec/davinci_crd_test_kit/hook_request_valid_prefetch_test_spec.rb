require_relative '../../lib/davinci_crd_test_kit/client_tests/hook_request_valid_prefetch_test'
require_relative '../../lib/davinci_crd_test_kit/jwt_helper'

RSpec.describe DaVinciCRDTestKit::HookRequestValidPrefetchTest do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('crd_client') }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: 'crd_client') }
  let(:jwt_helper) { Class.new(DaVinciCRDTestKit::JwtHelper) }

  let(:example_client_url) { 'https://cds.example.org' }
  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client" }
  let(:appointment_book_url) { "#{base_url}/cds-services/appointment-book-service" }
  let(:client_fhir_server) { 'https://example/r4' }
  let(:client_bearer_token) { 'SAMPLE_TOKEN' }

  let(:appointment_book_hook_request) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'appointment_book_hook_request.json'
                ))
    )
  end
  let(:encounter_start_hook_request) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'encounter_start_hook_request.json'
                ))
    )
  end
  let(:order_dispatch_hook_request) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'order_dispatch_hook_request.json'
                ))
    )
  end
  let(:order_select_hook_request) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'order_select_hook_request.json'
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

  let(:crd_coverage) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'crd_coverage_example.json'
                ))
    )
  end

  let(:crd_coverage_bundle) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{example_client_url}/Coverage/coverage_example",
                          resource: FHIR.from_contents(crd_coverage.to_json)
                        ))
    bundle
  end

  let(:crd_service_request) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'crd_service_request_example.json'
                ))
    )
  end

  let(:appointment_book_hook_request_with_prefetch) do
    request = appointment_book_hook_request
    request['prefetch'] = { user: crd_practitioner, patient: crd_patient, coverage: crd_coverage_bundle }
    request
  end
  let(:encounter_start_hook_request_with_prefetch) do
    request = encounter_start_hook_request
    request['prefetch'] = { user: crd_practitioner, patient: crd_patient, encounter: crd_encounter,
                            coverage: crd_coverage_bundle }
    request
  end
  let(:order_dispatch_hook_request_with_prefetch) do
    request = order_dispatch_hook_request
    request['prefetch'] = { performer: crd_practitioner, patient: crd_patient, order: crd_service_request,
                            coverage: crd_coverage_bundle }
    request
  end
  let(:order_select_hook_request_with_prefetch) do
    request = order_select_hook_request
    request['prefetch'] = { user: crd_practitioner, patient: crd_patient, coverage: crd_coverage_bundle }
    request
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

  def create_hook_request(url: appointment_book_url, body: nil, status: 200, hook_name: 'appointment_book')
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
      name: hook_name,
      direction: 'incoming',
      url:,
      test_session_id: test_session.id,
      request_body: body.is_a?(Hash) ? body.to_json : body,
      status:,
      headers:
    )
  end

  describe 'Appointment Book Hook Valid Prefetch' do
    let(:test) do
      Class.new(DaVinciCRDTestKit::HookRequestValidPrefetchTest) do
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
          requests: { hook_request: { name: :appointment_book } }
        )
      end
    end

    it 'passes if prefetch contains valid resources for `user`, `patient`, and `coverage` fields' do
      validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_success.to_json)

      create_hook_request(body: appointment_book_hook_request_with_prefetch)

      result = run(test)
      expect(result.result).to eq('pass')
      expect(validation_request).to have_been_made.times(3)
    end

    it 'skips if hook request does not contain the `prefetch` field' do
      create_hook_request(body: appointment_book_hook_request)

      result = run(test)

      expect(result.result).to eq('skip')
      expect(result.result_message).to eq('Received hook request does not contain the `prefetch` field.')
    end

    it 'skips if hook request does not contain the `context` field' do
      appointment_book_hook_no_context = appointment_book_hook_request_with_prefetch.except('context')
      create_hook_request(body: appointment_book_hook_no_context)

      result = run(test)

      expect(result.result).to eq('skip')
      expect(result.result_message).to match('Received hook request does not contain the `context` field')
    end

    it 'fails if prefetch `user` is not a valid resource type' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)

      appointment_book_hook_request_with_prefetch['prefetch'][:user]['resourceType'] = 'Observation'

      create_hook_request(body: appointment_book_hook_request_with_prefetch)

      result = run(test)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(
        'Unexpected resource type: expected Practitioner, but received Observation'
      )
    end

    it 'fails if prefetch `user` fails validation' do
      practitioner_validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_failure.to_json)

      create_hook_request(body: appointment_book_hook_request_with_prefetch)

      result = run(test)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match('Resource does not conform to the profile: http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-practitioner')
      expect(practitioner_validation_request).to have_been_made
    end

    it 'fails if prefetch `user` has wrong id' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)

      appointment_book_hook_request_with_prefetch['prefetch'][:user]['id'] = 'incorrect_id'

      create_hook_request(body: appointment_book_hook_request_with_prefetch)

      result = run(test)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match("Expected `user` field's FHIR resource to have an `id` of 'example'")
    end

    it 'fails if prefetch `patient` is not a Patient resource' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)

      appointment_book_hook_request_with_prefetch['prefetch'][:patient]['resourceType'] = 'Practitioner'

      create_hook_request(body: appointment_book_hook_request_with_prefetch)

      result = run(test)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match('Unexpected resource type: expected Patient, but received Practitioner')
    end

    it 'fails if prefetch `patient` fails validation' do
      patient_validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_failure.to_json)

      appointment_book_hook_request_with_prefetch['prefetch'].delete(:user)
      appointment_book_hook_request_with_prefetch['prefetch'].delete(:coverage)

      create_hook_request(body: appointment_book_hook_request_with_prefetch)

      result = run(test)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match('Resource does not conform to the profile: http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-patient')
      expect(patient_validation_request).to have_been_made
    end

    it 'fails if prefetch `patient` has wrong id' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)

      appointment_book_hook_request_with_prefetch['prefetch'][:patient]['id'] = 'incorrect_id'

      create_hook_request(body: appointment_book_hook_request_with_prefetch)

      result = run(test)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match("Expected `patient` field's FHIR resource to have an `id` of 'example'")
    end

    it 'fails if prefetch `coverage` is not a Coverage resource' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)

      appointment_book_hook_request_with_prefetch['prefetch'][:coverage].entry.first.resource =
        FHIR.from_contents(crd_practitioner.to_json)

      create_hook_request(body: appointment_book_hook_request_with_prefetch)

      result = run(test)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match('Unexpected resource type: expected Coverage, but received Practitioner')
    end

    it 'fails if prefetch `coverage` fails validation' do
      coverage_validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_failure.to_json)

      appointment_book_hook_request_with_prefetch['prefetch'].delete(:user)
      appointment_book_hook_request_with_prefetch['prefetch'].delete(:patient)

      create_hook_request(body: appointment_book_hook_request_with_prefetch)

      result = run(test)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match('Resource does not conform to the profile: http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-coverage')
      expect(coverage_validation_request).to have_been_made
    end

    it 'fails if prefetch `coverage` has wrong beneficiary id' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)

      appointment_book_hook_request_with_prefetch['prefetch'][:coverage].entry.first.resource.beneficiary.reference =
        'Patient/incorrect_id'

      create_hook_request(body: appointment_book_hook_request_with_prefetch)

      result = run(test)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(
        "Expected `coverage` field's Coverage resource to have a `beneficiary` reference id of"
      )
    end

    it 'fails if prefetch `coverage` has wrong status' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
      appointment_book_hook_request_with_prefetch['prefetch'][:coverage].entry.first.resource.status =
        'draft'

      create_hook_request(body: appointment_book_hook_request_with_prefetch)

      result = run(test)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(
        "Expected `coverage` field's Coverage resource to have a `status`"
      )
    end
  end

  describe 'Encounter Start Hook Valid Prefetch' do
    let(:test) do
      Class.new(DaVinciCRDTestKit::HookRequestValidPrefetchTest) do
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
          requests: { hook_request: { name: :encounter_start } }
        )
      end
    end

    it 'passes if prefetch contains valid resources for `user`, `patient`, and `encounter` fields' do
      validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_success.to_json)

      create_hook_request(body: encounter_start_hook_request_with_prefetch, hook_name: 'encounter_start')

      result = run(test)

      expect(result.result).to eq('pass')
      expect(validation_request).to have_been_made.times(4)
    end
  end

  describe 'Order Dispatch Hook Valid Prefetch' do
    let(:test) do
      Class.new(DaVinciCRDTestKit::HookRequestValidPrefetchTest) do
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
          options: { hook_name: 'order-dispatch' },
          requests: { hook_request: { name: :order_dispatch } }
        )
      end
    end

    it 'passes if prefetch contains valid resources for `performer`, `patient`, and `order` fields' do
      validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_success.to_json)

      create_hook_request(body: order_dispatch_hook_request_with_prefetch, hook_name: 'order_dispatch')

      result = run(test)

      expect(result.result).to eq('pass')
      expect(validation_request).to have_been_made.times(4)
    end
  end

  describe 'Order Select Hook Valid Prefetch' do
    let(:test) do
      Class.new(DaVinciCRDTestKit::HookRequestValidPrefetchTest) do
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
          options: { hook_name: 'order-select' },
          requests: { hook_request: { name: :order_select } }
        )
      end
    end

    it 'passes if prefetch contains valid resources for `user` and `patient` fields' do
      validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_success.to_json)

      create_hook_request(body: order_select_hook_request_with_prefetch, hook_name: 'order_select')

      result = run(test)

      expect(result.result).to eq('pass')
      expect(validation_request).to have_been_made.times(3)
    end
  end
end
