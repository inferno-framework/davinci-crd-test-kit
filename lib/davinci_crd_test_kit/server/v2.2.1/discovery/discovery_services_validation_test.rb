require_relative '../../server_test_helper'

module DaVinciCRDTestKit
  module V221
    class DiscoveryServicesValidationTest < Inferno::Test
      include DaVinciCRDTestKit::ServerTestHelper

      title 'Discovery response contains valid services'
      id :crd_v221_discovery_services_validation
      description %(
        As per the [CDS Hooks Spec](https://cds-hooks.hl7.org/2.0/#response),
        the response to the discovery endpoint SHALL be an object containing
        a list of CDS services. If your CDS server hosts no CDS services,
        the discovery endpoint should return a 200 HTTP response with
        an empty array of services.

        Each CDS service must contain the following required fields:
        `hook`, `description`, and `id`.

        Additionally, the [CRD
        Spec](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/deviations.html#crd-version-declaration)
        states that "CRD servers SHALL declare at least one supported CRD
        version for each supported hook" using the `davinci-crd.version`
        extension.

        This test checks for the presence of the required fields and
        validates that they are of the correct type.

        CDS services provided by the server to support use cases outside the
        scope of the CRD specification can be provided in an ignore list input to
        opt-out of CRD validation.

        The test will be skipped if the server hosts no CRD CDS services.
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@dev-1'

      input :cds_services
      input :crd_discovery_service_ignore_list,
            title: 'Service ID Ignore List',
            description: %(
              In the case that CDS services advertised on this server support
              use cases outside the scope of the CRD specification, provide a
              comma-separated list of service IDs to opt-out of CRD validation.
              Ignored services will not be stored for use in later tests.  If
              blank, all services are checked and saved.
            ),
            optional: true
      output :appointment_book_service_ids, :encounter_start_service_ids, :encounter_discharge_service_ids,
             :order_dispatch_service_ids, :order_select_service_ids, :order_sign_service_ids

      EXTENSION_KEY = 'davinci-crd.version'.freeze

      def required_fields
        {
          'hook' => String,
          'description' => String,
          'id' => String,
          'extension' => Hash
        }
      end

      run do
        object = parse_json(cds_services)
        assert object['services'], 'Discovery response did not contain `services`'

        services = object['services']
        assert services.is_a?(Array), 'Services field of the CDS Discovery response object is not an array.'

        ignored_service_ids = crd_discovery_service_ignore_list.to_s.split(',').map(&:strip).reject(&:blank?)
        services
          .select { |service| ignored_service_ids.include?(service['id']) }
          .each do |service|
            info "Ignoring service `#{service['id']}` because it is in the ignore list."
          end
        services_for_crd_validation = services.reject { |service| ignored_service_ids.include?(service['id']) }

        service_hooks_to_ids = services_for_crd_validation.each_with_object({}) do |service, hash|
          hash[service['hook']] ||= []
          hash[service['hook']] << service['id'] if service['id']
        end

        output appointment_book_service_ids: service_hooks_to_ids['appointment-book']&.join(', '),
               encounter_start_service_ids: service_hooks_to_ids['encounter-start']&.join(', '),
               encounter_discharge_service_ids: service_hooks_to_ids['encounter-discharge']&.join(', '),
               order_dispatch_service_ids: service_hooks_to_ids['order-dispatch']&.join(', '),
               order_select_service_ids: service_hooks_to_ids['order-select']&.join(', '),
               order_sign_service_ids: service_hooks_to_ids['order-sign']&.join(', ')

        skip_if services.empty?, 'Server hosts no CDS Services.'
        skip_if services_for_crd_validation.empty?, 'Ignore list excludes all CDS Services from validation.'

        services_for_crd_validation.each do |service|
          required_fields.each do |field, type|
            assert(service[field], "Service `#{service['id']}` did not contain required field: `#{field}`")
            assert(service[field].is_a?(type), "Service `#{service['id']}`: field `#{field}` is not of type #{type}")
          end

          assert service['extension'].key?(EXTENSION_KEY),
                 "Service `#{service['id']}`: does not contain a `#{EXTENSION_KEY}` extension"
          assert service['extension'][EXTENSION_KEY].is_a?(Array),
                 "Service `#{service['id']}`: `#{EXTENSION_KEY}` extension is not of type Array"
          assert service['extension'][EXTENSION_KEY].present?,
                 "Service `#{service['id']}`: `#{EXTENSION_KEY}` extension is empty"
          non_string_values = service['extension'][EXTENSION_KEY].reject { |value| value.is_a? String }
          assert non_string_values.blank?,
                 "Service `#{service['id']}`: `#{EXTENSION_KEY}` extension contains non-string values: " \
                 "#{non_string_values.join(', ')}"

          invalid_versions =
            service['extension'][EXTENSION_KEY]
              .reject { |version| version.match?(/\A[1-9]\d*\.\d+\Z/) }

          assert invalid_versions.blank?,
                 "Service `#{service['id']}`: `#{EXTENSION_KEY}` extension contains invalid " \
                 "version strings: #{invalid_versions.join(', ')}"
        end
      end
    end
  end
end
