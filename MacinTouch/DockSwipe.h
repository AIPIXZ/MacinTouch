#ifndef MACINTOUCH_DOCK_SWIPE_H
#define MACINTOUCH_DOCK_SWIPE_H
#include <CoreGraphics/CoreGraphics.h>
// Caller owns the returned event. macOS 27 private HID layout.
// phase: 1 began, 2 changed, 4 ended, 8 cancelled; progress is cumulative.
CGEventRef MacinTouchCreateDockSwipeEvent(int phase, double progress, double velocity);
// motion: 1 horizontal, 2 vertical, 3 pinch (positive spread, negative pinch).
CGEventRef MacinTouchCreateDockGestureEvent(int motion, int phase, double progress, double velocity);
// System-built IOHIDEvent backend, validated for macOS 27 pinch gestures.
CGEventRef MacinTouchCreateNativeDockGestureEvent(int motion, int phase, double progress, double velocity);
#endif
