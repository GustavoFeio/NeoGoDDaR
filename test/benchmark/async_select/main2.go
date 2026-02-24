
// This example tests a reading branch of a select statement with asynchronous channels.
// It does not deadlock.

package main

func tau() {
	
}

func main() {
	ch := make(chan int, 1)
	select {
	case <-ch:
	default:
		tau()
	}
}

