
// This example creates two channels, `ch` and `done`, which act as a worker and reader.
// The worker is loaded a value once, and the reader tries to receive two values from the worker.
// Although the whole program does not block, it is in a deadlocked state.

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
	go Recv(ch, done)
	go Work()

	<-done
	<-done
}
