angular.module('beamng.apps')
.directive('eliminatorLobby', [function () {
  return {
    templateUrl: '/ui/modules/apps/EliminatorLobby/app.html',
    replace: true,
    restrict: 'EA',
    scope: true,
    controller: ['$scope', function ($scope) {
      var emptySnapshot = {
        phase: 'waiting',
        competitors: [],
        spectators: [],
        active_competitors: 0,
        roster_locked: false
      };

      $scope.snapshot = emptySnapshot;
      $scope.countdownSeconds = null;
      $scope.slots = [];

      function rebuildSlots(snapshot) {
        var bySlot = {};
        var competitors = Array.isArray(snapshot.competitors) ? snapshot.competitors : [];
        var nextSlots = [];
        var i;

        for (i = 0; i < competitors.length; i++) {
          if (competitors[i] && typeof competitors[i].slot === 'number') {
            bySlot[competitors[i].slot] = competitors[i];
          }
        }

        for (i = 1; i <= 20; i++) {
          nextSlots.push(bySlot[i] || {
            slot: i,
            kind: 'empty',
            status: 'vacant',
            competitor_id: null
          });
        }
        $scope.slots = nextSlots;
      }

      $scope.phaseLabel = function (phase) {
        var labels = {
          waiting: 'Ожидание',
          lobby: 'Лобби',
          starting: 'Подготовка',
          active: 'Матч идёт',
          final_showdown: 'Финал',
          finished: 'Завершён',
          stopped: 'Остановлен'
        };
        return labels[phase] || 'Нет данных';
      };

      $scope.kindLabel = function (kind) {
        if (kind === 'human') return 'Игрок';
        if (kind === 'ai') return 'AI';
        return 'Свободный слот';
      };

      $scope.slotStatusLabel = function (slot) {
        if (slot.connection_status === 'disconnected') return 'Отключён';
        if (slot.status === 'eliminated') return 'Выбыл';
        if (slot.kind === 'empty') return 'Ожидание игрока';
        if (slot.kind === 'ai') return 'Соперник AI';
        return 'В составе';
      };

      $scope.activeCount = function () {
        return Number($scope.snapshot.active_competitors) || 0;
      };

      $scope.countKind = function (kind) {
        var count = 0;
        for (var i = 0; i < $scope.slots.length; i++) {
          if ($scope.slots[i].kind === kind && $scope.slots[i].status === 'active') count++;
        }
        return count;
      };

      $scope.spectatorCount = function () {
        return Array.isArray($scope.snapshot.spectators) ? $scope.snapshot.spectators.length : 0;
      };
      $scope.localCompetitor = function () {
        var id = $scope.snapshot.local_competitor_id;
        if (!id) return null;
        for (var i = 0; i < $scope.slots.length; i++) if ($scope.slots[i].competitor_id === id) return $scope.slots[i];
        return null;
      };
      $scope.canEditLobby = function () {
        var p = $scope.localCompetitor();
        return $scope.snapshot.phase === 'lobby' && !!p && p.kind === 'human' && p.connection_status !== 'disconnected';
      };
      $scope.selectSpawnRegion = function (region) {
        if (!/^(north|east|south|west)$/.test(region) || !$scope.canEditLobby()) return;
        if (typeof bngApi !== 'undefined' && bngApi && typeof bngApi.engineLua === 'function')
          bngApi.engineLua('extensions.eliminator.selectSpawnRegion("' + region + '")');
      };
      $scope.toggleReady = function () {
        if (!$scope.canEditLobby()) return;
        var ready = !( $scope.localCompetitor().ready === true);
        if (typeof bngApi !== 'undefined' && bngApi && typeof bngApi.engineLua === 'function')
          bngApi.engineLua('extensions.eliminator.setReady(' + (ready ? 'true' : 'false') + ')');
      };
      $scope.spawnRegionLabel = function (region) {
        return ({ north: 'Север', east: 'Восток', south: 'Юг', west: 'Запад' })[region] || 'Не выбран';
      };

      function applyUpdate(payload) {
        if (!payload || typeof payload !== 'object') return;

        if (payload.snapshot && typeof payload.snapshot === 'object') {
          $scope.snapshot = payload.snapshot;
          rebuildSlots(payload.snapshot);
        }

        if (typeof payload.countdown_seconds === 'number') {
          $scope.countdownSeconds = payload.countdown_seconds;
        } else if ($scope.snapshot.phase !== 'starting') {
          $scope.countdownSeconds = null;
        }
      }

      var removeUpdateListener = $scope.$on('EliminatorLobbyUpdate', function (_, payload) {
        applyUpdate(payload);
      });

      rebuildSlots($scope.snapshot);

      if (typeof bngApi !== 'undefined' && bngApi && typeof bngApi.engineLua === 'function') {
        bngApi.engineLua('extensions.eliminator.requestLobbySnapshot()');
      }

      $scope.$on('$destroy', function () {
        if (typeof removeUpdateListener === 'function') removeUpdateListener();
      });
    }]
  };
}]);
