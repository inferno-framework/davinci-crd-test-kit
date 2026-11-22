require_relative '../../../../../lib/davinci_crd_test_kit/client/v2.2.1/verify_request/hook_request_granted_scopes_test'

RSpec.describe DaVinciCRDTestKit::V221::HookRequestGrantedScopesTest do
  let(:suite_id) { 'crd_client_v221' }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }

  let(:test) do
    Class.new(described_class) do
      config(options: { hook_name: 'appointment-book', crd_interaction_group: 'appointment-book' })
    end
  end

  let(:us_core_3_resources) { DaVinciCRDTestKit::CRDClientOptions::US_CORE_3_RESOURCE_TYPES }
  let(:us_core_6_7_resources) { DaVinciCRDTestKit::CRDClientOptions::US_CORE_6_7_RESOURCE_TYPES }

  def resource_scopes(resources, level: 'user', interaction: 'rs')
    resources.map { |r| "#{level}/#{r}.#{interaction}" }.join(' ')
  end

  def create_hook_request(scope:, tags: ['appointment-book'])
    body = {
      'hookInstance' => 'd1577c69-dfbe-44ad-ba6d-3e05e953b2ea',
      'hook' => 'appointment-book',
      'fhirAuthorization' => {
        'access_token' => 'SAMPLE_TOKEN',
        'token_type' => 'Bearer',
        'expires_in' => 300,
        'scope' => scope,
        'subject' => 'cds-service'
      }
    }
    repo_create(
      :request,
      direction: 'incoming',
      url: 'https://example.com/cds-services/appointment-book-service',
      result:,
      test_session_id: test_session.id,
      request_body: body.to_json,
      status: 200,
      tags:
    )
  end

  def result_messages
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [test])
      .first
      .messages
  end

  def us_core_session(version)
    repo_create(:test_session, test_suite_id: suite_id, suite_options: [
                  Inferno::DSL::SuiteOption.new(id: :us_core_version, value: version)
                ])
  end

  it 'skips when no hook requests have been received' do
    result = run(test)
    expect(result.result).to eq('skip')
    expect(result.result_message).to include('No appointment-book hook requests received')
  end

  context 'with US Core 3 selected' do
    let(:test_session) { us_core_session(DaVinciCRDTestKit::CRDClientOptions::US_CORE_3) }

    it 'passes with valid user-level resource scopes' do
      create_hook_request(scope: resource_scopes(us_core_3_resources, level: 'user'))
      result = run(test)
      expect(result.result).to eq('pass')
    end

    it 'passes with valid patient-level resource scopes' do
      create_hook_request(scope: resource_scopes(us_core_3_resources, level: 'patient'))
      result = run(test)
      expect(result.result).to eq('pass')
    end

    it 'passes with multiple valid requests' do
      create_hook_request(scope: resource_scopes(us_core_3_resources, level: 'user'))
      create_hook_request(scope: resource_scopes(us_core_3_resources, level: 'patient'))
      result = run(test)
      expect(result.result).to eq('pass')
    end

    it 'fails when granted scopes are missing required resource types' do
      partial_resources = us_core_3_resources - ['Patient', 'Condition']
      create_hook_request(scope: resource_scopes(partial_resources))
      result = run(test)
      expect(result.result).to eq('fail')
      messages = result_messages.map(&:message)
      missing_message = messages.find { |m| m.include?('missing the following requested resource types') }
      expect(missing_message).to be_present
      expect(missing_message).to include('Patient')
      expect(missing_message).to include('Condition')
    end

    it 'fails when granted scopes include resource types that were not requested' do
      extra_resources = us_core_3_resources + ['Claim', 'Specimen']
      create_hook_request(scope: resource_scopes(extra_resources))
      result = run(test)
      expect(result.result).to eq('fail')
      messages = result_messages.map(&:message)
      extra_message = messages.find { |m| m.include?('beyond what was requested') }
      expect(extra_message).to be_present
      expect(extra_message).to include('Claim')
      expect(extra_message).to include('Specimen')
    end

    it 'passes when Coverage and ServiceRequest, which are not US Core 3.1.1 types, are also granted' do
      create_hook_request(scope: resource_scopes(us_core_3_resources + ['Coverage', 'ServiceRequest']))
      result = run(test)
      expect(result.result).to eq('pass')
    end

    it 'passes with a warning when all granted scopes use SMART v1 read interactions' do
      create_hook_request(scope: resource_scopes(us_core_3_resources, interaction: 'read'))
      result = run(test)
      expect(result.result).to eq('pass')
      expect(result_messages.map(&:message)).to include(include('SMART v1 `read` scope used'))
    end

    it 'passes with a warning when SMART v1 read and v2 rs scopes are mixed' do
      mixed_scope = "#{resource_scopes(us_core_3_resources.first(10), interaction: 'rs')} " \
                    "#{resource_scopes(us_core_3_resources.drop(10), interaction: 'read')}"
      create_hook_request(scope: mixed_scope)
      result = run(test)
      expect(result.result).to eq('pass')
      expect(result_messages.map(&:message)).to include(include('SMART v1 `read` scope used'))
    end

    it 'fails when granted scopes use an unrecognized access level' do
      scope = "#{resource_scopes(us_core_3_resources - ['Patient'])} user/Patient.view"
      create_hook_request(scope:)
      result = run(test)
      expect(result.result).to eq('fail')
      expect(result_messages.map(&:message)).to include(match(%r{unrecognized access level.*user/Patient\.view}))
    end

    it 'fails when granted scopes mix user and patient levels' do
      half = us_core_3_resources.length / 2
      mixed_scope = [
        resource_scopes(us_core_3_resources.first(half), level: 'user'),
        resource_scopes(us_core_3_resources.last(us_core_3_resources.length - half), level: 'patient')
      ].join(' ')
      create_hook_request(scope: mixed_scope)
      result = run(test)
      expect(result.result).to eq('fail')
      expect(result_messages.map(&:message)).to include(include('did not use a consistent level of scope'))
    end

    it 'fails when granted scopes use an unexpected scope level' do
      create_hook_request(scope: resource_scopes(us_core_3_resources, level: 'system'))
      result = run(test)
      expect(result.result).to eq('fail')
      expect(result_messages.map(&:message)).to include(match(/Unexpected level for granted scopes.*system/))
    end

    it 'reports the request number when one of multiple requests fails' do
      create_hook_request(scope: resource_scopes(us_core_3_resources, level: 'user'))
      create_hook_request(scope: resource_scopes(us_core_3_resources, level: 'user', interaction: 'cruds'))
      result = run(test)
      expect(result.result).to eq('fail')
      expect(result_messages.map(&:message)).to include(match(/\(Request 2\).*create, update, or delete/))
    end
  end

  context 'with US Core 6 selected' do
    let(:test_session) { us_core_session(DaVinciCRDTestKit::CRDClientOptions::US_CORE_6) }

    it 'passes with valid user-level resource scopes' do
      create_hook_request(scope: resource_scopes(us_core_6_7_resources, level: 'user'))
      result = run(test)
      expect(result.result).to eq('pass')
    end

    it 'fails when US Core 3 resources are granted instead of US Core 6' do
      create_hook_request(scope: resource_scopes(us_core_3_resources))
      result = run(test)
      expect(result.result).to eq('fail')
      expect(result_messages.map(&:message)).to include(include('missing the following requested resource types'))
    end

    ['Appointment', 'CommunicationRequest', 'DeviceRequest', 'NutritionOrder', 'VisionPrescription'].each do |type|
      it "passes when the CRD request type #{type} is also granted" do
        create_hook_request(scope: resource_scopes(us_core_6_7_resources + [type]))
        result = run(test)
        expect(result.result).to eq('pass')
      end
    end

    it 'passes when a CRD request type is granted with only read access' do
      create_hook_request(scope: "#{resource_scopes(us_core_6_7_resources)} user/DeviceRequest.r")
      result = run(test)
      expect(result.result).to eq('pass')
    end

    it 'fails when a resource type that is neither US Core nor a CRD request type is granted' do
      create_hook_request(scope: resource_scopes(us_core_6_7_resources + ['DeviceRequest', 'Claim']))
      result = run(test)
      expect(result.result).to eq('fail')
      extra_message = result_messages.map(&:message).find { |m| m.include?('beyond what was requested') }
      expect(extra_message).to include('Claim')
      expect(extra_message).to_not include('DeviceRequest')
    end

    it 'passes when read and search are granted as separate scopes' do
      scope = "#{resource_scopes(us_core_6_7_resources, interaction: 'r')} " \
              "#{resource_scopes(us_core_6_7_resources, interaction: 's')}"
      create_hook_request(scope:)
      result = run(test)
      expect(result.result).to eq('pass')
    end

    it 'fails when a US Core resource type is granted read but not search' do
      scope = "#{resource_scopes(us_core_6_7_resources - ['Patient'])} user/Patient.r"
      create_hook_request(scope:)
      result = run(test)
      expect(result.result).to eq('fail')
      expect(result_messages.map(&:message))
        .to include(match(/do not provide both read and search access.*Patient/))
    end

    it 'fails when granted scopes include create, update, or delete access' do
      scope = "#{resource_scopes(us_core_6_7_resources - ['Patient'])} user/Patient.cruds"
      create_hook_request(scope:)
      result = run(test)
      expect(result.result).to eq('fail')
      expect(result_messages.map(&:message)).to include(match(%r{create, update, or delete.*user/Patient\.cruds}))
    end

    it 'fails when a CRD request type is granted write access' do
      create_hook_request(scope: "#{resource_scopes(us_core_6_7_resources)} user/DeviceRequest.cruds")
      result = run(test)
      expect(result.result).to eq('fail')
      expect(result_messages.map(&:message))
        .to include(match(%r{create, update, or delete.*user/DeviceRequest\.cruds}))
    end

    it 'fails when granted scopes use the SMART v1 write or * access levels' do
      scope = "#{resource_scopes(us_core_6_7_resources - ['Patient', 'Condition'])} " \
              'user/Patient.write user/Patient.read user/Condition.*'
      create_hook_request(scope:)
      result = run(test)
      expect(result.result).to eq('fail')
      write_message = result_messages.map(&:message).find { |m| m.include?('create, update, or delete') }
      expect(write_message).to include('user/Patient.write')
      expect(write_message).to include('user/Condition.*')
    end

    it 'fails when a wildcard resource scope is granted' do
      create_hook_request(scope: 'user/*.rs')
      result = run(test)
      expect(result.result).to eq('fail')
      expect(result_messages.map(&:message)).to include(match(%r{wildcard.*user/\*\.rs}))
    end

    it 'fails when a wildcard resource scope is granted along with the requested scopes' do
      create_hook_request(scope: "#{resource_scopes(us_core_6_7_resources)} user/*.*")
      result = run(test)
      expect(result.result).to eq('fail')
      messages = result_messages.map(&:message)
      expect(messages).to include(match(%r{wildcard.*user/\*\.\*}))
      expect(messages).to_not include(include('beyond what was requested'))
    end

    it 'fails when a US Core resource type is only granted through a granular scope' do
      scope = "#{resource_scopes(us_core_6_7_resources - ['Observation'])} " \
              'user/Observation.rs?category=http://terminology.hl7.org/CodeSystem/observation-category|laboratory'
      create_hook_request(scope:)
      result = run(test)
      expect(result.result).to eq('fail')
      missing_message = result_messages.map(&:message)
        .find { |m| m.include?('missing the following requested resource types') }
      expect(missing_message).to include('Observation')
      expect(missing_message).to include('search parameters')
    end
  end

  context 'with US Core 7 selected' do
    let(:test_session) { us_core_session(DaVinciCRDTestKit::CRDClientOptions::US_CORE_7) }

    it 'passes with valid user-level resource scopes' do
      create_hook_request(scope: resource_scopes(us_core_6_7_resources, level: 'user'))
      result = run(test)
      expect(result.result).to eq('pass')
    end

    it 'passes when the CRD request type Appointment is also granted' do
      create_hook_request(scope: resource_scopes(us_core_6_7_resources + ['Appointment']))
      result = run(test)
      expect(result.result).to eq('pass')
    end
  end

  describe 'when a crd_interaction_group is configured' do
    let(:test) do
      Class.new(described_class) do
        config(options: { hook_name: 'appointment-book', crd_interaction_group: 'some-group' })
      end
    end

    let(:test_session) { us_core_session(DaVinciCRDTestKit::CRDClientOptions::US_CORE_3) }

    it 'only loads requests tagged with both the hook name and group tag' do
      create_hook_request(scope: 'invalid-scopes', tags: ['appointment-book'])
      create_hook_request(scope: resource_scopes(us_core_3_resources), tags: ['appointment-book', 'some-group'])
      result = run(test)
      expect(result.result).to eq('pass')
    end
  end
end
