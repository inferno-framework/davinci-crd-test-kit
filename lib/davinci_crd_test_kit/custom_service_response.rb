require_relative 'fhirpath_on_cds_request'
require_relative 'replace_tokens'
require_relative 'gather_response_generation_data'

module DaVinciCRDTestKit
  # Build responses using tester-provided template
  module CustomServiceResponse
    include DaVinciCRDTestKit::FhirpathOnCDSRequest
    include DaVinciCRDTestKit::ReplaceTokens
    include DaVinciCRDTestKit::GatherResponseGenerationData

    def custom_response_template
      @custom_response_template ||=
        JSON.parse(result.input_json)
          .find { |input| input['name'].include?('custom_response_template') }
          &.dig('value')
    end

    def parsed_user_input
      JSON.parse(custom_response_template)
    rescue JSON::ParserError
      error_response('Invalid template provided for custom Inferno CRD response: invalid JSON', code: 500)
      nil
    end

    def build_custom_hook_response
      hook_response = parsed_user_input
      return nil unless hook_response.present?

      # filter cards and actions
      filter_response(hook_response)

      # update cards and actions
      finalize_card_list(hook_response)
      hook_response['systemActions'] = instantiate_actions(hook_response, 'systemActions')

      hook_response
    end

    def finalize_card_list(hook_response)
      add_first_default(hook_response, 'cards') if hook_response['cards'].blank? && defaults_extension?(hook_response,
                                                                                                        'cards')
      remove_defaults_extension(hook_response, 'cards')
      hook_response['cards'].each { |card| update_card(card) }
    end

    def update_card(card)
      card['uuid'] = SecureRandom.uuid if card['uuid'].present?

      return unless card['suggestions'].is_a?(Array)

      card['suggestions'].each { |suggestion| update_suggestion(suggestion) }
    end

    def update_suggestion(suggestion)
      suggestion['uuid'] = SecureRandom.uuid if suggestion['uuid'].present?

      return unless suggestion['actions'].is_a?(Array)

      suggestion['actions'] = instantiate_actions(suggestion, 'actions')
    end

    def instantiate_actions(parent, list_element)
      actions = parent[list_element]
      default_actions = get_defaults_extension_value(parent, list_element)
      remove_defaults_extension(parent, list_element)

      return [] unless actions.present? || default_actions.present?

      instantiated_action_list = []
      instantiated_resources_list = []
      actions.each { |action| instantiate_an_action(action, instantiated_action_list, instantiated_resources_list) }
      default_actions.each do |action|
        instantiate_an_action(action, instantiated_action_list, instantiated_resources_list,
                              default_action: true)
      end

      instantiated_action_list
    end

    def instantiate_an_action(action, instantiated_action_list, instantiated_resources_list,
                              default_action: false)
      replace_tokens(action, request_body)

      if object_has_resource_selection_criteria?(action)
        targets = get_target_resources_for_request(get_object_resource_selection_criteria_extension_value(action))
        remove_resource_selection_criteria(action)
        instantiate_action_using_targets(action, targets, instantiated_action_list, instantiated_resources_list,
                                         default_action)
      elsif !default_action || instantiated_action_list.blank?
        instantiated_action_list << action
      end
    end

    def instantiate_action_using_targets(action, targets, instantiated_action_list, instantiated_resources_list,
                                         default_action)
      targets.each do |target|
        target_reference = "#{target['resourceType']}/#{target['id']}"
        next if default_action && instantiated_resources_list.include?(target_reference)

        instantiated_resources_list << target_reference unless instantiated_resources_list.include?(target_reference)
        instantiated_action_list << create_instantiated_action_from_target(action, target)
      end
    end

    def create_instantiated_action_from_target(action, target_resource)
      instantiated_action = JSON.parse(action.to_json)
      if instantiated_action['type'] == 'delete'
        instantiated_action['resourceId'] = "#{target_resource['resourceType']}/#{target_resource['id']}"
      elsif instantiated_action['resource'].is_a?(Hash)
        # merge action's resource into the target resource.
        # Merge extension lists, keeping duplicate url from action's resource,
        # otherwise replace (top-level elements)
        instantiated_action['resource'] =
          merge_action_resouce_into_target(instantiated_action['resource'], target_resource)

        coverage_information_ext = instantiated_action['resource']['extension']&.find do |ext|
          ext['url'] == 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information'
        end
        default_coverage_information_elements(coverage_information_ext) if coverage_information_ext.present?
      else
        instantiated_action['resource'] = target_resource
      end

      instantiated_action
    end

    def merge_action_resouce_into_target(action_resource, target_resource)
      target_resource.merge(action_resource) do |key, old_value, new_value|
        if key == 'extension'
          old_value.select do |existing_extention|
            new_value.find { |incoming_extension| existing_extention['url'] == incoming_extension['url'] }.blank?
          end + new_value
        else
          new_value
        end
      end
    end

    def filter_response(hook_response)
      filter_and_separate_defaults(hook_response, 'cards')
      hook_response['cards'].each do |card|
        card['suggestions']&.each { |suggestion| filter_and_separate_defaults(suggestion, 'actions') }
      end
      filter_and_separate_defaults(hook_response, 'systemActions')
    end

    def filter_and_separate_defaults(parent, list_element)
      defaults_ext = default_extension_name(list_element)
      define_extension(parent, defaults_ext, [])
      parent[list_element]&.select! do |object|
        if object_has_inclusion_criteria?(object)
          if object_is_a_default?(object)
            remove_inclusion_criteria(object)
            parent['extension'][defaults_ext] << object

            false
          elsif object_included_for_this_request?(object)
            remove_inclusion_criteria(object)
            true
          else
            false
          end
        else
          true
        end
      end
    end

    def object_is_a_default?(object)
      get_object_inclusion_criteria_extension_value(object) == 'default'
    end

    def default_extension_name(list_element)
      "com.inferno.internal.default#{list_element.capitalize}"
    end

    def defaults_extension?(object, list_element)
      get_defaults_extension_value(object, list_element).present?
    end

    def remove_defaults_extension(object, list_element)
      remove_extension(object, default_extension_name(list_element))
    end

    def get_defaults_extension_value(object, list_element)
      get_extension_value(object, default_extension_name(list_element))
    end

    def add_first_default(object, list_element)
      object[list_element] << get_extension_value(object, default_extension_name(list_element)).first
    end

    def object_has_inclusion_criteria?(object)
      get_object_inclusion_criteria_extension_value(object).present?
    end

    def get_object_inclusion_criteria_extension_value(object)
      get_extension_value(object, 'com.inferno.inclusionCriteria')
    end

    def remove_inclusion_criteria(object)
      remove_extension(object, 'com.inferno.inclusionCriteria')
    end

    def object_has_resource_selection_criteria?(object)
      get_object_resource_selection_criteria_extension_value(object).present?
    end

    def get_object_resource_selection_criteria_extension_value(object)
      get_extension_value(object, 'com.inferno.resourceSelectionCriteria')
    end

    def remove_resource_selection_criteria(object)
      remove_extension(object, 'com.inferno.resourceSelectionCriteria')
    end

    def object_included_for_this_request?(object)
      evaluate_inclusion_for_request(get_object_inclusion_criteria_extension_value(object))
    end

    def evaluate_inclusion_for_request(inclusion_criteria)
      return false if inclusion_criteria == 'default'

      result = execute_fhirpath_on_cds_request(request_body, inclusion_criteria)

      if result.empty? || result.length > 1
        false
      elsif [true, false].include?(result[0])
        result[0]
      else
        result[0] != 'false' # single non-false entry is always true for fhirpath
      end
    end

    def get_target_resources_for_request(resource_selection_criteria)
      execute_fhirpath_on_cds_request(request_body, resource_selection_criteria)
    end

    def define_extension(parent, extension, value)
      parent['extension'] = {} if parent['extension'].nil?
      return if parent['extension'][extension].present?

      parent['extension'][extension] = value
    end

    def remove_extension(parent, extension)
      parent['extension']&.delete(extension)
      return unless parent['extension'].blank?

      parent.delete('extension')
    end

    def get_extension_value(parent, extension)
      parent.dig('extension', extension)
    end

    def default_coverage_information_elements(coverage_info_ext)
      default_coverage_information_coverage(coverage_info_ext)
      default_coverage_information_date(coverage_info_ext)
      default_coverage_information_assertion_id(coverage_info_ext)
    end

    def default_coverage_information_coverage(coverage_info_ext)
      existing_coverage_ext = coverage_info_ext['extension']&.find { |ext| ext['url'] == 'coverage' }
      coverage_ext =
        if existing_coverage_ext.blank?
          new_coverage_ext = { url: 'coverage' }
          coverage_info_ext['extension'] << new_coverage_ext
          new_coverage_ext
        else
          existing_coverage_ext
        end

      return unless coverage_ext['valueReference'].blank? || coverage_ext['valueReference']['reference'].blank?

      coverage_reference = "Coverage/#{request_coverage&.id}"
      coverage_ext['valueReference'] = { reference: coverage_reference }
    end

    def default_coverage_information_date(coverage_info_ext)
      existing_date_ext = coverage_info_ext['extension']&.find { |ext| ext['url'] == 'date' }
      date_ext =
        if existing_date_ext.blank?
          new_date_ext = { url: 'date' }
          coverage_info_ext['extension'] << new_date_ext
          new_date_ext
        else
          existing_date_ext
        end

      return unless date_ext['valueDate'].blank?

      date_ext['valueDate'] = Time.now.utc.strftime('%Y-%m-%d')
    end

    def default_coverage_information_assertion_id(coverage_info_ext)
      existing_assertion_id_ext = coverage_info_ext['extension']&.find { |ext| ext['url'] == 'coverage-assertion-id' }
      assertion_id_ext =
        if existing_assertion_id_ext.blank?
          new_assertion_id_ext = { url: 'coverage-assertion-id' }
          coverage_info_ext['extension'] << new_assertion_id_ext
          new_assertion_id_ext
        else
          existing_assertion_id_ext
        end

      return unless assertion_id_ext['valueString'].blank?

      assertion_id_ext['valueString'] = SecureRandom.hex(32)
    end
  end
end
