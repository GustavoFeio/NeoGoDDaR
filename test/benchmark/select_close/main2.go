
// This example tests different branches of a select statement.
// Since only one of the branches may be executed at a time,
// one of the actions on `a` or `b` will not be able to execute,
// meaning that goroutine will deadlock, although the whole process does not block.

package main

func main() {
	a := make(chan int)
	b := make(chan int)
	c := make(chan int)

	go func() {
		a <- 42
	}()
	go func() {
		b <- 43
	}()
	go func() {
		<-c
	}()

	select {
	case <-a:
		close(c)
	case <-b:
		c <- 44
	}
}

