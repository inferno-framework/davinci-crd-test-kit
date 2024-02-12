RSpec.describe DaVinciCRDTestKit::CoverageInformationSystemActionValidationTest do
  let(:runnable) { Inferno::Repositories::Tests.new.find('crd_coverage_info_system_action_validation') }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: 'crd_server') }
  let(:valid_coverage_info_system_action) do
    json = File.read(File.join(__dir__, '..', 'fixtures', 'crd_authorization_hook_response.json'))
    JSON.parse(json)['systemActions'].first
  end

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(
        test_session_id: test_session.id,
        name:,
        value:,
        type: runnable.config.input_type(name)
      )
    end
    Inferno::TestRunner.new(test_session:, test_run:).run(runnable)
  end

  before do
    allow_any_instance_of(runnable).to receive(:hook_name).and_return('appointment-book')
    allow_any_instance_of(runnable).to receive(:assert_valid_resource).and_return(true)
  end

  def entity_result_message
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .first
  end

  context 'when resource extension has multiple repetions applying to the same coverage' do
    it 'passes if coverage-assertion-ids are the same and satisfied-pa-ids are the same' do
      dup_action = valid_coverage_info_system_action.deep_dup
      ext = dup_action['resource']['extension'].first.deep_dup
      dup_action['resource']['extension'] << ext

      result = run(runnable, coverage_info: [dup_action].to_json)
      expect(result.result).to eq('pass')
    end

    it 'fails if coverage-assertion-ids are distinct' do
      dup_action = valid_coverage_info_system_action.deep_dup
      ext = dup_action['resource']['extension'].first.deep_dup
      assertion_id = ext['extension'].find { |extension| extension['url'] == 'coverage-assertion-id' }
      assertion_id['valueString'] = 'asdf'
      dup_action['resource']['extension'] << ext

      result = run(runnable, coverage_info: [dup_action].to_json)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/different coverage-assertion-ids/)
    end

    it 'fails if satisfied-pa-ids are distinct' do
      dup_action = valid_coverage_info_system_action.deep_dup
      ext = dup_action['resource']['extension'].first.deep_dup
      satisfied_pa_id = ext['extension'].find { |extension| extension['url'] == 'satisfied-pa-id' }
      satisfied_pa_id['valueString'] = 'asdf'
      dup_action['resource']['extension'] << ext

      result = run(runnable, coverage_info: [dup_action].to_json)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/different satisfied-pa-ids/)
    end
  end

  context 'when resource extension has repetions referencing differing coverage' do
    it 'passes if coverage-assertion-ids and satisfied-pa-ids are distinct across coverages' do
      dup_action = valid_coverage_info_system_action.deep_dup
      ext = dup_action['resource']['extension'].first.deep_dup
      coverage = ext['extension'].find { |extension| extension['url'] == 'coverage' }
      coverage['valueReference']['reference'] = 'http://example.org/fhir/Coverage/asdf'
      assertion_id = ext['extension'].find { |extension| extension['url'] == 'coverage-assertion-id' }
      assertion_id['valueString'] = 'asdf'
      satisfied_pa_id = ext['extension'].find { |extension| extension['url'] == 'satisfied-pa-id' }
      satisfied_pa_id['valueString'] = 'asdf'
      dup_action['resource']['extension'] << ext

      result = run(runnable, coverage_info: [dup_action].to_json)
      expect(result.result).to eq('pass')
    end

    it 'fails if coverage-assertion-ids are the same across coverages' do
      dup_action = valid_coverage_info_system_action.deep_dup
      ext = dup_action['resource']['extension'].first.deep_dup
      coverage = ext['extension'].find { |extension| extension['url'] == 'coverage' }
      coverage['valueReference']['reference'] = 'http://example.org/fhir/Coverage/asdf'
      dup_action['resource']['extension'] << ext

      result = run(runnable, coverage_info: [dup_action].to_json)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/SHALL have distinct coverage-assertion-ids/)
    end

    it 'fails if satisfied-pa-ids are the same across coverages' do
      dup_action = valid_coverage_info_system_action.deep_dup
      ext = dup_action['resource']['extension'].first.deep_dup
      coverage = ext['extension'].find { |extension| extension['url'] == 'coverage' }
      coverage['valueReference']['reference'] = 'http://example.org/fhir/Coverage/asdf'
      assertion_id = ext['extension'].find { |extension| extension['url'] == 'coverage-assertion-id' }
      assertion_id['valueString'] = 'asdf'
      dup_action['resource']['extension'] << ext

      result = run(runnable, coverage_info: [dup_action].to_json)
      expect(result.result).to eq('fail')
      expect(entity_result_message.message).to match(/SHALL have distinct satisfied-pa-ids/)
    end
  end

  it 'skips if coverage_info_system_actions not provided' do
    result = run(runnable)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/'coverage_info' is nil, skipping test/)
  end

  it 'fails if coverage_info input is not valid json' do
    result = run(runnable, coverage_info: '[[')
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/Invalid JSON/)
  end

  it 'fails if a coverage info system action type is missing' do
    dup_action = valid_coverage_info_system_action.deep_dup
    dup_action.delete('type')

    result = run(runnable, coverage_info: [dup_action].to_json)
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to match(/`type` field is missing/)
  end

  it 'fails if a coverage info system action type is not update' do
    dup_action = valid_coverage_info_system_action.deep_dup
    dup_action['type'] = 'create'

    result = run(runnable, coverage_info: [dup_action].to_json)
    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to match(/`type` must be `update`/)
  end
end
