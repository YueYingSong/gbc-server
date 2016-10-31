local network = cc.import("#network")
local gbc = cc.import("#gbc")
local UserAction = cc.class("UserAction",gbc.ActionBase)
local NetMsgConstants = network.NetMsgConstants
local NetMsg = network.NetMsg
UserAction.ACCEPTED_REQUEST_TYPE = "websocket"

function UserAction:welcomeAction(args)
	-- cc.printInfo("User welcome entity")
	local msg = NetMsg.parser(args)
	local playerInfo = msg:getBody()
	msg:setBody(nil)

	if not playerInfo.nickName or 0 == string.len(playerInfo.nickName) then
		msg:setError(NetMsgConstants.ERROR_NICKNAME_NULL)
		return msg:getData()
	end

	-- start session
    local session = self:getInstance():getSession()
    -- session:start()
    local username = playerInfo.nickName
    session:set("username",username)
    session:set("count", 0)
    session:save()
    
	local Online = self:getInstance():getOnline()
	-- instance:add()
	-- Online:add(username, self:getInstance():getConnectId())

	local onLinePlayers = Online:getOnlinePlayer()

	local player = Online:getPlayerEntity(playerInfo.nickName, playerInfo.id)
	player:resetHealth()
	player:save()

	playerInfo = player:getPlayerInfo()

	local body = {}
	body.playerInfo = playerInfo
	body.entitysStatic = Online:getEntitysStaticInfo()
	body.onlinePlayers = onLinePlayers

	msg:setBody(body)

	-- cc.printf("发送给客户端    ------%s",msg:getString())
	Online:sendMessageToSelf(msg:getString())
	Online:playerEntry(playerInfo.id)
	-- return {msg:getString()}
	-- return {msg:getString()}
	-- cc.printInfo("User welcome exit")
end

function UserAction:rebornAction(args)
	local msg = NetMsg.parser(args)
	local playerInfo = msg:getBody()
	msg:setBody(nil)

	if not playerInfo.id or 0 == playerInfo.id then
		msg:setError(NetMsgConstants.ERROR_NICKNAME_NULL)
		return msg:getData()
	end
	local instance = self:getInstance():getOnline()
	local player = instance:getPlayerById(playerInfo.id)
	local pos = instance:getRebornPos()
	player:setPos(pos)
	player:resetHealth()
	player:save()

	instance:sendMsg("user.reborn", player:getPlayerInfo())
	instance:playerEntry(playerInfo.id)

	-- msg:setBody(player:getPlayerInfo())
	-- return msg:getData()
end

function UserAction:infoAction(args)
	local msg = NetMsg.parser(args)
	local body = msg:getBody()
	local instance = self:getInstance():getOnline()
	local entity = instance:getEntity(body.id)
	if not entity then
		return
	end
	if body.pos then
		entity:setPos(body.pos)
	end
	if body.orientation then
		entity:setOrientation(body.orientation)
	end
	entity:save()
end

function UserAction:moveAction(args)
	local msg = NetMsg.parser(args)
	local body = msg:getBody()
	-- cc.dump(body,"玩信息")
	local instance = self:getInstance():getOnline()
	local entity = instance:getEntity(body.id)
	entity:setPos(body.to)
	-- cc.dump(body.to,"move")
	entity:save()

	instance:broadcast("user.move", body)
end

function UserAction:attackAction(args)
	local msg = NetMsg.parser(args)
	local body = msg:getBody()
	local instance = self:getInstance():getOnline()
	local sender = instance:getEntity(body.sender)
	local target = instance:getEntity(body.target)
	if target:isDead() then
		return
	end

	local reduceBoold = -(50 + math.random(1, 10))
	local afterboold = target:healthChange(reduceBoold)
	body.healthChange = reduceBoold
	body.dead = (afterboold <= 0)

	instance:broadcast("user.attack", body)
	-- cc.printf("是否死亡  %s",tostring( body.dead))
	if body.dead then
		if target:isMob() then
			instance:broadcast("mob.dead", {id = body.target})
			instance:removeEntity(body.target)
			target:setAttack(0)
			-- target:reborn()
			-- cc.printf("怪物死了  3s后复活")
			cc.printf(online)

			instance:schedule("jobs.reborn", {id = body.target}, 10)
		else
			sender:setAttack(0)
			instance:broadcast("user.dead", {id = body.target})
		end
	else
		if target:isMob() then
			local attackId = target:getAttack()
			-- cc.printInfo("User:attack id %d", attackId)
			if 0 == attackId then
				target:setAttack(body.sender)
				instance:sendMsg("mob.attack", {sender = body.target, target = body.sender})
			end
		end
	end
end

function UserAction:cancelattackAction(args)
	local msg = NetMsg.parser(args)
	local body = msg:getBody()
	local instance = self:getInstance():getOnline()
	local sender = instance:getEntity(body.sender)
	local target = instance:getEntity(body.target)
	if target:isMob() then
		target:setAttack(0)
	end
end

return UserAction
