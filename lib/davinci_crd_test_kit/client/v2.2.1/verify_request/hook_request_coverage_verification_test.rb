require_relative '../../../cross_suite/tags'

module DaVinciCRDTestKit
  module V221
    class HookRequestCoverageVerficationTest < Inferno::Test
      id :crd_v221_hook_request_coverage_verification
      title 'Hook request coverages are valid'
      description %(
        The coverage associated with a hook request must be issued by the payer
        associated with Inferno's simulated CRD endpoints and conform to the
        [CRD Organization](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-organization.html)
        profile.
      )

      input :inferno_payer_organization_id,
            title: 'Inferno Payer Organization id',
            description: %(
              The FHIR Organization id associated with Inferno's simulated
              CRD endpoints. This Organization must be referenced as the
              payer on Coverages in hook requests. Run the Client Registration
              group to change this value.
            ),
            type: 'text',
            optional: true,
            locked: true

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

      def load_payer_request_for_hook_request(request_body)
        hook_tag = "#{HOOK_INSTANCE_TAG_PREFIX}#{request_body['hookInstance']}"
        load_tagged_requests('payer', hook_tag, DATA_FETCH_TAG).first
      end

      def check_payer_request(request_body)
        payer_request = load_payer_request_for_hook_request(request_body)
        unless payer_request.present? && payer_request.status.to_s.starts_with?('2')
          add_message('error',
                      "#{request_prefix}Inferno failed to retrieve the Coverage's payer during hook processing.")
          return
        end

        payer_resource = FHIR.from_contents(payer_request.response_body)
        unless payer_resource.present?
          add_message('error', "#{request_prefix}Request for payer resource returned invalid FHIR data.")
          return
        end

        if payer_resource.resourceType != 'Organization'
          add_message('error', "#{request_prefix}Payer for the Coverage is not an Organization: " \
                               "got '#{payer_resource.resourceType}'")
        end
        if payer_resource.id != inferno_payer_organization_id

          add_message('error', "#{request_prefix}Payer for the Coverage has the wrong id: " \
                               "expected '#{inferno_payer_organization_id}', got '#{payer_resource.id}'.")
        end

        resource_is_valid?(resource: payer_resource, profile_url: 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/profile-organization|2.2.1')
      end

      run do
        skip_if inferno_payer_organization_id.blank?,
                'Input "Inferno Payer Organization id " is needed to verify behavior.'

        hook_requests = load_tagged_requests(*tags_to_load)

        skip_if hook_requests.blank?, "No #{hook_name} hook requests received."

        hook_requests.each_with_index do |request, request_index|
          @request_number = request_index + 1

          request_body = parsed_json_if_valid(request.request_body, "#{request_prefix} Request body malformed.")
          next unless request_body.present?

          coverage = request_body.dig('prefetch', 'coverage', 'entry', 0, 'resource')
          unless coverage.present?
            add_message('warning', "#{request_prefix}Request has no coverage.")
            next
          end

          payer_organization_reference = coverage.dig('payor', 0, 'reference')
          if payer_organization_reference.blank?
            add_message('error', "#{request_prefix}Coverage has no payer reference.")
            next
          end

          check_payer_request(request_body)
        end

        assert_no_error_messages('Some hook requests contain invalid coverages. ' \
                                 'See Messages for details.')
      end
    end
  end
end
