using Graphs, Statistics, Logging, Plots
include("setup.jl")

# --- Parameters ---
n_nodes  = 5
regsize  = 60
T2       = 100.0
n_flows  = 6
npairs   = 10
sim_time = 60.0

graph    = Graphs.grid([n_nodes])
endNodes = [1, n_nodes]   # explicitly set end nodes

# --- Sliding average helpers ---
function sliding_avg(times, values, window, t_end, n=300)
    isempty(times) && return Float64[], Float64[]
    tg   = range(0.0, t_end, length=n)
    avgs = Float64[]
    for t in tg
        mask = (times .>= t - window) .& (times .<= t)
        push!(avgs, sum(mask) > 0 ? mean(values[mask]) : NaN)
    end
    return collect(tg), avgs
end

function sliding_thru(times, window, t_end, n=300)
    isempty(times) && return Float64[], Float64[]
    tg  = range(0.0, t_end, length=n)
    thr = [sum((times .>= t - window) .& (times .<= t)) / window
           for t in tg]
    return collect(tg), thr
end

# --- Run one condition ---
function run_chain(label)
    println("\n=== Running: $label ===")

    sim, net = simulation_setup(graph, regsize;
        T2=T2, endNodes=endNodes)

    for i in 1:n_flows
        flow = Flow(src=1, dst=n_nodes, npairs=npairs, uuid=i)
        put!(net[1], flow)
    end

    log_name = "chain_$(label)_log.txt"
    log_file = open(log_name, "w")
    global_logger(SimpleLogger(log_file, Logging.Info))

    run(sim, sim_time)

    flush(log_file)
    close(log_file)
    global_logger(ConsoleLogger())

    # verify counts
    function count_tags!(mb, tag_type)
        n = 0
        while !isnothing(querydelete!(mb, tag_type,
                                       ❓, ❓, ❓, ❓, ❓, ❓))
            n += 1
        end
        return n
    end

    mb_src = messagebuffer(net, 1)
    mb_dst = messagebuffer(net, n_nodes)
    n_src  = count_tags!(mb_src, QTCPPairBegin)
    n_dst  = count_tags!(mb_dst, QTCPPairEnd)
    total  = n_flows * npairs

    println("  PairBegin at src: $n_src / $total")
    println("  PairEnd   at dst: $n_dst / $total")

    # parse fidelity records
    records = Vector{Tuple{Float64, Int, Float64}}()
    open(log_name) do f
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

    println("  Fidelity records: $(length(records))")
    if !isempty(records)
        fids = [r[3] for r in records]
        println("  Mean F: $(round(mean(fids), digits=4))")
        println("  Min  F: $(round(minimum(fids), digits=4))")
    end

    times = [r[1] for r in records]
    fids  = [r[3] for r in records]
    return times, fids
end

# --- Run both conditions ---
# Step 1: set USE_AIMD = false in qtcp.jl, save, then press Enter
println("Set USE_AIMD = false in qtcp.jl and save, then press Enter...")
readline()
times_fixed, fids_fixed = run_chain("fixed")

# Step 2: set USE_AIMD = true in qtcp.jl, save, then press Enter
println("\nSet USE_AIMD = true in qtcp.jl and save, then press Enter...")
readline()
times_aimd, fids_aimd = run_chain("aimd")

# --- Plot (a): fidelity over time ---
p1 = plot(
    xlabel  = "Simulation time (s)",
    ylabel  = "Delivered fidelity F",
    title   = "(b) Fidelity over time — 5-node chain, $n_flows flows",
    legend  = :bottomleft,
    ylims   = (0.80, 1.0))

if !isempty(times_fixed)
    tg, fa = sliding_avg(times_fixed, fids_fixed, 8.0, sim_time)
    mean_f = round(mean(filter(!isnan, fa)), digits=4)
    plot!(p1, tg, fa,
        label = "Fixed window (WINDOW=3) — mean F=$mean_f",
        color = :orange, lw=2)
end

if !isempty(times_aimd)
    tg, fa = sliding_avg(times_aimd, fids_aimd, 8.0, sim_time)
    mean_f = round(mean(filter(!isnan, fa)), digits=4)
    plot!(p1, tg, fa,
        label = "AIMD + PI-AQM — mean F=$mean_f",
        color = :teal, lw=2)
end

hline!(p1, [0.875],
    color=:gray, linestyle=:dash,
    label="Entanglement threshold (approx.)")

# --- Plot (b): cumulative delivery ---
p2 = plot(
    xlabel  = "Simulation time (s)",
    ylabel  = "Cumulative pairs delivered",
    title   = "(b) Cumulative delivery — 5-node chain, $n_flows flows",
    legend  = :bottomright)

if !isempty(times_fixed)
    tg = range(0.0, sim_time, length=300)
    cum = [sum(times_fixed .<= t) for t in tg]
    plot!(p2, collect(tg), cum,
        label="Fixed window", color=:orange, lw=2)
end

if !isempty(times_aimd)
    tg = range(0.0, sim_time, length=300)
    cum = [sum(times_aimd .<= t) for t in tg]
    plot!(p2, collect(tg), cum,
        label="AIMD + PI-AQM", color=:teal, lw=2)
end

# add total expected line
hline!(p2, [n_flows * npairs],
    color=:gray, linestyle=:dash,
    label="Target ($( n_flows * npairs ) pairs)")

# --- Combine and save ---
p_combined = plot(p1, p2,
    layout       = (1, 2),
    size         = (1100, 420),
    left_margin  = 5Plots.mm,
    bottom_margin = 5Plots.mm)

savefig(p_combined, "fidelity_chain_comparison.pdf")
println("\nSaved: fidelity_chain_comparison.pdf")