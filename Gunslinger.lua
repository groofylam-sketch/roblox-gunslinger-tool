local Tool = script.Parent
local Player = game.Players.LocalPlayer
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Animation IDs
local IDLE_ANIM_ID = "rbxassetid://76826613726855"
local RIGHTCLICK_IDLE_ANIM_ID = "rbxassetid://110112280629975"
local DASH_ANIM_ID = "rbxassetid://122404569675475"
local WALK_ANIM_ID = "rbxassetid://117416026654079"
local KILL_ANIM_ID = "rbxassetid://110846524507230"
local SHOOT_ANIM_ID = "rbxassetid://126324501020348"
local RELOAD_ANIM_ID = "rbxassetid://79479628347707"
local EQUIP_SPIN_ANIM_ID = "rbxassetid://130629452406128"

-- State
local isEquipped = false
local isDashing = false
local isKillAnimPlaying = false
local isRightClickHeld = false
local canShoot = true
local isReloading = false
local ammo = 12
local maxAmmo = 12
local currentTrack = nil
local normalWalkSpeed = 14
local isPlayingEquipSpin = false

-- References (updated on equip)
local Character, Humanoid, HumanoidRootPart, Handle

local function loadAnim(id)
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	return anim
end

local idleAnim = loadAnim(IDLE_ANIM_ID)
local rcIdleAnim = loadAnim(RIGHTCLICK_IDLE_ANIM_ID)
local dashAnim = loadAnim(DASH_ANIM_ID)
local walkAnim = loadAnim(WALK_ANIM_ID)
local killAnim = loadAnim(KILL_ANIM_ID)
local shootAnim = loadAnim(SHOOT_ANIM_ID)
local reloadAnim = loadAnim(RELOAD_ANIM_ID)
local equipSpinAnim = loadAnim(EQUIP_SPIN_ANIM_ID)

local ourAnimIds = {
	[IDLE_ANIM_ID] = true,
	[RIGHTCLICK_IDLE_ANIM_ID] = true,
	[DASH_ANIM_ID] = true,
	[WALK_ANIM_ID] = true,
	[KILL_ANIM_ID] = true,
	[SHOOT_ANIM_ID] = true,
	[RELOAD_ANIM_ID] = true,
	[EQUIP_SPIN_ANIM_ID] = true,
}

local animBlockConnection = nil

local function playLoopedAnim(animObj)
	if isPlayingEquipSpin then return end
	if currentTrack then
		currentTrack:Stop()
	end
	local track = Humanoid:LoadAnimation(animObj)
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Action4
	track:Play()
	currentTrack = track
end

local function playOnceAnim(animObj)
	if isPlayingEquipSpin then return end
	if currentTrack then
		currentTrack:Stop()
	end
	local track = Humanoid:LoadAnimation(animObj)
	track.Looped = false
	track.Priority = Enum.AnimationPriority.Action4
	track:Play()
	currentTrack = track
	return track
end

local function stopAnim()
	if currentTrack then
		currentTrack:Stop()
		currentTrack = nil
	end
end

local function stopAllAnims()
	stopAnim()
end

local function isMoving()
	return Humanoid and Humanoid.MoveDirection.Magnitude > 0.1
end

local function updateIdleAnim()
	if isPlayingEquipSpin or isDashing or isKillAnimPlaying or isReloading or not isEquipped then return end
	if isMoving() then
		playLoopedAnim(walkAnim)
	elseif isRightClickHeld then
		playLoopedAnim(rcIdleAnim)
	else
		playLoopedAnim(idleAnim)
	end
end

local function spinToolOnEquip()
	if not Handle then return end

	isPlayingEquipSpin = true

	local startCFrame = Handle.CFrame
	local startTime = tick()
	local duration = 0.9

	-- Find and disable the weld between handle and hand
	local weld = Handle:FindFirstChildOfClass("Weld") or Handle:FindFirstChildOfClass("Motor6D")
	local weldDisabled = false
	if weld then
		weld.Enabled = false
		weldDisabled = true
	end

	local animTrack = Humanoid:LoadAnimation(equipSpinAnim)
	animTrack.Looped = false
	animTrack.Priority = Enum.AnimationPriority.Action4
	animTrack:Play()

	local spinConnection
	spinConnection = RunService.RenderStepped:Connect(function()
		if not isPlayingEquipSpin or not Handle or not Handle.Parent then
			spinConnection:Disconnect()
			-- Re-enable weld
			if weldDisabled and weld then
				weld.Enabled = true
			end
			return
		end

		local elapsed = tick() - startTime
		if elapsed >= duration then
			spinConnection:Disconnect()
			isPlayingEquipSpin = false
			Handle.CFrame = startCFrame * CFrame.Angles(0, math.rad(520), 0)
			-- Re-enable weld
			if weldDisabled and weld then
				weld.Enabled = true
			end
			updateIdleAnim()
			return
		end

		local t = elapsed / duration
		local angle = math.rad(520 * t)
		Handle.CFrame = startCFrame * CFrame.Angles(0, angle, 0)
	end)
end

local dashBodyVelocity = nil
local dashConnections = {}

local function endDash()
	if not isDashing then return end
	isDashing = false

	for _, conn in dashConnections do
		conn:Disconnect()
	end
	table.clear(dashConnections)

	if dashBodyVelocity then
		dashBodyVelocity:Destroy()
		dashBodyVelocity = nil
	end

	if Humanoid then
		Humanoid.WalkSpeed = normalWalkSpeed
	end

	local dashEvent = Tool:FindFirstChild("DashEvent")
	if dashEvent then
		dashEvent:FireServer(false)
	end

	updateIdleAnim()
end

local function startDash()
	if isDashing or isKillAnimPlaying or isReloading or isPlayingEquipSpin or not isEquipped then return end
	if not HumanoidRootPart or not Humanoid then return end

	isDashing = true

	local dashEvent = Tool:FindFirstChild("DashEvent")
	if dashEvent then
		dashEvent:FireServer(true)
	end

	playLoopedAnim(dashAnim)
	Humanoid.WalkSpeed = normalWalkSpeed * 2

	dashBodyVelocity = Instance.new("BodyVelocity")
	dashBodyVelocity.MaxForce = Vector3.new(math.huge, 0, math.huge)
	dashBodyVelocity.Velocity = HumanoidRootPart.CFrame.LookVector * normalWalkSpeed * 2
	dashBodyVelocity.Parent = HumanoidRootPart

	local startTime = tick()

	local hb = RunService.Heartbeat:Connect(function()
		if not isDashing then return end

		dashBodyVelocity.Velocity = HumanoidRootPart.CFrame.LookVector * normalWalkSpeed * 2

		if tick() - startTime >= 1 then
			endDash()
			return
		end
	end)
	table.insert(dashConnections, hb)
end

local killEvent = Tool:WaitForChild("KillEvent")
killEvent.OnClientEvent:Connect(function()
	if not Humanoid then return end

	if isDashing then
		endDash()
	end

	isKillAnimPlaying = true
	Humanoid.WalkSpeed = 0

	local freezeVelocity = Instance.new("BodyVelocity")
	freezeVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	freezeVelocity.Velocity = Vector3.new(0, 0, 0)
	freezeVelocity.Parent = HumanoidRootPart

	local track = playOnceAnim(killAnim)

	track.Stopped:Connect(function()
		isKillAnimPlaying = false
		if freezeVelocity then
			freezeVelocity:Destroy()
		end
		if Humanoid then
			Humanoid.WalkSpeed = normalWalkSpeed
		end
		updateIdleAnim()
	end)
end)

local function startReload()
	if isReloading or isPlayingEquipSpin or not isEquipped then return end
	if not Humanoid then return end
	if ammo >= maxAmmo then return end

	isReloading = true
	canShoot = false

	local track = playOnceAnim(reloadAnim)

	track.Stopped:Connect(function()
		isReloading = false
		ammo = maxAmmo
		canShoot = true
		updateIdleAnim()
	end)
end

UIS.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if not isEquipped or isPlayingEquipSpin then return end

	if input.KeyCode == Enum.KeyCode.C then
		startDash()
	elseif input.KeyCode == Enum.KeyCode.R then
		startReload()
	end
end)

Tool.Equipped:Connect(function(mouse)
	isEquipped = true
	Character = Player.Character or Player.CharacterAdded:Wait()
	Humanoid = Character:WaitForChild("Humanoid")
	HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
	Handle = Tool:WaitForChild("Handle")

	spinToolOnEquip()

	if animBlockConnection then animBlockConnection:Disconnect() end
	animBlockConnection = Humanoid.AnimationPlayed:Connect(function(track)
		if track.Animation and not ourAnimIds[track.Animation.AnimationId] then
			track:Stop()
		end
	end)

	if mouse then
		mouse.Button2Down:Connect(function()
			if not isEquipped or not Humanoid or isPlayingEquipSpin then return end
			isRightClickHeld = true
			updateIdleAnim()
		end)

		mouse.Button2Up:Connect(function()
			if not isEquipped then return end
			isRightClickHeld = false
			updateIdleAnim()
		end)

		mouse.Button1Down:Connect(function()
			if not isEquipped or not Humanoid or isPlayingEquipSpin then return end
			if not isRightClickHeld then return end
			if not canShoot then return end
			if isMoving() then return end
			if isReloading then return end
			if ammo <= 0 then return end

			canShoot = false
			ammo = ammo - 1

			local shootTrack = playOnceAnim(shootAnim)
			shootTrack.Stopped:Connect(function()
				if not isReloading and isEquipped then
					updateIdleAnim()
				end
			end)

			local shootEvent = Tool:FindFirstChild("ShootEvent")
			if shootEvent then
				shootEvent:FireServer(mouse.Hit.p)
			end

			if ammo <= 0 then
				-- out of ammo
			else
				task.delay(0.2, function()
					canShoot = true
				end)
			end
		end)
	end

	Humanoid.Running:Connect(function(speed)
		if not isDashing and not isKillAnimPlaying and not isPlayingEquipSpin then
			updateIdleAnim()
		end
	end)

	updateIdleAnim()
end)

Tool.Unequipped:Connect(function()
	if isReloading then
		if Character and Humanoid then
			Humanoid:EquipTool(Tool)
		end
		return
	end
	isEquipped = false
	isRightClickHeld = false
	if isDashing then
		endDash()
	end
	stopAllAnims()
	if animBlockConnection then
		animBlockConnection:Disconnect()
		animBlockConnection = nil
	end
	Humanoid = nil
	HumanoidRootPart = nil
	Character = nil
	Handle = nil
end)
