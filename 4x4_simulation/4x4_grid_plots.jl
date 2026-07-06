include("setup.jl")
using Statisitcs

numRows = 4
numCols =4
numNodes = numRows * numCols
regSize = 90
T2 = 100.0

graph = Graphs.grid([numRows, numCols])

#Set up the simulation with the full QTCP protocol suite
#End nodes are the four corners of the grid.
#[1, 4, 11, 16]
endNodes = [1, numCols, numNodes - numCols + 1, numNodes]
sim, net = simulation_setup(graph, regSize; T2=T2, endNodes = endNodes)
# -- Define multiple concurrent Flows --
flow1 = Flow(src=1,  dst=4,  npairs=5, uuid=1)  # top row
flow2 = Flow(src=13, dst=16, npairs=5, uuid=2)  # bottom row
flow3 = Flow(src=1,  dst=13, npairs=5, uuid=3)  # diagonal
flow4 = Flow(src=4,  dst=16, npairs=5, uuid=4)  # diagonal
flow5 = Flow(src=1,  dst=16, npairs=5, uuid=5)  # corner to corner
flow6 = Flow(src=4,  dst=13, npairs=5, uuid=6)  # corner to corner

put!(net[1],                    flow1)
put!(net[numNodes-numCols+1],   flow2)
put!(net[1],                    flow3)
put!(net[numCols],              flow4)
put!(net[1],                    flow5)
put!(net[numCols],              flow6)

using Logging
log_file = open("simulation_log.txt", "w")
logger = SimpleLogger(log_file, Logging.Info)
global_logger(logger)

run(sim, 300.0)

flush(log_file)
close(log_file)
global_logger(ConsoleLogger())

fidelity_records = Vector{Tuple{Float64, Int, Float64}}()

open("simulation_log.txt") do f
    for line in eachline(f)
        if occursin("FIDELITY RECORD", line)
            m = match(r"\[([0-9.]+)\].*flow=(\d+)\..*F=([0-9.]+)", line)
            if !isnothing(m)
                push!(fidelity_records, (
                    parse(Float64,  m[1]),
                    parse(Int,      m[2]),
                    parse(Float64,  m[3])
                ))
            end
        end
    end
end
println("Total fidelity records parsed: ", length(fidelity_records))

using Plots 

if !isempty(fidelity_records)
    times       = [r[1] for r in fidelity_records]
    fidelities  = [r[3] for r in fidelity_records]
    flow_ids    = [r[2] for r in fidelity_records]  

    unique_flows = sort(unique(flow_ids))
    colors       = palette(:tab10)

    p = scatter(xlabel = "Simulation time(s)",
    ylabel = "Delievered fidelity F",
    title  = "End-to-End fidelity -- 6 flows, 4 x 4 grid",
    legend = :bottomleft,
    ylims  = (0.85, 1.0),
    markersize = 5)

    for(i, fid) in enumerate(unique_flows)
        mask = flow_ids .== fid
        scatter!(p, times[mask], fidelities[mask],
        label       = "Flow $fid",
        color       = colors[i],
        markersize  = 5)
    end

    savefig(p, "fidelity_over_time.pdf")
    println("Plot saved: fidelity_over_time.pdf")
    println("Records: $(length(fidelity_records)) pairs across $(length(unique_flows)) flows")

    hop_counts  = [3, 3, 3, 3, 6, 6]
    mean_fids   = [0.9663, 0.9748, 0.9749, 0.9749, 0.9451, 0.9494]
    flow_labels = ["F1\n1→4", "F2\n13→16", "F3\n1→13",
               "F4\n4→16", "F5\n1→16", "F6\n4→13"]

    bar(flow_labels, mean_fids,
    xlabel    = "Flow (source → destination)",
    ylabel    = "Mean delivered fidelity F",
    title     = "Mean fidelity by flow — 6 flows, 4×4 grid",
    legend    = false,
    ylims     = (0.90, 1.0),
    color     = [:steelblue, :steelblue, :steelblue,
                 :steelblue, :coral, :coral],
    bar_width = 0.6)

    hline!([0.75], linestyle=:dash, color=:red, 
       label="Entanglement threshold")

    savefig("fidelity_by_flow.pdf")

    #also print summary stats per flow
    println("\nFidelity summary:")
    for fid in unique_flows
        mask = flow_ids .== fid
        f_vals = fidelities[mask]
        println("   Flow $fid: mean=$(round(mean(f_vals), digits=4)) min=$(round(minimum(f_vals), digits=4)) max=$(round(maximum(f_vals), digits=4))")
    end
else
    println("No FIDELITY RECORD lines found in simulation_log.txt")
    println("Check that @info FIDELITY RECORD lines are firing in EndNodeController")
end