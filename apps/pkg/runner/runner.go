package runner

import (
	"context"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/codingconcepts/errhandler"
	"github.com/codingconcepts/scale-spin/apps/pkg/apdex"
	"github.com/codingconcepts/scale-spin/apps/pkg/models"
	"github.com/codingconcepts/scale-spin/apps/pkg/repo"
)

type Runner struct {
	repo   repo.Repo
	region string

	messages     chan models.Message
	requestsMade chan time.Duration

	lastScoreMu sync.RWMutex
	lastScore   float64

	workersMu sync.RWMutex
	workers   []*Worker
}

func New(repo repo.Repo, region string, messages chan models.Message) *Runner {
	return &Runner{
		repo:         repo,
		region:       region,
		messages:     messages,
		requestsMade: make(chan time.Duration, 1000),
	}
}

func (rr *Runner) Run() {
	logTicks := time.Tick(time.Second)

	latencies := newThreadUnsafeRing[time.Duration](1000)
	requestsMade := 0

	for {
		select {
		case taken := <-rr.requestsMade:
			requestsMade++
			latencies.add(taken)

		case msg := <-rr.messages:
			switch msg.Scenario {
			case models.ScenarioScaleUpEU:
				if rr.region != "aws-eu-west-2" {
					continue
				}
				rr.addWorker()

			case models.ScenarioScaleDownEU:
				if rr.region != "aws-eu-west-2" {
					continue
				}
				rr.removeWorker()

			case models.ScenarioFlashSale:

			case models.ScenarioTest:
				log.Printf("test message received")
			}

		case <-logTicks:
			latencySlice := latencies.slice()
			rr.lastScore = apdex.Score(latencySlice)

			log.Printf("score: %.2f, rps: %d, workers: %d", rr.lastScore, requestsMade, len(rr.workers))
			requestsMade = 0
		}
	}
}

func (rr *Runner) addWorker() {
	rr.workersMu.Lock()
	defer rr.workersMu.Unlock()

	ctx, cancel := context.WithCancel(context.Background())

	w := NewWorker(ctx, cancel, rr.repo)
	rr.workers = append(rr.workers, w)

	go w.run()
}

func (rr *Runner) removeWorker() {
	rr.workersMu.Lock()
	defer rr.workersMu.Unlock()

	if len(rr.workers) == 0 {
		log.Printf("no workers to remove")
		return
	}

	lastIdx := len(rr.workers) - 1
	w := rr.workers[lastIdx]

	w.cancel()

	rr.workers = rr.workers[:lastIdx]
}

type scenarioRequest struct {
	Scenario string `json:"scenario"`
}

func (r *Runner) Serve() error {
	mux := http.NewServeMux()
	mux.Handle("GET /apdex", errhandler.Wrap(r.getApdex))

	// Tests:
	//
	// curl -s http://localhost:3000/messages --json '{"scenario": "scale-up-eu"}'
	mux.Handle("POST /messages", errhandler.Wrap(r.handleScenarioRequest))

	server := &http.Server{Addr: "localhost:3000", Handler: mux}
	return server.ListenAndServe()
}

func (rr *Runner) handleScenarioRequest(w http.ResponseWriter, r *http.Request) error {
	var req scenarioRequest
	if err := errhandler.ParseJSON(r, &req); err != nil {
		return errhandler.Error(http.StatusUnprocessableEntity, err)
	}

	rr.messages <- models.Message{
		Scenario: models.Scenario(req.Scenario),
		Delete:   models.NoopDelete,
	}
	return nil
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
