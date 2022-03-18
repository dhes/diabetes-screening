function expectOK(testCase) {
  return true;
}

function expectCards(testCase) {
  if (testCase.expected != null) {
    return (
      testCase.expected.NeedMoreInformation != null ||
      testCase.expected.Recommendation != null 
    );
  }
}

function expectCardsContent(testCase) {
  if (expectCards(testCase)) {
    const cardArray = [];
    if (testCase.expected.Recommendation != null) {
      cardArray.push({
        summary: "Prediabetes and Type 2 Diabetes: Screening",
        indicator: "info",
        detail: testCase.expected.Recommendation,
        source: {
          label:
            "Prediabetes and Type 2 Diabetes: Screening",
          url: "https://uspreventiveservicestaskforce.org/uspstf/recommendation/screening-for-prediabetes-and-type-2-diabetes",
        },
      });
    }
    if (testCase.expected.NeedMoreInformation != null) {
      cardArray.push({
        summary: "More information needed to complete diabetes screening assessment",
        indicator: "warning",
        detail: testCase.expected.NeedMoreInformation,
        source: {
          label:
            "Prediabetes and Type 2 Diabetes: Screening",
          url: "https://uspreventiveservicestaskforce.org/uspstf/recommendation/screening-for-prediabetes-and-type-2-diabetes",
        },
      });
    }
    return cardArray;
  }
}

module.exports = { expectOK, expectCards, expectCardsContent };
