
// This example tests multiple types of errors on the same program.
// It generates deadlocks, double closes, and closed writes.

package main

func write_deadlock(ch chan int) {
	ch <- 42
}

func read_deadlock(ch chan int) {
	<-ch
}

func double_close(ch chan int) {
	close(ch)
	close(ch)
}

func closed_write(ch chan int) {
	close(ch)
	ch <- 42
}

func main() {
	ch := make(chan int)
	if true {
		go write_deadlock(ch)
	} else {
		go read_deadlock(ch)
	}

	if true {
		go double_close(ch)
	} else {
		go closed_write(ch)
	}
}

