package runner

import (
	"context"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/codingconcepts/errhandler"
	"github.com/codingconcepts/scale-spin/apps/pkg/apdex"
	"github.com/codingconcepts/scale-spin/apps/pkg/repo"
)

type Runner struct {
	repo   repo.Repo
	region string

	taken chan time.Duration

	lastScoreMu sync.RWMutex
	lastScore   float64

	workersMu sync.RWMutex
	workers   []*Worker
}

func New(repo repo.Repo, region string) *Runner {
	return &Runner{
		repo:   repo,
		region: region,
		taken:  make(chan time.Duration, 1000),
	}
}

func (rr *Runner) Run() {
	logTicks := time.Tick(time.Second)

	latencies := newThreadUnsafeRing[time.Duration](1000)
	requestsMade := 0

	go rr.pollForWorkers()

	for {
		select {
		case taken := <-rr.taken:
			requestsMade++
			latencies.add(taken)

		case <-logTicks:
			latencySlice := latencies.slice()
			rr.lastScore = apdex.Score(latencySlice)

			log.Printf("score: %.2f, rps: %d, workers: %d", rr.lastScore, requestsMade, len(rr.workers))
			requestsMade = 0
		}
	}
}

func (rr *Runner) pollForWorkers() {
	for range time.Tick(time.Second * 5) {
		workers, err := rr.repo.FetchWorkers(context.Background(), rr.region)
		if err != nil {
			log.Printf("error fetching worker count: %v", err)
			continue
		}

		rr.setWorkers(workers)
	}
}

func (rr *Runner) setWorkers(count int) {
	rr.workersMu.Lock()
	defer rr.workersMu.Unlock()

	for len(rr.workers) != count {
		time.Sleep(time.Millisecond * 100)
		log.Printf("workers: %d / desired: %d", len(rr.workers), count)

		if len(rr.workers) < count {
			rr.addWorker()
		} else {
			rr.removeWorker()
		}
	}
}

// addWorker starts a new worker thread.
//
// IMPORTANT: Caller must hold an exclusive lock to rr.workersMu before invoking.
func (rr *Runner) addWorker() {
	ctx, cancel := context.WithCancel(context.Background())

	w := NewWorker(ctx, cancel, rr.repo, rr.taken)
	rr.workers = append(rr.workers, w)

	go w.run()
}

// removeWorker stops a worker thread.
//
// IMPORTANT: Caller must hold an exclusive lock to rr.workersMu before invoking.
func (rr *Runner) removeWorker() {
	if len(rr.workers) == 0 {
		log.Printf("no workers to remove")
		return
	}

	lastIdx := len(rr.workers) - 1
	w := rr.workers[lastIdx]

	w.cancel()

	rr.workers = rr.workers[:lastIdx]
}

func (r *Runner) Serve() error {
	mux := http.NewServeMux()
	mux.Handle("GET /healthz", errhandler.Wrap(r.handleHealthCheck))
	mux.Handle("GET /apdex", errhandler.Wrap(r.getApdex))

	server := &http.Server{Addr: "0.0.0.0:8080", Handler: mux}
	return server.ListenAndServe()
}

func (rr *Runner) handleHealthCheck(w http.ResponseWriter, r *http.Request) error {
	return errhandler.SendString(w, "OK")
}

type getApdexResponse struct {
	Score float64 `json:"score"`
}

func (rr *Runner) getApdex(w http.ResponseWriter, r *http.Request) error {
	rr.lastScoreMu.RLock()
	defer rr.lastScoreMu.RUnlock()

	resp := getApdexResponse{
		Score: rr.lastScore,
	}

	return errhandler.SendJSON(w, resp)
}
