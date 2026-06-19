module DaVinciCRDTestKit
  module V221
    # Users of this test need to set config options for expected_coverage_code and expected_reason_code
    class CoverageInfoReasonTest < Inferno::Test
      id :crd_v221_coverage_info_reason
      title 'Coverage Information responses have the expected coverage and reason codes'

      description <<~DESCRIPTION
        This test verifies that the Coverage Information responses received contain Coverage Information extensions
        with the expected coverage and reason codes.
      DESCRIPTION

      input :coverage_info

      COVERAGE_INFO_EXTENSION_URL =
        'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information'.freeze

      run do
        coverage_info_actions = JSON.parse(coverage_info)

        skip_if coverage_info_actions.blank?, 'No Coverage Information system actions received'

        coverage_info_actions.each_with_index do |action, index|
          coverage_info_extensions(action['resource']).each do |extension|
            unless expected_coverage? extension
              value = coverage_extension_value(extension)
              add_message(
                'error',
                "Coverage should be `#{expected_coverage_code}`, but found `#{value}` in action ##{index + 1}"
              )
            end

            next if expected_reason? extension

            value =
              reason_extension_values(extension)
                &.map { |reason| "`#{reason}`" }
                &.join(', ') || 'no reason'
            add_message(
              'error',
              "Coverage reason should be `#{expected_reason_code}`, but found #{value} in action ##{index + 1}"
            )
          end
        end

        assert_no_error_messages(
          "Not all coverage info extensions had `#{expected_coverage_code}` coverage " \
          "with a reason of `#{expected_reason_code}`"
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

      def expected_coverage?(coverage_info_extension)
        coverage_extension_value(coverage_info_extension) == expected_coverage_code
      end

      def reason_extension_values(coverage_info_extension)
        coverage_info_extension['extension']
          .find { |extension| extension['url'] == 'reason' }
          &.dig('valueCodeableConcept', 'coding')
          &.map { |coding| coding['code'] }
      end

      def expected_reason?(coverage_info_extension)
        reason_extension_values(coverage_info_extension)&.include? expected_reason_code
      end

      def expected_coverage_code
        config.options[:expected_coverage_code]
      end

      def expected_reason_code
        config.options[:expected_reason_code]
      end
    end
  end
end
