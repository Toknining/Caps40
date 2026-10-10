import 'dart:math' as math;

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

  /// Prim's pathway tree over [graph], built once by whoever loads the graph.
  final PathwayTree pathways;

  /// Called each time a pathway is shown, e.g. to record the search.
  final void Function(MapNode from, MapNode to)? onRouteShown;

  /// Shows a close button in the app bar when set.
  final VoidCallback? onBack;

  const CampusMapScreen({
    super.key,
    required this.graph,
    required this.plans,
    required this.pathways,
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
  int? _focusedFloor;
  List<String> _routeIds = const [];

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
        selected: end == _End.start ? _start : _destination,
      ),
    );
    if (place == null || !mounted) return;
    _choose(end, place);
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
  Future<void> _onNodeTap(MapNode place) async {
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
      _say('No connected pathway between these places yet.');
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
    if (from != null) _map.centerOn(from.id, zoom: _routeZoom);
  }

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    final floors = widget.plans.map((p) => p.floor).toSet().toList()..sort();

    final map = _MapCard(
      graph: widget.graph,
      plans: widget.plans,
      controller: _map,
      focusedFloor: _focusedFloor,
      start: _start,
      destination: _destination,
      routeIds: _routeIds,
      floors: floors,
      onFloorChanged: (f) => setState(() => _focusedFloor = f),
      onNodeTap: _onNodeTap,
      onRecenter: _routeIds.isEmpty ? null : _recenter,
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
  final List<int> floors;
  final ValueChanged<int?> onFloorChanged;
  final ValueChanged<MapNode> onNodeTap;

  /// Glides back to the starting point; the button shows only when set.
  final VoidCallback? onRecenter;

  const _MapCard({
    required this.graph,
    required this.plans,
    required this.controller,
    required this.focusedFloor,
    required this.start,
    required this.destination,
    required this.routeIds,
    required this.floors,
    required this.onFloorChanged,
    required this.onNodeTap,
    required this.onRecenter,
  });

  @override
  Widget build(BuildContext context) {
    final recenter = onRecenter;
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
          ],
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
            pill('$f', value == f, () => onChanged(f)),
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

class _PlaceSheet extends StatefulWidget {
  final String title;
  final List<MapNode> places;
  final MapNode? selected;

  const _PlaceSheet({
    required this.title,
    required this.places,
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
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: shown.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final n = shown[i];
                        return _Row(
                          icon: _iconFor(n),
                          title: n.name,
                          subtitle: '${n.building} · Floor ${n.floor}',
                          selected: n.id == widget.selected?.id,
                          onTap: () => Navigator.pop(context, n),
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

/// What to do with a place tapped on the map.
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
              '${place.building} · Floor ${place.floor}',
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

IconData _iconFor(MapNode n) => switch (n.kind) {
  'lab' => Icons.science_outlined,
  'classroom' => Icons.chair_alt_outlined,
  'facility' => Icons.local_cafe_outlined,
  'restroom' => Icons.wc_rounded,
  'stairs' => Icons.stairs_outlined,
  'elevator' => Icons.elevator_outlined,
  _ => Icons.meeting_room_outlined,
};

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.selected = false,
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
            border: Border.all(
              color: selected ? _Palette.blue : _Palette.border,
            ),
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
              Icon(
                selected ? Icons.check_rounded : Icons.chevron_right_rounded,
                color: selected ? _Palette.blue : _Palette.chevron,
              ),
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
