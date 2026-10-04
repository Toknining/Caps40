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

  group('CampusMapScreen', () {
    testWidgets('Directions shows the pathway and reports it once', (
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
                asset: 'assets/floorplans/floor_5.png',
                width: 1800,
                height: 1309,
              ),
            ],
            pathways: pathways,
            onRouteShown: (from, to) => shown.add('${from.name} -> ${to.name}'),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '544');
      await tester.pump();
      await tester.tap(find.text('Room 544'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Directions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text("CICS Dean's Office 531"));
      await tester.pumpAndSettle();

      final dean = graph.nodes.firstWhere(
        (n) => n.name == "CICS Dean's Office 531",
      );
      final room = graph.nodes.firstWhere((n) => n.name == 'Room 544');
      var map = tester.widget<TiltedCampusMap>(find.byType(TiltedCampusMap));
      expect(map.routeIds, pathways.route(dean.id, room.id));
      expect(map.originId, dean.id);
      expect(map.destinationId, room.id);
      expect(shown, ["CICS Dean's Office 531 -> Room 544"]);

      await tester.tap(find.byTooltip('Clear directions'));
      await tester.pumpAndSettle();

      map = tester.widget<TiltedCampusMap>(find.byType(TiltedCampusMap));
      expect(map.routeIds, isEmpty);
      expect(find.text('Directions'), findsOneWidget);
    });
  });
}
