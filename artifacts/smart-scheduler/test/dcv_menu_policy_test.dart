import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/dcv_menu_policy.dart';

void main() {
  test('utility categories do not show the view-mode menu item', () {
    expect(
      shouldShowDcvViewModeMenuItem(
        isUtilityCategory: true,
        isUserCreatedSmartCategory: false,
        hasSections: true,
        hasDatedSections: true,
      ),
      isFalse,
    );
  });

  test('user-created Smart Categories do not show the view-mode item', () {
    expect(
      shouldShowDcvViewModeMenuItem(
        isUtilityCategory: false,
        isUserCreatedSmartCategory: true,
        hasSections: false,
        hasDatedSections: true,
      ),
      isFalse,
    );
    expect(
      shouldShowDcvViewModeMenuItem(
        isUtilityCategory: false,
        isUserCreatedSmartCategory: true,
        hasSections: true,
        hasDatedSections: true,
      ),
      isFalse,
    );
  });

  test('categories without sections omit the view-mode item', () {
    expect(
      shouldShowDcvViewModeMenuItem(
        isUtilityCategory: false,
        isUserCreatedSmartCategory: false,
        hasSections: false,
        hasDatedSections: false,
      ),
      isFalse,
    );
  });

  test('categories with sections retain the view-mode item', () {
    expect(
      shouldShowDcvViewModeMenuItem(
        isUtilityCategory: false,
        isUserCreatedSmartCategory: false,
        hasSections: true,
        hasDatedSections: false,
      ),
      isTrue,
    );
  });

  test('built-in Smart Categories show view mode for dated sections', () {
    expect(
      shouldShowDcvViewModeMenuItem(
        isUtilityCategory: false,
        isUserCreatedSmartCategory: false,
        hasSections: false,
        hasDatedSections: true,
      ),
      isTrue,
    );
  });
}
