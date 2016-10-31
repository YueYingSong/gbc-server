--
-- Author: By.Yue
-- Date: 2016-10-20 10:06:39
--
cc.import("cocos.functions")
local gbc = cc.import("#gbc")
local JobsAction = cc.class("JobsAction", gbc.ActionBase)

JobsAction.ACCEPTED_REQUEST_TYPE = "worker"
local network = cc.import("#network")
local NetMsg = network.NetMsg

local gamemodel = cc.import("#gamemodel")
local Entity = gamemodel.Entity
local Constant = gamemodel.Constant
local Online = gamemodel.Online


function JobsAction:loopAction(args)
	self.config_ = args or self.config_
	assert("table" == type(self.config_))

	local redis = self:getInstance():getRedis()
	local ids = redis:smembers( Constant._REDIS_KEY_SETS_PLAYER_)
	for i, id in ipairs(ids) do
		local vals = redis:hmget( id, "health", "healthMax")
		if "table" == type(vals) and 2 == #vals then
			if vals[1] < vals[2] then
				redis:hincrby( id, "health", 1)
				local msg = NetMsg:new()
				msg:setAction("user.info")
				msg:setBody({id = id, healthPercent = vals[1]/vals[2]})
				redis:publish(Constant._CHANNEL_ALL_, msg:getString())
			end
		end
	end
	-- cc.printf("online  ---------------------")
	-- cc.printf(online)
	self:schedule("jobs.loop", nil, 1)

	-- self:closeRedis_()
end

function JobsAction:rebornAction(args)
	assert("table" == type(args)  and args.data and args.data.id)
	local entityId = args.data.id
	
	local online = Online:new(self:getInstance())
	local redis = self:getInstance():getRedis()
	local vals,_error = online:getRedis():hmget( entityId, "posX", "posY", "health", "healthMax", "type", "roamingX", "roamingY", "roamingW", "roamingH", "orientation")
	
	
	local entity = Entity:new(online)
	
	entity:setRedis(redis)
	entity:load(entityId)
	entity:reborn()

	local msg = NetMsg:new()
	msg:setAction("mob.reborn")
	msg:setBody(entity:getInfo())

	
	redis:publish(Constant._CHANNEL_ALL_, msg:getString())
	
end
function JobsAction:schedule(action, data, delay)
    local instance = self:getInstance()

    local delay = cc.checkint(delay)
    if delay <= 0 then
        delay = 1
    end
    

    -- send message to job
    local jobs = instance:getJobs()
    local job = {
        action = action,
        delay  = delay,
        data   = data,
    }
    local ok, err = jobs:add(job)
    if err then
        cc.printwarn("创建定时任务失败  %s",err)
    end
end


return JobsAction