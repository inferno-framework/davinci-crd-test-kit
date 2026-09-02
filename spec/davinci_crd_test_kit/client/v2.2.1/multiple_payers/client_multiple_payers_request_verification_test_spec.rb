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

    result = run(test)

    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/did not receive any hook requests/)
  end

  it 'fails when more than two hook requests were received' do
    stub_requests([
                    hook_request(primary_request_body, complete_service_url),
                    hook_request(secondary_request_body, subset_service_url),
                    hook_request(primary_request_body, complete_service_url)
                  ])

    result = run(test)

    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/expected at most one for each of the two payers/)
  end

  it 'passes when a single request solicits coverage information' do
    stub_requests([hook_request(primary_request_body, complete_service_url)])

    result = run(test)

    expect(result.result).to eq('pass')
  end

  it 'fails when a single request disables coverage information' do
    stub_requests([hook_request(secondary_request_body, subset_service_url)])

    result = run(test)

    expect(result.result).to eq('fail')
    expect(result_messages).to include(a_string_matching(/The hook request disables coverage information/))
  end

  it 'passes when two requests differ only in coverage details and one disables coverage information' do
    stub_requests([
                    hook_request(primary_request_body, complete_service_url),
                    hook_request(secondary_request_body, subset_service_url)
                  ])

    result = run(test)

    expect(result.result).to eq('pass')
  end

  it 'fails when both requests were made to the same simulated server' do
    stub_requests([
                    hook_request(primary_request_body, complete_service_url),
                    hook_request(secondary_request_body, complete_service_url)
                  ])

    result = run(test)

    expect(result.result).to eq('fail')
    expect(result_messages).to include(a_string_matching(/made to the same Inferno simulated CRD server/))
  end

  it 'fails when neither request disables coverage information' do
    secondary_request_body.delete('extension')
    stub_requests([
                    hook_request(primary_request_body, complete_service_url),
                    hook_request(secondary_request_body, subset_service_url)
                  ])

    result = run(test)

    expect(result.result).to eq('fail')
    expect(result_messages).to include(a_string_matching(/Neither hook request disables coverage information/))
  end

  it 'fails when both requests disable coverage information' do
    primary_request_body['extension'] = { 'davinci-crd.configuration' => { 'coverage-info' => false } }
    stub_requests([
                    hook_request(primary_request_body, complete_service_url),
                    hook_request(secondary_request_body, subset_service_url)
                  ])

    result = run(test)

    expect(result.result).to eq('fail')
    expect(result_messages).to include(a_string_matching(/Both hook requests disable coverage information/))
  end

  it 'fails when the requests differ beyond their coverage details' do
    secondary_request_body['context']['patientId'] = 'other-patient'
    stub_requests([
                    hook_request(primary_request_body, complete_service_url),
                    hook_request(secondary_request_body, subset_service_url)
                  ])

    result = run(test)

    expect(result.result).to eq('fail')
    expect(result_messages).to include(a_string_matching(/differ in `context`/))
  end
end
