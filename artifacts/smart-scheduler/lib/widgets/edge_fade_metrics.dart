/// The scroll state needed by an edge-fade overlay when the scrollable is
/// owned by a platform view rather than Flutter's Scrollable tree.
class EdgeFadeMetrics {
  final double pixels;
  final double minScrollExtent;
  final double maxScrollExtent;
  final double extentBefore;
  final double extentAfter;

  const EdgeFadeMetrics({
    required this.pixels,
    required this.minScrollExtent,
    required this.maxScrollExtent,
    required this.extentBefore,
    required this.extentAfter,
  });
}