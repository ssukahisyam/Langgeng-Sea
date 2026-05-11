/// WCAG 2.1 contrast-ratio helpers used to validate polyline colours
/// against map tile backgrounds.
///
/// Requirements 3.1, 3.2, 3.6 ask for a minimum 4.5:1 contrast ratio
/// between the polyline stroke and the underlying OSM tile across both
/// light and dark themes. These pure helpers make that a testable
/// numeric invariant.
///
/// Kept in [dart:ui] space (rather than importing `package:flutter`)
/// so the utility stays cheap to pull into non-widget code — and its
/// property tests don't need the Flutter binding.
library;

import 'dart:math' as math;
import 'dart:ui' show Color;

/// Relative luminance of [c] per the WCAG 2.1 definition
/// (https://www.w3.org/TR/WCAG21/#dfn-relative-luminance):
///
///   L = 0.2126 * R' + 0.7152 * G' + 0.0722 * B'
///
/// where each linearised channel `C'` is derived from the sRGB channel
/// `C ∈ [0, 1]`:
///
///   C' = C / 12.92                 if C <= 0.03928
///   C' = ((C + 0.055) / 1.055)^2.4 otherwise
///
/// Input channels come from `Color.r/.g/.b`, which already return
/// doubles in `[0, 1]` on Flutter 3.27+. The alpha channel is
/// intentionally ignored: this helper assumes the caller has already
/// composited any translucent colour against its background (alpha
/// blending is context-dependent and therefore the caller's concern).
double relativeLuminance(Color c) {
  final r = _linearise(c.r);
  final g = _linearise(c.g);
  final b = _linearise(c.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// WCAG 2.1 contrast ratio between two opaque colours [a] and [b].
///
/// Returns `(L1 + 0.05) / (L2 + 0.05)` where `L1 = max(L_a, L_b)` and
/// `L2 = min(L_a, L_b)`, so the result is always `>= 1.0` regardless
/// of argument order. The canonical black-vs-white pair yields `21.0`;
/// any colour vs itself yields `1.0`.
///
/// As with [relativeLuminance], the alpha channel is ignored. Callers
/// that need to evaluate a semi-transparent stroke against a tile
/// should pre-composite the stroke onto the tile colour themselves.
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final l1 = la >= lb ? la : lb;
  final l2 = la >= lb ? lb : la;
  return (l1 + 0.05) / (l2 + 0.05);
}

/// Convert a single sRGB channel in `[0, 1]` to its linear-light form
/// using the piecewise WCAG 2.1 transfer function. Clamps the input to
/// defend against floating-point jitter at the extremes (e.g. channels
/// nudged slightly above 1.0 by prior compositing maths).
double _linearise(double channel) {
  final v = channel.clamp(0.0, 1.0);
  if (v <= 0.03928) return v / 12.92;
  return math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}
