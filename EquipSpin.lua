local tool = script.Parent
local handle = tool:WaitForChild("Handle")

local function spinOnEquip()
	local startCFrame = handle.CFrame
	local startTime = tick()
	local duration = 0.5

	local spinConnection
	spinConnection = game:GetService("RunService").RenderStepped:Connect(function()
		local elapsed = tick() - startTime
		if elapsed >= duration then
			spinConnection:Disconnect()
			handle.CFrame = startCFrame * CFrame.Angles(0, math.rad(520), 0)
			return
		end

		local t = elapsed / duration
		local angle = math.rad(520 * t)
		handle.CFrame = startCFrame * CFrame.Angles(0, angle, 0)
	end)
end

tool.Equipped:Connect(function()
	spinOnEquip()
end)
