
// This example is identical to `dingo_local_deadlock`, except it only tries to read from the worker once.
// It does not deadlock.

package main

func Work() {
	for {
		println("Working")
		// time.Sleep(1 * time.Second)
	}
}

func Send(ch chan<- int)                  { ch <- 42 }
func Recv(ch <-chan int, done chan<- int) { done <- <-ch }

func main() {
	ch, done := make(chan int), make(chan int)
	go Send(ch)
	go Recv(ch, done)
	go Work()

	<-done
}
