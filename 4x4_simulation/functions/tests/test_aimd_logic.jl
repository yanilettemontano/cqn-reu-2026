window = Dict(1 => 1.0)
ssthresh = Dict(1 => 16.0)
in_slow_start = Dict(1 => true)

#simulate 10 successful ACKs
for i in 1:10
    if in_slow_start[1]
        window[1] += 1.0
        if window[1] >= ssthresh[1]
            in_slow_start[1] = false
        end
    else
        window[1] += 1.0 / window[1]
    end
    println("After ACK $i: window=$(round(window[1], digits=2)), slow_start = $(in_slow_start[1])")
end

#simulate a congestion event
old_window = window[1]
ssthresh[1] = max(window[1] / 2.0, 1.0)
window[1] = ssthresh[1]
in_slow_start[1] = false
println("After Congestion: window dropped from $(round(old_window, digits=2)) to $(round(window[1], digits=2))")