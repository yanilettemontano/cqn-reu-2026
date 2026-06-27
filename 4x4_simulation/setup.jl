using QuantumSavory 
using QuantumSavory.ProtocolZoo
using Graphs
using ResumableFunctions
using ConcurrentSim

#-------Network Setup-------------
#setting the topology
function simulation_setup(
    graph,
    regSize::Int;
    T2 = 100.0,
    representation = QuantumOpticsRepr,
    endNodes = nothing,
    EndNodeControllerType = EndNodeController,
    classical_delay = 1e-3
)

#creates the registers for each node
registers = Register[]
for _ in vertices(graph)
    traits = [Qubit() for _ in 1:regSize]
    repr = [representation() for _ in 1:regSize]
    bg = [T2Dephasing(T2) for _ in 1:regSize]
    push!(registers, Register(traits, repr, bg))
end

#Build the network and get the simulation scheduler
net = RegisterNet(graph, registers; classical_delay)
sim = get_time_tracker(net)

#default: all nodes can be end nodes
if isnothing(endNodes)
    endNodes = collect(vertices(graph))
end

#-----Protocol Definitons---------
#Launch the QTCP protocol suite
#1. EncNodeControllers one the designates end nodes
for node in endNodes
    ctrl = EndNodeControllerType(net, node)
    @process ctrl()
end
#2. NetworkNodeControllers on all nodes
for node in vertices(graph)
    ctrl = NetworkNodeController(net, node)
    @process ctrl()
end
#3. LinkControllers on every edge
for edge in edges(net)
    ctrl = LinkController(net, edge.src, edge.dst)
    @process ctrl()
end

return sim, net
end


