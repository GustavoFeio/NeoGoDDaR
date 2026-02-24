package main

import (
	"context"
)

// Database fetches Rows, that must be closed
// Since go1.8, when Rows are instantiated, in initContextClose() it spawns a goroutine that waits for
// ctx.Done() to be closed, after which it calls close() on the Rows.
// The Rows.close() also calls cancel on the ctx. So either manually closing the Rows or canceling the ctx is valid.
// If rows is not closed or ctx is not canceled the goroutine blocks forever and leaks

type Rows struct {
	cancel context.CancelFunc
	closed bool
}

func (rs *Rows) initContextClose(ctx context.Context) {
	ctx, rs.cancel = context.WithCancel(ctx)
	go rs.awaitDone(ctx)
}

// awaitDone blocks until the rows are closed or the context canceled.
func (rs *Rows) awaitDone(ctx context.Context) {
	<-ctx.Done()
	_ = rs.close(ctx.Err())
}

func (rs *Rows) Close() error {
	return rs.close(nil)
}
func (rs *Rows) close(err error) error {
	if rs.closed {
		return nil
	}
	rs.closed = true

	if rs.cancel != nil {
		rs.cancel()
	}
	// Lots of other "cleaning up" stuff, but this is what matters
	return err
}

func main() {
	rows := Rows{}
	ctx := context.Background()

	rows.initContextClose(ctx)

	// There is a path were the rows are never closed, so the rs.awaitDone() goroutine leaks.
}
