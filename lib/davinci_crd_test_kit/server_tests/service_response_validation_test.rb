require_relative '../cards_validation'
require_relative '../server_hook_helper'

module DaVinciCRDTestKit
  class ServiceResponseValidationTest < Inferno::Test
    include DaVinciCRDTestKit::CardsValidation
    include DaVinciCRDTestKit::ServerHookHelper

    title 'All service responses contain valid cards and optional systemActions'
    id :crd_service_response_validation
    description %(
      As per the [CDS Hooks spec section on CDS Service Response](https://cds-hooks.hl7.org/2.0/#cds-service-response),
      a successful server's response to a service request must be a JSON object containing a `cards` array.
      It must also contain a `systemActions` array for `appointment-book` and `order-sign` hook.

      Each card must contain the following required fields: `summary`, `indicator`, and `source`.
      The required fields must have a valid data structure.
    )
    input :invoked_hook
    output :valid_cards, :valid_system_actions

    SYSTEM_ACTIONS_HOOK_NAMES = ['appointment-book', 'order-sign', 'order-dispatch'].freeze

    def valid_cards
      @valid_cards ||= []
    end

    def valid_system_actions
      @valid_system_actions ||= []
    end

    def system_actions_check(system_actions)
      system_actions.each do |action|
        current_error_count = messages.count { |msg| msg[:type] == 'error' }
        action_fields_validation(action)
        valid_system_actions << action if current_error_count == messages.count { |msg| msg[:type] == 'error' }
      end
    end

    def perform_system_actions_validation(system_actions, response_index)
      if SYSTEM_ACTIONS_HOOK_NAMES.include?(invoked_hook) && system_actions.nil?
        msg = "Server response #{response_index + 1} did not have `systemActions` field." \
              "Must be present for #{invoked_hook}."
        add_message('error', msg)
      end
      return if system_actions.nil?

      unless system_actions.is_a?(Array)
        add_message('error', "`systemActions` of server response #{response_index + 1} is not an array.")
        return
      end
      system_actions_check(system_actions)
    end

    run do
      load_tagged_requests(tested_hook_name)
      skip_if requests.blank?, "No #{tested_hook_name} request was made in a previous test as expected."
      successful_requests = requests.select { |request| request.status == 200 }
      skip_if successful_requests.empty?, 'All service requests were unsuccessful.'

      info do
        unsuccessful_count = (requests - successful_requests).length
        assert unsuccessful_count.zero?, "#{unsuccessful_count} out of #{requests.length} requests were unsuccessful"
      end

      successful_requests.each_with_index do |request, index|
        service_response = JSON.parse(request.response_body)
        perform_cards_validation(service_response['cards'], index, service_response['systemActions'].present?)

        perform_system_actions_validation(service_response['systemActions'], index)
      rescue JSON::ParserError
        add_message('error', "Invalid JSON: server response #{index + 1} is not a valid JSON.")
      end

      output valid_system_actions: valid_system_actions.to_json
      output valid_cards: valid_cards.to_json

      no_error_validation('Some service responses are not valid. Check messages for issues found.')
    end
  end
end
