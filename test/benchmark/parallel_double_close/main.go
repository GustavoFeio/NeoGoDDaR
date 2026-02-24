
// This example tests two threads working on the same channel, each performing their own operations, ending in closing the channel.
// Due to the scheduler, this program may generate runtime errors due to writing on a closed channel or double close on channel `ch`.

package main

func worker1(ch chan int) {
	go func() {
		ch <- 42
	}()
	<-ch
	close(ch)
}

func worker2(ch chan int) {
	go func() {
		<-ch
	}()
	ch <- 42
	close(ch)
}

func main() {
	ch := make(chan int)
	go worker1(ch)
	go worker2(ch)
}

