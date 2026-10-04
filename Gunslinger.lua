local tool = script.Parent
local handle = tool:WaitForChild("Handle")
local character = tool.Parent
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")

local animTrack

local function playAnimation()
	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://130629452406128"
	
	animTrack = animator:LoadAnimation(animation)
	animTrack:Play(0.1, 1, 1)
end

local function spinTool()
	local startCFrame = handle.CFrame
	local spinDuration = 1.5 -- Adjust based on animation length
	local startTime = tick()
	
	while tool.Parent and (tick() - startTime) < spinDuration do
		local elapsed = tick() - startTime
		local progress = elapsed / spinDuration
		local rotation = math.rad(520 * progress)
		
		handle.CFrame = startCFrame * CFrame.Angles(0, rotation, 0)
		game:GetService("RunService").RenderStepped:Wait()
	end
	
	-- Reset to original orientation
	handle.CFrame = startCFrame * CFrame.Angles(0, math.rad(520), 0)
end

tool.Equipped:Connect(function()
	playAnimation()
	spinTool()
end)

tool.Unequipped:Connect(function()
	if animTrack then
		animTrack:Stop()
	end
end)
