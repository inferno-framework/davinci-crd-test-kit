require_relative '../client_urls'
require_relative '../../../cross_suite/cards_identification'

module DaVinciCRDTestKit
  module V221
    class BaseHookInvocationReceiveRequestTest < Inferno::Test
      include ClientURLs

      RESPONSE_TYPE_OPTIONS = [
        {
          label: 'External Reference (card)',
          value: 'external_reference'
        },
        {
          label: 'Instructions (card)',
          value: 'instructions'
        },
        {
          label: 'Coverage Information (systemAction)',
          value: 'coverage_information'
        },
        {
          label: 'Request Form Completion (card)',
          value: 'request_form_completion'
        },
        {
          label: 'Create/Update Coverage Information (card)',
          value: 'create_update_coverage_info'
        },
        {
          label: 'Launch SMART Application (card)',
          value: 'launch_smart_app'
        }
      ].freeze

      ORDER_RESPONSE_TYPE_OPTIONS = (RESPONSE_TYPE_OPTIONS + [
        {
          label: 'Propose Alternate Request (card)',
          value: 'propose_alternate_request'
        },
        {
          label: 'Additional Orders as Companions/Prerequisites (card)',
          value: 'companions_prerequisites'
        }
      ]).freeze

      config options: { accepts_multiple_requests: true }

      input :cds_jwt_iss,
            title: 'CRD JWT Issuer',
            description: %(
              Value of the `iss` claim that must be present in the JWT used to authorize the client's hook
              request sent as the Bearer token in the `Authorization` header.
              Run or re-run the "Registration" group to set or change this value.
            ),
            locked: true
      output :continuation_url

      def hook_key
        raise NotImplementedError, "#{self.class} must implement #hook_key"
      end

      def primary_hook?
        raise NotImplementedError, "#{self.class} must implement #primary_hook?"
      end

      def hook_slug
        hook_key.to_s.tr('_', '-')
      end

      def response_approach
        send(:"#{hook_key}_response_approach")
      end

      def selected_response_types
        send(:"#{hook_key}_selected_response_types")
      end

      def configured_response_details
        if response_approach == 'custom'
          # rubocop:disable Layout/LineLength
          'When responding, Inferno will evaluate the provided [custom response template](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#tester-directed-custom-responses) ' \
            "from the **Custom response template for #{hook_slug} hook requests** input " \
            'against the incoming request to create a response.'
          # rubocop:enable Layout/LineLength
        else
          # rubocop:disable Layout/LineLength
          'When responding, Inferno will [mock](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses#mocked-responses) ' \
            'the following response types using the incoming request: ' \
            "\n            - #{selected_response_types_string}"
          # rubocop:enable Layout/LineLength
        end
      end

      def selected_response_types_string
        response_types =
          if selected_response_types.present?
            selected_response_types
          else
            # matches the hook's default response type
            primary_hook? ? [DaVinciCRDTestKit::CardsIdentification::COVERAGE_INFORMATION_RESPONSE_TYPE] : [DaVinciCRDTestKit::CardsIdentification::INSTRUCTIONS_RESPONSE_TYPE]
          end.map do |response_type|
            if response_type == DaVinciCRDTestKit::CardsIdentification::COVERAGE_INFORMATION_RESPONSE_TYPE
              "#{response_type}_action"
            else
              "#{response_type}_card"
            end
          end

        format_responded_response_types(response_types)
      end

      def format_responded_response_types(response_types)
        response_types
          .map do |response_type|
            response_type.split('_')
              .map(&:capitalize)
              .join(' ')
              .sub('Smart', 'SMART')
              .sub('Create Update', 'Create/Update')
              .sub('Companions Prerequisites', 'Companions/Prerequisites')
              .sub('Card', '(card)')
              .sub('Action', '(systemAction)')
          end.join("\n            - ")
      end

      def invoke_heading
        "Invoke the `#{hook_slug}` hook"
      end

      def invoke_intro
        "Invoke #{hook_slug} hook by sending requests to one or both of the two Inferno simulated CRD servers:"
      end

      def complete_prefetch_url
        send(:"#{hook_key}_url")
      end

      def subset_prefetch_url
        send(:"#{hook_key}_prefetch_subset_url")
      end

      run do
        identifier = cds_jwt_iss
        continuation_url = "#{resume_pass_url}?token=#{identifier}"
        output(continuation_url:)

        wait(
          identifier:,
          message: %(
            **#{invoke_heading}**:

            #{invoke_intro}

            - Complete Prefetch: `#{complete_prefetch_url}`
            - Subset Prefetch: `#{subset_prefetch_url}`

            For Inferno to recognize these requests and associate them with this session,
            the authentication JWT sent as a Bearer token in the Authorization header
            must have `#{cds_jwt_iss}` as the `iss` claim in the JWT payload.

            #{configured_response_details}

            [Click here](#{continuation_url}) when you have finished submitting requests.
          )
        )
      end
    end
  end
end
