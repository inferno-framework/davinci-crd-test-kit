require_relative '../../multi_request_message_helper'
require_relative '../../crd_client_options'
require_relative '../../tagged_request_load_helper'

module DaVinciCRDTestKit
  module V221
    class HookRequestGrantedScopesTest < Inferno::Test
      include DaVinciCRDTestKit::MultiRequestMessageHelper
      include DaVinciCRDTestKit::TaggedRequestLoadHelper

      id :crd_v221_hook_request_granted_scopes
      title 'Hook requests grant the requested scopes'
      description %(
        As a part of registration, CRD clients and servers agree on a set of scopes that the server needs
        to obtain all data that goes into creating hook responses. For the purposes of simulating a
        payer CRD server acting as a part of these tests that evaluate conformance to the CRD specification,
        Inferno requires access to all US Core resource types. While in a real exchange scenario, a CRD client
        organization might well reject such a set of scopes as too large, for the purposes of testing, the client
        must grant these scopes in order for Inferno to verify its conformance.

        During this test, Inferno will verify that the requested scopes covering all resource types profiled in
        the selected version of the US Core IG are granted and no more. Clients may choose to grant either user scopes
        or patient scopes. If choosing patient scopes, note that the token is used by default for complete testing
        of the client's US Core FHIR API, so either that single patient would need to
        demonstrate all US Core resources and must support elements or another access token would need
        to be provided when testing the client's FHIR API.
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@found-21'

      run do
        hook_requests = load_hook_requests

        skip_if hook_requests.blank?, "No #{hook_name} hook requests received."

        hook_requests.each_with_index do |request, request_index|
          request_body = parse_json_request_entity(request.request_body, 'Request body', request_index)
          next unless request_body.present?

          # check that the resource scopes match what Inferno requested
          granted_resource_scopes = granted_resource_scopes(request_body)
          check_granted_resources(granted_resource_scopes, request_index)
          check_granted_scopes_level(granted_resource_scopes, request_index)
          check_granted_interactions(granted_resource_scopes, request_index)
        end

        assert_no_error_messages("#{requests_with_errors_prefix}Granted scopes do not match the requested scopes. " \
                                 'See Messages for details.')
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

      def check_granted_resources(granted_resource_scopes, request_index)
        granted_scope_resources = granted_resource_scopes.map { |scope| scope.split('/').last.split('.').first }

        missing_resources = requested_scope_resources - granted_scope_resources
        extra_resources = granted_scope_resources - requested_scope_resources
        if missing_resources.present?
          add_request_message('error', 'Granted scopes missing the following ' \
                                       "requested resource types: #{missing_resources.join(', ')}", request_index)
        end
        return unless extra_resources.present?

        add_request_message('error', 'Granted scopes included the following resource types ' \
                                     "beyond what was requested: #{extra_resources.join(', ')}", request_index)
      end

      def check_granted_interactions(granted_resource_scopes, request_index)
        return if granted_resource_scopes.all? { |scope| scope.split('.').last == 'rs' }

        if granted_resource_scopes.all? { |scope| scope.split('.').last == 'read' }
          add_request_message('warning',
                              'SMART v1 `read` scope used. Use of SMART v2 `rs` scope recommended.',
                              request_index)
          return
        end

        add_request_message('error', 'Some granted resource scopes do not provide ' \
                                     "requested 'rs' (read and search) interactions.", request_index)
      end

      def check_granted_scopes_level(granted_resource_scopes, request_index)
        level = scopes_level(granted_resource_scopes)
        if level.blank?
          add_request_message('error',
                              'Requested scopes did not use a consistent level of scope (patient or user).',
                              request_index)
          return
        end

        return if ['user', 'patient'].include?(level)

        add_request_message('error',
                            "Unexpected level for granted scopes: expected 'user' or 'patient', got '#{level}'.",
                            request_index)
      end

      def scopes_level(granted_resource_scopes)
        return nil unless granted_resource_scopes.present? && all_scopes_same_level?(granted_resource_scopes)

        granted_resource_scopes.first.split('/').first
      end

      def all_scopes_same_level?(granted_resource_scopes)
        granted_resource_scopes.map { |s| s.split('/').first }.uniq.size <= 1
      end
    end
  end
end
