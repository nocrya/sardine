package model

import "time"

type DirectConversation struct {
	ID                    int64     `json:"id"`
	PeerUserID            int64     `json:"peer_user_id"`
	PeerName              string    `json:"peer_name"`
	LastMessage           string    `json:"last_message"`
	LastMessageAt         time.Time `json:"last_message_at"`
	PeerLastReadMessageID int64     `json:"peer_last_read_message_id"`
	PeerLastReadAt        time.Time `json:"peer_last_read_at"`
	UnreadCount           int64     `json:"unread_count"`
}

type DirectMessage struct {
	ID                int64     `json:"id"`
	ConversationID    int64     `json:"conversation_id"`
	SenderID          int64     `json:"sender_id"`
	SenderDisplayName string    `json:"sender_display_name"`
	Content           string    `json:"content"`
	CreatedAt         time.Time `json:"created_at"`
	UpdatedAt         time.Time `json:"updated_at"`
}

type DirectReadState struct {
	UserID            int64     `json:"user_id"`
	LastReadMessageID int64     `json:"last_read_message_id"`
	LastReadAt        time.Time `json:"last_read_at"`
}
