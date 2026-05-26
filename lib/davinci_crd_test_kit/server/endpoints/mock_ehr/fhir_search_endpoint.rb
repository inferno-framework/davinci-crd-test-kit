require_relative 'fhir_request_handler'
require 'us_core_test_kit'

module DaVinciCRDTestKit
  module MockEHR
    class FHIRSearchEndpoint < Inferno::DSL::SuiteEndpoint
      include Inferno::DSL::FHIRResourceNavigation
      include FHIRRequestHandler

      def make_response
        prepare_response
        return unless mock_ehr_bundle_present?
        return unless resource_type_present?

        return_response_bundle
      rescue StandardError => e
        return_unhandled_error(e)
      end

      # ---------------------------------------------------------------------------
      # Search Response
      # ---------------------------------------------------------------------------

      def return_response_bundle
        response.status = 200
        response.body = response_bundle.to_json
      end

      def response_bundle
        bundle = FHIR::Bundle.new({ type: 'searchset' })
        bundle.link << FHIR::Bundle::Link.new({ relation: 'self', url: self_link })

        matching_entry_list.each do |entry|
          bundle.entry << FHIR::Bundle::Entry.new({ resource: entry.resource,
                                                    search: FHIR::Bundle::Entry::Search.new({ mode: 'match' }) })
        end
        included_entry_list.each do |entry|
          bundle.entry << FHIR::Bundle::Entry.new({ resource: entry.resource,
                                                    search: FHIR::Bundle::Entry::Search.new({ mode: 'include' }) })
        end
        revincluded_entry_list.each do |entry|
          bundle.entry << FHIR::Bundle::Entry.new({ resource: entry.resource,
                                                    search: FHIR::Bundle::Entry::Search.new({ mode: 'include' }) })
        end

        bundle
      end

      # ---------------------------------------------------------------------------
      # Search Metadata
      # ---------------------------------------------------------------------------

      def self.metadata_files
        nil
      end

      def self.metadata_by_resource_type
        @metadata_by_resource_type ||=
          metadata_files&.each_with_object(Hash.new { |h, k| h[k] = [] }) do |path, by_type|
            metadata = USCoreTestKit::Generator::GroupMetadata.new(YAML.load_file(path, aliases: true))
            by_type[metadata.resource] << metadata
          end
      end

      def metadata_directory
        File.join(Gem::Specification.find_by_name('us_core_test_kit').gem_dir,
                  'lib', 'us_core_test_kit', 'generated', 'v6.1.0')
      end

      def metadata_list
        @metadata_list ||= load_metadata_list
      end

      def load_metadata_list
        return self.class.metadata_by_resource_type&.dig(resource_type) || [] if self.class.metadata_files

        Dir.glob(File.join(metadata_directory, "#{resource_type.underscore}*", 'metadata.yml')).filter_map do |path|
          m = USCoreTestKit::Generator::GroupMetadata.new(YAML.load_file(path, aliases: true))
          m if m.resource == resource_type
        end
      end

      def merged_search_definitions
        @merged_search_definitions ||= metadata_list.each_with_object({}) do |m, defs|
          m.search_definitions&.each do |name, definition|
            defs[name] ||= definition
          end
        end
      end

      def all_include_params
        @all_include_params ||= metadata_list.flat_map { |m| m.include_params || [] }.uniq
      end

      def all_references
        @all_references ||= metadata_list.flat_map { |m| m.references || [] }.uniq
      end

      def all_must_support_elements
        @all_must_support_elements ||= metadata_list.flat_map { |m| m.must_supports&.dig(:elements) || [] }.uniq
      end

      # ---------------------------------------------------------------------------
      # Self Link search parameters identification
      # ---------------------------------------------------------------------------

      def self_link
        host_and_path = request.url.split('?').first
        param_list =
          (supported_search_param_names + supported_include_param_paths.keys).map do |name|
            "#{name}=#{request_params[name]}"
          end
        param_list << '_revinclude=Provenance:target' if revinclude_provenance_target?
        query_string = param_list.present? ? "?#{param_list.join('&')}" : ''

        "#{host_and_path}#{query_string}"
      end

      def supported_search_param_names
        @supported_search_param_names ||=
          request_params.keys.select { |name| merged_search_definitions.key?(name.to_sym) }
      end

      def revinclude_provenance_target?
        request_params.any? { |key, value| key == '_revinclude' && value == 'Provenance:target' }
      end

      # map from include name to a list of paths at which to find references to include
      def supported_include_param_paths
        @supported_include_param_paths ||= calculate_supported_includes
      end

      def calculate_supported_includes
        request_params.keys.each_with_object({}) do |name, includes|
          next unless name == '_include'

          target = request_params[name]
          next unless target.present? && all_include_params.include?(target)

          paths = paths_to_include(target)
          next unless paths.present?

          includes[name] = paths
        end
      end

      def paths_to_include(target)
        paths = paths_from_search_definition(target)
        paths = paths_from_reference_list(target) unless paths.present?
        paths = paths_from_must_support_element(target) unless paths.present?
        paths
      end

      def paths_from_search_definition(target)
        search_parameter = target.split(':').last
        definition = merged_search_definitions[search_parameter.to_sym]
        return unless definition.present? && definition[:type] == 'Reference'

        definition[:full_paths]
      end

      def paths_from_reference_list(target)
        path_with_resource_type = target.gsub(':', '.')
        return unless all_references.any? { |ref| ref[:path] == path_with_resource_type }

        [path_with_resource_type]
      end

      def paths_from_must_support_element(target)
        target_element = target.split(':').last
        return unless all_must_support_elements.any? { |elt| element_matches_reference_target?(elt, target_element) }

        [target.gsub(':', '.')]
      end

      def element_matches_reference_target?(element, target_element)
        element[:types]&.include?('Reference') &&
          [target_element, "#{target_element}[x]"].include?(element[:path])
      end

      # ---------------------------------------------------------------------------
      # Search Logic
      # ---------------------------------------------------------------------------

      def matching_entry_list
        @matching_entry_list ||= mock_ehr_bundle.entry&.select do |entry|
          entry.resource.present? &&
            entry.resource.resourceType == resource_type &&
            include_resource_in_search_results?(entry.resource)
        end
      end

      def matching_entry_set
        @matching_entry_set ||= matching_entry_list.each_with_object(Set.new) do |entry, set|
          set << [entry.resource.resourceType, entry.resource.id]
        end
      end

      def request_params
        @request_params ||= request.params.to_h.except(:resource_type).stringify_keys
      end

      def include_resource_in_search_results?(resource)
        supported_search_param_names.reduce(true) do |matches_so_far, name|
          return false unless matches_so_far

          escaped_search_value = request_params[name]
          values_found = []
          resource_matches_param?(resource, name, escaped_search_value, values_found)
        end
      end

      def unescape_search_value(value)
        value&.gsub('\\,', ',')
      end

      def search_param_paths(name)
        paths = merged_search_definitions.dig(name.to_sym, :paths)
        paths[0] = 'local_class' if paths.first == 'class'

        paths
      end

      def resource_matches_param?(resource, search_param_name, escaped_search_value, values_found = []) # rubocop:disable Metrics/CyclomaticComplexity
        search_value = unescape_search_value(escaped_search_value)
        paths = search_param_paths(search_param_name)

        match_found = false

        paths.each do |path|
          type = merged_search_definitions.dig(search_param_name.to_sym, :type)

          resolve_path(resource, path).each do |value|
            values_found <<
              if value.is_a? FHIR::Reference
                value.reference
              elsif value.is_a? Inferno::DSL::PrimitiveType
                value.value
              else
                value
              end
          end

          values_found.compact!
          match_found =
            case type
            when 'Period', 'date', 'instant', 'dateTime'
              values_found.any? { |date| validate_date_search(search_value, date) }
            when 'HumanName'
              # When a string search parameter refers to the types HumanName and Address,
              # the search covers the elements of type string, and does not cover elements such as use and period
              # https://www.hl7.org/fhir/search.html#string
              search_value_downcase = search_value.downcase
              values_found.any? do |name|
                name&.text&.downcase&.start_with?(search_value_downcase) ||
                  name&.family&.downcase&.start_with?(search_value_downcase) ||
                  name&.given&.any? { |given| given.downcase.start_with?(search_value_downcase) } ||
                  name&.prefix&.any? { |prefix| prefix.downcase.start_with?(search_value_downcase) } ||
                  name&.suffix&.any? { |suffix| suffix.downcase.start_with?(search_value_downcase) }
              end
            when 'Address'
              search_value_downcase = search_value.downcase
              values_found.any? do |address|
                address&.text&.downcase&.start_with?(search_value_downcase) ||
                  address&.city&.downcase&.start_with?(search_value_downcase) ||
                  address&.state&.downcase&.start_with?(search_value_downcase) ||
                  address&.postalCode&.downcase&.start_with?(search_value_downcase) ||
                  address&.country&.downcase&.start_with?(search_value_downcase)
              end
            when 'CodeableConcept'
              # FHIR token search (https://www.hl7.org/fhir/search.html#token): "When in doubt, servers SHOULD
              # treat tokens in a case-insensitive manner, on the grounds that including undesired data has
              # less safety implications than excluding desired behavior".
              codings = values_found.flat_map(&:coding)
              if search_value.include? '|'
                system = search_value.split('|').first
                code = search_value.split('|').last
                codings&.any? { |coding| coding.system == system && coding.code&.casecmp?(code) }
              else
                codings&.any? { |coding| coding.code&.casecmp?(search_value) }
              end
            when 'Coding'
              if search_value.include? '|'
                system = search_value.split('|').first
                code = search_value.split('|').last
                values_found.any? { |coding| coding.system == system && coding.code&.casecmp?(code) }
              else
                values_found.any? { |coding| coding.code&.casecmp?(search_value) }
              end
            when 'Identifier'
              if search_value.include? '|'
                values_found.any? { |identifier| "#{identifier.system}|#{identifier.value}" == search_value }
              else
                values_found.any? { |identifier| identifier.value == search_value }
              end
            when 'string'
              searched_values = search_value.downcase.split(/(?<!\\\\),/).map { |string| string.gsub('\\,', ',') }
              values_found.any? do |value_found|
                searched_values.any? { |searched_value| value_found.downcase.starts_with? searched_value }
              end
            else
              # searching by patient requires special case because we are searching by a resource identifier
              # references can also be URLs, so we may need to resolve those URLs
              if ['subject', 'patient'].include? search_param_name.to_s
                id = search_value.split('Patient/').last
                possible_values = [id, "Patient/#{id}"] # TODO: "#{url}/Patient/#{id}"] - allow absolute references?
                values_found.any? do |reference|
                  possible_values.include? reference
                end
              else
                search_values = search_value.split(/(?<!\\\\),/).map { |string| string.gsub('\\,', ',') }
                values_found.any? { |value_found| search_values.include? value_found }
              end
            end

          break if match_found
        end

        match_found
      end

      def get_fhir_datetime_range(datetime)
        range = { start: DateTime.xmlschema(datetime), end: nil }
        range[:end] =
          case datetime
          when /^\d{4}$/ # YYYY
            range[:start].next_year - 1.seconds
          when /^\d{4}-\d{2}$/ # YYYY-MM
            range[:start].next_month - 1.seconds
          when /^\d{4}-\d{2}-\d{2}$/ # YYYY-MM-DD
            range[:start].next_day - 1.seconds
          else # YYYY-MM-DDThh:mm:ss+zz:zz
            range[:start]
          end
        range
      end

      def get_fhir_period_range(period)
        range = { start: nil, end: nil }
        range[:start] = DateTime.xmlschema(period.start) unless period.start.nil?
        return range if period.end.nil?

        period_end_beginning = DateTime.xmlschema(period.end)
        range[:end] =
          case period.end
          when /^\d{4}$/ # YYYY
            period_end_beginning.next_year - 1.seconds
          when /^\d{4}-\d{2}$/ # YYYY-MM
            period_end_beginning.next_month - 1.seconds
          when /^\d{4}-\d{2}-\d{2}$/ # YYYY-MM-DD
            period_end_beginning.next_day - 1.seconds
          else # YYYY-MM-DDThh:mm:ss+zz:zz
            period_end_beginning
          end
        range
      end

      # NOTE: this is different from the US Core implementation for le and ge
      # See https://jira.hl7.org/browse/FHIR-51068
      def fhir_date_comparer(search_range, target_range, comparator, extend_start: false, extend_end: false) # rubocop:disable Metrics/CyclomaticComplexity
        # Implicitly, a missing lower boundary is "less than" any actual date.
        # A missing upper boundary is "greater than" any actual date.
        case comparator
        when 'eq' # the range of the search value fully contains the range of the target value
          !target_range[:start].nil? && !target_range[:end].nil? && search_range[:start] <= target_range[:start] &&
            search_range[:end] >= target_range[:end]
        when 'ne' # the range of the search value does not fully contain the range of the target value
          target_range[:start].nil? ||
            target_range[:end].nil? ||
            search_range[:start] > target_range[:start] ||
            search_range[:end] < target_range[:end]
        when 'gt' #  the range above the search value intersects (i.e. overlaps) with the range of the target value
          target_range[:end].nil? ||
            search_range[:end] < target_range[:end] ||
            (search_range[:end] < (target_range[:end] + 1) && extend_end)
        when 'lt' # the range below the search value intersects (i.e. overlaps) with the range of the target value
          target_range[:start].nil? ||
            search_range[:start] > target_range[:start] ||
            (search_range[:start] > (target_range[:start] - 1) && extend_start)
        when 'ge' # the target end is at or after the search range start
          target_range[:end].nil? || target_range[:end] >= search_range[:start]
        when 'le' # the target start is at or before the search range end
          target_range[:start].nil? || target_range[:start] <= search_range[:end]
        when 'sa' # the range above the search value contains the range of the target value
          !target_range[:start].nil? && search_range[:end] < target_range[:start]
        when 'eb' # the range below the search value contains the range of the target value
          !target_range[:end].nil? && search_range[:start] > target_range[:end]
        when 'ap' # the range of the search value overlaps with the range of the target value
          if target_range[:start].nil? || target_range[:end].nil?
            (target_range[:start].nil? && search_range[:start] < target_range[:end]) ||
              (target_range[:end].nil? && search_range[:end] > target_range[:start])
          else
            search_range[:start].between?(target_range[:start], target_range[:end]) ||
              search_range[:end].between?(target_range[:start], target_range[:end])
          end
        end
      end

      def validate_date_search(search_value, target_value)
        if target_value.instance_of? FHIR::Period
          validate_period_search(search_value, target_value)
        else
          validate_datetime_search(search_value, target_value)
        end
      end

      def validate_datetime_search(search_value, target_value)
        comparator = search_value[0..1]
        if ['eq', 'ge', 'gt', 'le', 'lt', 'ne', 'sa', 'eb', 'ap'].include? comparator
          search_value = search_value[2..]
        else
          comparator = 'eq'
        end
        search_is_date = date?(search_value)
        target_is_date = date?(target_value)
        search_range = get_fhir_datetime_range(search_value)
        target_range = get_fhir_datetime_range(target_value)
        fhir_date_comparer(search_range, target_range, comparator, extend_start: !search_is_date && target_is_date,
                                                                   extend_end: !search_is_date && target_is_date)
      end

      def validate_period_search(search_value, target_value)
        comparator = search_value[0..1]
        if ['eq', 'ge', 'gt', 'le', 'lt', 'ne', 'sa', 'eb', 'ap'].include? comparator
          search_value = search_value[2..]
        else
          comparator = 'eq'
        end
        search_is_date = date?(search_value)
        search_range = get_fhir_datetime_range(search_value)
        target_range = get_fhir_period_range(target_value)
        fhir_date_comparer(search_range, target_range, comparator,
                           extend_start: !search_is_date && date?(target_value.start),
                           extend_end: !search_is_date && date?(target_value.end))
      end

      def date?(value)
        /^\d{4}(-\d{2})?(-\d{2})?$/.match?(value) # YYYY or YYYY-MM or YYYY-MM-DD
      end

      # ---------------------------------------------------------------------------
      # _include logic
      # ---------------------------------------------------------------------------

      def included_entry_list
        @included_entry_list ||= begin
          entries = []
          included_set = Set.new
          matching_entry_list.each do |entry|
            resource = entry.resource
            next unless include_paths_by_resource_type.key?(resource.resourceType)

            include_paths_by_resource_type[resource.resourceType].each do |target_include_path|
              resolve_path(resource, target_include_path).each do |reference|
                evaluate_included_reference(reference, entries, included_set)
              end
            end
          end
          @included_entry_set = included_set
          entries
        end
      end

      def included_entry_set
        included_entry_list # ensure built, which populates @included_entry_set
        @included_entry_set ||= Set.new
      end

      def evaluate_included_reference(reference, included_entries, included_set)
        return unless local_reference?(reference)

        resource_type, resource_id = reference.reference.split('/')
        key = [resource_type, resource_id]
        return if included_set.include?(key) || matching_entry_set.include?(key)

        included_entry = resolve_reference_to_entry_in_bundle(resource_type, resource_id)
        return unless included_entry.present?

        included_entries << included_entry
        included_set << key
      end

      def include_paths_by_resource_type
        @include_paths_by_resource_type ||=
          supported_include_param_paths.values.each_with_object({}) do |include_paths, by_resource_type|
            include_paths.each do |path_with_resource_type|
              resource_type, path = path_with_resource_type.split('.', 2)
              (by_resource_type[resource_type] ||= []) << path
            end
          end
      end

      def local_reference?(reference)
        reference.is_a?(FHIR::Reference) &&
          reference.reference.split('/').length == 2 # local reference
      end

      def bundle_entry_index
        @bundle_entry_index ||= mock_ehr_bundle.entry.each_with_object({}) do |entry, index|
          next unless entry.resource.present?

          index[[entry.resource.resourceType, entry.resource.id]] = entry
        end
      end

      def resolve_reference_to_entry_in_bundle(resource_type, resource_id)
        bundle_entry_index[[resource_type, resource_id]]
      end

      # ---------------------------------------------------------------------------
      # _revinclude logic
      # ---------------------------------------------------------------------------
      def revincluded_entry_list
        @revincluded_entry_list ||= revinclude_provenance_target? ? build_revincluded_entry_list : []
      end

      def revincluded_entry_set
        revincluded_entry_list # ensure built, which populates @revincluded_entry_set
        @revincluded_entry_set ||= Set.new
      end

      def build_revincluded_entry_list
        entries = []
        revincluded_set = Set.new
        mock_ehr_bundle.entry.each do |entry|
          next unless candidate_provenance_for_revinclude?(entry, revincluded_set)

          resolve_path(entry.resource, 'target').each do |reference|
            evaluate_revincluded_reference(entry, reference, entries, revincluded_set)
          end
        end
        @revincluded_entry_set = revincluded_set
        entries
      end

      def candidate_provenance_for_revinclude?(entry, revincluded_set)
        return false unless entry.resource.present?
        return false unless entry.resource.resourceType == 'Provenance'

        key = [entry.resource.resourceType, entry.resource.id]
        !revincluded_set.include?(key) && !included_entry_set.include?(key) &&
          !matching_entry_set.include?(key)
      end

      def evaluate_revincluded_reference(referencing_entry, reference, revincluded_entries, revincluded_set)
        return unless local_reference?(reference)

        resource_type, resource_id = reference.reference.split('/')
        return unless matching_entry_set.include?([resource_type, resource_id]) ||
                      included_entry_set.include?([resource_type, resource_id])

        provenance_key = [referencing_entry.resource.resourceType, referencing_entry.resource.id]
        return if revincluded_set.include?(provenance_key)

        # referenced instance is matched or included — add the referencing Provenance
        revincluded_entries << referencing_entry
        revincluded_set << provenance_key
      end
    end
  end
end
