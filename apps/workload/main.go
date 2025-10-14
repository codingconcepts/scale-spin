package main

import (
	"context"
	"database/sql"
	"log"
	"strings"

	"github.com/codingconcepts/env"
	"github.com/codingconcepts/scale-spin/apps/pkg/models"
	"github.com/codingconcepts/scale-spin/apps/pkg/queue"
	"github.com/codingconcepts/scale-spin/apps/pkg/repo"
	"github.com/codingconcepts/scale-spin/apps/pkg/runner"

	_ "github.com/jackc/pgx/v5/stdlib"
)

type environment struct {
	SQSQueueURL    string `env:"SQS_QUEUE_URL" required:"true"`
	DatabaseDriver string `env:"DATABASE_DRIVER" required:"true"`
	DatabaseURL    string `env:"DATABASE_URL" required:"true"`
	Region         string `env:"COCKROACHDB_REGION" required:"true"`
}

func main() {
	var e environment
	if err := env.Set(&e); err != nil {
		log.Fatalf("setting config from environment: %v", err)
	}

	db, err := sql.Open(e.DatabaseDriver, e.DatabaseURL)
	if err != nil {
		log.Fatalf("error connecting to database: %v", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	reader, err := queue.NewSQSReader(ctx, e.SQSQueueURL)
	if err != nil {
		log.Fatalf("error creating SQS reader: %v", err)
	}

	var r repo.Repo
	switch strings.ToLower(e.DatabaseDriver) {
	case "pgx":
		r = repo.NewPostgresRepo(db)
	}

	messages := make(chan models.Message, 1)
	runner := runner.New(r, e.Region, messages)

	go runner.Serve()
	go runner.Run()

	if err = reader.Run(ctx, messages); err != nil {
		log.Fatalf("error running SQS reader: %v", err)
	}
}
