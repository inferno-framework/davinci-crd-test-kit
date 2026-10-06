require 'inferno'

module DaVinciCRDTestKit
  # Some CRD slices cannot be matched by the must support assessment as it stands, so they would
  # report as unobserved no matter what a client sent. Each override below covers one such case.
  module MustSupportSliceMatching
    def required_binding_value_match?(coding, values)
      whole_systems, enumerated = Array(values).partition do |value|
        value.is_a?(Hash) && value[:code].nil?
      end

      return true if whole_systems.any? { |value| value[:system] == coding.system }

      super(coding, enumerated)
    end

    def matching_slice?(slice, discriminator)
      return super unless discriminator[:type] == 'referenceTarget'

      reference_target?(slice, discriminator)
    end

    def find_slice(resource, path, discriminator)
      return super unless discriminator[:type] == 'referenceTarget'

      find_a_value_at(resource, path, recursive_segments: recursive_element_segments) do |element|
        reference_target?(element, discriminator)
      end
    end

    def reference_target?(element, discriminator)
      return false unless element.respond_to?(:actor)

      element.actor&.reference&.include?("#{discriminator[:resource_type]}/")
    end

    def matching_pattern_codeable_concept_slice?(slice, discriminator)
      return super if discriminator[:path].blank?

      codings = Array.wrap(slice.send(discriminator[:path])).flat_map { |value| Array.wrap(value.coding) }
      codings.any? { |coding| coding.code == discriminator[:code] && coding.system == discriminator[:system] }
    end

    INTERCHANGEABLE_TIMING_PATHS = ['oralDiet.schedule', 'supplement.schedule',
                                    'enteralFormula.administration.schedule'].freeze

    def missing_elements(resources = [])
      missing = super

      missing.reject do |element_definition|
        schedule = INTERCHANGEABLE_TIMING_PATHS.find { |path| element_definition[:path].start_with?("#{path}.") }
        next false if schedule.blank?

        timing_field = element_definition[:path].delete_prefix("#{schedule}.")
        (INTERCHANGEABLE_TIMING_PATHS - [schedule]).any? do |other|
          missing.none? { |one| one[:path] == "#{other}.#{timing_field}" }
        end
      end
    end
  end
end

# The must support assessment runs inside this class rather than in the test
Inferno::DSL::MustSupportAssessment::InternalMustSupportLogic.prepend(
  DaVinciCRDTestKit::MustSupportSliceMatching
)
