include("pi_controller.jl")

ctrl = PIController()
println("Initial p: ", ctrl.p)          # should be 0.0

# simulate queue longer than target (0.5ms)
# t_current = 1.0ms — queue is backing up
p1 = pi_update!(ctrl, 1.0e-3)
println("p after overcrowded queue: ", p1)   # should be > 0.0

# simulate again with same overcrowded queue
p2 = pi_update!(ctrl, 1.0e-3)
println("p after second step: ", p2)         # should be > p1

# simulate empty queue — t_current = 0.0
p3 = pi_update!(ctrl, 0.0)
println("p after empty queue: ", p3)         # should decrease

#Test 2 -- verify avg_buffering_time
empty_dict = Dict{Tuple{Int, Int}, Float64}()
println(avg_buffering_time(empty_dict, 10.0))

arrival_times = Dict((1, 1) => 8.0, (1, 2) => 9.0)
println(avg_buffering_time(arrival_times, 10.0))