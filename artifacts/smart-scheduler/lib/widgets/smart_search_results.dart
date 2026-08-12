import 'package:flutter/cupertino.dart';

import '../app_theme.dart';
import '../ai/search/search_service.dart';
import '../services/category_registry.dart';
import 'search_bar_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SmartSearchResultsSliver
//
// Sliver drop-in for the SliverFillRemaining(SearchNoResults()) placeholder in
// the grid, notes, and calendar search overlays.  When there are results it
// renders a padded SliverList of [_SearchEventTile]s; when empty it shows the
// standard SearchNoResults widget.
// ─────────────────────────────────────────────────────────────────────────────
class SmartSearchResultsSliver extends StatelessWidget {
  final List<SearchHit> hits;
  final String? suggestedQuery;
  final ValueChanged<String>? onSuggestionTap;

  const SmartSearchResultsSliver({
    super.key,
    required this.hits,
    this.suggestedQuery,
    this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (hits.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (suggestedQuery?.trim().isNotEmpty == true) ...[
                _SearchSuggestionBanner(
                  suggestion: suggestedQuery!,
                  onTap: onSuggestionTap,
                ),
                const SizedBox(height: 18),
              ],
              const SearchNoResults(),
            ],
          ),
        ),
      );
    }

    final hasSuggestion = suggestedQuery?.trim().isNotEmpty == true;
    return SliverPadding(
      // The banner has 8 px of its own top/bottom padding. Keep the outer
      // inset at 8 px too, so the visual gap above the suggestion matches the
      // gap from the suggestion to the first event tile.
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      sliver: SliverList.separated(
        itemCount: hits.length + (hasSuggestion ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          if (hasSuggestion && i == 0) {
            return _SearchSuggestionBanner(
              suggestion: suggestedQuery!,
              onTap: onSuggestionTap,
            );
          }
          final hitIndex = hasSuggestion ? i - 1 : i;
          return _SearchEventTile(hit: hits[hitIndex]);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SmartDcvSearchResults
//
// Widget used inside the DCV search overlay (Column layout).  Renders
// [primary] hits first (events inside the active category) and [overflow]
// below under an "Also found" section label.  Uses its own CustomScrollView so
// it respects rubber-band physics and keyboard overlap.
// ─────────────────────────────────────────────────────────────────────────────
class SmartDcvSearchResults extends StatelessWidget {
  final List<SearchHit> primary;
  final List<SearchHit> overflow;
  final String? suggestedQuery;
  final ValueChanged<String>? onSuggestionTap;
  final bool hidePrimaryCategoryName;

  const SmartDcvSearchResults({
    super.key,
    required this.primary,
    required this.overflow,
    this.suggestedQuery,
    this.onSuggestionTap,
    this.hidePrimaryCategoryName = false,
  });

  @override
  Widget build(BuildContext context) {
    if (primary.isEmpty && overflow.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (suggestedQuery?.trim().isNotEmpty == true) ...[
              _SearchSuggestionBanner(
                suggestion: suggestedQuery!,
                onTap: onSuggestionTap,
              ),
              const SizedBox(height: 18),
            ],
            const SearchNoResults(),
          ],
        ),
      );
    }

    return CustomScrollView(
      primary: false,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      slivers: [
        if (suggestedQuery?.trim().isNotEmpty == true)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _SearchSuggestionBanner(
                suggestion: suggestedQuery!,
                onTap: onSuggestionTap,
              ),
            ),
          ),
        if (primary.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverList.separated(
              itemCount: primary.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) => _SearchEventTile(
                hit: primary[i],
                showCategoryName: !hidePrimaryCategoryName,
              ),
            ),
          ),
        ],

        if (overflow.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                32,
                primary.isNotEmpty ? 20 : 16,
                32,
                8,
              ),
              child: Text(
                'ALSO FOUND',
                style: TextStyle(
                  inherit: false,
                  fontFamily: kSFProText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: resolveThemeColor(kSecondaryLabel, context),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList.separated(
              itemCount: overflow.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) => _SearchEventTile(hit: overflow[i]),
            ),
          ),
        ],

        if (primary.isNotEmpty && overflow.isEmpty)
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

class _SearchSuggestionBanner extends StatelessWidget {
  final String suggestion;
  final ValueChanged<String>? onTap;

  const _SearchSuggestionBanner({
    required this.suggestion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = resolveAccentColor(context);
    final secondary = resolveThemeColor(kSecondaryLabel, context);
    final content = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Did you mean ',
            style: TextStyle(
              inherit: false,
              color: secondary,
              fontSize: 15,
              fontFamily: kSFProText,
              fontWeight: FontWeight.w400,
              letterSpacing: kTracking16,
            ),
          ),
          TextSpan(
            text: '“$suggestion”',
            style: TextStyle(
              inherit: false,
              color: accent,
              fontSize: 15,
              fontFamily: kSFProText,
              fontWeight: FontWeight.w600,
              letterSpacing: kTracking16,
            ),
          ),
          TextSpan(
            text: '?',
            style: TextStyle(
              inherit: false,
              color: secondary,
              fontSize: 15,
              fontFamily: kSFProText,
              fontWeight: FontWeight.w400,
              letterSpacing: kTracking16,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null ? null : () => onTap!(suggestion),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: content,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SearchEventTile
//
// A single event result card. Matches the standalone event card used by the
// Events tab/DCV: same title, date, hour range, all-day and unscheduled state,
// location, padding, surface, and shadow. The category name is the only
// search-specific addition.
// ─────────────────────────────────────────────────────────────────────────────
class _SearchEventTile extends StatelessWidget {
  final SearchHit hit;
  final bool showCategoryName;

  const _SearchEventTile({
    required this.hit,
    this.showCategoryName = true,
  });

  static String _formatDate(String raw) {
    const months = {
      'January': '01',
      'February': '02',
      'March': '03',
      'April': '04',
      'May': '05',
      'June': '06',
      'July': '07',
      'August': '08',
      'September': '09',
      'October': '10',
      'November': '11',
      'December': '12',
    };
    final parts = raw.split(' ');
    if (parts.length < 3) return raw;
    final month = months[parts[0]];
    if (month == null) return raw;
    final day = parts[1].replaceAll(',', '').padLeft(2, '0');
    return '$month/$day/${parts[2]}';
  }

  String _subtitle() {
    final event = hit.event;
    final String? date;
    if (event.date == null || event.date!.isEmpty) {
      date = null;
    } else {
      final absolute = event.parsedDate?.absoluteDate;
      if (absolute != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final tomorrow = today.add(const Duration(days: 1));
        final eventDay = DateTime(absolute.year, absolute.month, absolute.day);
        if (eventDay == today) {
          date = 'Today';
        } else if (eventDay == tomorrow) {
          date = 'Tomorrow';
        } else {
          date = _formatDate(event.date!);
        }
      } else {
        date = _formatDate(event.date!);
      }
    }

    final String? time;
    if (event.isAllDay) {
      time = 'ALL-DAY';
    } else if (event.time != null && event.time!.isNotEmpty) {
      time = event.endTime != null && event.endTime!.isNotEmpty
          ? '${event.time!} - ${event.endTime!}'
          : event.time!;
    } else {
      time = null;
    }

    final parts = [if (date != null) date, if (time != null) time];
    return parts.isEmpty ? 'UNSCHEDULED' : parts.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    final event = hit.event;
    final meta = CategoryRegistry.get(event.categoryId);
    final catColor = meta != null
        ? renderCategoryColor(meta.rawColor, context)
        : resolveAccentColor(context);
    final secondaryLabel = resolveThemeColor(kSecondaryLabel, context);
    final sub = _subtitle();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: ShapeDecoration(
        color: resolveThemeColor(kSbSurface, context),
        shape: BoundedContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(kSbCornerRadius),
        ),
        shadows: resolveThemeShadows(kCardShadow, context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Category colour dot ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: catColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          // ── Text content ─────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(
                    inherit: false,
                    color: resolveThemeColor(kPrimaryLabel, context),
                    fontSize: 17,
                    fontFamily: kSFProText,
                    fontWeight: FontWeight.w400,
                    letterSpacing: kTracking16,
                  ),
                ),
                const SizedBox(height: 3),
                // Date / time subtitle
                Text(
                  sub.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    inherit: false,
                    color: secondaryLabel,
                    fontSize: 13,
                    fontFamily: kSFProText,
                    fontWeight: FontWeight.w400,
                    letterSpacing: kTracking16,
                  ),
                ),
                // Location
                if (event.location != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.location_fill,
                        size: 11,
                        color: secondaryLabel,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          event.location!.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            inherit: false,
                            color: secondaryLabel,
                            fontSize: 13,
                            fontFamily: kSFProText,
                            fontWeight: FontWeight.w400,
                            letterSpacing: kTracking16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                // Category name
                if (showCategoryName && meta != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    meta.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      inherit: false,
                      color: catColor,
                      fontSize: 12,
                      fontFamily: kSFProText,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

