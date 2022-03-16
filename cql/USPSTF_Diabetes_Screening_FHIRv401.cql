library USPSTF_Diabetes_Screening_FHIRv401 version '0.0.1'
using FHIR version '4.0.1'
include FHIRHelpers version '4.0.1' called FHIRHelpers
// include CDS_Connect_Conversions version '1.0.2' called Convert
include CDS_Connect_Commons_for_FHIRv401 version '1.0.0' called C3F

codesystem "LOINC": 'http://loinc.org'
codesystem "SNOMED-CT": 'http://snomed.info/sct'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113883.3.464.1003.103.12.1001/expansion)
valueset "Diabetes": 'https://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.103.12.1001'

// height should be in inches
// code BodyHeight: '8302-0' from "LOINC" display 'Body height'
code BodyHeightCode: '50373000' from "SNOMED-CT" display 'Body height measure'
// weight should be in pounds
code BodyWeightCode: '3141-9' from "LOINC" display 'Body weight'
// BMI can be calculated or entered manually
code BmiCode: '39156-5' from "LOINC" display 'BMI'

context Patient

define Heights:
  [Observation: BodyHeightCode]

define Weights:
  [Observation: BodyWeightCode]

define BmiObservations:
  [Observation: BmiCode]

define Height:
  FHIRHelpers.ToQuantity(C3F.MostRecent(Heights).value)

define Weight:
  FHIRHelpers.ToQuantity(C3F.MostRecent(Weights).value)

define HeightInMeters:
  // the only allowed units are [in_i] or cm
  case Height.unit
    when 'cm' then Height.value/100
    when '[in_i]' then (Height.value * 2.54)/100
    else null
  end

define WeightInKilos:
   // the only allowed values are [lb_av], kg and g
   // for all you physics majors out there, technically kg is MASS and kilo is WEIGHT ;)
  case Weight.unit
    when '[lb_av]' then Weight.value*0.4535924
    when 'kg' then Weight.value
    when 'gm' then Weight.value/1000
    else null
  end

define BMI:
  WeightInKilos/(HeightInMeters^2)