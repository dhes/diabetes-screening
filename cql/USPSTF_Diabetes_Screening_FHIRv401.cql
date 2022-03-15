library USPSTF_Diabetes_Screening_FHIRv401 version '0.0.1'
using FHIR version '4.0.1'
include FHIRHelpers version '4.0.1' called FHIRHelpers
// include CDS_Connect_Conversions version '1.0.2' called Convert
// include CDS_Connect_Commons_for_FHIRv401 version '1.0.0' called C3F

codesystem "LOINC": 'http://loinc.org'
codesystem "SNOMED-CT": 'http://snomed.info/sct'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113883.3.464.1003.103.12.1001/expansion)
valueset "Diabetes": 'https://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.103.12.1001'

// height should be in inches
// code BodyHeight: '8302-0' from "LOINC" display 'Body height'
code BodyHeight: '50373000' from "SNOMED-CT" display 'Body height measure'
// weight should be in pounds
code BodyWeight: '3141-9' from "LOINC" display 'Body weight'
// BMI can be calculated or entered manually
code BMI: '39156-5' from "LOINC" display 'BMI'

context Patient

define HeightObservation:
  [Observation: BodyHeight]

define WeightObservation:
  [Observation: BodyWeight]

define BmiObservation:
  [Observation: BMI]

define AllObservations:
  [Observation]

define HeightQuery: 
  [Observation] O
    where O.code = BodyHeight