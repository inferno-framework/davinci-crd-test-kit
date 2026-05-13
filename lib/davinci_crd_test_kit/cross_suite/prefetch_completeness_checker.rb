require_relative 'fhirpath_on_cds_request'
require_relative 'replace_tokens'
require 'uri'

module DaVinciCRDTestKit
  # -----------------------------------------------------------------------
  # Prefetch Check Helper Class
  # -----------------------------------------------------------------------
  class PrefetchCompletenessChecker
    include FhirpathOnCDSRequest
    include ReplaceTokens

    attr_accessor :hook_request, :request_index, :services_file_path,
                  :observed_fhirpath_collection_as_comma_delimited_string

    def initialize(hook_request, request_index, services_file_path)
      @hook_request = hook_request
      @request_index = request_index
      @services_file_path = services_file_path
      @observed_fhirpath_collection_as_comma_delimited_string = false
      extract_prefetched_resources
    end

    def check_prefetched_data
      return ["#{request_error_prefix} No prefetch data provided."] unless hook_request.key?('prefetch')

      hook_prefetch_templates.each do |prefetch_key, prefetch_request|
        check_prefetch_template(prefetch_key, prefetch_request)
      end

      hook_request['prefetch'].each_key do |prefetch_template|
        next if hook_prefetch_templates.key?(prefetch_template)

        errors << "#{request_error_prefix} Extra prefetch data " \
                  "provided in unrequested template '#{prefetch_template}'."
      end

      errors.uniq
    end

    private

    # -----------------------------------------------------------------------
    # Errors to return
    # -----------------------------------------------------------------------
    def errors
      @errors ||= []
    end

    def request_error_prefix
      "(Request #{request_index + 1})"
    end

    def error_prefix
      "#{request_error_prefix} Prefetch Template #{@current_prefetch_key} -"
    end

    # -----------------------------------------------------------------------
    # Requested Prefetch Templates
    # -----------------------------------------------------------------------
    def hook_prefetch_templates
      @hook_prefetch_templates ||=
        JSON.parse(File.read(services_file_path))['services'].find do |service|
          service['hook'] == hook_request['hook']
        end['prefetch']
    end

    # -----------------------------------------------------------------------
    # Check of actual prefetch against an instantiated request
    # -----------------------------------------------------------------------
    def check_prefetch_template(prefetch_key, prefetch_request)
      @current_prefetch_key = prefetch_key
      instantiated_request = replace_tokens_in_string(prefetch_request.dup, hook_request)
      if demonstrates_collection_as_comma_delimited_string?(prefetch_request, instantiated_request)
        @observed_fhirpath_collection_as_comma_delimited_string = true
      end
      unless hook_request['prefetch'].key?(prefetch_key)
        errors << "#{error_prefix} No prefetch data provided."
        return
      end
      check_provided_against_request(hook_request['prefetch'][prefetch_key], instantiated_request)
    rescue FhirpathServiceError => e
      raise "#{error_prefix} FHIRPath service error while evaluating prefetch template. " \
            "This indicates an implementation problem in Inferno - please log a ticket. Details: #{e.message}"
    end

    def check_provided_against_request(prefetched_value, instantiated_request)
      if instantiated_request.include?('?')
        if id_search?(instantiated_request)
          check_id_search(prefetched_value, instantiated_request)
        elsif instantiated_request.starts_with?('Coverage')
          check_coverage_search(prefetched_value, instantiated_request)
        else
          # TODO: better error handling for this case - or maybe none since we control the prefetches
          errors << "#{error_prefix} unexpected search template: #{instantiated_request}."
        end
      else
        check_read(prefetched_value, instantiated_request)
      end
    end

    def id_search?(request_string)
      resource_type = request_string.split('?').first
      request_string.starts_with?("#{resource_type}?_id=")
    end

    def check_coverage_search(prefetched_value, _instantiated_request)
      unless prefetched_value.present?
        errors << "#{error_prefix} requested Coverage not provided."
        return
      end

      check_is_fhir_resource(prefetched_value, target_resource_type: 'Bundle')
      unless prefetched_value['entry'].size == 1
        errors << "#{error_prefix} exactly one Coverage must be provided."
        return
      end

      check_coverage(prefetched_value.dig('entry', 0, 'resource'))
    end

    def check_coverage(prefetched_coverage)
      unless prefetched_coverage['resourceType'].present?
        errors << "#{error_prefix} entry in prefetched Coverage Bundle is not a FHIR resource (no resourceType)."
        return
      end

      unless prefetched_coverage['resourceType'] == 'Coverage'
        errors << "#{error_prefix} entry in prefetched Coverage Bundle has an unexpected type: " \
                  "expected Coverage, got #{prefetched_coverage['resourceType']}."
        return
      end

      unless prefetched_coverage['status'] == 'active'
        errors << "#{error_prefix} prefetched Coverage has an unexpected status: " \
                  "expected active, got #{prefetched_coverage['status']}."
      end

      target_patient_id = hook_request.dig('context', 'patientId')
      unless prefetched_coverage.dig('beneficiary', 'reference') == "Patient/#{target_patient_id}"
        errors << "#{error_prefix} prefetched Coverage has an unexpected beneficiary reference: " \
                  "expected Patient/#{target_patient_id}, got #{prefetched_coverage.dig('beneficiary',
                                                                                        'reference')}."
      end

      nil
    end

    def check_read(prefetched_value, instantiated_request)
      resource_type, resource_id = instantiated_request.split('/')

      resource_requested = resource_id.present?

      unless prefetched_value.present?
        errors << "#{error_prefix} requested resource '#{instantiated_request}' not provided." if resource_requested
        return
      end

      check_is_fhir_resource(prefetched_value, target_resource_type: resource_type)
      unless prefetched_value.key?('id')
        errors << "#{error_prefix} prefetched #{resource_type} is missing an id."
        return
      end
      unless prefetched_value['id'] == resource_id
        errors << "#{error_prefix} prefetched #{resource_type} has unexpected id: " \
                  "expected #{resource_id}, got #{prefetched_value['id']}."
      end

      nil
    end

    def check_id_search(prefetched_value, instantiated_request)
      resource_type, id_list = instantiated_request.split('?_id=')
      target_ids = id_list.present? ? id_list.split(',').map { |id| "#{resource_type}/#{id}" }.uniq.sort : []
      resources_requested = target_ids.present?

      unless prefetched_value.present?
        errors << "#{error_prefix} requested resources not provided: #{target_ids.join(', ')}." if resources_requested
        return
      end

      check_is_fhir_resource(prefetched_value, target_resource_type: 'Bundle')
      check_bundle_entry_resource_type(prefetched_value, resource_type)
      check_ids(target_ids, actual_ids(prefetched_value))
      nil
    end

    def actual_ids(prefetched_value)
      if prefetched_value['entry'].present?
        prefetched_value['entry'].map do |entry|
          type = entry.dig('resource', 'resourceType')
          id = entry.dig('resource', 'id')
          "#{type}/#{id}" if type.present? && id.present?
        end.compact
      else
        []
      end
    end

    def check_ids(target_ids, actual_ids)
      actual_ids_no_dups = actual_ids.compact.uniq
      unless actual_ids.size == actual_ids_no_dups.size
        errors << "#{error_prefix} prefetched Bundle has multiple entries with the same resource id."
      end

      missing_ids = target_ids - actual_ids
      if missing_ids.present?
        errors << "#{error_prefix} prefetched Bundle missing expected entries: " \
                  "#{missing_ids.join('\', \'')}."
      end
      extra_ids = actual_ids - target_ids
      return unless extra_ids.present?

      errors << "#{error_prefix} prefetched Bundle includes unrequested entries: " \
                "#{extra_ids.join('\', \'')}."
    end

    def check_bundle_entry_resource_type(bundle, target_resource_type)
      bundle['entry']&.each_with_index do |entry, index|
        entry_resource_type = entry.dig('resource', 'resourceType')
        next if entry_resource_type == target_resource_type

        errors << if entry_resource_type.present?
                    "#{error_prefix} prefetched Bundle entry #{index + 1} has an unexpected resourceType: " \
                      "expected #{target_resource_type}, got #{entry_resource_type}."
                  else
                    "#{error_prefix} prefetched Bundle entry #{index + 1} is not a FHIR resource (no resourceType)."
                  end
      end
    end

    def check_is_fhir_resource(prefetched_value, target_resource_type: nil)
      unless prefetched_value.key?('resourceType')
        errors << "#{error_prefix} prefetched value is not a FHIR resource (no resourceType)."
        return
      end

      return if target_resource_type.blank? || prefetched_value['resourceType'] == target_resource_type

      errors << "#{error_prefix} prefetched value has unexpected resourceType: " \
                "expected #{target_resource_type}, got #{prefetched_value['resourceType']}."
    end

    # -----------------------------------------------------------------------
    # Map of prefetched resources by fullUrl
    # -----------------------------------------------------------------------
    def prefetched_resources
      @prefetched_resources ||= {}
    end

    def extract_prefetched_resources
      hook_request['prefetch']&.each_value do |prefetch_resource|
        next unless prefetch_resource&.dig('resourceType').present?

        if prefetch_resource['resourceType'] == 'Bundle'
          extract_resources_from_prefetched_bundle(prefetch_resource)
        else
          extract_prefetched_resource_instance(prefetch_resource)
        end
      end
    end

    def extract_resources_from_prefetched_bundle(bundle)
      bundle['entry']&.each do |entry|
        next unless entry['resource'].present?

        if entry['fullUrl'].present?
          prefetched_resources[entry['fullUrl']] = entry['resource'] unless prefetched_resources.key?(entry['fullUrl'])
        else
          extract_prefetched_resource_instance(entry['resource'])
        end
      end
    end

    # no fullUrl available, so assume that it is a restful FHIR url
    # relative to the fhirServer of the hook request
    def extract_prefetched_resource_instance(resource_instance)
      return unless resource_instance['id'].present? &&
                    resource_instance['resourceType'].present? &&
                    hook_request['fhirServer'].present?

      fhir_server =
        if hook_request['fhirServer'].ends_with?('/')
          hook_request['fhirServer']
        else
          "#{hook_request['fhirServer']}/"
        end
      key = "#{fhir_server}#{resource_instance['resourceType']}/#{resource_instance['id']}"
      return if prefetched_resources.key?(key)

      prefetched_resources[key] = resource_instance
    end

    # -------------------------------------------------------------------------
    # fhirpath resolve() handling
    # -------------------------------------------------------------------------

    def resolve(reference)
      return nil unless reference.present?

      key = absolute_reference(reference)
      return nil unless key.present?

      unless prefetched_resources[key].present?
        errors << "#{error_prefix} resource '#{key}' needed to instantiate the query " \
                  'was not provided in the prefetched values.'

        nil
      end

      @current_base_fhir_server = base_fhir_server_for_identity(key)
      prefetched_resources[key]
    end

    def absolute_reference(reference)
      reference = reference['reference'] if reference.is_a?(Hash)
      if URI.parse(reference).absolute?
        reference
      else
        relative_to_absolute_reference(reference)
      end
    rescue URI::InvalidURIError => e
      errors << "#{error_prefix} '#{reference}' needed to instantiate the query " \
                "is invalid: #{e.message}."
      nil
    end

    def relative_to_absolute_reference(relative_reference)
      return nil unless relative_reference_valid?(relative_reference)

      if @current_base_fhir_server.nil?
        errors << "#{error_prefix} '#{relative_reference}' needed to instantiate the query " \
                  'is a relative reference, but the base FHIR Server is not known.'
        return nil
      end

      "#{@current_base_fhir_server}/#{relative_reference}"
    end

    def relative_reference_valid?(relative_reference)
      if relative_reference.split('/').length > 2
        errors << "#{error_prefix} '#{relative_reference}' needed to instantiate the query " \
                  'is not an absolute reference but has too many segments to be a relative reference.'
        return false
      end

      resource_type, id = relative_reference.split('/')
      if resource_type.blank? || id.blank?
        errors << "#{error_prefix} '#{relative_reference}' needed to instantiate the query " \
                  'is not a valid relative reference of the form <resource type>/<id>.'
      end

      true
    end

    # -------------------------------------------------------------------------
    # Observe a Collection represented as a comma-delimited string in instantiated search
    # -------------------------------------------------------------------------

    # client will have demonstrated turning a collection into a comma-delimited string if both
    # - the prefetch request follows the RESOURCE?_id={{TOKEN}} form when TOKEN has a | indicating 'and', and
    # - the instantiated query actually has multiple unique ids
    def demonstrates_collection_as_comma_delimited_string?(prefetch_request, instantiated_request)
      token = prefetch_request.match(/[a-zA-Z]*\?_id=\{\{(.+?)\}\}/)&.[](1)
      return false unless token.present? && token.include?('|')

      instantiated_request.split('?_id=').last.split(',').uniq.size > 1
    end
  end
end
