require_relative '../../lib/davinci_crd_test_kit/client_tests/hook_request_valid_prefetch_test'
require_relative '../../lib/davinci_crd_test_kit/jwt_helper'

RSpec.describe DaVinciCRDTestKit::HookRequestValidPrefetchTest do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('crd_client') }
  let(:runnable) { Inferno::Repositories::Tests.new.find('crd_hook_request_valid_prefetch') }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:results_repo) { Inferno::Repositories::Results.new }
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

  let(:appointment_book_prefetch) do
    { user: crd_practitioner, patient: crd_patient, coverage: crd_coverage_bundle }
  end
  let(:appointment_book_context) do
    appointment_book_hook_request['context']
  end
  let(:encounter_start_hook_prefetch) do
    { user: crd_practitioner, patient: crd_patient, encounter: crd_encounter,
      coverage: crd_coverage_bundle }
  end
  let(:encounter_start_context) do
    encounter_start_hook_request['context']
  end
  let(:order_dispatch_hook_prefetch) do
    { performer: crd_practitioner, patient: crd_patient, order: crd_service_request,
      coverage: crd_coverage_bundle }
  end
  let(:order_dispatch_context) do
    order_dispatch_hook_request['context']
  end
  let(:order_select_hook_prefetch) do
    { user: crd_practitioner, patient: crd_patient, coverage: crd_coverage_bundle }
  end
  let(:order_select_context) do
    order_select_hook_request['context']
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

  def entity_result_message(runnable)
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .map(&:message)
      .join(' ')
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
          options: { hook_name: 'appointment-book' }
        )
      end
    end

    it 'passes if prefetch contains valid resources for `user`, `patient`, and `coverage` fields' do
      validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_success.to_json)

      result = run(test,
                   contexts_prefetches: [{ context: appointment_book_context,
                                           prefetch: appointment_book_prefetch }].to_json)
      expect(result.result).to eq('pass')
      expect(validation_request).to have_been_made.times(3)
    end

    it 'passes if multiple requests have prefetch with valid resources for `user`, `patient`, and `coverage` fields' do
      validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_success.to_json)

      result = run(test,
                   contexts_prefetches: [{ context: appointment_book_context,
                                           prefetch: appointment_book_prefetch },
                                         { context: appointment_book_context,
                                           prefetch: appointment_book_prefetch }].to_json)
      expect(result.result).to eq('pass')
      expect(validation_request).to have_been_made.times(6)
    end

    it 'fails if one request of many has an invalid prefetch field' do
      validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_success.to_json)

      invalid_prefetch = { user: crd_practitioner, patient: crd_practitioner, coverage: crd_coverage_bundle }

      result = run(test,
                   contexts_prefetches: [{ context: appointment_book_context,
                                           prefetch: appointment_book_prefetch },
                                         { context: appointment_book_context,
                                           prefetch: invalid_prefetch }].to_json)
      expect(result.result).to eq('fail')
      expect(validation_request).to have_been_made.times(4)
      expect(entity_result_message(test)).to match(
        /Request 2: Unexpected resource type: expected Patient, but received Practitioner/
      )
    end

    it 'skips if hook request does not contain the `prefetch` field' do
      result = run(test, contexts_prefetches: [{ context: appointment_book_context,
                                                 prefetch: nil }].to_json)

      expect(result.result).to eq('skip')
      expect(result.result_message).to match(
        'No appointment-book requests contained both the `context` and `prefetch` field'
      )
    end

    it 'skips if hook request does not contain the `context` field' do
      result = run(test, contexts_prefetches: [{ context: nil,
                                                 prefetch: appointment_book_prefetch }].to_json)

      expect(result.result).to eq('skip')
      expect(result.result_message).to match(
        'No appointment-book requests contained both the `context` and `prefetch` field'
      )
    end

    it 'fails if prefetch `user` is not a valid resource type' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)

      appointment_book_prefetch[:user]['resourceType'] = 'Observation'

      result = run(test, contexts_prefetches: [{ context: appointment_book_context,
                                                 prefetch: appointment_book_prefetch }].to_json)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(
        /Unexpected resource type: expected Practitioner, but received Observation/
      )
    end

    it 'fails if prefetch `user` fails validation' do
      practitioner_validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_failure.to_json)

      appointment_book_prefetch.delete(:patient)
      appointment_book_prefetch.delete(:coverage)

      result = run(test, contexts_prefetches: [{ context: appointment_book_context,
                                                 prefetch: appointment_book_prefetch }].to_json)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(/Resource does not conform to profile/)
      expect(practitioner_validation_request).to have_been_made
    end

    it 'fails if prefetch `user` has wrong id' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)

      appointment_book_prefetch[:user]['id'] = 'incorrect_id'

      result = run(test, contexts_prefetches: [{ context: appointment_book_context,
                                                 prefetch: appointment_book_prefetch }].to_json)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(/Expected `user` field's FHIR resource to have an `id` of 'example'/)
    end

    it 'fails if prefetch `patient` is not a Patient resource' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)

      appointment_book_prefetch[:patient]['resourceType'] = 'Practitioner'

      result = run(test, contexts_prefetches: [{ context: appointment_book_context,
                                                 prefetch: appointment_book_prefetch }].to_json)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(
        /Unexpected resource type: expected Patient, but received Practitioner/
      )
    end

    it 'fails if prefetch `patient` fails validation' do
      patient_validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_failure.to_json)

      appointment_book_prefetch.delete(:user)
      appointment_book_prefetch.delete(:coverage)

      result = run(test, contexts_prefetches: [{ context: appointment_book_context,
                                                 prefetch: appointment_book_prefetch }].to_json)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(/Resource does not conform to profile/)
      expect(patient_validation_request).to have_been_made
    end

    it 'fails if prefetch `patient` has wrong id' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)

      appointment_book_prefetch[:patient]['id'] = 'incorrect_id'

      result = run(test, contexts_prefetches: [{ context: appointment_book_context,
                                                 prefetch: appointment_book_prefetch }].to_json)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(
        /Expected `patient` field's FHIR resource to have an `id` of 'example'/
      )
    end

    it 'fails if prefetch `coverage` is not a Coverage resource' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)

      appointment_book_prefetch[:coverage].entry.first.resource =
        FHIR.from_contents(crd_practitioner.to_json)

      result = run(test, contexts_prefetches: [{ context: appointment_book_context,
                                                 prefetch: appointment_book_prefetch }].to_json)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(
        /Unexpected resource type: expected Coverage, but received Practitioner/
      )
    end

    it 'fails if prefetch `coverage` fails validation' do
      coverage_validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_failure.to_json)

      appointment_book_prefetch.delete(:user)
      appointment_book_prefetch.delete(:patient)

      result = run(test, contexts_prefetches: [{ context: appointment_book_context,
                                                 prefetch: appointment_book_prefetch }].to_json)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(/Resource does not conform to profile/)
      expect(coverage_validation_request).to have_been_made
    end

    it 'fails if prefetch `coverage` has wrong beneficiary id' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)

      appointment_book_prefetch[:coverage].entry.first.resource.beneficiary.reference =
        'Patient/incorrect_id'

      result = run(test, contexts_prefetches: [{ context: appointment_book_context,
                                                 prefetch: appointment_book_prefetch }].to_json)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(
        /Expected `coverage` field's Coverage resource to have a `beneficiary` reference id of/
      )
    end

    it 'fails if prefetch `coverage` has wrong status' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
      appointment_book_prefetch[:coverage].entry.first.resource.status =
        'draft'

      result = run(test, contexts_prefetches: [{ context: appointment_book_context,
                                                 prefetch: appointment_book_prefetch }].to_json)
      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(/Expected `coverage` field's Coverage resource to have a `status`/)
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
          options: { hook_name: 'encounter-start' }
        )
      end
    end

    it 'passes if prefetch contains valid resources for `user`, `patient`, and `encounter` fields' do
      validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_success.to_json)

      result = run(test, contexts_prefetches: [{ context: encounter_start_context,
                                                 prefetch: encounter_start_hook_prefetch }].to_json)

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
          options: { hook_name: 'order-dispatch' }
        )
      end
    end

    it 'passes if prefetch contains valid resources for `performer`, `patient`, and `order` fields' do
      validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_success.to_json)

      result = run(test, contexts_prefetches: [{ context: order_dispatch_context,
                                                 prefetch: order_dispatch_hook_prefetch }].to_json)

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
          options: { hook_name: 'order-select' }
        )
      end
    end

    it 'passes if prefetch contains valid resources for `user` and `patient` fields' do
      validation_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_success.to_json)

      result = run(test, contexts_prefetches: [{ context: order_select_context,
                                                 prefetch: order_select_hook_prefetch }].to_json)

      expect(result.result).to eq('pass')
      expect(validation_request).to have_been_made.times(3)
    end
  end
end
