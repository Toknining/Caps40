import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:askuc/features/navigation/pathway_tree.dart';

void main() {
  group('PathwayTree', () {
    test('routes follow the tree even when a direct edge exists', () {
      // Prim's keeps A-B and B-C (total 4) and drops A-C (3), which would
      // close a loop. So the route from A to C goes through B.
      final tree = PathwayTree.build(
        ['A', 'B', 'C'],
        const [
          PathwayEdge('A', 'B', 2),
          PathwayEdge('B', 'C', 2),
          PathwayEdge('A', 'C', 3),
        ],
      );

      expect(tree.route('A', 'C'), ['A', 'B', 'C']);
      expect(tree.route('C', 'A'), ['C', 'B', 'A']);
    });

    test('a node routes to itself', () {
      final tree = PathwayTree.build(['A'], const []);

      expect(tree.route('A', 'A'), ['A']);
    });

    test('unknown ids have no route', () {
      final tree = PathwayTree.build(
        ['A', 'B'],
        const [PathwayEdge('A', 'B', 1)],
      );

      expect(tree.route('A', 'Z'), isEmpty);
      expect(tree.route('Z', 'A'), isEmpty);
    });

    test('parts that are not connected have no route between them', () {
      final tree = PathwayTree.build(
        ['A', 'B', 'C', 'D'],
        const [PathwayEdge('A', 'B', 1), PathwayEdge('C', 'D', 1)],
      );

      expect(tree.route('A', 'B'), ['A', 'B']);
      expect(tree.route('D', 'C'), ['D', 'C']);
      expect(tree.route('A', 'C'), isEmpty);
    });

    test('rejects edges that point to a missing node', () {
      expect(
        () => PathwayTree.build(['A'], const [PathwayEdge('A', 'B', 1)]),
        throwsArgumentError,
      );
    });

    test('rejects duplicate node ids', () {
      expect(
        () => PathwayTree.build(['A', 'A'], const []),
        throwsArgumentError,
      );
    });
  });

  group('FloorPathways', () {
    PathwayNode at(String id, int floor, double x, [double y = 0]) =>
        (id: id, floor: floor, x: x, y: y);

    test('takes the stairs nearest the walk', () {
      // Stairs at both ends; the start and the goal are both by the left.
      final pathways = FloorPathways.build(
        [
          at('L1', 1, 0), at('start', 1, 10), at('R1', 1, 100), //
          at('L2', 2, 0), at('goal', 2, 10), at('R2', 2, 100),
        ],
        const [
          ('L1', 'start'), ('start', 'R1'), //
          ('L2', 'goal'), ('goal', 'R2'),
          ('L1', 'L2'), ('R1', 'R2'),
        ],
        floorChangeCost: 150,
      );

      expect(pathways.route('start', 'goal'), ['start', 'L1', 'L2', 'goal']);
    });

    test('a trip on one floor stays on it', () {
      // Floor 1's corridor bends far out; going by floor 2 would be shorter.
      final pathways = FloorPathways.build(
        [
          at('a', 1, 0), at('bend', 1, 500, 1000), at('b', 1, 1000), //
          at('a2', 2, 0), at('b2', 2, 1000),
        ],
        const [
          ('a', 'bend'), ('bend', 'b'), ('a2', 'b2'), //
          ('a', 'a2'), ('b', 'b2'),
        ],
        floorChangeCost: 150,
      );

      expect(pathways.route('a', 'b'), ['a', 'bend', 'b']);
    });

    test('goes through another floor when a floor is split', () {
      final pathways = FloorPathways.build(
        [at('a', 1, 0), at('b', 1, 100), at('a2', 2, 0), at('b2', 2, 100)],
        const [('a2', 'b2'), ('a', 'a2'), ('b', 'b2')],
        floorChangeCost: 150,
      );

      expect(pathways.route('a', 'b'), ['a', 'a2', 'b2', 'b']);
    });

    test('switches stairs on a floor in between when needed', () {
      // One stairs joins floors 1 and 2, another joins floors 2 and 3.
      final pathways = FloorPathways.build(
        [
          at('start', 1, 0), at('x1', 1, 10), //
          at('x2', 2, 10), at('y2', 2, 200),
          at('y3', 3, 200), at('goal', 3, 210),
        ],
        const [
          ('start', 'x1'), ('x2', 'y2'), ('y3', 'goal'), //
          ('x1', 'x2'), ('y2', 'y3'),
        ],
        floorChangeCost: 150,
      );

      expect(pathways.route('start', 'goal'), [
        'start',
        'x1',
        'x2',
        'y2',
        'y3',
        'goal',
      ]);
    });

    test('unknown ids have no route', () {
      final pathways = FloorPathways.build(
        [at('a', 1, 0)],
        const [],
        floorChangeCost: 150,
      );

      expect(pathways.route('a', 'z'), isEmpty);
    });
  });

  group('campus_graph.json', () {
    test('every node is connected', () {
      final (pathways, nodes) = _loadCampus();
      final first = nodes.keys.first;
      final unreachable = [
        for (final id in nodes.keys)
          if (pathways.route(first, id).isEmpty) nodes[id]!['name'],
      ];

      expect(unreachable, isEmpty);
    });

    test('Dean Office to Cisco Lab 544 walks the corridor', () {
      final (pathways, nodes) = _loadCampus();
      String idOf(String name) =>
          nodes.values.firstWhere((node) => node['name'] == name)['id']
              as String;

      final route = pathways.route(
        idOf('CICS Dean Office'),
        idOf('CICS Cisco Lab 544'),
      );
      final names = [for (final id in route) nodes[id]!['name']];

      expect(names.first, 'CICS Dean Office');
      expect(names.last, 'CICS Cisco Lab 544');
      // Everything in between is corridor, never another room.
      expect([
        for (final id in route.sublist(1, route.length - 1)) nodes[id]!['kind'],
      ], everyElement(anyOf('hall', 'stairs', 'elevator')));
    });

    test('routes keep to the floors between their two ends', () {
      final (pathways, nodes) = _loadCampus();
      const corridorKinds = {'hall', 'stairs', 'elevator'};
      final places = [
        for (final node in nodes.values)
          if (!corridorKinds.contains(node['kind'])) node,
      ];

      // Every third place against every fifth keeps the test quick.
      final wandering = <String>[];
      for (var i = 0; i < places.length; i += 3) {
        for (var j = 0; j < places.length; j += 5) {
          final a = places[i], b = places[j];
          final floors = [
            for (final id in pathways.route(a['id'], b['id']))
              nodes[id]!['floor'] as int,
          ];
          final low = min(a['floor'] as int, b['floor'] as int);
          final high = max(a['floor'] as int, b['floor'] as int);
          // 7F's two halves only meet on 6F, so trips between them go down.
          final split7F = low == 7 && high == 7 && floors.contains(6);
          if (floors.any((f) => f < low || f > high) && !split7F) {
            wandering.add('${a['name']} -> ${b['name']}: $floors');
          }
        }
      }

      expect(wandering, isEmpty);
    });
  });
}

/// The app's pathways over the real asset: a Prim's tree per floor, joined by
/// the stairs and elevators.
(FloorPathways, Map<String, Map<String, dynamic>>) _loadCampus() {
  final json =
      jsonDecode(File('assets/campus_graph.json').readAsStringSync())
          as Map<String, dynamic>;
  final nodeList = (json['nodes'] as List).cast<Map<String, dynamic>>();
  final nodes = {for (final node in nodeList) node['id'] as String: node};

  return (
    FloorPathways.build(
      [
        for (final node in nodeList)
          (
            id: node['id'] as String,
            floor: node['floor'] as int,
            x: (node['x'] as num).toDouble(),
            y: (node['y'] as num).toDouble(),
          ),
      ],
      [
        for (final edge in (json['edges'] as List).cast<Map<String, dynamic>>())
          (edge['from'] as String, edge['to'] as String),
      ],
      floorChangeCost: 150,
    ),
    nodes,
  );
}
