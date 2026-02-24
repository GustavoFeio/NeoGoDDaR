
package main

func Producer(ch chan<- int) {
	for i := 2; ; i++ {
		ch <- i
	}
}

func Sieve(in <-chan int, out chan<- int, prime int) {
	for {
		n := <-in
		if n % prime != 0 {
			out <- n
		}
	}
}

func main() {
	ch := make(chan int)
	go Producer(ch)
	for i := 0; i < 10; i++ {
		prime := <-ch
		println(prime)
		ch1 := make(chan int)
		go Sieve(ch, ch1, prime)
		ch = ch1
	}
}

