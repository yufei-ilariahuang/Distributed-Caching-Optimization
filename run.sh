#!/bin/bash
trap "rm server;kill 0" EXIT

go build -o server
./server -port=8001 &
./server -port=8002 &
./server -port=8003 -api=1 &

sleep 2
echo ">>> start cache breakdown test"


# Test 2: Heavy load (1000000 concurrent requests) - Real cache breakdown scenario
echo "=== Test 2: 1000000 concurrent requests (Cache Breakdown) ==="
for i in {1..1000000}; do
  curl "http://localhost:9999/api?key=Tom" &
done
wait

