package runner

import "container/ring"

// threadUnsafeRing wraps container/ring and adds thread-safety and helper functions.
// Use New to create a new instance with a given size.
type threadUnsafeRing[T any] struct {
	buffer *ring.Ring
}

// newThreadUnsafeRing returns a pointer to a new instance of Ring.
func newThreadUnsafeRing[T any](size int) *threadUnsafeRing[T] {
	if size == 0 {
		panic("ring size cannot be zero")
	}

	return &threadUnsafeRing[T]{
		buffer: ring.New(size),
	}
}

func (r *threadUnsafeRing[T]) add(v T) {
	r.buffer.Value = v
	r.buffer = r.buffer.Next()
}

func (r *threadUnsafeRing[T]) slice() []T {
	values := []T{}
	r.buffer.Do(func(elem any) {
		if v, ok := elem.(T); ok {
			values = append(values, v)
		}
	})

	return values
}
