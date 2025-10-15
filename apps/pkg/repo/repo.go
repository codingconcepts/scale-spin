package repo

import "context"

type Repo interface {
	FetchWorkers(ctx context.Context, region string) (int, error)
	FetchIDs(ctx context.Context) ([]any, error)
	MakeRequest(ctx context.Context, idFrom, idTo any, amount float64) error
}
