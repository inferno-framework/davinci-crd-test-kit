RSpec.describe DaVinciCRDTestKit::V221::ClientMultiplePayersRequestVerificationTest do
  let(:suite_id) { 'crd_client_v221' }
  let(:test) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }

  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client_v221" }
  let(:complete_service_url) { "#{base_url}/cds-services/order-sign-service" }
  let(:subset_service_url) { "#{base_url}/prefetch-subset/cds-services/order-sign-subset" }

  let(:primary_request_body) do
    {
      'hook' => 'order-sign',
      'hookInstance' => 'hook-instance-primary',
      'fhirServer' => 'https://ehr.example.org/fhir',
      'fhirAuthorization' => { 'access_token' => 'token-primary' },
      'context' => {
        'userId' => 'Practitioner/example',
        'patientId' => 'example',
        'draftOrders' => {
          'resourceType' => 'Bundle',
          'entry' => [
            {
              'resource' => {
                'resourceType' => 'ServiceRequest',
                'id' => 'example-request',
                'insurance' => [{ 'reference' => 'Coverage/coverage-primary' }]
              }
            }
          ]
        }
      },
      'prefetch' => {
        'coverage' => {
          'resourceType' => 'Bundle',
          'entry' => [
            {
              'resource' => {
                'resourceType' => 'Coverage',
                'id' => 'coverage-primary',
                'payor' => [{ 'reference' => 'Organization/payer-primary' }]
              }
            }
          ]
        }
      }
    }
  end

  let(:secondary_request_body) do
    primary_request_body.deep_dup.tap do |request_body|
      request_body['hookInstance'] = 'hook-instance-secondary'
      request_body['fhirAuthorization'] = { 'access_token' => 'token-secondary' }
      request_body['context']['draftOrders']['entry'].first['resource']['insurance'] =
        [{ 'reference' => 'Coverage/coverage-secondary' }]
      request_body['prefetch']['coverage']['entry'].first['resource'] = {
        'resourceType' => 'Coverage',
        'id' => 'coverage-secondary',
        'payor' => [{ 'reference' => 'Organization/payer-secondary' }]
      }
      request_body['extension'] = { 'davinci-crd.configuration' => { 'coverage-info' => false } }
    end
  end

  let(:payer_inputs) do
    { complete_prefetch_service_organization_id: 'payer-primary',
      subset_prefetch_service_organization_id: 'payer-secondary' }
  end
  let(:fetch_result) { repo_create(:result, test_session_id: test_session.id) }

  # the payer reads Inferno makes while processing each hook request
  def create_payer_fetch(hook_instance, payer_id)
    repo_create(:request, direction: 'outgoing', test_session_id: test_session.id, result: fetch_result,
                          url: "https://ehr.example.org/fhir/Organization/#{payer_id}", status: 200,
                          response_body: { resourceType: 'Organization', id: payer_id }.to_json,
                          tags: [DaVinciCRDTestKit::PAYER_ORG_FETCH_TAG,
                                 DaVinciCRDTestKit::TagMethods.hook_instance_data_fetch_tag(hook_instance)])
  end

  before do
    create_payer_fetch('hook-instance-primary', 'payer-primary')
    create_payer_fetch('hook-instance-secondary', 'payer-secondary')
  end

  def hook_request(request_body, url)
    Inferno::Entities::Request.new(url:, request_body: request_body.to_json)
  end

  def stub_requests(requests)
    allow_any_instance_of(test).to receive(:load_interaction_group_requests).and_return(requests)
  end

  def result_messages
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [test])
      .first
      .messages
      .map(&:message)
  end

  it 'fails when no hook requests were received' do
    stub_requests([])

    result = run(test, payer_inputs)

    expect(result.result).to eq('fail')
    expect(result.result_message).to include('did not receive any hook requests')
  end

  it 'fails when more than two hook requests were received' do
    stub_requests([
                    hook_request(primary_request_body, complete_service_url),
                    hook_request(secondary_request_body, subset_service_url),
                    hook_request(primary_request_body, complete_service_url)
                  ])

    result = run(test, payer_inputs)

    expect(result.result).to eq('fail')
    expect(result.result_message).to include('expected at most one for each of the two payers')
  end

  it 'fails when a hook request has no body' do
    stub_requests([
                    hook_request(primary_request_body, complete_service_url),
                    Inferno::Entities::Request.new(url: subset_service_url, request_body: nil)
                  ])

    result = run(test, payer_inputs)

    expect(result.result).to eq('fail')
    expect(result.result_message).to include('do not contain valid JSON bodies')
  end

  it 'passes when a single request solicits coverage information' do
    stub_requests([hook_request(primary_request_body, complete_service_url)])

    result = run(test, payer_inputs)

    expect(result.result).to eq('pass')
  end

  it 'fails when a single request disables coverage information' do
    stub_requests([hook_request(secondary_request_body, subset_service_url)])

    result = run(test, payer_inputs)

    expect(result.result).to eq('fail')
    expect(result_messages).to include(a_string_matching(/The hook request disables coverage information/))
  end

  it 'passes when two requests differ only in coverage details and one disables coverage information' do
    stub_requests([
                    hook_request(primary_request_body, complete_service_url),
                    hook_request(secondary_request_body, subset_service_url)
                  ])

    result = run(test, payer_inputs)

    expect(result.result).to eq('pass')
  end

  it 'fails when both requests were made to the same simulated server' do
    stub_requests([
                    hook_request(primary_request_body, complete_service_url),
                    hook_request(secondary_request_body, complete_service_url)
                  ])

    result = run(test, payer_inputs)

    expect(result.result).to eq('fail')
    expect(result_messages).to include(a_string_matching(/made to the same Inferno simulated CRD server/))
  end

  it 'fails when neither request disables coverage information' do
    secondary_request_body.delete('extension')
    stub_requests([
                    hook_request(primary_request_body, complete_service_url),
                    hook_request(secondary_request_body, subset_service_url)
                  ])

    result = run(test, payer_inputs)

    expect(result.result).to eq('fail')
    expect(result_messages).to include(a_string_matching(/Neither hook request disables coverage information/))
  end

  it 'fails when both requests disable coverage information' do
    primary_request_body['extension'] = { 'davinci-crd.configuration' => { 'coverage-info' => false } }
    stub_requests([
                    hook_request(primary_request_body, complete_service_url),
                    hook_request(secondary_request_body, subset_service_url)
                  ])

    result = run(test, payer_inputs)

    expect(result.result).to eq('fail')
    expect(result_messages).to include(a_string_matching(/Both hook requests disable coverage information/))
  end

  it 'fails when the requests differ beyond their coverage details' do
    secondary_request_body['context']['patientId'] = 'other-patient'
    stub_requests([
                    hook_request(primary_request_body, complete_service_url),
                    hook_request(secondary_request_body, subset_service_url)
                  ])

    result = run(test, payer_inputs)

    expect(result.result).to eq('fail')
    expect(result_messages).to include(a_string_matching(/differ in `context`/))
  end

  describe 'prefetched coverage' do
    let(:secondary_coverage) { secondary_request_body.dig('prefetch', 'coverage', 'entry', 0) }

    it 'fails when a request prefetches more than one Coverage' do
      primary_request_body['prefetch']['coverage']['entry'] << secondary_coverage
      stub_requests([hook_request(primary_request_body, complete_service_url)])

      result = run(test, payer_inputs)

      expect(result.result).to eq('fail')
      expect(result_messages).to include(
        a_string_including('(Request 1) 2 Coverages were provided in the prefetched coverage data')
      )
    end

    it 'fails when a request prefetches no Coverage' do
      primary_request_body['prefetch']['coverage'] = { 'resourceType' => 'Bundle', 'entry' => [] }
      stub_requests([hook_request(primary_request_body, complete_service_url)])

      result = run(test, payer_inputs)

      expect(result.result).to eq('fail')
      expect(result_messages).to include(
        a_string_including('No Coverage was provided in the prefetched coverage data')
      )
    end

    it 'ignores prefetched Bundle entries whose resource is not an object' do
      [primary_request_body, secondary_request_body].each do |body|
        body['prefetch']['coverage']['entry'] << { 'resource' => 'Coverage/1' }
      end
      stub_requests([
                      hook_request(primary_request_body, complete_service_url),
                      hook_request(secondary_request_body, subset_service_url)
                    ])

      result = run(test, payer_inputs)

      expect(result.result).to eq('pass')
    end

    it 'counts a Coverage prefetched under the subset service key' do
      secondary_request_body['prefetch'] = { 'cov' => secondary_request_body['prefetch']['coverage'] }
      stub_requests([
                      hook_request(primary_request_body, complete_service_url),
                      hook_request(secondary_request_body, subset_service_url)
                    ])

      result = run(test, payer_inputs)

      expect(result.result).to eq('pass')
    end

    it "fails when a request's Coverage is not issued by the payer of the invoked service" do
      stub_requests([
                      hook_request(primary_request_body, subset_service_url),
                      hook_request(secondary_request_body, complete_service_url)
                    ])

      result = run(test, payer_inputs)

      expect(result.result).to eq('fail')
      expect(result_messages).to include(
        a_string_including("(Request 1) Payer for the Coverage has the wrong id: expected 'payer-secondary', " \
                           "got 'payer-primary'"),
        a_string_including("(Request 2) Payer for the Coverage has the wrong id: expected 'payer-primary', " \
                           "got 'payer-secondary'")
      )
    end

    it 'fails when the prefetched Coverage has no payer reference' do
      primary_request_body['prefetch']['coverage']['entry'][0]['resource'].delete('payor')
      stub_requests([hook_request(primary_request_body, complete_service_url)])

      result = run(test, payer_inputs)

      expect(result.result).to eq('fail')
      expect(result_messages).to include(a_string_including('(Request 1) Coverage has no payer reference'))
      expect(result_messages).to_not include(a_string_including("Inferno failed to retrieve the Coverage's payer"))
    end

    it 'fails rather than raising when the payer of the prefetched Coverage is not a reference object' do
      primary_request_body['prefetch']['coverage']['entry'][0]['resource']['payor'] = ['Organization/primary']
      stub_requests([hook_request(primary_request_body, complete_service_url)])

      result = run(test, payer_inputs)

      expect(result.result).to eq('fail')
      expect(result_messages).to include(a_string_including('(Request 1) Coverage has no payer reference'))
    end

    it 'fails when Inferno could not read the payer of the prefetched Coverage' do
      primary_request_body['hookInstance'] = 'hook-instance-without-payer-read'
      stub_requests([hook_request(primary_request_body, complete_service_url)])

      result = run(test, payer_inputs)

      expect(result.result).to eq('fail')
      expect(result_messages).to include(
        a_string_including("Inferno failed to retrieve the Coverage's payer during hook processing")
      )
    end

    it 'fails when no payer Organization id is configured for the invoked service' do
      stub_requests([hook_request(primary_request_body, complete_service_url)])

      result = run(test, payer_inputs.except(:complete_prefetch_service_organization_id))

      expect(result.result).to eq('fail')
      expect(result_messages).to include(
        a_string_including('No Inferno Payer Organization id configured for the invoked service')
      )
    end
  end
end
