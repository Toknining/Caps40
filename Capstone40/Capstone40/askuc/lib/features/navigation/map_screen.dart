import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/tilted_campus_map.dart';
import 'campus_map_screen.dart';
import 'pathway_tree.dart';

/// Floor plans shown on the map. width and height must be each image's real
/// pixel size, or every node lands in the wrong place. Keep every plan at the
/// same scale (pixels per metre) so walking costs compare fairly across floors.
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

/// Walking cost of riding stairs or an elevator one floor, in plan pixels.
/// Walks on a floor cost their plan distance; this weighs a floor against
/// them when choosing which stairs make the shortest pathway.
const _floorChangeCost = 150.0;

/// The campus graph and its pathways (Prim's Algorithm, one tree per floor).
/// Top-level finals load lazily, so this runs once, the first time a map
/// opens, and the Map tab and the /map route share the result.
final Future<(CampusGraph, FloorPathways)> _campus = _loadCampus();

Future<(CampusGraph, FloorPathways)> _loadCampus() async {
  final graph = await CampusGraph.loadAsset('assets/campus_graph.json');
  final pathways = FloorPathways.build(
    [for (final n in graph.nodes) (id: n.id, floor: n.floor, x: n.x, y: n.y)],
    [for (final e in graph.edges) (e.from, e.to)],
    floorChangeCost: _floorChangeCost,
  );
  return (graph, pathways);
}

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

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

        final (graph, pathways) = campus;
        // Only the /map route opened from Home has somewhere to go back to.
        final canGoBack = ModalRoute.of(context)?.canPop ?? false;

        return CampusMapScreen(
          graph: graph,
          plans: _plans,
          pathways: pathways,
          onRouteShown: _recordNavigationSearch,
          onBack: canGoBack ? () => Navigator.pop(context) : null,
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
