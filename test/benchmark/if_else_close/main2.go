
// This example tests channel communication with an if statement where the channel is closed in one of the branches.
// It also checks that reading from a closed channel does not block or cause an error.
// It does not deadlock.

package main

func foo(ch chan int) {
	ch <- 1
}

func main() {
	ch := make(chan int)

	go func() {
		<-ch
	}()

	if true {
		close(ch)
	} else {
		foo(ch)
	}
}

