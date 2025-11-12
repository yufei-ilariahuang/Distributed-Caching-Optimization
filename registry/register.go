package registry

import (
	"context"
	"fmt"
	"log"
	"time"

	"go.etcd.io/etcd/client/v3"
)

// Register creates and manages a service registration in etcd.
type Register struct {
	etcdClient *clientv3.Client
	leaseID    clientv3.LeaseID

	// service info
	serviceName string
	serviceAddr string

	stop chan error
}

const (
	defaultLeaseTTL = 10 // 10 seconds
)

// NewRegister creates a new service registration.
func NewRegister(endpoints []string, serviceName, serviceAddr string, leaseTTL int64) (*Register, error) {
	if serviceName == "" || serviceAddr == "" {
		return nil, fmt.Errorf("service name and address must be provided")
	}

	cli, err := clientv3.New(clientv3.Config{
		Endpoints:   endpoints,
		DialTimeout: 5 * time.Second,
	})
	if err != nil {
		return nil, err
	}

	if leaseTTL == 0 {
		leaseTTL = defaultLeaseTTL
	}

	reg := &Register{
		etcdClient:  cli,
		serviceName: serviceName,
		serviceAddr: serviceAddr,
		stop:        make(chan error),
	}

	if err := reg.register(leaseTTL); err != nil {
		return nil, err
	}

	go reg.keepAlive()

	return reg, nil
}

func (r *Register) register(leaseTTL int64) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Grant a lease
	leaseResp, err := r.etcdClient.Grant(ctx, leaseTTL)
	if err != nil {
		return err
	}
	r.leaseID = leaseResp.ID

	// Register the service with the lease
	key := fmt.Sprintf("/%s/%s", r.serviceName, r.serviceAddr)
	_, err = r.etcdClient.Put(ctx, key, r.serviceAddr, clientv3.WithLease(r.leaseID))
	if err != nil {
		return err
	}
	log.Printf("Registered service '%s' at '%s' with lease ID %d", r.serviceName, r.serviceAddr, r.leaseID)
	return nil
}

func (r *Register) keepAlive() {
	// The context for KeepAlive should be background, so it remains active
	keepAliveChan, err := r.etcdClient.KeepAlive(context.Background(), r.leaseID)
	if err != nil {
		log.Printf("Error setting up keep-alive for lease %d: %v", r.leaseID, err)
		r.stop <- err
		return
	}

	for {
		select {
		case <-r.stop:
			log.Printf("Stopping keep-alive for service '%s'", r.serviceName)
			return
		case ka, ok := <-keepAliveChan:
			if !ok {
				log.Printf("Keep-alive channel closed for lease %d. Re-registering...", r.leaseID)
				// If the channel is closed, it means the lease has expired or been revoked.
				// We should try to re-register.
				if err := r.register(defaultLeaseTTL); err != nil {
					log.Printf("Failed to re-register service '%s': %v", r.serviceName, err)
					r.stop <- fmt.Errorf("failed to re-register: %v", err)
				}
				return // Exit this goroutine, a new keepAlive will be started by the new registration.
			}
			// Log for debugging, can be removed in production
			log.Printf("Successfully sent keep-alive for lease %d, TTL: %d", r.leaseID, ka.TTL)
		}
	}
}

// Unregister removes the service from etcd.
func (r *Register) Unregister() error {
	close(r.stop)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Revoke the lease
	if _, err := r.etcdClient.Revoke(ctx, r.leaseID); err != nil {
		log.Printf("Failed to revoke lease %d: %v", r.leaseID, err)
		// Continue to close the client even if revoke fails
	} else {
		log.Printf("Unregistered service '%s' and revoked lease %d", r.serviceName, r.leaseID)
	}

	return r.etcdClient.Close()
}