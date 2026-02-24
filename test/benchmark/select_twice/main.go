
// This example writes a value to two channels and executes the same select statement twice
// in order to synchronize read/writes on both channels.
// It does not deadlock.

package main

func main() {
	ch1, ch2 := make(chan int), make(chan int)
	go func() {
		ch1 <- 42
	}()
	go func() {
		ch2 <- 42
	}()

	select {
	case n := <- ch1:
		n += 1
	case n := <- ch2:
		n += 2
	}

	select {
	case n := <- ch1:
		n += 1
	case n := <- ch2:
		n += 2
	}
}

