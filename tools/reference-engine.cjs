/* Shared by the browser, level authoring tool, and automated tests. No DOM dependencies. */
(function (root) {
  'use strict';
  const DIRS = [[1, 0], [0, 1], [-1, 0], [0, -1]];
  const key = ([x, y]) => `${x},${y}`;
  const cloneState = state => ({ ...state, mask: state.mask.map(c => [...c]),
    paths: state.paths.map(p => ({ ...p, cells: p.cells.map(c => [...c]) })) });
  function occupancy(state) {
    const map = new Map();
    for (const p of state.paths) if (p.active !== false) for (const c of p.cells) map.set(key(c), p.id);
    return map;
  }
  // Trace to the outer edge. Empty parts of a silhouette do not block movement;
  // another arm of the silhouette can still block a ray further ahead.
  function escapeRay(state, path) {
    const [dx, dy] = DIRS[path.direction], head = path.cells.at(-1), result = [];
    for (let x = head[0] + dx, y = head[1] + dy;
      x >= 0 && y >= 0 && x < state.width && y < state.height; x += dx, y += dy) result.push([x, y]);
    return result;
  }
  function blockers(state, path, map = occupancy(state)) {
    return [...new Set(escapeRay(state, path).map(c => map.get(key(c))).filter(id => id !== undefined))];
  }
  const isArrowBlocked = (state, path) => blockers(state, path).length > 0;
  function getAvailableArrows(state) {
    const map = occupancy(state);
    return state.paths.filter(p => p.active !== false && !blockers(state, p, map).length);
  }
  function simulateMove(state, id) {
    const path = state.paths.find(p => p.id === id);
    if (!path || path.active === false || isArrowBlocked(state, path)) return null;
    const copy = cloneState(state);
    copy.paths.find(p => p.id === id).active = false;
    return copy;
  }
  function solveLevel(state) {
    // Removal cannot introduce a blocker. Any available move is safe, so one
    // recursive branch is sufficient; factorial permutation searches add no value.
    if (!state.paths.some(p => p.active !== false)) return [];
    const next = getAvailableArrows(state)[0];
    if (!next) return null;
    const rest = solveLevel(simulateMove(state, next.id));
    return rest === null ? null : [next.id, ...rest];
  }
  function turns(path) {
    let result = 0;
    for (let i = 2; i < path.cells.length; i++) {
      const a = path.cells[i - 2], b = path.cells[i - 1], c = path.cells[i];
      if (b[0] - a[0] !== c[0] - b[0] || b[1] - a[1] !== c[1] - b[1]) result++;
    }
    return result;
  }
  function validateLevel(level) {
    const mask = new Set(level.mask.map(key)), occupied = new Set(), ids = new Set();
    if (mask.size !== level.mask.length) throw Error('Duplicate mask cells');
    for (const p of level.paths) {
      if (ids.has(p.id) || !p.cells.length || !DIRS[p.direction]) throw Error('Invalid path ID/direction');
      ids.add(p.id);
      p.cells.forEach((c, i) => {
        if (!mask.has(key(c)) || occupied.has(key(c))) throw Error(`Overlap or outside mask: ${p.id} at ${c}`);
        if (i && Math.abs(c[0] - p.cells[i - 1][0]) + Math.abs(c[1] - p.cells[i - 1][1]) !== 1) throw Error('Non-adjacent cells');
        occupied.add(key(c));
      });
      if (p.cells.length > 1) {
        const a = p.cells.at(-2), b = p.cells.at(-1), d = DIRS[p.direction];
        if (b[0] - a[0] !== d[0] || b[1] - a[1] !== d[1]) throw Error('Arrowhead disagrees with last segment');
      }
    }
    if (occupied.size !== mask.size) throw Error(`Incomplete coverage: ${occupied.size}/${mask.size}`);
    const solution = solveLevel(level);
    if (!solution || solution.length !== level.paths.length) throw Error('Unsolvable level');
    const map = occupancy(level), graph = new Map(level.paths.map(p => [p.id, blockers(level, p, map)]));
    const depths = new Map();
    const depth = id => { if (!depths.has(id)) depths.set(id, 1 + Math.max(0, ...graph.get(id).map(depth))); return depths.get(id); };
    return { cells: mask.size, arrows: ids.size, coverage: 1,
      available: getAvailableArrows(level).length, depth: Math.max(...level.paths.map(p => depth(p.id))),
      minLength: Math.min(...level.paths.map(p => p.cells.length)), maxLength: Math.max(...level.paths.map(p => p.cells.length)),
      turns: level.paths.reduce((sum, p) => sum + turns(p), 0),
      straight: level.paths.filter(p => !turns(p)).length,
      directions: DIRS.map((_, d) => level.paths.filter(p => p.direction === d).length),
      singles: level.paths.filter(p => p.cells.length === 1).length, solution };
  }
  const api = { DIRS, key, cloneState, occupancy, escapeRay, blockers, isArrowBlocked, getAvailableArrows, simulateMove, solveLevel, turns, validateLevel };
  if (typeof module !== 'undefined') module.exports = api;
  else root.ArrowEngine = api;
})(globalThis);
