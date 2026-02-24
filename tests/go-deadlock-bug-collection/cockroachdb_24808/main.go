package main

// 464ec953d579be4b4e79a1fb7a021bf79a279cd5

type Compactor struct {
	// ch channel is used to trigger some process
	ch chan struct{}
}

// Start pkg/storage/compactor/compactor.go:130
func (c *Compactor) Start() {
	// Here the channel is written to in order to trigger the select immediately
	// However, if Suggest had been called previously, the ch channel already has an item and as so is full (capacity of 1),
	// preventing this channel write from progressing
	c.ch <- struct{}{}

	go func() {
		for {
			select {
			// In the original code another case exists to terminate the loop
			// case <-stopper.ShouldStop():
			//	return

			case <-c.ch:
				// Process something
			}
		}
	}()
}

func (c *Compactor) Suggest() {
	select {
	case c.ch <- struct{}{}:
	default:
	}
}

func NewCompactor() Compactor {
	return Compactor{
		ch: make(chan struct{}, 1),
	}
}

func main() {
	compactor := NewCompactor()
	compactor.Suggest()
	compactor.Start() // Deadlock
}
