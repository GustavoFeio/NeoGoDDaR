package main

// 7055cc8d96883bda2f69bb1fe8bc7512b2543132

// ShouldQuiesce returns a channel which will be closed when Stop() has been invoked and outstanding tasks should begin to quiesce.
// pkg/util/stop/stopper.go:429
func ShouldQuiesce() <-chan struct{} {
	return make(chan struct{})
}

// In this bug, a channel is used to signal (by closing the channel) that an event is happening.
// However, if the channel is not closed blocking communication will block forever.
// For correct interaction with the channel, non-blocking communication must be used.

// pkg/storage/consistency_queue.go:107
func main() {
	<-ShouldQuiesce() // Deadlock, channel is not closed, and no value will ever be sent
}
