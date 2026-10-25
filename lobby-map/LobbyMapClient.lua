-- LobbyMapClient (LocalScript)
-- Put this in StarterPlayer > StarterPlayerScripts.
--
-- Makes the lobby from "LobbyMapServer" come alive on your screen: bobbing
-- and spinning brick icons, the spin wheel, bats circling overhead, chasing
-- string lights, flickering lamps, pulsing seat lights, trampolines, confetti
-- when someone gets a reward, and a red flash when something isn't ready yet.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local lobby = Workspace:WaitForChild("Lobby")
local remote = ReplicatedStorage:WaitForChild("LobbyEvent")

local BOUNCE = 95 -- trampoline launch speed
local RED = Color3.fromRGB(255, 60, 60)

task.wait(2) -- let the lobby finish arriving

---------------------------------------------------------------- collect what to animate

local icons = {} -- { parts, offsets, base, phase }
local wheel -- { parts, offsets, center, angle, spin }
local bulbs, lamps, seatLights, rims, trampolines = {}, {}, {}, {}, {}

local function captureModel(model, pivot)
	local parts, offsets = {}, {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(parts, part)
			table.insert(offsets, pivot:ToObjectSpace(part.CFrame))
		end
	end
	return parts, offsets
end

for _, item in lobby:GetDescendants() do
	if item:IsA("Model") and item.Name:sub(-4) == "Icon" then
		local pivot = item:GetPivot()
		local parts, offsets = captureModel(item, pivot)
		table.insert(icons, { parts = parts, offsets = offsets, base = pivot, phase = math.random() * 10 })
	elseif item:IsA("Model") and item.Name == "SpinWheel" then
		local center = item:GetAttribute("Center")
		if center then
			local parts, offsets = captureModel(item, center)
			wheel = { parts = parts, offsets = offsets, center = center, angle = 0, speed = 0.4 }
		end
	elseif item:IsA("BasePart") then
		if item.Name == "Bulb" then
			table.insert(bulbs, { part = item, color = item.Color })
		elseif item.Name == "Lamp" then
			local light = item:FindFirstChildWhichIsA("PointLight")
			table.insert(lamps, { part = item, light = light, brightness = light and light.Brightness or 1, phase = math.random() * 50 })
		elseif item.Name == "SeatLight" then
			table.insert(seatLights, item)
		elseif item.Name == "Rim" then
			table.insert(rims, item)
		elseif item.Name == "Trampoline" then
			table.insert(trampolines, item)
		end
	end
end

local moveParts, moveFrames = {}, {}
local function move(part, cframe)
	local n = #moveParts + 1
	moveParts[n] = part
	moveFrames[n] = cframe
end

---------------------------------------------------------------- bats

local bats = {}
local batFolder = Instance.new("Folder")
batFolder.Name = "LobbyBats"
batFolder.Parent = Workspace

local function batPart(name, size)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = Color3.fromRGB(34, 26, 44)
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Studs
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = batFolder
	return part
end

do
	local deck = lobby:FindFirstChild("Deck")
	local base = deck and deck:FindFirstChild("DeckBase")
	local center = base and (base.Position + Vector3.new(0, base.Size.Y / 2 + 26, 0)) or Vector3.new(0, 34, 0)
	for i = 1, 8 do
		local eyes = batPart("BatEyes", Vector3.new(0.9, 0.2, 0.2))
		eyes.Color = RED
		eyes.Material = Enum.Material.Neon
		table.insert(bats, {
			body = batPart("BatBody", Vector3.new(1, 1, 1.4)),
			left = batPart("BatWing", Vector3.new(2.2, 0.2, 1.2)),
			right = batPart("BatWing", Vector3.new(2.2, 0.2, 1.2)),
			eyes = eyes,
			center = center + Vector3.new(math.random(-40, 40), math.random(-6, 10), math.random(-40, 40)),
			radius = math.random(10, 26),
			speed = (math.random() < 0.5 and -1 or 1) * (0.4 + math.random() * 0.4),
			phase = i * 0.8,
		})
	end
end

---------------------------------------------------------------- confetti and flashes

local confetti = Instance.new("ParticleEmitter")
confetti.Enabled = false
confetti.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 60)),
	ColorSequenceKeypoint.new(0.66, Color3.fromRGB(90, 220, 90)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 160, 255)),
})
confetti.Size = NumberSequence.new(0.4, 0.3)
confetti.Lifetime = NumberRange.new(1.2, 2)
confetti.Speed = NumberRange.new(14, 22)
confetti.SpreadAngle = Vector2.new(40, 40)
confetti.Acceleration = Vector3.new(0, -30, 0)
confetti.Rotation = NumberRange.new(0, 360)
confetti.RotSpeed = NumberRange.new(-300, 300)
confetti.LightEmission = 0.4
local confettiPoint = Instance.new("Attachment")
confettiPoint.Name = "Confetti"
confettiPoint.Parent = Workspace.Terrain
confetti.Parent = confettiPoint

local function burst(position)
	confettiPoint.WorldPosition = position
	confetti:Emit(60)
end

local flashes = {} -- [part] = { until, color }
local function flash(model)
	if not model then
		return
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			flashes[part] = { untilTime = os.clock() + 0.6, color = flashes[part] and flashes[part].color or part.Color }
		end
	end
end

---------------------------------------------------------------- server events

local spinTarget -- { from, to, start, duration }

remote.OnClientEvent:Connect(function(action, data)
	if action == "Spin" and wheel and typeof(data) == "number" then
		-- Slice i points straight up (at the pointer) when the wheel's angle is 270 - 45 * i degrees.
		local target = math.rad(270 - 45 * data)
		local turns = math.pi * 2
		local final = wheel.angle + turns * 4 + ((target - wheel.angle) % turns)
		spinTarget = { from = wheel.angle, to = final, start = os.clock(), duration = 3.4 }
	elseif action == "Reward" and typeof(data) == "Instance" then
		local character = data.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			burst(root.Position + Vector3.new(0, 2, 0))
		end
	elseif action == "Denied" then
		local booth = data == "Spin" and lobby:FindFirstChild("DailySpins") or lobby:FindFirstChild("FreeRewards")
		flash(booth and booth:FindFirstChild((data == "Spin" and "Wheel" or "Gift") .. "Icon"))
	end
end)

---------------------------------------------------------------- trampolines

local lastBounce = 0
local function checkTrampolines()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or os.clock() - lastBounce < 0.4 then
		return
	end
	for _, pad in trampolines do
		local offset = root.Position - pad.Position
		local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
		if flat < pad.Size.Y / 2 and offset.Y > 0 and offset.Y < 4 and root.AssemblyLinearVelocity.Y <= 1 then
			lastBounce = os.clock()
			local velocity = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(velocity.X, BOUNCE, velocity.Z)
			burst(pad.Position + Vector3.new(0, 1, 0))
			return
		end
	end
end

---------------------------------------------------------------- every frame

local bulbStep, bulbClock = 0, 0
RunService.Heartbeat:Connect(function(dt)
	local t = os.clock()

	for _, item in icons do
		local frame = item.base * CFrame.new(0, math.sin(t * 2 + item.phase) * 0.5, 0) * CFrame.Angles(0, t * 0.8 + item.phase, 0)
		for i, part in item.parts do
			move(part, frame * item.offsets[i])
		end
	end

	if wheel then
		if spinTarget then
			local alpha = math.min((t - spinTarget.start) / spinTarget.duration, 1)
			local eased = 1 - (1 - alpha) ^ 3 -- fast, then slowing to a stop
			wheel.angle = spinTarget.from + (spinTarget.to - spinTarget.from) * eased
			if alpha >= 1 then
				spinTarget = nil
				wheel.holdUntil = t + 4 -- show the winning slice before idling again
			end
		elseif t > (wheel.holdUntil or 0) then
			wheel.angle += dt * wheel.speed
		end
		local frame = wheel.center * CFrame.Angles(wheel.angle, 0, 0)
		for i, part in wheel.parts do
			move(part, frame * wheel.offsets[i])
		end
	end

	for _, bat in bats do
		local a = t * bat.speed + bat.phase
		local position = bat.center + Vector3.new(math.cos(a) * bat.radius, math.sin(t * 1.3 + bat.phase) * 2, math.sin(a) * bat.radius)
		local ahead = bat.center + Vector3.new(math.cos(a + 0.1 * math.sign(bat.speed)) * bat.radius, 0, math.sin(a + 0.1 * math.sign(bat.speed)) * bat.radius)
		local facing = CFrame.lookAt(position, Vector3.new(ahead.X, position.Y, ahead.Z))
		local flap = math.sin(t * 14 + bat.phase) * 0.7
		move(bat.body, facing)
		move(bat.eyes, facing * CFrame.new(0, 0.2, -0.75))
		move(bat.left, facing * CFrame.Angles(0, 0, flap) * CFrame.new(-1.5, 0, 0))
		move(bat.right, facing * CFrame.Angles(0, 0, -flap) * CFrame.new(1.5, 0, 0))
	end

	if #moveParts > 0 then
		Workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
		table.clear(moveParts)
		table.clear(moveFrames)
	end

	-- String lights chase round the fence.
	bulbClock += dt
	if bulbClock > 0.25 then
		bulbClock = 0
		bulbStep += 1
		for i, bulb in bulbs do
			bulb.part.Transparency = (i + bulbStep) % 3 == 0 and 0.75 or 0
		end
	end

	for _, lamp in lamps do
		local flicker = math.clamp(0.75 + math.noise(t * 4, lamp.phase) * 0.8, 0.4, 1.1)
		if lamp.light then
			lamp.light.Brightness = lamp.brightness * flicker
		end
	end

	-- Taken seats pulse, full tables glow.
	local pulse = 0.25 + 0.25 * math.sin(t * 6)
	for _, light in seatLights do
		light.Transparency = light.Color.G > 0.9 and pulse or 0
	end
	for _, rim in rims do
		rim.Transparency = rim.Color.R > 0.9 and rim.Color.G > 0.5 and pulse or 0.1
	end

	for part, info in flashes do
		if t > info.untilTime then
			part.Color = info.color
			flashes[part] = nil
		else
			part.Color = math.floor(t * 12) % 2 == 0 and RED or info.color
		end
	end

	checkTrampolines()
end)
