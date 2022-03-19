library USPSTF_Diabetes_Screening_FHIRv401 version '0.0.1'
using FHIR version '4.0.1'
include FHIRHelpers version '4.0.1' called FHIRHelpers
// include CDS_Connect_Conversions version '1.0.2' called Convert
include CDS_Connect_Commons_for_FHIRv401 version '1.0.0' called C3F

codesystem "LOINC": 'http://loinc.org'
codesystem "SNOMED-CT": 'http://snomed.info/sct'
codesystem "ICD-10-CM": 'http://hl7.org/fhir/sid/icd-10-cm'

valueset "Diabetes": 'https://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.103.12.1001'
valueset "Pregnancy": 'https://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.526.3.378'
valueset "Pregnancy (New ICD10 codes published in 2018 and 2019)": 'https://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1032.80'
// This next set includes SNOMED-CT and ICD-10-CM codes for prediabetes, impaired glucose tolerance (IGT) and impaired fasting glucose (IFG)
valueset "Prediabetes": 'https://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1222.419'
valueset "HemoglobinA1cTest": 'https://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1195.278'
valueset "FastingPlasmaGlucose": 'https://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1032.87'
// Using single code for 2h PP glucose because there doesn't appear to be an appropriate valueset
code "BloodGlucoseTwoHoursPostLoad": '1518-0' from LOINC display 'Glucose [Mass/volume] in Serum or Plasma --2 hours post 75 g glucose PO'

// the LOINC code for body height in inches produces null results in retrieve
// code BodyHeight: '8302-0' from "LOINC" display 'Body height'
// using snomed code instead
code BodyHeightCode: '50373000' from "SNOMED-CT" display 'Body height measure'
code BodyWeightCode: '3141-9' from "LOINC" display 'Body weight'
code BmiCode: '39156-5' from "LOINC" display 'BMI'
code "Pregnancy status": '82810-3' from "LOINC" display 'Pregnancy status'
code "Pregnant": '77386006' from "SNOMED-CT" display 'Patient currently pregnant (finding)'

context Patient

define InAgeRange: 
  if Patient.birthDate is not null then 
    AgeInYears() >= 35 and AgeInYears() < 71 
  else null

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
   // for all you physics majors out there, kg is mass and kilo is weight ;)
  case Weight.unit
    when '[lb_av]' then Weight.value*0.4535924
    when 'kg' then Weight.value
    when 'gm' then Weight.value/1000
    else null
  end

define ScreeningNeverDone:
  // never had HbA1c measure since turning 35
  // or GTT or fasting glucose
  null

define BMI:
  WeightInKilos/(HeightInMeters^2)

define BMIIsTwentyFiveOrGreater:
  BMI>=25

define MostRecentPregnancyObservation:
  C3F.MostRecent(C3F.Verified(C3F.ObservationLookBack([Observation: "Pregnancy status"], 42 weeks)))

define IsPregnant:
  Exists(C3F.Confirmed(C3F.ActiveCondition(
    [Condition: "Pregnancy"] union 
    [Condition: "Pregnancy (New ICD10 codes published in 2018 and 2019)"]
  )))
  or C3F.ConceptValue(MostRecentPregnancyObservation) ~ "Pregnant"

define HasDiabetes:
  Exists(C3F.Confirmed(C3F.ActiveCondition([Condition: "Diabetes"])))

define HasPrediabetes: // which includes IGG and IFG
  Exists(C3F.Confirmed(C3F.ActiveCondition([Condition: "Prediabetes"])))

// 3 years is the interval suggested by the guideline
define ScreenedWithinFiveYears:
  C3F.MostRecent(C3F.Verified(C3F.ObservationLookBack(
    [Observation: "HemoglobinA1cTest"] union
    [Observation: "FastingPlasmaGlucose"] union
    [Observation: "BloodGlucoseTwoHoursPostLoad"], 3 years)))

define IsExcluded: 
  if IsPregnant or
    HasDiabetes or
    HasPrediabetes then true 
  else false

define NeedMoreInformation:
  if IsExcluded is false then
    if InAgeRange is null then
      '- date of birth'
    else
      if InAgeRange is true then
        Combine(List{
          if Height is null then '- height' else null,
          if Weight is null then '- weight' else null
        }, '\n')
      else null
  else null

define Recommendation: 
  if InAgeRange is true and 
    BMIIsTwentyFiveOrGreater is true and 
    NeedMoreInformation is null and
    ScreenedWithinFiveYears is null and
    IsExcluded is false 
    then '- order HbA1c'
  else null

