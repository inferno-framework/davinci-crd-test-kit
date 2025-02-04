module DaVinciCRDTestKit
  module ServerHookHelper
    # configured hook
    # used for tagging the request
    # "any" is an option
    def tested_hook_name
      config.options[:hook_name]
    end

    # identify the hook to invoke
    def identify_hook(payloads)
      if tested_hook_name == 'any'
        hook_list_from_payloads = payloads.map { |body| body['hook'] }.uniq

        assert hook_list_from_payloads.length == 1,
               'Could not identify the tested hook for the *Demonstrated Any Hook tests* from the request bodies.'

        hook_list_from_payloads.first
      else
        tested_hook_name
      end
    end

    # target service id for invocation
    # if a list isn't provided, use the discovery response and the target hook to find one
    def target_service_id(service_ids, hook_name)
      return service_ids.split(', ').first.strip if service_ids.present?

      discovered_service_id_for_hook(hook_name)
    end

    # load discovery response to get the target service id
    def discovered_service_id_for_hook(hook_name)
      discovery_requests = load_tagged_requests(DaVinciCRDTestKit::DISCOVERY_TAG)
      services = discovery_requests&.first&.response_body
      return unless services.present?

      JSON.parse(services)['services']&.find { |service| service['hook'] == hook_name }&.dig('id')
    end
  end
end
