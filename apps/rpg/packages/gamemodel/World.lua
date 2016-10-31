local network 	= cc.import("#network")
local NetMsg 	= network.NetMsg
local Map 		= cc.import(".Map")
local Entity 	= cc.import(".Entity")
local Player 	= cc.import(".Player")
local gbc 		= cc.import("#gbc")
local World 	= cc.class("World")

local Constant 	= cc.import(".Constant")

function World:ctor(instance)
	self._instance  = instance
    self._redis     = instance:getRedis()
    self._broadcast = gbc.Broadcast:new(self._redis, instance.config.app.websocketMessageFormat)


    self.player_ = {}
    self.attackIds_ = {}
end


function World:setMapPath(path)
	self.mapPath_ = path
end

function World:clearRedis()
	local redis = self._redis
	redis:command("SET", Constant._MAP_LOAD_, "no")
end

function World:initMapIf()
	local redis = self._redis
	-- redis:command("SET", Constant._MAP_LOAD_, "no")
	local isLoaded = redis:command("GET", Constant._MAP_LOAD_)
	local entitys = {}
	if not isLoaded or "no" == isLoaded then
		local map = Map:new(self.mapPath_)

		-- generate static entity
		local staticEntity = map:getStaticEntity()
		local idCounter = 1001

		for idx, name in pairs(staticEntity) do
			local p = map:getPosByTileIdx(idx)
			local entity = Entity:new()
			entity:setPos(p)
			entity:setRoamingArea(cc.rect(p.x, p.y, 1, 1))
			entity:setRedis(redis)
			entity:setId(idCounter)
			entity:setHealth(100)
			entity:setName(name)
			idCounter = idCounter + 1

			entity:save()
			entitys[#entitys + 1] = entity

			redis:command("SADD", Constant.__redisKEY_SETS_ENTITY_STATIC_, entity:getId())
		end

		-- generate roaming mobs
		-- local roamingArea = map:getRoamingArea()
		-- for i,area in ipairs(roamingArea) do
		-- 	local rect = cc.rect(area.x, area.y, area.width, area.height)
		-- 	for i=1, area.nb do
		-- 		local entity = Entity:new()
		-- 		entity:setRoamingArea(rect)
		-- 		entity:setRandomPos()
		-- 		entity:setRedis(redis)
		-- 		entity:setId(idCounter)
		-- 		entity:setHealth(100)
		-- 		entity:setName(area.type)

		-- 		idCounter = idCounter + 1

		-- 		entity:save()
		-- 		entitys[#entitys + 1] = entity

		-- 		redis:command("SADD", Constant.__redisKEY_SETS_ENTITY_STATIC_, entity:getId())
		-- 	end
		-- end

		-- launch game loop timer
		self:schedule("schedule.loop", self._instance.config, 1)

		redis:command("SET", Constant._MAP_LOAD_, "yes")
	else
		local ids = redis:command("SMEMBERS", Constant.__redisKEY_SETS_ENTITY_STATIC_)
		for i,id in ipairs(ids) do
			local entity = Entity:new()
			entity:setRedis(redis)
			entity:load(id)

			entitys[#entitys + 1] = entity
		end
	end
	self.entitysStatic_ = entitys
end

function World:getRedis()
	return self._redis
end

function World:getEntitysStaticInfo()
	local entitys = self.entitysStatic_

	local infos = {}
	for i,info in ipairs(entitys) do
		table.insert(infos, info:getAttribute())
	end

	return infos
end

function World:getEntityById(id)
	local entity = Entity:new()
	entity:load(id)

	return entity
end

function World:getRebornPos()
	return cc.p(math.random(32, 43), math.random(224, 232))
end

function World:getPlayerInfo(name, id)
	local entity = Player:new()
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
		idCounter = self._redis:command("INCR", Constant.__redisKEY_ID_COUNTER_)
		if 1 == idCounter then
			self._redis:command("SET", Constant.__redisKEY_ID_COUNTER_, Constant.IDCounterBegin)
			idCounter = Constant.IDCounterBegin
		end
	end
	playerInfo.id = idCounter

	return playerInfo
end

function World:getPlayerEntity(name, id)
	local entity
	local attr
	if string.len(name) > 10 then
		name = string.sub(name, 1, 10)
	end
	if id then
		entity = Player:new()
		if not entity:load(id) then
			entity = self:newPlayer()
		end
	else
		entity = self:newPlayer()
	end
	entity:setNickName(name)
	entity:save()

	return entity
end

function World:newPlayer()
	local entity = Player:new()
	entity:setArmor("clotharmor.png")
	entity:setWeapon("sword1.png")
	math.randomseed(os.time())
	entity:setPos(cc.p(math.random(35, 45), math.random(223, 234)))

	local idCounter
	idCounter = self._redis:command("INCR", Constant.__redisKEY_ID_COUNTER_)
	if 1 == idCounter then
		self._redis:command("SET", Constant.__redisKEY_ID_COUNTER_, Constant.IDCounterBegin)
		idCounter = Constant.IDCounterBegin
	end
	entity:setId(idCounter)

	return entity
end

function World:newPlayerEntity(playerInfo)
	local entity = Player:new()
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

function World:getPlayerById(id)
	local player = Player:new()
	player:load(id)

	return player
end

function World:getEntity(id)
	local cls
	if id >= Constant.IDCounterBegin then
		cls = Player
	else
		cls = Entity
	end

	local entity = cls:new()
	entity:load(id)

	return entity
end

function World:setPlayerStatus(id, isOnline)
	if isOnline then
		self._redis:command("SADD", Constant.__redisKEY_SETS_PLAYER_, id)
	else
		self._redis:command("SREM", Constant.__redisKEY_SETS_PLAYER_, id)
	end
end

function World:getOnlinePlayer()
	local players = self._redis:command("SMEMBERS", Constant.__redisKEY_SETS_PLAYER_)
	if not players then
		return
	end

	local playerInfos = {}
	local player = Player:new()
	for i,v in ipairs(players) do
		player:load(v)
		table.insert(playerInfos, player:getPlayerInfo())
	end

	return playerInfos
end

function World:addAttackEntity(id)
	table.insert(self.attackIds_, id)
end

function World:removeAttackEntity(id)
	local pos
	for i,v in ipairs(self.attackIds_) do
		if v == id then
			pos = i
			break
		end
	end
	table.remove(self.attackIds_, pos)
end

function World:clearAttack(playerId)
	for i,v in ipairs(self.attackIds_) do
		local entity = self:getEntity(v)
		if playerId == entity:getAttack() then
			entity:setAttack(0)
		end
	end
	self.attackIds_ = {}
end



function World:playerEntry(id)
	local playerId = id
	if not playerId then
		return
	end
	self.curPlayId_ = playerId
	self:setPlayerStatus(playerId, true)

	local player = Player:new()
	player:load(id)

	local msg = NetMsg:new()
	msg:setAction("user.entry")
	msg:setBody(player:getPlayerInfo())

	-- self._instance:sendMessageToChannel(Constant._CHANNEL_ALL_, msg:getString())
	self._broadcast:sendMessageToAll( msg:getString())
end

function World:playerQuit(id)
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

function World:playerMove(args)
	local msg = NetMsg:new()
	msg:setAction("play.move")
	msg:setBody(args)

	-- self._instance:sendMessageToChannel(Constant._CHANNEL_ALL_, msg:getString())
	self._broadcast:sendMessageToAll( msg:getString())
end

function World:broadcast(action, args)
	local msg = NetMsg:new()
	msg:setAction(action)
	msg:setBody(args)
	self._broadcast:sendMessageToAll( msg:getString())
	-- self._instance:sendMessageToChannel(Constant._CHANNEL_ALL_, msg:getString())
end

function World:broadcastNetMsg(action, netMsg)
	-- self._instance:sendMessageToChannel(Constant._CHANNEL_ALL_, netMsg:getString())
	self._broadcast:sendMessageToAll( netMsg:getString())
end

function World:sendMsg(action, args)
	local msg = NetMsg:new()
	msg:setAction(action)
	msg:setBody(args)
	self._instance:sendMessageToSelf(msg:getString())
end


function World:subscribeChannel()
    self._instance:subscribe(Constant._CHANNEL_ALL_, function(msg)
        self._instance:sendMessageToSelf(msg)
        return true
    end)
end

function World:sendMessageToAll(event)
    return self._broadcast:sendMessageToAll(event)
end

function World:unsubscribeChannel()
    -- self._instance:unsubscribe(Constant._CHANNEL_ALL_)
end

function World:schedule(action, data, delay)
	-- local beans = BeansService.new(self._instance.config.beanstalkd)
	-- beans:connect()
	-- local job = JobService.new(self._redis, beans, self._instance.config)
	-- job:add(action, data, delay)
end


return World
