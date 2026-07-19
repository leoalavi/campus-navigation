import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True while an in-shell immersive viewer (a 360° panorama backed by an
/// `InAppWebView` platform view) is on screen.
///
/// `AppShell` reads it to force its floating tab-bar glass onto the frost path:
/// a shader `BackdropFilter` cannot sample platform-view pixels, so the shader
/// would render flat/broken over the panorama. The immersive page is the sole
/// writer (true while mounted, false on dispose).
class ImmersiveViewerActiveNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setActive(bool active) {
    if (state != active) state = active;
  }
}

final immersiveViewerActiveProvider =
    NotifierProvider<ImmersiveViewerActiveNotifier, bool>(
      ImmersiveViewerActiveNotifier.new,
    );
