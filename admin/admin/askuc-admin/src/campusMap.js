// Reads the campus graph the mobile app ships with (askuc/assets/
// campus_graph.json) for the admin Map page.

const STOP_KINDS = new Set(['stairs', 'elevator']);

// Stairs and elevator stops: the points where a walk changes floors.
export function isStop(node) {
  return STOP_KINDS.has(node.kind);
}

// Doors (entrance points). A closed door can't be walked through, so the
// app routes another way, or says the place behind it is out of reach.
export function isDoor(node) {
  return node.kind === 'entrance';
}

// Every door, lowest floor first.
export function listDoors(graph) {
  return graph.nodes.filter(isDoor).sort(byFloorThenName);
}

// "5F Stairs 3 Near Gate 2" -> "Stairs 3 Near Gate 2"
function stairwellName(stopName) {
  return stopName.replace(/^\d+F\s+/, '');
}

function byFloorThenName(a, b) {
  return a.floor - b.floor || a.name.localeCompare(b.name, undefined, { numeric: true });
}

// Every stairwell and elevator with its stop on each floor, lowest first.
// Stops belong together when the graph links them between floors.
export function groupStairwells(graph) {
  const nodesById = new Map(graph.nodes.map((node) => [node.id, node]));
  const rides = new Map();

  for (const { from, to } of graph.edges) {
    const a = nodesById.get(from);
    const b = nodesById.get(to);
    if (!a || !b || a.floor === b.floor) {
      continue;
    }
    rides.set(from, [...(rides.get(from) ?? []), to]);
    rides.set(to, [...(rides.get(to) ?? []), from]);
  }

  const grouped = new Set();
  const stairwells = [];

  for (const stop of graph.nodes.filter(isStop).sort(byFloorThenName)) {
    if (grouped.has(stop.id)) {
      continue;
    }

    const stops = [];
    const queue = [stop.id];
    grouped.add(stop.id);
    while (queue.length > 0) {
      const id = queue.shift();
      stops.push(nodesById.get(id));
      for (const next of rides.get(id) ?? []) {
        if (!grouped.has(next)) {
          grouped.add(next);
          queue.push(next);
        }
      }
    }

    stops.sort(byFloorThenName);
    stairwells.push({
      id: stops[0].id,
      name: stairwellName(stops[0].name),
      kind: stops[0].kind,
      stops,
    });
  }

  return stairwells;
}

// Mapped points with no walkable link to the rest of the map, so no route
// can reach them. The biggest connected part counts as the map.
export function findUnconnected(graph) {
  const links = new Map(graph.nodes.map((node) => [node.id, []]));
  for (const { from, to } of graph.edges) {
    links.get(from)?.push(to);
    links.get(to)?.push(from);
  }

  const parts = [];
  const seen = new Set();
  for (const node of graph.nodes) {
    if (seen.has(node.id)) {
      continue;
    }

    const part = [];
    const queue = [node.id];
    seen.add(node.id);
    while (queue.length > 0) {
      const id = queue.shift();
      part.push(id);
      for (const next of links.get(id)) {
        if (!seen.has(next)) {
          seen.add(next);
          queue.push(next);
        }
      }
    }
    parts.push(part);
  }

  const map = new Set(parts.reduce((biggest, part) => (part.length > biggest.length ? part : biggest), []));
  return graph.nodes.filter((node) => !map.has(node.id));
}
