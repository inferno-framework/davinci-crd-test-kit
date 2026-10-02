module DaVinciCRDTestKit
  module V221
    # The target resource reference is provided once for the scenario and used by several tests,
    # all of which rely on it being relative so that it can be read from the FHIR server given in
    # each hook request and compared against the resources provided in prefetch.
    module AccessLevelTargetReference
      TARGET_REFERENCE_PATTERN = %r{\A[A-Z][A-Za-z]*/[A-Za-z0-9\-.]{1,64}\z}

      def assert_target_reference_valid
        assert access_level_target_reference.to_s.match?(TARGET_REFERENCE_PATTERN),
               "Target Resource Reference `#{access_level_target_reference}` is not a relative " \
               'reference. It must take the form `ResourceType/id`, e.g. `Observation/123`.'
      end
    end
  end
end
