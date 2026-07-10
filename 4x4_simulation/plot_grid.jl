using Plots, Statistics, DelimitedFiles 

data_fixed = readdlm("grid_fixed.csv", ',')
data_aimd = readdlm("grid_aimd.csv",    ',')

times_fixed = data_fixed[:, 1]
fids_fixed  = data_fixed[:, 2]
times_aimd  = data_aimd[:, 1]
fids_aimd   = data_aimd[:, 2]

println("Fixed Window: $(length(times_fixed)) pairs, mean F=$(round(mean(fids_fixed), digits=4))")
println("AIMD:         $(length(times_aimd)) pairs, mean F=$(round(mean(fids_aimd), digits=4))")

t_end = max(maximum(times_fixed), maximum(times_aimd)) * 1.05

function sliding_avg(times, values, window, t_end, n=300)
    isempty(times) && return Float64[], Float64[]
    tg = range(0.0, t_end, length=n)
    avgs = Float64[]
    for t in tg
        mask = (times .>= t - window) .& (times .<= t)
        push!(avgs, sum(mask) > 0 ? mean(values[mask]) : NaN)
    end
    return collect(tg), avgs
end

#---Plot (b) : fidelity over time ---
p1 = plot(
    xlabel = "Simulation time (s)",
    ylabel = "Delievered fidelity F",
    title = "Fidelity over time — 4x4 grid, 6 flows",
    legend = :bottomleft,
    ylims = (0.80, 1.0))

tg, fa = sliding_avg(times_fixed, fids_fixed, 8.0, t_end)
mf = round(mean(filter(!isnan, fa)), digits=4)
plot!(p1, tg, fa,
label="Fixed window (WINDOW=3) — mean F=$mf",
color = :orange, lw=2)

tg, fa = sliding_avg(times_aimd, fids_aimd, 8.0, t_end)
mf = round(mean(filter(!isnan, fa)), digits=4)
plot!(p1, tg, fa, 
label = "AIMD + PI-AQM (this work) — mean F=$mf",
color =:teal, lw=2)

hline!(p1, [0.875], color=:gray, linestyle=:dash,
label = "Entanglement threshold (approx.)")