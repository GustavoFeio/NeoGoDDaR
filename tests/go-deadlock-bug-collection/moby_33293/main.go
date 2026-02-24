package main

// ab83b924bc5dde5c2ac81b0befe5e370f3acb7e3

func ContainerWait() chan struct{} {
	errC := make(chan struct{})
	if true /* some error condition */ {
		errC <- struct{}{}
		return errC
	}
	return nil
}

// Simple send to channel without receive
func main() {
	ContainerWait()
}
