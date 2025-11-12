package registry

import (
	"context"
	"log"
	"sync"
	"time"

	clientv3 "go.etcd.io/etcd/client/v3"
	"go.etcd.io/etcd/client/v3/naming/resolver"
	"google.golang.org/grpc"
)

// ServiceDiscovery defines a struct for service discovery.
type ServiceDiscovery struct {
	client     *clientv3.Client
	serverChan chan []string // Channel to send server list updates
	prefix     string
	stop       chan struct{}
	serverList sync.Map // Using sync.Map for concurrent-safe access
}

// NewServiceDiscovery creates a new ServiceDiscovery instance.
func NewServiceDiscovery(endpoints []string, serviceName string) (*ServiceDiscovery, error) {
	cli, err := clientv3.New(clientv3.Config{
		Endpoints:   endpoints,
		DialTimeout: 5 * time.Second,
	})
	if err != nil {
		return nil, err
	}

	sd := &ServiceDiscovery{
		client:     cli,
		serverChan: make(chan []string, 1), // Buffered channel
		prefix:     "/" + serviceName,
		stop:       make(chan struct{}),
	}

	go sd.watchService()

	return sd, nil
}

// watchService watches for changes in the service directory.
func (sd *ServiceDiscovery) watchService() {
	// Get initial list of servers
	if err := sd.fetchAndSend(); err != nil {
		log.Printf("Failed to fetch initial server list: %v", err)
		// Optionally, you might want to retry or handle this error more gracefully
	}

	// Set up a watch channel
	watchChan := sd.client.Watch(context.Background(), sd.prefix, clientv3.WithPrefix())

	for {
		select {
		case <-sd.stop:
			log.Println("Stopping service discovery watch.")
			return
		case watchResp := <-watchChan:
			for _, ev := range watchResp.Events {
				switch ev.Type {
				case clientv3.EventTypePut: // New server or update
					sd.serverList.Store(string(ev.Kv.Key), string(ev.Kv.Value))
				case clientv3.EventTypeDelete: // Server down
					sd.serverList.Delete(string(ev.Kv.Key))
				}
			}
			// After processing events, send the updated list
			if err := sd.sendUpdatedList(); err != nil {
				log.Printf("Failed to send updated server list: %v", err)
			}
		}
	}
}

// fetchAndSend gets all servers and sends them to the channel.
func (sd *ServiceDiscovery) fetchAndSend() error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	resp, err := sd.client.Get(ctx, sd.prefix, clientv3.WithPrefix())
	if err != nil {
		return err
	}

	for _, kv := range resp.Kvs {
		sd.serverList.Store(string(kv.Key), string(kv.Value))
	}

	return sd.sendUpdatedList()
}

// sendUpdatedList collects server addresses from sync.Map and sends them to the channel.
func (sd *ServiceDiscovery) sendUpdatedList() error {
	var servers []string
	sd.serverList.Range(func(key, value interface{}) bool {
		servers = append(servers, value.(string))
		return true
	})

	// Non-blocking send to avoid getting stuck if the receiver is not ready
	select {
	case sd.serverChan <- servers:
		log.Printf("Sent updated server list: %v", servers)
	default:
		// If the channel is full, drain it and send the new list
		log.Println("Server channel full, draining and sending new list.")
		<-sd.serverChan
		sd.serverChan <- servers
	}

	return nil
}

// GetServerChan returns the channel for server list updates.
func (sd *ServiceDiscovery) GetServerChan() <-chan []string {
	return sd.serverChan
}

// Close stops the service discovery and closes the etcd client.
func (sd *ServiceDiscovery) Close() error {
	close(sd.stop)
	return sd.client.Close()
}

// EtcdDial request grpc for new service connection
// By providing an etcd client and service name, you can obtain a Connection
func EtcdDial(c *clientv3.Client, service string) (*grpc.ClientConn, error) {
	etcdResolver, err := resolver.NewBuilder(c)
	if err != nil {
		return nil, err
	}
	return grpc.Dial(
		"etcd:///"+service,
		grpc.WithResolvers(etcdResolver),
		grpc.WithInsecure(),
		grpc.WithBlock(),
	)
}