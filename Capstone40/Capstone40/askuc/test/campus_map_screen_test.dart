import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:askuc/features/navigation/campus_map_screen.dart';
import 'package:askuc/features/navigation/pathway_tree.dart';
import 'package:askuc/widgets/tilted_campus_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CampusGraph graph;
  late PathwayTree pathways;

  setUpAll(() async {
    graph = await CampusGraph.loadAsset('assets/campus_graph.json');
    final byId = {for (final n in graph.nodes) n.id: n};
    pathways = PathwayTree.build(graph.nodes.map((n) => n.id), [
      for (final e in graph.edges)
        PathwayEdge(
          e.from,
          e.to,
          (Offset(byId[e.from]!.x, byId[e.from]!.y) -
                  Offset(byId[e.to]!.x, byId[e.to]!.y))
              .distance,
        ),
    ]);
  });

  MapNode named(String name) => graph.nodes.firstWhere((n) => n.name == name);

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
            ],
            pathways: pathways,
            onRouteShown: (from, to) => shown.add('${from.name} -> ${to.name}'),
          ),
        ),
      );

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
  });
}
