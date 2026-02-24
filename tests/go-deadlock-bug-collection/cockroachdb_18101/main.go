package main

import "context"

// The sending goroutine, will leak/block when the receiving/parent goroutine cancels the context
// Fix is to add a select to the sending goroutine with both the send and the receive from the Done() context channel
// and defer a cancel on the context on the receiving goroutine

func main() {
	ctx := context.Background()

	channel := make(chan struct{})
	go func() {
		defer close(channel)
		for true /* some range of data */ {
			channel <- struct{}{}
		}
	}()

	for _ = range channel {
		select {
		case <-ctx.Done():
			return
		default:
		}
	}
}
