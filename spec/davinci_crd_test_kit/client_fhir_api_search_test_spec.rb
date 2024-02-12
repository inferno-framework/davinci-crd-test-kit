require_relative '../../lib/davinci_crd_test_kit/client_tests/client_fhir_api_search_test'

RSpec.describe DaVinciCRDTestKit::ClientFHIRApiSearchTest do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('crd_client') }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: 'crd_client') }

  let(:server_endpoint) { 'http://example.com/fhir' }
  let(:ehr_smart_credentials) do
    {
      access_token: 'SAMPLE_TOKEN',
      refresh_token: 'REFRESH_TOKEN',
      expires_in: 3600,
      client_id: 'CLIENT_ID',
      token_retrieval_time: Time.now.iso8601,
      token_url: 'http://example.com/token'
    }.to_json
  end

  let(:patient_id) { 'example' }
  let(:encounter_id) { 'example' }
  let(:encounter_include_search_request) do
    "#{server_endpoint}/Encounter?_id=#{encounter_id}&_include=Encounter:location"
  end
  let(:encounter_include_search_request_different_id) do
    "#{server_endpoint}/Encounter?_id=example2&_include=Encounter:location"
  end

  let(:crd_coverage_active) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'crd_coverage_example.json'
                ))
    )
  end

  let(:crd_coverage_cancelled) do
    crd_coverage_active.merge('status' => 'cancelled')
  end

  let(:crd_coverage_draft) do
    crd_coverage_active.merge('status' => 'draft')
  end

  let(:crd_coverage_entered_in_error) do
    crd_coverage_active.merge('status' => 'entered-in-error')
  end

  let(:crd_encounter) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'crd_encounter_example.json'
                ))
    )
  end

  let(:crd_encounter_second) do
    crd_encounter_second = crd_encounter.dup
    crd_encounter_second['id'] = 'example2'
    crd_encounter_second
  end

  let(:crd_location) do
    JSON.parse(
      File.read(File.join(
                  __dir__, '..', 'fixtures', 'crd_location_example.json'
                ))
    )
  end

  let(:operation_outcome) do
    FHIR::OperationOutcome.new(
      issue: [
        {
          severity: 'information',
          code: 'informational',
          details: {
            text: 'All OK'
          }
        }
      ]
    )
  end

  let(:crd_coverage_search_bundle_active) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Coverage/coverage_example",
                          resource: FHIR.from_contents(crd_coverage_active.to_json)
                        ))
    bundle
  end

  let(:crd_coverage_search_bundle_with_operation_outcome) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Coverage/coverage_example",
                          resource: FHIR.from_contents(crd_coverage_active.to_json)
                        ),
                        FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/OperationOutcome/operation_outcome_example",
                          resource: FHIR.from_contents(operation_outcome.to_json)
                        ))
    bundle
  end

  let(:crd_coverage_search_bundle_cancelled) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Coverage/coverage_example",
                          resource: FHIR.from_contents(crd_coverage_cancelled.to_json)
                        ))
    bundle
  end

  let(:crd_coverage_search_bundle_draft) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Coverage/coverage_example",
                          resource: FHIR.from_contents(crd_coverage_draft.to_json)
                        ))
    bundle
  end

  let(:crd_coverage_search_bundle_entered_in_error) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Coverage/coverage_example",
                          resource: FHIR.from_contents(crd_coverage_entered_in_error.to_json)
                        ))
    bundle
  end

  let(:crd_encounter_search_bundle) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Encounter/encounter_example",
                          resource: FHIR.from_contents(crd_encounter.to_json)
                        ))
    bundle
  end

  let(:crd_location_search_bundle) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Location/location_example",
                          resource: FHIR.from_contents(crd_location.to_json)
                        ))
    bundle
  end

  let(:crd_encounter_search_bundle_multiple_entries) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Encounter/encounter_example",
                          resource: FHIR.from_contents(crd_encounter.to_json)
                        ), FHIR::Bundle::Entry.new(
                             fullUrl: "#{server_endpoint}/Encounter/encounter_example2",
                             resource: FHIR.from_contents(crd_encounter_second.to_json)
                           ))
    bundle
  end

  let(:crd_encounter_search_bundle_wrong_entries) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Encounter/encounter_example",
                          resource: FHIR.from_contents(crd_encounter.to_json)
                        ), FHIR::Bundle::Entry.new(
                             fullUrl: "#{server_endpoint}/Encounter/encounter_example2",
                             resource: FHIR.from_contents(crd_coverage_active.to_json)
                           ))
    bundle
  end

  let(:crd_encounter_search_bundle_with_location) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Encounter/encounter_example",
                          resource: FHIR.from_contents(crd_encounter.to_json)
                        ), FHIR::Bundle::Entry.new(
                             fullUrl: "#{server_endpoint}/Encounter/encounter_example2",
                             resource: FHIR.from_contents(crd_location.to_json)
                           ))
    bundle
  end

  let(:crd_encounter_search_bundle_with_location_wrong_id) do
    crd_location['id'] = 'wrong_id'
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Encounter/encounter_example",
                          resource: FHIR.from_contents(crd_encounter.to_json)
                        ), FHIR::Bundle::Entry.new(
                             fullUrl: "#{server_endpoint}/Encounter/encounter_example2",
                             resource: FHIR.from_contents(crd_location.to_json)
                           ))
    bundle
  end

  let(:crd_encounter_search_bundle_with_operation_outcome) do
    bundle = FHIR::Bundle.new(type: 'searchset')
    bundle.entry.append(FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/Encounter/encounter_example",
                          resource: FHIR.from_contents(crd_encounter.to_json)
                        ),
                        FHIR::Bundle::Entry.new(
                          fullUrl: "#{server_endpoint}/OperationOutcome/operation_outcome_example",
                          resource: FHIR.from_contents(operation_outcome.to_json)
                        ))
    bundle
  end

  let(:empty_bundle) do
    FHIR::Bundle.new(type: 'searchset')
  end

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(
        test_session_id: test_session.id,
        name: runnable.config.input_name(name),
        value:,
        type: runnable.config.input_type(name)
      )
    end
    Inferno::TestRunner.new(test_session:, test_run:).run(runnable)
  end

  describe 'Coverage search test with reference search parameter `patient`' do
    let(:test) do
      Inferno::Repositories::Tests.new.find(
        'crd_client-crd_client_fhir_api-Group02-Group03-crd_client_coverage_patient_search_test'
      ) do
        fhir_client do
          url :url
          oauth_credentials :ehr_smart_credentials
        end
      end
    end

    it 'passes if valid Patient id is passed in that can be used to search for Coverage resources' do
      coverage_search_request = stub_request(:get, "#{server_endpoint}/Coverage?patient=#{patient_id}")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_coverage_search_bundle_active.to_json)

      result = run(test, search_param_values: patient_id, url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('pass')
      expect(coverage_search_request).to have_been_made
    end

    it 'passes if patient search result includes an OperationOutcome resource' do
      coverage_search_request = stub_request(:get, "#{server_endpoint}/Coverage?patient=#{patient_id}")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_coverage_search_bundle_with_operation_outcome.to_json)

      result = run(test, search_param_values: patient_id, url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('pass')
      expect(coverage_search_request).to have_been_made
    end

    it 'passes if at least 1 of list of Patient ids returns resources in Coverage search' do
      coverage_search_request = stub_request(:get, "#{server_endpoint}/Coverage?patient=#{patient_id}")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_coverage_search_bundle_active.to_json)
      coverage_search_request_empty = stub_request(:get, "#{server_endpoint}/Coverage?patient=example2")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: empty_bundle.to_json)

      patient_id_list = "#{patient_id}, example2"
      result = run(test, search_param_values: patient_id_list, url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('pass')
      expect(coverage_search_request).to have_been_made
      expect(coverage_search_request_empty).to have_been_made
    end

    it 'skips if no resources returned in Coverage search' do
      coverage_search_request_empty = stub_request(:get, "#{server_endpoint}/Coverage?patient=#{patient_id}")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: empty_bundle.to_json)
      coverage_search_request_empty_second = stub_request(:get, "#{server_endpoint}/Coverage?patient=example2")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: empty_bundle.to_json)

      patient_id_list = "#{patient_id}, example2"
      result = run(test, search_param_values: patient_id_list, url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('skip')
      expect(result.result_message).to eq('No resources returned in any of the search result bundles.')
      expect(coverage_search_request_empty).to have_been_made
      expect(coverage_search_request_empty_second).to have_been_made
    end

    it 'skips if no Patient ids are inputted' do
      result = run(test, search_param_values: '', url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('skip')
      expect(result.result_message).to eq('No search parameters passed in, skipping test.')
    end

    it 'fails if patient Coverage search returns non 200' do
      coverage_search_request = stub_request(:get, "#{server_endpoint}/Coverage?patient=#{patient_id}")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 400, body: crd_coverage_search_bundle_active.to_json)

      result = run(test, search_param_values: patient_id, url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Unexpected response status: expected 200, but received 400')
      expect(coverage_search_request).to have_been_made
    end

    it 'fails if patient Coverage search returns bundle with non Coverage resources' do
      coverage_search_request = stub_request(:get, "#{server_endpoint}/Coverage?patient=#{patient_id}")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter_search_bundle.to_json)

      result = run(test, search_param_values: patient_id, url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Unexpected resource type: expected Coverage, but received Encounter')
      expect(coverage_search_request).to have_been_made
    end

    it 'fails if patient Coverage search returns Coverage resource with incorrect beneficiary id' do
      coverage_search_request = stub_request(:get, "#{server_endpoint}/Coverage?patient=wrong_id")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_coverage_search_bundle_active.to_json)

      result = run(test, search_param_values: 'wrong_id', url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(
        'The Coverage resource in search result bundle with id coverage_example should have a\npatient'
      )
      expect(coverage_search_request).to have_been_made
    end
  end

  describe 'Coverage search test with `status` search parameter' do
    let(:test) do
      Inferno::Repositories::Tests.new.find(
        'crd_client-crd_client_fhir_api-Group02-Group03-crd_client_coverage_status_search_test'
      ) do
        fhir_client do
          url :url
          oauth_credentials :ehr_smart_credentials
        end
      end
    end

    it 'passes if all Coverage status search returns a valid bundle with Coverage resources' do
      active_coverage_search_request = stub_request(:get, "#{server_endpoint}/Coverage?status=active")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_coverage_search_bundle_active.to_json)
      cancelled_coverage_search_request = stub_request(:get, "#{server_endpoint}/Coverage?status=cancelled")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_coverage_search_bundle_cancelled.to_json)
      draft_coverage_search_request = stub_request(:get, "#{server_endpoint}/Coverage?status=draft")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_coverage_search_bundle_draft.to_json)
      entered_in_error_coverage_search_request =
        stub_request(:get, "#{server_endpoint}/Coverage?status=entered-in-error")
          .with(
            headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
          )
          .to_return(status: 200, body: crd_coverage_search_bundle_entered_in_error.to_json)

      result = run(test, url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('pass')
      expect(active_coverage_search_request).to have_been_made
      expect(cancelled_coverage_search_request).to have_been_made
      expect(draft_coverage_search_request).to have_been_made
      expect(entered_in_error_coverage_search_request).to have_been_made
    end

    it 'passes if status search result includes an OperationOutcome resource' do
      active_coverage_search_request = stub_request(:get, "#{server_endpoint}/Coverage?status=active")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_coverage_search_bundle_with_operation_outcome.to_json)
      cancelled_coverage_search_request = stub_request(:get, "#{server_endpoint}/Coverage?status=cancelled")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_coverage_search_bundle_cancelled.to_json)
      draft_coverage_search_request = stub_request(:get, "#{server_endpoint}/Coverage?status=draft")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_coverage_search_bundle_draft.to_json)
      entered_in_error_coverage_search_request =
        stub_request(:get, "#{server_endpoint}/Coverage?status=entered-in-error")
          .with(
            headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
          )
          .to_return(status: 200, body: crd_coverage_search_bundle_entered_in_error.to_json)

      result = run(test, url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('pass')
      expect(active_coverage_search_request).to have_been_made
      expect(cancelled_coverage_search_request).to have_been_made
      expect(draft_coverage_search_request).to have_been_made
      expect(entered_in_error_coverage_search_request).to have_been_made
    end

    it 'passes if at least 1 Coverage status search returns a valid bundle with Coverage resources' do
      active_coverage_search_request = stub_request(:get, "#{server_endpoint}/Coverage?status=active")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: empty_bundle.to_json)
      cancelled_coverage_search_request = stub_request(:get, "#{server_endpoint}/Coverage?status=cancelled")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: empty_bundle.to_json)
      draft_coverage_search_request = stub_request(:get, "#{server_endpoint}/Coverage?status=draft")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_coverage_search_bundle_draft.to_json)
      entered_in_error_coverage_search_request =
        stub_request(:get, "#{server_endpoint}/Coverage?status=entered-in-error")
          .with(
            headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
          )
          .to_return(status: 200, body: empty_bundle.to_json)

      result = run(test, url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('pass')
      expect(active_coverage_search_request).to have_been_made
      expect(cancelled_coverage_search_request).to have_been_made
      expect(draft_coverage_search_request).to have_been_made
      expect(entered_in_error_coverage_search_request).to have_been_made
    end

    it 'skips if all Coverage status search returns empty bundles' do
      active_coverage_search_request = stub_request(:get, "#{server_endpoint}/Coverage?status=active")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: empty_bundle.to_json)
      cancelled_coverage_search_request = stub_request(:get, "#{server_endpoint}/Coverage?status=cancelled")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: empty_bundle.to_json)
      draft_coverage_search_request = stub_request(:get, "#{server_endpoint}/Coverage?status=draft")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: empty_bundle.to_json)
      entered_in_error_coverage_search_request =
        stub_request(:get, "#{server_endpoint}/Coverage?status=entered-in-error")
          .with(
            headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
          )
          .to_return(status: 200, body: empty_bundle.to_json)

      result = run(test, url: server_endpoint, ehr_smart_credentials:)
      expect(result.result).to eq('skip')
      expect(result.result_message).to eq('No resources returned in any of the search result bundles.')
      expect(active_coverage_search_request).to have_been_made
      expect(cancelled_coverage_search_request).to have_been_made
      expect(draft_coverage_search_request).to have_been_made
      expect(entered_in_error_coverage_search_request).to have_been_made
    end

    it 'fails if status Coverage search returns non 200' do
      active_coverage_search_request = stub_request(:get, "#{server_endpoint}/Coverage?status=active")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 400, body: crd_coverage_search_bundle_active.to_json)

      result = run(test, url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Unexpected response status: expected 200, but received 400')
      expect(active_coverage_search_request).to have_been_made
    end

    it 'fails if status Coverage search returns bundle with non Coverage resources' do
      active_coverage_search_request = stub_request(:get, "#{server_endpoint}/Coverage?status=active")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter_search_bundle.to_json)

      result = run(test, url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Unexpected resource type: expected Coverage, but received Encounter')
      expect(active_coverage_search_request).to have_been_made
    end

    it 'fails if status Coverage search returns bundle with incorrect Coverage status' do
      active_coverage_search_request = stub_request(:get, "#{server_endpoint}/Coverage?status=active")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_coverage_search_bundle_cancelled.to_json)

      result = run(test, url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(
        'Each Coverage resource in search result bundle should have a status of `active`, instead got'
      )
      expect(active_coverage_search_request).to have_been_made
    end
  end

  describe 'Encounter search test with `_id` search parameter' do
    let(:test) do
      Inferno::Repositories::Tests.new.find(
        'crd_client-crd_client_fhir_api-Group02-Group06-crd_client_encounter_id_search_test'
      ) do
        fhir_client do
          url :url
          oauth_credentials :ehr_smart_credentials
        end
      end
    end

    it 'passes if valid Encounter id is passed in that can be used to search for Encounter resources' do
      encounter_search_request = stub_request(:get, "#{server_endpoint}/Encounter?_id=#{encounter_id}")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter_search_bundle.to_json)

      result = run(test, search_param_values: encounter_id, url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('pass')
      expect(encounter_search_request).to have_been_made
    end

    it 'passes if _id search result includes an OperationOutcome resource' do
      encounter_search_request = stub_request(:get, "#{server_endpoint}/Encounter?_id=#{encounter_id}")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter_search_bundle_with_operation_outcome.to_json)

      result = run(test, search_param_values: encounter_id, url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('pass')
      expect(encounter_search_request).to have_been_made
    end

    it 'passes if at least 1 of list of Encounter ids returns resources in Encounter _id search' do
      encounter_search_request = stub_request(:get, "#{server_endpoint}/Encounter?_id=#{encounter_id}")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter_search_bundle.to_json)
      encounter_search_request_empty = stub_request(:get, "#{server_endpoint}/Encounter?_id=example2")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: empty_bundle.to_json)

      encounter_id_list = "#{encounter_id}, example2"
      result = run(test, search_param_values: encounter_id_list, url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('pass')
      expect(encounter_search_request).to have_been_made
      expect(encounter_search_request_empty).to have_been_made
    end

    it 'skips if no resources returned in Encounter _id search' do
      encounter_search_request = stub_request(:get, "#{server_endpoint}/Encounter?_id=#{encounter_id}")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: empty_bundle.to_json)
      encounter_search_request_empty = stub_request(:get, "#{server_endpoint}/Encounter?_id=example2")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: empty_bundle.to_json)

      encounter_id_list = "#{encounter_id}, example2"
      result = run(test, search_param_values: encounter_id_list, url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('skip')
      expect(result.result_message).to eq('No resources returned in any of the search result bundles.')
      expect(encounter_search_request).to have_been_made
      expect(encounter_search_request_empty).to have_been_made
    end

    it 'skips if no Encounter ids are inputted' do
      result = run(test, search_param_values: '', url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('skip')
      expect(result.result_message).to eq('No search parameters passed in, skipping test.')
    end

    it 'fails if Encounter _id search returns non 200' do
      encounter_search_request = stub_request(:get, "#{server_endpoint}/Encounter?_id=#{encounter_id}")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 400, body: crd_encounter_search_bundle.to_json)

      result = run(test, search_param_values: encounter_id, url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Unexpected response status: expected 200, but received 400')
      expect(encounter_search_request).to have_been_made
    end

    it 'fails if Encounter _id search returns bundle with non Encounter resource' do
      encounter_search_request = stub_request(:get, "#{server_endpoint}/Encounter?_id=#{encounter_id}")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_coverage_search_bundle_active.to_json)

      result = run(test, search_param_values: encounter_id, url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Unexpected resource type: expected Encounter, but received Coverage')
      expect(encounter_search_request).to have_been_made
    end

    it 'fails if Encounter _id search returns Encounter resource with wrong id' do
      encounter_search_request = stub_request(:get, "#{server_endpoint}/Encounter?_id=wrong_id")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter_search_bundle.to_json)

      result = run(test, search_param_values: 'wrong_id', url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Expected resource to have id: `wrong_id`, but found `example`')
      expect(encounter_search_request).to have_been_made
    end
  end

  describe 'Encounter search test with `_include` search parameter' do
    let(:test) do
      Inferno::Repositories::Tests.new.find(
        'crd_client-crd_client_fhir_api-Group02-Group06-crd_client_encounter_location_include_test'
      ) do
        fhir_client do
          url :url
          oauth_credentials :ehr_smart_credentials
        end
      end
    end

    it 'passes if valid Encounter id is passed in that can be used to _include search for Encounter resources' do
      encounter_search_request = stub_request(:get, encounter_include_search_request)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter_search_bundle_with_location.to_json)

      result = run(test, search_param_values: encounter_id, url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('pass')
      expect(encounter_search_request).to have_been_made
    end

    it 'passes if _include search result includes an OperationOutcome resource' do
      encounter_search_request = stub_request(:get, encounter_include_search_request)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter_search_bundle_with_operation_outcome.to_json)

      result = run(test, search_param_values: encounter_id, url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('pass')
      expect(encounter_search_request).to have_been_made
    end

    it 'passes if at least 1 of list of Encounter ids returns resources in Encounter _include search' do
      encounter_search_request = stub_request(:get, encounter_include_search_request)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter_search_bundle_with_location.to_json)
      encounter_search_request_empty = stub_request(:get, encounter_include_search_request_different_id)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: empty_bundle.to_json)

      encounter_id_list = "#{encounter_id}, example2"
      result = run(test, search_param_values: encounter_id_list, url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('pass')
      expect(encounter_search_request).to have_been_made
      expect(encounter_search_request_empty).to have_been_made
    end

    it 'skips if no resources returned in Encounter _include search' do
      encounter_search_request = stub_request(:get, encounter_include_search_request)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: empty_bundle.to_json)
      encounter_search_request_empty = stub_request(:get, encounter_include_search_request_different_id)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: empty_bundle.to_json)

      encounter_id_list = "#{encounter_id}, example2"
      result = run(test, search_param_values: encounter_id_list, url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('skip')
      expect(result.result_message).to eq('No resources returned in any of the search result bundles.')
      expect(encounter_search_request).to have_been_made
      expect(encounter_search_request_empty).to have_been_made
    end

    it 'skips if no Encounter ids are inputted' do
      result = run(test, search_param_values: '', url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('skip')
      expect(result.result_message).to eq('No search parameters passed in, skipping test.')
    end

    it 'fails if Encounter _id search returns non 200' do
      encounter_search_request = stub_request(:get, encounter_include_search_request)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 400, body: crd_encounter_search_bundle_with_location.to_json)

      result = run(test, search_param_values: encounter_id, url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Unexpected response status: expected 200, but received 400')
      expect(encounter_search_request).to have_been_made
    end

    it 'fails if Encounter _include search returns a bundle with no Encounter resource' do
      encounter_search_request = stub_request(:get, encounter_include_search_request)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_location_search_bundle.to_json)

      result = run(test, search_param_values: encounter_id, url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(
        'should include exactly 1 Encounter resource, instead got 0'
      )
      expect(encounter_search_request).to have_been_made
    end

    it 'fails if Encounter _include search returns a bundle with more than 1 Encounter resource' do
      encounter_search_request = stub_request(:get, encounter_include_search_request)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter_search_bundle_multiple_entries.to_json)

      result = run(test, search_param_values: encounter_id, url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(
        'should include exactly 1 Encounter resource, instead got 2'
      )
      expect(encounter_search_request).to have_been_made
    end

    it 'fails if Encounter _include search returns a bundle with incorrect resource types' do
      encounter_search_request = stub_request(:get, encounter_include_search_request)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter_search_bundle_wrong_entries.to_json)

      result = run(test, search_param_values: encounter_id, url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match('Unexpected resource type: expected Location, but received Coverage')
      expect(encounter_search_request).to have_been_made
    end

    it 'fails if Encounter _include search returns a bundle with wrong Encounter id' do
      encounter_search_request = stub_request(:get, encounter_include_search_request_different_id)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter_search_bundle_with_location.to_json)

      result = run(test, search_param_values: 'example2', url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match('Expected resource to have id: `example2`, but found `example`')
      expect(encounter_search_request).to have_been_made
    end

    it 'fails if Encounter _id search returns Location resources that are not referenced by the Encounter resource' do
      encounter_search_request = stub_request(:get, encounter_include_search_request)
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 200, body: crd_encounter_search_bundle_with_location_wrong_id.to_json)

      result = run(test, search_param_values: encounter_id, url: server_endpoint, ehr_smart_credentials:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(
        'The Encounter resource in search result bundle with id example did not have a\nlocation reference'
      )
      expect(encounter_search_request).to have_been_made
    end
  end
end
