package main

import "context"

// Stream is created, goroutine is instantiated to close stream when context is canceled
// Seems like, that is not enough. An error channel also exists, to signify that an error has occurred (error channel is closed).
// Error doesn't seem to imply a canceling of the context (didn't find that in the code)

type stream struct {
	c context.Context
}

func newClientStream() stream {
	s := stream{c: context.Background()}
	go func() {
		<-s.c.Done()
		// Close stream
		// s.Close()
	}()
	return s
}

func main() {
	s := newClientStream()
	// do stuff with stream
	// Error might happen but context will not be canceled
	// goroutine will leak
	println(s)
}
