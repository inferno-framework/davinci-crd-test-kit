RSpec.describe DaVinciCRDTestKit::CardOptionalFieldsValidationTest do
  let(:suite_id) { 'crd_client' }
  let(:runnable) { described_class }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:valid_cards) do
    json = File.read(File.join(__dir__, '..', 'fixtures', 'valid_cards.json'))
    JSON.parse(json)
  end
  let(:link_required_fields) { ['label', 'type', 'url'] }
  let(:override_reasons_required_fields) { ['code', 'system', 'display'] }
  let(:suggestions_required_fields) { ['label'] }
  let(:actions_required_fields) { ['type', 'description'] }

  def entity_result_messages
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
  end

  it 'passes if all provided optional fields have the correct type' do
    result = run(runnable, valid_cards: valid_cards.to_json)
    expect(result.result).to eq('pass')
  end

  it 'skips if valid_cards not present' do
    result = run(runnable)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/'valid_cards' is nil, skipping test/)
  end

  it 'fails if valid_cards a valid json' do
    result = run(runnable, valid_cards:)
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(/Invalid JSON/)
  end

  it 'fails if an optional field is not of the correct type' do
    valid_cards.first['uuid'] = 2
    result = run(runnable, valid_cards: valid_cards.to_json)
    expect(result.result).to eq('fail')

    msg = entity_result_messages.find { |m| m.type == 'error' }
    expect(msg.message).to match(/`uuid` is not of type/)
  end

  it 'fails if field is of correcty type but empty' do
    valid_cards.first['uuid'] = ''
    valid_cards.first['links'] = []
    result = run(runnable, valid_cards: valid_cards.to_json)
    expect(result.result).to eq('fail')

    msg = entity_result_messages.map(&:message).join(' ')
    expect(msg).to match(/`uuid` should not be an empty String/)
    expect(msg).to match(/`links` should not be an empty Array/)
  end

  it 'fails if a required field is missing from Card.link' do
    link_required_fields.each do |field|
      dup_cards = valid_cards.deep_dup
      card_with_links = dup_cards.find { |card| card['links'].present? }

      card_with_links['links'].first.delete(field)
      result = run(runnable, valid_cards: dup_cards.to_json)
      expect(result.result).to eq('fail')

      msg = entity_result_messages.find { |m| m.type == 'error' }
      expect(msg.message).to match(/does not contain required field `#{field}`/)
    end
  end

  it 'fails if Card.link required field is a wrong type' do
    link_required_fields.each do |field|
      dup_cards = valid_cards.deep_dup
      card_with_links = dup_cards.find { |card| card['links'].present? }

      card_with_links['links'].first[field] = 123
      result = run(runnable, valid_cards: dup_cards.to_json)
      expect(result.result).to eq('fail')

      msg = entity_result_messages.find { |m| m.type == 'error' }
      expect(msg.message).to match(/field `#{field}` is not/)
    end
  end

  it 'fails if Card.link.type is not absolute or smart' do
    card_with_links = valid_cards.find { |card| card['links'].present? }
    card_with_links['links'].first['type'] = '123'
    result = run(runnable, valid_cards: valid_cards.to_json)
    expect(result.result).to eq('fail')
    msg = entity_result_messages.filter { |m| m.type == 'error' }.map(&:message).join(' ')
    expect(msg).to match(/`Link.type` must be `absolute` or `smart`/)
  end

  it 'fails if Card.link.appContext is present for absolute link' do
    card_with_links = valid_cards.find { |card| card['links'].present? }
    card_with_links['links'].first['type'] = 'absolute'
    card_with_links['links'].first['appContext'] = 'context'
    result = run(runnable, valid_cards: valid_cards.to_json)
    expect(result.result).to eq('fail')
    msg = entity_result_messages.filter { |m| m.type == 'error' }.map(&:message).join(' ')
    expect(msg).to match(/`appContext` field should only be valued if the link type is smart/)
  end

  it 'fails if a required field is missing from Card.overrideReasons' do
    override_reasons_required_fields.each do |field|
      dup_cards = valid_cards.deep_dup
      card_with_reasons = dup_cards.find { |card| card['overrideReasons'].present? }

      card_with_reasons['overrideReasons'].first.delete(field)
      result = run(runnable, valid_cards: dup_cards.to_json)
      expect(result.result).to eq('fail')

      msg = entity_result_messages.find { |m| m.type == 'error' }
      expect(msg.message).to match(/does not contain required field `#{field}`/)
    end
  end

  it 'fails if Card.overrideReasons required field is a wrong type' do
    override_reasons_required_fields.each do |field|
      dup_cards = valid_cards.deep_dup
      card_with_reasons = dup_cards.find { |card| card['overrideReasons'].present? }

      card_with_reasons['overrideReasons'].first[field] = 123
      result = run(runnable, valid_cards: dup_cards.to_json)
      expect(result.result).to eq('fail')

      msg = entity_result_messages.find { |m| m.type == 'error' }
      expect(msg.message).to match(/field `#{field}` is not/)
    end
  end

  it 'fails if a required field is missing from Card.suggestions' do
    suggestions_required_fields.each do |field|
      dup_cards = valid_cards.deep_dup
      cards_with_suggestions = dup_cards.find { |card| card['suggestions'].present? }

      cards_with_suggestions['suggestions'].first.delete(field)
      result = run(runnable, valid_cards: dup_cards.to_json)
      expect(result.result).to eq('fail')

      msg = entity_result_messages.find { |m| m.type == 'error' }
      expect(msg.message).to match(/does not contain required field `#{field}`/)
    end
  end

  it 'fails if Card.suggestions required field is a wrong type' do
    suggestions_required_fields.each do |field|
      dup_cards = valid_cards.deep_dup
      cards_with_suggestions = dup_cards.find { |card| card['suggestions'].present? }

      cards_with_suggestions['suggestions'].first[field] = 123
      result = run(runnable, valid_cards: dup_cards.to_json)
      expect(result.result).to eq('fail')

      msg = entity_result_messages.find { |m| m.type == 'error' }
      expect(msg.message).to match(/field `#{field}` is not/)
    end
  end

  it 'fails if a required field is missing from Suggestion action' do
    actions_required_fields.each do |field|
      dup_cards = valid_cards.deep_dup
      cards_with_suggestions = dup_cards.find { |card| card['suggestions'].present? }
      actions = cards_with_suggestions['suggestions'].first['actions']

      actions.first.delete(field)
      result = run(runnable, valid_cards: dup_cards.to_json)
      expect(result.result).to eq('fail')

      msg = entity_result_messages.find { |m| m.type == 'error' }
      expect(msg.message).to match(/does not contain required field `#{field}`/)
    end
  end

  it 'fails if Suggestion action required field is a wrong type' do
    actions_required_fields.each do |field|
      dup_cards = valid_cards.deep_dup
      cards_with_suggestions = dup_cards.find { |card| card['suggestions'].present? }
      actions = cards_with_suggestions['suggestions'].first['actions']

      actions.first[field] = 123
      result = run(runnable, valid_cards: dup_cards.to_json)
      expect(result.result).to eq('fail')

      msg = entity_result_messages.find { |m| m.type == 'error' }
      expect(msg.message).to match(/field `#{field}` is not/)
    end
  end

  it 'fails if `Card.selectionBehavior` is missing when suggestions present' do
    cards_with_suggestions = valid_cards.find { |card| card['suggestions'].present? }
    cards_with_suggestions.delete('selectionBehavior')

    result = run(runnable, valid_cards: valid_cards.to_json)
    expect(result.result).to eq('fail')

    msg = entity_result_messages.find { |m| m.type == 'error' }
    expect(msg.message).to match(/`Card.selectionBehavior` must be provided/)
  end

  it 'fails if Card.selectionBehavior value is not at-most-one or any' do
    cards_with_suggestions = valid_cards.find { |card| card['suggestions'].present? }
    cards_with_suggestions['selectionBehavior'] = 'abs'

    result = run(runnable, valid_cards: valid_cards.to_json)
    expect(result.result).to eq('fail')

    msg = entity_result_messages.find { |m| m.type == 'error' }
    expect(msg.message).to match(/not allowed/)
  end

  it 'fails Action.type is not an allowed value' do
    cards_with_suggestions = valid_cards.find { |card| card['suggestions'].present? }
    actions = cards_with_suggestions['suggestions'].first['actions']

    actions.first['type'] = 'example'
    result = run(runnable, valid_cards: valid_cards.to_json)
    expect(result.result).to eq('fail')

    msg = entity_result_messages.find { |m| m.type == 'error' }
    expect(msg.message).to match(/is not allowed/)
  end

  it 'fails if a create action does not have a resource field' do
    cards_with_suggestions = valid_cards.find { |card| card['suggestions'].present? }
    create_action = cards_with_suggestions['suggestions'].first['actions'].find { |action| action['type'] == 'create' }
    create_action.delete('resource')

    result = run(runnable, valid_cards: valid_cards.to_json)
    expect(result.result).to eq('fail')

    msg = entity_result_messages.find { |m| m.type == 'error' }
    expect(msg.message).to match(/Action.resource` must be present/)
  end

  it 'fails if a create action resource is not a FHIR resource' do
    cards_with_suggestions = valid_cards.find { |card| card['suggestions'].present? }
    create_action = cards_with_suggestions['suggestions'].first['actions'].find { |action| action['type'] == 'create' }
    create_action['resource'] = 'example'

    result = run(runnable, valid_cards: valid_cards.to_json)
    expect(result.result).to eq('fail')

    msg = entity_result_messages.find { |m| m.type == 'error' }
    expect(msg.message).to match(/`Action.resource` must be a FHIR resource/)
  end

  it 'fails if a delete action does not have a resourceId field' do
    cards_with_suggestions = valid_cards.find { |card| card['suggestions'].present? }
    delete_action = cards_with_suggestions['suggestions'].first['actions'].find { |action| action['type'] == 'delete' }
    delete_action.delete('resourceId')

    result = run(runnable, valid_cards: valid_cards.to_json)
    expect(result.result).to eq('fail')

    msg = entity_result_messages.find { |m| m.type == 'error' }
    expect(msg.message).to match(/does not contain required field/)
  end

  it 'fails if a delete action resourceId is not an array' do
    cards_with_suggestions = valid_cards.find { |card| card['suggestions'].present? }
    delete_action = cards_with_suggestions['suggestions'].first['actions'].find { |action| action['type'] == 'delete' }
    delete_action['resourceId'] = 'example'

    result = run(runnable, valid_cards: valid_cards.to_json)
    expect(result.result).to eq('fail')

    msg = entity_result_messages.find { |m| m.type == 'error' }
    expect(msg.message).to match(/is not of type `Array`/)
  end

  it 'fails if a delete action resourceId item is not a relative reference' do
    cards_with_suggestions = valid_cards.find { |card| card['suggestions'].present? }
    delete_action = cards_with_suggestions['suggestions'].first['actions'].find { |action| action['type'] == 'delete' }
    delete_action['resourceId'] = ['example']

    result = run(runnable, valid_cards: valid_cards.to_json)
    expect(result.result).to eq('fail')

    msg = entity_result_messages.find { |m| m.type == 'error' }
    expect(msg.message).to match(/Invalid `Action.resourceId item` format/)
  end

  it 'persists outputs when valid card with suggestions and/or links are present' do
    result = run(runnable, valid_cards: valid_cards.to_json)
    expect(result.result).to eq('pass')

    persisted_link_cards = session_data_repo.load(test_session_id: test_session.id, name: :valid_cards_with_links)
    persisted_suggestion_cards = session_data_repo.load(test_session_id: test_session.id,
                                                        name: :valid_cards_with_suggestions)
    cards_with_links = valid_cards.filter { |card| card['links'].present? }
    cards_with_suggestions = valid_cards.filter { |card| card['suggestions'].present? }
    expect(persisted_link_cards).to eq(cards_with_links.to_json)
    expect(persisted_suggestion_cards).to eq(cards_with_suggestions.to_json)
  end
end
