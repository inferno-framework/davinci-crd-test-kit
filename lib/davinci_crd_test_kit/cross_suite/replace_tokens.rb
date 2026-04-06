require_relative 'fhirpath_on_cds_request'

module DaVinciCRDTestKit
  # Replace "prefetch" tokens (fhirpath surrounded by {{}}) in json object representation
  module ReplaceTokens
    include DaVinciCRDTestKit::FhirpathOnCDSRequest

    def replace_tokens(value, request)
      case value
      when Hash
        value.each_value { |sub_value| replace_tokens(sub_value, request) }
      when Array
        value.map! { |entry| replace_tokens(entry, request) }
      else
        replace_tokens_in_string(value.to_s, request)
      end
    end

    def replace_tokens_in_string(string, request)
      return string unless string.include?('{{')

      tokens_to_replace = string.scan(/\{\{([^}]+)\}\}/).flatten
      replacements = tokens_to_replace.each_with_object({}) do |expression, dictionary|
        next if dictionary[expression].present?

        dictionary["{{#{expression}}}"] = calculate_expression_value(request, expression)
      end

      string.gsub!(/\{\{.*?\}\}/, replacements)
    end

    def calculate_expression_value(request, expression)
      results = execute_fhirpath_on_cds_request(request, expression)
      results.map { |res| res.is_a?(Array) || res.is_a?(Hash) ? nil : res }.map(&:to_s).join(',')
    end
  end
end
