module DaVinciCRDTestKit
  module V220
    class HookRequestConformanceTest < Inferno::Test
      id :crd_v220_hook_request_conformance
      title 'Hook request conforms to required logical model'
      description %(
        CRD defines logical models representing requirements for the request for each hook.
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

          conforms_to_logical_model?(request_body, 'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/CRDHooksRequest|2.2.0',
                                     message_prefix: request_number)
        end

        assert_no_error_messages('Non-conformant hook requests detected. See Messages for details.')
      end
    end
  end
end
