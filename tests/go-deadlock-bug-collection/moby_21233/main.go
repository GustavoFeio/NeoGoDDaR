package main

import "math/rand"

// The deadlock in the test unit that test the progress tracking of downloads/uploads
//
// The progress tracking features a Progress channel masterProgressChan from where it receives updates, and
// Watchers that receive updates via another channel.
// The test unit checks that progress updates in the correct sequence, from 0 to 10, ensuring that it starts with 0 and
// ends with 10.
// The bug occurs because the unit test checked if all updates incremented by 1, and terminated the
// watchers are not guaranteed to receive all updates, consecutive updates might be condensed
// into a single one (the last update of the set).

// distribution/xfer/transfer_test.go:11
func main() {
	var progress chan int64 = make(chan int64, 0)

	XferFunc := func(progress chan int64) {
		for i := 0; i <= 10; i++ {
			if rand.Intn(10) != 0 {
				progress <- int64(i)
			}
		}
	}

	go XferFunc(progress)

	receivedProgress := int64(0)

	for p := range progress {
		val := receivedProgress
		if p != val+1 {
			//t.Fatalf("got unexpected progress value: %d (expected %d)", p.Current, val+1)
		}
		receivedProgress = p
	}
}
