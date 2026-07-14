include("setup.jl")
using Graphs
using Statistics
function dumbbell_graph(cluster_size::Int)
    g = SimpleGraph(2 * cluster_size + 2)
    #left cluster: nodes 1..cluster_size, hub at cluster_size+1
    left_hub = cluster_size + 1
    for i in 1:cluster_size
        add_edge!(g, i, left_hub)
    end
    #right cluster: nodes cluster_size+3..end, hub at cluster_size+2
    right_hub = cluster_size + 2
    for i in 1:cluster_size
        add_edge!(g, right_hub + i, right_hub)
    end
    #bottleneck link between the two hubs
    add_edge!(g, left_hub, right_hub)
    return g
end

clusterSize = 3
regSize = 90
T2 = 100.0

dumbbell = dumbbell_graph(clusterSize) #two clusters of 3 + 2 hubs = 8 nodes

println("Dumbbell edges:")
for e in edges(dumbbell)
    println("   $(e.src) -- $(e.dst)")
end
println("Total nodes: ", nv(dumbbell))
println("Total edges: ", ne(dumbbell))

left_hub = clusterSize + 1  #node 4
right_hub = clusterSize + 2 #node 5
left_leaves = collect(1:clusterSize)                  #[1, 2, 3]
right_leaves = collect(clusterSize+3:2*clusterSize+2) #[6, 7, 8]

# hubs are pure quantum switches -- only leaves are end nodes
endNodes = vcat(left_leaves,right_leaves)

sim, net = simulation_setup(dumbbell, regSize;
    T2=T2, endNodes=endNodes)

#--- Flows ---
#three flows all crossing the bottleneck simultaneously
flow1 = Flow(src=left_leaves[1], dst=right_leaves[1], npairs=5, uuid=1)
flow2 = Flow(src=left_leaves[2], dst=right_leaves[2], npairs=5, uuid=2)
flow3 = Flow(src=left_leaves[3], dst=right_leaves[3], npairs=5, uuid=3)
flow4 = Flow(src=left_leaves[1], dst=right_leaves[2], npairs=5, uuid=4)
flow5 = Flow(src=left_leaves[2], dst=right_leaves[3], npairs=5, uuid=5)
flow6 = Flow(src=left_leaves[3], dst=right_leaves[1], npairs=5, uuid=6)
flow7 = Flow(src=left_leaves[1], dst=right_leaves[3], npairs=5, uuid=7)
flow8 = Flow(src=left_leaves[2], dst=right_leaves[1], npairs=5, uuid=8)
flow9 = Flow(src=left_leaves[3], dst=right_leaves[2], npairs=5, uuid=9)


put!(net[left_leaves[1]], flow1)
put!(net[left_leaves[2]], flow2)
put!(net[left_leaves[3]], flow3)
put!(net[left_leaves[1]], flow4)
put!(net[left_leaves[2]], flow5)
put!(net[left_leaves[3]], flow6)
put!(net[left_leaves[1]], flow7)
put!(net[left_leaves[2]], flow8)
put!(net[left_leaves[3]], flow9)

#--- Run ---
using Logging
log_file = open("dumbbell_log.txt", "w")
global_logger(SimpleLogger(log_file, Logging.Info))

run(sim, 300.0)

flush(log_file)
close(log_file)
global_logger(ConsoleLogger())

mb1 = messagebuffer(net, left_leaves[1])
mb2 = messagebuffer(net, left_leaves[2])
mb3 = messagebuffer(net, left_leaves[3])
mb6 = messagebuffer(net, right_leaves[1])
mb7 = messagebuffer(net, right_leaves[2])
mb8 = messagebuffer(net, right_leaves[3])
# --- Verify ---
function count_tags!(mb, tag_type, flow_uuid)
    n = 0
    while !isnothing(querydelete!(mb, tag_type, flow_uuid, ❓, ❓, ❓, ❓, ❓))
        n += 1
    end
    return n
end

flow1_src = count_tags!(mb1, QTCPPairBegin, 1)
flow1_dst = count_tags!(mb6, QTCPPairEnd,   1)
flow2_src = count_tags!(mb2, QTCPPairBegin, 2)
flow2_dst = count_tags!(mb7, QTCPPairEnd,   2)
flow3_src = count_tags!(mb3, QTCPPairBegin, 3)
flow3_dst = count_tags!(mb8, QTCPPairEnd,   3)
flow4_src = count_tags!(mb1, QTCPPairBegin, 4)
flow4_dst = count_tags!(mb7, QTCPPairEnd,   4)
flow5_src = count_tags!(mb2, QTCPPairBegin, 5)
flow5_dst = count_tags!(mb8, QTCPPairEnd,   5)
flow6_src = count_tags!(mb3, QTCPPairBegin, 6)
flow6_dst = count_tags!(mb6, QTCPPairEnd,   6)
flow7_src = count_tags!(mb1, QTCPPairBegin, 7)
flow7_dst = count_tags!(mb8, QTCPPairEnd,   7)
flow8_src = count_tags!(mb2, QTCPPairBegin, 8)
flow8_dst = count_tags!(mb6, QTCPPairEnd,   8)
flow9_src = count_tags!(mb3, QTCPPairBegin, 9)
flow9_dst = count_tags!(mb7, QTCPPairEnd,   9)

for(i, src, dst, flow) in[
    (1, flow1_src, flow1_dst, flow1),
    (2, flow2_src, flow2_dst, flow2),
    (3, flow3_src, flow3_dst, flow3),
    (4, flow4_src, flow4_dst, flow4),
    (5, flow5_src, flow5_dst, flow5),
    (6, flow6_src, flow6_dst, flow6),
    (7, flow7_src, flow7_dst, flow7),
    (8, flow8_src, flow8_dst, flow8),
    (9, flow9_src, flow9_dst, flow9)
]
    @info "== Flow $i =="
    @info "QTCPPairBegin at src: $src"
    @info "QTCPPairEnd at dst: $dst"
    @assert src == flow.npairs "Expected $(flow.npairs) pairs at flow $i source, got $src"
    @assert dst == flow.npairs "Expected $(flow.npairs) pairs at flow $i destination, got $dst"
end

#--- fidelity summary ---
records = let
    recs = Vector{Tuple{Float64, Int, Float64}}()
    open("dumbbell_log.txt") do f
        for line in eachline(f)
            if occursin("FIDELITY RECORD", line)
                m = match(r"\[([0-9.]+)\].*flow=(\d+)\..*F=([0-9.]+)", line)
                if !isnothing(m)
                    push!(recs, (parse(Float64, m[1]),
                                 parse(Int,     m[2]),
                                 parse(Float64, m[3])))
                end
            end
        end
    end
    recs
end
show(stdout, "text/plain", records)