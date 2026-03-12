module DaVinciCRDTestKit
  # Build responses using tester-provided template
  module FhirpathOnCDSRequest
    def fhirpath_evaluator
      @fhirpath_evaluator ||= Inferno::DSL::FhirpathEvaluation::Evaluator.new
    end

    # fhirpath service assumes that the object passed is a FHIR resource
    # so do everything manually until we get to that or a data type (e.g., string)
    def execute_fhirpath_on_cds_request(request, fhirpath_expression)
      execute_fhirpath_on_object(request, fhirpath_expression.split('.').map(&:strip))
    end

    def execute_fhirpath_on_object(hash, fhirpath_tokens)
      return [hash] unless fhirpath_tokens.present?
      return [] unless hash[fhirpath_tokens.first].present?

      next_value = hash[fhirpath_tokens.first]
      next_tokens = fhirpath_tokens.drop(1)

      case next_value
      when Hash
        if next_value['resourceType'].present?
          execute_fhirpath_on_fhir_resource(next_value, next_tokens)
        else
          handle_object_next_value_where(next_value, next_tokens)
        end
      when Array
        execute_fhirpath_on_array(next_value, next_tokens)
      else
        execute_fhirpath_on_datatype(next_value, next_tokens)
      end
    end

    def handle_object_next_value_where(next_value, next_tokens)
      return [next_value] unless next_tokens.present?

      if next_tokens.first&.starts_with?('where(')
        condition_target, condition_value = next_tokens.first[6..-2].split('=').map(&:strip)
        return [] unless next_value[condition_target] == condition_value

        next_tokens = next_tokens.drop(1)
      end

      execute_fhirpath_on_object(next_value, next_tokens)
    end

    def execute_fhirpath_on_fhir_resource(hash, fhirpath_tokens)
      return [hash] unless fhirpath_tokens.present?

      result = fhirpath_evaluator.call_fhirpath_service(hash, fhirpath_tokens.join('.'))
      return [] unless result.status.to_s.starts_with?('2')

      JSON.parse(result.body).map { |entry| entry['element'] }
    end

    def execute_fhirpath_on_array(array, fhirpath_tokens)
      return array unless fhirpath_tokens.present?

      array.map do |entry|
        case entry
        when Hash
          execute_fhirpath_on_object(entry, fhirpath_tokens)
        when Array
          execute_fhirpath_on_array(entry, fhirpath_tokens)
        else
          execute_fhirpath_on_datatype(entry, fhirpath_tokens)
        end
      end.flatten
    end

    def execute_fhirpath_on_datatype(value, fhirpath_tokens)
      return [] unless fhirpath_tokens.blank?

      [value]
    end
  end
end
