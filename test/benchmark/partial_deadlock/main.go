
// This example is similar to `dingo_local_deadlock`, but it sends on the channel twice and only receives once.
// Since it only receives once, it generates a deadlock on one of the goroutines, although the whole program does not block.

package main

func work(data int) {
	for {
		println("Working!")
		// time.Sleep(1 * time.Second)
	}
}

func recvr(ch <-chan int, done chan<- int) {
	val := <-ch
	go work(val)
	done <- val
}

func sender(ch chan<- int) {
	ch <- 42
}

func main() {
	ch, done := make(chan int), make(chan int)
	go recvr(ch, done)
	go sender(ch)
	go sender(ch)
	<-done
	<-done
}
