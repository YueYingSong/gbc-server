local network = cc.import("#network")
local NetMsgConstants = network.NetMsgConstants
local NetMsg = network.NetMsg
local gbc = cc.import("#gbc")
local PlayAction = cc.class("PlayAction",gbc.ActionBase)
PlayAction.ACCEPTED_REQUEST_TYPE = "websocket"

function PlayAction:moveAction(args)
	local msg = NetMsg.parser(args)
	local body = msg:getBody()
	local Online = self:getInstance():getOnline()
	local entity = Online:getEntity(body.id)
	entity:setPos(body.to)
	if entity.getPlayerInfo then
		-- entity is player instance
		entity:healthChange(1)
	end
	entity:save()

	Online:broadcast("play.move", body)
end

function PlayAction:attackAction(args)
	local msg = NetMsg.parser(args)
	local body = msg:getBody()
	local Online = self:getInstance():getOnline()
	local sender = Online:getEntity(body.sender)
	sender:save()
	local target = Online:getEntity(body.target)
	local reduceBoold = -5 -- (10 + math.random(1, 10))
	local afterboold = target:healthChange(reduceBoold)
	body.healthChange = reduceBoold
	body.dead = (afterboold <= 0)

	Online:broadcast("play.attack", body)
end

function PlayAction:attackmoveAction(args)
	local msg = NetMsg.parser(args)
	local body = msg:getBody()
	local Online = self:getInstance():getOnline()

	Online:broadcast("play.attackMove", body)
end

function PlayAction:chatAction(args)
	local msg = NetMsg.parser(args)
	local Online = self:getInstance():getOnline()
	Online:broadcastNetMsg("play.chat", msg)
end

return PlayAction
