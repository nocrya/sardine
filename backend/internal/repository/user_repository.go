package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"github.com/nocrya/sardine/internal/model"
)

var ErrUserNotFound = errors.New("user not found")

type UserRepository struct {
	db *sql.DB
}

func NewUserRepository(db *sql.DB) *UserRepository {
	return &UserRepository{db: db}
}

func (r *UserRepository) Create(ctx context.Context, user *model.User) error {
	if r.db == nil {
		return errors.New("postgres is not configured")
	}

	const query = `
INSERT INTO users (email, username, password_hash, display_name, avatar_url)
VALUES ($1, $2, $3, $4, $5)
RETURNING id, created_at, updated_at;
`

	return r.db.QueryRowContext(
		ctx,
		query,
		user.Email,
		user.Username,
		user.PasswordHash,
		user.DisplayName,
		user.AvatarURL,
	).Scan(&user.ID, &user.CreatedAt, &user.UpdatedAt)
}

func (r *UserRepository) FindByEmail(ctx context.Context, email string) (*model.User, error) {
	return r.findOne(ctx, "email = $1", email)
}

func (r *UserRepository) FindByUsername(ctx context.Context, username string) (*model.User, error) {
	return r.findOne(ctx, "username = $1", username)
}

func (r *UserRepository) FindByID(ctx context.Context, id int64) (*model.User, error) {
	return r.findOne(ctx, "id = $1", id)
}

func (r *UserRepository) findOne(ctx context.Context, whereClause string, value any) (*model.User, error) {
	if r.db == nil {
		return nil, errors.New("postgres is not configured")
	}

	query := fmt.Sprintf(`
SELECT id, email, username, display_name, avatar_url, password_hash, created_at, updated_at
FROM users
WHERE %s
LIMIT 1;
`, whereClause)

	var user model.User
	err := r.db.QueryRowContext(ctx, query, value).Scan(
		&user.ID,
		&user.Email,
		&user.Username,
		&user.DisplayName,
		&user.AvatarURL,
		&user.PasswordHash,
		&user.CreatedAt,
		&user.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}

	return &user, nil
}
