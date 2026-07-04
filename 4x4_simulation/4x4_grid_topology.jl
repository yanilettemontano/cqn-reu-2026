include("setup.jl")

#---Network Parameters---
numRows = 4
numCols = 4
numNodes = numRows * numCols #16-node grid
regSize = 20 #added more slots to handle concurrent flows
T2 = 100.0

#build the grid topology
graph = grid([numRows, numCols])

#Set up the simulation with the full QTCP protocol suite
#End nodes are the four corners of the grid.
#[1, 4, 11, 16]
endNodes = [1, numCols, numNodes - numCols + 1, numNodes]
sim, net = simulation_setup(graph, regSize; T2=T2, endNodes = endNodes)
# -- Define multiple concurrent Flows --
#flow 1: top-left(1) → top-right(numCols)
flow1 = Flow(src=1, dst = numCols, npairs = 5, uuid = 1)
put!(net[1], flow1)
#flow 2: bottom-left (n_nodes - n_cols + 1) → bottom-right(n_nodes)
flow2 = Flow(src=numNodes - numCols + 1, dst=numNodes, npairs = 5, uuid = 2)
put!(net[numNodes - numCols + 1], flow2)
#flow 3: top-left(1) → bottom-left
flow3 = Flow(src=1, dst=numNodes - numCols + 1, npairs = 5, uuid = 3)
put!(net[1], flow3)

run(sim, 100.0)

# --- Verify results ---
function count_tags!(mb, tag_type)
    n = 0
    while !isnothing(querydelete!(mb, tag_type, ❓, ❓, ❓, ❓, ❓, ❓))
        n += 1
    end
    return n
end

mb1   = messagebuffer(net, 1)
mb4   = messagebuffer(net, numCols)
mb13  = messagebuffer(net, numNodes - numCols + 1)
mb16  = messagebuffer(net, numNodes)

flow1_src = count_tags!(mb1, QTCPPairBegin)
flow1_dst = count_tags!(mb4, QTCPPairEnd)
flow2_src = count_tags!(mb13, QTCPPairBegin)
flow2_dst = count_tags!(mb16, QTCPPairEnd)
flow3_src = count_tags!(mb1, QTCPPairBegin)
flow3_dst = count_tags!(mb13, QTCPPairEnd)

#----Test to see the grid topology----

#g = grid([numRows, numCols])
#println("Grid edges:")
#for e in edges(g)
#    println("  $(e.src) -- $(e.dst)")
#end
#println("\nEnd nodes: $endNodes")
#println("Flow 1: $(flow1.src) → $(flow1.dst)")
#println("Flow 2: $(flow2.src) → $(flow2.dst)")

@info "=== Flow 1: node 1 → node $(numCols) ==="
@info "QTCPPairBegin at src: $flow1_src"
@info "QTCPPairEnd at dst:   $flow1_dst"

@info "=== Flow 2: node $(numNodes-numCols+1) → node $(numNodes) ==="
@info "QTCPPairBegin at src: $flow2_src"
@info "QTCPPairEnd at dst:   $flow2_dst"

#the asserts below checks if the PairBegin and PairEnd tags are equal at the end of the flow
#if they are not equal then the bell pairs were lost and never delivered during the flow
@assert flow1_src == flow1.npairs "Expected $(flow1.npairs) pairs at flow 1 source, got $flow1_src"
@assert flow1_dst == flow1.npairs "Expected $(flow1.npairs) pairs at flow 1 destination, got $flow1_dst"
@assert flow2_src == flow2.npairs "Expected $(flow2.npairs) pairs at flow 2 source, got $flow2_src"
@assert flow2_dst == flow2.npairs "Expected $(flow2.npairs) pairs at flow 2 destination, got $flow2_dst"