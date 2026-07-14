include("setup.jl")
using GLMakie
GLMakie.activate!(inline=false)

# --- Network parameters ---
numRows = 4
numCols = 4
numNodes = numRows * numCols
regsize = 90
T2 = 100.0

graph = grid([numRows, numCols])

endNodes = [1, numCols, numNodes-numCols + 1, numNodes]
sim, net = simulation_setup(graph, regsize; T2=T2)

flow = Flow(src=1, dst=4, npairs=5, uuid=1)
put!(net[1], flow)

fig = Figure(size=(1000, 400))
_, ax, _, obs = registernetplot_axis(fig[1,1], net)
ax.title = "QTCP on a 5-node repeater chain"

display(fig)


step_size = 0.05
step_ts = range(0, 25, step=step_size)
output_path = "qtcp_grid.mp4"

record(fig, output_path, step_ts; framerate=30, visible=true) do t
    run(sim, t)
    ax.title = "t = $(round(t, digits=1))"
    notify(obs)
end

function count_delivered!(mb, tag_type)
    n = 0
    while !isnothing(querydelete!(mb, tag_type, ❓, ❓, ❓, ❓, ❓, ❓))
        n += 1
    end
    return n
end

mb_src = messagebuffer(net, 1)
mb_dst = messagebuffer(net, n_nodes)
n_delivered_src = count_delivered!(mb_src, QTCPPairBegin)
n_delivered_dst = count_delivered!(mb_dst, QTCPPairEnd)

@assert n_delivered_src == flow.npairs"Expected $(flow.npairs) pairs at source, got $n_delivered_src"
@assert n_delivered_dst == flow.npairs "Expected $(flow.npairs) pairs at destination, got $n_delivered_dst"
@assert isfile(output_path) "Expected visualization output $(output_path) to be created"

@info "Animation saved to $(output_path)"