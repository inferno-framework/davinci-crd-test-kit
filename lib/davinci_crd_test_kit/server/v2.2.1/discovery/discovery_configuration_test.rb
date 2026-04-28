module DaVinciCRDTestKit
  module V221
    class DiscoveryConfigurationTest < Inferno::Test
      title 'Server makes configuration options available'
      id :crd_v221_discovery_configuration
      description %(
        According to the spec:

        > CRD servers SHALL, at minimum, offer configuration options for each
          type of card they support

        This test verifies that all primary hook services contain at least one
        valid configuration option. Secondary hooks are not expected to return
        cards, so they are ignored in this test.
      )

      input :cds_services

      run do
        services = JSON.parse(cds_services)['services']

        primary_hooks = ['appointment-book', 'order-sign', 'order-dispatch']

        primary_hook_services = services.select { |service| primary_hooks.include? service['hook'] }

        omit_if primary_hook_services.blank?, 'No services for primary hooks found'

        services_without_configuration_options =
          primary_hook_services.reject do |service|
            service['extension'].present? && service['extension']['davinci-crd.configuration-options'].present?
          end

        if services_without_configuration_options.present?
          add_message(
            'error',
            'The following services do not contain any configuration options: ' \
            "#{services_without_configuration_options.map { |service| service['code'] }.join(', ')}"
          )
        end

        required_fields = ['code', 'type', 'name', 'description', 'default']

        primary_hook_services.each do |service|
          coverage_info_config_found =
            service.dig('extension', 'davinci-crd.configuration-options')&.any? do |config_option|
              config_option['code'] == 'coverage-info'
            end

          unless coverage_info_config_found
            add_message(
              'error',
              "Service `#{service['id']}` does not contain a `coverage-info` configuration option"
            )
          end

          service.dig('extension', 'davinci-crd.configuration-options')&.each do |config_option|
            required_fields.each do |field_name|
              unless config_option.key?(field_name)
                add_message(
                  'error',
                  "Service `#{service['id']}` configuration option `#{config_option['code']}` " \
                  "does not contain `#{field_name}` field"
                )
                next
              end

              next if field_name == 'default'

              next if config_option[field_name].is_a? String

              type = config_option[field_name].class
              add_message(
                'error',
                "Expected service `#{service['id']}` configuration option `#{service['code']}` " \
                "field `#{field_name}` to be a String, but found #{type}"
              )
            end
          end
        end

        assert messages.none? { |message| message[:type] == 'error' },
               'Not all primary hook services contain valid configuration options.'
      end
    end
  end
end
