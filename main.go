package main

/*
$ curl "http://localhost:9999/api?key=Tom"
630

$ curl "http://localhost:9999/api?key=kkk"
kkk not exist
*/

import (
	"flag"
	"fmt"
	"log"
	"net/http"

	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/yufei-ilariahuang/Distributed-Caching-Optimization/geecache"
)

var db = map[string]string{
	"Tom":  "630",
	"Jack": "589",
	"Sam":  "567",
}

func createGroup() *geecache.Group {
	return geecache.NewGroup("scores", 2<<10, geecache.GetterFunc(
		func(key string) ([]byte, error) {
			log.Println("[SlowDB] search key", key)
			if v, ok := db[key]; ok {
				return []byte(v), nil
			}
			return nil, fmt.Errorf("%s not exist", key)
		}))
}

func startCacheServer(addr string, addrs []string, gee *geecache.Group) {
	peers := geecache.NewHTTPPool(addr)
	peers.Set(addrs...)
	gee.RegisterPeers(peers)

	// Expose metrics endpoint
	http.Handle("/metrics", promhttp.Handler())

	log.Println("geecache is running at", addr)
	log.Println("metrics available at", addr+"/metrics")
	// Extract port from addr (format: http://host:port) and bind to all interfaces
	port := addr[len("http://localhost"):]
	log.Fatal(http.ListenAndServe("0.0.0.0"+port, peers))
}

func startAPIServer(apiAddr string, gee *geecache.Group) {
	mux := http.NewServeMux()
	mux.Handle("/api", http.HandlerFunc(
		func(w http.ResponseWriter, r *http.Request) {
			key := r.URL.Query().Get("key")
			view, err := gee.Get(key)
			if err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			w.Header().Set("Content-Type", "application/octet-stream")
			w.Write(view.ByteSlice())

		}))
	// Expose metrics endpoint for API server
	mux.Handle("/metrics", promhttp.Handler())

	log.Println("fontend server is running at", apiAddr)
	log.Println("metrics available at", apiAddr+"/metrics")
	// Extract port from apiAddr and bind to all interfaces
	port := apiAddr[len("http://localhost"):]
	log.Fatal(http.ListenAndServe("0.0.0.0"+port, mux))

}

func main() {
	var port int
	var api bool
	flag.IntVar(&port, "port", 8001, "Geecache server port")
	flag.BoolVar(&api, "api", false, "Start a api server?")
	flag.Parse()

	apiAddr := "http://localhost:9999"
	addrMap := map[int]string{
		8001: "http://localhost:8001",
		8002: "http://localhost:8002",
		8003: "http://localhost:8003",
	}

	var addrs []string
	for _, v := range addrMap {
		addrs = append(addrs, v)
	}

	gee := createGroup()
	if api {
		go startAPIServer(apiAddr, gee)
	}
	startCacheServer(addrMap[port], addrs, gee)
}
