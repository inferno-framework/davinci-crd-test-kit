module DaVinciCRDTestKit
  module V221
    class NoMemberFoundTest < Inferno::Test
      id :crd_v221_coverage_info_no_member_found
      title 'Coverage Information responses have not-covered coverage for no member-member-found reason'

      description <<~DESCRIPTION
        This test verifies that the Coverage Information responses received contain Coverage Information
        extensions with `not-covered` coverage and a `no-member-found` reason.
      DESCRIPTION

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@resp-44'

      input :coverage_info

      COVERAGE_INFO_EXTENSION_URL =
        'http://hl7.org/fhir/us/davinci-crd/StructureDefinition/ext-coverage-information'.freeze

      run do
        coverage_info_actions = JSON.parse(coverage_info)

        skip_if coverage_info_actions.blank?, 'No Coverage Information system actions received'

        coverage_info_actions.each_with_index do |action, index|
          coverage_info_extensions(action['resource']).each do |extension|
            unless not_covered_coverage? extension
              value = coverage_extension_value(extension)
              add_message(
                'error',
                "Coverage should be `not-covered`, but found `#{value}` in action ##{index + 1}"
              )
            end

            next if no_member_found_reason? extension

            value =
              reason_extension_values(extension)
                &.map { |reason| "`#{reason}`" }
                &.join(', ') || 'no reason'
            add_message(
              'error',
              "Coverage reason should be `no-member-found`, but found #{value} in action ##{index + 1}"
            )
          end
        end

        assert_no_error_messages(
          'Not all coverage info extensions had `not-covered` coverage with a reason of `no-member-found`'
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

      def not_covered_coverage?(coverage_info_extension)
        coverage_extension_value(coverage_info_extension) == 'not-covered'
      end

      def reason_extension_values(coverage_info_extension)
        coverage_info_extension['extension']
          .find { |extension| extension['url'] == 'reason' }
          &.dig('valueCodeableConcept', 'coding')
          &.map { |coding| coding['code'] }
      end

      def no_member_found_reason?(coverage_info_extension)
        reason_extension_values(coverage_info_extension)&.include? 'no-member-found'
      end
    end
  end
end
