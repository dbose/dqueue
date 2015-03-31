# dqueue
Redis for scaling elasticsearch indexing

# Motivation

1. Suspends (USR2 ?) any real-time indexing queue to avoid potential race conditions downstream.

2. For indexing massive dataset, we partition (brute-force as opposed to datarow-size-based partitioning) the database 
into equal fragments

3. Then handover each such fragment (range) to a worker potentially running on a different node or in 
the same node (unless we have some sane worker_per_node threshold). 

4. The worker then makes a range query to the database, applies any necessary scope and invokes the `_bulk` API 
endpoint of Elasticsearch.

5. Workers can be scaled out across many nodes/cores. 

6. Once exhausted a worker wait for a while and the signals the master (a master is elected automatically out of 
the workers) about completion. 

7. Once master receives completion signals from all slave workers, it resumes (CONT ?) the areal-time indexing queue


