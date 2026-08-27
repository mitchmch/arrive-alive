(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.ArriveAliveSpeedBreach = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  function createController(options = {}) {
    const onChange = options.onChange || (() => {});
    const onAlarmStart = options.onAlarmStart || (() => {});
    const onAlarmStop = options.onAlarmStop || (() => {});
    let state = {active: false, reported: false};

    function emit() {
      onChange({...state});
      return {...state};
    }

    function update(active) {
      const nextActive = Boolean(active);
      if (nextActive === state.active) return {...state};
      if (nextActive) {
        state = {active: true, reported: false};
        onAlarmStart();
      } else {
        state = {active: false, reported: false};
        onAlarmStop();
      }
      return emit();
    }

    function markReported() {
      if (!state.active || state.reported) return false;
      state = {...state, reported: true};
      emit();
      return true;
    }

    function reset() {
      if (state.active) onAlarmStop();
      state = {active: false, reported: false};
      return emit();
    }

    return {update, markReported, reset, getState: () => ({...state})};
  }

  return {createController};
});
