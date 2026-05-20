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
        valid configuration option for `coverage-info`. Secondary hooks are not
        expected to return cards, so they are ignored in this test.
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@dev-4',
                            'hl7.fhir.us.davinci-crd_2.2.1@dev-5',
                            'hl7.fhir.us.davinci-crd_2.2.1@dev-7',
                            'hl7.fhir.us.davinci-crd_2.2.1@dev-8'

      input :cds_services
      input :crd_discovery_service_ignore_list,
            optional: true

      def primary_hooks
        ['appointment-book', 'order-sign', 'order-dispatch']
      end

      def primary_hook?(hook)
        primary_hooks.include? hook
      end

      def required_fields
        ['code', 'type', 'name', 'description', 'default']
      end

      def verify_unique_values(hook, service)
        unique_fields = ['code', 'name', 'description']

        config_options =
          service
            .dig('extension', 'davinci-crd.configuration-options')

        return if config_options.blank?

        unique_fields.each do |unique_field|
          value_counts =
            config_options
              .map { |config_option| config_option[unique_field] }
              .tally

          duplicate_values =
            value_counts
              .select { |_value, count| count > 1 }
              .keys

          next if duplicate_values.blank?

          duplicate_values_string = duplicate_values.map { |value| "\n- `#{value}`" }.join

          add_message(
            'error',
            "Services for hook `#{hook}` contain duplicate values for `#{unique_field}`:" \
            "#{duplicate_values_string}"
          )
        end
      end

      def verify_required_fields(hook, service)
        service.dig('extension', 'davinci-crd.configuration-options')&.each do |config_option|
          required_fields.each do |field_name|
            unless config_option.key?(field_name)
              add_message(
                'error',
                "Hook `#{hook}` service `#{service['id']}` configuration option `#{config_option['code']}` " \
                "does not contain `#{field_name}` field"
              )
              next
            end

            next if field_name == 'default'

            next if config_option[field_name].is_a? String

            type = config_option[field_name].class
            add_message(
              'error',
              "Expected hook `#{hook}` service `#{service['id']}` configuration option `#{config_option['code']}` " \
              "field `#{field_name}` to be a String, but found #{type}"
            )
          end
        end
      end

      run do
        ignore_list = crd_discovery_service_ignore_list.to_s.split(',').map(&:strip).reject(&:blank?)
        services =
          JSON.parse(cds_services)['services']
            .reject { |service| ignore_list.include? service['id'] }

        services_by_hook = services.group_by { |service| service['hook'] }

        services_by_hook.each do |hook, hook_services|
          hook_services.each do |service|
            verify_required_fields(hook, service)
            verify_unique_values(hook, service)
          end
        end

        primary_hook_services = services_by_hook.slice(*primary_hooks).values.flatten

        assert messages.none? { |message| message[:type] == 'error' },
               'Some services contain invalid configuration options.'

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

        primary_hook_services.each do |service|
          coverage_info_config =
            service.dig('extension', 'davinci-crd.configuration-options')&.find do |config_option|
              config_option['code'] == 'coverage-info'
            end

          if coverage_info_config.present?
            if coverage_info_config['type'] != 'boolean'
              add_message(
                'error',
                "Service `#{service['id']}` `coverage-info` configuration option is not of type boolean"
              )
            end

            next
          end

          add_message(
            'error',
            "Service `#{service['id']}` does not contain a `coverage-info` configuration option"
          )
        end

        assert messages.none? { |message| message[:type] == 'error' },
               'Not all primary hook services contain valid configuration options.'
      end
    end
  end
end
