package main

import (
	"context"
	"sync"
)

// When it receives an error (via wc.errChan) it might block trying to send (wc.resultChan) due to no receivers.

const (
	outgoingBufSize = 100
)

type watchChan struct {
	resultChan chan struct{}
	errChan    chan error
	ctx        context.Context
	cancel     context.CancelFunc
}

func (wc *watchChan) processEvent(s *sync.WaitGroup) {
	defer s.Done()
	for {
		// Receive event
		event := struct{}{}
		select {
		case wc.resultChan <- event:
		case <-wc.ctx.Done():
			return
		}
	}
}

// pkg/storage/etcd3/watcher.go:103
func (wc *watchChan) run() {
	var resultChanWG sync.WaitGroup
	resultChanWG.Add(1)
	// processEvent processes events from etcd watcher and sends results to resultChan
	go wc.processEvent(&resultChanWG)

	select {
	case err := <-wc.errChan:
		wc.cancel()
		if err != nil {
			wc.resultChan <- struct{}{}
		}
	case <-wc.ctx.Done():
	}
	resultChanWG.Wait()
	close(wc.resultChan)
}

func main() {
	wc := watchChan{
		resultChan: make(chan struct{}, outgoingBufSize),
		errChan:    make(chan error, 1),
	}
	ctx := context.Background()
	wc.ctx, wc.cancel = context.WithCancel(ctx)

	wc.run()
}