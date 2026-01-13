require_relative '../cards_identification'

module DaVinciCRDTestKit
  class ClientCardMustSupportCoverageInformationTest < Inferno::Test
    include CardsIdentification

    title 'Coverage Information Action Support'
    id :crd_client_card_must_support_coverage_information
    description <<~DESCRIPTION
      Checks that the client demonstrated support for the [Coverage Information](https://hl7.org/fhir/us/davinci-crd/STU2/cards.html#coverage-information)
      action type. At least one hook invocation performed during this test session must have returned a Coverage Information action.
      Additionally, all [coverage-information extension](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-ext-coverage-information.html)
      must support elements must be demonstrated across all the returned actions.

      If this test fails, adjust the [cards returned by Inferno's simulated CRD Server](https://github.com/inferno-framework/davinci-crd-test-kit/wiki/Controlling-Simulated-Responses)
      and the hook requests made by the client such that Coverage Information actions are returned that cover the full scope of the
      coverage-information extension](https://hl7.org/fhir/us/davinci-crd/STU2/StructureDefinition-ext-coverage-information.html)
      and support for them is demonstrated.
    DESCRIPTION

    ALL_HOOKS = [
      APPOINTMENT_BOOK_TAG,
      ENCOUNTER_START_TAG,
      ENCOUNTER_DISCHARGE_TAG,
      ORDER_DISPATCH_TAG,
      ORDER_SELECT_TAG,
      ORDER_SIGN_TAG
    ].freeze

    def metadata
      @metadata ||= YAML.load_file(File.join(__dir__, 'coverage-information_stu201_metadata.yml'))
    end

    def configured_hook_name
      config.options[:hook_name]
    end

    def crd_test_group
      config.options[:crd_test_group]
    end

    def tags_to_load(hook_name)
      crd_test_group.present? ? [hook_name, crd_test_group] : [hook_name]
    end

    def requests_to_analyze
      if configured_hook_name.present?
        load_requests_for_tags(tags_to_load(configured_hook_name))
      else
        ALL_HOOKS.each_with_object([]) do |hook_name, request_list|
          request_list.concat(load_requests_for_tags(tags_to_load(hook_name)))
        end
      end
    end

    def load_requests_for_tags(tags_to_load)
      load_tagged_requests(*tags_to_load)
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

      sorted_cards = sorted_cards_from_requests(loaded_requests)

      assert sorted_cards['actions'][COVERAGE_INFORMATION_RESPONSE_TYPE].present?,
             'Coverage Information action support not demonstrated.'

      coverage_information_extensions = extract_coverage_information_extensions(sorted_cards)
      assert_must_support_elements_present(coverage_information_extensions, COVERAGE_INFO_EXT_URL,
                                           metadata: MustSupportMetadataHolder.new(metadata))
    end
  end
end
