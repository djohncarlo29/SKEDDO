package io.flutter.plugin.platform;

import android.app.Activity;
import androidx.annotation.NonNull;
import io.flutter.embedding.engine.systemchannels.PlatformChannel;

/**
 * Keeps Flutter's repeated Android selection-click feedback from firing while
 * a text-selection handle is held, without changing other haptic feedback.
 */
public final class SelectionQuietPlatformPlugin extends PlatformPlugin {
  private static volatile boolean selectionHandleDragging;

  public SelectionQuietPlatformPlugin(
      @NonNull Activity activity,
      @NonNull PlatformChannel platformChannel,
      @NonNull PlatformPluginDelegate delegate) {
    super(activity, platformChannel, delegate);
  }

  public static void setSelectionHandleDragging(boolean dragging) {
    selectionHandleDragging = dragging;
  }

  @Override
  public void vibrateHapticFeedback(
      @NonNull PlatformChannel.HapticFeedbackType feedbackType) {
    if (selectionHandleDragging
        && feedbackType == PlatformChannel.HapticFeedbackType.SELECTION_CLICK) {
      return;
    }
    super.vibrateHapticFeedback(feedbackType);
  }
}