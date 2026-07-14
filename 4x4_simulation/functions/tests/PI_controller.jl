using Statistics
using Random

"""
difference equation to update the marking/drop probability (p)
based on the current and previous states of the quantum memory queue
p := a*(q-q_ref) - b*(q_old-q_ref) + p_old

Parameters:
a, b: PI coefficients (where a>b>0)
q_ref : desired queue length (or target buffer time)
q_old, p_old: state variables from previous samples
"""

#---Default constants ---
α_default = 1.822e-5            #proportional gain
β_default = 1.816e-5            #integral gain (always < alpha)
t_target_default = 0.5e-3       #target buffering time
update_interval_default = 0.1   #how often PI runs
fidelity_target_default = 0.88   #fidelty maintanance
variance_thres_default = 0.001  #max acceptable fidelity variance
α_min_default = 1e-7            #safety floor
α_max_default = 1e-3            #safety ceiling

mutable struct PIController
    p::Float64                          # current marking probability
    t_prev::Float64                     # buffering time from last step
    α::Float64                          # proportional gain
    β::Float64                          # integral gain (always < alpha)
    t_target::Float64                   # target buffering time
    fidelity_history::Vector{Float64}   # recent delivered fidelity values
    last_update_time::Float64           # sim time of last PI update
end

# convenience constructor with defaults
function PIController()
    PIController(
        0.0,                  # p starts at 0
        0.0,                  # t_prev starts at 0
        α_default,
        β_default,
        t_target_default,
        Float64[],            # empty fidelity history
        0.0                   # last update time
    )
end
##
#using proportional and integral components to periodically update the probability pᵢ → pᵢ₊₁
#between time steps i and i + 1
#pᵢ₊₁ = pᵢ + α(tᵢ₊₁ - t) - β(tᵢ - t)
#t = target buffering time

#mutating function because ctrl.p and ctrl.t_prev are being mutated
function pi_update!(ctrl::PIController, t_current::Float64)
    p_new = ctrl.p + ctrl.α * (t_current - ctrl.t_target) - ctrl.β * (ctrl.t_prev - ctrl.t_target)
    p_new = clamp(p_new, 0.0, 1.0) #clamped from [0, 1]

    #update state
    ctrl.p = p_new
    ctrl.t_prev = t_current

    return p_new
end

#---Buffering time measurement ---
#Compute the average time qdatagrams have been waiting at this switch node
function avg_buffering_time(arrival_times::Dict, current_time::Float64)
    isempty(arrival_times) && return 0.0 

    total_wait = 0.0
    for arrival_time in values(arrival_times)
        total_wait += current_time - arrival_time
    end
    num_entries = length(arrival_times)
    return total_wait/num_entries
end

##
#Decide whether to mark an arriving datagram as congested
#Called every time a QDatagram, arrives at this switch
function should_mark(ctrl::PIController)
random_value = rand()

return random_value < ctrl.p

end

##
#---Fidelity Tracking ---
"""
Record the fidelity of a delivered bell pair 
Called from EndNodeController whne QTCPPairEnd arrives
Keeps only the last N = 20 values to track recent performance
"""
function record_fidelity!(ctrl::PIController, fidelity::Float64)
#append fidelity_value to controller fidelity_history
    push!(ctrl.fidelity_history, fidelity)
    #keep only the last 20 values
    if length(ctrl.fidelity_history) > 20
        popfirst!(ctrl.fidelity_history)
    end
end

##
#---Adaptive Gain Tuning ---
"""
Adaptively tune alpha and beta based on observed network state
Called periodically -- less often than pi_update
Suggested Interval: every 10 seconds of sim time
Inputs:
    controller - the PIController struct
    flow_count - number of active flows at this node right now

The three adaptive signals are:
1. fidelity below target: increase alpha and beta to react faster
2. fidelity variance too high: decrease alpha and beta to stabilize
3. flow count scaling: more flows = more competition = tighter control needed
→ scale alpha proportionally with active flow count
"""
function adapt_gains!(ctrl::PIController, flow_count::Int)
fidelity_history = ctrl.fidelity_history

if length(fidelity_history) < 5
    return              #not enough data to adapt gains so keep current gain values
end

#Signal 1: fidelity below target
avg_fidelity = mean(ctrl.fidelity_history)
fidelity_variance = var(ctrl.fidelity_history)
if avg_fidelity < fidelity_target_default
    ctrl.α *= 1.1      #increase alpha by 10%

#Signal 2: fidelity variance too high
elseif fidelity_variance > variance_thres_default
    ctrl.α *= 0.9      #decrease alpha by 10%
end
#Signal 3: flow count scaling
ctrl.α *= 1 + 0.1 * flow_count  #increase alpha by 10% for each active flow

#maintain alpha > beta > 0 (for PI stability)
ctrl.β = ctrl.α * 0.99  #keep beta slightly less than alpha

#clamp to safe operating range
ctrl.α = clamp(ctrl.α, α_min_default, α_max_default)
ctrl.β = clamp(ctrl.β, α_min_default * 0.99, ctrl.α * 0.99)  #beta slightly less than alpha
end