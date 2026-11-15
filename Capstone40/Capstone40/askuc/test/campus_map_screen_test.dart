import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:askuc/features/navigation/campus_map_screen.dart';
import 'package:askuc/features/navigation/pathway_tree.dart';
import 'package:askuc/widgets/tilted_campus_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CampusGraph graph;
  late FloorPathways pathways;

  /// The app's pathways with the [closed] stairs and elevator stops.
  FloorPathways pathwaysWith(Set<String> closed) => FloorPathways.build(
    [for (final n in graph.nodes) (id: n.id, floor: n.floor, x: n.x, y: n.y)],
    [for (final e in graph.edges) (e.from, e.to)],
    floorChangeCost: 150,
    closed: closed,
  );

  setUpAll(() async {
    graph = await CampusGraph.loadAsset('assets/campus_graph.json');
    pathways = pathwaysWith(const {});
  });

  MapNode named(String name) => graph.nodes.firstWhere((n) => n.name == name);

  TiltedCampusMap mapIn(WidgetTester tester) =>
      tester.widget<TiltedCampusMap>(find.byType(TiltedCampusMap));

  /// Pumps the screen; pumping again with other [closed] stops or doors
  /// updates the same screen, the way the Map tab does when an admin closes
  /// one. [reasons] are what the admin wrote, by id.
  Future<List<String>> pumpScreen(
    WidgetTester tester, {
    Set<String> closed = const {},
    Map<String, String> reasons = const {},
  }) async {
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
          pathways: closed.isEmpty ? pathways : pathwaysWith(closed),
          closedIds: closed,
          closureReasons: reasons,
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

    testWidgets('a pathway on show moves off stairs that close', (
      tester,
    ) async {
      await pumpScreen(tester);
      await choose(tester, 'Select starting point', 'dean', 'CICS Dean Office');
      await choose(tester, 'Select destination', '734', 'Physics Lab 734');
      await tester.tap(find.text('GENERATE ROUTE'));
      await tester.pumpAndSettle();

      final dean = named('CICS Dean Office');
      final lab = named('Physics Lab 734');
      final before = [for (final id in mapIn(tester).routeIds) graph.byId(id)!];
      // Close the stops the pathway rides between, as an admin would.
      final closed = {
        for (final change in floorChanges(before)) ...[
          change.from.id,
          change.to.id,
        ],
      };
      final shown = await pumpScreen(tester, closed: closed);
      await tester.pumpAndSettle();

      final after = mapIn(tester).routeIds;
      expect(after, pathwaysWith(closed).route(dean.id, lab.id));
      expect(after, isNotEmpty);
      expect(after, isNot(before.map((n) => n.id).toList()));
      expect(mapIn(tester).closedIds, closed);
      // The first closed stop the old pathway reached is named.
      expect(
        find.text(
          '${floorChanges(before).first.from.name} on your pathway closed. '
          'Showing another pathway.',
        ),
        findsOneWidget,
      );
      expect(shown, isEmpty); // a redone pathway isn't a new search
    });

    testWidgets('a closed door says why a place is out of reach', (
      tester,
    ) async {
      final door = named('Door Library');
      await pumpScreen(
        tester,
        closed: {door.id},
        reasons: {door.id: "Use the library's 3F entrance"},
      );
      await choose(tester, 'Select starting point', '422', 'Room 422');
      await choose(tester, 'Select destination', 'main lib', 'Main Library');
      await tester.tap(find.text('GENERATE ROUTE'));
      await tester.pump();

      expect(
        find.text(
          "No open pathway right now: Door Library is closed. Use the "
          "library's 3F entrance.",
        ),
        findsOneWidget,
      );
      expect(mapIn(tester).routeIds, isEmpty);
    });

    testWidgets('closed places are listed but cannot be picked', (
      tester,
    ) async {
      final door = named('Door Library');
      await pumpScreen(
        tester,
        closed: {door.id},
        reasons: {door.id: "Use the library's 3F entrance"},
      );
      await tester.tap(
        find
            .ancestor(
              of: find.text('Select destination'),
              matching: find.byType(InkWell),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'door');
      await tester.pump();

      expect(
        find.text(
          "${door.building} · Floor 4 · Closed · Use the library's 3F "
          'entrance',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Door Library'));
      await tester.pumpAndSettle();
      // Nothing was picked: the list is still open, with no destination.
      expect(find.text('Door Library'), findsOneWidget);
      expect(mapIn(tester).destinationId, isNull);
    });

    testWidgets('tapping a closed place on the map says why instead', (
      tester,
    ) async {
      final door = named('Door Library');
      await pumpScreen(
        tester,
        closed: {door.id},
        reasons: {door.id: "Use the library's 3F entrance"},
      );
      // Show 4F by picking a place there, then bring the door to the middle.
      await choose(tester, 'Select starting point', '422', 'Room 422');
      mapIn(tester).controller!.centerOn(door.id, zoom: 1.3);
      await tester.pumpAndSettle();

      await tester.tapAt(tester.getCenter(find.byType(TiltedCampusMap)));
      await tester.pump();

      expect(
        find.text("Door Library is closed. Use the library's 3F entrance."),
        findsOneWidget,
      );
      expect(find.text('Set as starting point'), findsNothing);
    });
  });
}
