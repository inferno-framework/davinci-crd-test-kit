require_relative '../server_base_urls'

module DaVinciCRDTestKit
  module V201
    module ServerURLs
      include ServerBaseURLs

      def suite_id
        DaVinciCRDTestKit::V201::CRDServerSuite.id
      end
    end
  end
end
