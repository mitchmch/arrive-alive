const assert = require('node:assert/strict');
const {DEFAULT_THRESHOLDS_METERS, createTracker} = require('../web-hazard-alerts');

assert.deepEqual(DEFAULT_THRESHOLDS_METERS, [800, 500]);

const hazard = {id: 'hazard-1', status: 'active', label: 'Pothole'};
const tracker = createTracker();

assert.deepEqual(tracker.update([hazard], () => 900), []);
assert.deepEqual(
  tracker.update([hazard], () => 490).map(item => item.thresholdMeters),
  [800, 500],
  'A GPS jump across both boundaries must queue both alert stages',
);

const first = tracker.next();
assert.equal(first.thresholdMeters, 800);
assert.equal(tracker.hasWarned('hazard-1', 800), true);
assert.equal(tracker.next().thresholdMeters, 500);
assert.equal(tracker.hasWarned('hazard-1', 500), true);
assert.equal(tracker.next(), null);

tracker.update([hazard], () => 450);
tracker.update([hazard], () => 700);
tracker.update([hazard], () => 450);
assert.equal(tracker.next(), null, 'A stage must not alert twice during one journey');

const firstFixTracker = createTracker();
firstFixTracker.update([hazard], () => 750);
assert.equal(firstFixTracker.next().thresholdMeters, 800, 'A first valid fix inside 800 m must alert');
firstFixTracker.update([hazard], () => 510);
assert.equal(firstFixTracker.next(), null);
firstFixTracker.update([hazard], () => 499);
assert.equal(firstFixTracker.next().thresholdMeters, 500);

const discardTracker = createTracker();
discardTracker.update([hazard], () => 400);
discardTracker.discardHazard(hazard.id);
assert.equal(discardTracker.next(), null, 'Resolving a hazard must clear its queued alerts');

discardTracker.reset();
discardTracker.update([hazard], () => 790);
assert.equal(discardTracker.next().thresholdMeters, 800, 'A new journey reset must allow alerts again');

console.log('Hazard alert checks passed.');
