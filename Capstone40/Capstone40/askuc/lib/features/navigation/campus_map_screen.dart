import 'package:flutter/material.dart';

import '../../widgets/tilted_campus_map.dart';
import 'pathway_tree.dart';

/// Campus Map screen — the build of storyboard Figure 23.
///
/// Blue header, search, category chips, the tilted map, then the building list.
/// Drop it in lib/features/navigation/ and push it from your Map tab.

class AskUcColors {
  static const blue = Color(0xFF1565D8);
  static const blueDark = Color(0xFF0D47A1);
  static const bg = Color(0xFFF4F6F9);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF16202B);
  static const muted = Color(0xFF6B7A8C);
  static const hairline = Color(0xFFE3E8EF);
}

enum PlaceFilter { all, academic, service, admin }

extension on PlaceFilter {
  String get label => switch (this) {
    PlaceFilter.all => 'All',
    PlaceFilter.academic => 'Academic',
    PlaceFilter.service => 'Service',
    PlaceFilter.admin => 'Admin',
  };

  bool matches(MapNode n) => switch (this) {
    PlaceFilter.all => true,
    PlaceFilter.academic => n.kind == 'lab' || n.kind == 'classroom',
    PlaceFilter.service => n.kind == 'facility' || n.kind == 'restroom',
    PlaceFilter.admin => n.kind == 'office',
  };
}

class CampusMapScreen extends StatefulWidget {
  final CampusGraph graph;
  final List<FloorPlan> plans;

  /// Prim's pathway tree over [graph], built once by whoever loads the graph.
  final PathwayTree pathways;

  /// Called each time a pathway is shown, e.g. to record the search.
  final void Function(MapNode from, MapNode to)? onRouteShown;

  /// Shows a back arrow in the header when set.
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
  final _search = TextEditingController();
  final _mapController = TransformationController();
  PlaceFilter _filter = PlaceFilter.all;
  String _query = '';
  int? _focusedFloor;
  MapNode? _selected;
  MapNode? _origin;
  List<String> _routeIds = const [];

  @override
  void dispose() {
    _search.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Buildings, with how many floors each one has.
  List<({String name, int floors, int rooms})> get _buildings {
    final map = <String, Set<int>>{};
    final counts = <String, int>{};
    for (final n in widget.graph.nodes) {
      if (n.isTransit) continue;
      final b = n.building.isEmpty ? 'Campus' : n.building;
      map.putIfAbsent(b, () => <int>{}).add(n.floor);
      counts[b] = (counts[b] ?? 0) + 1;
    }
    final out = map.entries
        .map(
          (e) =>
              (name: e.key, floors: e.value.length, rooms: counts[e.key] ?? 0),
        )
        .toList();
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  List<MapNode> get _matchingRooms {
    final q = _query.toLowerCase().trim();
    return widget.graph.nodes.where((n) {
      if (n.isTransit) return false;
      if (!_filter.matches(n)) return false;
      if (q.isEmpty) return true;
      return n.name.toLowerCase().contains(q) ||
          n.building.toLowerCase().contains(q);
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  bool get _showingRooms =>
      _query.trim().isNotEmpty || _filter != PlaceFilter.all;

  void _goTo(MapNode n) {
    setState(() {
      _selected = n;
      _focusedFloor = n.floor;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${n.name} · Floor ${n.floor}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    _updateRoute();
  }

  /// Asks where the student is now, then shows the pathway to [_selected].
  Future<void> _pickOrigin() async {
    final destination = _selected;
    if (destination == null) return;

    final places =
        widget.graph.nodes
            .where((n) => n.kind != 'hall' && n.id != destination.id)
            .toList()
          ..sort(
            (a, b) => a.floor == b.floor
                ? a.name.compareTo(b.name)
                : a.floor.compareTo(b.floor),
          );

    final origin = await showModalBottomSheet<MapNode>(
      context: context,
      showDragHandle: true,
      builder: (_) => _OriginSheet(destination: destination, places: places),
    );
    if (origin == null || !mounted) return;
    _startFrom(origin);
  }

  void _startFrom(MapNode? origin) {
    setState(() => _origin = origin);
    _updateRoute();
  }

  /// Shows the optimized connected pathway from [_origin] to [_selected].
  void _updateRoute() {
    final from = _origin;
    final to = _selected;
    if (from == null || to == null || from.id == to.id) {
      setState(() => _routeIds = const []);
      return;
    }

    final route = widget.pathways.route(from.id, to.id);
    setState(() => _routeIds = route);
    if (route.isNotEmpty) {
      widget.onRouteShown?.call(from, to);
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('No connected pathway between these places yet.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final floors = widget.plans.map((p) => p.floor).toSet().toList()..sort();

    return Scaffold(
      backgroundColor: AskUcColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              search: _search,
              onSearch: (v) => setState(() => _query = v),
              onOffices: () => setState(() => _filter = PlaceFilter.admin),
              onBack: widget.onBack,
            ),
            const SizedBox(height: 12),
            _FilterChips(
              value: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
            const SizedBox(height: 12),
            _MapCard(
              graph: widget.graph,
              plans: widget.plans,
              controller: _mapController,
              focusedFloor: _focusedFloor,
              selected: _selected,
              origin: _origin,
              routeIds: _routeIds,
              floors: floors,
              onFloorChanged: (f) => setState(() => _focusedFloor = f),
              onNodeTap: _goTo,
              overlay: _selected == null
                  ? null
                  : _RoutePill(
                      origin: _origin,
                      onPick: _pickOrigin,
                      onClear: () => _startFrom(null),
                    ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _showingRooms
                  ? _RoomList(rooms: _matchingRooms, onTap: _goTo)
                  : _BuildingList(
                      buildings: _buildings,
                      onTap: (name) => setState(() => _query = name),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ----------------------------------------------------------- header */

class _Header extends StatelessWidget {
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final VoidCallback onOffices;
  final VoidCallback? onBack;

  const _Header({
    required this.search,
    required this.onSearch,
    required this.onOffices,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AskUcColors.blue, AskUcColors.blueDark],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onBack != null) ...[
                IconButton(
                  onPressed: onBack,
                  tooltip: 'Back',
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Campus Map',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'University of Cebu – Main Campus',
                      style: TextStyle(
                        color: Color(0xFFBBD4F5),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: onOffices,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    child: Text(
                      'Offices',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: search,
            onChanged: onSearch,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search a room, office or lab',
              hintStyle: const TextStyle(
                color: AskUcColors.muted,
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: AskUcColors.muted,
                size: 21,
              ),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ----------------------------------------------------------- chips */

class _FilterChips extends StatelessWidget {
  final PlaceFilter value;
  final ValueChanged<PlaceFilter> onChanged;
  const _FilterChips({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: PlaceFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = PlaceFilter.values[i];
          final on = f == value;
          return Material(
            color: on ? AskUcColors.blue : AskUcColors.card,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () => onChanged(f),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: on ? AskUcColors.blue : AskUcColors.hairline,
                  ),
                ),
                child: Text(
                  f.label,
                  style: TextStyle(
                    color: on ? Colors.white : AskUcColors.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/* ----------------------------------------------------------- map card */

class _MapCard extends StatelessWidget {
  final CampusGraph graph;
  final List<FloorPlan> plans;
  final TransformationController controller;
  final int? focusedFloor;
  final MapNode? selected;
  final MapNode? origin;
  final List<String> routeIds;
  final List<int> floors;
  final ValueChanged<int?> onFloorChanged;
  final ValueChanged<MapNode> onNodeTap;

  /// Shown in the bottom-left corner of the map, e.g. the directions pill.
  final Widget? overlay;

  const _MapCard({
    required this.graph,
    required this.plans,
    required this.controller,
    required this.focusedFloor,
    required this.selected,
    required this.origin,
    required this.routeIds,
    required this.floors,
    required this.onFloorChanged,
    required this.onNodeTap,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    final place = selected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        height: 230,
        decoration: BoxDecoration(
          color: AskUcColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AskUcColors.hairline),
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
                originId: origin?.id,
                destinationId: selected?.id,
                focusIds: routeIds.isNotEmpty
                    ? routeIds
                    : [if (place != null) place.id],
                // Keep the framed places clear of the directions pill.
                viewPadding: overlay == null
                    ? EdgeInsets.zero
                    : const EdgeInsets.only(bottom: 56),
                onNodeTap: onNodeTap,
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: _FloorPicker(
                floors: floors,
                value: focusedFloor,
                onChanged: onFloorChanged,
              ),
            ),
            if (overlay != null)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Align(alignment: Alignment.bottomLeft, child: overlay),
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
      color: on ? AskUcColors.blue : Colors.white,
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
              color: on ? Colors.white : AskUcColors.ink,
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
        border: Border.all(color: AskUcColors.hairline),
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

/* ----------------------------------------------------------- directions */

class _RoutePill extends StatelessWidget {
  final MapNode? origin;
  final VoidCallback onPick;
  final VoidCallback onClear;
  const _RoutePill({
    required this.origin,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final from = origin;
    if (from == null) {
      return Material(
        color: AskUcColors.blue,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.directions_walk_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                SizedBox(width: 6),
                Text(
                  'Directions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AskUcColors.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: InkWell(
                onTap: onPick,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                  child: Text(
                    'From ${from.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AskUcColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: onClear,
              tooltip: 'Clear directions',
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.close_rounded,
                color: AskUcColors.muted,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OriginSheet extends StatelessWidget {
  final MapNode destination;
  final List<MapNode> places;
  const _OriginSheet({required this.destination, required this.places});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Where are you now?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AskUcColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Pathway to ${destination.name}',
                style: const TextStyle(fontSize: 13, color: AskUcColors.muted),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            itemCount: places.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final n = places[i];
              return _Row(
                icon: _iconFor(n),
                title: n.name,
                subtitle: '${n.building} · Floor ${n.floor}',
                onTap: () => Navigator.pop(context, n),
              );
            },
          ),
        ),
      ],
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

class _BuildingList extends StatelessWidget {
  final List<({String name, int floors, int rooms})> buildings;
  final ValueChanged<String> onTap;
  const _BuildingList({required this.buildings, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (buildings.isEmpty) {
      return const _Empty(text: 'No buildings mapped yet.');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      itemCount: buildings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final b = buildings[i];
        return _Row(
          icon: Icons.apartment_rounded,
          title: b.name,
          subtitle:
              '${b.floors} Floor${b.floors == 1 ? '' : 's'} · ${b.rooms} places',
          onTap: () => onTap(b.name),
        );
      },
    );
  }
}

class _RoomList extends StatelessWidget {
  final List<MapNode> rooms;
  final ValueChanged<MapNode> onTap;
  const _RoomList({required this.rooms, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return const _Empty(text: 'Nothing matches that. Try a shorter word.');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      itemCount: rooms.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final n = rooms[i];
        return _Row(
          icon: _iconFor(n),
          title: n.name,
          subtitle: '${n.building} · Floor ${n.floor}',
          onTap: () => onTap(n),
        );
      },
    );
  }
}

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
      color: AskUcColors.card,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AskUcColors.hairline),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: AskUcColors.blue, size: 21),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AskUcColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AskUcColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AskUcColors.muted),
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
          style: const TextStyle(color: AskUcColors.muted, height: 1.45),
        ),
      ),
    );
  }
}
