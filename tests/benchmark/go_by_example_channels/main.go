
// This example tests basic channel communication.
// It does not deadlock

package main

func main() {

	messages := make(chan string)

	go func() { messages <- "ping" }()

	msg := <-messages
	println(msg)
}
