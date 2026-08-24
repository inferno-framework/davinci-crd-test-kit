require_relative 'client_long_running_hook_group'
require_relative 'client_unknown_content_hook_group'
require_relative 'client_user_access_level_group'

module DaVinciCRDTestKit
  module V221
    class ClientScenariosGroup < Inferno::TestGroup
      title 'Scenarios'
      id :crd_v221_client_scenarios
      description <<~DESCRIPTION
        This group checks CRD requirements that pertain to specific scenarios
        that clients need to handle.

        These scenarios test specific situations and conformance details of requests
        and responses beyond those required for the scenario and for Inferno to
        recognize client requests are not checked. Testers are expected to follow
        the same workflows as used during other tests and should adhere to the
        same CRD requirements when performing these scenarios.
      DESCRIPTION

      group from: :crd_v221_client_long_running_hook
      group from: :crd_v221_client_unknown_content_hook
      group from: :crd_v221_client_user_access_level
    end
  end
end
