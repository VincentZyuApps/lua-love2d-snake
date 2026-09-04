local algorithms = {
    require("src.ai.random-safe-algorithm"),
    require("src.ai.greedy-algorithm"),
    require("src.ai.bfs-shortest-algorithm"),
    require("src.ai.astar-tail-safe-algorithm"),
    require("src.ai.space-scoring-algorithm"),
    require("src.ai.beam-search-algorithm"),
    require("src.ai.hamiltonian-algorithm"),
    require("src.ai.hamiltonian-shortcut-algorithm"),
}

local Registry = { list = algorithms, byId = {} }
for index, algorithm in ipairs(algorithms) do
    Registry.byId[algorithm.id] = algorithm
    algorithm.index = index
end

function Registry.get(id)
    return assert(Registry.byId[id], "unknown AI algorithm: " .. tostring(id))
end

function Registry.next(id, delta)
    local current = Registry.get(id)
    local index = ((current.index - 1 + delta) % #algorithms) + 1
    return algorithms[index]
end

return Registry
