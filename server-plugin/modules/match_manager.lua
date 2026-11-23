-- Match lifecycle and authoritative state.
-- No BeamMP callbacks are registered here yet: event names and signatures
-- must be verified against the target BeamMP Server release first.

local MatchManager = {}

local state = {
    phase = "waiting",
    competitors = {},
    capacity = 20
}

function MatchManager.initialize()
    state.phase = "waiting"
    state.competitors = {}
end

function MatchManager.shutdown()
    state.phase = "stopped"
    state.competitors = {}
end

function MatchManager.get_state()
    -- Return a copy so callers cannot mutate internal state accidentally.
    local snapshot = {
        phase = state.phase,
        capacity = state.capacity,
        competitors = {}
    }

    for index, competitor in ipairs(state.competitors) do
        snapshot.competitors[index] = competitor
    end

    return snapshot
end

return MatchManager
