cc.import("cocos.functions")
local gamemodel = cc.import("#gamemodel")

local Online = gamemodel.Online

local Session = cc.import("#session")

local gbc = cc.import("#gbc")
local WebSocketInstance = cc.class("WebSocketInstance", gbc.WebSocketInstanceBase)

function WebSocketInstance:ctor(config)
    WebSocketInstance.super.ctor(self, config)
    self._event:bind(WebSocketInstance.EVENT.CONNECTED, cc.handler(self, self.onConnected))
    self._event:bind(WebSocketInstance.EVENT.DISCONNECTED, cc.handler(self, self.onDisconnected))

    local mapFile = "/Users/dev/Documents/gbc-server/apps/rpg/maps/world_server.json"
    local online = Online:new(self)
    online:setMapPath(mapFile)
    online:initMapIf()
    self._online = online
end

function WebSocketInstance:onConnected()
    -- cc.printwarn("[websocket:%s] connected", self:getConnectId())
    local redis = self:getRedis()
    -- self._online:subscribeChannel()

    -- load session
    local sid = self:getConnectToken() -- token is session id
    local session = Session:new(redis)
    session:start(sid)

    -- add user to online users list
    
    -- local username = session:get("username")
    -- online:add(username, self:getConnectId())

    -- -- send all usernames to current client
    -- local users = online:getAll()
    -- online:sendMessage(username, {name = "LIST_ALL_USERS", users = users})
    -- subscribe online users event
    

    -- self._username = username
    self._session = session
    self._online:subscribeChannel()
    

end

function WebSocketInstance:onDisconnected(event)
    self._online:playerQuit()
    
    if event.reason ~= gbc.Constants.CLOSE_CONNECT then
        self._online:unsubscribeChannel()
    end
end

function WebSocketInstance:heartbeat()
    -- refresh session
    self._session:setKeepAlive()
end

function WebSocketInstance:getUsername()
    return self._username
end

function WebSocketInstance:getSession()
    return self._session
end

function WebSocketInstance:getOnline()
    return self._online
end

return WebSocketInstance
