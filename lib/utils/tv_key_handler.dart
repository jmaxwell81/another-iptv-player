import 'package:flutter/services.dart';

/// D-pad key event handling utilities for Android TV remote control.
/// Supports standard Android TV remotes and Amazon Fire TV remotes.
class TvKeyHandler {
  TvKeyHandler._();

  // D-pad key codes
  static const int keyCodeDpadUp = 19;
  static const int keyCodeDpadDown = 20;
  static const int keyCodeDpadLeft = 21;
  static const int keyCodeDpadRight = 22;
  static const int keyCodeDpadCenter = 23;
  static const int keyCodeEnter = 66;
  static const int keyCodeBack = 4;

  // Media key codes
  static const int keyCodeMediaPlayPause = 85;
  static const int keyCodeMediaPlay = 126;
  static const int keyCodeMediaPause = 127;
  static const int keyCodeMediaRewind = 89;
  static const int keyCodeMediaFastForward = 90;
  static const int keyCodeMediaNext = 87;
  static const int keyCodeMediaPrevious = 88;
  static const int keyCodeMediaSkipForward = 272;
  static const int keyCodeMediaSkipBackward = 273;
  static const int keyCodeMediaStepForward = 274;
  static const int keyCodeMediaStepBackward = 275;

  // Amazon Fire TV specific key codes
  static const int keyCodeMenu = 82;
  static const int keyCodeSearch = 84;

  /// Check if the key event is a D-pad navigation key
  static bool isDpadNavigationKey(KeyEvent event) {
    final keyCode = event.logicalKey.keyId;
    return keyCode == LogicalKeyboardKey.arrowUp.keyId ||
        keyCode == LogicalKeyboardKey.arrowDown.keyId ||
        keyCode == LogicalKeyboardKey.arrowLeft.keyId ||
        keyCode == LogicalKeyboardKey.arrowRight.keyId;
  }

  /// Check if the key event is a selection key (Enter/Select)
  static bool isSelectKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA;
  }

  /// Check if the key event is a back key
  static bool isBackKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack ||
        event.logicalKey == LogicalKeyboardKey.browserBack;
  }

  /// Check if the key event is a play/pause key
  static bool isPlayPauseKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.mediaPlayPause ||
        event.logicalKey == LogicalKeyboardKey.mediaPlay ||
        event.logicalKey == LogicalKeyboardKey.mediaPause ||
        event.logicalKey == LogicalKeyboardKey.space;
  }

  /// Check if the key event is a rewind key
  static bool isRewindKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.mediaRewind;
  }

  /// Check if the key event is a fast forward key
  static bool isFastForwardKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.mediaFastForward;
  }

  /// Check if the key event is a next track/episode key (Amazon wheel forward)
  static bool isNextTrackKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.mediaTrackNext ||
        event.logicalKey == LogicalKeyboardKey.channelUp ||
        event.logicalKey == LogicalKeyboardKey.mediaSkipForward;
  }

  /// Check if the key event is a previous track/episode key (Amazon wheel backward)
  static bool isPreviousTrackKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.mediaTrackPrevious ||
        event.logicalKey == LogicalKeyboardKey.channelDown ||
        event.logicalKey == LogicalKeyboardKey.mediaSkipBackward;
  }

  /// Check if the key event is a menu key (for showing options/info)
  static bool isMenuKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.contextMenu ||
        event.logicalKey == LogicalKeyboardKey.f1 ||
        event.logicalKey == LogicalKeyboardKey.info;
  }

  /// Get the navigation direction from a key event
  static TvNavigationDirection? getNavigationDirection(KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      return TvNavigationDirection.up;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      return TvNavigationDirection.down;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      return TvNavigationDirection.left;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      return TvNavigationDirection.right;
    }
    return null;
  }

  /// Check if the key event is a key down event
  static bool isKeyDown(KeyEvent event) {
    return event is KeyDownEvent;
  }

  /// Check if the key event is a key up event
  static bool isKeyUp(KeyEvent event) {
    return event is KeyUpEvent;
  }
}

/// Navigation direction for D-pad
enum TvNavigationDirection {
  up,
  down,
  left,
  right,
}
