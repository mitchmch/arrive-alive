(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.ArriveAliveHazardAlerts = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  const DEFAULT_THRESHOLDS_METERS = [800, 500];

  function validDistance(value) {
    const distance = Number(value);
    return Number.isFinite(distance) && distance >= 0 ? distance : null;
  }

  function createTracker(thresholds = DEFAULT_THRESHOLDS_METERS) {
    const stages = [...new Set(thresholds.map(Number))]
      .filter(value => Number.isFinite(value) && value > 0)
      .sort((a, b) => b - a);
    const warned = new Set();
    const previousDistances = new Map();
    const queued = new Set();
    let queue = [];

    function update(hazards, distanceFor) {
      const activeIds = new Set();
      for (const hazard of hazards || []) {
        if (!hazard || hazard.status !== 'active' || hazard.id == null) continue;
        const id = String(hazard.id);
        const distanceMeters = validDistance(distanceFor(hazard));
        if (distanceMeters === null) continue;
        activeIds.add(id);
        const previous = previousDistances.get(id);
        for (const thresholdMeters of stages) {
          const key = `${id}:${thresholdMeters}`;
          if (warned.has(key) || queued.has(key)) continue;
          // A first good fix inside a stage is eligible. A later fix is eligible
          // only when it crosses into the stage, including jumps across both.
          if ((previous === undefined && distanceMeters <= thresholdMeters)
              || (previous > thresholdMeters && distanceMeters <= thresholdMeters)) {
            queue.push({hazard, hazardId: id, thresholdMeters, distanceMeters});
            queued.add(key);
          }
        }
        previousDistances.set(id, distanceMeters);
      }
      for (const id of previousDistances.keys()) {
        if (!activeIds.has(id)) previousDistances.delete(id);
      }
      return queue.slice();
    }

    function next() {
      const alert = queue.shift() || null;
      if (!alert) return null;
      const key = `${alert.hazardId}:${alert.thresholdMeters}`;
      queued.delete(key);
      warned.add(key);
      return alert;
    }

    function discardHazard(hazardId) {
      const id = String(hazardId);
      queue = queue.filter(alert => {
        if (alert.hazardId !== id) return true;
        queued.delete(`${alert.hazardId}:${alert.thresholdMeters}`);
        return false;
      });
      previousDistances.delete(id);
    }

    function reset() {
      warned.clear();
      previousDistances.clear();
      queued.clear();
      queue = [];
    }

    return {
      thresholds: stages.slice(),
      update,
      next,
      discardHazard,
      reset,
      pending: () => queue.slice(),
      hasWarned: (hazardId, thresholdMeters) => warned.has(`${String(hazardId)}:${Number(thresholdMeters)}`),
    };
  }

  return {DEFAULT_THRESHOLDS_METERS, createTracker};
});
