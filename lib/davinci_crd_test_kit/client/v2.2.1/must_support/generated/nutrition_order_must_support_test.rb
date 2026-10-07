require_relative '../request_must_support_with_attestation_option'

module DaVinciCRDTestKit
  module V221
    class NutritionOrderMustSupportTest < RequestMustSupportWithAttestationOption
      id :crd_v221_nutrition_order_must_support
      title 'CRD Nutrition Order must support elements are observed'
      description <<~DESCRIPTION
        The CRD IG [requires](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/conformance.html#ci-c-conf-3)
        that when a client "maintains a mustSupport data element and surfaces it to users, then it
        SHALL be exposed in their FHIR interface when the data exists and privacy constraints permit."

        During this test, Inferno will check whether all must support elements defined in the
        profile(s) listed below are demonstrated within hook requests made during this session.
        This check may vacuously pass if the tester has attested that this resource type is not
        supported by the client system or if the relevant hooks are not invoked.

        If any must support elements are not demonstrated, the tester will have the option to attest
        that these elements are not supported by the client system or surfaced to its users. Testers
        must setup scenarios in which the "data exists and privacy constraints permit" Inferno to view
        the must support information.

        Inferno will consider resources present within the `context` and `prefetch` elements of all hook
        requests made during the latest run of each `Hooks` subgroup and the `Additional Hook
        Invocations for Cross Hook Support Demonstration` group, but not any made within the `Scenarios`
        subgroups. If any of the considered groups are re-run, then requests made during prior runs will
        no longer be considered and must support elements demonstrated only during that prior run must
        be re-demonstrated on the new run or a subsequent one.


        ### [CRD Nutrition Order](http://hl7.org/fhir/us/davinci-crd/2.2.1/en/StructureDefinition-profile-nutritionorder.html)

        - `allergyIntolerance`
        - `contained`
        - `dateTime`
        - `encounter`
        - `enteralFormula`
        - `enteralFormula.additiveType`
        - `enteralFormula.administration`
        - `enteralFormula.administration.quantity`
        - `enteralFormula.administration.rate[x]:rateRatio`
        - `enteralFormula.administration.schedule`
        - `enteralFormula.baseFormulaType`
        - `enteralFormula.caloricDensity`
        - `enteralFormula.routeofAdministration`
        - `excludeFoodModifier`
        - `extension:Coverage-Information`
        - `extension:EncounterCategory`
        - `extension:ServiceCategory`
        - `foodPreferenceModifier`
        - `identifier`
        - `oralDiet`
        - `oralDiet.nutrient`
        - `oralDiet.nutrient.modifier`
        - `oralDiet.schedule`
        - `oralDiet.texture`
        - `oralDiet.texture.foodType`
        - `oralDiet.texture.modifier`
        - `oralDiet.type`
        - `orderer`
        - `patient`
        - `status`
        - `supplement`
        - `supplement.quantity`
        - `supplement.schedule`
        - `supplement.type`

        #### Timing

        The CRD Timing elements below appear in more than one place on this profile. Each only
        needs to be demonstrated in one of the locations listed under it.

        - `event`, on any one of:
          - `oralDiet.schedule.event`
          - `supplement.schedule.event`
          - `enteralFormula.administration.schedule.event`

        - `repeat`, on any one of:
          - `oralDiet.schedule.repeat`
          - `supplement.schedule.repeat`
          - `enteralFormula.administration.schedule.repeat`

        - `repeat.bounds[x]:boundsPeriod`, on any one of:
          - `oralDiet.schedule.repeat.bounds[x]:boundsPeriod`
          - `supplement.schedule.repeat.bounds[x]:boundsPeriod`
          - `enteralFormula.administration.schedule.repeat.bounds[x]:boundsPeriod`

        - `repeat.count`, on any one of:
          - `oralDiet.schedule.repeat.count`
          - `supplement.schedule.repeat.count`
          - `enteralFormula.administration.schedule.repeat.count`

        - `repeat.duration`, on any one of:
          - `oralDiet.schedule.repeat.duration`
          - `supplement.schedule.repeat.duration`
          - `enteralFormula.administration.schedule.repeat.duration`

        - `repeat.durationUnit`, on any one of:
          - `oralDiet.schedule.repeat.durationUnit`
          - `supplement.schedule.repeat.durationUnit`
          - `enteralFormula.administration.schedule.repeat.durationUnit`

        - `repeat.frequency`, on any one of:
          - `oralDiet.schedule.repeat.frequency`
          - `supplement.schedule.repeat.frequency`
          - `enteralFormula.administration.schedule.repeat.frequency`

        - `repeat.period`, on any one of:
          - `oralDiet.schedule.repeat.period`
          - `supplement.schedule.repeat.period`
          - `enteralFormula.administration.schedule.repeat.period`

        - `repeat.periodUnit`, on any one of:
          - `oralDiet.schedule.repeat.periodUnit`
          - `supplement.schedule.repeat.periodUnit`
          - `enteralFormula.administration.schedule.repeat.periodUnit`
      DESCRIPTION

      verifies_requirements 'hl7.fhir.us.davinci-crd_2.2.1@conf-3',
                            'hl7.fhir.us.davinci-crd_2.2.1@hook-3'

      config(
        options: {
          ig_version: 'v2.2.1',
          profiles: [
            { resource_type: 'NutritionOrder', profile_keys: ['nutrition_order'] }
          ]
        }
      )
    end
  end
end
