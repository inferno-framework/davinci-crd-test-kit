require_relative '../../server_test_helper'

module DaVinciCRDTestKit
  module V221
    class DiscoveryStandardPrefetchExpressionsTest < Inferno::Test
      include DaVinciCRDTestKit::ServerTestHelper

      title 'Server uses standard prefetch expressions'
      id :crd_v221_discovery_standard_prefetch_expressions
      description %(
        This test checks each prefetch expression value advertised by CRD services in the discovery
        response against the standard prefetch expressions listed in the CRD IG for the service hook. If a prefetch
        expression does not match one of the standard expressions for that hook, the test will add a warning.

        These warnings should be checked individually, as the interpretation of the warning will depend on the server's
        intent: For expressions that are intended to capture any of the data elements in that hook's set of
        [standard prefetch queries](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/foundation.html#appointment-book-prefetch),
        it must match the corresponding expression in the IG, and the warning should be considered an error. Note that
        the expression keys do not need to match and are ignored by this test.
        For expressions that are meant to capture other data in addition to what is captured by the standard prefetch
        queries, the warning can be ignored.
      )

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@found-29'

      input :cds_services
      input :crd_discovery_service_ignore_list,
            optional: true

      ALL_HOOKS = [
        'appointment-book',
        'encounter-start',
        'encounter-discharge',
        'order-dispatch',
        'order-select',
        'order-sign'
      ].freeze

      def ignored_service_ids
        crd_discovery_service_ignore_list.to_s.split(',').map(&:strip).reject(&:blank?)
      end

      def services_for_crd_validation(services)
        services
          .select { |service| ignored_service_ids.include?(service['id']) }
          .each do |service|
            info "Ignoring service `#{service['id']}` because it is in the ignore list."
          end

        services.reject { |service| ignored_service_ids.include?(service['id']) }
      end

      # rubocop:disable Layout/LineLength, Metrics/CyclomaticComplexity
      def standard_prefetch_expressions(hook, keys)
        communication_requests = keys['communicationRequests']
        device_requests = keys['deviceRequests']
        encounter = keys['encounter']
        medication_requests = keys['medicationRequests']
        nutrition_orders = keys['nutritionOrders']
        practitioner_roles = keys['practitionerRoles']
        service_requests = keys['serviceRequests']
        vision_prescriptions = keys['visionPrescriptions']

        case hook
        when 'appointment-book'
          {
            'patient' => 'Patient/{{context.patientId}}',
            'encounter' => 'Encounter/{{context.encounterId}}',
            'coverage' => 'Coverage?patient={{context.patientId}}&status=active',
            'deviceRequests' => "DeviceRequest?_id={{context.appointments.entry.resource.basedOn.extension('http://hl7.org/fhir/StructureDefinition/alternate-reference').value.resolve().ofType(DeviceRequest).id}}",
            'serviceRequests' => 'ServiceRequest?_id={{context.appointments.entry.resource.basedOn.resolve().ofType(ServiceRequest).id}}',
            'medicationRequests' => "MedicationRequest?_id={{context.appointments.entry.resource.basedOn.extension('http://hl7.org/fhir/StructureDefinition/alternate-reference').value.resolve().ofType(MedicationRequest).id}}",
            'devices' => ("Device?_id={{%#{device_requests}.entry.resource.code.resolve().id}}" if device_requests),
            'medications' => ("Medication?_id={{%#{medication_requests}.entry.resource.medication.resolve().id}}" if medication_requests),
            'practitionerRoles' => ("PractitionerRole?_id={{%#{encounter}.participant.individual.resolve().ofType(PractitionerRole).id|context.appointments.entry.resource.participant.actor.resolve().ofType(PractitionerRole).id|%#{device_requests}.entry.resource.performer.resolve().ofType(PractitionerRole).id|%#{device_requests}.entry.resource.requester.resolve().ofType(PractitionerRole).id|%#{medication_requests}.entry.resource.performer.resolve().ofType(PractitionerRole).id|%#{medication_requests}.entry.resource.requester.resolve().ofType(PractitionerRole).id|%#{service_requests}.entry.resource.performer.resolve().ofType(PractitionerRole).id|%#{service_requests}.entry.resource.requester.resolve().ofType(PractitionerRole).id}}" if encounter && device_requests && medication_requests && service_requests),
            'practitioners' => ("Practitioner?_id={{%#{practitioner_roles}.entry.resource.practitioner.resolve().id|%#{encounter}.participant.individual.resolve().ofType(Practitioner).id|context.appointments.entry.resource.participant.actor.resolve().ofType(Practitioner).id|%#{device_requests}.entry.resource.performer.resolve().ofType(Practitioner).id|%#{device_requests}.entry.resource.requester.resolve().ofType(Practitioner).id|%#{medication_requests}.entry.resource.performer.resolve().ofType(Practitioner).id|%#{medication_requests}.entry.resource.requester.resolve().ofType(Practitioner).id|%#{service_requests}.entry.resource.performer.resolve().ofType(Practitioner).id|%#{service_requests}.entry.resource.requester.resolve().ofType(Practitioner).id}}" if encounter && device_requests && medication_requests && practitioner_roles && service_requests),
            'organizations' => ("Organization?_id={{%#{practitioner_roles}.entry.resource.organization.resolve().id|%#{encounter}.serviceProvider.resolve().ofType(Organization).id|%#{medication_requests}.entry.resource.dispenseRequest.performer.resolve().ofType(Organization).id|%#{service_requests}.entry.resource.performer.resolve().ofType(Organization).id}}" if encounter && medication_requests && practitioner_roles && service_requests),
            'locations' => ("Location?_id={{%#{practitioner_roles}.entry.resource.location.resolve().id|%#{encounter}.location.location.resolve().id|context.appointments.entry.resource.participant.actor.resolve().ofType(Location).id|%#{service_requests}.entry.resource.locationReference.resolve().ofType(Location).id}}" if encounter && practitioner_roles && service_requests)
          }.compact
        when 'encounter-start', 'encounter-discharge'
          {
            'patient' => 'Patient/{{context.patientId}}',
            'encounter' => 'Encounter/{{context.encounterId}}',
            'coverage' => 'Coverage?patient={{context.patientId}}&status=active',
            'practitionerRoles' => ("PractitionerRole?_id={{%#{encounter}.participant.individual.resolve().ofType(PractitionerRole).id}}" if encounter),
            'practitioners' => ("Practitioner?_id={{%#{practitioner_roles}.entry.resource.practitioner.resolve().id|%#{encounter}.participant.individual.resolve().ofType(Practitioner).id}}" if encounter && practitioner_roles),
            'organizations' => ("Organization?_id={{%#{practitioner_roles}.entry.resource.organization.resolve().id|%#{encounter}.serviceProvider.resolve().ofType(Organization).id}}" if encounter && practitioner_roles),
            'locations' => ("Location?_id={{%#{practitioner_roles}.entry.resource.location.resolve().id|%#{encounter}.location.location.resolve().id}}" if encounter && practitioner_roles)
          }.compact
        when 'order-dispatch'
          {
            'patient' => 'Patient/{{context.patientId}}',
            'encounter' => 'Encounter/{{context.encounterId}}',
            'coverage' => 'Coverage?patient={{context.patientId}}&status=active',
            'communicationRequests' => 'CommunicationRequest?_id={{context.dispatchedOrders.resolve().ofType(CommunicationRequest).id}}',
            'deviceRequests' => 'DeviceRequest?_id={{context.dispatchedOrders.resolve().ofType(DeviceRequest).id}}',
            'medicationRequests' => 'MedicationRequest?_id={{context.dispatchedOrders.resolve().ofType(MedicationRequest).id}}',
            'nutritionOrders' => 'NutritionOrder?_id={{context.dispatchedOrders.resolve().ofType(NutritionOrder).id}}',
            'serviceRequests' => 'ServiceRequest?_id={{context.dispatchedOrders.resolve().ofType(ServiceRequest).id}}',
            'visionPrescriptions' => 'VisionPrescription?_id={{context.dispatchedOrders.resolve().ofType(VisionPrescription).id}}',
            'devices' => ("Device?_id={{%#{device_requests}.entry.resource.code.resolve().id}}" if device_requests),
            'medications' => ("Medication?_id={{%#{medication_requests}.entry.resource.medication.resolve().id}}" if medication_requests),
            'practitionerRoles' => ("PractitionerRole?_id={{%#{encounter}.participant.individual.resolve().ofType(PractitionerRole).id|%#{communication_requests}.entry.resource.sender.resolve().ofType(PractitionerRole).id|%#{communication_requests}.entry.resource.recipient.resolve().ofType(PractitionerRole).id|%#{communication_requests}.entry.resource.requester.resolve().ofType(PractitionerRole).id|%#{device_requests}.entry.resource.performer.resolve().ofType(PractitionerRole).id|%#{device_requests}.entry.resource.requester.resolve().ofType(PractitionerRole).id|%#{medication_requests}.entry.resource.performer.resolve().ofType(PractitionerRole).id|%#{medication_requests}.entry.resource.requester.resolve().ofType(PractitionerRole).id|%#{service_requests}.entry.resource.performer.resolve().ofType(PractitionerRole).id|%#{service_requests}.entry.resource.requester.resolve().ofType(PractitionerRole).id|%#{nutrition_orders}.entry.resource.orderer.resolve().ofType(PractitionerRole).id|%#{vision_prescriptions}.entry.resource.prescriber.resolve().ofType(PractitionerRole).id}}" if communication_requests && device_requests && encounter && medication_requests && nutrition_orders && service_requests && vision_prescriptions),
            'practitioners' => ("Practitioner?_id={{%#{practitioner_roles}.entry.resource.practitioner.resolve().id|%#{encounter}.participant.individual.resolve().ofType(Practitioner).id|%#{communication_requests}.entry.resource.sender.resolve().ofType(Practitioner).id|%#{communication_requests}.entry.resource.recipient.resolve().ofType(Practitioner).id|%#{communication_requests}.entry.resource.requester.resolve().ofType(Practitioner).id|%#{device_requests}.entry.resource.performer.resolve().ofType(Practitioner).id|%#{device_requests}.entry.resource.requester.resolve().ofType(Practitioner).id|%#{medication_requests}.entry.resource.performer.resolve().ofType(Practitioner).id|%#{medication_requests}.entry.resource.requester.resolve().ofType(Practitioner).id|%#{service_requests}.entry.resource.performer.resolve().ofType(Practitioner).id|%#{service_requests}.entry.resource.requester.resolve().ofType(Practitioner).id|%#{nutrition_orders}.entry.resource.orderer.resolve().ofType(Practitioner).id|%#{vision_prescriptions}.entry.resource.prescriber.resolve().ofType(Practitioner).id}}" if communication_requests && device_requests && encounter && medication_requests && nutrition_orders && practitioner_roles && service_requests && vision_prescriptions),
            'organizations' => ("Organization?_id={{%#{practitioner_roles}.entry.resource.organization.resolve().id|%#{encounter}.serviceProvider.resolve().ofType(Organization).id|%#{communication_requests}.entry.resource.recipient.resolve().ofType(Organization).id|%#{communication_requests}.entry.resource.sender.resolve().ofType(Organization).id|%#{medication_requests}.entry.resource.dispenseRequest.performer.resolve().id|%#{service_requests}.entry.resource.performer.resolve().ofType(Organization).id}}" if communication_requests && encounter && medication_requests && practitioner_roles && service_requests),
            'locations' => ("Location?_id={{%#{practitioner_roles}.entry.resource.location.resolve().id|%#{encounter}.location.location.resolve().id|%#{service_requests}.entry.resource.locationReference.resolve().id}}" if encounter && practitioner_roles && service_requests)
          }.compact
        when 'order-select', 'order-sign'
          {
            'patient' => 'Patient/{{context.patientId}}',
            'encounter' => 'Encounter/{{context.encounterId}}',
            'coverage' => 'Coverage?patient={{context.patientId}}&status=active',
            'devices' => 'Device?_id={{context.draftOrders.entry.resource.ofType(DeviceRequest).code.resolve().id}}',
            'medications' => 'Medication?_id={{context.draftOrders.entry.resource.ofType(MedicationRequest).medication.resolve().id}}',
            'practitionerRoles' => ("PractitionerRole?_id={{%#{encounter}.participant.individual.resolve().ofType(PractitionerRole).id|context.draftOrders.entry.resource.sender.resolve().ofType(PractitionerRole).id|context.draftOrders.entry.resource.recipient.resolve().ofType(PractitionerRole).id|context.draftOrders.entry.resource.requester.resolve().ofType(PractitionerRole).id|context.draftOrders.entry.resource.performer.resolve().ofType(PractitionerRole).id|context.draftOrders.entry.resource.orderer.resolve().ofType(PractitionerRole).id|context.draftOrders.entry.resource.prescriber.resolve().ofType(PractitionerRole).id}}" if encounter),
            'practitioners' => ("Practitioner?_id={{%#{practitioner_roles}.entry.resource.practitioner.resolve().id|%#{encounter}.participant.individual.resolve().ofType(Practitioner).id|context.draftOrders.entry.resource.sender.resolve().ofType(Practitioner).id|context.draftOrders.entry.resource.recipient.resolve().ofType(Practitioner).id|context.draftOrders.entry.resource.requester.resolve().ofType(Practitioner).id|context.draftOrders.entry.resource.performer.resolve().ofType(Practitioner).id|context.draftOrders.entry.resource.orderer.resolve().ofType(Practitioner).id|context.draftOrders.entry.resource.prescriber.resolve().ofType(Practitioner).id}}" if encounter && practitioner_roles),
            'organizations' => ("Organization?_id={{%#{practitioner_roles}.entry.resource.organization.resolve().id|%#{encounter}.serviceProvider.resolve().ofType(Organization).id|context.draftOrders.entry.resource.dispenseRequest.performer.resolve().id|context.draftOrders.entry.resource.sender.resolve().ofType(Organization).id|context.draftOrders.entry.resource.recipient.resolve().ofType(Organization).id|context.draftOrders.entry.resource.performer.resolve().ofType(Organization).id}}" if encounter && practitioner_roles),
            'locations' => ("Location?_id={{%#{practitioner_roles}.entry.resource.location.resolve().id|%#{encounter}.location.location.resolve().id|context.draftOrders.entry.resource.locationReference.resolve().id}}" if encounter && practitioner_roles)
          }.compact
        end
      end
      # rubocop:enable Layout/LineLength, Metrics/CyclomaticComplexity

      # We're not guaranteed the order of expressions, so infer standard-to-advertised key mappings in n passes,
      # This is necessary because each pass may make additional dependent expressions renderable,
      # such as practitioners after encounter and practitionerRoles have both been matched.
      def infer_keys_for_standard_expressions(prefetch, hook)
        key_map = {}
        remaining_prefetch = prefetch.dup

        prefetch.size.times do
          matched_keys = []

          remaining_prefetch.each do |actual_key, actual_expression|
            standard_key = standard_prefetch_expressions(hook, key_map).key(actual_expression)
            next if standard_key.blank? || key_map.key?(standard_key)

            key_map[standard_key] = actual_key
            matched_keys << actual_key
          end

          break if matched_keys.blank?

          matched_keys.each { |actual_key| remaining_prefetch.delete(actual_key) }
        end

        key_map
      end

      run do
        object = parse_json(cds_services)
        assert object['services'], 'Discovery response did not contain `services`'

        services = object['services']
        assert services.is_a?(Array), 'Services field of the CDS Discovery response object is not an array.'

        prefetch_services =
          services_for_crd_validation(services)
            .select { |service| service['prefetch'].is_a?(Hash) && service['prefetch'].present? }

        skip_if prefetch_services.blank?, 'No CRD services advertised prefetch support'

        prefetch_services.each do |service|
          next unless ALL_HOOKS.include?(service['hook'])

          keys_for_standard_expressions = infer_keys_for_standard_expressions(service['prefetch'], service['hook'])
          standard_expressions = standard_prefetch_expressions(service['hook'], keys_for_standard_expressions)

          service['prefetch'].each do |prefetch_key, prefetch_value|
            next if standard_expressions.value?(prefetch_value)

            msg = "Service `#{service['id']}` advertises prefetch expression `#{prefetch_value}` " \
                  "for hook `#{service['hook']}` in prefetch field `#{prefetch_key}`, which does not match " \
                  'one of the standard CRD prefetch expressions for that hook.'
            add_message('warning', msg)
          end
        end
      end
    end
  end
end
