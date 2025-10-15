package runner

import (
	"context"
	"fmt"
	"log"
	"math/rand/v2"
	"time"

	"github.com/codingconcepts/scale-spin/apps/pkg/repo"
	"github.com/samber/lo"
)

type Worker struct {
	repo   repo.Repo
	taken  chan time.Duration
	ctx    context.Context
	cancel context.CancelFunc
}

func NewWorker(ctx context.Context, cancel context.CancelFunc, repo repo.Repo, taken chan time.Duration) *Worker {
	return &Worker{
		repo:   repo,
		taken:  taken,
		ctx:    ctx,
		cancel: cancel,
	}
}

func (w *Worker) run() error {
	ids, err := w.fetchIDs()
	if err != nil {
		return fmt.Errorf("fetching ids: %w", err)
	}

	if len(ids) == 0 {
		return fmt.Errorf("no ids found")
	}

	requestTicks := time.Tick(time.Second / 100)

	for {
		select {
		case <-requestTicks:
			pair := lo.Samples(ids, 2)
			if len(pair) < 2 {
				log.Printf("need at least 2 ids, got %d (of a total %d)", len(pair), len(ids))
				continue
			}

			amount := rand.Float64() * 100

			taken, err := w.makeRequest(pair[0], pair[1], amount)
			if err != nil {
				log.Printf("error making request: %v", err)
			}

			w.taken <- taken

		case <-w.ctx.Done():
			return nil
		}
	}
}

func (w *Worker) fetchIDs() ([]any, error) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second*5)
	defer cancel()

	return w.repo.FetchIDs(ctx)
}

func (w *Worker) makeRequest(idFrom, idTo any, amount float64) (taken time.Duration, err error) {
	start := time.Now()
	defer func() {
		taken = time.Since(start)
	}()

	ctx, cancel := context.WithTimeout(context.Background(), time.Second*1)
	defer cancel()

	err = w.repo.MakeRequest(ctx, idFrom, idTo, amount)
	return
}
