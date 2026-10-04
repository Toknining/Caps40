import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Tilted floor-plan map for AskUC.
///
/// The whole idea in one sentence: the floor plan images are tilted by a 2D
/// matrix, and every node is pushed through the SAME matrix, so dots and routes
/// land on the right rooms without any coordinate maths of your own.
///
/// Nothing here is 3D. No camera, no mesh, no WebView. Just images, a matrix,
/// and a painter.
///
/// Drop this file in lib/widgets/ and see the usage note at the bottom.

// ---------------------------------------------------------------- data

class MapNode {
  final String id;
  final String name;
  final String building;
  final int floor;
  final double x; // pixel coords in the ORIGINAL, untilted floor plan image
  final double y;
  final String kind;

  const MapNode({
    required this.id,
    required this.name,
    required this.floor,
    required this.x,
    required this.y,
    this.building = '',
    this.kind = 'office',
  });

  factory MapNode.fromJson(Map<String, dynamic> j) => MapNode(
    id: j['id'] as String,
    name: (j['name'] ?? j['id']) as String,
    building: (j['building'] ?? '') as String,
    floor: (j['floor'] as num).toInt(),
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    kind: (j['kind'] ?? 'office') as String,
  );

  bool get isTransit =>
      kind == 'hall' || kind == 'stairs' || kind == 'elevator';
}

class MapEdge {
  final String from;
  final String to;
  const MapEdge({required this.from, required this.to});

  factory MapEdge.fromJson(Map<String, dynamic> j) =>
      MapEdge(from: j['from'] as String, to: j['to'] as String);
}

/// One floor plan image. [width] and [height] are the image's real pixel size —
/// the same numbers the node editor showed when you loaded it.
class FloorPlan {
  final int floor;
  final String asset;
  final double width;
  final double height;
  const FloorPlan({
    required this.floor,
    required this.asset,
    required this.width,
    required this.height,
  });
}

class CampusGraph {
  final List<MapNode> nodes;
  final List<MapEdge> edges;
  const CampusGraph({required this.nodes, required this.edges});

  static Future<CampusGraph> loadAsset(String path) async {
    final raw = await rootBundle.loadString(path);
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return CampusGraph(
      nodes: (j['nodes'] as List)
          .map((e) => MapNode.fromJson(e as Map<String, dynamic>))
          .toList(),
      edges: (j['edges'] as List? ?? [])
          .map((e) => MapEdge.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  MapNode? byId(String id) {
    for (final n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }
}

// ---------------------------------------------------------------- widget

class TiltedCampusMap extends StatelessWidget {
  final CampusGraph graph;
  final List<FloorPlan> plans;

  /// Node ids in walking order, from your routing backend.
  final List<String> routeIds;

  final String? originId;
  final String? destinationId;

  /// null shows every floor. Set it to dim the others.
  final int? focusedFloor;

  /// 1.0 is flat, 0.5 is steeply tilted. 0.62 reads well and keeps labels legible.
  final double squash;

  /// Slight rotation in radians. Keep it small; -0.10 adds depth without
  /// making room names hard to read. 0 is fine too.
  final double rotation;

  /// Vertical gap between stacked floors, in screen pixels.
  final double floorGap;

  final ValueChanged<MapNode>? onNodeTap;
  final TransformationController? controller;

  /// Node ids to keep in view, e.g. the route or the selected place. When
  /// empty, the view frames every node on the visible floors. The view only
  /// re-frames when this changes, so the user's own pan and zoom are kept.
  final List<String> focusIds;

  /// Edges of the map covered by other widgets, such as buttons laid over it.
  /// Framing keeps the focus nodes out from under them.
  final EdgeInsets viewPadding;

  const TiltedCampusMap({
    super.key,
    required this.graph,
    required this.plans,
    this.routeIds = const [],
    this.originId,
    this.destinationId,
    this.focusedFloor,
    this.squash = 0.62,
    this.rotation = -0.10,
    this.floorGap = 150,
    this.onNodeTap,
    this.controller,
    this.focusIds = const [],
    this.viewPadding = EdgeInsets.zero,
  });

  Matrix4 get _tilt => Matrix4.identity()
    ..scale(1.0, squash, 1.0)
    ..rotateZ(rotation);

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) {
      return const Center(child: Text('No floor plans loaded'));
    }

    final sorted = [...plans]..sort((a, b) => a.floor.compareTo(b.floor));
    final maxFloor = sorted.last.floor;
    final matrix = _tilt;

    // Where does each tilted plan actually land on screen?
    Rect boundsOf(FloorPlan p) => MatrixUtils.transformRect(
      matrix,
      Rect.fromLTWH(0, 0, p.width, p.height),
    );

    final allBounds = sorted.map(boundsOf).toList();
    final minLeft = allBounds.map((r) => r.left).reduce(math.min);
    final minTop = allBounds.map((r) => r.top).reduce(math.min);
    final maxRight = allBounds.map((r) => r.right).reduce(math.max);
    final maxBottom = allBounds.map((r) => r.bottom).reduce(math.max);

    const pad = 60.0;
    final originX = -minLeft + pad;
    final originY = -minTop + pad;
    final stackHeight = (maxFloor - sorted.first.floor) * floorGap;
    final canvas = Size(
      maxRight - minLeft + pad * 2,
      maxBottom - minTop + stackHeight + pad * 2,
    );

    double offsetYFor(int floor) => (maxFloor - floor) * floorGap;

    Offset project(MapNode n) {
      final p = MatrixUtils.transformPoint(matrix, Offset(n.x, n.y));
      return Offset(p.dx + originX, p.dy + originY + offsetYFor(n.floor));
    }

    final layers = <Widget>[];
    for (final p in sorted) {
      final dim = focusedFloor != null && focusedFloor != p.floor;
      layers.add(
        Positioned(
          // Transform paints from the child's top-left, so the tilted plan's own
          // bounds tell us how far it spills left/up of that anchor.
          left: originX,
          top: originY + offsetYFor(p.floor),
          child: Transform(
            transform: matrix,
            alignment: Alignment.topLeft,
            child: Opacity(
              opacity: dim ? 0.22 : 1.0,
              child: Container(
                width: p.width,
                height: p.height,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 24,
                      color: Color(0x33000000),
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Image.asset(
                  p.asset,
                  width: p.width,
                  height: p.height,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => ColoredBox(
                    color: const Color(0xFFEDF1EB),
                    child: Center(
                      child: Text(
                        'Missing asset:\n${p.asset}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9B2C2C),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    layers.add(
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _OverlayPainter(
              graph: graph,
              project: project,
              routeIds: routeIds,
              originId: originId,
              destinationId: destinationId,
              focusedFloor: focusedFloor,
            ),
          ),
        ),
      ),
    );

    // Frame the focus nodes, else every node on the visible floors.
    var framed = focusIds.map(graph.byId).whereType<MapNode>().toList();
    if (framed.isEmpty) {
      framed = graph.nodes
          .where((n) => focusedFloor == null || n.floor == focusedFloor)
          .toList();
    }

    return _FramedViewer(
      controller: controller,
      padding: viewPadding,
      target: framed.isEmpty
          ? Offset.zero & canvas
          : _around(framed.map(project)),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          if (onNodeTap == null) return;
          MapNode? best;
          double bestDist = 26;
          for (final n in graph.nodes) {
            if (focusedFloor != null && n.floor != focusedFloor) continue;
            if (n.kind == 'hall') continue; // corridor points aren't places
            final dist = (project(n) - d.localPosition).distance;
            if (dist < bestDist) {
              bestDist = dist;
              best = n;
            }
          }
          if (best != null) onNodeTap!(best);
        },
        child: SizedBox(
          width: canvas.width,
          height: canvas.height,
          child: Stack(clipBehavior: Clip.none, children: layers),
        ),
      ),
    );
  }
}

/// A box around [points] with room for labels, never smaller than a few rooms
/// so a single selected place still shows its surroundings.
Rect _around(Iterable<Offset> points) {
  var box = Rect.fromPoints(points.first, points.first);
  for (final p in points) {
    box = box.expandToInclude(Rect.fromPoints(p, p));
  }
  return Rect.fromCenter(
    center: box.center,
    width: math.max(box.width + 160, 520),
    height: math.max(box.height + 160, 340),
  );
}

/// InteractiveViewer that frames [target] inside the viewport minus [padding]
/// whenever any of those change, and otherwise leaves the user's pan and zoom
/// alone.
class _FramedViewer extends StatefulWidget {
  final Rect target;
  final EdgeInsets padding;
  final TransformationController? controller;
  final Widget child;

  const _FramedViewer({
    required this.target,
    required this.padding,
    required this.controller,
    required this.child,
  });

  @override
  State<_FramedViewer> createState() => _FramedViewerState();
}

class _FramedViewerState extends State<_FramedViewer> {
  static const _minScale = 0.1;
  static const _maxScale = 4.0;

  TransformationController? _own;
  (Size, Rect, EdgeInsets)? _framed;

  TransformationController get _controller =>
      widget.controller ?? (_own ??= TransformationController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        final frame = (viewport, widget.target, widget.padding);
        if (viewport.isFinite && !viewport.isEmpty && _framed != frame) {
          _framed = frame;
          final matrix = _fit(
            widget.target,
            widget.padding.deflateRect(Offset.zero & viewport),
          );
          // The controller can't change mid-layout, so apply it next frame.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _controller.value = matrix;
          });
        }

        return InteractiveViewer(
          transformationController: _controller,
          minScale: _minScale,
          maxScale: _maxScale,
          boundaryMargin: const EdgeInsets.all(400),
          constrained: false,
          child: widget.child,
        );
      },
    );
  }

  /// Scales and centres [target] (canvas coordinates) inside [area] (screen).
  static Matrix4 _fit(Rect target, Rect area) {
    final scale = math
        .min(area.width / target.width, area.height / target.height)
        .clamp(_minScale, _maxScale)
        .toDouble();
    return Matrix4.diagonal3Values(scale, scale, 1)..setTranslationRaw(
      area.center.dx - target.center.dx * scale,
      area.center.dy - target.center.dy * scale,
      0,
    );
  }
}

// ---------------------------------------------------------------- painter

const Map<String, Color> _kindColor = {
  'office': Color(0xFF1B5E3F),
  'lab': Color(0xFF35667E),
  'classroom': Color(0xFF5C6BC0),
  'facility': Color(0xFF8A5A2B),
  'lobby': Color(0xFF56685D),
  'entrance': Color(0xFF2E7D32),
  'hall': Color(0xFF9AA79C),
  'stairs': Color(0xFFC2185B),
  'elevator': Color(0xFF7B1FA2),
  'restroom': Color(0xFF00838F),
  'open': Color(0xFF7C8B7F),
};
const _gold = Color(0xFFE0A526);
const _ink = Color(0xFF14251C);

class _OverlayPainter extends CustomPainter {
  final CampusGraph graph;
  final Offset Function(MapNode) project;
  final List<String> routeIds;
  final String? originId;
  final String? destinationId;
  final int? focusedFloor;

  _OverlayPainter({
    required this.graph,
    required this.project,
    required this.routeIds,
    this.originId,
    this.destinationId,
    this.focusedFloor,
  });

  bool _visible(MapNode n) => focusedFloor == null || n.floor == focusedFloor;

  @override
  void paint(Canvas canvas, Size size) {
    // corridors
    final corridor = Paint()
      ..color = const Color(0x55C6D2C8)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final e in graph.edges) {
      final a = graph.byId(e.from), b = graph.byId(e.to);
      if (a == null || b == null) continue;
      if (!_visible(a) || !_visible(b)) continue;
      if (a.floor != b.floor) continue;
      canvas.drawLine(project(a), project(b), corridor);
    }

    // route
    final route = routeIds.map(graph.byId).whereType<MapNode>().toList();
    if (route.length >= 2) {
      final halo = Paint()
        ..color = Colors.white
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final line = Paint()
        ..color = _gold
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      for (var i = 0; i < route.length - 1; i++) {
        final a = route[i], b = route[i + 1];
        if (focusedFloor != null &&
            (a.floor != focusedFloor && b.floor != focusedFloor)) {
          continue;
        }
        final pa = project(a), pb = project(b);
        canvas.drawLine(pa, pb, halo);
        if (a.floor != b.floor) {
          _dashed(canvas, pa, pb, _gold, 6, 10, 7); // the stair or lift hop
        } else {
          canvas.drawLine(pa, pb, line);
        }
      }
    }

    final onRoute = routeIds.toSet();

    // nodes
    for (final n in graph.nodes) {
      if (!_visible(n)) continue;
      final p = project(n);
      final isEnd = n.id == originId || n.id == destinationId;
      final lit = onRoute.contains(n.id);

      if (n.isTransit && !lit && !isEnd) {
        canvas.drawCircle(p, 4.5, Paint()..color = const Color(0x889AA79C));
        continue;
      }

      final r = isEnd ? 9.0 : (lit ? 7.0 : 6.0);
      canvas.drawCircle(p, r + 3, Paint()..color = Colors.white);
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..color = isEnd
              ? _gold
              : (lit ? _gold : (_kindColor[n.kind] ?? _ink)),
      );

      if (isEnd) {
        final label = n.id == originId ? 'A' : 'B';
        final marker = Offset(p.dx, p.dy - 24);
        canvas.drawCircle(marker, 12, Paint()..color = Colors.white);
        canvas.drawCircle(marker, 10, Paint()..color = _ink);
        _text(canvas, label, marker, size: 12, color: Colors.white, bold: true);
      }

      if (!n.isTransit) {
        _text(
          canvas,
          n.name,
          Offset(p.dx, p.dy + 13),
          size: 10.5,
          color: _ink,
          bold: lit,
          background: true,
        );
      }
    }
  }

  void _dashed(
    Canvas canvas,
    Offset a,
    Offset b,
    Color c,
    double w,
    double dash,
    double gap,
  ) {
    final paint = Paint()
      ..color = c
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    var t = 0.0;
    while (t < total) {
      final end = math.min(t + dash, total);
      canvas.drawLine(a + dir * t, a + dir * end, paint);
      t = end + gap;
    }
  }

  void _text(
    Canvas canvas,
    String value,
    Offset center, {
    required double size,
    required Color color,
    bool bold = false,
    bool background = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: 110);

    final offset = Offset(
      center.dx - tp.width / 2,
      center.dy - (background ? 0 : tp.height / 2),
    );

    if (background) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          offset.dx - 4,
          offset.dy - 2,
          tp.width + 8,
          tp.height + 4,
        ),
        const Radius.circular(5),
      );
      canvas.drawRRect(rect, Paint()..color = const Color(0xE6FFFFFF));
    }
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) =>
      old.routeIds != routeIds ||
      old.originId != originId ||
      old.destinationId != destinationId ||
      old.focusedFloor != focusedFloor;
}

// ---------------------------------------------------------------- usage
//
// 1. pubspec.yaml:
//
//    flutter:
//      assets:
//        - assets/floorplans/
//        - assets/campus_graph.json
//
// 2. Load once, then hand it to the widget:
//
//    final graph = await CampusGraph.loadAsset('assets/campus_graph.json');
//
//    TiltedCampusMap(
//      graph: graph,
//      plans: const [
//        FloorPlan(floor: 4, asset: 'assets/floorplans/floor_4.png', width: 2000, height: 1400),
//        FloorPlan(floor: 5, asset: 'assets/floorplans/floor_5.png', width: 2000, height: 1400),
//      ],
//      routeIds: const ['main_gate', 'mb_lobby', 'mb_stairs_1', 'mb_stairs_2', 'registrar'],
//      originId: 'main_gate',
//      destinationId: 'registrar',
//      onNodeTap: (n) => debugPrint('tapped ${n.name}'),
//    );
//
// 3. width and height must be the image's real pixel size — the node editor
//    prints it when you load a plan. Wrong numbers put every dot in the wrong
//    place, and it is the first thing to check if the overlay looks shifted.
//
// 4. Export the graph UNCALIBRATED (scale 1) so x and y stay in image pixels,
//    which is what this widget expects. Calibrate only if you want the backend
//    reporting metres, and in that case divide by scale_m_per_px when loading.
