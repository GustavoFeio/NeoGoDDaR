
// This example generates a worker which may read or write to a channel while there is a select on the main function.
// Since in either case of the if statement there is a corresponding action in the select statement,
// it does not deadlock.

package main

func worker(ch chan int) {
	if false {
		ch <- 404
	} else {
		<-ch
	}
}

func main() {
	ch := make(chan int)
	go worker(ch)
	select {
	case n := <-ch:
		close(ch)
		println(n)
	case ch <- 42:
		println("Wrote 42")
	}
}

