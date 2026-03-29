module DaVinciCRDTestKit
  # Methods for executing simple fhirpath queries on cds request objects, e.g., to resolve
  # prefetch tokens.
  #
  # If resolve() calls are in scope (CRD 2.2.0 and beyond), then an implementation of the
  # `resolve(target)` method must be provided, where `target` is
  module FhirpathOnCDSRequest
    # fhirpath services doesn't handle the following, which are handled manually
    # - non-fhir objects
    # - resolve()
    def execute_fhirpath_on_cds_request(hook_request, fhirpath_query)
      cds_component, remaining_query = identify_cds_component(fhirpath_query)
      execution_targets = cds_component.present? ? get_cds_field(hook_request, cds_component) : hook_request

      iteratively_execute_and_resolve(execution_targets, remaining_query)
    end

    private

    # -------------------------------------------------------------------------
    # resolve() handling
    # -------------------------------------------------------------------------

    # input is either
    # - string representing a FHIR reference, absolute or relative
    # - a FHIR Reference object with an absolute or relative reference in the `reference` element
    # Default implementation does not perform any resolving
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

    def iteratively_execute_and_resolve(execution_targets, fhirpath_query)
      remaining_query = fhirpath_query

      while remaining_query.present? && execution_targets.present?
        if remaining_query.starts_with?('resolve()')
          execution_targets = execution_targets.map do |target|
            resolve(target) # external implementation must be provided
          end.compact
          remaining_query = remaining_query[10..]
        else
          path_to_execute, query_after_next_resolve = remaining_query.split('.resolve()', 2)
          execution_targets = execution_targets.map do |target|
            delegate_execution_to_fhirpath_engine(target, path_to_execute)
          end.flatten
          remaining_query = "#{'resolve()' if remaining_query.include?('resolve()')}#{query_after_next_resolve}"
        end
      end

      execution_targets
    end

    # -------------------------------------------------------------------------
    # fhirpath delegation
    # -------------------------------------------------------------------------

    def fhirpath_evaluator
      @fhirpath_evaluator ||= Inferno::DSL::FhirpathEvaluation::Evaluator.new
    end

    def delegate_execution_to_fhirpath_engine(hash, fhirpath_query)
      return [hash] unless fhirpath_query.present?

      result = fhirpath_evaluator.call_fhirpath_service(hash, fhirpath_query)
      unless result.status.to_s.starts_with?('2')
        puts "Error on fhirpath #{fhirpath_query} on #{hash.to_json}: #{result.body}"
      end
      return [] unless result.status.to_s.starts_with?('2')

      JSON.parse(result.body).map { |entry| entry['element'] }
    end
  end
end
