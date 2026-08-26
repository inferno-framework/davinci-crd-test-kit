require_relative '../../../cross_suite/cards_identification'
require_relative '../../tagged_request_load_helper'

module DaVinciCRDTestKit
  module V201
    class ClientCardMustSupportCoverageInformationTest < Inferno::Test
      include CardsIdentification
      include TaggedRequestLoadHelper

      title 'Coverage Information Action Support'
      id :crd_v201_client_card_must_support_coverage_information
      description <<~DESCRIPTION
        Checks that the client demonstrated support for the [Coverage Information](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#coverage-information-response-type)
        action type. At least one hook invocation performed during this test session must have returned a Coverage Information action.
        Additionally, all [coverage-information extension](https://hl7.org/fhir/us/davinci-crd/2.2.1/StructureDefinition-ext-coverage-information.html)
        must support elements must be demonstrated across all the returned actions.

        If this test fails, adjust the [cards returned by Inferno's simulated CRD server](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses)
        and/or the hook requests made by the client during the Hooks tests such that Coverage Information actions are returned
        that cover the full scope of the coverage-information extension](https://hl7.org/fhir/us/davinci-crd/2.2.1/StructureDefinition-ext-coverage-information.html)
        and support for them is demonstrated.
      DESCRIPTION

      def metadata
        @metadata ||= YAML.load_file(
          File.join(__dir__, '..', '..', '..', 'cross_suite', 'coverage-information_stu201_metadata.yml')
        )
      end

      class MustSupportMetadataHolder
        attr_accessor :metadata

        def initialize(metadata)
          self.metadata = metadata
        end

        def must_supports
          @must_supports ||= {
            extensions: metadata[:must_supports][:extensions] || [],
            slices: metadata[:must_supports][:slices] || [],
            elements: metadata[:must_supports][:elements] || []
          }
        end
      end

      run do
        loaded_requests = load_requests_for_cross_hook_analysis

        sorted_cards = sorted_cards_from_requests(loaded_requests)

        assert sorted_cards['actions'][COVERAGE_INFORMATION_RESPONSE_TYPE].present?,
               'Coverage Information action support not demonstrated.'

        coverage_information_extensions = extract_coverage_information_extensions(sorted_cards)
        assert_must_support_elements_present(coverage_information_extensions, COVERAGE_INFO_EXT_URL,
                                             metadata: MustSupportMetadataHolder.new(metadata))
      end
    end
  end
end
