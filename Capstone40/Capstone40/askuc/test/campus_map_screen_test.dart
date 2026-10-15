import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:askuc/features/navigation/campus_map_screen.dart';
import 'package:askuc/features/navigation/pathway_tree.dart';
import 'package:askuc/widgets/tilted_campus_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CampusGraph graph;
  late FloorPathways pathways;

  setUpAll(() async {
    graph = await CampusGraph.loadAsset('assets/campus_graph.json');
    pathways = FloorPathways.build(
      [for (final n in graph.nodes) (id: n.id, floor: n.floor, x: n.x, y: n.y)],
      [for (final e in graph.edges) (e.from, e.to)],
      floorChangeCost: 150,
    );
  });

  MapNode named(String name) => graph.nodes.firstWhere((n) => n.name == name);

  TiltedCampusMap mapIn(WidgetTester tester) =>
      tester.widget<TiltedCampusMap>(find.byType(TiltedCampusMap));

  Future<List<String>> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final shown = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: CampusMapScreen(
          graph: graph,
          plans: const [
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
          ],
          pathways: pathways,
          onRouteShown: (from, to) => shown.add('${from.name} -> ${to.name}'),
        ),
      ),
    );
    return shown;
  }

  /// Opens a field's list, searches it, and picks [place].
  Future<void> choose(
    WidgetTester tester,
    String field,
    String search,
    String place,
  ) async {
    await tester.tap(
      find.ancestor(of: find.text(field), matching: find.byType(InkWell)).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), search);
    await tester.pump();
    await tester.tap(find.text(place));
    await tester.pumpAndSettle();
  }

  group('CampusMapScreen', () {
    testWidgets('Generate route shows the pathway and glides to the start', (
      tester,
    ) async {
      final shown = await pumpScreen(tester);
      expect(mapIn(tester).focusedFloor, 5); // starts on the lowest floor

      await tester.tap(find.text('GENERATE ROUTE'));
      await tester.pump();
      expect(find.text('Please choose a starting point.'), findsOneWidget);
      expect(find.text('Please choose a destination.'), findsOneWidget);

      await choose(tester, 'Select starting point', 'dean', 'CICS Dean Office');
      expect(find.text('Please choose a starting point.'), findsNothing);
      await choose(tester, 'Select destination', '544', 'CICS Cisco Lab 544');
      await tester.tap(find.text('GENERATE ROUTE'));
      await tester.pumpAndSettle();

      final dean = named('CICS Dean Office');
      final room = named('CICS Cisco Lab 544');
      var map = tester.widget<TiltedCampusMap>(find.byType(TiltedCampusMap));
      expect(map.routeIds, pathways.route(dean.id, room.id));
      expect(map.originId, dean.id);
      expect(map.destinationId, room.id);
      expect(shown, ['CICS Dean Office -> CICS Cisco Lab 544']);

      // The map glided to the starting point, now in the middle of the map.
      final middle = tester
          .getSize(find.byType(TiltedCampusMap))
          .center(Offset.zero);
      final start = map.controller!.positionOf(dean.id)!;
      expect((start - middle).distance, lessThan(1));

      // Picking a new destination clears the old pathway until it is
      // generated again.
      await choose(
        tester,
        'CICS Cisco Lab 544',
        '530',
        'CICS Computer lab 530',
      );
      map = tester.widget<TiltedCampusMap>(find.byType(TiltedCampusMap));
      expect(map.routeIds, isEmpty);
      expect(map.destinationId, named('CICS Computer lab 530').id);
    });

    testWidgets('a route to another floor says which stairs to take', (
      tester,
    ) async {
      await pumpScreen(tester);
      await choose(tester, 'Select starting point', 'dean', 'CICS Dean Office');
      await choose(tester, 'Select destination', '734', 'Physics Lab 734');
      await tester.tap(find.text('GENERATE ROUTE'));
      await tester.pumpAndSettle();

      final dean = named('CICS Dean Office');
      final lab = named('Physics Lab 734');
      final route = [
        for (final id in pathways.route(dean.id, lab.id)) graph.byId(id)!,
      ];
      final change = floorChanges(route).first;
      expect(mapIn(tester).focusedFloor, 5);

      // The hint names the stairs and the floor where the walk carries on;
      // tapping it shows that floor where the route arrives.
      final hint = find.textContaining('to ${change.to.floor}F');
      expect(hint, findsOneWidget);
      await tester.tap(hint);
      await tester.pumpAndSettle();

      final map = mapIn(tester);
      expect(map.focusedFloor, change.to.floor);
      final size = tester.getSize(find.byType(TiltedCampusMap));
      final arrival = map.controller!.positionOf(change.to.id)!;
      expect((Offset.zero & size).deflate(20).contains(arrival), isTrue);
    });
  });
}
