RSpec.describe DaVinciCRDTestKit::V221::TechnicalIssuesTest do
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

  def coverage_info_system_action(covered: 'indeterminate', reason: 'technical', exclude_text: false)
    reason_extension = {
      text: 'TEXT Reason',
      coding: [
        {
          code: reason
        }
      ]
    }
    reason_extension.delete :text if exclude_text

    base_coverage_info_system_action.deep_dup.tap do |action|
      action['resource']['extension']
        .first['extension']
        .find { |extension| extension['url'] == 'covered' }['valueCode'] = covered
      action['resource']['extension']
        .first['extension']
        .find { |extension| extension['url'] == 'reason' }['valueCodeableConcept'] = reason_extension
    end
  end

  it 'passes when the coverage info extension is indeterminate for technical reasons' do
    result = run(runnable, coverage_info: [coverage_info_system_action].to_json)

    expect(result.result).to eq('pass'), result.result_message
  end

  it 'skips when no coverage information actions are received' do
    result = run(runnable, coverage_info: [].to_json)

    expect(result.result).to eq('skip'), result.result_message
  end

  it 'fails when the coverage info extension coverage is not indeterminate' do
    result = run(runnable, coverage_info: [coverage_info_system_action(covered: 'covered')].to_json)

    expect(result.result).to eq('fail'), result.result_message
    expect(result.result_message).to match(/Not all coverage info extensions/)

    expect(entity_result_message).to match(/Coverage should be `indeterminate`, but found `covered`/)
  end

  it 'fails when the coverage info extension reason is not technical' do
    result = run(runnable, coverage_info: [coverage_info_system_action(reason: 'gold-card')].to_json)

    expect(result.result).to eq('fail'), result.result_message
    expect(result.result_message).to match(/Not all coverage info extensions/)

    expect(entity_result_message).to match(/Coverage reason should be `technical`, but found `gold-card`/)
  end

  it 'fails when the coverage info extension reason has no text' do
    result = run(runnable, coverage_info: [coverage_info_system_action(exclude_text: true)].to_json)

    expect(result.result).to eq('fail'), result.result_message
    expect(result.result_message).to match(/Not all coverage info extensions/)

    expect(entity_result_message).to match(/contains no additional details in `text` field/)
  end
end
