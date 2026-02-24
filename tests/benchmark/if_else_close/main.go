
// This example tests channel communication with an if statement where the channel is closed in one of the branches.
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
		foo(ch)
		close(ch)
	} else {
		foo(ch)
	}
}

