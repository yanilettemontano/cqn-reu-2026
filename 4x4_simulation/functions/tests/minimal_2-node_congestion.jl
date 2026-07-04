include(joinpath(@__DIR__, "..", "..", "setup.jl"))

#small 2-node line: source-switch-destination
graph = path_graph(3)

endNodes = [1, 3]
sim,net = simulation_setup(graph, 20; T2=100.0, endNodes=endNodes)

#manually foruce the PI controller at node 2 at a high p
#so marking is guaranteed to trigger temporarily for testing only
flow1 = Flow(src=1, dst=3, npairs=5, uuid=1)
put!(net[1], flow1)

run(sim, 100.0)

function count_tags!(mb, tag_type)
    n = 0
    while !isnothing(querydelete!(mb, tag_type, W, W, W, W, W, W))
        n += 1
    end
    return n
end

mb1 = messagebuffer(net, 1)
mb3 = messagebuffer(net, 3)

flow1_src = count_tags!(mb1, QTCPPairBegin)
flow1_dst = count_tags!(mb3, QTCPPairEnd)

@info "=== Flow 1: node 1 → node 3 ==="
@info "QTCPPairBegin at src: $flow1_src"
@info "QTCPPairEnd at dst:   $flow1_dst"

@assert flow1_src == flow1.npairs "Expected $(flow1.npairs) pairs at flow 1 source, got $flow1_src"
@assert flow1_dst == flow1.npairs "Expected $(flow1.npairs) pairs at flow 1 destination, got $flow1_dst"