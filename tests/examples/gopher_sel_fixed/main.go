
// This example is identical to `gopher_sel`, except it only tries to read from one of the channels once.
// Since only one of the channels is read, the other goroutine is still in the background,
// which means it deadlocks in one of the background threads.

package main

func provide1(x chan bool) {
	x <- true
}
func provide2(y chan bool) {
	y <- false
}

func main() {
	x, y := make(chan bool), make(chan bool)
	go provide1(x)
	go provide2(y)
	
	select {
	case z := <-x:
		println(z)
	case z := <-y:
		println(z)
	}
}
