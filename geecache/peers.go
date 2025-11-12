package geecache

import pb "github.com/yufei-ilariahuang/Distributed-Caching-Optimization/geecachepb"

// PeerPicker is the interface that must be implemented to locate
// the peer that owns a specific key.
type PeerPicker interface {
	PickPeer(key string) (peer PeerGetter, ok bool)
}

// PeerGetter is the interface that must be implemented by a peer to get data from the cache.
type PeerGetter interface {
	Get(in *pb.Request, out *pb.Response) error
}
