module DaVinciCRDTestKit
  module V221
    class TechnicalIssuesTest < Inferno::Test
      id :crd_v221_coverage_info_technical_issues
      title 'Coverage Information responses have indeterminate coverage for technical reasons'

      description <<~DESCRIPTION
        This test verifies that the Coverage Information responses received
        contain Coverage Information extensions with `indeterminate` coverage
        and a `technical` reason, and additional details about the failure are
        included in the `text` field of the reason extension.
      DESCRIPTION

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@resp-43'

      input :coverage_info

      COVERAGE_INFO_EXTENSION_URL =
        'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information'.freeze

      run do
        coverage_info_actions = JSON.parse(coverage_info)

        skip_if coverage_info_actions.blank?, 'No Coverage Information system actions received'

        coverage_info_actions.each_with_index do |action, index|
          coverage_info_extensions(action['resource']).each do |extension|
            unless indeterminate_coverage? extension
              value = coverage_extension_value(extension)
              add_message(
                'error',
                "Coverage should be `indeterminate`, but found `#{value}` in action ##{index + 1}"
              )
            end

            unless technical_reason? extension
              value =
                reason_extension_values(extension)
                  &.map { |value| "`#{value}`" }
                  &.join(', ') || 'no reason'
              add_message(
                'error',
                "Coverage reason should be `technical`, but found #{value} in action ##{index + 1}"
              )

              next
            end

            next if technical_reason_text? extension

            add_message(
              'error',
              "`technical` coverage reason contains no additional details in `text` field in action ##{index + 1}"
            )
          end
        end

        assert_no_error_messages(
          'Not all coverage info extensions had `indeterminate` coverage with a reason of `technical` ' \
          'and details in `text`'
        )
      end

      def coverage_info_extensions(resource)
        resource['extension'].select { |extension| extension['url'] == COVERAGE_INFO_EXTENSION_URL }
      end

      def coverage_extension_value(coverage_info_extension)
        coverage_info_extension['extension']
          .find { |extension| extension['url'] == 'covered' }
          &.dig('valueCode')
      end

      def indeterminate_coverage?(coverage_info_extension)
        coverage_extension_value(coverage_info_extension) == 'indeterminate'
      end

      def reason_extension_values(coverage_info_extension)
        coverage_info_extension['extension']
          .find { |extension| extension['url'] == 'reason' }
          &.dig('valueCodeableConcept', 'coding')
          &.map { |coding| coding['code'] }
      end

      def technical_reason?(coverage_info_extension)
        reason_extension_values(coverage_info_extension)&.include? 'technical'
      end

      def technical_reason_text?(coverage_info_extension)
        coverage_info_extension['extension']
          .find { |extension| extension['url'] == 'reason' }
          &.dig('valueCodeableConcept', 'text')
          &.present?
      end
    end
  end
end
