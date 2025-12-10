package consistenthash

import (
	"strconv"
	"testing"
)

func TestHashing(t *testing.T) {
	hash := New(3, func(key []byte) uint32 {
		i, _ := strconv.Atoi(string(key))
		return uint32(i)
	})

	// Given the above hash function, this will give replicas with "hashes":
	// 2, 4, 6, 12, 14, 16, 22, 24, 26
	hash.Add("6", "4", "2")

	testCases := map[string]string{
		"2":  "2",
		"11": "2",
		"23": "4",
		"27": "2",
	}

	for k, v := range testCases {
		if hash.Get(k) != v {
			t.Errorf("Asking for %s, should have yielded %s", k, v)
		}
	}

	// Adds 8, 18, 28
	hash.Add("8")

	// 27 should now map to 8.
	testCases["27"] = "8"

	for k, v := range testCases {
		if hash.Get(k) != v {
			t.Errorf("Asking for %s, should have yielded %s", k, v)
		}
	}

}

// Benchmark for Get operations
func BenchmarkGet(b *testing.B) {
	hash := New(150, nil)
	hash.Add("node1", "node2", "node3")

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		hash.Get("key" + strconv.Itoa(i%1000))
	}
}

// Benchmark consistent hashing with different replica counts
func BenchmarkGetWithReplicas(b *testing.B) {
	replicas := []int{1, 10, 50, 150, 500}

	for _, r := range replicas {
		b.Run("replicas="+strconv.Itoa(r), func(b *testing.B) {
			hash := New(r, nil)
			hash.Add("node1", "node2", "node3", "node4")

			b.ResetTimer()
			for i := 0; i < b.N; i++ {
				hash.Get("key" + strconv.Itoa(i%1000))
			}
		})
	}
}

// Benchmark key distribution across nodes
func BenchmarkKeyDistribution(b *testing.B) {
	hash := New(150, nil)
	nodes := []string{"node1", "node2", "node3", "node4"}
	hash.Add(nodes...)

	distribution := make(map[string]int)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		node := hash.Get("key" + strconv.Itoa(i))
		distribution[node]++
	}

	b.StopTimer()
	// Report distribution variance
	if b.N >= 10000 {
		b.Logf("Distribution after %d keys:", b.N)
		for _, node := range nodes {
			pct := float64(distribution[node]) / float64(b.N) * 100
			b.Logf("  %s: %.2f%%", node, pct)
		}
	}
}

// Benchmark adding nodes (simulating scale-up)
func BenchmarkAdd(b *testing.B) {
	for i := 0; i < b.N; i++ {
		hash := New(150, nil)
		hash.Add("node1", "node2", "node3")
		b.StartTimer()
		hash.Add("node4") // Adding 4th node
		b.StopTimer()
	}
}

// Test key redistribution when adding a node
func TestKeyRedistribution(t *testing.T) {
	hash := New(150, nil)
	hash.Add("node1", "node2", "node3")

	// Map 10000 keys
	keyMap := make(map[string]string)
	for i := 0; i < 10000; i++ {
		key := "key" + strconv.Itoa(i)
		keyMap[key] = hash.Get(key)
	}

	// Add 4th node
	hash.Add("node4")

	// Count remapped keys
	remapped := 0
	for key, oldNode := range keyMap {
		newNode := hash.Get(key)
		if oldNode != newNode {
			remapped++
		}
	}

	remapPct := float64(remapped) / float64(len(keyMap)) * 100
	t.Logf("Keys remapped after adding node4: %d/%d (%.2f%%)", remapped, len(keyMap), remapPct)

	// Theoretical expectation: ~25% (1/4) should remap to new node
	if remapPct < 15 || remapPct > 35 {
		t.Errorf("Expected ~25%% redistribution, got %.2f%%", remapPct)
	}
}
