# Multiplayer Presence and Chat

Herja uses the Node backend WebSocket server for lightweight real-time multiplayer.

## What works now

- The client sends player position, name, level, character, and clan over WebSocket.
- The backend broadcasts a presence snapshot once per second.
- Other players render as remote character sprites with name, level, clan, and walking animation.
- Players can send chat messages through the same WebSocket connection.
- The in-game chat panel appears near the lower-left of the screen.

## Controls

```text
Enter / T = focus chat
Send button or Enter in the text field = send message
```

## Backend

The backend accepts:

- `player_state` packets for presence.
- `chat_message` packets for live chat.

Messages are trimmed to 180 characters before broadcast.

## Main files

- `backend/src/server.js`
- `godot_client/scripts/NetworkClient.gd`
- `godot_client/scripts/RemotePlayer.gd`
- `godot_client/scripts/ChatPanel.gd`
- `godot_client/scripts/Main.gd`
