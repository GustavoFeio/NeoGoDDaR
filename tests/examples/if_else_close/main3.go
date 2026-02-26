
// This example is identical to `if_else_close/main2.go`,
// except the goroutine in the main function write into the channel instead of reading.
// Since one of the branches closes the channel and there is a goroutine trying to write to it,
// it generates a runtime error due to a closed write on channel `ch`.

package main

func foo(ch chan int) {
	<-ch
}

func main() {
	ch := make(chan int)

	go func() {
		ch <- 1
	}()

	if true {
		close(ch)
	} else {
		foo(ch)
	}
}

