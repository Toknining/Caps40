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

  group('campus_graph.json', () {
    test('every node is connected', () {
      final (tree, nodes) = _loadCampus();
      final first = nodes.keys.first;
      final unreachable = [
        for (final id in nodes.keys)
          if (tree.route(first, id).isEmpty) nodes[id]!['name'],
      ];

      expect(unreachable, isEmpty);
    });

    test("Dean's Office to Room 544 walks the corridor", () {
      final (tree, nodes) = _loadCampus();
      String idOf(String name) =>
          nodes.values.firstWhere((node) => node['name'] == name)['id']
              as String;

      final route = tree.route(
        idOf("CICS Dean's Office 531"),
        idOf('Room 544'),
      );

      expect(
        [for (final id in route) nodes[id]!['name']],
        [
          "CICS Dean's Office 531",
          '5_c1',
          '5_c2',
          '5_c4',
          '5_c5',
          '5_c6',
          '5_c7',
          '5_c8',
          '5_c9',
          'Room 544',
        ],
      );
    });
  });
}

/// Builds the tree from the real asset, weighting edges by plan distance.
(PathwayTree, Map<String, Map<String, dynamic>>) _loadCampus() {
  final json =
      jsonDecode(File('assets/campus_graph.json').readAsStringSync())
          as Map<String, dynamic>;
  final nodeList = (json['nodes'] as List).cast<Map<String, dynamic>>();
  final nodes = {for (final node in nodeList) node['id'] as String: node};
  final edges = [
    for (final edge in (json['edges'] as List).cast<Map<String, dynamic>>())
      PathwayEdge(
        edge['from'] as String,
        edge['to'] as String,
        _distance(nodes[edge['from']]!, nodes[edge['to']]!),
      ),
  ];

  return (
    PathwayTree.build([
      for (final node in nodeList) node['id'] as String,
    ], edges),
    nodes,
  );
}

double _distance(Map<String, dynamic> a, Map<String, dynamic> b) {
  final dx = (a['x'] as num) - (b['x'] as num);
  final dy = (a['y'] as num) - (b['y'] as num);
  return sqrt(dx * dx + dy * dy);
}
