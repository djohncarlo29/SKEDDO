/// The AppShell reserves keyboard space for DCV section editing.
///
/// The DCV search-results viewport owns its own keyboard inset, so the shell
/// must not reserve the same space while that search field is focused.
double dcvKeyboardContentBottomInset({
  required bool hasActiveDcv,
  required bool searchFocused,
  required double keyboardBottomInset,
}) {
  if (!hasActiveDcv || searchFocused) return 0.0;
  return keyboardBottomInset;
}
