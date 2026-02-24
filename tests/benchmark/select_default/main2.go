
// This example is identical to `select_default/main.go`, except it has one less case.

package main

func main() {
	ch := make(chan int)
	select {
	case <-ch:
	default:
	}
}


