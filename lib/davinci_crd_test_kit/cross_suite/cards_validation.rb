require_relative 'hook_request_field_validation'
require_relative 'suggestion_actions_validation'

module DaVinciCRDTestKit
  module CardsValidation
    include DaVinciCRDTestKit::HookRequestFieldValidation
    include DaVinciCRDTestKit::SuggestionActionsValidation

    HOOKS = [
      'appointment-book', 'encounter-discharge', 'encounter-start',
      'order-dispatch', 'order-select', 'order-sign'
    ].freeze

    def card_required_fields
      {
        'v221' => {
          'uuid' => String,
          'summary' => String,
          'source' => Hash
        },
        'v201' => {
          'indicator' => String,
          'summary' => String,
          'source' => Hash
        }
      }
    end

    def source_required_fields
      { 'label' => String, 'topic' => Hash }
    end

    def source_topic_required_fields
      { 'code' => String, 'system' => String }
    end

    def card_optional_fields
      {
        'v221' => {
          'detail' => String,
          'indicator' => String,
          'suggestions' => Array,
          'selectionBehavior' => String,
          'overrideReasons' => Array,
          'links' => Array
        },
        'v201' => {
          'detail' => String,
          'uuid' => String,
          'suggestions' => Array,
          'selectionBehavior' => String,
          'overrideReasons' => Array,
          'links' => Array
        }
      }
    end

    def override_reasons_required_fields
      { 'code' => String, 'system' => String, 'display' => String }
    end

    def link_required_fields
      { 'label' => String, 'type' => String, 'url' => 'URL' }
    end

    def valid_card_with_optionals?(card, version)
      current_error_count = messages.count { |msg| msg[:type] == 'error' }
      card_optional_fields[version].each do |field, type|
        next unless card[field]

        validate_presence_and_type(card, field, type, 'Card', required: false)
      end

      card_selection_behavior_check(card)
      card_override_reasons_check(card)
      card_links_check(card)
      card_suggestions_check(card)

      current_error_count == messages.count { |msg| msg[:type] == 'error' }
    end

    def card_selection_behavior_check(card)
      return unless card['suggestions'].present?

      selection_behavior = card['selectionBehavior']
      unless selection_behavior
        add_message('error', "`Card.selectionBehavior` must be provided if suggestions are present. In Card `#{card}`")
        return
      end

      allowed_values = ['at-most-one', 'any']
      return if allowed_values.include?(selection_behavior)

      error_msg = "`selectionBehavior` #{selection_behavior} not allowed. " \
                  "Allowed values: #{allowed_values.to_sentence}. In Card `#{card}`"
      add_message('error', error_msg)
    end

    def card_override_reasons_check(card)
      return unless card['overrideReasons'].is_a?(Array)

      card['overrideReasons'].each do |reason|
        override_reasons_required_fields.each do |field, type|
          validate_presence_and_type(reason, field, type, 'OverrideReason Coding')
        end
      end
    end

    def card_links_check(card) # rubocop:disable Metrics/CyclomaticComplexity
      return unless card['links'].is_a?(Array) && card['links'].present?

      card['links'].each do |link|
        link_required_fields.each do |field, type|
          validate_presence_and_type(link, field, type, 'Link')
        end
      end

      if card['links'].all? { |link| link['type'] == 'absolute' }
        external_reference_card_check(card)
      elsif card['links'].all? { |link| link['type'] == 'smart' }
        smart_app_card_check(card)
      else
        add_message(
          'error',
          "All links must either be `absolute` or `smart` in card: #{card}"
        )
      end
    end

    def external_reference_card_check(card)
      if card['suggestions'].present?
        add_message(
          'error',
          "Cards with `absolute` links must not contain suggestions. In card `#{card}`"
        )
      end

      card['links'].each do |link|
        next if link['appContext'].blank?

        add_message(
          'error',
          '`appContext` field must not be present if the link type is absolute: ' \
          "`#{link}`. In Card `#{card}`"
        )
      end
    end

    def smart_app_card_check(card)
      if card['suggestions'].blank?
        add_message(
          'error',
          "Cards with `smart` links must contain at least one suggestion. In card `#{card}`"
        )
      elsif card['suggestions'].any? { |suggestion| suggestion['actions'].present? }
        add_message(
          'error',
          "Cards with `smart` links must not contain any suggestion actions. In card `#{card}`"
        )
      end
    end

    def no_links_check(card, card_type)
      return unless card['links'].present?

      add_message(
        'error',
        "#{card_type} response must not contain links. In card: `#{card}`"
      )
    end

    def additional_orders_check(card)
      no_links_check(card, 'Additional Orders')
    end

    def create_or_update_coverage_check(card)
      no_links_check(card, 'Update Coverage Records')
    end

    def form_completion_check(card)
      no_links_check(card, 'Form Completion')
    end

    def propose_alternate_request_check(card)
      no_links_check(card, 'Propose Alternate Request')
    end

    def card_suggestions_check(card)
      return unless card['suggestions'].is_a?(Array) && card['suggestions'].present?

      card['suggestions'].each do |suggestion|
        process_suggestion(card, suggestion)
      end
    end

    def process_suggestion(card, suggestion)
      validate_presence_and_type(suggestion, 'label', String, 'Suggestion')
      validate_presence_and_type(suggestion, 'uuid', String, 'Suggestion')
      return unless suggestion['actions']

      validate_and_process_actions(card, suggestion)
    end

    def validate_and_process_actions(card, suggestion)
      actions = suggestion['actions']
      if !actions.is_a?(Array)
        add_message('error', "Suggestion `actions` field is not of type Array: `#{suggestion}`. In Card `#{card}`")
        return
      elsif actions.empty?
        add_message('error',
                    "Suggestion `actions` field should not be an empty Array: `#{suggestion}`. In Card `#{card}`")
        return
      end

      actions.each do |action|
        action_fields_validation(action)
      end
    end

    def card_source_check(card)
      source = card['source']
      return unless source.is_a?(Hash)

      source_required_fields.each do |field, type|
        validate_presence_and_type(source, field, type, 'Source')
      end

      card_source_topic_check(source['topic'])
      # TODO: How to validate topic binding to the ValueSet CRD Card Types?
    end

    def card_source_topic_check(topic)
      return unless topic.is_a?(Hash)

      source_topic_required_fields.each do |field, type|
        validate_presence_and_type(topic, field, type, 'Source topic')
      end
    end

    def card_summary_check(card)
      return if !card['summary'].is_a?(String) || card['summary'].length < 140

      add_message('error', "`summary` is over the 140-character limit: `#{card['summary']}`")
    end

    def card_indicator_check(card)
      return if !card['indicator'].is_a?(String) || ['info', 'warning', 'critical'].include?(card['indicator'])

      msg = "`indicator` is `#{card['indicator']}`. Allowed values are `info`, `warning`, `critical`: `#{card}`"
      add_message('error', msg)
    end

    def cards_check(cards, version = 'v221')
      cards.each do |card|
        current_error_count = messages.count { |msg| msg[:type] == 'error' }
        card_required_fields[version].each do |field, type|
          validate_presence_and_type(card, field, type, 'Card')
        end

        card_summary_check(card)
        card_indicator_check(card)
        card_source_check(card)

        valid_cards << card if current_error_count == messages.count { |msg| msg[:type] == 'error' }
      end
    end

    def response_label(index = nil)
      "Server response #{index}"
    end

    def perform_cards_validation(cards, response_has_system_actions, version, response_index)
      unless cards
        add_message('error', "#{response_label(response_index + 1)} did not have the `cards` field.")
        return
      end
      unless cards.is_a?(Array)
        add_message('error', "`cards` field of #{response_label(response_index + 1).downcase} is not an array.")
        return
      end
      warning do
        assert cards.present? || response_has_system_actions,
               "#{response_label(response_index + 1)} has no decision support."
      end
      cards_check(cards, version)
    end

    def all_requests
      @all_requests ||= HOOKS.each_with_object([]) do |hook, reqs|
        load_tagged_requests(hook)
        reqs.concat(requests)
      end
    end
  end
end
