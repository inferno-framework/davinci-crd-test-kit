require_relative '../../../../../lib/davinci_crd_test_kit/cross_suite/tags'

RSpec.describe DaVinciCRDTestKit::V221::ClientHookInstancesUniqueTest do
  let(:suite_id) { 'crd_client_v221' }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:requests_repo) { Inferno::Repositories::Requests.new }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }
  let(:hook_instance_one) { 'd1577c69-dfbe-44ad-ba6d-3e05e953b2ea' }
  let(:hook_instance_two) { 'd1577c69-dfbe-44ad-ba6d-3e05e953b2eb' }
  let(:service_url) { 'https://example.com/cds-services/appointment-book-service' }
  let(:fhir_server) { 'https://fhir.example.com' }

  let(:test) { described_class }

  def create_hook_request(hook_instance,
                          tags: ['appointment-book', DaVinciCRDTestKit::TagMethods.hook_instance_tag(hook_instance)])
    body = {
      'hookInstance' => hook_instance,
      'hook' => 'appointment-book',
      'fhirServer' => fhir_server
    }.compact
    repo_create(
      :request,
      direction: 'incoming',
      url: service_url,
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

  it 'passes when no hook requests have been received' do
    result = run(test)
    expect(result.result).to eq('pass')
  end

  it 'passes when all hook request have unique hookInstances' do
    create_hook_request(hook_instance_one)
    create_hook_request(hook_instance_two)
    result = run(test)
    expect(result.result).to eq('pass')
  end

  it 'fails when there are multiple hooks calls with the same hookInstance' do
    create_hook_request(hook_instance_one)
    create_hook_request(hook_instance_one, tags: [DaVinciCRDTestKit::DUPLICATED_HOOK_INSTANCE_TAG])
    create_hook_request(hook_instance_two)
    create_hook_request(hook_instance_two, tags: [DaVinciCRDTestKit::DUPLICATED_HOOK_INSTANCE_TAG])
    result = run(test)
    expect(result.result).to eq('fail')
    expect(result.result_message).to eq('Inferno received hook requests that re-used `hookInstance` values: ' \
                                        "#{hook_instance_one}, #{hook_instance_two}")

    fetched = results_repo.current_results_for_test_session_and_runnables(test_session.id, [test]).first
    expect(fetched.requests.uniq(&:id).size).to eq(4)
  end
end
