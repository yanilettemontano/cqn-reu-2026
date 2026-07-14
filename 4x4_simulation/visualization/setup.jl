using QuantumSavory
using QuantumSavory.ProtocolZoo
using Graphs
using ConcurrentSim
using ResumableFunctions

function simulation_setup(
    graph, 
    regSize::Int;
    T2=100.0,
    represenation = QuantumOpticsRepr,
    end_nodes = nothing,
    EndNodeControllerType = EndNodeController,
    classical_delay = 1e-3
)

registers = Register[]
for _ in vertices(graph)
    traits = [Qubit() for _ in 1:regsize]
    repr   = [represenation() for _ in 1:regsize]
    bg     = [T2Dephasing(T2) for _ in 1:regsize]
    push!(registers, Register(traits, repr, bg))
end

net = RegisterNet(graph, registers; classical_delay)
sim = get_time_tracker(net)

if isnothing(end_nodes)
    end_nodes = collect(vertices(graph))
end

for node in end_nodes
    ctrl = EndNodeControllerType(net, node)
    @process ctrl()
end

for node in vertices(graph)
    ctrl = NetworkNodeController(net, node)
    @process ctrl()
end

for edge in edges(net)
    ctrl = LinkController(net, edge.src, edge.dst)
    @process ctrl()
end

    return sim, net
end