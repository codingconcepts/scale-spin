package repo

import (
	"database/sql"
	"fmt"
)

type Repo interface {
	FetchIDs() ([]any, error)
	MakeRequest(idFrom, idTo any, amount float64) error
}

type PostgresRepo struct {
	db *sql.DB
}

func NewPostgresRepo(db *sql.DB) *PostgresRepo {
	return &PostgresRepo{
		db: db,
	}
}

func (r *PostgresRepo) FetchIDs() ([]any, error) {
	const stmt = `SELECT id
								FROM account
								ORDER BY random()
								LIMIT $1`

	rows, err := r.db.Query(stmt, 1000)
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

func (r *PostgresRepo) MakeRequest(idFrom, idTo any, amount float64) error {
	const stmt = `UPDATE account
									SET balance = CASE 
										WHEN id = $1 THEN balance - $3
										WHEN id = $2 THEN balance + $3
									END
								WHERE id IN ($1, $2)`

	if _, err := r.db.Exec(stmt, idFrom, idTo, amount); err != nil {
		return fmt.Errorf("making request: %w", err)
	}

	return nil
}
