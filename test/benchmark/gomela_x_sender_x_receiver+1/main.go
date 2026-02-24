
// This example is identical to `gomela_x_sender_x_receiver`, except the number of iterations is different.
// Since one loop iterates once more than the other, it does deadlock.
// Note: The original example assigned `x` from a command-line argument.

package main

func sender(a chan int, x int) {
	for i := 0; i < x; i++ {
		a <- i
	}
}

func receiver(a chan int, x int) {
	for i := 0; i < x; i++ {
		<-a
	}
}

func main() {
	x := 42
	a := make(chan int)
	go sender(a, x)
	receiver(a, x+1)
}
