RSpec.describe DaVinciCRDTestKit::HookRequestPrefetchEqualsQueriedTest do
  let(:suite_id) { 'crd_client' }
  let(:runnable) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }

  let(:example_client_url) { 'https://cds.example.org' }
  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client" }
  let(:appointment_book_url) { "#{base_url}/cds-services/appointment-book-service" }
  let(:client_fhir_server) { 'https://example/r4' }
  let(:client_access_token) { 'SAMPLE_TOKEN' }
  let(:override_access_token) { 'ANOTHER_TOKEN' }
  let(:patient_id) { 'example' }

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

  def entity_result_message(runnable)
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .map(&:message)
      .join(' ')
  end

  def create_appointment_hook_request(url: appointment_book_url, body: nil, status: 200, headers: nil, auth_header: nil)
    headers ||= [
      {
        type: 'request',
        name: 'Authorization',
        value: auth_header
      }
    ]
    repo_create(
      :request,
      name: 'hook_request',
      direction: 'incoming',
      url:,
      result:,
      test_session_id: test_session.id,
      request_body: body.is_a?(Hash) ? body.to_json : body,
      status:,
      headers:,
      tags: ['appointment-book']
    )
  end

  describe 'Appointment Book Hook Prefetch' do
    let(:test) do
      Class.new(DaVinciCRDTestKit::HookRequestPrefetchEqualsQueriedTest) do
        config(
          options: { hook_name: 'appointment-book' }
        )
      end
    end

    describe 'For invalid inputs' do
      it 'skips when no requests made' do
        result = run(test)
        expect(result.result).to eq('skip')
        expect(result.result_message).to match(/No Hook Requests to verify./)
      end

      it 'skips when no fhir server and prefetch data to verify' do
        appointment_book_hook_request['prefetch'] = { user: crd_practitioner }
        create_appointment_hook_request(body: appointment_book_hook_request)
        result = run(test)
        expect(result.result).to eq('skip')
        expect(result.result_message)
          .to match(/No FHIR server provided in the hook request to use to validate the prefetch data./)
      end
    end

    describe 'When providing an override access token' do
      it 'uses the override token' do
        user_resource_request =
          stub_request(:get,
                       "#{client_fhir_server}/#{crd_practitioner['resourceType']}/#{crd_practitioner['id']}")
            .with(
              headers: { Authorization: "Bearer #{override_access_token}" }
            )
            .to_return(status: 200, body: crd_practitioner.to_json)
        appointment_book_hook_request['prefetch'] = { user: crd_practitioner }
        create_appointment_hook_request(body: appointment_book_hook_request)

        result = run(test, client_fhir_server:, client_access_token:, override_access_token:)
        expect(result.result).to eq('pass')
        expect(result.result_message).to match(/Prefetched data matches the requested queries./)
        expect(user_resource_request).to have_been_made.once
      end
    end

    describe 'When no prefetch data provided' do
      it 'passes when no prefetch field' do
        create_appointment_hook_request(body: appointment_book_hook_request)

        result = run(test)
        expect(result.result).to eq('pass')
        expect(result.result_message).to match(/No prefetched data provided./)
      end

      it 'passes when the prefetch hash is empty' do
        appointment_book_hook_request['prefetch'] = {}
        create_appointment_hook_request(body: appointment_book_hook_request)

        result = run(test)
        expect(result.result).to eq('pass')
        expect(result.result_message).to match(/No prefetched data provided./)
      end
    end

    describe 'When prefetched data matches queried data' do
      it 'passes for a prefetch read' do
        user_resource_request =
          stub_request(:get,
                       "#{client_fhir_server}/#{crd_practitioner['resourceType']}/#{crd_practitioner['id']}")
            .with(
              headers: { Authorization: "Bearer #{client_access_token}" }
            )
            .to_return(status: 200, body: crd_practitioner.to_json)
        appointment_book_hook_request['prefetch'] = { user: crd_practitioner }
        create_appointment_hook_request(body: appointment_book_hook_request)

        result = run(test, client_fhir_server:, client_access_token:)
        expect(result.result).to eq('pass')
        expect(result.result_message).to match(/Prefetched data matches the requested queries./)
        expect(user_resource_request).to have_been_made.once
      end

      it 'passes for a prefetch read (empty)' do
        user_resource_request =
          stub_request(:get,
                       "#{client_fhir_server}/#{crd_practitioner['resourceType']}/#{crd_practitioner['id']}")
            .with(
              headers: { Authorization: "Bearer #{client_access_token}" }
            )
            .to_return(status: 400)
        appointment_book_hook_request['prefetch'] = { user: nil }
        create_appointment_hook_request(body: appointment_book_hook_request)

        result = run(test, client_fhir_server:, client_access_token:)
        expect(result.result).to eq('pass')
        expect(result.result_message).to match(/Prefetched data matches the requested queries./)
        expect(user_resource_request).to have_been_made.once
      end

      it 'passes for a prefetch search' do
        coverage_resource_request =
          stub_request(:get, "#{client_fhir_server}/Coverage?patient=#{patient_id}&status=active")
            .with(
              headers: { Authorization: "Bearer #{client_access_token}" }
            )
            .to_return(status: 200, body: crd_coverage_bundle.to_json)
        appointment_book_hook_request['prefetch'] = { coverage: crd_coverage_bundle }
        create_appointment_hook_request(body: appointment_book_hook_request)

        result = run(test, client_fhir_server:, client_access_token:)
        expect(result.result).to eq('pass')
        expect(result.result_message).to match(/Prefetched data matches the requested queries./)
        expect(coverage_resource_request).to have_been_made.once
      end

      it 'passes for a prefetch search (empty)' do
        coverage_resource_request =
          stub_request(:get, "#{client_fhir_server}/Coverage?patient=#{patient_id}&status=active")
            .with(
              headers: { Authorization: "Bearer #{client_access_token}" }
            )
            .to_return(status: 200, body: FHIR::Bundle.new.to_json)
        appointment_book_hook_request['prefetch'] = { coverage: nil }
        create_appointment_hook_request(body: appointment_book_hook_request)

        result = run(test, client_fhir_server:, client_access_token:)
        expect(result.result).to eq('pass')
        expect(result.result_message).to match(/Prefetched data matches the requested queries./)
        expect(coverage_resource_request).to have_been_made.once
      end
    end

    describe 'When prefetched data does not match queried data' do
      it 'fails for a prefetch read where no data is returned for the read' do
        user_resource_request =
          stub_request(:get,
                       "#{client_fhir_server}/#{crd_practitioner['resourceType']}/#{crd_practitioner['id']}")
            .with(
              headers: { Authorization: "Bearer #{client_access_token}" }
            )
            .to_return(status: 400)
        appointment_book_hook_request['prefetch'] = { user: crd_practitioner }
        create_appointment_hook_request(body: appointment_book_hook_request)

        result = run(test, client_fhir_server:, client_access_token:)
        expect(result.result).to eq('fail')
        expect(user_resource_request).to have_been_made.once
        expect(result.result_message).to match(/Prefetched data does not match the requested queries./)
        expect(entity_result_message(test)).to match(
          %r{Prefetched data `user` was different than data returned from requested query `#{crd_practitioner['resourceType']}/#{crd_practitioner['id']}`} # rubocop:disable Layout/LineLength
        )
      end

      it 'fails for a prefetch search where extra data is returned in the query' do
        appointment_book_hook_request['prefetch'] = { coverage: crd_coverage_bundle }
        create_appointment_hook_request(body: appointment_book_hook_request)

        crd_coverage_bundle.entry.append(FHIR::Bundle::Entry.new(
                                           fullUrl: "#{example_client_url}/Coverage/coverage_example",
                                           resource: FHIR.from_contents(crd_coverage.to_json)
                                         ))
        coverage_resource_request =
          stub_request(:get, "#{client_fhir_server}/Coverage?patient=#{patient_id}&status=active")
            .with(
              headers: { Authorization: "Bearer #{client_access_token}" }
            )
            .to_return(status: 200, body: crd_coverage_bundle.to_json)

        result = run(test, client_fhir_server:, client_access_token:)
        expect(result.result).to eq('fail')
        expect(coverage_resource_request).to have_been_made.once
        expect(result.result_message).to match(/Prefetched data does not match the requested queries./)
        expect(entity_result_message(test)).to match(
          /Prefetched data `coverage` was different than data returned from requested query `Coverage\?patient=#{patient_id}&status=active`/ # rubocop:disable Layout/LineLength
        )
      end
    end
  end
end
