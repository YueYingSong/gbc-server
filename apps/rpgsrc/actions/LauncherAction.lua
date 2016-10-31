
local Launcher = class("Launcher")
local Session = cc.import("#session")


function Launcher:getsessionidAction(args)
	if not args.appName or "BrowerQuestLua" ~= args.appName then
		throw("invalid launcher command")
	end

    local session = Session:new(self:getInstance():getRedis())
    session:start()

    return {sid = session:getSid()}
end

return Launcher
