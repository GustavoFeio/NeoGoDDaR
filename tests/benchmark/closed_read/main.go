
// This example tests the behavior of reading from a closed channel.
// It does not generate a deadlock.

package main

func main() {
	ch := make(chan int)
	close(ch)
	<-ch
}

