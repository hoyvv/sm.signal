---@class Signal
---@field messageKey string The unique identifier for the message channel.
---@field options table Configuration options for the signal.
---@field isDebug boolean Whether debug logging is enabled.
---@field isMuted boolean Whether the signal emission is suppressed (Sender side).
---@field isConnected boolean Whether the signal is actively listening (Receiver side).
---@field target table|nil Reference to the script instance.
---@field callbackName string|nil Name of the connected method.
local Signal = {}
Signal.__index = Signal

--- Creates a new Signal instance.
---@param messageKey string|nil Optional custom key.
---@param options table|nil Optional settings dictionary.
---@param target table|nil Optional reference to the script instance.
---@return Signal
function Signal.new(messageKey, options, target)
    local self = setmetatable({}, Signal)
    
    self.messageKey = messageKey or ("signal_" .. tostring(sm.uuid.new()))
    self.options = options or {}
    self.isDebug = self.options.debug or false
    
    self.isMuted = false
    self.isConnected = false
    self.target = target
    self.callbackName = nil
    self._isHooked = false
    
    return self
end

--- Mass-creates and injects signals into a target table.
---@param target table The target object (usually `self`).
---@param definitions table Array of signal names or a dictionary of configurations.
---@return table target
function Signal.define(target, definitions)
    assert(type(target) == "table", "[Signal Error] Target must be a table (usually 'self').")
    assert(type(definitions) == "table", "[Signal Error] Definitions must be a table.")

    for key, value in pairs(definitions) do
        if type(key) == "number" and type(value) == "string" then
            target[value] = Signal.new(nil, nil, target)
        elseif type(key) == "string" and type(value) == "table" then
            target[key] = Signal.new(value.key, value, target)
        else
            print("[Signal Warning] Skipped invalid configuration format in define:", key, value)
        end
    end
    
    return target
end

--- Subscribes a method to this signal (acts as connect/reconnect).
---@param callbackName string The name of the method to be invoked.
---@param target table|nil (Optional) The script instance.
---@return Signal self
function Signal:connect(callbackName, target)
    target = target or self.target
    assert(target ~= nil, "[Signal Error] Target is required for connection!")
    assert(type(callbackName) == "string", "[Signal Error] Callback name must be a string!")
    
    self.target = target
    self.callbackName = callbackName
    self.isConnected = true

    local originalMethod = target[callbackName]
    assert(type(originalMethod) == "function", ("[Signal Error] Method '%s' not found in target class!"):format(callbackName))

    if not self._isHooked then
        target[callbackName] = function(instance, data)
            if not self.isConnected then
                return
            end
            return originalMethod(instance, data)
        end
        self._isHooked = true
    end
    
    sm.message.subscribe(self.messageKey, callbackName)
    
    if self.isDebug then
        print(("[Signal Debug] Connected: Method '%s' is listening to '%s'"):format(callbackName, self.messageKey))
    end
    
    return self
end

--- Completely disconnects and deactivates the signal (simulates removal).
---@return Signal self
function Signal:disconnect()
    self.isConnected = false
    
    if self.isDebug then
        print(("[Signal Debug] Disconnected signal for key: %s"):format(self.messageKey))
    end
    
    return self
end

--- Emits the signal, broadcasting data to subscribers.
---@param data any|nil Optional data payload.
---@return Signal self
function Signal:emit(data)
    if self.isMuted then return self end
    sm.message.send(self.messageKey, data)
    return self
end

--- Temporarily disables emission (Sender side).
---@return Signal self
function Signal:mute()
    self.isMuted = true
    return self
end

--- Re-enables emission (Sender side).
---@return Signal self
function Signal:unmute()
    self.isMuted = false
    return self
end

return Signal