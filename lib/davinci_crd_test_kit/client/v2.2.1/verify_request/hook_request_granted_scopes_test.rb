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
        The CRD IG [requires](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/foundation.html#ci-c-found-21)
        that CRD clients limit the scopes provided in their access token as narrowly as feasible to the
        data the CRD server identifies as necessary for its decision support. To evaluate the CRD client's
        conformance to the CRD specification, Inferno's simulated CRD server needs read and search access
        to all resource types profiled in the selected version of the US Core IG, and it may also read
        the request resources (orders and appointments) that the CRD client sends in hook requests.
        While in a real exchange scenario, an organization operating CRD clients might well reject such
        a set of scopes as too large, for the purposes of testing, the CRD client must grant these scopes
        in order for Inferno to verify its conformance. See the
        [CRD Test Kit wiki](#{CRDClientOptions::ACCESS_TOKEN_SCOPES_WIKI_URL})
        for the full list of scopes.

        During this test, Inferno verifies that the `fhirAuthorization.scope` field of each hook request:
        - grants read and search access, either as `rs` or as separate `r` and `s` scopes, to every
          resource type profiled in the selected version of the US Core IG.
        - grants access to no other resource types, except the types that Inferno's Coverage Information
          responses can target (#{CardsIdentification::COVERAGE_INFO_EXPECTED_RESOURCE_TYPES.join(', ')})
          and, when US Core 3.1.1 is selected, Coverage, which the CRD client may but need not include.
        - grants no create, update or delete access.
        - does not use wildcard (`*`) resource scopes.
        - uses either user scopes or patient scopes, but not both.

        SMART v1 `read` scopes are accepted with a warning. If choosing patient scopes, note that the
        token is used by default for complete testing of the CRD client's US Core FHIR API, so either
        that single patient would need to demonstrate all US Core resources and must support elements
        or another access token would need to be provided when testing the CRD client's FHIR API.
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@found-21'

      RESOURCE_SCOPE_REGEX = %r{\A(?<level>[^/\s]+)/(?<resource_type>[^.\s]+)\.(?<access>[^?\s]+)(?<query>\?\S*)?\z}
      READ_AND_SEARCH = ['r', 's'].freeze
      WRITE_PERMISSIONS = ['c', 'u', 'd'].freeze
      SMART_V1_PERMISSIONS = {
        'read' => READ_AND_SEARCH,
        'write' => WRITE_PERMISSIONS,
        '*' => READ_AND_SEARCH + WRITE_PERMISSIONS
      }.freeze

      run do
        hook_requests = load_interaction_group_requests

        skip_if hook_requests.blank?, "No #{hook_name} hook requests received."

        hook_requests.each_with_index do |request, request_index|
          request_body = parse_json_request_entity(request.request_body, 'Request body', request_index)
          next unless request_body_object?(request_body, request.request_body, request_index)

          resource_scopes = granted_resource_scopes(request_body, request_index)
          next if resource_scopes.nil?

          check_granted_scopes_level(resource_scopes, request_index)
          check_granted_access(resource_scopes, request_index)
          check_granted_resources(resource_scopes, request_index)
        end

        assert_no_error_messages("#{requests_with_errors_prefix}Granted scopes do not match the requested scopes. " \
                                 'See Messages for details.')
      end

      def requested_scope_resources
        CRDClientOptions.us_core_resource_types(suite_options[:us_core_version])
      end

      def optional_scope_resources
        CRDClientOptions.optional_scope_resource_types(suite_options[:us_core_version])
      end

      # A nil parsed body means the body was not valid JSON (already reported), unless it was the JSON null.
      def request_body_object?(request_body, raw_body, request_index)
        return true if request_body.is_a?(Hash)
        return false if request_body.nil? && raw_body.to_s.strip != 'null'

        add_request_message('error', 'Request body is not a JSON object.', request_index)
        false
      end

      # The resource scopes in fhirAuthorization.scope, or nil (with an error message) when there are none
      # to check.
      def granted_resource_scopes(request_body, request_index)
        granted_scopes = granted_scope_string(request_body, request_index)
        return if granted_scopes.nil?

        resource_scopes = granted_scopes.split.filter_map { |scope| parse_resource_scope(scope) }
        return resource_scopes if resource_scopes.present?

        add_request_message('error', 'No resource scopes were granted in the `fhirAuthorization.scope` field.',
                            request_index)
        nil
      end

      def granted_scope_string(request_body, request_index)
        fhir_authorization = request_body['fhirAuthorization']
        unless fhir_authorization.is_a?(Hash)
          add_request_message('error',
                              if fhir_authorization.nil?
                                'No `fhirAuthorization` field, so no scopes were granted.'
                              else
                                '`fhirAuthorization` is not a JSON object.'
                              end,
                              request_index)
          return
        end

        scope = fhir_authorization['scope']
        return scope if scope.is_a?(String)

        add_request_message('error',
                            if scope.nil?
                              'No `fhirAuthorization.scope` field, so no scopes were granted.'
                            else
                              '`fhirAuthorization.scope` is not a string.'
                            end,
                            request_index)
        nil
      end

      def parse_resource_scope(scope)
        match = RESOURCE_SCOPE_REGEX.match(scope)
        return unless match.present?

        {
          scope:,
          level: match[:level],
          resource_type: match[:resource_type],
          permissions: scope_permissions(match[:access]),
          smart_v1_read: match[:access] == 'read',
          granular: match[:query].present?
        }
      end

      # Returns the SMART v2 permission letters the access part of a scope grants, or nil if unrecognized.
      def scope_permissions(access)
        return SMART_V1_PERMISSIONS[access] if SMART_V1_PERMISSIONS.key?(access)
        return access.chars.uniq if access.match?(/\A[cruds]+\z/)

        nil
      end

      def scope_list(scopes)
        scopes.map { |scope| "`#{scope[:scope]}`" }.join(', ')
      end

      def check_granted_access(resource_scopes, request_index)
        unrecognized_scopes = resource_scopes.select { |scope| scope[:permissions].nil? }
        add_scopes_error('Granted scopes include an unrecognized access level', unrecognized_scopes, request_index)

        write_scopes = resource_scopes.select { |scope| scope[:permissions]&.intersect?(WRITE_PERMISSIONS) }
        add_scopes_error('Granted scopes include create, update, or delete access, which was not requested',
                         write_scopes, request_index)

        return unless resource_scopes.any? { |scope| scope[:smart_v1_read] }

        add_request_message('warning', 'SMART v1 `read` scope used. Use of SMART v2 `rs` scope recommended.',
                            request_index)
      end

      def add_scopes_error(message, scopes, request_index)
        return unless scopes.present?

        add_request_message('error', "#{message}: #{scope_list(scopes)}.", request_index)
      end

      def check_granted_resources(resource_scopes, request_index)
        wildcard_scopes, type_scopes = resource_scopes.partition { |scope| scope[:resource_type] == '*' }
        if wildcard_scopes.present?
          add_scopes_error('Granted scopes include wildcard resource scopes, which grant access to all resource ' \
                           'types rather than only the requested ones', wildcard_scopes, request_index)
        else
          check_missing_resources(type_scopes, request_index)
          check_read_and_search(type_scopes, request_index)
        end
        check_extra_resources(type_scopes, request_index)
      end

      def check_missing_resources(type_scopes, request_index)
        full_type_scopes = type_scopes.reject { |scope| scope[:granular] }
        missing_resources = requested_scope_resources - full_type_scopes.map { |scope| scope[:resource_type] }
        return unless missing_resources.present?

        message = 'Granted scopes missing the following requested resource types: ' \
                  "#{missing_resources.join(', ')}."
        granular_only_resources = missing_resources & type_scopes.map { |scope| scope[:resource_type] }
        if granular_only_resources.present?
          message += ' Scopes restricted by search parameters were granted for ' \
                     "#{granular_only_resources.join(', ')}, but they do not grant access to all resources " \
                     'of the type.'
        end
        add_request_message('error', message, request_index)
      end

      def check_read_and_search(type_scopes, request_index)
        permissions_by_type = permissions_by_resource_type(type_scopes)
        partial_resources = requested_scope_resources.select do |resource_type|
          permissions_by_type.key?(resource_type) && (READ_AND_SEARCH - permissions_by_type[resource_type]).present?
        end
        return unless partial_resources.present?

        add_request_message('error', 'Granted scopes do not provide both read and search access to the following ' \
                                     "requested resource types: #{partial_resources.join(', ')}.", request_index)
      end

      # Permissions granted for each resource type by scopes that are not restricted by search parameters.
      def permissions_by_resource_type(type_scopes)
        type_scopes.reject { |scope| scope[:granular] }
          .group_by { |scope| scope[:resource_type] }
          .transform_values { |scopes| scopes.flat_map { |scope| scope[:permissions].to_a } }
      end

      def check_extra_resources(type_scopes, request_index)
        extra_resources = type_scopes.map { |scope| scope[:resource_type] }.uniq -
                          requested_scope_resources - optional_scope_resources
        return unless extra_resources.present?

        add_request_message('error', 'Granted scopes include the following resource types ' \
                                     "beyond what was requested: #{extra_resources.join(', ')}.", request_index)
      end

      def check_granted_scopes_level(resource_scopes, request_index)
        level = scopes_level(resource_scopes)
        if level.blank?
          add_request_message('error',
                              'Granted scopes did not use a consistent level of scope (patient or user).',
                              request_index)
          return
        end

        return if ['user', 'patient'].include?(level)

        add_request_message('error',
                            "Unexpected level for granted scopes: expected 'user' or 'patient', got '#{level}'.",
                            request_index)
      end

      def scopes_level(resource_scopes)
        levels = resource_scopes.map { |scope| scope[:level] }.uniq
        levels.first if levels.size == 1
      end
    end
  end
end
