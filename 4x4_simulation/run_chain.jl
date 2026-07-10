using Statistics, Logging, Graphs
include("setup.jl")

n_nodes  = 5
regsize  = 60
T2       = 100.0
n_flows  = 6
npairs   = 10
sim_time = 300.0

graph    = Graphs.grid([n_nodes])

flowspecs = [
    (1, 5),
    (1, 5),
    (1, 5), 
    (1, 5),
    (1, 5),
]

endNodes = unique(vcat([src for (src, dst) in flowspecs],
                       [dst for (src, dst) in flowspecs]))

sim, net = simulation_setup(graph, regsize; T2=T2, endNodes=endNodes)

for(uuid, (src, dst)) in enumerate(flowspecs)
    put!(net[src], Flow(src=src, dst=dst, npairs=npairs, uuid=uuid))
end

log_file = open("chain_run_log.txt", "w")
global_logger(SimpleLogger(log_file, Logging.Info))

run(sim, sim_time)

flush(log_file)
close(log_file)
global_logger(ConsoleLogger())
# parse fidelity records
records = Vector{Tuple{Float64, Int, Float64}}()
open("chain_run_log.txt") do f
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

# detect which mode we ran based on USE_AIMD constant
# save to different files depending on mode
using DelimitedFiles

if isempty(records)
    println("No fidelity records found — check log file")
else
    times = [r[1] for r in records]
    fids  = [r[3] for r in records]
    println("Mean F: $(round(mean(fids), digits=4))")
    println("Min  F: $(round(minimum(fids), digits=4))")

    # determine output filename from qtcp USE_AIMD constant
    # check by looking at window behavior — if all windows are 3 it's fixed
    # simplest: just name the file manually based on what you set
    # CHANGE THIS LINE to "chain_fixed.csv" or "chain_aimd.csv" to match your run
    outfile = "chain_fixed.csv"    # ← change to chain_fixed.csv for fixed window run
    writedlm(outfile, hcat(times, fids), ',')
    println("Saved to $outfile")
end