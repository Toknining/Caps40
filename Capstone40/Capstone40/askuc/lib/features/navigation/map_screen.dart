import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

import '../../widgets/tilted_campus_map.dart';
import 'campus_map_screen.dart';
import 'pathway_tree.dart';

/// Floor plans shown on the map. width and height must be each image's real
/// pixel size, or every node lands in the wrong place. Plans may be drawn at
/// different scales: loading lines every floor up by its stairs (see
/// [CampusGraph.alignFloors]).
const _plans = [
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

/// Walking cost of riding stairs or an elevator one floor, in plan pixels.
/// Walks on a floor cost their plan distance; this weighs a floor against
/// them when choosing which stairs make the shortest pathway.
const _floorChangeCost = 150.0;

/// The campus graph and floor plans, every floor lined up on the others.
/// Top-level finals load lazily, so this runs once, the first time a map
/// opens, and the Map tab and the /map route share it.
final Future<({CampusGraph graph, List<FloorPlan> plans})> _campus =
    CampusGraph.loadAsset(
      'assets/campus_graph.json',
    ).then((graph) => graph.alignFloors(_plans));

/// The stairs and elevator stops, and doors, closed on the admin panel's Map
/// page: each id with the reason the admin gave, '' if none. Until they load,
/// or if they can't, everything counts as open; after a failed read the last
/// closures that loaded stay in force.
Stream<Map<String, String>> _closures() => FirebaseFirestore.instance
    .collection('mapClosures')
    .snapshots()
    .map(
      (snapshot) => {
        for (final doc in snapshot.docs)
          doc.id: (doc.data()['reason'] as String?)?.trim() ?? '',
      },
    )
    .handleError((Object error) {
      debugPrint('Failed to load closed stairs, elevators and doors: $error');
    });

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _closureUpdates = _closures();

  /// The pathways (Prim's Algorithm, one tree per floor) and the closed
  /// stops and doors they route around. Rebuilt only when those change.
  FloorPathways? _pathways;
  Set<String> _pathwaysClosed = const {};

  FloorPathways _pathwaysFor(CampusGraph graph, Set<String> closed) {
    final built = _pathways;
    if (built != null && setEquals(closed, _pathwaysClosed)) {
      return built;
    }
    _pathwaysClosed = closed;
    return _pathways = FloorPathways.build(
      [for (final n in graph.nodes) (id: n.id, floor: n.floor, x: n.x, y: n.y)],
      [for (final e in graph.edges) (e.from, e.to)],
      floorChangeCost: _floorChangeCost,
      closed: closed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _campus,
      builder: (context, snapshot) {
        final campus = snapshot.data;
        if (campus == null) {
          return Scaffold(
            body: Center(
              child: snapshot.hasError
                  ? Text(
                      'Could not load the campus map.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    )
                  : const CircularProgressIndicator(),
            ),
          );
        }

        final graph = campus.graph;
        return StreamBuilder<Map<String, String>>(
          stream: _closureUpdates,
          builder: (context, closures) {
            final reasons = closures.data ?? const <String, String>{};
            final closed = reasons.keys.toSet();
            // Only the /map route opened from Home has somewhere to go back to.
            final canGoBack = ModalRoute.of(context)?.canPop ?? false;

            return CampusMapScreen(
              graph: graph,
              plans: campus.plans,
              pathways: _pathwaysFor(graph, closed),
              closedIds: closed,
              closureReasons: reasons,
              onRouteShown: _recordNavigationSearch,
              onBack: canGoBack ? () => Navigator.pop(context) : null,
            );
          },
        );
      },
    );
  }
}

/// Feeds the navigation chart on the admin dashboard.
Future<void> _recordNavigationSearch(MapNode from, MapNode to) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return;
  }

  try {
    await FirebaseFirestore.instance.collection('navigationSearches').add({
      'userId': user.uid,
      'startingPoint': from.name,
      'destination': to.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  } catch (error) {
    debugPrint('Failed to record navigation search: $error');
  }
}
