using Plots, Statistics

# data from your two runs
times_aimd  = [3.006, 4.006, 5.006, 6.006, 7.006, 8.006, 9.006, 10.006, 11.006,
               12.006, 13.006, 14.006, 15.006, 16.006, 17.006, 18.006, 19.006,
               20.006, 21.006, 22.006, 23.006, 24.006, 25.006, 26.006, 27.006,
               28.006, 29.006, 30.006, 31.006, 32.006, 33.006, 34.006, 35.006,
               36.006, 37.006, 38.006, 39.006, 40.006, 41.006, 42.006, 43.006,
               44.006, 45.006, 46.006, 47.006]

fids_aimd   = [0.9778, 0.9705, 0.9634, 0.9563, 0.9493, 0.9423, 0.9354, 0.9286,
               0.9218, 0.9354, 0.9286, 0.9286, 0.9219, 0.9219, 0.9152, 0.9152,
               0.9086, 0.9086, 0.908, 0.8955, 0.8955, 0.8955, 0.8991, 0.8991,
               0.8827, 0.8827, 0.8765, 0.8765, 0.8702, 0.8765, 0.8702, 0.8765,
               0.8702, 0.8765, 0.8702, 0.8765, 0.8702, 0.8702, 0.864, 0.8765, 
               0.8702, 0.8765, 0.8765, 0.8765, 0.8702]

times_fixed = [3.006, 4.006, 5.006, 6.006, 7.006, 8.006, 9.006, 10.006, 11.006,
               12.006, 13.006, 14.006, 15.006, 16.006, 17.006, 18.006, 19.006,
               20.006, 21.006, 22.006, 23.006, 24.006, 25.006, 26.006, 27.006,
               28.006, 29.006, 30.006, 31.006, 32.006, 33.006, 34.006, 35.006,
               36.006, 37.006, 38.006, 39.006, 40.006, 41.006, 42.006, 43.006,
               44.006, 45.006, 46.006, 47.006]

fids_fixed  = [0.9778, 0.9705, 0.9634, 0.9563, 0.9493, 0.9423, 0.9354, 0.9286, 
               0.9218, 0.9152, 0.9085, 0.902, 0.8955, 0.8891, 0.8827, 0.8764, 
               0.8702, 0.864, 0.8579, 0.8519, 0.8459, 0.8399, 0.8341, 0.8283,
               0.8225, 0.8168, 0.8112, 0.8225, 0.8225, 0.8225, 0.8225, 0.8225, 
               0.8225, 0.84, 0.84, 0.84, 0.84, 0.84, 0.84, 0.8579, 0.8579, 0.8579,
               0.8579, 0.8579, 0.8579]

# sliding average function
function sliding_avg(times, values, window, t_end, n=200)
    tg   = range(0.0, t_end, length=n)
    avgs = Float64[]
    for t in tg
        mask = (times .>= t - window) .& (times .<= t)
        push!(avgs, sum(mask) > 0 ? mean(values[mask]) : NaN)
    end
    return collect(tg), avgs
end

function sliding_thru(times, window, t_end, n=200)
    tg  = range(0.0, t_end, length=n)
    thr = [sum((times .>= t-window) .& (times .<= t)) / window
           for t in tg]
    return collect(tg), thr
end

# --- Plot (a): fidelity over time ---
p1 = plot(xlabel="Simulation time (s)",
          ylabel="Delivered fidelity F",
          title="(a) Fidelity over time -- Dumbbell",
          legend=:bottomleft,
          ylims=(0.82, 1.0))

tg, fa = sliding_avg(times_fixed, fids_fixed, 8.0, 50.0)
plot!(p1, tg, fa, label="Fixed window (WINDOW=3)",
      color=:orange, lw=2)

tg, fa = sliding_avg(times_aimd, fids_aimd, 8.0, 50.0)
plot!(p1, tg, fa, label="AIMD + PI-AQM (this work)",
      color=:teal, lw=2)

hline!(p1, [0.875], color=:gray, linestyle=:dash,
       label="Entanglement threshold approx.")
