module DaVinciCRDTestKit
  class CDSServicesDiscoveryHandler
    def self.call(...)
      new.call(...)
    end

    def self.cds_services(version = 'v2.0.1', prefetch_subset: false)
      key = "#{version}_#{prefetch_subset}"
      cds_services_array[key] ||= begin
        filename = if prefetch_subset
                     "cds-services-prefetch-subset-#{version.gsub('.', '')}.json"
                   else
                     "cds-services-#{version.gsub('.', '')}.json"
                   end
        File.read(File.join(__dir__, '..', version, filename))
      end
    end

    def self.cds_services_array
      @cds_services_array ||= {}
    end

    def call(env)
      path_parts = env['PATH_INFO'].split('/')
      # /custom/<suite>/[prefetch-subset/]cds-services
      prefetch_subset = path_parts.include?('prefetch-subset')
      suite = path_parts.find { |p| p.start_with?('crd_client_') } || path_parts[-2]
      version_no_dots = suite.split('_')[2].presence || 'v201' # crd_client_<version>
      version = version_no_dots.sub(/\A(v\d)(\d)(\d)\z/, '\1.\2.\3')
      [200, { 'Content-Type' => 'application/json', 'Access-Control-Allow-Origin' => '*' },
       [self.class.cds_services(version, prefetch_subset:)]]
    end
  end
end
