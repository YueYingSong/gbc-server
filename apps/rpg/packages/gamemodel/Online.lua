--
-- Author: By.Yue
-- Date: 2016-10-14 11:54:55
--

local string_format = string.format

local json = cc.import("#json")
local gbc = cc.import("#gbc")

local Online = cc.class("Online")

local _ONLINE_SET        = "_ONLINE_USERS"
local _ONLINE_CHANNEL    = "_ONLINE_CHANNEL"
local _EVENT = table.readonly({
    ADD_USER    = "ADD_USER",
    REMOVE_USER = "REMOVE_USER",
})
local _CONNECT_TO_USERNAME = "_CONNECT_TO_USERNAME"
local _USERNAME_TO_CONNECT = "_USERNAME_TO_CONNECT"



local network   = cc.import("#network")

local Map       = cc.import(".Map")
local Entity    = cc.import(".Entity")
local Player    = cc.import(".Player")
local gbc       = cc.import("#gbc")

local Constant  = cc.import(".Constant")
local NetMsg    = network.NetMsg





function Online:ctor(instance)
    self._instance  = instance
    self._redis     = instance:getRedis()
    self._broadcast = gbc.Broadcast:new(self._redis, instance.config.app.websocketMessageFormat)
    self.mapPath_   = nil;
    self.player_    = {}
    self.attackIds_ = {}

end
function Online:getRedis()
    return self._redis
end
function Online:initMapIf()
    local redis = self._redis
    -- redis:set( Constant._MAP_LOAD_, "no")
    local isLoaded = redis:get( Constant._MAP_LOAD_)
    local entitys = {}
    if not isLoaded or "no" == isLoaded then
        cc.printf("需要初始化地图")
        local map = Map:new(self.mapPath_)

        -- generate static entity
        local staticEntity = map:getStaticEntity()
        local idCounter = 1001

        for idx, name in pairs(staticEntity) do
            local p = map:getPosByTileIdx(idx)
            local entity = Entity:new(self)
            entity:setPos(p)
            entity:setRoamingArea(cc.rect(p.x, p.y, 1, 1))
            entity:setRedis(redis)
            entity:setId(idCounter)
            entity:setHealth(100)
            entity:setName(name)
            idCounter = idCounter + 1

            entity:save()
            entitys[#entitys + 1] = entity

            redis:sadd( Constant._REDIS_KEY_SETS_ENTITY_STATIC_, entity:getId())
        end
        -- launch game loop timer
        self:schedule("jobs.loop", self._instance.config, 1)

        redis:set( Constant._MAP_LOAD_, "yes")
    else
        local ids = redis:smembers( Constant._REDIS_KEY_SETS_ENTITY_STATIC_)
        for i,id in ipairs(ids) do
            local entity = Entity:new(self)
            entity:setRedis(redis)
            entity:load(id)

            entitys[#entitys + 1] = entity
        end
    end
    self.entitysStatic_ = entitys
end

function Online:setMapPath(path)
    self.mapPath_ = path
end


function Online:getChannel()
    return _ONLINE_CHANNEL
end


function Online:sendMessageToAll(event)
    return self._broadcast:sendMessageToAll(event)
end


function Online:getEntitysStaticInfo()
    local entitys = self.entitysStatic_

    local infos = {}
    for i,info in ipairs(entitys) do
        table.insert(infos, info:getAttribute())
    end

    return infos
end
-- 怪物死了
function Online:removeEntity(id)
    local redis = self._redis
    -- cc.printf("死亡 删除怪物   %d",id)
    redis:srem( Constant._REDIS_KEY_SETS_ENTITY_STATIC_, id)

    for i,entity in ipairs(self.entitysStatic_) do
        if entity:getId() == id then
            -- cc.printf("找到死亡的怪物  删除  ")
            table.remove(self.entitysStatic_,i)
            break;
        end
    end
end

function Online:getEntityById(id)
    local entity = Entity:new(self)
    entity:load(id)

    return entity
end

function Online:getRebornPos()
    return cc.p(math.random(32, 43), math.random(224, 232))
end

function Online:getPlayerInfo(name, id)
    local entity = Player:new(self)
    local attr
    if id then
        entity:load(id)
    end
    local playerInfo = {}
    playerInfo.imageName = entity:getArmor() or "clotharmor.png"
    playerInfo.weaponName = entity:getWeapon() or "sword1.png"
    if string.len(name) > 10 then
        playerInfo.nickName = string.sub(name, 1, 10)
    end

    -- born position
    math.randomseed(os.time())
    playerInfo.pos = entity:getPos() or self:getRebornPos() -- cc.p(35, 230)

    local idCounter
    idCounter = entity:getId()
    if not idCounter then
        idCounter = self._redis:incr( Constant._REDIS_KEY_ID_COUNTER_)
        if 1 == idCounter then
            self._redis:set( Constant._REDIS_KEY_ID_COUNTER_, Constant.IDCounterBegin)
            idCounter = Constant.IDCounterBegin
        end
    end
    playerInfo.id = idCounter

    return playerInfo
end

function Online:getPlayerEntity(name, id)
    local entity
    local attr
    if string.len(name) > 10 then
        name = string.sub(name, 1, 10)
    end
    if id then
        cc.printwarn("玩家存不存在    不存在")
        entity = Player:new(self)
        if not entity:load(id) then
            entity = self:newPlayer()
        end
    else
        cc.printwarn("玩家存不存在    存在")
        entity = self:newPlayer()
    end

    entity:setNickName(name)
    entity:save()

    return entity
end

function Online:newPlayer()
    local entity = Player:new(self)
    entity:setArmor("clotharmor.png")
    entity:setWeapon("sword1.png")
    math.randomseed(os.time())
    entity:setPos(cc.p(math.random(35, 45), math.random(223, 234)))

    local idCounter
    idCounter = self._redis:incr( Constant._REDIS_KEY_ID_COUNTER_)
    if 1 == idCounter then
        self._redis:set( Constant._REDIS_KEY_ID_COUNTER_, Constant.IDCounterBegin)
        idCounter = Constant.IDCounterBegin
    end
    entity:setId(idCounter)

    return entity
end

function Online:newPlayerEntity(playerInfo)
    local entity = Player:new(self)
    entity:setPos(playerInfo.pos)
    entity:setRedis(self._redis)
    entity:setId(playerInfo.id)
    entity:setHealth(100)
    entity:setType(Entity.TYPE_WARRIOR)
    entity:setArmor(playerInfo.imageName)
    entity:setWeapon(playerInfo.weaponName)

    entity:save()
    table.insert(self.player_, entity)
end

function Online:getPlayerById(id)
    local player = Player:new(self)
    player:load(id)

    return player
end

function Online:getEntity(id)
    local cls
    -- cc.printf("id   %d",id)
    -- cc.printf(Constant.IDCounterBegin)
    if id >= Constant.IDCounterBegin then
        cls = Player
    else
        cls = Entity
    end

    local entity = cls:new(self)
    entity:load(id)

    return entity
end

function Online:setPlayerStatus(id, isOnline)
    if isOnline then
        -- cc.printf("插入一个玩家    %d %s", id,type(id))
        -- cc.printf("插入数据是否成功   %d", self._redis:sadd(Constant._REDIS_KEY_SETS_PLAYER_, id))
        self._redis:sadd( Constant._REDIS_KEY_SETS_PLAYER_, id)
        
    else
        -- cc.printf("删除一个玩家    %d", id)
        self._redis:srem( Constant._REDIS_KEY_SETS_PLAYER_, id)
        
    end
end

function Online:getOnlinePlayer()
    local players = self._redis:smembers(Constant._REDIS_KEY_SETS_PLAYER_)
    if not players then
        return
    end
    -- cc.dump(players,"所有玩家")
    local playerInfos = {}
    local player = Player:new(self)
    for i,v in ipairs(players) do
        player:load(v)
        table.insert(playerInfos, player:getPlayerInfo())
    end
    -- cc.dump(playerInfos,"所有玩家详细")
    return playerInfos
end

function Online:addAttackEntity(id)
    table.insert(self.attackIds_, id)
end

function Online:removeAttackEntity(id)
    local pos
    for i,v in ipairs(self.attackIds_) do
        if v == id then
            pos = i
            break
        end
    end
    table.remove(self.attackIds_, pos)
end

function Online:clearAttack(playerId)
    for i,v in ipairs(self.attackIds_) do
        local entity = self:getEntity(v)
        if playerId == entity:getAttack() then
            entity:setAttack(0)
        end
    end
    self.attackIds_ = {}
end



function Online:playerEntry(id)
    local playerId = id
    if not playerId then
        return
    end
    self.curPlayId_ = playerId
    cc.printf("进来了一个玩家   %d", playerId)
    self:setPlayerStatus(playerId, true)

    local player = Player:new(self)
    player:load(id)

    local msg = NetMsg:new()
    msg:setAction("user.entry")
    msg:setBody(player:getPlayerInfo())

    -- self._instance:sendMessageToChannel(Constant._CHANNEL_ALL_, msg:getString())
    self._broadcast:sendMessageToAll( msg:getString())
end

function Online:playerQuit(id)
    local playerId = id
    if not playerId then
        playerId = tonumber(self.curPlayId_)
    end
    self:setPlayerStatus(playerId, false)

    local msg = NetMsg:new()
    msg:setAction("user.bye")
    msg:setBody({id = playerId})

    -- self._instance:sendMessageToChannel(Constant._CHANNEL_ALL_, msg:getString())
    self._broadcast:sendMessageToAll( msg:getString())

    self:clearAttack(playerId)
end

function Online:playerMove(args)
    local msg = NetMsg:new()
    msg:setAction("play.move")
    msg:setBody(args)

    -- self._instance:sendMessageToChannel(Constant._CHANNEL_ALL_, msg:getString())
    self._broadcast:sendMessageToAll( msg:getString())
end

function Online:broadcast(action, args)
    local msg = NetMsg:new()
    msg:setAction(action)
    msg:setBody(args)
    self._broadcast:sendMessageToAll( msg:getString())
    -- self._instance:sendMessageToChannel(Constant._CHANNEL_ALL_, msg:getString())
end

function Online:broadcastNetMsg(action, netMsg)
    -- self._instance:sendMessageToChannel(Constant._CHANNEL_ALL_, netMsg:getString())
    self._broadcast:sendMessageToAll( netMsg:getString())
end

function Online:sendMsg(action, args)
    local msg = NetMsg:new()
    msg:setAction(action)
    msg:setBody(args)
    self:sendMessageToSelf(msg:getString())
end

function Online:sendMessageToSelf(msg)
    self._broadcast:sendMessage(self._instance:getConnectId(), msg)
end

function Online:subscribeChannel()
    self._instance:subscribe(Constant._CHANNEL_ALL_)
end

-- function Online:sendMessageToAll(event)
--     return self._broadcast:sendMessageToAll(event)
-- end

function Online:unsubscribeChannel()
    self._instance:unsubscribe(Constant._CHANNEL_ALL_)
end

function Online:schedule(action, data, delay)
    local instance = self._instance

    local delay = cc.checkint(delay)
    if delay <= 0 then
        delay = 1
    end
    

    -- send message to job
    local jobs = instance:getJobs()
    local job = {
        action = "/jobs/"..action,
        delay  = delay,
        data   = data,
    }
    local ok, err = jobs:add(job)
    if err then
        cc.printwarn("创建定时任务失败  %s",err)
    else
        cc.printf("创建定时任务成功 %s","/jobs/"..action )
    end
    -- local beans = BeansService.new(self._instance.config.beanstalkd)
    -- beans:connect()
    -- local job = JobService.new(self._redis, beans, self._instance.config)
    -- job:add(action, data, delay)
end
return Online
