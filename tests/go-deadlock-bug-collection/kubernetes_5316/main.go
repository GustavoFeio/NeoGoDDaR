package main

import "time"

// simple deadlock, select might choose the timeout case, and sending on ch or errCh will block forever

// pkg/apiserver/resthandler.go:394
func finishRequest(timeout time.Duration, fn func() (struct{}, error)) {
	ch := make(chan struct{})
	errCh := make(chan error)
	go func() {
		if result, err := fn(); err != nil {
			errCh <- err
		} else {
			ch <- result
		}
	}()

	select {
	case _ = <-ch:
		return
	case _ = <-errCh:
		return
	case <-time.After(timeout):
		return
	}
}

func main() {
	fn := func() (struct{}, error) {
		time.Sleep(5 * time.Second)
		return struct{}{}, nil
	}
	finishRequest(time.Second, fn)
}
