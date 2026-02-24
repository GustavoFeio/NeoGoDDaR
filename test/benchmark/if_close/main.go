
// This example tests channel closing in an if statement.
// It does not deadlock or generate an error.
// Note: Since conditions are not evaluated in GoDDaR,
// all paths of an if are explored, meaning it generates a runtime error due to a closed write on channel `ch`.

package main

func main() {
	ch := make(chan int)

	go func() {
		ch <- 1
	}()

	// 
	if false {
		close(ch)
	}
	<-ch
}

