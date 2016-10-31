
local Entity = cc.import(".Entity")
local NPC = cc.class("NPC", Entity)

function NPC:ctor(...)
	NPC.super.ctor(self, ...)

end

return NPC
