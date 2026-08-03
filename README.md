# Signal — Module Documentation

A Lua module for **Scrap Mechanic** that implements a "signal/event" pattern on top of the built-in messaging system (`sm.message`). It lets you create named communication channels between scripts, subscribe to them, temporarily enable/disable them, and emit data.

---

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [API](#api)
  - [Signal.new](#signalnewmessagekey-options-target)
  - [Signal.define](#signaldefinetarget-definitions)
  - [Signal:connect](#signalconnectcallbackname-target)
  - [Signal:disconnect](#signaldisconnect)
  - [Signal:emit](#signalemitdata)
  - [Signal:mute / Signal:unmute](#signalmute--signalunmute)
- [Signal Object Fields](#signal-object-fields)
- [Usage Examples](#usage-examples)

---

## Overview

The module wraps `sm.message.subscribe` / `sm.message.send` in a convenient OOP interface:

- **Sender** — calls `emit(data)` to broadcast data to all subscribers.
- **Receiver** — calls `connect(callbackName)` so the specified method is invoked when a message arrives.

It also supports:
- **mute/unmute** — temporarily disabling sending without losing the subscription;
- **disconnect** — a "soft" disconnect for the receiver (the hook stays in place but stops calling the original method);
- **bulk signal creation** via `Signal.define`.

---

## Installation

Place `signal.lua` in your mod's script folder and load it with `dofile`, using the `$CONTENT_` path to your mod's UUID:

```lua
local Signal = dofile("$CONTENT_<your-mod-uuid>/Scripts/signal.lua")
```

---

## API

> **Note:** All methods below (`Signal.new`, `Signal.define`, `Signal:connect`, `Signal:disconnect`, `Signal:emit`, `Signal:mute`, `Signal:unmute`) are **server-side only**. Call them from `server_*` callbacks (e.g. `server_onCreate`) — they are not meant to be used in `client_*` code.

### `Signal.new(messageKey, options, target)`

Creates a new signal instance.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `messageKey` | `string \| nil` | no | Unique channel key. If not provided, it's auto-generated via `sm.uuid.new()`. |
| `options` | `table \| nil` | no | Settings table. Supports `debug = true/false` to enable logging. |
| `target` | `table \| nil` | no | Reference to the script instance (usually `self`), used as the default target for `connect`. |

**Returns:** a new `Signal` object.

```lua
local mySignal = Signal.new("door_opened", { debug = true }, self)
```

---

### `Signal.define(target, definitions)`

Mass-creates and injects signals into the `target` table. Handy for initializing several signals at once in `server_onCreate`/`client_onCreate`.

| Parameter | Type | Description |
|---|---|---|
| `target` | `table` | The target table (usually `self`). |
| `definitions` | `table` | An array of names (strings) **or** a dictionary of configurations (`{key = {...}}`). |

Supports two formats:

1. **Simple array of strings** — creates signals with an auto-generated `messageKey`:
```lua
Signal.define(self, { "onDamage", "onRepair" })
-- self.onDamage and self.onRepair are now Signal objects
```

2. **Configuration dictionary** (key is the field name, value is a settings table, including `key`):
```lua
Signal.define(self, {
    onDamage = { key = "vehicle_damage", debug = true },
})
-- self.onDamage is created with messageKey = "vehicle_damage"
```

**Returns:** the same `target` (for chaining convenience).

---

### `Signal:connect(callbackName, target)`

Subscribes the method `target[callbackName]` to this signal. Works both as an initial connection and as a reconnection.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `callbackName` | `string` | yes | Name of the method in `target` to be invoked when the message arrives. |
| `target` | `table \| nil` | no | The script instance. If not provided, `self.target` (set in `Signal.new`) is used. |

**Important:** the method `target[callbackName]` must already exist before calling `connect` (it's used as the "original" method and wrapped by the hook).

Inside `connect`, the method is wrapped only once (`_isHooked`), after which the hook checks `isConnected` before each actual call — this avoids **recreating the hook** on repeated `connect`/`disconnect` calls.

**Returns:** `self` (for chaining).

```lua
function MyScript:server_onCreate()
    self.onDamage = Signal.new("vehicle_damage", nil, self)
    self.onDamage:connect("onDamageReceived")
end

function MyScript:onDamageReceived(data)
    print("Damage received:", data.amount)
end
```

---

### `Signal:disconnect()`

"Softly" disconnects the receiver: the hook itself (`sm.message.subscribe`) remains registered, but when the message fires, the original method is **not** called as long as `isConnected == false`.

**Returns:** `self`.

```lua
self.onDamage:disconnect()
-- can be re-enabled later:
self.onDamage:connect("onDamageReceived")
```

---

### `Signal:emit(data)`

Sends data to all subscribers of the `messageKey` channel via `sm.message.send`. If the signal is muted (`isMuted == true`), nothing is sent.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `data` | `any \| nil` | no | The message payload. |

**Returns:** `self`.

```lua
self.onDamage:emit({ amount = 25, source = "explosion" })
```

---

### `Signal:mute()` / `Signal:unmute()`

Control the `isMuted` flag on the sender's side. While muted, calls to `emit()` are silently ignored (no error).

**Return:** `self`.

```lua
self.onDamage:mute()     -- temporarily disable sending
self.onDamage:emit(data) -- nothing happens
self.onDamage:unmute()   -- re-enable sending
```

---

## Signal Object Fields

| Field | Type | Description |
|---|---|---|
| `messageKey` | `string` | Unique identifier of the message channel. |
| `options` | `table` | Settings table passed at creation. |
| `isDebug` | `boolean` | Enables debug logs during `connect`/`disconnect`. |
| `isMuted` | `boolean` | Whether sending is muted (sender side). |
| `isConnected` | `boolean` | Whether the subscription is active (receiver side). |
| `target` | `table \| nil` | Reference to the script instance. |
| `callbackName` | `string \| nil` | Name of the connected method. |
| `_isHooked` | `boolean` | Internal flag: whether the method has already been wrapped by the hook (do not edit manually). |

---

## Usage Examples

### 1. Simple link between two scripts

**Sender script (e.g., a button):**
```lua
local Signal = dofile("$CONTENT_<your-mod-uuid>/Scripts/signal.lua")

ButtonScript = class()

function ButtonScript:server_onCreate()
    self.onPressed = Signal.new("button_pressed", nil, self)
end

function ButtonScript:onInteract(character, state)
    if state then
        self.onPressed:emit({ pressedBy = character })
    end
end
```

**Receiver script (e.g., a door):**
```lua
local Signal = dofile("$CONTENT_<your-mod-uuid>/Scripts/signal.lua")

DoorScript = class()

function DoorScript:server_onCreate()
    self.onPressed = Signal.new("button_pressed", nil, self)
    self.onPressed:connect("openDoor")
end

function DoorScript:openDoor(data)
    print("Door opened by:", tostring(data.pressedBy))
    -- door-opening logic here
end
```

### 2. Bulk signal creation with `Signal.define`

```lua
local Signal = dofile("$CONTENT_<your-mod-uuid>/Scripts/signal.lua")

VehicleScript = class()

function VehicleScript:server_onCreate()
    Signal.define(self, {
        "onEngineStart",
        "onEngineStop",
        onDamage = { key = "vehicle_damage_channel", debug = true },
    })

    self.onDamage:connect("handleDamage")
end

function VehicleScript:handleDamage(data)
    self.health = self.health - data.amount
end
```

### 3. Temporarily muting a signal

```lua
-- Disable notifications during initialization to avoid spamming events
self.onStateChanged:mute()
self:resetState()
self.onStateChanged:unmute()
self.onStateChanged:emit({ state = "ready" })
```

### 4. Softly disconnecting/reconnecting a receiver

```lua
-- For example, disable damage handling while the object is invulnerable
function VehicleScript:activateShield()
    self.onDamage:disconnect()
end

function VehicleScript:deactivateShield()
    self.onDamage:connect("handleDamage")
end
```

### 5. Storing a signal in a global Lua table

Instead of creating a signal separately in every script and matching `messageKey` strings by hand, you can create it once and store it in a global Lua table. Any other script in the mod can then read that same `Signal` object directly — no need to know the `messageKey` at all, since they all share the exact same instance.

```lua
-- GlobalSignals.lua — loaded once, e.g. via a dofile/require at the top of your scripts
local Signal = dofile("$CONTENT_<your-mod-uuid>/Scripts/signal.lua")

-- A global table accessible from any script in the mod
MyModSignals = MyModSignals or {}

MyModSignals.onPlayerScored = MyModSignals.onPlayerScored or Signal.new("global_player_scored", { debug = true })
```

Any script can now connect to or emit from the very same signal instance via the global table:

```lua
-- ScoreKeeper.lua — emits the signal
function ScoreKeeper:server_onCreate()
    self.data = { points = 0 }
end

function ScoreKeeper:addPoints(amount)
    self.data.points = self.data.points + amount
    MyModSignals.onPlayerScored:emit({ points = self.data.points })
end
```

```lua
-- ScoreDisplay.lua — listens to the signal
ScoreDisplay = class()

function ScoreDisplay:server_onCreate()
    MyModSignals.onPlayerScored:connect("onScore", self)
end

function ScoreDisplay:onScore(data)
    print("Score updated:", data.points)
end
```

> **Note:** since the table is global, make sure `GlobalSignals.lua` is loaded before any script that references `MyModSignals` — for example, by placing a `dofile("$CONTENT_.../Scripts/GlobalSignals.lua")` at the top of every script that needs it, or by relying on your mod's load order.

### 6. Fully disconnecting a signal and destroying the instance

As shown in the [`disconnect`](#signaldisconnect) reference above, calling `signal:disconnect()` only performs a **soft** disconnect: it flips `isConnected` to `false` so the wrapped method stops being invoked, but the hook installed on `target[callbackName]` is never removed, and the `Signal` object itself still exists in memory as long as something references it.

To fully tear a signal down — so the hook stops intercepting calls, the connection to `sm.message` is dropped, and the `Signal` instance can be garbage-collected — you need to do a bit more than just call `disconnect()`:

```lua
function MyScript:teardownSignal()
    if self.onDamage then
        -- 1. Soft-disconnect first, so no stale calls slip through
        --    while we tear the rest down.
        self.onDamage:disconnect()

        -- 2. Restore the original (unwrapped) method on the target,
        --    removing the hook that Signal:connect() installed.
        --    (Requires you to have kept a reference to the original
        --    method yourself before calling :connect(), since the
        --    module does not expose it.)
        if self.originalOnDamage then
            self[self.onDamage.callbackName] = self.originalOnDamage
            self.originalOnDamage = nil
        end

        -- 3. Drop every reference to the Signal object so Lua's
        --    garbage collector can reclaim it.
        self.onDamage = nil
    end
end
```

To make step 2 possible, keep a copy of the method before you connect it:

```lua
function MyScript:server_onCreate()
    self.originalOnDamage = self.onDamageReceived   -- keep a reference for later restoration

    self.onDamage = Signal.new("vehicle_damage", nil, self)
    self.onDamage:connect("onDamageReceived")
end
```

> **Important limitations of this module:**
> - `signal.lua` does **not** call anything like `sm.message.unsubscribe` — there is no built-in API in this file to cancel the underlying `sm.message` subscription itself, only to stop reacting to it (`isConnected = false`).
> - The method-wrapping hook (`_isHooked`) is permanent for the lifetime of `target` — the module has no method to unwrap it automatically. The workaround above (steps 1–3) is the closest you can get with the current implementation: disconnect, manually restore the original method, then drop all references to the `Signal` object.
> - If you never need to literally remove the hook (most gameplay scripts don't), calling `disconnect()` and setting `self.onDamage = nil` is usually enough in practice — the leftover hook simply won't do anything once `isConnected` is `false`, and it will be collected along with `target` when the target itself is destroyed.

---

## Notes

- `messageKey` must match between the sender and the receiver, otherwise messages won't arrive.
- `connect` requires that a method named `callbackName` already exists on `target` at call time — otherwise an error is raised via `assert`.
- Calling `connect` again does **not** create a new hook thanks to the `_isHooked` flag; it only updates `target`, `callbackName`, and `isConnected`.
- `disconnect` does not cancel the `sm.message` subscription — it only blocks the actual method call. Keep this in mind when debugging.
