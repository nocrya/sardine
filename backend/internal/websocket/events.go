package websocket

import "time"

type ClientProfile struct {
	UserID      int64     `json:"user_id"`
	DisplayName string    `json:"display_name"`
	LastActive  time.Time `json:"last_active"`
	Online      bool      `json:"online"`
}

// Event 是后续 WebSocket 推送的统一包裹结构。
type Event struct {
	Type      string         `json:"type"`
	Timestamp time.Time      `json:"timestamp"`
	Payload   map[string]any `json:"payload"`
}

func NewMessageCreatedEvent(channelID, messageID int64) Event {
	return Event{
		Type:      "message.created",
		Timestamp: time.Now().UTC(),
		Payload: map[string]any{
			"channel_id": channelID,
			"message_id": messageID,
		},
	}
}

func NewMessageCreatedWithPayload(channelID int64, message map[string]any) Event {
	return Event{
		Type:      "message.created",
		Timestamp: time.Now().UTC(),
		Payload: map[string]any{
			"channel_id": channelID,
			"message":    message,
		},
	}
}

func NewPresenceSnapshotEvent(channelID int64, members []ClientProfile) Event {
	return Event{
		Type:      "presence.snapshot",
		Timestamp: time.Now().UTC(),
		Payload: map[string]any{
			"channel_id": channelID,
			"members":    members,
		},
	}
}

func NewPresenceJoinedEvent(channelID int64, member ClientProfile) Event {
	return Event{
		Type:      "presence.joined",
		Timestamp: time.Now().UTC(),
		Payload: map[string]any{
			"channel_id": channelID,
			"member":     member,
		},
	}
}

func NewPresenceLeftEvent(channelID int64, member ClientProfile) Event {
	return Event{
		Type:      "presence.left",
		Timestamp: time.Now().UTC(),
		Payload: map[string]any{
			"channel_id": channelID,
			"member":     member,
		},
	}
}

func NewServerPresenceSnapshotEvent(serverID int64, members []ClientProfile) Event {
	return Event{
		Type:      "server.presence.snapshot",
		Timestamp: time.Now().UTC(),
		Payload: map[string]any{
			"server_id": serverID,
			"members":   members,
		},
	}
}

func NewServerPresenceUpdatedEvent(serverID int64, member ClientProfile) Event {
	return Event{
		Type:      "server.presence.updated",
		Timestamp: time.Now().UTC(),
		Payload: map[string]any{
			"server_id": serverID,
			"member":    member,
		},
	}
}

func NewTypingStartedEvent(channelID int64, member ClientProfile) Event {
	return Event{
		Type:      "typing.started",
		Timestamp: time.Now().UTC(),
		Payload: map[string]any{
			"channel_id": channelID,
			"member":     member,
		},
	}
}

func NewTypingStoppedEvent(channelID int64, member ClientProfile) Event {
	return Event{
		Type:      "typing.stopped",
		Timestamp: time.Now().UTC(),
		Payload: map[string]any{
			"channel_id": channelID,
			"member":     member,
		},
	}
}

func NewDirectMessageCreatedEvent(conversationID int64, message map[string]any) Event {
	return Event{
		Type:      "direct.message.created",
		Timestamp: time.Now().UTC(),
		Payload: map[string]any{
			"conversation_id": conversationID,
			"message":         message,
		},
	}
}

func NewDirectPresenceSnapshotEvent(conversationID int64, members []ClientProfile) Event {
	return Event{
		Type:      "direct.presence.snapshot",
		Timestamp: time.Now().UTC(),
		Payload: map[string]any{
			"conversation_id": conversationID,
			"members":         members,
		},
	}
}

func NewDirectPresenceJoinedEvent(conversationID int64, member ClientProfile) Event {
	return Event{
		Type:      "direct.presence.joined",
		Timestamp: time.Now().UTC(),
		Payload: map[string]any{
			"conversation_id": conversationID,
			"member":          member,
		},
	}
}

func NewDirectPresenceLeftEvent(conversationID int64, member ClientProfile) Event {
	return Event{
		Type:      "direct.presence.left",
		Timestamp: time.Now().UTC(),
		Payload: map[string]any{
			"conversation_id": conversationID,
			"member":          member,
		},
	}
}

func NewDirectTypingStartedEvent(conversationID int64, member ClientProfile) Event {
	return Event{
		Type:      "direct.typing.started",
		Timestamp: time.Now().UTC(),
		Payload: map[string]any{
			"conversation_id": conversationID,
			"member":          member,
		},
	}
}

func NewDirectTypingStoppedEvent(conversationID int64, member ClientProfile) Event {
	return Event{
		Type:      "direct.typing.stopped",
		Timestamp: time.Now().UTC(),
		Payload: map[string]any{
			"conversation_id": conversationID,
			"member":          member,
		},
	}
}

func NewDirectReadSnapshotEvent(conversationID int64, reads any) Event {
	return Event{
		Type:      "direct.read.snapshot",
		Timestamp: time.Now().UTC(),
		Payload: map[string]any{
			"conversation_id": conversationID,
			"reads":           reads,
		},
	}
}

func NewDirectReadUpdatedEvent(conversationID int64, read any) Event {
	return Event{
		Type:      "direct.read.updated",
		Timestamp: time.Now().UTC(),
		Payload: map[string]any{
			"conversation_id": conversationID,
			"read":            read,
		},
	}
}
