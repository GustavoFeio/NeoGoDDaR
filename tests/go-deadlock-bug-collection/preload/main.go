package main

import (
	"runtime"
	"sync"
)

func IsError(s string) bool {
	return s == ""
}

func DoSomeWork(v string) string {
	return v[1:]
}

func preload(trees []string, n int) {
	ch := make(chan string, n) 	// new chan with capacity n
	limitCh := make(chan int, runtime.NumCPU())
	for i := 0; i < runtime.NumCPU(); i++ {
		limitCh <- 1 			// send token on chan limitCh
	}
	var wg sync.WaitGroup
	for _, t := range trees {
		wg.Add(1) 				// increment wg counter
		go func(v string) { 	// spawn goroutine
			<-limitCh 			// receive token before starting work
			s := DoSomeWork(v)
			ch <- s
			limitCh <- 1 		// return token
			wg.Done() 			// decrement wg counter
		}(t)
	}
	go func() { 				// spawn goroutine
		wg.Wait() 				// wait for wg to reach 0
		close(ch) 				// set ch to closed
	}()
	for s := range ch { 		// receive message from ch
		if IsError(s) {
			return
		}
	}
}

func main() {
	preload(make([]string, 3), 2)
}
