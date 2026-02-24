
// This example is identical to `parallel_double_close/main.go` except each thread only does one action before closing the channel.
// It generates a runtime error due to a double close on channel `ch`.

package main

func worker1(ch chan int) {
	ch <- 42
	close(ch)
}

func worker2(ch chan int) {
	<-ch
	close(ch)
}

func main() {
	ch := make(chan int)
	go worker1(ch)
	go worker2(ch)
}

