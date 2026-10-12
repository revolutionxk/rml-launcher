import 'package:rml_launcher/core/platform/window_chrome.dart';

final class FakeWindowChrome implements WindowChrome {
  int drags = 0;
  int minimizes = 0;
  int maximizes = 0;
  int closes = 0;

  @override
  Future<void> startDragging() async => drags++;

  @override
  Future<void> minimize() async => minimizes++;

  @override
  Future<void> toggleMaximize() async => maximizes++;

  @override
  Future<void> close() async => closes++;
}
