package main

//4e56696c6c5a8cd7b711a1eb8936463559361da5

// clientconn.go:613
func lbWatcher(doneChan chan struct{}) {
	// There is an execution path were the doneChan is not closed
	// The fix is to defer the closure of the channel
}

func main() {
	doneChan := make(chan struct{})
	go lbWatcher(doneChan)
	<-doneChan // deadlock
}
