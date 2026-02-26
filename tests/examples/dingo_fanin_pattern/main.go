
// This example creates two channels, `input1` and `input2`, onto which values are constantly generated.
// Another channel, `c`, consumes the values from the two channels and prints them to the console.
// It tests loops and select clauses, and does not deadlock.

package main

func work(out chan<- int) {
	for {
		out <- 42
	}
}

func fanin(ch1, ch2 <-chan int) <-chan int {
	c := make(chan int)
	go func() {
		for {
			select {
			case s := <-ch1:
				c <- s
			case s := <-ch2:
				c <- s
			}
		}
	}()
	return c
}

func main() {
	input1, input2 := make(chan int), make(chan int)
	go work(input1)
	go work(input2)
	c := fanin(input1, input2)
	for {
		println(<-c)
	}
}
