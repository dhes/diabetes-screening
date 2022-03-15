library USPSTF_Diabetes_Screening_FHIRv401 version '0.0.1'
using FHIR version '4.0.1'
include FHIRHelpers version '4.0.1' called FHIRHelpers
// include CDS_Connect_Conversions version '1.0.2' called Convert
// include CDS_Connect_Commons_for_FHIRv401 version '1.0.0' called C3F

codesystem "LOINC": 'http://loinc.org'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113883.3.464.1003.103.12.1001/expansion)
valueset "Diabetes": 'https://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.103.12.1001'

// height should be in inches
code "Height": '8302-0' from "LOINC" display 'height'
// weight should be in pounds
code "Weight": '3141-9' from "LOINC" display 'weight'
// BMI can be calculated or entered manually
code "BMI": '39156-5' from "LOINC" display 'BMI'

context Patient

define HeightObservation:
  [Observation: Height]

define WeightObservation:
  [Observation: Weight]

define BmiObservation:
  [Observation: BMI]