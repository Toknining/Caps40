import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:askuc/widgets/tilted_campus_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CampusGraph graph;

  setUpAll(() async {
    graph = await CampusGraph.loadAsset('assets/campus_graph.json');
  });

  Future<CampusMapController> pumpMap(WidgetTester tester) async {
    final controller = CampusMapController();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 360,
            height: 320,
            child: TiltedCampusMap(
              graph: graph,
              controller: controller,
              plans: const [
                FloorPlan(
                  floor: 5,
                  asset: 'assets/floorplans/Main_5ft_Floor_CSS.png',
                  width: 1216,
                  height: 864,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return controller;
  }

  /// Two fingers on either side of the map's centre, at [from] and [to]
  /// pixels apart and turned [turn] radians by the end.
  Future<void> twoFingers(
    WidgetTester tester, {
    required double from,
    required double to,
    double turn = 0,
  }) async {
    final c = tester.getCenter(find.byType(TiltedCampusMap));
    Offset at(double spread, double angle) =>
        Offset(math.cos(angle), math.sin(angle)) * spread / 2;

    final a = await tester.startGesture(c - at(from, 0), pointer: 1);
    final b = await tester.startGesture(c + at(from, 0), pointer: 2);
    for (var i = 1; i <= 12; i++) {
      final t = i / 12;
      final spread = from + (to - from) * t;
      await a.moveTo(c - at(spread, turn * t));
      await b.moveTo(c + at(spread, turn * t));
      await tester.pump();
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
  }

  testWidgets('zooming out stops with the whole map in view', (tester) async {
    final map = await pumpMap(tester);
    final size = tester.getSize(find.byType(TiltedCampusMap));

    await twoFingers(tester, from: 300, to: 20);
    final limit = map.zoom;
    for (final n in graph.nodes) {
      final p = map.positionOf(n.id)!;
      expect(p.dx, inInclusiveRange(0, size.width), reason: n.name);
      expect(p.dy, inInclusiveRange(0, size.height), reason: n.name);
    }

    await twoFingers(tester, from: 300, to: 20);
    expect(map.zoom, closeTo(limit, 1e-9));

    await twoFingers(tester, from: 40, to: 300);
    expect(map.zoom, greaterThan(limit * 3));
  });

  testWidgets('two fingers turn the map; the controller turns it back', (
    tester,
  ) async {
    final map = await pumpMap(tester);
    final before = map.rotation;

    await twoFingers(tester, from: 200, to: 200, turn: 0.6);
    // The map turns with the fingers, minus the first bit of twist, which is
    // ignored so ordinary pinches don't turn it.
    expect(map.rotation - before, inInclusiveRange(0.2, 0.45));

    map.resetRotation();
    await tester.pumpAndSettle();
    final off = (map.rotation - before) % (2 * math.pi);
    expect(math.min(off, 2 * math.pi - off), lessThan(1e-6));
  });

  testWidgets('a pinch without a twist keeps the angle', (tester) async {
    final map = await pumpMap(tester);
    final before = map.rotation;

    await twoFingers(tester, from: 100, to: 260, turn: 0.1);
    expect(map.rotation, before);
  });
}
