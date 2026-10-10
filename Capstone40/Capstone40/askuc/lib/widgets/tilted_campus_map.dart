import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
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
/// Drag to pan, pinch to zoom, twist with two fingers to turn the floors.
/// Zooming out stops once the whole map is in view. A [CampusMapController]
/// moves the view from code, e.g. to glide to where a pathway starts.
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

// ---------------------------------------------------------------- controller

/// Moves a [TiltedCampusMap] from code. Hand the same controller to the map,
/// then call it from buttons, e.g. to glide to the starting point.
class CampusMapController {
  _TiltedCampusMapState? _state;

  /// Glides so [nodeId] sits in the middle of the map. [zoom] is in screen
  /// pixels per plan pixel; it stays between the whole-map view and the
  /// closest zoom. Leave it out to keep the current zoom.
  void centerOn(String nodeId, {double? zoom}) =>
      _state?._centerOn(nodeId, zoom);

  /// Glides back out to the whole map.
  void showAll() => _state?._showAll();

  /// Turns the floors back to their starting angle.
  void resetRotation() => _state?._resetRotation();

  /// Current zoom, in screen pixels per plan pixel.
  double get zoom => _state?._view?.zoom ?? 1;

  /// Current turn of the floors, in radians.
  double get rotation => _state?._view?.azimuth ?? 0;

  /// Where [nodeId] is drawn, measured from the map's top-left corner.
  Offset? positionOf(String nodeId) => _state?._positionOf(nodeId);
}

// ---------------------------------------------------------------- widget

class TiltedCampusMap extends StatefulWidget {
  final CampusGraph graph;
  final List<FloorPlan> plans;

  /// Node ids in walking order, from your routing backend.
  final List<String> routeIds;

  final String? originId;
  final String? destinationId;

  /// null shows every floor. Set it to dim the others.
  final int? focusedFloor;

  /// 1.0 is flat, 0.5 is steeply tilted. 0.577 (tan 30°) together with a 45°
  /// [rotation] is true isometric.
  final double squash;

  /// Starting turn in radians, applied before the squash. -pi/4 (45°) is true
  /// isometric. Values near 0, like -0.10, keep the room names printed on the
  /// plan image easier to read. Users can twist away from it;
  /// [CampusMapController.resetRotation] turns the floors back.
  final double rotation;

  /// Vertical gap between stacked floors, in plan pixels.
  final double floorGap;

  final ValueChanged<MapNode>? onNodeTap;
  final CampusMapController? controller;

  const TiltedCampusMap({
    super.key,
    required this.graph,
    required this.plans,
    this.routeIds = const [],
    this.originId,
    this.destinationId,
    this.focusedFloor,
    this.squash = 0.577,
    this.rotation = -math.pi / 4,
    this.floorGap = 150,
    this.onNodeTap,
    this.controller,
  });

  @override
  State<TiltedCampusMap> createState() => _TiltedCampusMapState();
}

/// What the map is looking at. [camera] is the point on the top floor's plan
/// drawn in the middle of the map.
@immutable
class _View {
  final Offset camera;
  final double zoom;
  final double azimuth;
  const _View(this.camera, this.zoom, this.azimuth);
}

class _TiltedCampusMapState extends State<TiltedCampusMap>
    with TickerProviderStateMixin {
  static const _maxZoom = 4.0;

  /// Room left around the whole map when zoomed all the way out.
  static const _fitPadding = 12.0;

  /// How far past the outermost nodes the building reaches, in plan pixels:
  /// half a room plus its wall.
  static const _outlineMargin = 48.0;

  /// How far past its edges the map can be dragged.
  static const _edgeSlack = 24.0;

  /// Twist, in radians, before two fingers start turning the map, so an
  /// ordinary pinch doesn't turn it by accident.
  static const _twistSlop = 0.15;

  late final _glide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..addListener(_onGlide);
  late final _fling = AnimationController.unbounded(vsync: this)
    ..addListener(_onFling);

  Size? _viewport;
  _View? _view;
  int _topFloor = 0;

  /// Plan points that outline what there is to see: every node, plus the
  /// corners of any plan with no nodes yet. Fitting to these instead of the
  /// image rectangles keeps a plan's empty corners from shrinking the map.
  List<(Offset, int)> _outline = const [];

  _View? _glideFrom;
  _View? _glideTo;

  _View? _flingFrom;
  Offset _flingDirection = Offset.zero;

  _View? _gestureStart;
  Offset _anchor = Offset.zero;
  double? _twistOffset;
  bool _multiTouch = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  @override
  void didUpdateWidget(TiltedCampusMap old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      if (old.controller?._state == this) old.controller?._state = null;
      widget.controller?._state = this;
    }
    if (old.plans != widget.plans ||
        old.graph != widget.graph ||
        old.squash != widget.squash ||
        old.floorGap != widget.floorGap) {
      _viewport = null; // measure again on the next build
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller?._state = null;
    _glide.dispose();
    _fling.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ the maths

  Offset get _center => _viewport!.center(Offset.zero);

  /// Turn by [azimuth], then squash vertically: the tilt every plan and node
  /// goes through.
  Offset _tilt(Offset p, double azimuth) {
    final c = math.cos(azimuth), s = math.sin(azimuth);
    return Offset(p.dx * c - p.dy * s, (p.dx * s + p.dy * c) * widget.squash);
  }

  Offset _untilt(Offset q, double azimuth) {
    final c = math.cos(azimuth), s = math.sin(azimuth);
    final y = q.dy / widget.squash;
    return Offset(q.dx * c + y * s, -q.dx * s + y * c);
  }

  /// Lower floors are drawn further down, like an exploded drawing.
  Offset _lift(int floor) => Offset(0, (_topFloor - floor) * widget.floorGap);

  Offset _toScreen(_View v, Offset plan, int floor) =>
      _center + (_tilt(plan - v.camera, v.azimuth) + _lift(floor)) * v.zoom;

  /// The top-floor plan point under [screen].
  Offset _toPlane(_View v, Offset screen) =>
      v.camera + _untilt((screen - _center) / v.zoom, v.azimuth);

  /// The box on screen that holds the whole map.
  Rect _contentOnScreen(_View v) {
    var left = double.infinity, top = double.infinity;
    var right = double.negativeInfinity, bottom = double.negativeInfinity;
    for (final (plan, floor) in _outline) {
      final s = _toScreen(v, plan, floor);
      left = math.min(left, s.dx);
      top = math.min(top, s.dy);
      right = math.max(right, s.dx);
      bottom = math.max(bottom, s.dy);
    }
    return Rect.fromLTRB(
      left,
      top,
      right,
      bottom,
    ).inflate(_outlineMargin * v.zoom);
  }

  /// The zoom at which the whole map just fits, turned to [azimuth]. Zooming
  /// out stops here.
  double _minZoomAt(double azimuth) {
    final box = _contentOnScreen(_View(Offset.zero, 1, azimuth));
    final room = _viewport!;
    final fit = math.min(
      math.max(room.width - 2 * _fitPadding, 1) / box.width,
      math.max(room.height - 2 * _fitPadding, 1) / box.height,
    );
    return math.min(fit, _maxZoom);
  }

  /// The whole map in view and centred.
  _View _wholeMap(double azimuth) {
    final box = _contentOnScreen(_View(Offset.zero, 1, azimuth));
    return _View(
      _untilt(box.center - _center, azimuth),
      _minZoomAt(azimuth),
      azimuth,
    );
  }

  /// Keeps the zoom in range and the map in view. When the map is bigger than
  /// the viewport the viewport stays over it; when smaller it stays inside.
  _View _clamp(_View v) {
    final zoom = v.zoom.clamp(_minZoomAt(v.azimuth), _maxZoom);
    final out = _View(v.camera, zoom, v.azimuth);
    final box = _contentOnScreen(out);
    final room = _viewport!;
    double nudge(double start, double length, double space) {
      final lo = math.min(0.0, space - length) - _edgeSlack;
      final hi = math.max(0.0, space - length) + _edgeSlack;
      return start < lo ? lo - start : (start > hi ? hi - start : 0.0);
    }

    final shift = Offset(
      nudge(box.left, box.width, room.width),
      nudge(box.top, box.height, room.height),
    );
    if (shift == Offset.zero) return out;
    return _View(
      out.camera - _untilt(shift / zoom, out.azimuth),
      zoom,
      out.azimuth,
    );
  }

  /// Signed turn from [from] to [to], the short way round.
  static double _turn(double from, double to) {
    final d = (to - from) % (2 * math.pi);
    return d > math.pi ? d - 2 * math.pi : d;
  }

  void _measure(Size size) {
    _viewport = size;
    _topFloor = widget.plans.map((p) => p.floor).reduce(math.max);
    final mapped = {for (final n in widget.graph.nodes) n.floor};
    _outline = [
      for (final n in widget.graph.nodes) (Offset(n.x, n.y), n.floor),
      for (final p in widget.plans)
        if (!mapped.contains(p.floor))
          for (final corner in [
            Offset.zero,
            Offset(p.width, 0),
            Offset(0, p.height),
            Offset(p.width, p.height),
          ])
            (corner, p.floor),
    ];
    final v = _view;
    _view = v == null ? _wholeMap(widget.rotation) : _clamp(v);
  }

  // ------------------------------------------------------------ motion

  void _stopMotion() {
    _glide.stop();
    _fling.stop();
  }

  void _glideToView(_View target) {
    if (_view == null) return;
    _stopMotion();
    _glideFrom = _view;
    _glideTo = _clamp(target);
    _glide.forward(from: 0);
  }

  void _onGlide() {
    final a = _glideFrom, b = _glideTo;
    if (a == null || b == null) return;
    final t = Curves.easeInOutCubic.transform(_glide.value);
    final logZoom =
        math.log(a.zoom) + (math.log(b.zoom) - math.log(a.zoom)) * t;
    setState(() {
      _view = _View(
        Offset.lerp(a.camera, b.camera, t)!,
        math.exp(logZoom),
        a.azimuth + _turn(a.azimuth, b.azimuth) * t,
      );
    });
  }

  void _onFling() {
    final from = _flingFrom;
    if (from == null || _view == null) return;
    final moved = _flingDirection * _fling.value;
    final camera = from.camera - _untilt(moved / from.zoom, from.azimuth);
    setState(() => _view = _clamp(_View(camera, from.zoom, from.azimuth)));
  }

  void _centerOn(String nodeId, double? zoom) {
    final v = _view;
    final n = widget.graph.byId(nodeId);
    if (v == null || n == null) return;
    // The camera point that puts this node in the middle of the map.
    final camera = Offset(n.x, n.y) + _untilt(_lift(n.floor), v.azimuth);
    _glideToView(_View(camera, zoom ?? v.zoom, v.azimuth));
  }

  void _showAll() {
    final v = _view;
    if (v != null) _glideToView(_wholeMap(v.azimuth));
  }

  void _resetRotation() {
    final v = _view;
    if (v != null) _glideToView(_View(v.camera, v.zoom, widget.rotation));
  }

  Offset? _positionOf(String nodeId) {
    final v = _view;
    final n = widget.graph.byId(nodeId);
    if (v == null || n == null) return null;
    return _toScreen(v, Offset(n.x, n.y), n.floor);
  }

  // ------------------------------------------------------------ gestures

  void _onScaleStart(ScaleStartDetails d) {
    _stopMotion();
    final v = _view;
    if (v == null) return;
    _gestureStart = v;
    _anchor = _toPlane(v, d.localFocalPoint);
    _twistOffset = null;
    if (d.pointerCount > 1) _multiTouch = true;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final start = _gestureStart;
    if (start == null) return;
    var turn = 0.0;
    if (d.pointerCount > 1) {
      _multiTouch = true;
      if (_twistOffset == null && d.rotation.abs() > _twistSlop) {
        _twistOffset = d.rotation.sign * _twistSlop;
      }
      final offset = _twistOffset;
      if (offset != null) turn = d.rotation - offset;
    }
    final azimuth = start.azimuth + turn;
    final zoom = (start.zoom * d.scale).clamp(_minZoomAt(azimuth), _maxZoom);
    // Keep the plan point that was under the fingers under the fingers.
    final camera =
        _anchor - _untilt((d.localFocalPoint - _center) / zoom, azimuth);
    setState(() => _view = _clamp(_View(camera, zoom, azimuth)));
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _gestureStart = null;
    if (d.pointerCount > 0) return; // fingers still down; a new start follows
    final pinched = _multiTouch;
    _multiTouch = false;
    final v = _view;
    final velocity = d.velocity.pixelsPerSecond;
    final speed = velocity.distance;
    if (pinched || v == null || speed < 60) return;
    // A quick one-finger swipe keeps the map gliding for a moment.
    _flingFrom = v;
    _flingDirection = velocity / speed;
    _fling.animateWith(
      FrictionSimulation(
        0.02,
        0,
        speed,
        tolerance: const Tolerance(velocity: 10),
      ),
    );
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    // Mouse wheel and trackpad scroll zoom, handy on desktop and web.
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final scroll = e as PointerScrollEvent;
      final v = _view;
      if (v == null) return;
      _stopMotion();
      final anchor = _toPlane(v, scroll.localPosition);
      final zoom = (v.zoom * math.exp(-scroll.scrollDelta.dy / 300)).clamp(
        _minZoomAt(v.azimuth),
        _maxZoom,
      );
      final camera =
          anchor - _untilt((scroll.localPosition - _center) / zoom, v.azimuth);
      setState(() => _view = _clamp(_View(camera, zoom, v.azimuth)));
    });
  }

  bool _onShownFloor(MapNode n) =>
      widget.focusedFloor == null || n.floor == widget.focusedFloor;

  void _onTapUp(TapUpDetails d) {
    final onTap = widget.onNodeTap;
    final v = _view;
    if (onTap == null || v == null) return;
    MapNode? best;
    var bestDist = 26.0;
    for (final n in widget.graph.nodes) {
      if (!_onShownFloor(n)) continue;
      if (n.kind == 'hall') continue; // corridor points aren't places
      final dist =
          (_toScreen(v, Offset(n.x, n.y), n.floor) - d.localPosition).distance;
      if (dist < bestDist) {
        bestDist = dist;
        best = n;
      }
    }
    if (best != null) onTap(best);
  }

  // ------------------------------------------------------------ drawing

  /// Draws a plan image straight onto the map: plan pixel (x, y) lands where
  /// [_toScreen] says.
  Matrix4 _planMatrix(_View v, int floor) {
    final c = math.cos(v.azimuth), s = math.sin(v.azimuth);
    final k = widget.squash, z = v.zoom;
    final origin = _toScreen(v, Offset.zero, floor);
    return Matrix4(
      z * c,
      z * k * s,
      0,
      0, //
      -z * s,
      z * k * c,
      0,
      0,
      0,
      0,
      1,
      0,
      origin.dx,
      origin.dy,
      0,
      1,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.plans.isEmpty) {
      return const Center(child: Text('No floor plans loaded'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (!size.isFinite || size.isEmpty) return const SizedBox.expand();
        if (size != _viewport) _measure(size);
        return _buildMap(_view!);
      },
    );
  }

  Widget _buildMap(_View v) {
    final sorted = [...widget.plans]
      ..sort((a, b) => a.floor.compareTo(b.floor));

    return Listener(
      onPointerSignal: _onPointerSignal,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        onTapUp: _onTapUp,
        child: Stack(
          children: [
            for (final p in sorted)
              Positioned(
                left: 0,
                top: 0,
                child: Transform(
                  transform: _planMatrix(v, p.floor),
                  child: Opacity(
                    opacity:
                        widget.focusedFloor == null ||
                            widget.focusedFloor == p.floor
                        ? 1.0
                        : 0.22,
                    // No sheet behind the image: plans are transparent PNGs
                    // that carry their own walls and shadows.
                    child: SizedBox(
                      width: p.width,
                      height: p.height,
                      child: Image.asset(
                        p.asset,
                        width: p.width,
                        height: p.height,
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, _, _) => ColoredBox(
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
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _OverlayPainter(
                    graph: widget.graph,
                    project: (n) => _toScreen(v, Offset(n.x, n.y), n.floor),
                    view: v,
                    zoom: v.zoom,
                    routeIds: widget.routeIds,
                    originId: widget.originId,
                    destinationId: widget.destinationId,
                    focusedFloor: widget.focusedFloor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
const _routeBlue = Color(0xFF0866E8);
const _flagRed = Color(0xFFE5484D);
const _ink = Color(0xFF14251C);
const _markerSize = 30.0;

/// Labels and marker icons are laid out once and reused on every frame.
final _paintCache = <String, TextPainter>{};

TextPainter _label(String text, {required bool bold}) =>
    _paintCache.putIfAbsent(
      'label:$bold:$text',
      () => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: _ink,
            fontSize: 10.5,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: 110),
    );

TextPainter _icon(IconData icon, Color color, {bool halo = false}) =>
    _paintCache.putIfAbsent(
      'icon:${icon.codePoint}:${color.toARGB32()}:$halo',
      () => TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: _markerSize,
            height: 1,
            color: halo ? null : color,
            foreground: halo
                ? (Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 4
                    ..strokeJoin = StrokeJoin.round
                    ..color = Colors.white)
                : null,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );

/// A pin or flag drawn at a node: [tip] is where on the icon, as a fraction
/// of its size, touches the node.
typedef _Marker = ({MapNode node, IconData icon, Color color, Offset tip});

class _OverlayPainter extends CustomPainter {
  final CampusGraph graph;
  final Offset Function(MapNode) project;

  /// Changes whenever the map moves, so the overlay repaints with it.
  final Object view;
  final double zoom;
  final List<String> routeIds;
  final String? originId;
  final String? destinationId;
  final int? focusedFloor;

  _OverlayPainter({
    required this.graph,
    required this.project,
    required this.view,
    required this.zoom,
    required this.routeIds,
    this.originId,
    this.destinationId,
    this.focusedFloor,
  });

  bool _visible(MapNode n) => focusedFloor == null || n.floor == focusedFloor;

  @override
  void paint(Canvas canvas, Size size) {
    final byId = {for (final n in graph.nodes) n.id: n};
    final at = {for (final n in graph.nodes) n.id: project(n)};
    final area = (Offset.zero & size).inflate(60);
    // Dots shrink a little when zoomed far out, so small rooms stay readable.
    final dot = 4.0 + 2.0 * ((zoom - 0.3) / 0.5).clamp(0.0, 1.0);

    Paint stroke(Color color, double width) => Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // corridors
    final corridor = stroke(const Color(0x55C6D2C8), 3);
    for (final e in graph.edges) {
      final a = byId[e.from], b = byId[e.to];
      if (a == null || b == null) continue;
      if (!_visible(a) || !_visible(b)) continue;
      if (a.floor != b.floor) continue;
      canvas.drawLine(at[a.id]!, at[b.id]!, corridor);
    }

    // route: every halo first, then the line, so joints stay clean
    final route = routeIds.map((id) => byId[id]).whereType<MapNode>().toList();
    final legs = <(Offset, Offset, bool)>[];
    for (var i = 0; i < route.length - 1; i++) {
      final a = route[i], b = route[i + 1];
      if (focusedFloor != null &&
          (a.floor != focusedFloor && b.floor != focusedFloor)) {
        continue;
      }
      legs.add((at[a.id]!, at[b.id]!, a.floor != b.floor));
    }
    final halo = stroke(Colors.white, 10);
    for (final (a, b, _) in legs) {
      canvas.drawLine(a, b, halo);
    }
    final line = stroke(_routeBlue, 6);
    for (final (a, b, floorChange) in legs) {
      if (floorChange) {
        _dashed(canvas, a, b, line, 10, 7); // the stair or lift hop
      } else {
        canvas.drawLine(a, b, line);
      }
    }

    final onRoute = routeIds.toSet();
    final labels = <(MapNode, Offset, int)>[]; // node, where, rank (0 first)

    // nodes
    for (final n in graph.nodes) {
      if (!_visible(n)) continue;
      final p = at[n.id]!;
      if (!area.contains(p)) continue;
      if (n.id == originId || n.id == destinationId) continue; // markers
      final lit = onRoute.contains(n.id);

      if (n.isTransit) {
        if (lit) {
          // Corridor points disappear into the line; stairs and lifts stay.
          if (n.kind != 'hall') {
            canvas.drawCircle(p, 7, Paint()..color = Colors.white);
            canvas.drawCircle(p, 4.5, Paint()..color = _routeBlue);
          }
          continue;
        }
        if (n.kind == 'hall' && zoom < 0.6) continue;
        canvas.drawCircle(
          p,
          n.kind == 'hall' ? 3 : 4.5,
          Paint()..color = const Color(0x889AA79C),
        );
        continue;
      }

      final r = lit ? dot + 1 : dot;
      canvas.drawCircle(p, r + 2.5, Paint()..color = Colors.white);
      canvas.drawCircle(
        p,
        r,
        Paint()..color = lit ? _routeBlue : (_kindColor[n.kind] ?? _ink),
      );
      labels.add((n, p, lit ? 1 : 2));
    }

    // Markers claim their space first, so no label covers them.
    final markers = <_Marker>[
      if (byId[originId] case final n? when _visible(n))
        (
          node: n,
          icon: Icons.location_on,
          color: _routeBlue,
          tip: const Offset(0.5, 0.92),
        ),
      if (byId[destinationId] case final n? when _visible(n))
        (
          node: n,
          icon: Icons.flag,
          color: _flagRed,
          tip: const Offset(0.25, 0.875),
        ),
    ];
    final taken = <Rect>[];
    for (final m in markers) {
      final topLeft = at[m.node.id]! - m.tip * _markerSize;
      taken.add(topLeft & const Size(_markerSize, _markerSize));
      labels.add((m.node, at[m.node.id]!, 0));
    }

    // Labels go in order of importance and skip any spot already used, so
    // zooming in shows more names instead of a pile of overlapping ones.
    labels.sort((a, b) => a.$3.compareTo(b.$3));
    for (final (n, p, rank) in labels) {
      final tp = _label(n.name, bold: rank < 2);
      final box = Rect.fromLTWH(
        p.dx - tp.width / 2 - 4,
        p.dy + 9,
        tp.width + 8,
        tp.height + 4,
      );
      if (taken.any(box.overlaps)) continue;
      taken.add(box);
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(5)),
        Paint()..color = const Color(0xE6FFFFFF),
      );
      tp.paint(canvas, Offset(box.left + 4, box.top + 2));
    }

    for (final m in markers) {
      final p = at[m.node.id]!;
      canvas.drawCircle(p, 5.5, Paint()..color = Colors.white);
      canvas.drawCircle(p, 3.5, Paint()..color = m.color);
      final topLeft = p - m.tip * _markerSize;
      _icon(m.icon, m.color, halo: true).paint(canvas, topLeft);
      _icon(m.icon, m.color).paint(canvas, topLeft);
    }
  }

  void _dashed(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint,
    double dash,
    double gap,
  ) {
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

  @override
  bool shouldRepaint(covariant _OverlayPainter old) =>
      old.view != view ||
      old.graph != graph ||
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
//    final map = CampusMapController();
//
//    TiltedCampusMap(
//      graph: graph,
//      controller: map,
//      plans: const [
//        FloorPlan(floor: 4, asset: 'assets/floorplans/floor_4.png', width: 1216, height: 864),
//        FloorPlan(floor: 5, asset: 'assets/floorplans/floor_5.png', width: 1216, height: 864),
//      ],
//      routeIds: const ['main_gate', 'mb_lobby', 'mb_stairs_1', 'mb_stairs_2', 'registrar'],
//      originId: 'main_gate',
//      destinationId: 'registrar',
//      onNodeTap: (n) => debugPrint('tapped ${n.name}'),
//    );
//
//    map.centerOn('main_gate', zoom: 1.3); // glide to where the walk starts
//
// 3. width and height must be the image's real pixel size — the node editor
//    prints it when you load a plan. Wrong numbers put every dot in the wrong
//    place, and it is the first thing to check if the overlay looks shifted.
//
// 4. Export the graph UNCALIBRATED (scale 1) so x and y stay in image pixels,
//    which is what this widget expects. Calibrate only if you want the backend
//    reporting metres, and in that case divide by scale_m_per_px when loading.
