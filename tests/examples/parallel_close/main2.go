
// This example is identical to `parallel_close/main.go`, except the order of the goroutine declarations is different.
// Note: Functionally, this program is identical to the original.
// It is meant to check GoDDaR's behavior on the same program with different orders.

package main

func main() {
	ch := make(chan int)

	go func() {
		<-ch
	}()
	go func() {
		close(ch)
	}()
	go func() {
		ch <- 42
	}()
}

