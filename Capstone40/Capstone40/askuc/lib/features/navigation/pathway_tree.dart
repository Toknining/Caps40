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
