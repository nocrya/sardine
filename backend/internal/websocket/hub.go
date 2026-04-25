package websocket

import (
	"encoding/json"
	"log"
	"sync"
	"time"

	gws "github.com/gorilla/websocket"
)

type Hub struct {
	mu                 sync.RWMutex
	clients            map[*Client]struct{}
	channelSubscribers map[int64]map[*Client]struct{}
	directSubscribers  map[int64]map[*Client]struct{}
	serverSubscribers  map[int64]map[*Client]struct{}
	userPresence       map[int64]*PresenceState
}

type PresenceState struct {
	UserID      int64
	DisplayName string
	LastActive  time.Time
	ActiveCount int
}

type Client struct {
	hub             *Hub
	conn            *gws.Conn
	userID          int64
	displayName     string
	send            chan []byte
	channelSubs     map[int64]struct{}
	directSubs      map[int64]struct{}
	serverSubs      map[int64]struct{}
	channelToServer map[int64]int64
}

func NewHub() *Hub {
	return &Hub{
		clients:            make(map[*Client]struct{}),
		channelSubscribers: make(map[int64]map[*Client]struct{}),
		directSubscribers:  make(map[int64]map[*Client]struct{}),
		serverSubscribers:  make(map[int64]map[*Client]struct{}),
		userPresence:       make(map[int64]*PresenceState),
	}
}

func (h *Hub) Run() {
	log.Print("websocket hub: ready")
}

func (h *Hub) Register(conn *gws.Conn, userID int64, displayName string) *Client {
	now := time.Now().UTC()
	client := &Client{
		hub:             h,
		conn:            conn,
		userID:          userID,
		displayName:     displayName,
		send:            make(chan []byte, 32),
		channelSubs:     make(map[int64]struct{}),
		directSubs:      make(map[int64]struct{}),
		serverSubs:      make(map[int64]struct{}),
		channelToServer: make(map[int64]int64),
	}

	h.mu.Lock()
	h.clients[client] = struct{}{}
	if _, ok := h.userPresence[userID]; !ok {
		h.userPresence[userID] = &PresenceState{
			UserID:      userID,
			DisplayName: displayName,
			LastActive:  now,
		}
	} else {
		h.userPresence[userID].DisplayName = displayName
		h.userPresence[userID].LastActive = now
	}
	h.mu.Unlock()

	return client
}

func (h *Hub) Unregister(client *Client) {
	type serverUpdate struct {
		serverID int64
		profile  ClientProfile
	}
	var channelLeaves []int64
	var serverLeaves []serverUpdate

	h.mu.Lock()
	if _, ok := h.clients[client]; !ok {
		h.mu.Unlock()
		return
	}
	delete(h.clients, client)

	for channelID, serverID := range client.channelToServer {
		channelLeaves = append(channelLeaves, channelID)
		if subscribers, ok := h.channelSubscribers[channelID]; ok {
			delete(subscribers, client)
			if len(subscribers) == 0 {
				delete(h.channelSubscribers, channelID)
			}
		}

		if state, ok := h.userPresence[client.userID]; ok {
			state.LastActive = time.Now().UTC()
			if _, stillSubscribed := client.serverSubs[serverID]; stillSubscribed {
				state.ActiveCount--
				if state.ActiveCount < 0 {
					state.ActiveCount = 0
				}
				serverLeaves = append(serverLeaves, serverUpdate{
					serverID: serverID,
					profile:  profileFromState(state),
				})
			}
		}
	}

	for conversationID := range client.directSubs {
		if subscribers, ok := h.directSubscribers[conversationID]; ok {
			delete(subscribers, client)
			if len(subscribers) == 0 {
				delete(h.directSubscribers, conversationID)
			}
		}
	}

	for serverID := range client.serverSubs {
		if subscribers, ok := h.serverSubscribers[serverID]; ok {
			delete(subscribers, client)
			if len(subscribers) == 0 {
				delete(h.serverSubscribers, serverID)
			}
		}
	}

	close(client.send)
	h.mu.Unlock()

	for _, channelID := range channelLeaves {
		profile := h.CurrentProfile(client.userID)
		h.PublishToChannel(channelID, NewPresenceLeftEvent(channelID, profile))
		h.PublishToChannel(channelID, NewTypingStoppedEvent(channelID, profile))
	}
	for _, update := range serverLeaves {
		h.PublishToServer(update.serverID, NewServerPresenceUpdatedEvent(update.serverID, update.profile))
	}
	for conversationID := range client.directSubs {
		profile := h.CurrentProfile(client.userID)
		h.PublishToDirectConversation(conversationID, NewDirectPresenceLeftEvent(conversationID, profile))
		h.PublishToDirectConversation(conversationID, NewDirectTypingStoppedEvent(conversationID, profile))
	}
}

func (h *Hub) Subscribe(client *Client, serverID, channelID int64) {
	var channelSnapshot []ClientProfile
	var serverSnapshot []ClientProfile
	channelJoined := false
	serverJoined := false

	h.mu.Lock()
	if _, ok := h.channelSubscribers[channelID]; !ok {
		h.channelSubscribers[channelID] = make(map[*Client]struct{})
	}
	if _, ok := h.serverSubscribers[serverID]; !ok {
		h.serverSubscribers[serverID] = make(map[*Client]struct{})
	}
	if _, ok := client.channelSubs[channelID]; !ok {
		channelJoined = true
	}
	if _, ok := client.serverSubs[serverID]; !ok {
		serverJoined = true
	}
	h.channelSubscribers[channelID][client] = struct{}{}
	h.serverSubscribers[serverID][client] = struct{}{}
	client.channelSubs[channelID] = struct{}{}
	client.serverSubs[serverID] = struct{}{}
	client.channelToServer[channelID] = serverID

	state := h.userPresence[client.userID]
	if state == nil {
		state = &PresenceState{
			UserID:      client.userID,
			DisplayName: client.displayName,
		}
		h.userPresence[client.userID] = state
	}
	state.DisplayName = client.displayName
	state.LastActive = time.Now().UTC()
	if channelJoined {
		state.ActiveCount++
	}

	channelSnapshot = h.channelProfilesLocked(channelID)
	serverSnapshot = h.serverProfilesLocked(serverID)
	profile := profileFromState(state)
	h.mu.Unlock()

	h.Send(client, NewPresenceSnapshotEvent(channelID, channelSnapshot))
	h.Send(client, NewServerPresenceSnapshotEvent(serverID, serverSnapshot))
	if channelJoined {
		h.PublishToChannel(channelID, NewPresenceJoinedEvent(channelID, profile))
	}
	if serverJoined || channelJoined {
		h.PublishToServer(serverID, NewServerPresenceUpdatedEvent(serverID, profile))
	}
}

func (h *Hub) SubscribeToDirectConversation(client *Client, conversationID int64, readStates any) {
	var snapshot []ClientProfile
	joined := false

	h.mu.Lock()
	if _, ok := h.directSubscribers[conversationID]; !ok {
		h.directSubscribers[conversationID] = make(map[*Client]struct{})
	}
	if _, ok := client.directSubs[conversationID]; !ok {
		joined = true
	}
	h.directSubscribers[conversationID][client] = struct{}{}
	client.directSubs[conversationID] = struct{}{}
	state := h.userPresence[client.userID]
	if state == nil {
		state = &PresenceState{
			UserID:      client.userID,
			DisplayName: client.displayName,
		}
		h.userPresence[client.userID] = state
	}
	state.DisplayName = client.displayName
	state.LastActive = time.Now().UTC()
	snapshot = h.directProfilesLocked(conversationID)
	h.mu.Unlock()

	h.Send(client, NewDirectPresenceSnapshotEvent(conversationID, snapshot))
	h.Send(client, NewDirectReadSnapshotEvent(conversationID, readStates))
	if joined {
		h.PublishToDirectConversation(conversationID, NewDirectPresenceJoinedEvent(conversationID, client.Profile()))
	}
}

func (h *Hub) Unsubscribe(client *Client, channelID int64) {
	type serverUpdate struct {
		serverID int64
		profile  ClientProfile
	}
	var serverEvent *serverUpdate
	var channelProfile *ClientProfile

	h.mu.Lock()
	serverID, subscribed := client.channelToServer[channelID]
	if !subscribed {
		h.mu.Unlock()
		return
	}
	delete(client.channelSubs, channelID)
	delete(client.channelToServer, channelID)
	if subscribers, ok := h.channelSubscribers[channelID]; ok {
		delete(subscribers, client)
		if len(subscribers) == 0 {
			delete(h.channelSubscribers, channelID)
		}
	}

	stillInServer := false
	for _, mappedServerID := range client.channelToServer {
		if mappedServerID == serverID {
			stillInServer = true
			break
		}
	}
	if !stillInServer {
		delete(client.serverSubs, serverID)
		if subscribers, ok := h.serverSubscribers[serverID]; ok {
			delete(subscribers, client)
			if len(subscribers) == 0 {
				delete(h.serverSubscribers, serverID)
			}
		}
	}

	if state, ok := h.userPresence[client.userID]; ok {
		state.LastActive = time.Now().UTC()
		state.ActiveCount--
		if state.ActiveCount < 0 {
			state.ActiveCount = 0
		}
		profile := profileFromState(state)
		channelProfile = &profile
		serverEvent = &serverUpdate{serverID: serverID, profile: profile}
	}
	h.mu.Unlock()

	if channelProfile != nil {
		h.PublishToChannel(channelID, NewPresenceLeftEvent(channelID, *channelProfile))
		h.PublishToChannel(channelID, NewTypingStoppedEvent(channelID, *channelProfile))
	}
	if serverEvent != nil {
		h.PublishToServer(serverEvent.serverID, NewServerPresenceUpdatedEvent(serverEvent.serverID, serverEvent.profile))
	}
}

func (h *Hub) UnsubscribeFromDirectConversation(client *Client, conversationID int64) {
	removed := false
	h.mu.Lock()
	if _, ok := client.directSubs[conversationID]; ok {
		removed = true
	}
	delete(client.directSubs, conversationID)
	if subscribers, ok := h.directSubscribers[conversationID]; ok {
		delete(subscribers, client)
		if len(subscribers) == 0 {
			delete(h.directSubscribers, conversationID)
		}
	}
	h.mu.Unlock()

	profile := h.CurrentProfile(client.userID)
	if removed {
		h.PublishToDirectConversation(conversationID, NewDirectPresenceLeftEvent(conversationID, profile))
	}
	h.PublishToDirectConversation(conversationID, NewDirectTypingStoppedEvent(conversationID, profile))
}

func (h *Hub) PublishToChannel(channelID int64, event Event) {
	payload, err := json.Marshal(event)
	if err != nil {
		log.Printf("websocket publish marshal: %v", err)
		return
	}

	h.mu.RLock()
	subscribers := h.channelSubscribers[channelID]
	clients := make([]*Client, 0, len(subscribers))
	for client := range subscribers {
		clients = append(clients, client)
	}
	h.mu.RUnlock()

	h.publishBytes(clients, payload)
}

func (h *Hub) PublishToServer(serverID int64, event Event) {
	payload, err := json.Marshal(event)
	if err != nil {
		log.Printf("websocket publish server marshal: %v", err)
		return
	}

	h.mu.RLock()
	subscribers := h.serverSubscribers[serverID]
	clients := make([]*Client, 0, len(subscribers))
	for client := range subscribers {
		clients = append(clients, client)
	}
	h.mu.RUnlock()

	h.publishBytes(clients, payload)
}

func (h *Hub) PublishToDirectConversation(conversationID int64, event Event) {
	payload, err := json.Marshal(event)
	if err != nil {
		log.Printf("websocket publish direct marshal: %v", err)
		return
	}

	h.mu.RLock()
	subscribers := h.directSubscribers[conversationID]
	clients := make([]*Client, 0, len(subscribers))
	for client := range subscribers {
		clients = append(clients, client)
	}
	h.mu.RUnlock()

	h.publishBytes(clients, payload)
}

func (h *Hub) Send(client *Client, event Event) {
	payload, err := json.Marshal(event)
	if err != nil {
		log.Printf("websocket send marshal: %v", err)
		return
	}

	select {
	case client.send <- payload:
	default:
		go client.Close()
	}
}

func (h *Hub) CurrentProfile(userID int64) ClientProfile {
	h.mu.RLock()
	defer h.mu.RUnlock()
	if state, ok := h.userPresence[userID]; ok {
		return profileFromState(state)
	}
	return ClientProfile{UserID: userID, LastActive: time.Now().UTC()}
}

func (h *Hub) Touch(userID int64) ClientProfile {
	h.mu.Lock()
	defer h.mu.Unlock()
	state, ok := h.userPresence[userID]
	if !ok {
		state = &PresenceState{UserID: userID}
		h.userPresence[userID] = state
	}
	state.LastActive = time.Now().UTC()
	return profileFromState(state)
}

func (h *Hub) channelProfilesLocked(channelID int64) []ClientProfile {
	subscribers := h.channelSubscribers[channelID]
	profiles := make([]ClientProfile, 0, len(subscribers))
	seen := make(map[int64]struct{})
	for client := range subscribers {
		if _, ok := seen[client.userID]; ok {
			continue
		}
		seen[client.userID] = struct{}{}
		if state, ok := h.userPresence[client.userID]; ok {
			profiles = append(profiles, profileFromState(state))
		}
	}
	return profiles
}

func (h *Hub) serverProfilesLocked(serverID int64) []ClientProfile {
	subscribers := h.serverSubscribers[serverID]
	profiles := make([]ClientProfile, 0, len(subscribers))
	seen := make(map[int64]struct{})
	for client := range subscribers {
		if _, ok := seen[client.userID]; ok {
			continue
		}
		seen[client.userID] = struct{}{}
		if state, ok := h.userPresence[client.userID]; ok {
			profiles = append(profiles, profileFromState(state))
		}
	}
	return profiles
}

func (h *Hub) directProfilesLocked(conversationID int64) []ClientProfile {
	subscribers := h.directSubscribers[conversationID]
	profiles := make([]ClientProfile, 0, len(subscribers))
	seen := make(map[int64]struct{})
	for client := range subscribers {
		if _, ok := seen[client.userID]; ok {
			continue
		}
		seen[client.userID] = struct{}{}
		if state, ok := h.userPresence[client.userID]; ok {
			profiles = append(profiles, profileFromState(state))
		}
	}
	return profiles
}

func (h *Hub) publishBytes(clients []*Client, payload []byte) {
	for _, client := range clients {
		select {
		case client.send <- payload:
		default:
			go client.Close()
		}
	}
}

func profileFromState(state *PresenceState) ClientProfile {
	return ClientProfile{
		UserID:      state.UserID,
		DisplayName: state.DisplayName,
		LastActive:  state.LastActive,
		Online:      state.ActiveCount > 0,
	}
}

func (c *Client) UserID() int64 {
	return c.userID
}

func (c *Client) Profile() ClientProfile {
	return c.hub.CurrentProfile(c.userID)
}

func (c *Client) ReadJSON(v any) error {
	return c.conn.ReadJSON(v)
}

func (c *Client) WritePump() {
	defer c.Close()

	for message := range c.send {
		if err := c.conn.WriteMessage(gws.TextMessage, message); err != nil {
			return
		}
	}
}

func (c *Client) Close() {
	c.hub.Unregister(c)
	_ = c.conn.Close()
}
