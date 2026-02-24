
// This example generates two deadlocks on two distinct channels, `ch1` and `ch2`.
// Its objective is to check how GoDDaR reports multiple deadlocks.

package main

func main() {
	ch1 := make(chan int)
	<-ch1
	ch1 <- 1

	ch2 := make(chan int)
	ch2 <- 1
	<-ch2
}

