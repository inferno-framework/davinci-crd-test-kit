require_relative '../../../cross_suite/cards_identification'
require_relative '../../tagged_request_load_helper'

module DaVinciCRDTestKit
  module V221
    class ClientCardMustSupportCoverageInformationTest < Inferno::Test
      include CardsIdentification
      include TaggedRequestLoadHelper

      title 'Client supports the Coverage Information response type'
      id :crd_v221_client_card_must_support_coverage_information
      description <<~DESCRIPTION
        During this test, Inferno will verify that the client demonstrated support for the [Coverage Information](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#coverage-information)
        response type for this hook. At least one hook invocation received during this group must have returned a Coverage Information action.
        Additionally, all [coverage-information extension](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-ext-coverage-information.html)
        must support elements must be demonstrated across all the returned actions.

        If this test fails, adjust the [cards returned by Inferno's simulated CRD server](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses)
        and/or the hook requests made by the client during the Hooks tests such that Coverage Information actions are returned
        that cover the full scope of the [coverage-information extension](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-ext-coverage-information.html)
        and support for them is demonstrated.
      DESCRIPTION

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@resp-14'

      def metadata
        @metadata ||= YAML.load_file(
          File.join(__dir__, '..', '..', '..', 'cross_suite', 'coverage-information_stu221_metadata.yml')
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
        loaded_requests = requests_to_analyze
        skip_if loaded_requests.blank?, 'No hook requests received.'

        sorted_cards = sorted_cards_from_requests(loaded_requests)

        assert sorted_cards['actions'][COVERAGE_INFORMATION_RESPONSE_TYPE].present?,
               'Support for the Coverage Information response type not demonstrated.'

        coverage_information_extensions = extract_coverage_information_extensions(sorted_cards)
        assert_must_support_elements_present(coverage_information_extensions, COVERAGE_INFO_EXT_URL,
                                             metadata: MustSupportMetadataHolder.new(metadata))
      end
    end
  end
end
