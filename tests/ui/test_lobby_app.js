const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

let registeredDirective = null;
let registeredFactory = null;
const luaCalls = [];

global.angular = {
  module(name) {
    assert.equal(name, 'beamng.apps');
    return {
      directive(name, factory) {
        registeredDirective = name;
        registeredFactory = factory;
      }
    };
  }
};

global.bngApi = {
  engineLua(command) {
    luaCalls.push(command);
  }
};

const source = fs.readFileSync(
  'client-mod/ui/modules/apps/EliminatorLobby/app.js',
  'utf8'
);
vm.runInThisContext(source, { filename: 'EliminatorLobby/app.js' });

assert.equal(registeredDirective, 'eliminatorLobby');
assert.ok(Array.isArray(registeredFactory));
assert.equal(typeof registeredFactory[registeredFactory.length - 1], 'function');

const definition = registeredFactory[registeredFactory.length - 1]();
const handlers = Object.create(null);
const scope = {
  $on(eventName, callback) {
    handlers[eventName] = callback;
    return function () {
      delete handlers[eventName];
    };
  }
};

const controller = definition.controller[1];
controller(scope);

assert.equal(scope.slots.length, 20);
assert.deepEqual(luaCalls, [
  'extensions.eliminator.requestLobbySnapshot()'
]);

const competitors = [];
for (let slot = 1; slot <= 20; slot++) {
  competitors.push({
    slot,
    kind: slot <= 2 ? 'human' : 'ai',
    status: 'active',
    competitor_id: slot <= 2 ? 'player:' + slot : 'ai:' + slot,
    display_name: slot <= 2 ? 'Driver ' + slot : null,
    connection_status: slot === 2 ? 'disconnected' : 'connected'
  });
}

handlers.EliminatorLobbyUpdate(null, {
  snapshot: {
    phase: 'lobby',
    local_competitor_id: 'player:1',
    competitors: competitors.map(function (c) {
      if (c.competitor_id === 'player:1') { c.spawn_region = 'north'; c.ready = false; }
      return c;
    }),
    active_competitors: 20,
    spectators: [{ player_id: 'player:21', status: 'spectating' }],
    roster_locked: true
  },
  countdown_seconds: 5
});

assert.equal(scope.slots.length, 20);
assert.equal(scope.countKind('human'), 2);
assert.equal(scope.countKind('ai'), 18);
assert.equal(scope.activeCount(), 20);
assert.equal(scope.spectatorCount(), 1);
assert.equal(scope.slots[1].connection_status, 'disconnected');
assert.equal(scope.countdownSeconds, 5);
assert.equal(scope.phaseLabel('lobby'), 'Лобби');
assert.equal(scope.canEditLobby(), true);
scope.selectSpawnRegion('east');
assert.ok(luaCalls[luaCalls.length - 1].includes('selectSpawnRegion("east")'));
scope.toggleReady();
assert.ok(luaCalls[luaCalls.length - 1].includes('setReady(true)'));
const beforeInvalid = luaCalls.length;
scope.selectSpawnRegion('bad"); os.execute("bad');
assert.equal(luaCalls.length, beforeInvalid);

handlers.EliminatorLobbyUpdate(null, { countdown_seconds: 4 });
assert.equal(scope.countdownSeconds, 4);

handlers.EliminatorLobbyUpdate(null, {
  snapshot: {
    phase: 'active',
    local_competitor_id: 'player:1',
    competitors,
    active_competitors: 19,
    spectators: [],
    roster_locked: true
  }
});
assert.equal(scope.countdownSeconds, null);
assert.equal(scope.activeCount(), 19);
assert.equal(scope.spectatorCount(), 0);

handlers.$destroy();
assert.equal(handlers.EliminatorLobbyUpdate, undefined);

delete global.angular;
delete global.bngApi;
console.log('Lobby UI state tests passed.');
