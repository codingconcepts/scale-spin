package repo

import (
	"context"
	"database/sql"
	"fmt"
)

type PostgresRepoMR struct {
	db     *sql.DB
	region string
}

func NewPostgresRepoMR(db *sql.DB, region string) *PostgresRepoMR {
	return &PostgresRepoMR{
		db:     db,
		region: region,
	}
}

func (r *PostgresRepoMR) FetchWorkers(ctx context.Context, region string) (int, error) {
	const stmt = `SELECT workers
								FROM workload
								WHERE region = $1
								LIMIT 1`

	row := r.db.QueryRowContext(ctx, stmt, region)

	var workers int
	if err := row.Scan(&workers); err != nil {
		return 0, fmt.Errorf("scanning row: %w", err)
	}

	return workers, nil
}

func (r *PostgresRepoMR) FetchIDs(ctx context.Context) ([]any, error) {
	const stmt = `SELECT id
								FROM account
								WHERE crdb_region = $1
								ORDER BY random()
								LIMIT $2`

	rows, err := r.db.QueryContext(ctx, stmt, r.region, 1000)
	if err != nil {
		return nil, fmt.Errorf("making query: %w", err)
	}

	var ids []any
	var id string

	for rows.Next() {
		if err = rows.Scan(&id); err != nil {
			return nil, fmt.Errorf("scanning row: %w", err)
		}
		ids = append(ids, id)
	}

	return ids, nil
}

func (r *PostgresRepoMR) MakeRequest(ctx context.Context, idFrom, idTo any, amount float64) error {
	const stmt = `UPDATE account
									SET balance = CASE 
										WHEN id = $1 THEN balance - $3
										WHEN id = $2 THEN balance + $3
									END
								WHERE id IN ($1, $2)
								AND crdb_region = $4`

	if _, err := r.db.ExecContext(ctx, stmt, idFrom, idTo, amount, r.region); err != nil {
		return fmt.Errorf("making request: %w", err)
	}

	return nil
}
