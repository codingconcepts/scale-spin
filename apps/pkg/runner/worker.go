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
	repo         repo.Repo
	requestsMade chan time.Duration
	ctx          context.Context
	cancel       context.CancelFunc
}

func NewWorker(ctx context.Context, cancel context.CancelFunc, repo repo.Repo) *Worker {
	return &Worker{
		repo:   repo,
		ctx:    ctx,
		cancel: cancel,
	}
}

func (w *Worker) run() error {
	ids, err := w.repo.FetchIDs()
	if err != nil {
		return fmt.Errorf("fetching ids: %w", err)
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

			w.requestsMade <- taken

		case <-w.ctx.Done():
			return nil
		}
	}
}

func (w *Worker) makeRequest(idFrom, idTo any, amount float64) (taken time.Duration, err error) {
	start := time.Now()
	defer func() {
		taken = time.Since(start)
	}()

	err = w.repo.MakeRequest(idFrom, idTo, amount)
	return
}
