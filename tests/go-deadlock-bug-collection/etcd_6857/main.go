package main

// node seems designed as a server/client model. It features an infinite loop with a select statement that waits to
// receive a message from a number of channels, each channel represents an operation.
// When the node is stopped, via a message in chan stop, the channel done is closed and the loop terminates

// The deadlock occurs when the node is stopped, and another goroutine calls the node.Status() function.
// The Status() will try sending a message to the channel status, requesting the status info from the node.
// Since the node has stopped, the infinite loop has also stopped, and the send on channel status will never complete.
// The fix is to add a select statement, with the send to the status channel and a receive on done channel.
// If the node is stopped, the done channel will be closed and the select will choose the case with the done channel.

// raft/node.go:224
type node struct {
	// Channel to request the status of the node
	status chan chan struct{}
	// Channel to signal node to stop
	stop chan struct{}
	// Channel that will be closed when node is stopped
	done chan struct{}
}

func main() {
	n := node{
		status: make(chan chan struct{}),
		stop:   make(chan struct{}),
		done:   make(chan struct{}),
	}
	go n.Run()
	n.Stop()
	n.Status() // Block here
}

// Run raft/node.go:269
func (n *node) Run() {
	for {
		select {
		case c := <-n.status:
			c <- struct{}{}
		case <-n.stop:
			close(n.done)
			return
		}
	}
}

// Stop raft/node.go:257
func (n *node) Stop() {
	select {
	case n.stop <- struct{}{}:
		// Not already stopped, so trigger it
	case <-n.done:
		// Node has already been stopped - no need to do anything
		return
	}
	// Block until the stop has been acknowledged by run()
	<-n.done
}

// Status raft/node.go:463
func (n *node) Status() struct{} {
	c := make(chan struct{})
	n.status <- c // Block here
	return <-c
}
