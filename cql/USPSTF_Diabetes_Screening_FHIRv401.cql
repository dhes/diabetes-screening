library USPSTF_Diabetes_Screening_FHIRv401 version '0.0.1'
using FHIR version '4.0.1'
include FHIRHelpers version '4.0.1' called FHIRHelpers
// include CDS_Connect_Conversions version '1.0.2' called Convert
include CDS_Connect_Commons_for_FHIRv401 version '1.0.0' called C3F

codesystem "LOINC": 'http://loinc.org'
codesystem "SNOMED-CT": 'http://snomed.info/sct'
codesystem "ICD-10-CM": 'http://hl7.org/fhir/sid/icd-10-cm'
codesystem "Race & Ethnicity - CDC": 'urn:oid:2.16.840.1.113883.6.238'

// + indicates this set is also in diabetes-screening-cds-connect, - that it is not
// +
valueset "Diabetes": 'https://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.103.12.1001'
// +
valueset "Pregnancy": 'https://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.526.3.378'
// +
valueset "Pregnancy (New ICD10 codes published in 2018 and 2019)": 'https://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1032.80'
// This next set includes SNOMED-CT and ICD-10-CM codes for prediabetes, impaired glucose tolerance (IGT) and impaired fasting glucose (IFG)
// -
valueset "Prediabetes": 'https://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1222.419'
// -
valueset "HemoglobinA1cTest": 'https://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1195.278'
// +
valueset "FastingPlasmaGlucose": 'https://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1032.87'
// Using single code for 2h PP glucose 
// diabetes-screening-cds-connect uses valueset 2.16.840.1.113762.1.4.1032.94 containing 20 kinds of GTT result
// but.... the USPSTF guideline text specifies the two-hour 75 gm load version, so here a single code is used
code "BloodGlucoseTwoHoursPostLoad": '1518-0' from LOINC display 'Glucose [Mass/volume] in Serum or Plasma --2 hours post 75 g glucose PO'

// the LOINC code for body height in inches produces null results in retrieve
// code BodyHeight: '8302-0' from "LOINC" display 'Body height'
// using snomed code instead
code BodyHeightCode: '50373000' from "SNOMED-CT" display 'Body height measure'
code BodyWeightCode: '3141-9' from "LOINC" display 'Body weight'
code BmiCode: '39156-5' from "LOINC" display 'BMI'
code "Pregnancy status": '82810-3' from "LOINC" display 'Pregnancy status'
code "Pregnant": '77386006' from "SNOMED-CT" display 'Patient currently pregnant (finding)'
code "Asian": '2028-9' from "Race & Ethnicity - CDC" display 'Asian'

context Patient

define RaceExtension:
	singleton from (
		Patient.extension Ext
		where Ext.url.value = 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-race'
	)

define RaceCodes:
	(RaceExtension.extension) Ext where Ext.url.value = 'ombCategory' return FHIRHelpers.ToCode(Ext.value as FHIR.Coding)

define IsAsian: if exists (RaceCodes) then exists (RaceCodes RC where RC ~ "Asian") else null

// "The USPSTF recommends screening for prediabetes and type 2 diabetes in adults aged 35 to 70 years..."
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

define Gender: 
  case Patient.gender.value
    when 'male' then 'He'
    when 'female' then 'She'
    else null
  end

define MostRecentHeight:
  C3F.MostRecent(C3F.Verified(Heights))

// Get most recent date whether it is effectiveDateTime, instant, 
// effectivePeriod.end, effectivePeriod.start or issued 
// define HeightDate:
//   C3F.FindDate(MostRecentHeight)

// "...who have overweight or obesity"
define Height:
  C3F.QuantityValue(MostRecentHeight)

define MostRecentWeight:
  C3F.MostRecent(C3F.Verified(Weights))

define WeightDate:
  C3F.FindDate(MostRecentWeight)

define Weight:
  C3F.QuantityValue(MostRecentWeight)

define MostRecentBmiObservation:
  C3F.MostRecent(C3F.Verified(BmiObservations))

define BmiDate:
  C3F.FindDate(MostRecentBmiObservation)

define BmiObservation:
  C3F.QuantityValue(MostRecentBmiObservation)

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

define BmiCalc:
  if WeightInKilos is not null and HeightInMeters is not null then 
    System.Quantity  {
      value: WeightInKilos/(HeightInMeters^2), 
      unit: 'kg/m2'
    }
  else null

// truth table
// Use the BMI recorded as an observation if it is more recent than the most recent height and weight observations; else the BMI calculated from height and weight
// First determine which of these observastions exist and impact on BMI
// | =================================================== |
// |                     | Exists? -->                   |
// | =================== | = | = | = | = | = | = | = | = |
// |  BMI Observation    | T | T | T | F | F | F | T | F |
// |  Height Observation | T | T | F | T | F | T | F | F |
// |  Weight Observation | T | F | T | T | T | F | F | F |
// | =================== | = | = | = | = | = | = | = | = |
// |  BMI                | * | O | O | C | N | N | O | N |
// | =================== | = | = | = | = | = | = | = | = |
// 
// N Null
// O BMIO - BMI Observation
// C BmiCalc - calculated from weight and height
// * BMIO or BmiCalc, whichever is newer

// inverting the truth table
// | =============================== |
// |          | BMIO | Wt | Ht | BMI |                
// | =============================== |
// |  Exists? |  T   | T  | T  |  *  |
// |     |    |  T   | T  | F  |  O  |
// |     |    |  T   | F  | T  |  O  |
// |    \ /   |  F   | T  | T  |  C  |
// |          |  F   | F  | T  |  N  |
// |          |  F   | T  | F  |  N  |
// |          |  T   | F  | F  |  O  |
// |          |  F   | F  | F  |  N  |
// | =============================== |
// LEGEND
// N Null
// O BMIO - BMI Observation
// C BmiCalc - calculated from weight and height
// * BMIO or BmiCalc, whichever is newer
// Weight and height might have different dates. 
// Since height is relatively static, use the date of the weight to determine whether BmiObservation or BmiCalc is newer. 

// Truth table in code form. T='exists' F='not exists'. The all-false case is covered by the last 'else null'
define BMI:
  case 
    when     exists (BmiObservations) and     exists (Weights) and     exists (Heights) then if WeightDate > BmiDate then BmiCalc else BmiObservation
    when     exists (BmiObservations) and     exists (Weights) and not exists (Heights) then BmiObservation
    when     exists (BmiObservations) and not exists (Weights) and     exists (Heights) then BmiObservation
    when not exists (BmiObservations) and     exists (Weights) and     exists (Heights) then BmiCalc
    when not exists (BmiObservations) and not exists (Weights) and     exists (Heights) then null
    when not exists (BmiObservations) and     exists (Weights) and not exists (Heights) then null
    when     exists (BmiObservations) and not exists (Weights) and not exists (Heights) then BmiObservation
    else                                                                                     null
  end
    
// values for testing BMI logic only
//  |
// \ /
define BmiEqualsBmiCalc:
  BMI.value=BmiCalc.value
define BmiEqualsBmiObs:
  BMI.value=BmiObservation.value
// / \
//  |

define IsOverweight:
  if BMI is not null then 
    case
      // when IsAsian and BMI>=23.0 then true
      // "Data suggest that a BMI of 23 or greater may be an appropriate cut point in Asian American persons."
      when IsAsian and BMI>=23.0 'kg/m2' and BMI<30.0 'kg/m2' then true
      when not IsAsian and BMI>=25.0 'kg/m2' and BMI<30.0 'kg/m2' then true
      else false
    end
  else null

define IsObese: 
  if BMI is not null then 
    if BMI >= 30.0 'kg/m2' then true else false
  else null

define ScreeningTrigger:
  case 
    when IsObese then 'obese' 
    when IsOverweight then 'overweight'
    else null
  end

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

// 3 years is the interval suggested by the guideline. 
// Including this interval in the cql is a design decision.  
// If you are following a strictly literal interpretation of the USPSTF guideline 
// you could use a different interval or no interval. 
// "Prediabetes and type 2 diabetes can be detected by measuring fasting plasma glucose or HbA1c level, or with an oral glucose tolerance test. "
// "Cohort and modeling studies suggest that screening every 3 years may be a reasonable approach for adults with normal blood glucose levels."
define ScreenedWithinThreeYears:
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
        // Saving this in case: 
        // Combine(List{
        //   if Height is null then '- height' else null,
        //   if Weight is null then '- weight' else null
        // }, '\n')
        if (Height is null or Weight is null) and BmiObservation is null then 'Need height and weight or BMI' else null
      else null
  else null

define Recommendation: 
  if InAgeRange is true and 
    (IsOverweight or IsObese) is true and 
    NeedMoreInformation is null and
    ScreenedWithinThreeYears is null and
    IsExcluded is false 
    // "Prediabetes and type 2 diabetes can be detected by measuring fasting plasma glucose or HbA1c level, or with an oral glucose tolerance test. "
    then 'This patient is ' + ScreeningTrigger + '. ' + Gender + 
      ' should be screened for diabetes with a HbA1c, glucose tolerance test or fasting blood sugar.'
  else null

