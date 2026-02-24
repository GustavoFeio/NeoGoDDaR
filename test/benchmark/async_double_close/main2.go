
package main

func main() {
	ch := make(chan int, 10)
	go func() {
		<-ch
		close(ch)
	}()
	ch <- 42
	close(ch)
}

