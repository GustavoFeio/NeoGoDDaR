
// This example tests a double close on a channel after communication.
// It generates a runtime error due to a double close on channel `ch`.

package main

func recv(ch chan int) {
	<- ch
	close(ch)
}

func main() {
	ch := make(chan int)
  	go recv(ch)
	ch <- 0
	close(ch)
}
