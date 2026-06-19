RSpec.describe DaVinciCRDTestKit::V221::CoverageInfoReasonTest do
  let(:suite_id) { 'crd_server' }
  let(:runnable) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:expected_coverage_code) { 'indeterminate' }
  let(:other_coverage_code) { 'covered' }
  let(:expected_reason_code) { 'technical' }
  let(:other_reason_code) { 'gold-card' }
  let(:require_reason_text) { false }
  let(:base_coverage_info_system_action) do
    json = File.read(File.join(__dir__, '..', '..', '..', '..', 'fixtures', 'crd_authorization_hook_response.json'))
    JSON.parse(json)['systemActions'].first
  end

  before do
    runnable.config(options: { expected_coverage_code:, expected_reason_code:, require_reason_text: })
  end

  def entity_result_message
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .first
      .message
  end

  def coverage_info_system_action(covered: expected_coverage_code, reason: expected_reason_code, reason_text: nil)
    base_coverage_info_system_action.deep_dup.tap do |action|
      reason_extension = {
        'coding' => [
          {
            'code' => reason
          }
        ]
      }
      reason_extension['text'] = reason_text if reason_text.present?

      action['resource']['extension']
        .first['extension']
        .find { |extension| extension['url'] == 'covered' }['valueCode'] = covered
      action['resource']['extension']
        .first['extension']
        .find { |extension| extension['url'] == 'reason' }['valueCodeableConcept'] = reason_extension
    end
  end

  it 'passes when the coverage info extension has the expected coverage and reason codes' do
    result = run(runnable, coverage_info: [coverage_info_system_action].to_json)

    expect(result.result).to eq('pass'), result.result_message
  end

  it 'skips when no coverage information actions are received' do
    result = run(runnable, coverage_info: [].to_json)

    expect(result.result).to eq('skip'), result.result_message
  end

  it 'fails when the coverage info extension coverage is not the expected coverage code' do
    result = run(runnable, coverage_info: [coverage_info_system_action(covered: other_coverage_code)].to_json)

    expect(result.result).to eq('fail'), result.result_message
    expect(result.result_message).to match(/Not all coverage info extensions/)

    expect(entity_result_message)
      .to match(/Coverage should be `#{expected_coverage_code}`, but found `#{other_coverage_code}`/)
  end

  it 'fails when the coverage info extension reason is not the expected reason' do
    result = run(runnable, coverage_info: [coverage_info_system_action(reason: other_reason_code)].to_json)

    expect(result.result).to eq('fail'), result.result_message
    expect(result.result_message).to match(/Not all coverage info extensions/)

    expect(entity_result_message)
      .to match(/Coverage reason should be `#{expected_reason_code}`, but found `#{other_reason_code}`/)
  end

  it 'passes when reason text is required and present' do
    runnable.config(options: { require_reason_text: true })

    result = run(runnable, coverage_info: [coverage_info_system_action(reason_text: 'reason text')].to_json)

    expect(result.result).to eq('pass'), result.result_message
  end

  it 'fails when reason text is required but absent' do
    runnable.config(options: { require_reason_text: true })

    result = run(runnable, coverage_info: [coverage_info_system_action(reason_text: nil)].to_json)

    expect(result.result).to eq('fail'), result.result_message
    expect(result.result_message).to match(/Not all coverage info extensions/)

    expect(entity_result_message).to match(/contains no additional details in `text` field/)
  end
end
