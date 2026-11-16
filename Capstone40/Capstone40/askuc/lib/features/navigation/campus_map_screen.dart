import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../widgets/tilted_campus_map.dart';
import 'pathway_tree.dart';

/// Campus Map tab: the 2.5D map on top, then the starting point, destination
/// and GENERATE ROUTE, laid out like the first Map tab design.
///
/// Generating a route draws the optimized connected pathway and glides the
/// map to the starting point, the way Google Maps does when directions start.

class _Palette {
  static const bg = Color(0xFFF8FAFC);
  static const title = Color(0xFF20262D);
  static const text = Color(0xFF34454F);
  static const muted = Color(0xFF8A969E);
  static const hint = Color(0xFF9AA6AE);
  static const border = Color(0xFFD1E0E7);
  static const blue = Color(0xFF0866E8);
  static const mapBg = Color(0xFFE0EAF3);
  static const chevron = Color(0xFF657984);
  static const iconBg = Color(0xFFE8F0FE);
}

/// Zoom, in screen pixels per plan pixel, when a route starts: about five
/// rooms across the map.
const _routeZoom = 1.3;

/// Zoom used to show a place picked in a field, unless already closer.
const _placeZoom = 0.8;

enum _End { start, destination }

class CampusMapScreen extends StatefulWidget {
  final CampusGraph graph;
  final List<FloorPlan> plans;

  /// The pathways over [graph] (Prim's, one tree per floor), built by
  /// whoever loads the graph. New pathways, e.g. after stairs close, redo a
  /// pathway on show.
  final FloorPathways pathways;

  /// Stairs and elevator stops, and doors, an admin closed. [pathways]
  /// already routes around them; the map and the place lists mark them.
  final Set<String> closedIds;

  /// What the admin wrote about each closure, by id, e.g. "Use the library's
  /// 3F entrance". Shown when a closure leaves no way through.
  final Map<String, String> closureReasons;

  /// Called each time a pathway is shown, e.g. to record the search.
  final void Function(MapNode from, MapNode to)? onRouteShown;

  /// Shows a close button in the app bar when set.
  final VoidCallback? onBack;

  const CampusMapScreen({
    super.key,
    required this.graph,
    required this.plans,
    required this.pathways,
    this.closedIds = const {},
    this.closureReasons = const {},
    this.onRouteShown,
    this.onBack,
  });

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  final _map = CampusMapController();
  MapNode? _start;
  MapNode? _destination;
  List<String> _routeIds = const [];

  late final List<int> _floors =
      widget.plans.map((p) => p.floor).toSet().toList()..sort();

  /// The floor on show; null shows every floor stacked. Starts on the lowest.
  late int? _focusedFloor = _floors.firstOrNull;

  /// Set once GENERATE ROUTE is pressed with a field still empty, so the
  /// empty fields say what they need.
  bool _showMissing = false;

  /// Every place a student can start from or go to. Corridor points are left
  /// out; stairs and elevators stay, since students often stand at them.
  late final List<MapNode> _places =
      widget.graph.nodes.where((n) => n.kind != 'hall').toList()..sort(
        (a, b) => a.floor == b.floor
            ? a.name.compareTo(b.name)
            : a.floor.compareTo(b.floor),
      );

  /// Stairs, an elevator or a door closed or reopened while a pathway is on
  /// show: works the pathway out again, so it never goes through one closed.
  @override
  void didUpdateWidget(CampusMapScreen old) {
    super.didUpdateWidget(old);
    final from = _start;
    final to = _destination;
    if (widget.pathways == old.pathways ||
        _routeIds.isEmpty ||
        from == null ||
        to == null) {
      return;
    }

    final route = widget.pathways.route(from.id, to.id);
    if (listEquals(route, _routeIds)) return;
    final closedOnRoute = _routeIds.where(widget.closedIds.contains).toList();
    _routeIds = route; // build() runs right after this
    final message = closedOnRoute.isEmpty
        ? 'Stairs, an elevator or a door reopened. Showing an updated '
              'pathway.'
        : route.isEmpty
        ? '${_name(closedOnRoute.first)} on your pathway closed, and no '
              'other pathway is open right now.${_reasons(closedOnRoute)}'
        : '${_name(closedOnRoute.first)} on your pathway closed. Showing '
              'another pathway.';
    // A snackbar can't be shown in the middle of a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _say(message);
    });
  }

  Future<void> _pick(_End end) async {
    final place = await showModalBottomSheet<MapNode>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _PlaceSheet(
        title: end == _End.start
            ? 'Select starting point'
            : 'Select destination',
        places: _places,
        closedIds: widget.closedIds,
        closureReasons: widget.closureReasons,
        selected: end == _End.start ? _start : _destination,
      ),
    );
    if (place == null || !mounted) return;
    final whyNot = _whyNot(place);
    if (whyNot != null) {
      _say(whyNot);
      return;
    }
    _choose(end, place);
  }

  /// Every node with at least one link. A place without one, such as GATE 1
  /// (PARKING ENTRANCE), which is for cars, is on no walkway.
  late final Set<String> _linked = {
    for (final e in widget.graph.edges) ...[e.from, e.to],
  };

  /// Why [place] can't be a starting point or destination, or null if it
  /// can: it's closed, or no walkway reaches it.
  String? _whyNot(MapNode place) {
    if (widget.closedIds.contains(place.id)) {
      return '${place.name} is closed.${_reasons([place.id])}';
    }
    if (!_linked.contains(place.id)) {
      return place.name.toLowerCase().contains('parking')
          ? '${place.name} is a parking entrance.'
          : "${place.name} isn't on a walkway on the map yet.";
    }
    return null;
  }

  void _choose(_End end, MapNode place) {
    setState(() {
      if (end == _End.start) {
        _start = place;
      } else {
        _destination = place;
      }
      _routeIds = const []; // the drawn pathway no longer matches the fields
      _focusedFloor = place.floor;
    });
    _map.centerOn(place.id, zoom: math.max(_map.zoom, _placeZoom));
  }

  /// Tapping a place on the map offers it as the start or the destination.
  /// Something closed or on no walkway can't be picked; the tap says why
  /// instead.
  Future<void> _onNodeTap(MapNode place) async {
    final whyNot = _whyNot(place);
    if (whyNot != null) {
      _say(whyNot);
      return;
    }
    final end = await showModalBottomSheet<_End>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _PlaceActions(place: place),
    );
    if (end == null || !mounted) return;
    _choose(end, place);
  }

  /// Shows the optimized connected pathway from [_start] to [_destination].
  void _generateRoute() {
    final from = _start;
    final to = _destination;
    if (from == null || to == null) {
      // Said under the empty fields, where a snackbar would cover them.
      setState(() => _showMissing = true);
      return;
    }
    if (from.id == to.id) {
      _say('Your starting point and destination are the same place.');
      return;
    }

    final route = widget.pathways.route(from.id, to.id);
    if (route.isEmpty) {
      // Say which closure is in the way, e.g. a locked door that was the
      // only way in, with what the admin wrote about it.
      final inTheWay = widget.pathways.closedOnTheWay(from.id, to.id);
      _say(
        inTheWay.isNotEmpty
            ? 'No open pathway right now: ${_names(inTheWay)} '
                  '${inTheWay.length == 1 ? 'is' : 'are'} closed.'
                  '${_reasons(inTheWay)}'
            : widget.closedIds.isEmpty
            ? 'No connected pathway between these places yet.'
            : 'No open pathway between these places right now. Some stairs, '
                  'elevators or doors are closed.',
      );
      return;
    }
    setState(() {
      _routeIds = route;
      _focusedFloor = from.floor;
    });
    widget.onRouteShown?.call(from, to);
    // Like starting directions in Google Maps: glide to where the walk begins.
    _map.centerOn(from.id, zoom: _routeZoom);
  }

  void _recenter() {
    final from = _start;
    if (from == null) return;
    setState(() => _focusedFloor = from.floor);
    _map.centerOn(from.id, zoom: _routeZoom);
  }

  List<MapNode> get _route => [
    for (final id in _routeIds) ?widget.graph.byId(id),
  ];

  /// Shows [floor], or every floor when null. On a floor the route crosses,
  /// the map goes to where the route reaches that floor.
  void _showFloor(int? floor) {
    setState(() => _focusedFloor = floor);
    if (floor == null) return;
    final arrival = _route.where((n) => n.floor == floor).firstOrNull;
    if (arrival != null) {
      _map.centerOn(arrival.id, zoom: math.max(_map.zoom, _placeZoom));
    }
  }

  String _name(String id) => widget.graph.byId(id)?.name ?? id;

  /// e.g. "4F Library Door Entrance" or "5F Stairs 1 and 6F Stairs 1".
  String _names(List<String> ids) {
    final names = [for (final id in ids) _name(id)];
    return names.length == 1
        ? names.single
        : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  }

  /// What the admin wrote about [ids], as sentences after a leading space,
  /// e.g. " Use the library's 3F entrance."; '' if they wrote nothing.
  String _reasons(List<String> ids) => [
    for (final reason in {
      for (final id in ids) widget.closureReasons[id]?.trim() ?? '',
    })
      if (reason.isNotEmpty)
        ' $reason${RegExp(r'[.!?]$').hasMatch(reason) ? '' : '.'}',
  ].join();

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    // Where the route leaves the floor on show, if it does.
    final change = floorChanges(
      _route,
    ).where((c) => c.from.floor == _focusedFloor).firstOrNull;

    final map = _MapCard(
      graph: widget.graph,
      plans: widget.plans,
      controller: _map,
      focusedFloor: _focusedFloor,
      start: _start,
      destination: _destination,
      routeIds: _routeIds,
      closedIds: widget.closedIds,
      floors: _floors,
      onFloorChanged: _showFloor,
      onNodeTap: _onNodeTap,
      onRecenter: _routeIds.isEmpty ? null : _recenter,
      hint: change == null
          ? null
          : _FloorHint(
              change: change,
              onTap: () => _showFloor(change.to.floor),
            ),
    );
    final panel = _RoutePanel(
      start: _start,
      destination: _destination,
      showMissing: _showMissing,
      onPickStart: () => _pick(_End.start),
      onPickDestination: () => _pick(_End.destination),
      onGenerate: _generateRoute,
    );
    const subtitle = Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Text(
        'Find your destination',
        style: TextStyle(color: _Palette.muted, fontSize: 11),
      ),
    );

    return Scaffold(
      backgroundColor: _Palette.bg,
      appBar: AppBar(
        backgroundColor: _Palette.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: widget.onBack == null
            ? null
            : IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.close, color: _Palette.title),
                tooltip: 'Back',
              ),
        title: const Text(
          'Campus Map',
          style: TextStyle(
            color: _Palette.title,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        top: false, // the app bar already clears the status bar
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Short screens scroll instead, with the map at a fixed height.
            if (constraints.maxHeight < 520) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    subtitle,
                    SizedBox(height: 272, child: map),
                    const SizedBox(height: 14),
                    panel,
                  ],
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                subtitle,
                Expanded(child: map),
                const SizedBox(height: 14),
                panel,
              ],
            );
          },
        ),
      ),
    );
  }
}

/* ----------------------------------------------------------- map card */

class _MapCard extends StatelessWidget {
  final CampusGraph graph;
  final List<FloorPlan> plans;
  final CampusMapController controller;
  final int? focusedFloor;
  final MapNode? start;
  final MapNode? destination;
  final List<String> routeIds;
  final Set<String> closedIds;
  final List<int> floors;
  final ValueChanged<int?> onFloorChanged;
  final ValueChanged<MapNode> onNodeTap;

  /// Glides back to the starting point; the button shows only when set.
  final VoidCallback? onRecenter;

  /// Shown in the bottom-left corner, e.g. which stairs to take next.
  final Widget? hint;

  const _MapCard({
    required this.graph,
    required this.plans,
    required this.controller,
    required this.focusedFloor,
    required this.start,
    required this.destination,
    required this.routeIds,
    required this.closedIds,
    required this.floors,
    required this.onFloorChanged,
    required this.onNodeTap,
    required this.onRecenter,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final recenter = onRecenter;
    final hint = this.hint;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _Palette.mapBg,
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: TiltedCampusMap(
                graph: graph,
                plans: plans,
                controller: controller,
                focusedFloor: focusedFloor,
                routeIds: routeIds,
                closedIds: closedIds,
                originId: start?.id,
                destinationId: destination?.id,
                onNodeTap: onNodeTap,
              ),
            ),
            if (floors.length > 1)
              Positioned(
                right: 10,
                top: 10,
                child: _FloorPicker(
                  floors: floors,
                  value: focusedFloor,
                  onChanged: onFloorChanged,
                ),
              ),
            if (recenter != null)
              Positioned(
                right: 10,
                bottom: 10,
                child: Tooltip(
                  message: 'Back to starting point',
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: recenter,
                      child: const SizedBox(
                        width: 42,
                        height: 42,
                        child: Icon(
                          Icons.my_location_rounded,
                          color: _Palette.blue,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (hint != null)
              Positioned(
                left: 10,
                right: 62, // clear of the starting-point button
                bottom: 10,
                child: Align(alignment: Alignment.bottomLeft, child: hint),
              ),
          ],
        ),
      ),
    );
  }
}

/// Which stairs or lift the route takes off the floor on show. Tapping it
/// shows the floor where the walk carries on.
class _FloorHint extends StatelessWidget {
  final FloorChange change;
  final VoidCallback onTap;
  const _FloorHint({required this.change, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final up = change.to.floor > change.from.floor;
    // "5F Stairs 3 Near Gate 2" reads as "Stairs 3 Near Gate 2" here.
    final via = change.from.name.replaceFirst(RegExp(r'^\d+F\s+'), '');

    return Material(
      color: _Palette.blue,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                change.from.kind == 'elevator'
                    ? Icons.elevator_outlined
                    : Icons.stairs_outlined,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Take $via ${up ? 'up' : 'down'} to ${floorLabel(change.to.floor)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloorPicker extends StatelessWidget {
  final List<int> floors;
  final int? value;
  final ValueChanged<int?> onChanged;
  const _FloorPicker({
    required this.floors,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget pill(String text, bool on, VoidCallback onTap) => Material(
      color: on ? _Palette.blue : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 28,
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: on ? Colors.white : _Palette.text,
            ),
          ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _Palette.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          pill('All', value == null, () => onChanged(null)),
          for (final f in floors.reversed) ...[
            const SizedBox(height: 3),
            pill(floorLabel(f), value == f, () => onChanged(f)),
          ],
        ],
      ),
    );
  }
}

/* ----------------------------------------------------------- route panel */

class _RoutePanel extends StatelessWidget {
  final MapNode? start;
  final MapNode? destination;

  /// Whether empty fields say they need filling.
  final bool showMissing;
  final VoidCallback onPickStart;
  final VoidCallback onPickDestination;
  final VoidCallback onGenerate;

  const _RoutePanel({
    required this.start,
    required this.destination,
    required this.showMissing,
    required this.onPickStart,
    required this.onPickDestination,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(
      color: _Palette.text,
      fontSize: 11,
      fontWeight: FontWeight.w500,
    );

    return Material(
      color: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Starting Point', style: label),
            const SizedBox(height: 7),
            _PlaceField(
              place: start,
              hint: 'Select starting point',
              icon: Icons.location_on,
              error: showMissing && start == null
                  ? 'Please choose a starting point.'
                  : null,
              onTap: onPickStart,
            ),
            const SizedBox(height: 13),
            const Text('Destination', style: label),
            const SizedBox(height: 7),
            _PlaceField(
              place: destination,
              hint: 'Select destination',
              icon: Icons.flag,
              error: showMissing && destination == null
                  ? 'Please choose a destination.'
                  : null,
              onTap: onPickDestination,
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: onGenerate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _Palette.blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'GENERATE ROUTE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Looks like a dropdown; opens a searchable list, since a floor has too many
/// places for a plain dropdown menu.
class _PlaceField extends StatelessWidget {
  final MapNode? place;
  final String hint;
  final IconData icon;

  /// Shown in red under the field when set.
  final String? error;
  final VoidCallback onTap;

  const _PlaceField({
    required this.place,
    required this.hint,
    required this.icon,
    required this.onTap,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder outline(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        isEmpty: place == null,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _Palette.hint, fontSize: 10),
          prefixIcon: Icon(icon, color: _Palette.blue, size: 19),
          suffixIcon: const Icon(
            Icons.keyboard_arrow_down,
            color: _Palette.chevron,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 11,
          ),
          errorText: error,
          errorStyle: const TextStyle(fontSize: 10),
          border: outline(_Palette.border),
          enabledBorder: outline(_Palette.border),
          errorBorder: outline(Theme.of(context).colorScheme.error),
        ),
        child: Text(
          place?.name ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _Palette.text, fontSize: 11),
        ),
      ),
    );
  }
}

/* ----------------------------------------------------------- sheets */

/// Picks a starting point or destination: a dropdown for each floor, top
/// floor first, listing the floor's places by kind. Searching keeps only the
/// floors with a match, opened.
class _PlaceSheet extends StatefulWidget {
  final String title;
  final List<MapNode> places;

  /// Closed places are listed but can't be picked.
  final Set<String> closedIds;
  final Map<String, String> closureReasons;
  final MapNode? selected;

  const _PlaceSheet({
    required this.title,
    required this.places,
    required this.closedIds,
    required this.closureReasons,
    required this.selected,
  });

  @override
  State<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<_PlaceSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.places
        : widget.places
              .where(
                (n) =>
                    n.name.toLowerCase().contains(q) ||
                    n.building.toLowerCase().contains(q),
              )
              .toList();
    final floors = {for (final n in shown) n.floor}.toList()
      ..sort((a, b) => b.compareTo(a)); // top floor first
    final screen = MediaQuery.sizeOf(context).height;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return SizedBox(
      height: math.min(screen * 0.7 + keyboard, screen * 0.92),
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                widget.title,
                style: const TextStyle(
                  color: _Palette.title,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: _Palette.text, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search a room, office or lab',
                  hintStyle: const TextStyle(
                    color: _Palette.hint,
                    fontSize: 12,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: _Palette.chevron,
                    size: 20,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _Palette.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: _Palette.blue,
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? const _Empty(
                      text: 'Nothing matches that. Try a shorter word.',
                    )
                  : ListView.separated(
                      // A new list for each search, so its results start
                      // at the top rather than where the last list was.
                      key: ValueKey(q),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: floors.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final floor = floors[i];
                        return _FloorGroup(
                          // Each search starts with its floors opened.
                          key: ValueKey('$floor/$q'),
                          floor: floor,
                          places: [
                            for (final n in shown)
                              if (n.floor == floor) n,
                          ],
                          searching: q.isNotEmpty,
                          open: q.isNotEmpty || widget.selected?.floor == floor,
                          selectedId: widget.selected?.id,
                          closedIds: widget.closedIds,
                          closureReasons: widget.closureReasons,
                          onPick: (n) => Navigator.pop(context, n),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The headings a floor's places are listed under, in this order.
const _sections = <(String, Set<String>)>[
  ('Classrooms', {'classroom'}),
  ('Labs', {'lab'}),
  ('Offices', {'office'}),
  ('Facilities', {'facility'}),
  ('Restrooms', {'restroom'}),
  ('Entrances', {'entrance'}),
  ('Stairs and elevators', {'stairs', 'elevator'}),
];

/// One floor in a place list: a dropdown of the floor's places, under
/// headings such as Classrooms and Labs.
class _FloorGroup extends StatelessWidget {
  final int floor;
  final List<MapNode> places;

  /// Whether [places] are search matches rather than the whole floor.
  final bool searching;

  /// Whether the dropdown starts opened.
  final bool open;
  final String? selectedId;
  final Set<String> closedIds;
  final Map<String, String> closureReasons;
  final ValueChanged<MapNode> onPick;

  const _FloorGroup({
    super.key,
    required this.floor,
    required this.places,
    required this.searching,
    required this.open,
    required this.selectedId,
    required this.closedIds,
    required this.closureReasons,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final count = places.length;
    final holdsSelected = places.any((n) => n.id == selectedId);
    bool listed(MapNode n) => _sections.any((s) => s.$2.contains(n.kind));
    final sections = [
      for (final (heading, kinds) in _sections)
        (
          heading,
          [
            for (final n in places)
              if (kinds.contains(n.kind)) n,
          ],
        ),
      (
        'Other places',
        [
          for (final n in places)
            if (!listed(n)) n,
        ],
      ),
    ];

    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: holdsSelected ? _Palette.blue : _Palette.border,
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: open,
        // An opened floor slides up to the top of the list, so its places
        // show even when it was near the bottom.
        onExpansionChanged: (opened) {
          if (!opened) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            Scrollable.ensureVisible(
              context,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          });
        },
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
        childrenPadding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        iconColor: _Palette.blue,
        collapsedIconColor: _Palette.chevron,
        leading: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _Palette.iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            floorLabel(floor),
            style: const TextStyle(
              color: _Palette.blue,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: Text(
          floorName(floor),
          style: const TextStyle(
            color: _Palette.title,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          searching
              ? '$count ${count == 1 ? 'match' : 'matches'}'
              : '$count ${count == 1 ? 'place' : 'places'}',
          style: const TextStyle(color: _Palette.muted, fontSize: 11),
        ),
        children: [
          for (final (heading, items) in sections)
            if (items.isNotEmpty) ...[
              _SectionLabel(heading),
              for (final n in items..sort((a, b) => _byName(a.name, b.name)))
                _PlaceRow(
                  place: n,
                  selected: n.id == selectedId,
                  closed: closedIds.contains(n.id),
                  reason: closureReasons[n.id] ?? '',
                  onTap: () => onPick(n),
                ),
            ],
        ],
      ),
    );
  }
}

/// A heading inside a floor's dropdown, e.g. "CLASSROOMS".
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: _Palette.muted,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// A place in a floor's dropdown. A closed one is greyed out with a lock,
/// says why, and can't be picked.
class _PlaceRow extends StatelessWidget {
  final MapNode place;
  final bool selected;
  final bool closed;

  /// What the admin wrote about the closure.
  final String reason;
  final VoidCallback onTap;

  const _PlaceRow({
    required this.place,
    required this.selected,
    required this.closed,
    required this.reason,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final why = reason.trim();
    return InkWell(
      onTap: closed ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: closed ? _Palette.bg : _Palette.iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _iconFor(place),
                color: closed ? _Palette.hint : _Palette.blue,
                size: 17,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: closed
                          ? _Palette.muted
                          : selected
                          ? _Palette.blue
                          : _Palette.title,
                    ),
                  ),
                  if (closed)
                    Text(
                      why.isEmpty ? 'Closed' : 'Closed · $why',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _Palette.muted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded, color: _Palette.blue, size: 20)
            else if (closed)
              const Icon(
                Icons.lock_outline_rounded,
                color: _Palette.chevron,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

/// Orders names the way people count, so "Room 9" comes before "Room 10".
int _byName(String a, String b) {
  final chunk = RegExp(r'\d+|\D+');
  final x = [for (final m in chunk.allMatches(a.toLowerCase())) m[0]!];
  final y = [for (final m in chunk.allMatches(b.toLowerCase())) m[0]!];
  for (var i = 0; i < x.length && i < y.length; i++) {
    final p = int.tryParse(x[i]), q = int.tryParse(y[i]);
    final c = p != null && q != null ? p.compareTo(q) : x[i].compareTo(y[i]);
    if (c != 0) return c;
  }
  return x.length.compareTo(y.length);
}

/// What to do with an open place tapped on the map.
class _PlaceActions extends StatelessWidget {
  final MapNode place;
  const _PlaceActions({required this.place});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              place.name,
              style: const TextStyle(
                color: _Palette.title,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _whereIs(place),
              style: const TextStyle(color: _Palette.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _Row(
              icon: Icons.location_on,
              title: 'Set as starting point',
              subtitle: 'Start the pathway here',
              onTap: () => Navigator.pop(context, _End.start),
            ),
            const SizedBox(height: 8),
            _Row(
              icon: Icons.flag,
              title: 'Set as destination',
              subtitle: 'End the pathway here',
              onTap: () => Navigator.pop(context, _End.destination),
            ),
          ],
        ),
      ),
    );
  }
}

/* ----------------------------------------------------------- lists */

/// e.g. "Main Building · Floor 5" or "Main Building · Mezzanine".
String _whereIs(MapNode n) => '${n.building} · ${floorName(n.floor)}';

IconData _iconFor(MapNode n) => switch (n.kind) {
  'lab' => Icons.science_outlined,
  'classroom' => Icons.chair_alt_outlined,
  'facility' => Icons.local_cafe_outlined,
  'restroom' => Icons.wc_rounded,
  'stairs' => Icons.stairs_outlined,
  'elevator' => Icons.elevator_outlined,
  'entrance' => Icons.door_front_door_outlined,
  _ => Icons.meeting_room_outlined,
};

/// A choice in the sheet that opens when a place on the map is tapped.
class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _Palette.border),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _Palette.iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _Palette.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _Palette.title,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _Palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _Palette.chevron),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _Palette.muted, height: 1.45),
        ),
      ),
    );
  }
}
