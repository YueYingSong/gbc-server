
local Types = cc.import(".Types")
local Entity = cc.class("Entity")
local Orientation = cc.import(".Orientation")

for k,v in pairs(Types) do
	Entity[k] = v
end

function Entity:ctor(instance,attribute)
	-- cc.printf("新建一个敌人对象      ")
	local t = type(attribute)
	if "string" == t then
		self.attributes_ = json.decode(attribute)
	elseif "table" == t then
		self.attributes_ = attribute
	else
		self.attributes_ = {}
		self.attributes_.healthMax = 100
		self.attributes_.health = self.attributes_.healthMax
		self.attributes_.type = Types.TYPE_NONE
		self.attributes_.pos = cc.p(0, 0)
		self.attributes_.roamingArea = cc.rect(0, 0, 0, 0)
		self.attributes_.orientation = Orientation.DOWN
	end
	self._instance = instance
end

function Entity:getAttributeStr()
	return json.encode(self.attributes_)
end

function Entity:getAttribute()
	return self.attributes_
end

function Entity:save()
	local attr = self.attributes_
	local redis = self.redis_ or self._instance:getRedis()
	self.redis_ = redis
	-- cc.printInfo("Entity save orientation %s", tostring(attr.orientation))
	-- redis:initPipeline()
	-- cc.printf("储存数据   %d", attr.id)
	-- cc.dump(attr,"存数据")
	local succ = redis:hmset( attr.id,
		"posX", attr.pos.x or 0,
		"posY", attr.pos.y or 0,
		"health", attr.health,
		"healthMax", attr.healthMax,
		"type", attr.type or Types.TYPE_NONE,
		"roamingX", attr.roamingArea.x or 0,
		"roamingY", attr.roamingArea.y or 0,
		"roamingW", attr.roamingArea.width or 0,
		"roamingH", attr.roamingArea.height or 0,
		"orientation", attr.orientation or Orientation.DOWN)
	-- redis:commitPipeline()
	-- cc.printf("储存数据是否成功  %s", succ)
end

function Entity:load(entityId)
	local id = entityId or self.attributes_.id
	self.attributes_.id = tonumber(id)
	local redis = self.redis_ or self._instance:getRedis()
	self.redis_ = redis
	local vals,_error = redis:hmget( id, "posX", "posY", "health", "healthMax", "type", "roamingX", "roamingY", "roamingW", "roamingH", "orientation")
	if not vals then
		return false
	end
	-- cc.printf("读取的ID  %d %s", entityId,_error)
	-- cc.dump(vals,"读取到的数据")
	vals = self:transRedisNull(vals)
	local attr = self.attributes_
	-- cc.printf(tonumber(vals[1] or 0))
	-- cc.printf(tonumber(vals[2] or 0))
	attr.pos = cc.p(tonumber(vals[1] or 0), tonumber(vals[2] or 0))
	attr.health = tonumber(vals[3]) or attr.health
	attr.healthMax = tonumber(vals[4]) or attr.healthMax
	attr.type = tonumber(vals[5])
	attr.roamingArea = cc.rect(tonumber(vals[6] or 0), tonumber(vals[7] or 0), tonumber(vals[8] or 0), tonumber(vals[9] or 0))
	attr.orientation = tonumber(vals[10])
	if 0 == attr.orientation then
		attr.orientation = Orientation.DOWN
	end

	return true
end

function Entity:transRedisNull(val)
	local newV
	local types = type(val)

	local f = function(v)
		if "userdata: NULL" == tostring(v) then
			return nil
		else
			return v
		end
	end

	if "table" == types then
		for k,v in pairs(val) do
			val[k] = self:transRedisNull(v)
		end
		newV = val
	else
		newV = f(val)
	end

	return newV
end

function Entity:setRedis(redis)
	self.redis_ = redis
end

function Entity:getRedis()
	local redis = self.redis_ or self._instance:getRedis()
	self.redis_ = redis
	return redis
end

function Entity:setName(name)
	local t = "TYPE_" .. name
	t = string.upper(t)
	self:setType(Types[t])
end

function Entity:setOrientation(orientation)
	self.attributes_.orientation = orientation
end

function Entity:setType(type)
	self.attributes_.type = type
end

function Entity:getType()
	return self.attributes_.type
end

function Entity:setRoamingArea(rect)
	self.attributes_.roamingArea = rect
end

function Entity:getRoamingArea()
	return self.attributes_.roamingArea
end

function Entity:isNPC()
	return self.attributes_.type > Types.TYPE_NPCS_BEGIN and self.attributes_.type < Types.TYPE_NPCS_END
end

function Entity:isMob()
	return self.attributes_.type > Types.TYPE_MOBS_BEGIN and self.attributes_.type < Types.TYPE_MOBS_END
end

function Entity:setPos(p)
	self.attributes_.pos = p
end

function Entity:getPos()
	return self.attributes_.pos
end

function Entity:setRandomPos()
	local rect = self.attributes_.roamingArea
	self.attributes_.pos = cc.p(math.random(rect.x, rect.x + rect.width), math.random(rect.y, rect.y + rect.height))
end

function Entity:setId(id)
	self.attributes_.id = id
end

function Entity:getId()
	return self.attributes_.id
end

function Entity:setAttack(id)
	if 0 == id then
		self._instance:removeAttackEntity(self.attributes_.id)
	else
		self._instance:addAttackEntity(self.attributes_.id)
	end
	self:getRedis():hmset( self.attributes_.id, "attack", id or 0)
end

function Entity:getAttack()
	local vals = self:getRedis():hmset( self.attributes_.id, "attack")
	return tonumber(vals and vals[1]) or 0
end

function Entity:setMaxHealth(max)
	self.attributes_.healthMax = max
end

function Entity:setHealth(health)
	self.attributes_.health = health
end

function Entity:resetHealth()
	self.attributes_.health = self.attributes_.healthMax
end

function Entity:healthChange(val)
	local redis = self.redis_ or self._instance:getRedis()
	self.redis_ = redis
	self.attributes_.health = redis:hget( self.attributes_.id, "health")
	-- cc.printf("扣血之前   %d %d", self.attributes_.health,self.attributes_.id)
	self.attributes_.health = self.attributes_.health + val
	if self.attributes_.health > self.attributes_.healthMax then
		self.attributes_.health = self.attributes_.healthMax
	end

	-- redis:initPipeline()

	redis:hset( self.attributes_.id, "health", self.attributes_.health)
	-- cc.printf("扣血之后   %d  %d", self.attributes_.health,self.attributes_.id)
	self:save();
	-- redis:commitPipeline()
	return self.attributes_.health
end

function Entity:getInfo()
	local attr = self.attributes_
	local entityInfo = {}
	entityInfo.imageName = attr.armor
	entityInfo.pos = attr.pos
	entityInfo.id = attr.id
	entityInfo.type = attr.type
	entityInfo.orientation = attr.orientation

	return entityInfo
end

function Entity:reborn()
	self:setRandomPos()
	self.attributes_.health = self.attributes_.healthMax

	self:save()

	-- self._instance:broadcast("mob.reborn", self:getInfo())
end

function Entity:isDead()
	return self.attributes_.health < 1
end

return Entity
