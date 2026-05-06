RSpec.describe DaVinciCRDTestKit::V221::FormCompletionResponseValidationTest do
  let(:suite_id) { 'crd_client_v221' }
  let(:runnable) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:base_card) do
    {
      'summary' => 'Order Select Request Form Completion Card',
      'uuid' => 'jksfghisldlrldsse',
      'detail' => 'This is a Card containing one or more suggestions.',
      'indicator' => 'info',
      'source' => {
        'label' => 'Inferno',
        'url' => 'https://inferno.healthit.gov/',
        'topic' => {
          'system' => 'http://hl7.org/fhir/us/davinci-crd/CodeSystem/temp',
          'code' => 'order-select',
          'display' => 'Order Select'
        }
      },
      'selectionBehavior' => 'any',
      'suggestions' => [
        {
          'label' => "Add 'completion of the ABC form' to your task list (possibly for reassignment)",
          'actions' => [
            {
              'type' => 'create',
              'description' => 'Create form',
              'resource' => {
                'resourceType' => 'Questionnaire',
                'url' => 'http://example.org/Questionnaire/XYZ'
              }
            },
            {
              'type' => 'create',
              'description' => 'Create task',
              'resource' => {
                'resourceType' => 'Task',
                'code' => {
                  'coding' => [
                    {
                      'system' => 'http://hl7.org/fhir/uv/sdc/CodeSystem/temp',
                      'code' => 'complete-questionnaire'
                    }
                  ]
                },
                'input' => [
                  {
                    'type' => {
                      'text' => 'questionnaire',
                      'coding' => [
                        {
                          'system' => 'http://hl7.org/fhir/uv/sdc/CodeSystem/temp',
                          'code' => 'questionnaire'
                        }
                      ]
                    },
                    'valueCanonical' => 'http://example.org/Questionnaire/XYZ'
                  }
                ]
              }
            }
          ]
        }
      ]
    }
  end

  def entity_result_message
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .first
  end

  before do
    allow_any_instance_of(runnable).to receive(:resource_is_valid?).and_return(true)
  end

  it 'passes if questionnaire creation actions include the if-none-exist extension' do
    card = base_card
    card['suggestions'].first['actions'].first['extension'] = {
      'davinci-crd.if-none-exist': 'http://example.org/Questionnaire/XYZ'
    }
    result = run(runnable, valid_cards_with_suggestions: [base_card].to_json,
                           valid_system_actions: [].to_json)

    expect(result.result).to eq('pass'), result.result_message
  end

  it 'fails if form creation actions do not include the if-none-exist extension' do
    result = run(runnable, valid_cards_with_suggestions: [base_card].to_json,
                           valid_system_actions: [].to_json)

    expect(result.result).to eq('fail')
    expect(entity_result_message.message).to match(/is not present/)
  end

  it 'fails if the if-none-exist extension is the wrong type' do
    card = base_card
    card['suggestions'].first['actions'].first['extension'] = {
      'davinci-crd.if-none-exist': ['http://example.org/Questionnaire/XYZ']
    }
    result = run(runnable, valid_cards_with_suggestions: [base_card].to_json,
                           valid_system_actions: [].to_json)

    expect(result.result).to eq('fail'), result.result_message
    expect(entity_result_message.message).to match(/is not a string/)
  end

  it 'fails if the if-none-exist extension is an empty string' do
    card = base_card
    card['suggestions'].first['actions'].first['extension'] = {
      'davinci-crd.if-none-exist': ''
    }
    result = run(runnable, valid_cards_with_suggestions: [base_card].to_json,
                           valid_system_actions: [].to_json)

    expect(result.result).to eq('fail'), result.result_message
    expect(entity_result_message.message).to match(/is an empty string/)
  end
end
