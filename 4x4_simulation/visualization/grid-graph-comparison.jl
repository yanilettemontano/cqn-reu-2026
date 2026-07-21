using Graphs, Statistics, Distributions
using GLMakie
include("setup.jl")

# ---- Parameters ----
n_nodes = 5
regsize = 60
T2 = 100.0
sim_time = 30.0
endNodes = [1, n_nodes]
graph = Graphs.grid([n_nodes])

# Poisson arrival parameters

λ       = 0.5   #flows per second
npairs  = 3     #pairs per flow
T_c     = 100.0 #coherence time

fig = Figure(size = (1100, 500))

ax1 = Axis(fig[1, 1],
    xlabel = "Simulation time (s)",
    ylabel = "Delivered fidelity F",
    title = "Fidelity vs time - 5-node chain, Poisson arrivals",
    limits = (0, sim_time, 0.75, 1.0))

ax2 = Axis(fig[1, 2],
    xlabel = "Simulation time (s)",
    ylabel = "Throughput (pairs/s)",
    title = "Throughput vs time",
    limits = (0, sim_time, 0, nothing))

#load region shading
vspan!(ax1, 5.0, 10.0, color=(:red, 0.08))
vspan!(ax2, 5.0, 10.0, color=(:red, 0.08))

#entanglement threshold line 
hlines!(ax1, [0.875], color=:gray, linestyle=:dash, linewidth=1)

#Observables -- live data containers 
#fixed window condition
times_fixed_obs = Observable(Float64[])
fids_fixed_obs  = Observable(Float64[])

#AIMD + PI condition
times_aimd_obs = Observable(Float64[])
fids_aimd_obs  = Observable(Float64[])

#plot scatter points 
scatter!(ax1, times_fixed_obs, fids_fixed_obs, color=:orange, markersize=6, label="Fixed window (no CC)")
scatter!(ax1, times_aimd_obs, fids_aimd_obs, color=:teal, markersize=6, label="AIMD + PI-AQM")

axislegend(ax1, position=:lb)

#throughput lines -- sliding average computed from observables
window_size = 2.0 # seconds

throughput_fixed = @lift begin
    ts = $times_fixed_obs
    isempty(ts) && return (Float64[], Float64[])
    tg = range(0.0, sim_time, length=300)
    thr = [sum((ts .>= t - window_size) .& (ts .<= t)) / window_size for t in tg]
    (collect(tg), thr)
end

throughput_aimd = @lift begin
    ts = $times_aimd_obs
    isempty(ts) && return (Float64[], Float64[])
    tg = range(0.0, sim_time, length=300)
    thr = [sum((ts .>= t - window_size) .& (ts .<= t)) / window_size for t in tg]
    (collect(tg), thr)
end

lines!(ax2, 
@lift($throughput_fixed[1]), 
@lift($throughput_fixed[2]),
color=:orange, linewidth=2, label="Fixed Window")

lines!(ax2,
@lift($throughput_aimd[1]),
@lift($throughput_aimd[2]),
color=:teal, linewidth=2, label = "AIMD + PI-AQM")

axislegend(ax2, position=:lt)

display(fig)

function run_and_stream!(
    times_obs, fids_obs;
    use_aimd::Bool, 
    step_size = 0.5)

    sim, net = simulation_setup(graph, regsize; T2=T2, endNodes=endNodes, use_aimd=use_aimd)

    uuid = Ref(1)
    t_sched = 0.0
    flows_to_inject = Vector{Tuple{Float64, Flow}}()

    for(t_start, t_stop, rate) in [
        (0.0, 5.0, λ),
        (5.0, 10.0, λ * 2.5),
        (10.0, sim_time, λ)]
        t = t_start
        while t < t_stop
            inter = rand(Exponential(1.0 / rate))
            t += inter
            t >= t_stop && break
            flow = Flow(src = 1, dst = n_nodes, npairs = npairs, uuid=uuid[])
            push!(flows_to_inject, (t, flow))
            uuid[] += 1
        end
    end
    sort!(flows_to_inject, by=x->x[1])
    println("Scheduled $(length(flows_to_inject)) flows")

    #step through simulation, inject flows, collect data live 
    t_current = 0.0 
    flow_idx = 1
    n_delievered_before = 0

    while t_current < sim_time
        t_next = min(t_current + step_size, sim_time)

        while flow_idx <= length(flows_to_inject) &&
            flows_to_inject[flow_idx][1] <= t_next 
            _, flow = flows_to_inject[flow_idx]
            put!(net[flow.src], flow)
            flow_idx += 1
        end

        run(sim, t_next)
        t_current = t_next

        reg_src = net[1]
        while true 
            tag = querydelete!(reg_src, QTCPPairBegin, ❓, ❓, ❓, ❓, ❓, ❓)
            isnothing(tag) && break
            _, flow_uuid, flow_src, flow_dst, seq_num, memory_slot, start_time = tag.tag
            transit     = t_current - start_time
            fidelity = 0.25 + 0.75 * exp(-transit / T_c)
            push!(times_obs[], t_current)
            push!(fids_obs, fidelity)
        end

        #notifies GLMakie when to restart
        notify(times_obs)
        notify(fids_obs)
        sleep(0.01)
    end
    println("Done. Delievered: $(length(times_obs[]))")

end

println("Running fixed window baseline...")
run_and_stream!(times_fixed_obs, fids_fixed_obs; use_aimd=false)

println("Running AIMD + PI_AQM...")
run_and_stream!(times_aimd_obs, fids_aimd_obs; use_aimd=true)

save("fidelity_throughput_poisson_chain.png", fig)
println("Saved: fidelity_throughput_poisson_chain.png")

