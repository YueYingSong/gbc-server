--
-- Author: By.Yue
-- Date: 2016-10-14 11:23:37
--
local gbc 				= cc.import("#gbc")
local LauncherAction 	= cc.class("LauncherAction", gbc.ActionBase)
local Session 			= cc.import("#session")


function LauncherAction:getsessionidAction(args)
	local appName = args.appName
    if not appName then
        cc.throw("not set argsument: \"appName\"")
    end

    -- start session
    local session = Session:new(self:getInstance():getRedis())
    session:start()
    session:set("appName", appName)
    session:set("count", 0)
    session:save()

    -- return result
    return {sid = session:getSid(), count = 0}
end

return LauncherAction