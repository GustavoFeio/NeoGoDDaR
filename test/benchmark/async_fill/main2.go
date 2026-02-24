
// This example fills and then drains an asynchronous channel.
// Since there is one more read than the number of writes to the channel,
// it does deadlock.

package main

func main() {
	ch := make(chan int, 2)
	ch <- 42
	ch <- 43
	<-ch
	<-ch
	<-ch
}

