
// This example creates two channels which are written to, `x` and `y`,
// and two channels which try to read from both of them, `z1` and `z2`.
// Since both `z1` and `z2` try to read from channels that only have one value,
// it does deadlock.

package main

func provide1(x chan bool) {
    x <- true
}
func provide2(y chan bool) {
    y <- false
}

func collect1(in, out chan bool) {
    out <- <-in
}
func collect2(in, out chan bool) {
    out <- <-in
}

func main() {
    x, y := make(chan bool), make(chan bool)
    go provide1(x)
    go provide2(y)
    
    z1 := make(chan bool)
    go collect1(x,z1)
    go collect2(y,z1)
    <-z1
    
    z2 := make(chan bool)
    go collect1(x,z2)
    go collect2(y,z2)
    <-z2 
}
