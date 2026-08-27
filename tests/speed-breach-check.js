const assert = require('node:assert/strict');
const {createController} = require('../web-speed-breach');

const changes = [];
let starts = 0;
let stops = 0;
const controller = createController({
  onChange: state => changes.push(state),
  onAlarmStart: () => starts++,
  onAlarmStop: () => stops++,
});

assert.deepEqual(controller.getState(), {active: false, reported: false});
controller.update(true);
assert.deepEqual(controller.getState(), {active: true, reported: false});
assert.equal(starts, 1, 'The alarm must start once when a breach begins');
controller.update(true);
assert.equal(starts, 1, 'Repeated over-limit samples must not restart the alarm');
assert.equal(controller.markReported(), true);
assert.deepEqual(controller.getState(), {active: true, reported: true});
assert.equal(controller.markReported(), false, 'Only one report is allowed for one continuous breach');
controller.update(false);
assert.deepEqual(controller.getState(), {active: false, reported: false});
assert.equal(stops, 1, 'The alarm must stop as soon as speed returns below the limit');
controller.update(true);
assert.equal(controller.markReported(), true, 'A new breach can be reported again');
controller.reset();
assert.deepEqual(controller.getState(), {active: false, reported: false});
assert.equal(stops, 2, 'Resetting an active journey must stop its alarm');
assert.ok(changes.length >= 5);

console.log('Speed breach checks passed.');
