require_relative '../../../cross_suite/cards_identification'
require_relative '../../../cross_suite/tags'

module DaVinciCRDTestKit
  module V221
    class CoverageInformationMustSupportTest < Inferno::Test
      include DaVinciCRDTestKit::CardsIdentification

      title 'Coverage Information responses demonstrate Must Support elements'
      id :crd_v221_coverage_information_must_support
      description <<~DESCRIPTION
        Checks that the server demonstrated must support coverage for the [Coverage Information](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#coverage-information-response-type)
        extension across the hook responses returned during this test session.

        At least one hook invocation must have returned a Coverage Information system action.
        Additionally, the set of [coverage-information extension](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-ext-coverage-information.html)
        instances returned across those actions must collectively demonstrate all must support elements.

        If this test fails, re-run the hook tests using request payloads that cause the server to return
        Coverage Information system actions that cover the full set of must support elements.
      DESCRIPTION

      ALL_HOOKS = [
        DaVinciCRDTestKit::APPOINTMENT_BOOK_TAG,
        DaVinciCRDTestKit::ENCOUNTER_START_TAG,
        DaVinciCRDTestKit::ENCOUNTER_DISCHARGE_TAG,
        DaVinciCRDTestKit::ORDER_DISPATCH_TAG,
        DaVinciCRDTestKit::ORDER_SELECT_TAG,
        DaVinciCRDTestKit::ORDER_SIGN_TAG
      ].freeze

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
        ALL_HOOKS.each { |hook_tag| load_tagged_requests(hook_tag) }
        sorted_cards = sorted_cards_from_requests(requests)
        coverage_info_system_actions = sorted_cards['actions'][COVERAGE_INFORMATION_RESPONSE_TYPE]

        assert coverage_info_system_actions.present?,
               'Coverage Information system action support not demonstrated.'

        coverage_information_extensions = extract_coverage_information_extensions(sorted_cards)
        assert_must_support_elements_present(
          coverage_information_extensions,
          COVERAGE_INFO_EXT_URL,
          metadata: MustSupportMetadataHolder.new(metadata)
        )
      end
    end
  end
end
