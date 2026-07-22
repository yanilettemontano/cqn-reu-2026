using Graphs, Statistics, Distributions, Plots
import Random, Logging

include("setup.jl")

# ── Parameters ───────────────────────────────────────────────
n_nodes  = 5
regsize  = 60
T2       = 100.0
sim_time = 50.0
endNodes = [1, n_nodes]
graph    = Graphs.grid([n_nodes])
λ        = 0.5    # flows per second
npairs   = 3      # pairs per flow
T_c      = 100.0  # coherence time

# ── Poisson schedule — generated ONCE, shared by both runs ───
Random.seed!(42)
function generate_schedule(sim_time, arrival_rate)
    scheduled = Vector{Tuple{Float64, Int}}()
    t    = 0.0
    uuid = 1
    while t < sim_time
        inter = rand(Exponential(1.0 / arrival_rate))
        t += inter
        t >= sim_time && break
        push!(scheduled, (t, uuid))
        uuid += 1
    end
    return sort(scheduled, by=x -> x[1])
end

shared_schedule = generate_schedule(sim_time, λ)
println("Generated $(length(shared_schedule)) flows (shared by both conditions)")

# ── Custom logger — collects data during simulation ───────────
mutable struct DataCollector <: Logging.AbstractLogger
    times::Vector{Float64}
    fids::Vector{Float64}
end

DataCollector() = DataCollector(Float64[], Float64[])

Logging.min_enabled_level(::DataCollector) = Logging.Info
Logging.shouldlog(::DataCollector, level, _m, _g, _id) = level >= Logging.Info

function Logging.handle_message(dc::DataCollector, level, message,
                                _m, _g, _id, _f, _l; kwargs...)
    msg = string(message)
    if occursin("FIDELITY RECORD", msg)
        m = match(r"\[([0-9.]+)\].*F=([0-9.]+)", msg)
        if !isnothing(m)
            push!(dc.times, parse(Float64, m[1]))
            push!(dc.fids,  parse(Float64, m[2]))
        end
    end
end

# ── Run one simulation condition ──────────────────────────────
function run_condition(scheduled_flows; use_aimd::Bool)
    label = use_aimd ? "AIMD + PI-AQM" : "Fixed window"
    println("\n=== $label ===")

    sim, net = simulation_setup(graph, regsize;
        T2=T2, endNodes=endNodes, use_aimd=use_aimd)

    dc       = DataCollector()
    flow_idx = 1
    t_cur    = 0.0

    Logging.with_logger(dc) do
        while t_cur < sim_time
            t_next = min(t_cur + 0.5, sim_time)

            while flow_idx <= length(scheduled_flows) &&
                  scheduled_flows[flow_idx][1] <= t_next
                _, uuid = scheduled_flows[flow_idx]
                put!(net[1], Flow(src=1, dst=n_nodes,
                                  npairs=npairs, uuid=uuid))
                flow_idx += 1
            end

            run(sim, t_next)
            t_cur = t_next
        end
    end

    println("  Delivered: $(length(dc.times)) pairs")
    isempty(dc.fids) || println("  Mean F: $(round(mean(dc.fids), digits=4))")
    isempty(dc.fids) || println("  Min  F: $(round(minimum(dc.fids), digits=4))")

    return dc.times, dc.fids
end

# ── Run both conditions ───────────────────────────────────────
times_fixed, fids_fixed = run_condition(shared_schedule; use_aimd=false)
times_aimd,  fids_aimd  = run_condition(shared_schedule; use_aimd=true)

# ── Sliding average helper ────────────────────────────────────
function sliding_avg(times, values, window, t_end, n=400)
    isempty(times) && return Float64[], Float64[]
    tg   = range(0.0, t_end, length=n)
    avgs = [let mask = (times .>= t - window) .& (times .<= t)
                sum(mask) > 0 ? mean(values[mask]) : NaN
            end for t in tg]
    return collect(tg), avgs
end

# ── Plot (a): fidelity over time — LINE not scatter ───────────
p1 = plot(
    xlabel    = "Simulation time (s)",
    ylabel    = "Delivered fidelity F",
    title     = "(a) Fidelity over time — 5-node chain",
    legend    = :bottomleft,
    ylims     = (0.75, 1.0),
    size      = (600, 400),
    linewidth = 2)

# sliding average line — smooth, no scatter
if !isempty(times_fixed)
    tg, fa = sliding_avg(times_fixed, fids_fixed, 4.0, sim_time)
    plot!(p1, tg, fa,
        label     = "Fixed window (WINDOW=3) — mean F=$(round(mean(filter(!isnan,fa)),digits=4))",
        color     = :orange,
        linewidth = 2)
end

if !isempty(times_aimd)
    tg, fa = sliding_avg(times_aimd, fids_aimd, 4.0, sim_time)
    plot!(p1, tg, fa,
        label     = "AIMD + PI-AQM (this work) — mean F=$(round(mean(filter(!isnan,fa)),digits=4))",
        color     = :teal,
        linewidth = 2)
end

hline!(p1, [0.875],
    color     = :gray,
    linestyle = :dash,
    linewidth = 1,
    label     = "Entanglement threshold (F=0.875)")

# ── Plot (b): cumulative pairs delivered ──────────────────────
p2 = plot(
    xlabel    = "Simulation time (s)",
    ylabel    = "Cumulative pairs delivered",
    title     = "(b) Cumulative delivery — 5-node chain",
    legend    = :bottomright,
    size      = (600, 400),
    linewidth = 2)

if !isempty(times_fixed)
    tg = range(0.0, sim_time, length=500)
    cm = [sum(times_fixed .<= t) for t in tg]
    plot!(p2, collect(tg), cm,
        label     = "Fixed window",
        color     = :orange,
        linewidth = 2)
end

if !isempty(times_aimd)
    tg = range(0.0, sim_time, length=500)
    cm = [sum(times_aimd .<= t) for t in tg]
    plot!(p2, collect(tg), cm,
        label     = "AIMD + PI-AQM",
        color     = :teal,
        linewidth = 2)
end

# target line
n_total = length(shared_schedule) * npairs
hline!(p2, [min(n_total, max(length(times_fixed), length(times_aimd)))],
    color     = :gray,
    linestyle = :dash,
    linewidth = 1,
    label     = "Max possible")

# ── Combine and save ─────────────────────────────────────────
p_combined = plot(p1, p2,
    layout        = (1, 2),
    size          = (1200, 450),
    left_margin   = 5Plots.mm,
    bottom_margin = 5Plots.mm,
    dpi           = 150)

savefig(p_combined, "fidelity_chain_poisson.pdf")
savefig(p_combined, "fidelity_chain_poisson.png")
println("\nSaved: fidelity_chain_poisson.pdf and .png")

# ── Summary table ─────────────────────────────────────────────
println("\n=== Results Summary ===")
println("Condition        | Delivered | Mean F | Min F")
println("-----------------|-----------|--------|------")
if !isempty(fids_fixed)
    println("Fixed window     | $(lpad(length(fids_fixed),9)) | $(round(mean(fids_fixed),digits=4)) | $(round(minimum(fids_fixed),digits=4))")
end
if !isempty(fids_aimd)
    println("AIMD + PI-AQM    | $(lpad(length(fids_aimd),9)) | $(round(mean(fids_aimd),digits=4)) | $(round(minimum(fids_aimd),digits=4))")
end