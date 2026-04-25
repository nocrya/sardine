package model

import "time"

type Server struct {
	ID          int64     `json:"id"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	OwnerID     int64     `json:"owner_id"`
	MemberRole  string    `json:"member_role"`
	UnreadCount int64     `json:"unread_count"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type ServerMember struct {
	UserID      int64     `json:"user_id"`
	Email       string    `json:"email"`
	DisplayName string    `json:"display_name"`
	Role        string    `json:"role"`
	JoinedAt    time.Time `json:"joined_at"`
}

type Channel struct {
	ID          int64     `json:"id"`
	ServerID    int64     `json:"server_id"`
	Name        string    `json:"name"`
	Kind        string    `json:"kind"`
	Topic       string    `json:"topic"`
	UnreadCount int64     `json:"unread_count"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type Message struct {
	ID                int64     `json:"id"`
	ChannelID         int64     `json:"channel_id"`
	SenderID          int64     `json:"sender_id"`
	SenderDisplayName string    `json:"sender_display_name"`
	Content           string    `json:"content"`
	CreatedAt         time.Time `json:"created_at"`
	UpdatedAt         time.Time `json:"updated_at"`
}

type ServerInvite struct {
	Code       string     `json:"code"`
	ServerID   int64      `json:"server_id"`
	CreatedBy  int64      `json:"created_by"`
	Role       string     `json:"role"`
	UseCount   int64      `json:"use_count"`
	MaxUses    int64      `json:"max_uses"`
	ExpiresAt  *time.Time `json:"expires_at,omitempty"`
	CreatedAt  time.Time  `json:"created_at"`
	InviteLink string     `json:"invite_link"`
}

type VoiceJoinSession struct {
	ChannelID           int64  `json:"channel_id"`
	RoomName            string `json:"room_name"`
	ServerURL           string `json:"server_url"`
	AccessToken         string `json:"access_token"`
	ParticipantIdentity string `json:"participant_identity"`
	ParticipantName     string `json:"participant_name"`
}
