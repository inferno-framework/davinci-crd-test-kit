require_relative '../../../../../lib/davinci_crd_test_kit/cross_suite/tags'

RSpec.describe DaVinciCRDTestKit::V221::HookRequestCoverageVerificationTest do
  let(:suite_id) { 'crd_client_v221' }
  let(:runnable) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }
  let(:hook_name) { 'order-sign' }
  let(:hook_instance) { 'd1577c69-dfbe-44ad-ba6d-3e05e953b2ea' }
  let(:payer_org_id) { 'inferno-payer-org' }

  let(:test) do
    Class.new(described_class) do
      config(options: { hook_name: 'order-sign' })
    end
  end

  let(:coverage_resource) do
    {
      'resourceType' => 'Coverage',
      'payor' => [{ 'reference' => "Organization/#{payer_org_id}" }]
    }
  end

  let(:hook_request_body) do
    {
      'hookInstance' => hook_instance,
      'hook' => hook_name,
      'prefetch' => {
        'coverage' => {
          'resourceType' => 'Bundle',
          'entry' => [{ 'resource' => coverage_resource }]
        }
      }
    }
  end

  let(:payer_organization) do
    { 'resourceType' => 'Organization', 'id' => payer_org_id }
  end

  def create_hook_request(body: hook_request_body, tags: [hook_name])
    repo_create(
      :request,
      direction: 'incoming',
      url: "https://example.com/cds-services/#{hook_name}-service",
      result:,
      test_session_id: test_session.id,
      request_body: body.is_a?(Hash) ? body.to_json : body,
      status: 200,
      headers: [],
      tags:
    )
  end

  def create_payer_fetch_request(response_body: payer_organization, status: 200,
                                 instance: hook_instance)
    repo_create(
      :request,
      direction: 'outgoing',
      url: "https://example.com/fhir/Organization/#{payer_org_id}",
      result:,
      test_session_id: test_session.id,
      response_body: response_body.is_a?(Hash) ? response_body.to_json : response_body,
      status:,
      headers: [],
      tags: [DaVinciCRDTestKit::PAYER_ORG_FETCH_TAG,
             DaVinciCRDTestKit::TagMethods.hook_instance_data_fetch_tag(instance),
             DaVinciCRDTestKit::DATA_FETCH_TAG]
    )
  end

  def result_messages
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
  end

  it 'fails when complete_prefetch_service_organization_id is blank and complete endpoint requests are received' do
    create_hook_request(body: { 'hookInstance' => hook_instance, 'hook' => hook_name })
    result = run(test, complete_prefetch_service_organization_id: '',
                       subset_prefetch_service_organization_id: payer_org_id)
    expect(result.result).to eq('fail')
    expect(result_messages.map(&:message).join).to match(/No Inferno Payer Organization id configured/)
  end

  it 'fails when subset_prefetch_service_organization_id is blank and subset endpoint requests are received' do
    repo_create(
      :request,
      direction: 'incoming',
      url: "https://example.com/prefetch-subset/cds-services/#{hook_name}",
      result:,
      test_session_id: test_session.id,
      request_body: { 'hookInstance' => hook_instance, 'hook' => hook_name }.to_json,
      status: 200,
      headers: [],
      tags: [hook_name]
    )
    result = run(test, complete_prefetch_service_organization_id: payer_org_id,
                       subset_prefetch_service_organization_id: '')
    expect(result.result).to eq('fail')
    expect(result_messages.map(&:message).join).to match(/No Inferno Payer Organization id configured/)
  end

  it 'skips when no hook requests received' do
    result = run(test, complete_prefetch_service_organization_id: payer_org_id,
                       subset_prefetch_service_organization_id: payer_org_id)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/No #{hook_name} hook requests received/)
  end

  it 'passes with a warning when no coverage is present in the prefetch' do
    create_hook_request(body: { 'hookInstance' => hook_instance, 'hook' => hook_name })
    result = run(test, complete_prefetch_service_organization_id: payer_org_id,
                       subset_prefetch_service_organization_id: payer_org_id)
    expect(result.result).to eq('pass')
    expect(result_messages.map(&:message).join).to match(/Request has no coverage/)
  end

  it 'passes when coverage payer matches the expected organization and passes validation' do
    allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
    create_hook_request
    create_payer_fetch_request
    result = run(test, complete_prefetch_service_organization_id: payer_org_id,
                       subset_prefetch_service_organization_id: payer_org_id)
    expect(result.result).to eq('pass')
  end

  it 'fails when coverage has no payer reference' do
    no_payer_coverage = { 'resourceType' => 'Coverage' }
    body = hook_request_body.deep_merge(
      'prefetch' => { 'coverage' => { 'entry' => [{ 'resource' => no_payer_coverage }] } }
    )
    create_hook_request(body:)
    result = run(test, complete_prefetch_service_organization_id: payer_org_id,
                       subset_prefetch_service_organization_id: payer_org_id)
    expect(result.result).to eq('fail')
    expect(result_messages.map(&:message).join).to match(/Coverage has no payer reference/)
  end

  it 'fails when Inferno did not successfully retrieve the payer during hook processing' do
    create_hook_request
    # No payer fetch request stored
    result = run(test, complete_prefetch_service_organization_id: payer_org_id,
                       subset_prefetch_service_organization_id: payer_org_id)
    expect(result.result).to eq('fail')
    expect(result_messages.map(&:message).join).to match(/failed to retrieve the Coverage's payer/)
  end

  it 'fails when the payer fetch request returned a non-2xx status' do
    create_hook_request
    create_payer_fetch_request(status: 404)
    result = run(test, complete_prefetch_service_organization_id: payer_org_id,
                       subset_prefetch_service_organization_id: payer_org_id)
    expect(result.result).to eq('fail')
    expect(result_messages.map(&:message).join).to match(/failed to retrieve the Coverage's payer/)
  end

  it 'fails when the payer fetch response is not valid FHIR' do
    create_hook_request
    create_payer_fetch_request(response_body: '{"not": "fhir"}')
    result = run(test, complete_prefetch_service_organization_id: payer_org_id,
                       subset_prefetch_service_organization_id: payer_org_id)
    expect(result.result).to eq('fail')
    expect(result_messages.map(&:message).join).to match(/returned invalid FHIR data/)
  end

  it 'fails when the payer resource is not an Organization' do
    allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
    create_hook_request
    create_payer_fetch_request(response_body: { 'resourceType' => 'Patient', 'id' => payer_org_id })
    result = run(test, complete_prefetch_service_organization_id: payer_org_id,
                       subset_prefetch_service_organization_id: payer_org_id)
    expect(result.result).to eq('fail')
    expect(result_messages.map(&:message).join).to match(/Payer for the Coverage is not an Organization/)
  end

  it 'fails when payer organization id does not match expected' do
    allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
    create_hook_request
    create_payer_fetch_request(response_body: { 'resourceType' => 'Organization', 'id' => 'wrong-id' })
    result = run(test, complete_prefetch_service_organization_id: payer_org_id,
                       subset_prefetch_service_organization_id: payer_org_id)
    expect(result.result).to eq('fail')
    expect(result_messages.map(&:message).join).to match(/Payer for the Coverage has the wrong id/)
  end

  it 'fails when the payer resource does not conform to the CRD Organization profile' do
    allow_any_instance_of(test).to receive(:resource_is_valid?) do |instance|
      instance.add_message('error', 'Resource does not conform to profile')
      false
    end
    create_hook_request
    create_payer_fetch_request
    result = run(test, complete_prefetch_service_organization_id: payer_org_id,
                       subset_prefetch_service_organization_id: payer_org_id)
    expect(result.result).to eq('fail')
    expect(result_messages.map(&:message).join).to match(/does not conform to profile/)
  end

  it 'includes request number in error message for the failing request' do
    allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
    second_instance = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
    no_payer_coverage = { 'resourceType' => 'Coverage' }
    second_body = {
      'hookInstance' => second_instance,
      'hook' => hook_name,
      'prefetch' => {
        'coverage' => {
          'resourceType' => 'Bundle',
          'entry' => [{ 'resource' => no_payer_coverage }]
        }
      }
    }
    create_hook_request
    create_payer_fetch_request
    create_hook_request(body: second_body)
    result = run(test, complete_prefetch_service_organization_id: payer_org_id,
                       subset_prefetch_service_organization_id: payer_org_id)
    expect(result.result).to eq('fail')
    expect(result_messages.map(&:message).join).to match(/\(Request 2\).*Coverage has no payer reference/m)
  end

  describe 'when the request was sent to the prefetch-subset endpoint' do
    let(:subset_payer_org_id) { 'inferno-subset-payer-org' }
    let(:subset_payer_organization) { { 'resourceType' => 'Organization', 'id' => subset_payer_org_id } }
    let(:subset_hook_request_body) do
      {
        'hookInstance' => hook_instance,
        'hook' => hook_name,
        'prefetch' => {
          'coverage' => {
            'resourceType' => 'Bundle',
            'entry' => [{ 'resource' => {
              'resourceType' => 'Coverage',
              'payor' => [{ 'reference' => "Organization/#{subset_payer_org_id}" }]
            } }]
          }
        }
      }
    end

    def create_subset_hook_request(body: subset_hook_request_body, tags: [hook_name])
      repo_create(
        :request,
        direction: 'incoming',
        url: "https://example.com/prefetch-subset/cds-services/#{hook_name}-subset",
        result:,
        test_session_id: test_session.id,
        request_body: body.is_a?(Hash) ? body.to_json : body,
        status: 200,
        headers: [],
        tags:
      )
    end

    it 'uses subset_prefetch_service_organization_id for coverage verification' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
      create_subset_hook_request
      create_payer_fetch_request(response_body: subset_payer_organization)
      result = run(test, complete_prefetch_service_organization_id: payer_org_id,
                         subset_prefetch_service_organization_id: subset_payer_org_id)
      expect(result.result).to eq('pass')
    end

    it 'fails when the payer id does not match the subset org id' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
      create_subset_hook_request
      create_payer_fetch_request(response_body: { 'resourceType' => 'Organization', 'id' => 'wrong-id' })
      result = run(test, complete_prefetch_service_organization_id: payer_org_id,
                         subset_prefetch_service_organization_id: subset_payer_org_id)
      expect(result.result).to eq('fail')
      expect(result_messages.map(&:message).join).to match(/Payer for the Coverage has the wrong id/)
    end

    it 'does not use complete_prefetch_service_organization_id for subset endpoint requests' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
      create_subset_hook_request
      # Return the main payer org id instead of the subset org id — should still fail
      create_payer_fetch_request(response_body: payer_organization)
      result = run(test, complete_prefetch_service_organization_id: payer_org_id,
                         subset_prefetch_service_organization_id: subset_payer_org_id)
      expect(result.result).to eq('fail')
      expect(result_messages.map(&:message).join).to match(/Payer for the Coverage has the wrong id/)
    end
  end

  describe 'when a crd_test_group is configured' do
    let(:test) do
      Class.new(described_class) do
        config(options: { hook_name: 'order-sign', crd_test_group: 'some-group' })
      end
    end

    it 'only loads requests that have both the hook tag and the group tag' do
      allow_any_instance_of(test).to receive(:resource_is_valid?).and_return(true)
      # This request lacks the group tag and has invalid coverage — should be ignored
      invalid_body = hook_request_body.deep_merge(
        'prefetch' => { 'coverage' => { 'entry' => [{ 'resource' => { 'resourceType' => 'Coverage' } }] } }
      )
      create_hook_request(body: invalid_body, tags: [hook_name])
      # This request has both tags and is valid
      create_hook_request(tags: [hook_name, 'some-group'])
      create_payer_fetch_request
      result = run(test, complete_prefetch_service_organization_id: payer_org_id,
                         subset_prefetch_service_organization_id: payer_org_id)
      expect(result.result).to eq('pass')
    end
  end
end
