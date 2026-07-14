using Graphs, Statistics, Logging
include("setup.jl")

#reproducible random graph
import Random
Random.seed!(42)

n_nodes     = 12
edge_prob   = 0.3
regSize     = 30
T2          = 100.0

#generate connected random graph
rg = erdos_renyi(n_nodes, edge_prob)
while !is_connected(rg)
    rg = erdos_renyi(n_nodes, edge_prob)
end

println("Random graph: $(nv(rg)) nodes, $(ne(rg)) edges")

#pick end nodes as degree-1 or degree-2 nodes (leaf-like)
#so flows have meaningful paths through the interior
degrees     = degree(rg)
end_nodes   = [v for v in vertices(rg) if degrees[v] <= 2]

#fallback if no low-degree nodes exist
if length(end_nodes) < 2
    end_nodes = [1, n_nodes]
end

println("End nodes: ", end_nodes)

sim, net = simulation_setup(rg, regSize; T2=T2, endNodes=end_nodes)

#pick two pairs of end nodes for flows
#make sure they're different nodes

src1, dst1 = end_nodes[1], end_nodes[end]
src2, dst2 = end_nodes[2], end_nodes[end-1]

flow1 = Flow(src=src1, dst=dst1, npairs=5, uuid=1)
flow2 = Flow(src=src2, dst=dst2, npairs=5, uuid=2)

put!(net[src1], flow1)
put!(net[src2], flow2)

log_file = open("random_graph_log.txt", "w")
global_logger(SimpleLogger(log_file, Logging.Info))
run(sim, 300.0)
flush(log_file)
close(log_file)
global_logger(ConsoleLogger())

#verify
function count_tags!(mb, tag_type, flow_uuid)
    n = 0
    while !isnothing(querydelete!(mb, tag_type, flow_uuid, ❓, ❓, ❓, ❓, ❓))
        n += 1
    end
    return n
end

mb_src1 = messagebuffer(net, src1)
mb_dst1 = messagebuffer(net, dst1)
mb_src2 = messagebuffer(net, src2)
mb_dst2 = messagebuffer(net, dst2)

f1_src = count_tags!(mb_src1, QTCPPairBegin, 1)
f1_dst = count_tags!(mb_dst1, QTCPPairEnd,   1)
f2_src = count_tags!(mb_src2, QTCPPairBegin, 2)
f2_dst = count_tags!(mb_dst2, QTCPPairEnd,   2)

@info "Flow 1 ($src1→$dst1): src=$f1_src dst=$f1_dst"
@info "Flow 2 ($src2→$dst2): src=$f2_src dst=$f2_dst"

#fidelity
records = Vector{Tuple{Float64, Int, Float64}}()
open("random_graph_log.txt") do f
    for line in eachline(f)
        if occursin("FIDELITY RECORD", line)
            m = match(r"\[([0-9.]+)\].*flow=(\d+)\..*F=([0-9.]+)", line)
            if !isnothing(m)
                push!(records, (parse(Float64, m[1]),
                                parse(Int,     m[2]),
                                parse(Float64, m[3])))
            end
        end
    end
end

if !isempty(records)
    println("\nFidelity summary (random graph):")
    for fid in [1, 2]
        vals = [r[3] for r in records if r[2] == fid]
        if !isempty(vals)
            println("  Flow $fid ($( fid==1 ? "$src1→$dst1" : "$src2→$dst2" )): " *
                    "mean=$(round(mean(vals), digits=4)) " *
                    "min=$(round(minimum(vals), digits=4))")
        end
    end
end