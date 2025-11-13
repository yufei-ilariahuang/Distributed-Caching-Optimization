### Problem, Team, and Overview of Experiments

*   **Problem:** Modern large-scale applications, particularly those in finance and real-time data, face a critical challenge: delivering data to users with minimal latency while managing heavy load on backend systems. Direct database queries for every request are slow and unscalable. This project solves this by creating a high-performance, distributed in-memory caching system. A distributed cache acts as a fast data-access layer, drastically reducing latency, decreasing load on primary data stores, and improving overall system resilience and scalability. This is crucial for platforms that process and distribute real-time data, where speed and reliability are paramount.

*   **Team:** This project is developed by a single engineer passionate about distributed systems and performance optimization. Their expertise lies in Go programming, system design, and implementing foundational components for scalable infrastructure.

*   **Overview of Experiments:** The project will be evaluated through a series of experiments focused on performance, scalability, and correctness. Key metrics will include:
    *   **Cache Hit Rate:** Measuring the effectiveness of the cache under various load patterns.
    *   **Latency:** Measuring the average and tail latencies for cache hits and misses.
    *   **Throughput:** Determining the number of requests per second the system can handle.
    *   **Scalability:** Analyzing how performance metrics change as new nodes are added to the cluster, demonstrating the effectiveness of the consistent hashing algorithm.
    *   **Correctness:** Unit and integration tests will validate the logic of each component (LRU eviction, consistent hashing, data retrieval).

### Project Plan and Recent Progress

*   **Recent Progress:** The foundational components of the caching system have been implemented and unit-tested. This includes the core LRU cache, the consistent hashing module for key distribution, the single-flight mechanism to prevent cache stampedes, and the peer-to-peer communication logic. Most recently, service registration using etcd has been completed, allowing nodes to announce their presence in the distributed system.

*   **Timeline and Breakdown of Tasks:**
    *   **Phase 1 (Complete):**
        *   Implement core LRU cache (`lru/`).
        *   Implement consistent hashing (`consistenthash/`).
        *   Implement single-flight execution (`singleflight/`).
        *   Implement main cache logic and peer communication (`geecache/`).
        *   Add service registration with etcd (`registry/register.go`).
    *   **Phase 2 (In Progress):**
        *   **Implement Service Discovery:** Finalize the `registry/discover.go` module to allow the cache to dynamically discover and react to changes in cluster membership via etcd.
    *   **Phase 3 (Next Steps):**
        *   **Integration and Benchmarking:** Integrate all components and conduct the performance experiments outlined above.
        *   **API Finalization:** Expose a clean, public API for the cache group.
        *   **Deployment:** Package the system for deployment.

### Objectives

*   **Short-Term:** To deliver a fully functional, production-ready distributed caching system. This includes completing the dynamic service discovery feature, conducting thorough testing and benchmarking, and ensuring the system is stable and reliable. The goal is to have a system where new cache nodes can be added or removed seamlessly with zero downtime.

*   **Long-Term:** The vision extends to creating a more advanced and feature-rich caching solution. Future work includes:
    *   **Replication:** Adding data replication for enhanced fault tolerance, so the failure of a single node does not lead to data loss.
    *   **Advanced Eviction Policies:** Exploring and implementing more sophisticated eviction algorithms beyond LRU (e.g., LFU, ARC).
    *   **Security:** Implementing authentication and authorization for cache access.
    *   **Monitoring and Observability:** Integrating with monitoring tools (like Prometheus) to provide detailed insights into cache performance and health.

### Related work

This project is inspired by and builds upon the concepts of several well-established systems and academic papers.
*   **Google's Groupcache:** This project is heavily influenced by the design of `groupcache`, a caching and cache-filling library that is part of Google's production infrastructure. It borrows concepts like single-flight request collapsing and peer-to-peer data fetching.
*   **Memcached:** A classic, simple, and high-performance distributed memory object caching system. This project shares the goal of providing a fast, in-memory key-value store but adds more sophisticated features like consistent hashing within the client library.
*   **Redis:** A more feature-rich in-memory data store that can be used as a database, cache, and message broker. While Redis offers more data structures, this project focuses on excelling at one thing: providing a scalable, distributed cache for arbitrary data blobs.
*   **Consistent Hashing:** The distribution of keys across nodes is based on the principles laid out in the original paper by Karger et al., which is fundamental to building scalable distributed storage systems.

### Methodology

The proposed system is a distributed cache written in Go, designed for simplicity and performance. The architecture consists of several key components:

1.  **Node-Local Cache:** Each node in the cluster maintains an in-memory LRU (Least Recently Used) cache for fast access to hot data.
2.  **Consistent Hashing:** A consistent hash ring is used to map each data key to a specific node in the cluster. This ensures that only a small fraction of keys need to be remapped when a node is added or removed, minimizing cache churn.
3.  **Peer-to-Peer Communication:** If a node receives a request for a key that it does not own, it uses the consistent hash ring to identify the correct peer. It then acts as a client, fetching the data from that peer via an HTTP or gRPC endpoint.
4.  **Single-Flight Mechanism:** To prevent cache stampedes (where multiple concurrent requests for a missing key all hit the backend data source), a single-flight mechanism is employed. It ensures that for any given key, only one request to the backend is in flight at any time.
5.  **Service Discovery with etcd:** Nodes are not statically configured. Instead, they register themselves with an etcd cluster upon startup. A discovery module on each node watches etcd for changes in cluster membership (nodes joining or leaving) and dynamically updates its consistent hash ring accordingly. This allows for elastic scaling and high availability.

### System Architecture

The following diagram illustrates the high-level architecture of the distributed caching system.

```mermaid
graph TD
    subgraph Client
        A[Client Application]
    end

    subgraph GeeCache Cluster
        B{GeeCache Node}
        C[Local Cache (LRU)]
        D[Consistent Hash]
        E[Single Flight]
        F[Peer Communication]
    end

    subgraph Service Discovery
        G[etcd]
    end

    subgraph Backend
        H[Database]
    end

    A -- Request --> B
    B -- Local Get --> C
    B -- Key Lookup --> D
    D -- Determines Peer --> F
    F -- Remote Get --> B
    B -- If cache miss --> E
    E -- Prevents stampede --> H
    B -- Registers/Discovers --> G
```

### Preliminary Results

The individual components have been validated through comprehensive unit tests (`lru_test.go`, `consistenthash_test.go`, etc.), which serve as the initial set of results demonstrating correctness. For example, tests confirm that the LRU cache correctly evicts the least recently used item and that the consistent hash ring distributes keys as expected.

The next phase of results collection will involve integration benchmarking. The planned experiments will measure:
*   **Latency reduction:** Comparing response times for a sample application with and without the cache.
*   **Database load reduction:** Measuring the number of queries hitting the primary database under load, with and without the cache.
*   **Dynamic scaling impact:** Measuring the key re-balancing and temporary performance degradation when a new node is added to a live cluster.

Analysis of these results will be critical to fine-tuning the system for the final report.

### Impact

The significance of this project is twofold. First, it serves as a practical, hands-on implementation of a sophisticated distributed system, demonstrating a deep understanding of the principles required to build scalable, real-world infrastructure. Second, the resulting system is a valuable, reusable component for any developer building large-scale services. In an era where application performance and user experience are paramount, an effective caching layer is not a luxury but a necessity. By providing an open-source, easy-to-use, and high-performance distributed cache, this project empowers developers to build faster and more reliable applications, directly impacting end-users and business stakeholders who depend on them. For companies like Bloomberg, which operate at the intersection of big data, low latency, and high availability, the principles and implementation details of this project are directly applicable and highly valuable.