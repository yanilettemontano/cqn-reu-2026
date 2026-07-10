# replace the graph and flow setup section with:
include("setup.jl")
numRows  = 4
numCols  = 4
numNodes = numRows * numCols
regSize  = 90
T2       = 100.0
n_flows  = 6
npairs   = 5
sim_time = 300.0

using Graphs

graph    = Graphs.grid([numRows, numCols])
endNodes = [1, numCols, numNodes-numCols+1, numNodes]

sim, net = simulation_setup(graph, regSize; T2=T2, endNodes=endNodes)

flow_defs = [
    (1,  4,  1),   # top row
    (13, 16, 2),   # bottom row
    (1,  13, 3),   # left column
    (4,  16, 4),   # right column
    (1,  16, 5),   # diagonal
    (4,  13, 6),   # diagonal
]

for (src, dst, uuid) in flow_defs
    flow = Flow(src=src, dst=dst, npairs=npairs, uuid=uuid)
    put!(net[src], flow)
end

using Logging
log_file = open("grid_run_log.txt", "w")
global_logger(SimpleLogger(log_file, Logging.Info))
run(sim, 300.0)
flush(log_file)
close(log_file)
global_logger(ConsoleLogger())

records = Vector{Tuple{Float64, Int, Float64}}()
open("grid_run_log.txt") do f
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

println("Records collected: $(length(records))")

using DelimitedFiles

if isempty(records)
    println("No fidelity records found -- check log file")
else
    times = [r[1] for r in records]
    fids = [r[3] for r in records]
    println("Mean F: $(round(mean(fids), digits=4))")
    println("Min  F: $(round(minimum(fids), digits=4))")
end
# output file — change between runs
outfile = "grid_aimd.csv"    # ← change to grid_fixed.csv for fixed window run
writedlm(outfile, hcat(times, fids), ',')
println("Saved to $outfile")