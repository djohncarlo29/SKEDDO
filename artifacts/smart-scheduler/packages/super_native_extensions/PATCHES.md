# Local patch

Based on `super_native_extensions` 0.9.1.

- Android drop items with a URI also advertise `text/uri-list`, even when the
  content provider advertises MIME types such as `image/jpeg` instead. This
  lets the app resolve the URI's real `OpenableColumns.DISPLAY_NAME` instead
  of showing the generic attachment label.