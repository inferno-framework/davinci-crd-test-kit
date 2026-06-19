require_relative 'specific_coverage_responses/technical_issues_group'
require_relative 'specific_coverage_responses/no_member_found_group'
require_relative 'specific_coverage_responses/coverage_not_found_group'
require_relative 'specific_coverage_responses/no_active_coverage_group'

module DaVinciCRDTestKit
  module V221
    class SpecificCoverageResponseGroup < Inferno::TestGroup
      title 'Specific Coverage Responses'
      id :crd_v221_specific_coverage_responses

      description <<~DESCRIPTION
        This group verifies the ability of a server to return specific
        coverage-info responses in particular situations.
      DESCRIPTION

      group from: :crd_v221_server_technical_issues_group
      group from: :crd_v221_server_no_member_found_group
      group from: :crd_v221_server_coverage_not_found_group
      group from: :crd_v221_server_no_active_coverage_group
    end
  end
end
