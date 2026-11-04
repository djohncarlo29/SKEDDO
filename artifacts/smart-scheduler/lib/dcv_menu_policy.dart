bool shouldShowDcvViewModeMenuItem({
  required bool isUtilityCategory,
  required bool isUserCreatedSmartCategory,
  required bool hasSections,
  bool hasDatedSections = false,
}) {
  return !isUtilityCategory &&
      !isUserCreatedSmartCategory &&
      (hasSections || hasDatedSections);
}
