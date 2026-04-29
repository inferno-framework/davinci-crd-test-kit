module DaVinciCRDTestKit
  module V221
    class HookRequestExtensionsTest < Inferno::Test
      id :crd_v221_hook_request_requested_version
      title 'Hook request contains the CRD version extension'
      description %(
        Inferno's CRD service supports multiple versions of CRD, so [clients are required](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/conformancedetails.html#ci-c-dev-3)
        to use the `davinci-crd.requestedVersion` extension on each request.
      )

      # verifies_requirements 'cds-hooks_2.0@1', 'cds-hooks_2.0@3', 'cds-hooks_2.0@20', 'cds-hooks_2.0@21',
      #                       'cds-hooks_2.0@23', 'cds-hooks_2.0@65', 'cds-hooks_2.0@66', 'cds-hooks_2.0@67',
      #                       'cds-hooks_2.0@68', 'cds-hooks_2.0@69', 'cds-hooks_2.0@70'

      def hook_name
        config.options[:hook_name]
      end

      def crd_test_group
        config.options[:crd_test_group]
      end

      def tags_to_load
        crd_test_group.present? ? [hook_name, crd_test_group] : [hook_name]
      end

      def request_number
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

          requested_version = request_body.dig('extension', 'davinci-crd.requestedVersion')
          if requested_version.blank?
            add_message('error', "#{request_number} Required extension 'davinci-crd.requestedVersion' is not present.")
          elsif !requested_version.is_a?(String)
            add_message('error',
                        "#{request_number} For extension 'davinci-crd.requestedVersion' expected a String, " \
                        "got #{requested_version.class}")
          elsif requested_version != '2.2'
            add_message('error',
                        "#{request_number} For extension 'davinci-crd.requestedVersion' expected '2.2', " \
                        "got '#{requested_version}'")
          end
        end

        assert_no_error_messages('Some hook requests did not populate the requested version extension properly. ' \
                                 'See Messages for details.')
      end
    end
  end
end
