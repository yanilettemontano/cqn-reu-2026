using Graphs, Statistics, Distributions
using GLMakie
using Logging
using Random

include("setup.jl")

# ── LivePlotLogger — defined ONCE at top level ───────────────
# intercepts FIDELITY RECORD log lines and pushes to Makie observables
struct LivePlotLogger <: Logging.AbstractLogger
    times_obs::Observable{Vector{Float64}}
    fids_obs::Observable{Vector{Float64}}
end

Logging.min_enabled_level(::LivePlotLogger) = Logging.Info

Logging.shouldlog(::LivePlotLogger, level, _module, group, id) =
    level >= Logging.Info

function Logging.handle_message(logger::LivePlotLogger, level, message,
                                _module, group, id, file, line; kwargs...)
    msg = string(message)
    if occursin("FIDELITY RECORD", msg)
        m = match(r"\[([0-9.]+)\].*F=([0-9.]+)", msg)
        if !isnothing(m)
            push!(logger.times_obs[], parse(Float64, m[1]))
            push!(logger.fids_obs[],  parse(Float64, m[2]))
            notify(logger.times_obs)
            notify(logger.fids_obs)
            yield()
        end
    end
end

# ── Parameters ───────────────────────────────────────────────
n_nodes  = 5
regsize  = 60
T2       = 100.0
sim_time = 50.0
endNodes = [1, n_nodes]
graph    = Graphs.grid([n_nodes])

λ       = 0.5   # flows per second
npairs  = 3     # pairs per flow

# ── Build figure ─────────────────────────────────────────────
fig = Figure(size=(1100, 500))

ax1 = Axis(fig[1, 1],
    xlabel = "Simulation time (s)",
    ylabel = "Delivered fidelity F",
    title  = "Fidelity vs time — 5-node chain, Poisson arrivals",
    limits = (0, sim_time, 0.75, 1.0))

ax2 = Axis(fig[1, 2],
    xlabel = "Simulation time (s)",
    ylabel = "Throughput (pairs/s)",
    title  = "Throughput vs time",
    limits = (0, sim_time, 0, nothing))

# entanglement threshold
hlines!(ax1, [0.875], color=:gray, linestyle=:dash, linewidth=1)

# ── Observables ───────────────────────────────────────────────
times_fixed_obs = Observable(Float64[])
fids_fixed_obs  = Observable(Float64[])
times_aimd_obs  = Observable(Float64[])
fids_aimd_obs   = Observable(Float64[])

# scatter plots — each point is one delivered Bell pair
scatter!(ax1, times_fixed_obs, fids_fixed_obs,
    color=:orange, markersize=6, label="Fixed window (no CC)")
scatter!(ax1, times_aimd_obs, fids_aimd_obs,
    color=:teal, markersize=6, label="AIMD + PI-AQM")

axislegend(ax1, position=:lb)

# ── Throughput — separate observables updated manually ────────
# Using @lift on a tuple doesn't work well with lines! 
# Instead use separate time and value observables for throughput
thr_times_fixed = Observable(Float64[])
thr_vals_fixed  = Observable(Float64[])
thr_times_aimd  = Observable(Float64[])
thr_vals_aimd   = Observable(Float64[])

lines!(ax2, thr_times_fixed, thr_vals_fixed,
    color=:orange, linewidth=2, label="Fixed window")
lines!(ax2, thr_times_aimd, thr_vals_aimd,
    color=:teal, linewidth=2, label="AIMD + PI-AQM")

axislegend(ax2, position=:lt)

display(fig)

# ── Throughput update helper ──────────────────────────────────
function update_throughput!(thr_times_obs, thr_vals_obs, times_data, window=2.0)
    isempty(times_data) && return
    tg  = range(0.0, sim_time, length=300)   # always full range
    thr = [sum((times_data .>= t - window) .& (times_data .<= t)) / window
           for t in tg]
    thr_times_obs[] = collect(tg)
    thr_vals_obs[]  = thr
    notify(thr_times_obs)
    notify(thr_vals_obs)
end

# ── Poisson flow schedule generator ──────────────────────────
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
    sort!(scheduled, by=x -> x[1])
    return scheduled
end

Random.seed!(42)
scheduled_flows = generate_schedule(sim_time, λ)
# ── run_and_stream! ───────────────────────────────────────────
function run_and_stream!(times_obs, fids_obs, thr_times_obs, thr_vals_obs, scheduled_flows;
                         use_aimd::Bool, step_size=0.5)
    println("\n=== $(use_aimd ? "AIMD + PI-AQM" : "Fixed window") ===")

    sim, net = simulation_setup(graph, regsize;
        T2=T2, endNodes=endNodes, use_aimd=use_aimd)

    # schedule Poisson flows
    uuid_counter    = Ref(1)
    scheduled_flows = Vector{Tuple{Float64, Int}}()
    t = 0.0
    while t < sim_time
        inter = rand(Exponential(1.0 / λ))
        t += inter
        t >= sim_time && break
        push!(scheduled_flows, (t, uuid_counter[]))
        uuid_counter[] += 1
    end
    sort!(scheduled_flows, by=x -> x[1])
    println("  Scheduled $(length(scheduled_flows)) flows")

    flow_idx  = 1
    t_current = 0.0

    # use the top-level LivePlotLogger
    live_logger = LivePlotLogger(times_obs, fids_obs)

    with_logger(live_logger) do
        while t_current < sim_time
            t_next = min(t_current + step_size, sim_time)

            # inject flows due before t_next
            while flow_idx <= length(scheduled_flows) &&
                  scheduled_flows[flow_idx][1] <= t_next
                _, uuid = scheduled_flows[flow_idx]
                flow = Flow(src=1, dst=n_nodes,
                            npairs=npairs, uuid=uuid)
                put!(net[1], flow)
                flow_idx += 1
            end

            run(sim, t_next)
            t_current = t_next

            # update throughput plot with current data
            update_throughput!(thr_times_obs, thr_vals_obs, times_obs[])

            yield()  # let Makie render new points
        end
    end

    println("  Done. Delivered: $(length(times_obs[]))")
    if !isempty(times_obs[])
        println("  Mean F: $(round(mean(fids_obs[]), digits=4))")
        println("  Min  F: $(round(minimum(fids_obs[]), digits=4))")
    end
end

# ── Run both conditions ───────────────────────────────────────

println("Running fixed window baseline...")
run_and_stream!(times_fixed_obs, fids_fixed_obs,
                thr_times_fixed, thr_vals_fixed,
                scheduled_flows;
                use_aimd=false)

println("\nRunning AIMD + PI-AQM...")
run_and_stream!(times_aimd_obs, fids_aimd_obs,
                thr_times_aimd, thr_vals_aimd,
                scheduled_flows;
                use_aimd=true)

# ── Save final figure ─────────────────────────────────────────
save("fidelity_throughput_poisson_chain.png", fig)
println("\nSaved: fidelity_throughput_poisson_chain.png")