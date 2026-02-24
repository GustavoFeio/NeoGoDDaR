
// This example tests circular dependencies with asynchronous channels.
// Since the program does not need to wait on channel reads,
// it does not deadlock.

package main

func main() {
	a := make(chan int, 1)
	b := make(chan int, 1)

	a <- 1

	go func() {
		<-a
		b <- 2
	}()

	<-b
}

