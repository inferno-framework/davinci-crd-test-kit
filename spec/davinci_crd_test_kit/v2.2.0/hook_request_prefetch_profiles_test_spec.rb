RSpec.describe DaVinciCRDTestKit::V220::HookRequestPrefetchProfilesTest do
  let(:suite_id) { 'crd_client' }
  let(:runnable) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }
  let(:example_client_url) { 'https://cds.example.org' }
  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client" }
  let(:order_sign_url) { "#{base_url}/cds-services/order-sign-service" }
  let(:test) do
    Class.new(described_class) do
      fhir_resource_validator do
        url ENV.fetch('FHIR_RESOURCE_VALIDATOR_URL', nil)

        cli_context do
          txServer nil
          displayWarnings true
          disableDefaultResourceFetcher true
        end

        igs('hl7.fhir.us.davinci-crd', 'hl7.fhir.us.core')
      end

      config(
        options: { hook_name: 'order-sign' }
      )
    end
  end

  let(:order_sign_request) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', '..', 'fixtures', 'order_sign_hook_request.json'
                ))
    )
  end
  let(:crd_patient_example) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', '..', 'fixtures', 'crd_patient_example.json'
                ))
    )
  end
  let(:crd_practitioner_example) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', '..', 'fixtures', 'crd_practitioner_example.json'
                ))
    )
  end
  let(:crd_example_bundle) do
    { 'resourceType' => 'Bundle',
      'entry' => [{ 'resource' => crd_patient_example }, { 'resource' => crd_practitioner_example }] }
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

  let(:operation_outcome_warning) do
    {
      outcomes: [{
        issues: [
          {
            level: 'WARNING',
            message: 'Resource has a potential issue'
          },
          {
            level: 'INFORMATION',
            message: 'For your information'
          }
        ]
      }],
      sessionId: 'b8cf5547-1dc7-4714-a797-dc2347b93fe2'
    }
  end

  def store_hook_request(hook_type, url: order_sign_url, body: nil, status: 200, headers: nil, auth_header: nil)
    if auth_header.present?
      headers ||= [
        {
          type: 'request',
          name: 'Authorization',
          value: auth_header
        }
      ]
    end
    repo_create(
      :request,
      direction: 'incoming',
      url:,
      result:,
      test_session_id: test_session.id,
      request_body: body.is_a?(Hash) ? body.to_json : body,
      status:,
      headers:,
      tags: [hook_type]
    )
  end

  def entity_result_message_text(runnable)
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .map(&:message)
      .join(' ')
  end

  def entity_result_messages(runnable)
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
  end

  describe 'when validating a single resource' do
    it 'passes if validation returns no messages' do
      validation_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('pass')
      expect(entity_result_messages(test).size).to eq(0)
      expect(validation_request).to have_been_made.once
    end

    it 'passes if validation returns only info and warning messages' do
      validation_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_warning.to_json)

      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('pass')
      expect(entity_result_messages(test).size).to eq(2)
      expect(entity_result_message_text(test))
        .to eq('(Request 1) Prefetch Template \'patient\' validation issue - ' \
               'Patient/example: unknown: Resource has a potential issue ' \
               '(Request 1) Prefetch Template \'patient\' validation issue - ' \
               'Patient/example: unknown: For your information')
      expect(validation_request).to have_been_made.once
    end

    it 'fails if validation returns an error message' do
      validation_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_failure.to_json)

      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message_text(test))
        .to eq('(Request 1) Prefetch Template \'patient\' validation issue - ' \
               'Patient/example: unknown: Resource does not conform to profile')
      expect(validation_request).to have_been_made.once
    end

    it 'does nothing (passes) if the contents is not a FHIR resource (validated elsewhere)' do
      validation_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      order_sign_request['prefetch'] = { 'patient' => { 'not' => 'FHIR' } }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('pass')
      expect(entity_result_messages(test).size).to eq(0)
      expect(validation_request).to_not have_been_made
    end

    it 'does nothing (passes) if there is no associated CRD profile (validated elsewhere)' do
      validation_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      order_sign_request['prefetch'] = { 'patient' => { 'resourceType' => 'StructureDefinition' } }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('pass')
      expect(entity_result_messages(test).size).to eq(0)
      expect(validation_request).to_not have_been_made
    end
  end

  describe 'when validating a Bundle' do
    it 'passes if all entry validations returns no messages' do
      validation_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      order_sign_request['prefetch'] = { 'patient' => crd_example_bundle }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('pass')
      expect(entity_result_messages(test).size).to eq(0)
      expect(validation_request).to have_been_made.times(2)
    end

    it 'passes if all entry validations returns only info and warning messages' do
      validation_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_warning.to_json)

      order_sign_request['prefetch'] = { 'patient' => crd_example_bundle }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('pass')
      expect(entity_result_messages(test).size).to eq(4)
      expect(entity_result_message_text(test))
        .to eq('(Request 1) Prefetch Template \'patient\' Bundle entry 1 validation issue - ' \
               'Patient/example: unknown: Resource has a potential issue ' \
               '(Request 1) Prefetch Template \'patient\' Bundle entry 1 validation issue - ' \
               'Patient/example: unknown: For your information ' \
               '(Request 1) Prefetch Template \'patient\' Bundle entry 2 validation issue - ' \
               'Practitioner/example: unknown: Resource has a potential issue ' \
               '(Request 1) Prefetch Template \'patient\' Bundle entry 2 validation issue - ' \
               'Practitioner/example: unknown: For your information')
      expect(validation_request).to have_been_made.times(2)
    end

    it 'fails if one entry validation returns an error message' do
      validation_request_patient = stub_request(:post, validation_url)
        .with(body: /\\"resourceType\\":\\"Patient\\"/)
        .to_return(status: 200, body: operation_outcome_success.to_json)
      validation_request_practitioner = stub_request(:post, validation_url)
        .with(body: /\\"resourceType\\":\\"Practitioner\\"/)
        .to_return(status: 200, body: operation_outcome_failure.to_json)

      order_sign_request['prefetch'] = { 'patient' => crd_example_bundle }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_messages(test).size).to eq(1)
      expect(entity_result_message_text(test))
        .to eq('(Request 1) Prefetch Template \'patient\' Bundle entry 2 validation issue - ' \
               'Practitioner/example: unknown: Resource does not conform to profile')
      expect(validation_request_patient).to have_been_made.once
      expect(validation_request_practitioner).to have_been_made.once
    end

    it 'does nothing (passes) if all entry contents are not FHIR resources (validated elsewhere)' do
      validation_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      order_sign_request['prefetch'] =
        { 'patient' => { 'resourceType' => 'Bundle',
                         'entry' => [{ 'resource' => { 'not' => 'FHIR' } },
                                     { 'resource' => { 'also_not' => 'FHIR' } }] } }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('pass')
      expect(entity_result_messages(test).size).to eq(0)
      expect(validation_request).to_not have_been_made
    end

    it 'does nothing (passes) if no entry contents have an associated CRD profile (validated elsewhere)' do
      validation_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      order_sign_request['prefetch'] =
        { 'patient' => { 'resourceType' => 'Bundle',
                         'entry' => [{ 'resource' => { 'resourceType' => 'StructureDefinition' } },
                                     { 'resource' => { 'resourceType' => 'StructureDefinition' } }] } }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('pass')
      expect(entity_result_messages(test).size).to eq(0)
      expect(validation_request).to_not have_been_made
    end
  end

  describe 'when multiple requests' do
    it 'includes a prefix with the request number on messages' do
      validation_request_patient = stub_request(:post, validation_url)
        .with(body: /\\"resourceType\\":\\"Patient\\"/)
        .to_return(status: 200, body: operation_outcome_success.to_json)
      validation_request_practitioner = stub_request(:post, validation_url)
        .with(body: /\\"resourceType\\":\\"Practitioner\\"/)
        .to_return(status: 200, body: operation_outcome_failure.to_json)

      order_sign_request['prefetch'] = { 'patient' => crd_patient_example }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      order_sign_request['prefetch'] = { 'practitioner' => crd_practitioner_example }
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('fail')
      expect(entity_result_message_text(test))
        .to eq('(Request 2) Prefetch Template \'practitioner\' validation issue - ' \
               'Practitioner/example: unknown: Resource does not conform to profile')
      expect(validation_request_patient).to have_been_made.once
      expect(validation_request_practitioner).to have_been_made.once
    end

    it 'passes if no requests have prefetch data (validated elsewhere)' do
      validation_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      store_hook_request('order-sign', url: order_sign_url, body: order_sign_request)
      results = run(test)

      expect(results.result).to eq('pass')
      expect(entity_result_messages(test).size).to eq(0)
      expect(validation_request).to_not have_been_made
    end
  end
end
