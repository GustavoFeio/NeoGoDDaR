
package main

func main() {
	ch := make(chan int)
	for i := 0; i < 10; i++ {
		if i == 2 {
			go func() {
				ch <- 42
			}()
			break
		}
	}
	<-ch
}

