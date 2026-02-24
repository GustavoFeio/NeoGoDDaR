
// This example tests how GoDDaR deals with channel closes in threads.
// It does not deadlock.

package main

func main() {
	ch := make(chan int)
	go func() {
		close(ch)
	}()
	<-ch
}

