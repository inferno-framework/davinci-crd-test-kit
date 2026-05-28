require 'date'
require 'uri'

module DaVinciCRDTestKit
  class FhirpathServiceError < StandardError; end

  # Methods for executing simple fhirpath queries on cds request objects, e.g., to resolve
  # prefetch tokens.
  #
  # If resolve() calls are in scope (CRD 2.2.1 and beyond), then an implementation of the
  # `resolve(target)` method must be provided, where `target` is
  module FhirpathOnCDSRequest
    SUPPORTED_POST_RESOLVE_FUNCTIONS = %w[ofType today resolve].freeze
    TODAY_EXPRESSION_PATTERN = /\Atoday\(\)\s*(?:([+-])\s*(\d+)\s+days)?\z/

    # fhirpath services doesn't handle the following, which are handled manually
    # - non-fhir objects
    # - resolve()
    # - Bundle.entry.resource when resolve() appears in the remaining query (to track entry.fullUrl per entry)
    # - standalone today() expressions (today(), today()-N, today()+N)
    def execute_fhirpath_on_cds_request(hook_request, fhirpath_query)
      today_result = execute_today_expression(fhirpath_query)
      return today_result if today_result

      cds_component, remaining_query = identify_cds_component(fhirpath_query)
      execution_targets = cds_component.present? ? get_cds_field(hook_request, cds_component) : hook_request

      execution_targets.map do |execution_target|
        @current_base_fhir_server = hook_request['fhirServer']
        execute(execution_target, remaining_query)
      end.flatten.compact
    ensure
      # clean-up identity
      @current_base_fhir_server = nil
    end

    private

    # -------------------------------------------------------------------------
    # today() handling
    # -------------------------------------------------------------------------

    def execute_today_expression(fhirpath_query)
      match = fhirpath_query.strip.match(TODAY_EXPRESSION_PATTERN)
      return nil unless match

      date = Date.today
      if match[1]
        days = match[2].to_i
        date = match[1] == '+' ? date + days : date - days
      end
      [date.to_s]
    end

    # -------------------------------------------------------------------------
    # resolve() handling
    # -------------------------------------------------------------------------

    # input is either
    # - string representing a FHIR reference, absolute or relative
    # - a FHIR Reference object with an absolute or relative reference in the `reference` element
    # Default implementation does not perform any resolution
    def resolve(_reference)
      nil
    end

    # -------------------------------------------------------------------------
    # CDS Request Handling
    # -------------------------------------------------------------------------

    # returns a pair of [cds component, remaining query]
    def identify_cds_component(fhirpath_query)
      if fhirpath_query.starts_with?('context.')
        context_field, remaining_query = fhirpath_query[8..].split('.', 2)
        ["context.#{context_field}", remaining_query]
      elsif fhirpath_query.starts_with?('%')
        prefetch_key, remaining_query = fhirpath_query[1..].split('.', 2)
        ["prefetch.#{prefetch_key}",  remaining_query]
      else
        # everything is in the cds request
        [fhirpath_query, nil]
      end
    end

    def get_cds_field(request, cds_path)
      value = cds_path.split('.').reduce(request) { |hash, path| hash.present? ? hash[path] : nil }

      value.is_a?(Array) ? value : [value]
    end

    # -------------------------------------------------------------------------
    # Main execution loop
    # -------------------------------------------------------------------------

    def execute(execution_target, fhirpath_query)
      return execution_target unless fhirpath_query.present? && execution_target.present?

      if fhirpath_query.starts_with?('resolve()')
        execute_resolve(execution_target, fhirpath_query)
      elsif fhirpath_query.starts_with?('entry.resource.') && fhirpath_query.include?('resolve()')
        execute_entry_resource_step(execution_target, fhirpath_query)
      else
        execute_fhirpath_step(execution_target, fhirpath_query)
      end
    end

    def execute_fhirpath_step(execution_target, fhirpath_query)
      path_to_execute, query_after_next_resolve = fhirpath_query.split('.resolve()', 2)
      remaining_query = "#{'resolve()' if fhirpath_query.include?('resolve()')}#{query_after_next_resolve}"
      delegate_execution_to_fhirpath_engine(execution_target, path_to_execute).compact.map do |result|
        execute(result, remaining_query)
      end.flatten.compact
    end

    def execute_resolve(execution_target, fhirpath_query)
      referenced = resolve(execution_target)
      return nil unless referenced.present?

      execute(referenced, fhirpath_query[10..])
    end

    def execute_entry_resource_step(execution_target, fhirpath_query)
      validate_entry_resource_query!(fhirpath_query)
      return nil unless execution_target['entry'].present?

      Array.wrap(execution_target['entry']).map do |entry|
        @current_base_fhir_server = base_fhir_server_for_identity(entry['fullUrl'])
        execute(entry['resource'], fhirpath_query[15..])
      end.flatten.compact
    end

    def validate_entry_resource_query!(fhirpath_query)
      _, post_resolve = fhirpath_query.split('.resolve()', 2)
      return unless post_resolve.present?

      unsupported = post_resolve.scan(/[a-zA-Z_]\w*(?=\()/).uniq - SUPPORTED_POST_RESOLVE_FUNCTIONS
      return if unsupported.empty?

      raise FhirpathServiceError,
            "Unsupported function(s) after resolve() in '#{fhirpath_query}': #{unsupported.join(', ')}. " \
            "Supported: #{SUPPORTED_POST_RESOLVE_FUNCTIONS.join(', ')}."
    end

    def base_fhir_server_for_identity(current_resource_identity)
      return nil unless current_resource_identity.present?

      parsed_identity = URI.parse(current_resource_identity)
      return nil unless ['http', 'https'].include?(parsed_identity.scheme)

      current_resource_identity.split('/')[0..-3].join('/')
    rescue URI::InvalidURIError
      nil
    end

    # -------------------------------------------------------------------------
    # fhirpath delegation
    # -------------------------------------------------------------------------

    def fhirpath_evaluator
      @fhirpath_evaluator ||= Inferno::DSL::FhirpathEvaluation::Evaluator.new
    end

    def delegate_execution_to_fhirpath_engine(hash, fhirpath_query)
      return [hash] unless fhirpath_query.present?
      return [] unless hash.present?

      result = fhirpath_evaluator.call_fhirpath_service(hash, fhirpath_query)
      unless result.status.to_s.starts_with?('2')
        raise FhirpathServiceError,
              "FHIRPath service returned #{result.status} for query '#{fhirpath_query}' " \
              "on resource #{hash.to_json}: #{result.body}"
      end

      JSON.parse(result.body).map { |entry| entry['element'] }
    end
  end
end
