require_relative '../client_urls'
require_relative '../../../cross_suite/cards_identification'
require_relative '../../tagged_request_load_helper'

module DaVinciCRDTestKit
  module V221
    class ClientUnknownContentAttestationTest < Inferno::Test
      include ClientURLs
      include CardsIdentification
      include DaVinciCRDTestKit::TaggedRequestLoadHelper

      KNOWN_ACTION_ELEMENTS = ['type', 'description', 'resource', 'resourceId', 'extension'].freeze

      id :crd_v221_client_unknown_content_attestation_test
      title 'Client processes coverage information returned with unknown content'
      description %(
        The CRD IG [requires](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/foundation.html#ci-c-found-33)
        that client systems ignore unexpected elements when processing instances and that they not depend
        on elements beyond those the specification marks as mandatory or mustSupport. During this test,
        the tester will confirm that the unknown element and custom extension included in the previous
        response did not prevent the client system from processing the coverage information returned
        alongside them and making it available to the user.
      )
      attestation

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@conf-10',
                            'hl7.fhir.us.davinci-crd_2.2.1@found-33'

      output :attest_true_url
      output :attest_false_url

      def response_bodies(hook_requests)
        hook_requests.filter_map do |request|
          body = JSON.parse(request.response_body)
          body if body.is_a?(Hash)
        rescue JSON::ParserError
          nil
        end
      end

      def unknown_action_elements(bodies)
        bodies.flat_map do |body|
          body['systemActions'].to_a.flat_map { |action| action.keys - KNOWN_ACTION_ELEMENTS }
        end.uniq
      end

      def unknown_extensions(bodies)
        bodies.flat_map { |body| body['extension'].is_a?(Hash) ? body['extension'].keys : [] }.uniq
      end

      def format_unknown_content(bodies)
        [
          format_unknown_names('System action element name', unknown_action_elements(bodies)),
          format_unknown_names('Response extension name', unknown_extensions(bodies))
        ].compact.join("\n")
      end

      def format_unknown_names(label, names)
        return if names.blank?

        "- #{label}: #{names.map { |name| "`#{name}`" }.join(', ')}"
      end

      run do
        hook_requests = load_interaction_group_requests
        skip_if hook_requests.blank?, 'Unknown response content not demonstrated: ' \
                                      'no hook requests sent during the previous wait.'

        bodies = response_bodies(hook_requests)
        skip_if bodies.none? { |body| coverage_info_system_action_response?(body) },
                'Unknown response content not demonstrated: ' \
                'no coverage information system action was returned.'

        identifier = SecureRandom.hex(32)
        attest_true_url = "#{resume_pass_url}?token=#{identifier}"
        attest_false_url = "#{resume_fail_url}?token=#{identifier}"
        output(attest_true_url:)
        output(attest_false_url:)
        wait(
          identifier:,
          message: <<~MESSAGE
            **Unknown Response Content Attestation**:

            Inferno returned coverage information along with the following content that is
            not defined by CRD or CDS Hooks:

            #{format_unknown_content(bodies)}

            I attest that this unexpected content did not prevent the client system from
            processing the coverage information returned in the same response and that the
            coverage information was displayed or otherwise made available to the user:

            [Click here](#{attest_true_url}) if the above statement is **true**.

            [Click here](#{attest_false_url}) if the above statement is **false**.
          MESSAGE
        )
      end
    end
  end
end
