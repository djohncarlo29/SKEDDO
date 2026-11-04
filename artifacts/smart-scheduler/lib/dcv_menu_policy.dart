bool shouldShowDcvViewModeMenuItem({
  required bool isUtilityCategory,
  required bool isUserCreatedSmartCategory,
  required bool hasSections,
}) {
  return !isUtilityCategory && !isUserCreatedSmartCategory && hasSections;
}
