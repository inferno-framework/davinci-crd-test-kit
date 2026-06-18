RSpec.describe DaVinciCRDTestKit::V221::UnresolvedCoverageTest do
  let(:suite_id) { 'crd_server' }
  let(:runnable) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:base_coverage_info_system_action) do
    json = File.read(File.join(__dir__, '..', '..', '..', '..', 'fixtures', 'crd_authorization_hook_response.json'))
    JSON.parse(json)['systemActions'].first
  end

  def entity_result_message
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .first
      .message
  end

  def coverage_info_system_action(covered: 'not-covered', reason: 'coverage-not-found')
    base_coverage_info_system_action.deep_dup.tap do |action|
      action['resource']['extension']
        .first['extension']
        .find { |extension| extension['url'] == 'covered' }['valueCode'] = covered
      action['resource']['extension']
        .first['extension']
        .find { |extension| extension['url'] == 'reason' }['valueCodeableConcept'] = {
          'coding' => [
            {
              'code' => reason
            }
          ]
        }
    end
  end

  it 'passes when the coverage info extension is not-covered because coverage was not found' do
    result = run(runnable, coverage_info: [coverage_info_system_action].to_json)

    expect(result.result).to eq('pass'), result.result_message
  end

  it 'passes when the coverage info extension is not-covered because no active coverage was found' do
    result = run(runnable, coverage_info: [coverage_info_system_action(reason: 'no-active-coverage')].to_json)

    expect(result.result).to eq('pass'), result.result_message
  end

  it 'skips when no coverage information actions are received' do
    result = run(runnable, coverage_info: [].to_json)

    expect(result.result).to eq('skip'), result.result_message
  end

  it 'fails when the coverage info extension coverage is not not-covered' do
    result = run(runnable, coverage_info: [coverage_info_system_action(covered: 'covered')].to_json)

    expect(result.result).to eq('fail'), result.result_message
    expect(result.result_message).to match(/Not all coverage info extensions/)

    expect(entity_result_message).to match(/Coverage should be `not-covered`, but found `covered`/)
  end

  it 'fails when the coverage info extension reason is not coverage-not-found or no-active-coverage' do
    result = run(runnable, coverage_info: [coverage_info_system_action(reason: 'no-member-found')].to_json)

    expect(result.result).to eq('fail'), result.result_message
    expect(result.result_message).to match(/Not all coverage info extensions/)

    expect(entity_result_message)
      .to match(/Coverage reason should be `coverage-not-found` or `no-active-coverage`, but found `no-member-found`/)
  end
end
