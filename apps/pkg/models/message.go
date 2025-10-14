package models

type Message struct {
	Scenario Scenario
	Delete   func() error
}

func NoopDelete() error {
	return nil
}
