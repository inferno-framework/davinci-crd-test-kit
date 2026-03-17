require_relative '../server_base_urls'

module DaVinciCRDTestKit
  module V220
    module ServerURLs
      include ServerBaseURLs

      def suite_id
        DaVinciCRDTestKit::V220::CRDServerSuite.id
      end
    end
  end
end
