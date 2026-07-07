include(setup.jl)
function dumbbell_graph(cluster_size::Int)
    g = SimpleGraph(2 * cluster_size + 2)
    #left cluster: nodes 1..cluster_size, hub at cluster_size+1
    for i in 1:cluster_size
        add_edge!(g, i, cluster_size + 1)
    end
    #right cluster: nodes cluster_size+3..end, hub at cluster_size+2
    for i in 1:cluster_size
        add_edge!(g, cluster_size + 2 + i - 1, cluster_size + 2)
    end
    #bottleneck link between the two hubs
    add_edge!(g, cluster_size + 1, cluster_size + 2)
    return g
end

dumbbell = dumbbell_graph(3) #two clusters of 3 + 2 hubs = 8 nodes