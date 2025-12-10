package singleflight

import (
	"testing"
)

func TestDo(t *testing.T) {
	var g Group
	v, err := g.Do("key", func() (interface{}, error) {
		return "bar", nil
	})

	if v != "bar" || err != nil {
		t.Errorf("Do v = %v, error = %v", v, err)
	}
}

// Test concurrent requests to same key (cache stampede scenario)
func TestConcurrentCalls(t *testing.T) {
	var g Group
	callCount := 0

	// Simulate 100 concurrent requests for the same key
	const concurrent = 100
	results := make(chan string, concurrent)

	for i := 0; i < concurrent; i++ {
		go func() {
			v, _ := g.Do("expensive_key", func() (interface{}, error) {
				callCount++ // This should only increment ONCE
				return "result", nil
			})
			results <- v.(string)
		}()
	}

	// Collect all results
	for i := 0; i < concurrent; i++ {
		<-results
	}

	// The function should only be called once despite 100 concurrent requests
	if callCount != 1 {
		t.Errorf("Expected function to be called 1 time, but was called %d times", callCount)
	}

	t.Logf("✓ Cache stampede prevented: %d concurrent requests → %d database call", concurrent, callCount)
}

// Benchmark WITH singleflight (current implementation)
func BenchmarkSingleflightEnabled(b *testing.B) {
	var g Group

	b.Run("sequential", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			g.Do("key", func() (interface{}, error) {
				return "value", nil
			})
		}
	})

	b.Run("concurrent_same_key", func(b *testing.B) {
		b.RunParallel(func(pb *testing.PB) {
			for pb.Next() {
				g.Do("shared_key", func() (interface{}, error) {
					return "value", nil
				})
			}
		})
	})

	b.Run("concurrent_different_keys", func(b *testing.B) {
		i := 0
		b.RunParallel(func(pb *testing.PB) {
			for pb.Next() {
				i++
				g.Do(string(rune(i)), func() (interface{}, error) {
					return "value", nil
				})
			}
		})
	})
}

// Benchmark WITHOUT singleflight (naive approach)
func BenchmarkWithoutSingleflight(b *testing.B) {
	// Simulate direct database calls without deduplication
	dbCall := func(key string) (interface{}, error) {
		return "value", nil
	}

	b.Run("sequential", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			dbCall("key")
		}
	})

	b.Run("concurrent_same_key", func(b *testing.B) {
		// Without singleflight, all concurrent requests hit the database
		b.RunParallel(func(pb *testing.PB) {
			for pb.Next() {
				dbCall("shared_key")
			}
		})
	})
}
