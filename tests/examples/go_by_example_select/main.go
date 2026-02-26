
// This example writes a value onto two channels and selects reading on them in a loop.
// Since the loop is executed twice, it does not deadlock.

package main

func main() {
	c1 := make(chan string)
	c2 := make(chan string)

	// GoDDaR analyzes the program exhaustively; it does not care for timings
	go func() {
		// time.Sleep(1 * time.Second)
		c1 <- "one"
	}()
	go func() {
		// time.Sleep(2 * time.Second)
		c2 <- "two"
	}()

	for i := 0; i < 2; i++ {
		select {
		case msg1 := <-c1:
			println("received " + msg1)
		case msg2 := <-c2:
			println("received " + msg2)
		}
	}
}
