# Logical Model Validation Changes

The [logical models in version 2.2.1 of the CRD
IG](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/artifacts.html#4) contain
errors which are corrected in this test kit, so validation results may not
exactly match what would be expected from inspecting the logical models. The
following corrections are implemented:

* [Card.summary must be less than 140
  characters.](https://jira.hl7.org/browse/FHIR-56603)
* [Suggestion.uuid is
  required](https://hl7.org/fhir/us/davinci-crd/2.2.1/en/cards.html#ci-c-resp-3)
* [Suggestions are prohibited in Launch SMART App
  cards](https://jira.hl7.org/browse/FHIR-57471)
* [Alternate request allows additional
  creates](https://chat.fhir.org/#narrow/channel/180803-Da-Vinci-CRD/topic/Logical.20Model.20for.20Alternate.20Request.20is.20very.20strict/with/598419878)
* [Alternate request allows delete and
  update](https://jira.hl7.org/browse/FHIR-56606)
* [Form completion allows if-none-exist extension in system
  actions](https://chat.fhir.org/#narrow/channel/180803-Da-Vinci-CRD/topic/Questions.20around.20Form.20Completion.20response.20as.20a.20systemAction/with/598418134)
* [Form completion allows Questionnaire
  creation](https://jira.hl7.org/browse/FHIR-56604)
* [Form completion allows system actions instead of
  cards](https://jira.hl7.org/browse/FHIR-56607)
* [Update coverage allows system actions instead of
  cards](https://jira.hl7.org/browse/FHIR-56607)
* Additional resource types are allowed for [Alternate
  Request](https://jira.hl7.org/browse/FHIR-56701) and [Additional
  Orders](https://jira.hl7.org/browse/FHIR-56702)
