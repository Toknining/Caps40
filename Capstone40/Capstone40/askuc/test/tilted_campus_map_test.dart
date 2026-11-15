import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:askuc/widgets/tilted_campus_map.dart';

const _plans = [
  FloorPlan(
    floor: 3,
    asset: 'assets/floorplans/Main_3_Floor_transparent.png',
    width: 1184,
    height: 896,
  ),
  FloorPlan(
    floor: 4,
    asset: 'assets/floorplans/Main_4ft_Floor_transparent.png',
    width: 2560,
    height: 1903,
  ),
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

  late CampusGraph raw;
  late CampusGraph graph;
  late List<FloorPlan> plans;

  setUpAll(() async {
    raw = await CampusGraph.loadAsset('assets/campus_graph.json');
    // The floors lined up by their stairs, as the app loads them.
    (graph: graph, plans: plans) = raw.alignFloors(_plans);
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
              plans: plans,
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

  test('alignFloors lines a floor up by its stairs', () {
    // Floor 2's plan was drawn twice as big and shifted by (10, 20).
    MapNode at(String id, int floor, double x, double y) =>
        MapNode(id: id, name: id, floor: floor, x: x, y: y, kind: 'stairs');
    final campus = CampusGraph(
      nodes: [
        at('a1', 1, 0, 0), at('b1', 1, 100, 0), at('c1', 1, 0, 100), //
        at('a2', 2, 10, 20), at('b2', 2, 210, 20), at('c2', 2, 10, 220),
      ],
      edges: const [
        MapEdge(from: 'a1', to: 'a2'),
        MapEdge(from: 'b1', to: 'b2'),
        MapEdge(from: 'c1', to: 'c2'),
      ],
    );
    const floorPlans = [
      FloorPlan(floor: 1, asset: 'one.png', width: 100, height: 100),
      FloorPlan(floor: 2, asset: 'two.png', width: 200, height: 200),
    ];

    final (graph: lined, plans: placed) = campus.alignFloors(floorPlans);

    for (final (one, two) in [('a1', 'a2'), ('b1', 'b2'), ('c1', 'c2')]) {
      final p = lined.byId(one)!, q = lined.byId(two)!;
      expect(q.x, closeTo(p.x, 1e-9));
      expect(q.y, closeTo(p.y, 1e-9));
    }
    expect(placed.first.scale, 1); // floor 1 stays put on a tie
    expect(placed.last.scale, closeTo(0.5, 1e-9));
    expect(placed.last.place(const Offset(210, 20)).dx, closeTo(100, 1e-9));
  });

  test('every real floor lines up with the floors next to it', () {
    final byId = {for (final n in graph.nodes) n.id: n};
    final apart = <String>[];
    for (final e in graph.edges) {
      final a = byId[e.from]!, b = byId[e.to]!;
      if (a.floor == b.floor) continue;
      // Each floor's nodes were placed by hand, so the same stairs land a
      // little apart; a floor out of line would be hundreds of px off.
      final d = (Offset(a.x, a.y) - Offset(b.x, b.y)).distance;
      if (d > 50) apart.add('${a.name} -> ${b.name}: ${d.round()} px');
    }

    expect(apart, isEmpty);
    FloorPlan plan(int floor) => plans.firstWhere((p) => p.floor == floor);
    // 5F, drawn at the middle size, stays put, though 4F has more stairs.
    expect((plan(5).scale, plan(5).offset), (1, Offset.zero));
    // 4F's plan image was drawn about 2.3 times as big as the others.
    expect(plan(4).scale, closeTo(0.44, 0.01));
    expect(plan(3).scale, closeTo(1, 0.05));
  });
}
