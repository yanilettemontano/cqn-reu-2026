include("setup.jl")

numRows = 4
numCols = 4
numNodes = numRows * numCols #16-node grid
regSize = 90 #added more slots to handle concurrent flows
T2 = 100.0

graph = grid([numRows, numCols])

#Set up the simulation with the full QTCP protocol suite
#End nodes are the four corners of the grid.
#[1, 4, 11, 16]
endNodes = [1, numCols, numNodes - numCols + 1, numNodes]
sim, net = simulation_setup(graph, regSize; T2=T2, endNodes = endNodes)
# -- Define multiple concurrent Flows --
flow1 = Flow(src=1,  dst=4,  npairs=5, uuid=1)  # top row

flow2 = Flow(src=13, dst=16, npairs=5, uuid=2)  # bottom row
flow3 = Flow(src=1,  dst=13, npairs=5, uuid=3)  # diagonal
flow4 = Flow(src=4,  dst=16, npairs=5, uuid=4)  # diagonal
flow5 = Flow(src=1,  dst=16, npairs=5, uuid=5)  # corner to corner
flow6 = Flow(src=4,  dst=13, npairs=5, uuid=6)  # corner to corner

put!(net[1], flow1)
put!(net[numNodes-numCols+1], flow2)
put!(net[1], flow3)
put!(net[numCols], flow4)
put!(net[1], flow5)
put!(net[numCols], flow6)

run(sim, 300.0)
# --- Verify results ---
function count_tags!(mb, tag_type, flow_uuid)
    n = 0
    while !isnothing(querydelete!(mb, tag_type, flow_uuid, ❓, ❓, ❓, ❓, ❓))
        n += 1
    end
    return n
end

mb1   = messagebuffer(net, 1)
mb4   = messagebuffer(net, numCols)
mb13  = messagebuffer(net, numNodes - numCols + 1)
mb16  = messagebuffer(net, numNodes)

flow1_src = count_tags!(mb1, QTCPPairBegin, 1)
flow1_dst = count_tags!(mb4, QTCPPairEnd, 1)
flow2_src = count_tags!(mb13, QTCPPairBegin, 2)
flow2_dst = count_tags!(mb16, QTCPPairEnd, 2)
flow3_src = count_tags!(mb1, QTCPPairBegin, 3)
flow3_dst = count_tags!(mb13, QTCPPairEnd, 3)
flow4_src = count_tags!(mb4, QTCPPairBegin, 4)
flow4_dst = count_tags!(mb16, QTCPPairEnd, 4)
flow5_src = count_tags!(mb1, QTCPPairBegin, 5)
flow5_dst = count_tags!(mb16, QTCPPairEnd, 5)
flow6_src = count_tags!(mb4, QTCPPairBegin, 6)
flow6_dst = count_tags!(mb13, QTCPPairEnd, 6)

@info "=== Flow 1: node 1 → node $(numCols) ==="
@info "QTCPPairBegin at src: $flow1_src"
@info "QTCPPairEnd at dst:   $flow1_dst"

@info "=== Flow 2: node $(numNodes-numCols+1) → node $(numNodes) ==="
@info "QTCPPairBegin at src: $flow2_src"
@info "QTCPPairEnd at dst:   $flow2_dst"

@info "=== Flow 3: node 1 → node $(numNodes-numCols+1) ==="
@info "QTCPPairBegin at src: $flow3_src"
@info "QTCPPairEnd at dst:   $flow3_dst"

@info "=== Flow 4: node $(numCols) → node $(numNodes) ==="
@info "QTCPPairBegin at src: $flow4_src"
@info "QTCPPairEnd at dst:   $flow4_dst"

@info "=== Flow 5: node 1 → node $(numNodes) ==="
@info "QTCPPairBegin at src: $flow5_src"
@info "QTCPPairEnd at dst:   $flow5_dst"

@info "=== Flow 6: node $(numCols) → node $(numNodes-numCols+1) ==="
@info "QTCPPairBegin at src: $flow6_src"
@info "QTCPPairEnd at dst:   $flow6_dst"

#the asserts below checks if the PairBegin and PairEnd tags are equal at the end of the flow
#if they are not equal then the bell pairs were lost and never delivered during the flow
@assert flow1_src == flow1.npairs "Expected $(flow1.npairs) pairs at flow 1 source, got $flow1_src"
@assert flow1_dst == flow1.npairs "Expected $(flow1.npairs) pairs at flow 1 destination, got $flow1_dst"
@assert flow2_src == flow2.npairs "Expected $(flow2.npairs) pairs at flow 2 source, got $flow2_src"
@assert flow2_dst == flow2.npairs "Expected $(flow2.npairs) pairs at flow 2 destination, got $flow2_dst"
@assert flow3_src == flow3.npairs "Expected $(flow3.npairs) pairs at flow 3 source, got $flow3_src"
@assert flow3_dst == flow3.npairs "Expected $(flow3.npairs) pairs at flow 3 destination, got $flow3_dst"
@assert flow4_src == flow4.npairs "Expected $(flow4.npairs) pairs at flow 4 source, got $flow4_src"
@assert flow4_dst == flow4.npairs "Expected $(flow4.npairs) pairs at flow 4 destination, got $flow4_dst"
@assert flow5_src == flow5.npairs "Expected $(flow5.npairs) pairs at flow 5 source, got $flow5_src"
@assert flow5_dst == flow5.npairs "Expected $(flow5.npairs) pairs at flow 5 destination, got $flow5_dst"
@assert flow6_src == flow6.npairs "Expected $(flow6.npairs) pairs at flow 6 source, got $flow6_src"
@assert flow6_dst == flow6.npairs "Expected $(flow6.npairs) pairs at flow 6 destination, got $flow6_dst"