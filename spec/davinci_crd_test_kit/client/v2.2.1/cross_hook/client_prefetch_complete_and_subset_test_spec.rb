RSpec.describe DaVinciCRDTestKit::V221::ClientPrefetchCompleteAndSubsetTest do
  let(:suite_id) { 'crd_client_v221' }

  let(:runnable) do
    Inferno::Repositories::Tests.new.find(
      'crd_client_v221-crd_v221_client_hook_invocation-crd_v221_client_cross_hook' \
      '-crd_v221_client_prefetch_complete_and_subset'
    )
  end

  let(:prefetch_complete_test) do
    Inferno::Repositories::Tests.new.find(
      'crd_client_v221-crd_v221_client_hook_invocation-crd_v221_client_hooks' \
      '-crd_v221_client_order_sign-Group03-crd_v221_hook_request_prefetch_complete'
    )
  end

  let(:prefetch_complete_test_appt_book) do
    Inferno::Repositories::Tests.new.find(
      'crd_client_v221-crd_v221_client_hook_invocation-crd_v221_client_hooks' \
      '-crd_v221_client_appointment_book-Group03-crd_v221_hook_request_prefetch_complete'
    )
  end

  let(:result) { repo_create(:result, test_session_id: test_session.id) }
  let(:base_url) { "#{Inferno::Application['base_url']}/custom/crd_client" }
  let(:subset_url) { "#{base_url}/prefetch-subset/cds-services/order-sign-subset" }
  let(:service_url) { "#{base_url}/cds-services/order-sign-service" }

  def create_completeness_result(output_json: '[]')
    repo_create(
      :result,
      test_session_id: test_session.id,
      runnable: prefetch_complete_test.reference_hash,
      output_json:,
      result: 'pass'
    )
  end

  def create_hook_request(url:)
    repo_create(
      :request,
      direction: 'incoming',
      url:,
      result:,
      test_session_id: test_session.id,
      request_body: { 'hook' => 'order-sign', 'hookInstance' => SecureRandom.uuid }.to_json,
      status: 200,
      tags: ['order-sign']
    )
  end

  it 'skips when no requests have been received' do
    create_completeness_result
    expect(run(runnable).result).to eq('skip')
  end

  it 'skips when requests exist but none were made to the subset endpoint' do
    create_hook_request(url: service_url)
    create_completeness_result(
      output_json: [{ name: 'demonstrates_prefetch_complete_distinct_from_subset', value: 'true' }].to_json
    )
    expect(run(runnable).result).to eq('skip')
  end

  it 'skips when requests exist but none were made to the complete endpoint' do
    create_hook_request(url: subset_url)
    create_completeness_result(
      output_json: [{ name: 'demonstrates_prefetch_subset_distinct_from_complete', value: 'true' }].to_json
    )
    expect(run(runnable).result).to eq('skip')
  end

  it 'skips when subset requests exist but the subset distinction output is not demonstrated' do
    create_hook_request(url: subset_url)
    create_hook_request(url: service_url)
    create_completeness_result(
      output_json: [{ name: 'demonstrates_prefetch_complete_distinct_from_subset', value: 'true' }].to_json
    )
    expect(run(runnable).result).to eq('skip')
  end

  it 'skips when complete requests exist but the complete distinction output is not demonstrated' do
    create_hook_request(url: subset_url)
    create_hook_request(url: service_url)
    create_completeness_result(
      output_json: [{ name: 'demonstrates_prefetch_subset_distinct_from_complete', value: 'true' }].to_json
    )
    expect(run(runnable).result).to eq('skip')
  end

  it 'passes when both distinction outputs are demonstrated in a single result' do
    create_hook_request(url: subset_url)
    create_hook_request(url: service_url)
    create_completeness_result(
      output_json: [
        { name: 'demonstrates_prefetch_subset_distinct_from_complete', value: 'true' },
        { name: 'demonstrates_prefetch_complete_distinct_from_subset', value: 'true' }
      ].to_json
    )
    expect(run(runnable).result).to eq('pass')
  end

  it 'passes when distinction outputs come from different hook group completeness results' do
    create_hook_request(url: subset_url)
    create_hook_request(url: service_url)
    repo_create(
      :result,
      test_session_id: test_session.id,
      runnable: prefetch_complete_test.reference_hash,
      output_json: [{ name: 'demonstrates_prefetch_subset_distinct_from_complete', value: 'true' }].to_json,
      result: 'pass'
    )
    repo_create(
      :result,
      test_session_id: test_session.id,
      runnable: prefetch_complete_test_appt_book.reference_hash,
      output_json: [{ name: 'demonstrates_prefetch_complete_distinct_from_subset', value: 'true' }].to_json,
      result: 'pass'
    )
    expect(run(runnable).result).to eq('pass')
  end
end
