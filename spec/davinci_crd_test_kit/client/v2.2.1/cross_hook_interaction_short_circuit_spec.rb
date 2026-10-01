require_relative '../../../../lib/davinci_crd_test_kit/client/v2.2.1/client_cross_hook_interaction_group'

# The interaction group is optional: a tester who demonstrated everything during the Hooks group
# can decline to send more requests, and the tests that would evaluate them pass rather than skip.
RSpec.describe DaVinciCRDTestKit::V221::ClientCrossHookInteractionGroup, :request do
  let(:suite_id) { 'crd_client_v221' }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite_id) }
  let(:scratch) { {} }

  let(:wait_test) { find_test(described_class, 'crd_v221_cross_hooks_request') }
  let(:conformance_test) { find_test(described_class, 'crd_v221_hook_request_conformance') }

  def wait_test_inputs(make_additional_hook_requests)
    { make_additional_hook_requests:, cds_jwt_iss: 'https://example.org/client' }
  end

  # Every test in the group other than the one that does the waiting.
  def group_test_ids
    ids = []
    collect = lambda do |runnable|
      ids << runnable.id.to_s if runnable.is_a?(Class) && runnable < Inferno::Test
      runnable.children.each { |child| collect.call(child) } if runnable.respond_to?(:children)
    end
    collect.call(described_class)

    ids.reject { |id| id.end_with?('crd_v221_cross_hooks_request') }
  end

  describe 'when the tester declines to make additional requests' do
    it 'passes the waiting test without waiting' do
      result = run(wait_test, wait_test_inputs('false'), scratch)

      expect(result.result).to eq('pass')
      expect(result.result_message).to include('chose not to make additional hook requests')
    end

    it 'passes the tests that would have evaluated those requests' do
      run(wait_test, wait_test_inputs('false'), scratch)

      result = run(conformance_test, {}, scratch)

      expect(result.result).to eq('pass')
      expect(result.result_message).to include('chose not to make additional hook requests')
    end

    # The authorization tests read outputs of the tests before them rather than loading requests, so
    # a required input would skip them before the short circuit could pass them.
    it 'passes every test in the group, including those reading upstream outputs' do
      run(wait_test, wait_test_inputs('false'), scratch)

      results = group_test_ids.map { |test_id| run(find_test(described_class, test_id), {}, scratch) }
      failures = results.reject { |result| result.result == 'pass' }

      expect(failures).to be_empty, failures.map { |one| "#{one.result}: #{one.result_message}" }.join("\n")
    end
  end

  describe 'when the tester chooses to make additional requests' do
    it 'waits for them' do
      result = run(wait_test, wait_test_inputs('true'), scratch)

      expect(result.result).to eq('wait')
    end

    # Without the short circuit flag the downstream tests behave exactly as they always have.
    it 'leaves the evaluating tests to skip when no requests arrive' do
      run(wait_test, wait_test_inputs('true'), scratch)

      result = run(conformance_test, {}, scratch)

      expect(result.result).to eq('skip')
    end
  end

  # The flag lives in scratch, which persists for the session, so a re-run after the tester changes
  # their mind must not still be short circuited.
  it 'clears the flag when the waiting test runs again' do
    run(wait_test, wait_test_inputs('false'), scratch)
    expect(scratch[:short_circuit]).to eq(:pass)

    run(wait_test, wait_test_inputs('true'), scratch)

    expect(scratch[:short_circuit]).to be_nil
  end
end
