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

    group('closed stairs', () {
      // Stairs at both ends; the nearer ones, by the left, are closed.
      FloorPathways twoStairs(Set<String> closed) => FloorPathways.build(
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
        closed: closed,
      );

      test('are skipped for other stairs', () {
        expect(twoStairs(const {'L2'}).route('start', 'goal'), [
          'start',
          'R1',
          'R2',
          'goal',
        ]);
      });

      test('can still be walked to on their floor', () {
        expect(twoStairs(const {'L1'}).route('start', 'L1'), ['start', 'L1']);
      });

      test('leave no route when every stairs is closed', () {
        expect(twoStairs(const {'L1', 'R2'}).route('start', 'goal'), isEmpty);
      });

      test('are not ridden through to another floor', () {
        // One stairwell joins floors 1, 2 and 3; its floor 2 stop is closed.
        final pathways = FloorPathways.build(
          [at('s1', 1, 0), at('s2', 2, 0), at('s3', 3, 0)],
          const [('s1', 's2'), ('s2', 's3')],
          floorChangeCost: 150,
          closed: const {'s2'},
        );

        expect(pathways.route('s1', 's3'), isEmpty);
      });
    });

    group('closed doors', () {
      // A room with two doors off one corridor; the front door is nearer.
      FloorPathways twoDoors(Set<String> closed) => FloorPathways.build(
        [
          at('hall', 1, 0), at('front', 1, 10), at('room', 1, 20), //
          at('hall2', 1, 0, 30), at('side', 1, 20, 30),
        ],
        const [
          ('hall', 'front'), ('front', 'room'), //
          ('hall', 'hall2'), ('hall2', 'side'), ('side', 'room'),
        ],
        floorChangeCost: 150,
        closed: closed,
      );

      test('are not walked through', () {
        expect(twoDoors(const {}).route('hall', 'room'), [
          'hall',
          'front',
          'room',
        ]);
        expect(twoDoors(const {'front'}).route('hall', 'room'), [
          'hall',
          'hall2',
          'side',
          'room',
        ]);
      });

      test('leave no route when they were the only way in, and say so', () {
        final pathways = twoDoors(const {'front', 'side'});

        expect(pathways.route('hall', 'room'), isEmpty);
        // With everything open the walk would go through the front door, and
        // without it, through the side door.
        expect(pathways.closedOnTheWay('hall', 'room'), ['front', 'side']);
      });
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

    test('closing the stairs a route rides moves it to open ones', () {
      final (pathways, nodes) = _loadCampus();
      String idOf(String name) =>
          nodes.values.firstWhere((node) => node['name'] == name)['id']
              as String;
      int floorOf(String id) => nodes[id]!['floor'] as int;
      // The stops at both ends of every ride between floors.
      Set<String> ridden(List<String> route) => {
        for (var i = 1; i < route.length; i++)
          if (floorOf(route[i - 1]) != floorOf(route[i])) ...[
            route[i - 1],
            route[i],
          ],
      };

      final from = idOf('CICS Dean Office');
      final to = idOf('Physics Lab 734');
      final closed = ridden(pathways.route(from, to));
      expect(closed, isNotEmpty);

      final (rerouted, _) = _loadCampus(closed: closed);
      final route = rerouted.route(from, to);
      expect(route, isNotEmpty);
      expect(ridden(route).intersection(closed), isEmpty);
    });

    test(
      'with 4F Library Door Entrance closed, the library is entered from 3F',
      () {
        final (_, nodes) = _loadCampus();
        String idOf(String name) =>
            nodes.values.firstWhere((node) => node['name'] == name)['id']
                as String;
        final door = idOf('4F Library Door Entrance');
        final room = idOf('Room 422'), library = idOf('Main Library');

        // The 4F door is locked in reality, so the walk goes down to 3F, in at
        // the library's 3F door and up the library's own stairs.
        final (pathways, _) = _loadCampus(closed: {door});
        final route = pathways.route(room, library);
        expect(route, isNotEmpty);
        expect(route, isNot(contains(door)));
        expect([for (final id in route) nodes[id]!['floor']], contains(3));

        // With the 3F door closed as well there's no way in; both are named.
        final door3F = idOf('3F Library Door Entrance');
        final (shut, _) = _loadCampus(closed: {door, door3F});
        expect(shut.route(room, library), isEmpty);
        expect(shut.closedOnTheWay(room, library), [door, door3F]);
        // Places outside the library are still reachable.
        expect(shut.route(room, idOf('Room 423')), isNotEmpty);
      },
    );
  });
}

/// The app's pathways over the real asset: a Prim's tree per floor, joined by
/// the stairs and elevators, minus any [closed] stops and doors.
(FloorPathways, Map<String, Map<String, dynamic>>) _loadCampus({
  Set<String> closed = const {},
}) {
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
      closed: closed,
    ),
    nodes,
  );
}
