package main

// Through a bunch of function calls, this is a "missing send" kind of deadlock
// Client/Server kinda deal, where messages are sent between each other
// Connection is established, stream is created.
// Client tries to read from the stream in a goroutine, server never sends a thing, and client stops the stream.
// goroutine blocks even though stream was closed

type recvMsg struct {
	data []byte
	err  error
}

type recvBuff struct {
	c chan recvMsg
}

func main() {
	buf := recvBuff{c: make(chan recvMsg)}
	// Receive
	go func() {
		_ = <-buf.c
	}()

	// CloseStream()
	// doesn't write to buf, so goroutine will never unblock
	// Fix is to write a message with an error to the channel
	// buf.c <- recvMsg{ err: errors.New("client connection is closing") }
}
