import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:askuc/widgets/tilted_campus_map.dart';

const _plans = [
  FloorPlan(
    floor: 5,
    asset: 'assets/floorplans/Main_5ft_Floor_CSS.png',
    width: 1216,
    height: 864,
  ),
  FloorPlan(
    floor: 6,
    asset: 'assets/floorplans/Main_6F_Floor.png',
    width: 1216,
    height: 864,
  ),
  FloorPlan(
    floor: 7,
    asset: 'assets/floorplans/Main_7ft_Floor.png',
    width: 1184,
    height: 896,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CampusGraph graph;

  setUpAll(() async {
    graph = await CampusGraph.loadAsset('assets/campus_graph.json');
  });

  /// Pumps the map showing [floor] (every floor when null). Pumping again
  /// with the same [controller] updates the same map.
  Future<CampusMapController> pumpMap(
    WidgetTester tester, {
    int? floor = 5,
    CampusMapController? controller,
  }) async {
    final map = controller ?? CampusMapController();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 360,
            height: 320,
            child: TiltedCampusMap(
              graph: graph,
              controller: map,
              plans: _plans,
              focusedFloor: floor,
            ),
          ),
        ),
      ),
    );
    return map;
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

  void expectAllInView(
    WidgetTester tester,
    CampusMapController map,
    Iterable<MapNode> nodes,
  ) {
    final size = tester.getSize(find.byType(TiltedCampusMap));
    for (final n in nodes) {
      final p = map.positionOf(n.id)!;
      expect(p.dx, inInclusiveRange(0, size.width), reason: n.name);
      expect(p.dy, inInclusiveRange(0, size.height), reason: n.name);
    }
  }

  MapNode named(String name) => graph.nodes.firstWhere((n) => n.name == name);

  testWidgets('zooming out stops with the whole floor in view', (tester) async {
    final map = await pumpMap(tester);

    await twoFingers(tester, from: 300, to: 20);
    final limit = map.zoom;
    expectAllInView(tester, map, graph.nodes.where((n) => n.floor == 5));

    await twoFingers(tester, from: 300, to: 20);
    expect(map.zoom, closeTo(limit, 1e-9));

    await twoFingers(tester, from: 40, to: 300);
    expect(map.zoom, greaterThan(limit * 3));
  });

  testWidgets('every floor at once zooms out to the whole building', (
    tester,
  ) async {
    final map = await pumpMap(tester, floor: null);

    await twoFingers(tester, from: 300, to: 20);
    expectAllInView(tester, map, graph.nodes);
  });

  testWidgets('switching floors keeps the same spot in view', (tester) async {
    final map = await pumpMap(tester);
    map.centerOn(named('5F Stairs 6 Near Gate 4').id, zoom: 1.3);
    await tester.pumpAndSettle();

    await pumpMap(tester, floor: 6, controller: map);
    await tester.pumpAndSettle();
    // The same stairs, one floor up, drawn a few plan pixels apart.
    final middle = tester
        .getSize(find.byType(TiltedCampusMap))
        .center(Offset.zero);
    final stairs = map.positionOf(named('6F Stairs 6 Near Gate 4').id)!;
    expect((stairs - middle).distance, lessThan(10));
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

  test('floorChanges skips floors passed inside the stairwell', () {
    MapNode at(String id, int floor, [String kind = 'hall']) =>
        MapNode(id: id, name: id, floor: floor, x: 0, y: 0, kind: kind);
    final route = [
      at('room', 5, 'classroom'),
      at('s5', 5, 'stairs'),
      at('s6', 6, 'stairs'),
      at('s7', 7, 'stairs'),
      at('hall', 7),
      at('lab', 7, 'lab'),
    ];

    final changes = floorChanges(route);
    expect(changes, hasLength(1));
    expect(changes.single.from.id, 's5');
    expect(changes.single.to.id, 's7');
  });
}
