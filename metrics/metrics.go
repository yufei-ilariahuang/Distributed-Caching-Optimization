package metrics

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	// RequestsTotal counts total cache requests
	RequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "geecache_requests_total",
			Help: "Total number of cache requests",
		},
		[]string{"node", "status"}, // status: hit, miss, error
	)

	// HitsTotal counts cache hits
	HitsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "geecache_hits_total",
			Help: "Total number of cache hits",
		},
		[]string{"node"},
	)

	// MissesTotal counts cache misses
	MissesTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "geecache_misses_total",
			Help: "Total number of cache misses",
		},
		[]string{"node"},
	)

	// RequestDuration tracks request latency
	RequestDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "geecache_request_duration_seconds",
			Help:    "Request duration in seconds",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"node", "operation"},
	)

	// CacheEntries tracks number of entries in cache
	CacheEntries = promauto.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "geecache_cache_entries",
			Help: "Current number of entries in cache",
		},
		[]string{"node", "group"},
	)

	// CacheBytes tracks memory usage
	CacheBytes = promauto.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "geecache_cache_bytes",
			Help: "Current cache size in bytes",
		},
		[]string{"node", "group"},
	)

	// PeerRequestsTotal counts requests to other peers
	PeerRequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "geecache_peer_requests_total",
			Help: "Total number of requests to peer nodes",
		},
		[]string{"node", "peer", "status"},
	)

	// LoadsTotal counts loads from data source
	LoadsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "geecache_loads_total",
			Help: "Total number of loads from data source",
		},
		[]string{"node", "group"},
	)

	// SingleflightSuppressed counts requests suppressed by singleflight
	SingleflightSuppressed = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "geecache_singleflight_suppressed_total",
			Help: "Total number of duplicate requests suppressed by singleflight",
		},
		[]string{"node", "group"},
	)
)
