require_relative '../../server_test_helper'

module DaVinciCRDTestKit
  module V221
    class DiscoveryPrefetchSupportTest < Inferno::Test
      include DaVinciCRDTestKit::ServerTestHelper

      title 'Server advertises prefetch support'
      id :crd_v221_discovery_prefetch_support
      description %(
        This test expects the server to demonstrate support for prefetch queries
        by providing a prefetch query in at least one of the advertised service
        in the discovery response.
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@found-24'

      input :cds_services
      input :crd_discovery_service_ignore_list,
            optional: true

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

        prefetch_supported = services_for_crd_validation.any? { |service| service['prefetch'].present? }

        skip_if !prefetch_supported, 'No CRD services advertised prefetch support'
      end
    end
  end
end
