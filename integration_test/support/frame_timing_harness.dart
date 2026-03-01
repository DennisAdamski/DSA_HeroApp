import 'dart:ui';

import 'package:flutter/widgets.dart';

class FrameTimingHarness {
  final List<FrameTiming> _timings = <FrameTiming>[];
  bool _recording = false;

  int get sampleCount => _timings.length;

  void start() {
    if (_recording) {
      return;
    }
    _recording = true;
    WidgetsBinding.instance.addTimingsCallback(_onTimings);
  }

  void stop() {
    if (!_recording) {
      return;
    }
    _recording = false;
    WidgetsBinding.instance.removeTimingsCallback(_onTimings);
  }

  void reset() {
    _timings.clear();
  }

  int percentileBuildMicros(double percentile) {
    if (_timings.isEmpty) {
      return 0;
    }
    final buildTimes =
        _timings
            .map((timing) => timing.buildDuration.inMicroseconds)
            .toList(growable: false)
          ..sort();
    final normalized = percentile.clamp(0, 100) / 100.0;
    final index = ((buildTimes.length - 1) * normalized).round();
    return buildTimes[index];
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!_recording || timings.isEmpty) {
      return;
    }
    _timings.addAll(timings);
  }
}
