using Graphs
using Statistics
include("setup.jl")

#---Network parameters ---
n_nodes = 5
regsize = 10
T2 = 100.0

graph = Graphs.grid([n_nodes])

sim,net = simulation_setup(graph, regsize; T2=T2)

flow = Flow(src=1, dst = n_nodes, npairs=10, uuid=1)
put!(net[1], flow)

using Logging
log_file = open("chain_simulation_log.txt", "w")
global_logger(SimpleLogger(log_file, Logging.Info))

run(sim, 200.0)

flush(log_file)
close(log_file)
global_logger(ConsoleLogger())

mb_src = messagebuffer(net, 1)
mb_dst = messagebuffer(net, n_nodes)

function count_delivered!(mb, tag_type)
    n = 0
    while !isnothing(querydelete!(mb, tag_type, ❓, ❓, ❓, ❓, ❓, ❓))
        n += 1
    end
    return n
end

n_delivered_src = count_delivered!(mb_src, QTCPPairBegin)
n_delivered_dst = count_delivered!(mb_dst, QTCPPairEnd)

@info "=== QTCP Chain Simulation Results ==="
@info "Chain length:       $n_nodes nodes"
@info "Requested pairs:    $(flow.npairs)"
@info "Delivered at source: $n_delivered_src"
@info "Delivered at dest:   $n_delivered_dst"
@info "Simulation time:     $(round(now(sim), digits=2))"

@assert n_delivered_src == flow.npairs "Expected $(flow.npairs) pairs at source, got $n_delivered_src"
@assert n_delivered_dst == flow.npairs "Expected $(flow.npairs) pairs at destination, got $n_delivered_dst"
@info "All $(flow.npairs) Bell pairs successfully delivered!"

# --- Parse fidelity from log ---
fidelity_records = Vector{Tuple{Float64, Float64}}()
open("chain_simulation_log.txt") do f
    for line in eachline(f)
        if occursin("FIDELITY RECORD", line)
            m = match(r"\[([0-9.]+)\].*F=([0-9.]+)", line)
            if !isnothing(m)
                push!(fidelity_records,
                    (parse(Float64, m[1]), parse(Float64, m[2])))
            end
        end
    end
end

if !isempty(fidelity_records)
    times      = [r[1] for r in fidelity_records]
    fidelities = [r[2] for r in fidelity_records]
    println("\nFidelity summary (5-node chain):")
    println("  Mean: ", round(mean(fidelities), digits=4))
    println("  Min:  ", round(minimum(fidelities), digits=4))
    println("  Max:  ", round(maximum(fidelities), digits=4))
end