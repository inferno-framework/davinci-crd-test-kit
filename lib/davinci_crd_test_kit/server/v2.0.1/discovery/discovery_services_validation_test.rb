require_relative '../test_helper'

module DaVinciCRDTestKit
  class DiscoveryServicesValidationTest < Inferno::Test
    include DaVinciCRDTestKit::TestHelper

    title 'Discovery response contains valid services'
    id :crd_discovery_services_validation
    description %(
      As per the [CDS Hooks Spec](https://cds-hooks.hl7.org/2.0/#response),
      the response to the discovery endpoint SHALL be an object containing
      a list of CDS services. If your CDS server hosts no CDS services,
      the discovery endpoint should return a 200 HTTP response with
      an empty array of services.

      Each CDS service must contain the following required fields:
      `hook`, `description`, and `id`.

      This test checks for the presence of the required fields and
      validates that they are of the correct type.

      The test will be skipped if the server hosts no CDS services.
    )

    input :cds_services
    output :appointment_book_service_ids, :encounter_start_service_ids, :encounter_discharge_service_ids,
           :order_dispatch_service_ids, :order_select_service_ids, :order_sign_service_ids

    def required_fields
      {
        'hook' => String,
        'description' => String,
        'id' => String
      }
    end

    run do
      object = parse_json(cds_services)
      assert object['services'], 'Discovery response did not contain `services`'

      services = object['services']
      assert services.is_a?(Array), 'Services field of the CDS Discovery response object is not an array.'
      skip_if services.empty?, 'Server hosts no CDS Services.'

      service_hooks_to_ids = services.each_with_object({}) do |service, hash|
        hash[service['hook']] ||= []
        hash[service['hook']] << service['id'] if service['id']
      end

      output appointment_book_service_ids: service_hooks_to_ids['appointment-book']&.join(', '),
             encounter_start_service_ids: service_hooks_to_ids['encounter-start']&.join(', '),
             encounter_discharge_service_ids: service_hooks_to_ids['encounter-discharge']&.join(', '),
             order_dispatch_service_ids: service_hooks_to_ids['order-dispatch']&.join(', '),
             order_select_service_ids: service_hooks_to_ids['order-select']&.join(', '),
             order_sign_service_ids: service_hooks_to_ids['order-sign']&.join(', ')

      services.each do |service|
        required_fields.each do |field, type|
          assert(service[field], "Service `#{service}` did not contain required field: `#{field}`")
          assert(service[field].is_a?(type), "Service `#{service}`: field `#{field}` is not of type #{type}")
        end
      end
    end
  end
end
