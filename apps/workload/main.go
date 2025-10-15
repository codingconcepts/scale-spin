package main

import (
	"database/sql"
	"log"
	"strings"

	"github.com/codingconcepts/env"
	"github.com/codingconcepts/scale-spin/apps/pkg/repo"
	"github.com/codingconcepts/scale-spin/apps/pkg/runner"

	_ "github.com/jackc/pgx/v5/stdlib"
)

type environment struct {
	DatabaseDriver string `env:"DATABASE_DRIVER" required:"true"`
	DatabaseURL    string `env:"DATABASE_URL" required:"true"`
	Region         string `env:"REGION" required:"true"`
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

	var r repo.Repo
	switch strings.ToLower(e.DatabaseDriver) {
	case "pgx":
		r = repo.NewPostgresRepoMR(db, e.Region)
	}

	runner := runner.New(r, e.Region)

	go runner.Serve()
	runner.Run()
}
