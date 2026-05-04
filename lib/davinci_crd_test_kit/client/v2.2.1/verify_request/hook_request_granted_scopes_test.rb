require_relative '../../crd_client_options'

module DaVinciCRDTestKit
  module V221
    class HookRequestGrantedScopesTest < Inferno::Test
      id :crd_v221_hook_request_granted_scopes
      title 'Hook requests grant the requested scopes'
      description %(
        As a part of registration, CRD Clients and Services agree on a set of scopes that the Service needs
        to obtain all data that goes into creating hook responses. For the purposes of Inferno's simulated
        payer CRD Service acting as a part of these tests that evaluate conformance to the CRD specification,
        access to all US Core resource types are required.

        THe test verifies that scopes covering the US Core data types are granted and no more. Clients may
        choose to grant either user scopes or patient scopes. If choosing patient scopes, note that the token
        is used by default for testing the complete US Core FHIR API, so with patient scopes either that
        single patient needs to demonstrate the full scope of US Core or another access token will need to be
        provided for those tests.
      )

      def hook_name
        config.options[:hook_name]
      end

      def crd_test_group
        config.options[:crd_test_group]
      end

      def tags_to_load
        crd_test_group.present? ? [hook_name, crd_test_group] : [hook_name]
      end

      def request_prefix
        if @request_number.blank?
          ''
        else
          "(Request #{@request_number}) "
        end
      end

      run do
        hook_requests = load_tagged_requests(*tags_to_load)

        skip_if hook_requests.blank?, "No #{hook_name} hook requests received."

        hook_requests.each_with_index do |request, request_index|
          @request_number = request_index + 1

          request_body = parsed_json_if_valid(request.request_body)
          next unless request_body.present?

          # check that the resource scopes match what Inferno requested
          granted_resource_scopes = granted_resource_scopes(request_body)
          check_granted_resources(granted_resource_scopes)
          check_granted_scopes_level(granted_resource_scopes)
          check_granted_interactions(granted_resource_scopes)
        end

        assert_no_error_messages('Granted scopes do not match what was requested. See Messages for details.')
      end

      def requested_scope_resources
        case suite_options[:us_core_version]
        when CRDClientOptions::US_CORE_3
          CRDClientOptions::US_CORE_3_RESOURCE_TYPES
        when CRDClientOptions::US_CORE_6, CRDClientOptions::US_CORE_7
          CRDClientOptions::US_CORE_6_7_RESOURCE_TYPES
        end
      end

      def granted_resource_scopes(request_body)
        granted_scopes = request_body.dig('fhirAuthorization', 'scope')
        return [] unless granted_scopes.present?

        granted_scopes.split(' ').grep(%r{\A\S+/\S+\.\S+\z}) # rubocop:disable Style/RedundantArgument
      end

      def check_granted_resources(granted_resource_scopes)
        granted_scope_resources = granted_resource_scopes.map { |scope| scope.split('/').last.split('.').first }

        missing_resources = requested_scope_resources - granted_scope_resources
        extra_resources = granted_scope_resources - requested_scope_resources
        if missing_resources.present?
          add_message('error', "#{request_prefix} Granted scopes missing the following " \
                               "requested resource types: #{missing_resources.join(', ')}")
        end
        if extra_resources.present?
          add_message('error', "#{request_prefix} Granted scopes included the following resource types " \
                               "beyond what was requested: #{extra_resources.join(', ')}")
        end

        nil
      end

      def check_granted_interactions(granted_resource_scopes)
        return if granted_resource_scopes.all? { |scope| scope.split('.').last == 'rs' }

        if granted_resource_scopes.all? { |scope| scope.split('.').last == 'read' }
          add_message('warning',
                      "#{request_prefix} SMART v1 `read` scope used. Use of SMART v2 `rs` scope recommended.")
          return
        end

        add_message('error', "#{request_prefix} Some granted resource scopes do not provide " \
                             "requested 'rs' (read and search) interactions.")
      end

      def check_granted_scopes_level(granted_resource_scopes)
        level = scopes_level(granted_resource_scopes)
        if level.blank?
          add_message('error',
                      "#{request_prefix} Requested scopes did not use a consistent level of scope (patient or user).")
          return
        end

        return if ['user', 'patient'].include?(level)

        add_message('error',
                    "#{request_prefix} Unexpected level for granted scopes: " \
                    "expected 'user' or 'patient', got '#{level}'.")
      end

      def scopes_level(granted_resource_scopes)
        return nil unless granted_resource_scopes.present? && all_scopes_same_level?(granted_resource_scopes)

        granted_resource_scopes.first.split('/').first
      end

      def all_scopes_same_level?(granted_resource_scopes)
        return true unless granted_resource_scopes.present?

        level = granted_resource_scopes.first.split('/').first
        granted_resource_scopes.each do |scope|
          return false if scope.split('/').first != level
        end

        true
      end
    end
  end
end
