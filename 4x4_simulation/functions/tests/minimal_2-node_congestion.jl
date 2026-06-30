include(joinpath(@__DIR__, "..", "..", "setup.jl"))

#small 3-node line: source-switch-destination
graph = path_graph(3)

endNodes = [1, 3]
sim,net = simulation_setup(graph, 20; T2=100.0, endNodes=endNodes)

#manually foruce the PI controller at node 2 at a high p
#so marking is guaranteed to trigger temporarily for testing only
flow1 = Flow(src=1, dst=3, npairs=5, uuid=1)
#flow2 = Flow(src=2, dst=3, npairs=5, uuid=1)
println("flow1.src = ", flow1.src)
println("flow1.dst = ", flow1.dst)
println("flow1.npairs = ", flow1.npairs)
println("flow1.uuid = ", flow1.uuid)
put!(net[1], flow1)
#put!(net[2], flow2)

run(sim, 5.0)