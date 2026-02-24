
// This example tests the behavior of a process when an operation on channel `b` can only
// proceed when another pair of actions on channel `a` execute.
// The objective is to check if the closing of channel `b` after actions on `a`
// is applied to the pending read on `b`, unlocking it.

package main

func main() {
	a := make(chan int)
	b := make(chan int)
	go func() {
		<-a
		close(b)
	}()
	go func() {
		<-b
	}()
	go func() {
		a <- 1
	}()
}

