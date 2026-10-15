import 'dart:math' as math;

/// A walkable connection between two campus nodes. Direction does not matter.
class PathwayEdge {
  const PathwayEdge(this.from, this.to, this.weight);

  final String from;
  final String to;

  /// Walking cost between the two nodes, e.g. their distance on the floor plan.
  final double weight;
}

/// The optimized connected pathway through the campus, built with Prim's
/// Algorithm.
///
/// Prim's grows a minimum spanning tree over the walkable graph: starting
/// from one node, it keeps adding whichever outside node has the cheapest
/// edge into the tree until every connected node is in. A route between two
/// places is then the single path between them through that tree.
///
/// Because the tree is fixed, the same two places always get the same
/// directions, and each [route] lookup only climbs the tree (O(V)) instead of
/// searching the graph. Routes follow the tree, so they are not guaranteed to
/// be the most direct walk.
///
/// Building costs O(V²), so build one tree when the graph loads and reuse it.
class PathwayTree {
  PathwayTree._(this._ids, this._index, this._parent, this._depth);

  /// Runs Prim's Algorithm over [nodeIds] and the undirected [edges].
  ///
  /// Parts of the graph that are not connected to each other each get their
  /// own tree, and there is no route between them.
  factory PathwayTree.build(
    Iterable<String> nodeIds,
    Iterable<PathwayEdge> edges,
  ) {
    final ids = List<String>.unmodifiable(nodeIds);
    final index = <String, int>{};
    for (var i = 0; i < ids.length; i++) {
      if (index.containsKey(ids[i])) {
        throw ArgumentError('Duplicate node id "${ids[i]}"');
      }
      index[ids[i]] = i;
    }

    final neighbors = List.generate(ids.length, (_) => <(int, double)>[]);
    for (final edge in edges) {
      final a = index[edge.from];
      final b = index[edge.to];
      if (a == null || b == null) {
        throw ArgumentError(
          'Edge ${edge.from} -> ${edge.to} has a missing node',
        );
      }
      neighbors[a].add((b, edge.weight));
      neighbors[b].add((a, edge.weight));
    }

    final count = ids.length;
    final inTree = List.filled(count, false);
    // For each node outside the tree: its cheapest edge into the tree so far,
    // and the tree node at the other end of that edge.
    final linkCost = List.filled(count, double.infinity);
    final parent = List.filled(count, -1);
    final depth = List.filled(count, 0);

    for (var root = 0; root < count; root++) {
      if (inTree[root]) continue;
      linkCost[root] = 0;

      while (true) {
        // Prim's step: pick the outside node with the cheapest link.
        var next = -1;
        for (var v = 0; v < count; v++) {
          if (!inTree[v] &&
              linkCost[v].isFinite &&
              (next == -1 || linkCost[v] < linkCost[next])) {
            next = v;
          }
        }
        if (next == -1) break; // everything reachable from root is in

        inTree[next] = true;
        if (parent[next] != -1) depth[next] = depth[parent[next]] + 1;

        for (final (neighbor, weight) in neighbors[next]) {
          if (!inTree[neighbor] && weight < linkCost[neighbor]) {
            linkCost[neighbor] = weight;
            parent[neighbor] = next;
          }
        }
      }
    }

    return PathwayTree._(ids, index, parent, depth);
  }

  final List<String> _ids;
  final Map<String, int> _index;
  final List<int> _parent; // -1 at the root of each tree
  final List<int> _depth;

  /// Node ids from [fromId] to [toId] in walking order, both ends included.
  ///
  /// Empty if either id is unknown or the two nodes are not connected.
  List<String> route(String fromId, String toId) {
    final start = _index[fromId];
    final end = _index[toId];
    if (start == null || end == null) return const [];

    // Climb from both ends until they meet where their paths join.
    var a = start;
    var b = end;
    final fromSide = <int>[];
    final toSide = <int>[];
    while (_depth[a] > _depth[b]) {
      fromSide.add(a);
      a = _parent[a];
    }
    while (_depth[b] > _depth[a]) {
      toSide.add(b);
      b = _parent[b];
    }
    while (a != b) {
      if (_parent[a] == -1) return const []; // two different trees
      fromSide.add(a);
      a = _parent[a];
      toSide.add(b);
      b = _parent[b];
    }

    return [
      for (final i in fromSide) _ids[i],
      _ids[a],
      for (final i in toSide.reversed) _ids[i],
    ];
  }
}

/// A campus node as [FloorPathways] needs it: its floor and where it is on
/// that floor's plan.
typedef PathwayNode = ({String id, int floor, double x, double y});

/// The optimized connected pathway through a building with several floors.
///
/// Every floor gets its own [PathwayTree] (Prim's Algorithm) over its own
/// corridors, so a trip that starts and ends on one floor stays on it. A trip
/// to another floor follows the start floor's pathway to a stairs or
/// elevator, rides it, and follows the other floor's pathway from where it
/// comes out. Of all the stairs and elevators that could join the two
/// floors, the one that gives the shortest total pathway is used.
///
/// A walk goes beyond the floors between its start and destination only when
/// there is no other way, e.g. two parts of a floor that only meet on another
/// floor.
class FloorPathways {
  FloorPathways._(this._nodes, this._trees, this._stairs, this._floorCost);

  /// Builds one pathway tree per floor from [nodes] and the undirected
  /// [links]. Links between floors are stairs and elevators; each floor
  /// ridden costs [floorChangeCost], in the same units as plan distance.
  factory FloorPathways.build(
    Iterable<PathwayNode> nodes,
    Iterable<(String, String)> links, {
    required double floorChangeCost,
  }) {
    final byId = <String, PathwayNode>{};
    for (final n in nodes) {
      if (byId.containsKey(n.id)) {
        throw ArgumentError('Duplicate node id "${n.id}"');
      }
      byId[n.id] = n;
    }

    final corridors = <int, List<PathwayEdge>>{};
    final stairs = <String, List<String>>{};
    for (final (from, to) in links) {
      final a = byId[from], b = byId[to];
      if (a == null || b == null) {
        throw ArgumentError('Link $from -> $to has a missing node');
      }
      if (a.floor == b.floor) {
        corridors
            .putIfAbsent(a.floor, () => [])
            .add(PathwayEdge(from, to, _distance(a, b)));
      } else {
        stairs.putIfAbsent(from, () => []).add(to);
        stairs.putIfAbsent(to, () => []).add(from);
      }
    }

    final trees = {
      for (final floor in {for (final n in byId.values) n.floor})
        floor: PathwayTree.build([
          for (final n in byId.values)
            if (n.floor == floor) n.id,
        ], corridors[floor] ?? const []),
    };
    return FloorPathways._(byId, trees, stairs, floorChangeCost);
  }

  /// How many times a walk may switch from one stairwell to another, e.g.
  /// when the stairs it starts on stop a floor short.
  static const _maxStairSwitches = 2;

  final Map<String, PathwayNode> _nodes;
  final Map<int, PathwayTree> _trees;
  final Map<String, List<String>> _stairs; // links between floors
  final double _floorCost;

  /// The stairs and elevator stops on each floor.
  late final Map<int, List<String>> _landings = {
    for (final floor in _trees.keys)
      floor: [
        for (final n in _nodes.values)
          if (n.floor == floor && _stairs.containsKey(n.id)) n.id,
      ],
  };

  final _rides = <String, List<(String, List<String>)>>{};

  /// Node ids from [fromId] to [toId] in walking order, both ends included.
  ///
  /// Empty if either id is unknown or nothing joins the two nodes.
  List<String> route(String fromId, String toId) {
    final from = _nodes[fromId], to = _nodes[toId];
    if (from == null || to == null) return const [];
    if (from.floor == to.floor) {
      final onFloor = _trees[from.floor]!.route(fromId, toId);
      if (onFloor.isNotEmpty) return onFloor;
    }
    final low = math.min(from.floor, to.floor);
    final high = math.max(from.floor, to.floor);
    return _byStairs(fromId, toId, (floor) => floor >= low && floor <= high) ??
        _byStairs(fromId, toId, (_) => true) ??
        const [];
  }

  /// The shortest walk from [fromId] to [toId] that rides stairs or
  /// elevators, getting off only on floors where [allowed] holds. It tries
  /// every stairs and elevator each floor's pathway reaches; null if none
  /// gets there.
  List<String>? _byStairs(
    String fromId,
    String toId,
    bool Function(int floor) allowed,
  ) {
    final goal = _nodes[toId]!;
    List<String>? best;
    var bestCost = double.infinity;

    void walkFrom(String at, List<String> walked, double cost, int switches) {
      final floor = _nodes[at]!.floor;
      for (final landing in _landings[floor]!) {
        final leg = _trees[floor]!.route(at, landing);
        if (leg.isEmpty) continue;
        final atLanding = cost + _length(leg);
        if (atLanding >= bestCost) continue;

        for (final (exit, ride) in _ridesFrom(landing)) {
          final exitFloor = _nodes[exit]!.floor;
          if (!allowed(exitFloor)) continue;
          final offRide = atLanding + (ride.length - 1) * _floorCost;
          if (offRide >= bestCost) continue;
          final path = [...walked, ...leg.skip(1), ...ride.skip(1)];

          if (exitFloor == goal.floor) {
            final last = _trees[exitFloor]!.route(exit, toId);
            final total = offRide + _length(last);
            if (last.isNotEmpty && total < bestCost) {
              bestCost = total;
              best = [...path, ...last.skip(1)];
            }
          }
          if (switches < _maxStairSwitches) {
            walkFrom(exit, path, offRide, switches + 1);
          }
        }
      }
    }

    walkFrom(fromId, [fromId], 0, 0);
    return best;
  }

  /// Every stop the stairs or elevator at [landing] goes to, each with the
  /// stops on the way there, [landing] first.
  List<(String, List<String>)> _ridesFrom(String landing) =>
      _rides.putIfAbsent(landing, () {
        final rides = <(String, List<String>)>[];
        final reached = {
          landing: [landing],
        };
        final queue = [landing];
        for (var i = 0; i < queue.length; i++) {
          final at = queue[i];
          for (final next in _stairs[at] ?? const <String>[]) {
            if (reached.containsKey(next)) continue;
            final ride = [...reached[at]!, next];
            reached[next] = ride;
            queue.add(next);
            rides.add((next, ride));
          }
        }
        return rides;
      });

  /// Plan distance along [path], whose nodes are all on one floor.
  double _length(List<String> path) {
    var total = 0.0;
    for (var i = 1; i < path.length; i++) {
      total += _distance(_nodes[path[i - 1]]!, _nodes[path[i]]!);
    }
    return total;
  }
}

double _distance(PathwayNode a, PathwayNode b) {
  final dx = a.x - b.x, dy = a.y - b.y;
  return math.sqrt(dx * dx + dy * dy);
}
