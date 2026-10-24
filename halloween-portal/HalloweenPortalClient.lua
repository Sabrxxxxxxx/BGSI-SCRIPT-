-- HalloweenPortalClient (LocalScript)
-- Put this in StarterPlayer > StarterPlayerScripts.
--
-- Plays everything you see: the portal flying together and swirling open,
-- the ghosts and pumpkins, and the trip through the portal. The Script
-- "HalloweenPortalServer" builds the parts and decides who travels.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("HalloweenPortalEvent")
local world = Workspace:WaitForChild("HalloweenWorld")
local epoch = world:GetAttribute("Epoch") or 0

local ANIMATE_DISTANCE = 350 -- studs; anything further from the camera holds still
local HOLD_TIMEOUT = 8 -- seconds of black screen before giving up on the server

local THEME = {
	Orange = Color3.fromRGB(255, 140, 32),
	Purple = Color3.fromRGB(150, 60, 230),
	DeepPurple = Color3.fromRGB(30, 8, 44),
	White = Color3.new(1, 1, 1),
	GlowDim = Color3.fromRGB(220, 110, 25),
	GlowBright = Color3.fromRGB(255, 216, 120),
	TitleFont = Font.fromEnum(Enum.Font.Creepster),
}

---------------------------------------------------------------- moving parts

-- Everything moved this frame goes into one BulkMoveTo call.
local moveParts, moveCFrames = {}, {}
local function queueMove(part, cframe)
	local n = #moveParts + 1
	moveParts[n] = part
	moveCFrames[n] = cframe
end

local tracked = {} -- [model] = record with an update(record, t, cameraPosition, now) function

local function track(tag, setup)
	local function add(model)
		if tracked[model] or not model:IsA("Model") then
			return
		end
		local record = setup(model)
		if record and model.Parent then
			tracked[model] = record
		end
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(model)
		tracked[model] = nil
	end)
	for _, model in CollectionService:GetTagged(tag) do
		task.spawn(add, model)
	end
end

---------------------------------------------------------------- ghosts

local function ghostPosition(ghost, t)
	local angle = t * ghost.speed + ghost.phase
	local wander = 1 + 0.25 * math.sin(angle * 2.3 + ghost.phase)
	return ghost.center
		+ Vector3.new(
			math.cos(angle) * ghost.radius * wander,
			ghost.height + math.sin(t * 1.7 + ghost.phase) * 0.9,
			math.sin(angle) * ghost.radius * wander * 0.8
		)
end

local function updateGhost(ghost, t, cameraPosition)
	-- Fade in rather than pop in, when spawned or streamed in.
	if ghost.fading then
		local fade = math.min((os.clock() - ghost.born) / 1, 1)
		for part, base in ghost.transparency do
			part.Transparency = 1 - (1 - base) * fade
		end
		ghost.fading = fade < 1
	end
	if (ghost.center - cameraPosition).Magnitude > ANIMATE_DISTANCE + ghost.radius then
		return
	end

	local position = ghostPosition(ghost, t)
	local heading = (ghostPosition(ghost, t + 0.2) - position) * Vector3.new(1, 0, 1)
	local facing = heading.Magnitude > 1e-3 and CFrame.lookAt(position, position + heading) or CFrame.new(position)
	local pivot = facing * CFrame.Angles(0, 0, math.sin(t * 1.3 + ghost.phase) * 0.08)

	for i, part in ghost.parts do
		queueMove(part, pivot * ghost.offsets[i])
	end
	for _, arm in ghost.arms do
		local wave = math.sin(t * 1.6 + ghost.phase + (arm.side > 0 and 0 or 1.3)) * 0.45
		queueMove(arm.part, pivot * arm.shoulder * CFrame.Angles(0, 0, arm.side * wave) * arm.offset)
	end
end

local function setupGhost(model)
	local head = model.PrimaryPart
	if not head then
		return nil
	end
	local pivot = model:GetPivot()
	local ghost = {
		center = model:GetAttribute("Center") or pivot.Position,
		radius = model:GetAttribute("Radius") or 20,
		height = model:GetAttribute("Height") or 8,
		speed = model:GetAttribute("Speed") or 0.2,
		phase = model:GetAttribute("Phase") or 0,
		parts = {},
		offsets = {},
		arms = {},
		transparency = {},
		born = os.clock(),
		fading = true,
		update = updateGhost,
	}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local side = part:GetAttribute("Side")
			local shoulder = side and head:FindFirstChild(side < 0 and "LeftShoulder" or "RightShoulder")
			if shoulder then
				table.insert(ghost.arms, {
					part = part,
					side = side,
					shoulder = shoulder.CFrame,
					offset = (pivot * shoulder.CFrame):ToObjectSpace(part.CFrame),
				})
			else
				table.insert(ghost.parts, part)
				table.insert(ghost.offsets, pivot:ToObjectSpace(part.CFrame))
			end
			ghost.transparency[part] = part.Transparency
			part.Transparency = 1
		end
	end
	return ghost
end

---------------------------------------------------------------- pumpkins

local function updatePumpkin(pumpkin, t, cameraPosition)
	if (pumpkin.base.Position - cameraPosition).Magnitude > ANIMATE_DISTANCE then
		return
	end

	local beat = t * pumpkin.speed + pumpkin.phase
	local hop = math.abs(math.sin(beat)) * pumpkin.hop
	local wobble = CFrame.Angles(math.sin(beat * 0.9) * 0.1 * pumpkin.wobble, 0, math.cos(beat * 1.1) * 0.12 * pumpkin.wobble)
	local pivot = pumpkin.base * CFrame.new(0, hop, 0) * wobble
	for i, part in pumpkin.parts do
		queueMove(part, pivot * pumpkin.offsets[i])
	end

	-- Candle flicker: two layers of noise, one slow and one fast.
	local noise = math.noise(t * 4, pumpkin.phase * 7.3) + 0.5 * math.noise(t * 11, pumpkin.phase * 3.1)
	local flame = math.clamp(0.65 + noise * 1.2, 0.25, 1)
	local color = THEME.GlowDim:Lerp(THEME.GlowBright, flame)
	for _, part in pumpkin.glow do
		part.Color = color
	end
	if pumpkin.candle then
		pumpkin.candle.Brightness = pumpkin.candleBrightness * (0.45 + flame * 0.75)
	end
end

local function setupPumpkin(model)
	local base = model:GetPivot()
	local candle = model:FindFirstChildWhichIsA("PointLight", true)
	local pumpkin = {
		base = base,
		speed = model:GetAttribute("Speed") or 2.6,
		phase = model:GetAttribute("Phase") or 0,
		hop = model:GetAttribute("Hop") or 0.8,
		wobble = model:GetAttribute("Wobble") or 1,
		parts = {},
		offsets = {},
		glow = {},
		candle = candle,
		candleBrightness = candle and candle.Brightness or 0,
		update = updatePumpkin,
	}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(pumpkin.parts, part)
			table.insert(pumpkin.offsets, base:ToObjectSpace(part.CFrame))
			if part:GetAttribute("Glow") then
				table.insert(pumpkin.glow, part)
			end
		end
	end
	return pumpkin
end

---------------------------------------------------------------- portal

local dustPoint = Instance.new("Attachment")
dustPoint.Name = "PortalDust"
local dust = Instance.new("ParticleEmitter")
dust.Enabled = false
dust.Color = ColorSequence.new(Color3.fromRGB(120, 100, 110), THEME.Orange)
dust.LightEmission = 0.3
dust.Size = NumberSequence.new(1.2, 3)
dust.Transparency = NumberSequence.new(0.3, 1)
dust.Lifetime = NumberRange.new(0.5, 0.9)
dust.Speed = NumberRange.new(5, 9)
dust.SpreadAngle = Vector2.new(50, 50)
dust.Drag = 4
dust.Parent = dustPoint
dustPoint.Parent = Workspace.Terrain

local function spinSwirl(portal, t, open)
	local eased = TweenService:GetValue(open, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local spin = t * 1.1 + (1 - eased) * 5 -- whips round faster while opening
	for _, bit in portal.swirl do
		local angle = bit.angle + spin
		local radius = bit.radius * eased
		queueMove(bit.part, portal.center * CFrame.new(math.cos(angle) * radius * portal.swirlX, math.sin(angle) * radius * portal.swirlY, 0) * CFrame.Angles(0, 0, angle))
		if open < 1 then
			bit.part.Transparency = 1 - open * (1 - bit.final)
		end
	end
	if open < 1 then
		local grow = math.max(eased, 0.02)
		local size = portal.coreSize
		portal.core.Size = Vector3.new(size.X, size.Y * grow, size.Z * grow)
		portal.core.Transparency = 1 - open * (1 - portal.coreFinal)
		if portal.coreLight then
			portal.coreLight.Enabled = open > 0
			portal.coreLight.Brightness = portal.coreBrightness * open
		end
	end
end

local function settlePortal(portal)
	portal.settled = true
	for _, piece in portal.pieces do
		for i, part in piece.parts do
			queueMove(part, piece.final * piece.offsets[i])
			part.Transparency = piece.finals[part]
			if piece.runes[part] then
				part.Color = piece.runes[part]
			end
		end
	end
	portal.core.Size = portal.coreSize
	portal.core.Transparency = portal.coreFinal
	if portal.coreLight then
		portal.coreLight.Enabled = true
		portal.coreLight.Brightness = portal.coreBrightness
	end
end

local function updatePortal(portal, t, cameraPosition, now)
	local elapsed = now - portal.start
	if elapsed < portal.total then
		-- Ring pieces burst out of the ground one by one and light up as they land.
		for _, piece in portal.pieces do
			local launchAt = (piece.index - 1) * portal.delay
			local flight = (elapsed - launchAt) / portal.fly
			if flight <= 0 then
				for _, part in piece.parts do
					part.Transparency = 1
				end
			else
				if not piece.launched then
					piece.launched = true
					if flight < 0.5 then
						dustPoint.WorldPosition = piece.launch
						dust:Emit(14)
					end
				end
				local alpha = math.min(flight, 1)
				local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
				local position = piece.from:Lerp(piece.final.Position, eased) + Vector3.new(0, math.sin(alpha * math.pi) * 2.5, 0)
				local pivot = CFrame.new(position)
					* piece.final.Rotation
					* CFrame.Angles((1 - eased) * 1.1, 0, (1 - eased) * piece.spin)
				local lit = math.clamp((elapsed - launchAt - portal.fly) / portal.light, 0, 1)
				for i, part in piece.parts do
					queueMove(part, pivot * piece.offsets[i])
					local runeColor = piece.runes[part]
					if runeColor then
						part.Transparency = 1 - lit * (1 - piece.finals[part])
						part.Color = THEME.White:Lerp(runeColor, lit) -- flash white, then settle
					else
						part.Transparency = piece.finals[part]
					end
				end
			end
		end
		spinSwirl(portal, t, math.clamp((elapsed - portal.openAt) / portal.open, 0, 1))
		return
	end

	if not portal.settled then
		settlePortal(portal)
	end
	if (portal.center.Position - cameraPosition).Magnitude > ANIMATE_DISTANCE then
		return
	end
	spinSwirl(portal, t, 1)
	portal.core.Transparency = portal.coreFinal + math.sin(t * 2.2) * 0.06
end

local function setupPortal(model)
	local center = model:GetAttribute("PortalCFrame")
	local piecesFolder = model:WaitForChild("Pieces", 10)
	local swirlFolder = model:WaitForChild("Swirl", 10)
	local core = model:WaitForChild("Core", 10)
	if not (center and piecesFolder and swirlFolder and core) then
		return nil
	end

	local coreLight = core:FindFirstChildWhichIsA("PointLight")
	local portal = {
		center = center,
		start = model:GetAttribute("BuildStart") or 0,
		delay = model:GetAttribute("PieceDelay") or 0.15,
		fly = model:GetAttribute("FlyTime") or 0.8,
		light = model:GetAttribute("LightTime") or 0.35,
		open = model:GetAttribute("OpenTime") or 1.4,
		core = core,
		coreSize = core.Size,
		coreFinal = core:GetAttribute("FinalTransparency") or 0.3,
		coreLight = coreLight,
		coreBrightness = coreLight and coreLight.Brightness or 0,
		pieces = {},
		swirl = {},
		swirlX = model:GetAttribute("SwirlScaleX") or 1,
		swirlY = model:GetAttribute("SwirlScaleY") or 1,
		settled = false,
		update = updatePortal,
	}
	local groundY = model:GetAttribute("GroundY") or center.Y
	local count = #piecesFolder:GetChildren()
	portal.openAt = (count - 1) * portal.delay + portal.fly + portal.light
	portal.total = portal.openAt + portal.open

	for _, pieceModel in piecesFolder:GetChildren() do
		local stone = pieceModel:FindFirstChild("Stone")
		local index = pieceModel:GetAttribute("Index")
		if stone and index then
			local final = stone.CFrame
			local outward = (final.Position - center.Position) * Vector3.new(1, 0, 1)
			outward = outward.Magnitude > 0.01 and outward.Unit or Vector3.zero
			local launch = Vector3.new(final.X, groundY, final.Z) + outward * 3
			local piece = {
				index = index,
				final = final,
				launch = launch,
				from = launch - Vector3.new(0, 4, 0), -- starts buried
				spin = (index % 2 == 0 and 1 or -1) * 2.6,
				launched = false,
				parts = {},
				offsets = {},
				finals = {},
				runes = {},
			}
			for _, part in pieceModel:GetChildren() do
				if part:IsA("BasePart") then
					table.insert(piece.parts, part)
					table.insert(piece.offsets, final:ToObjectSpace(part.CFrame))
					piece.finals[part] = part:GetAttribute("FinalTransparency") or 0
					if part.Name == "Rune" then
						piece.runes[part] = part.Color
					end
				end
			end
			table.insert(portal.pieces, piece)
		end
	end

	for _, part in swirlFolder:GetChildren() do
		if part:IsA("BasePart") then
			table.insert(portal.swirl, {
				part = part,
				angle = part:GetAttribute("Angle") or 0,
				radius = part:GetAttribute("Radius") or 1,
				final = part:GetAttribute("FinalTransparency") or 0.15,
			})
		end
	end
	return portal
end

track("HalloweenGhost", setupGhost)
track("HalloweenPumpkin", setupPumpkin)
track("HalloweenPortal", setupPortal)

---------------------------------------------------------------- candles and lanterns

-- Candle flames and lantern glass flicker once the server marks them Lit.
local flames = {} -- [part] = { light, brightness, size, phase, glass }

local function addFlame(part)
	if not part:IsA("BasePart") or flames[part] then
		return
	end
	local light = part:FindFirstChildWhichIsA("PointLight")
	flames[part] = {
		light = light,
		brightness = light and light.Brightness or 0,
		size = part.Size,
		phase = math.random() * 100,
		glass = part:GetAttribute("LitColor") ~= nil,
	}
end
CollectionService:GetInstanceAddedSignal("HalloweenFlame"):Connect(addFlame)
CollectionService:GetInstanceRemovedSignal("HalloweenFlame"):Connect(function(part)
	flames[part] = nil
end)
for _, part in CollectionService:GetTagged("HalloweenFlame") do
	addFlame(part)
end

local function updateFlames(t, cameraPosition)
	for part, flame in flames do
		if not part.Parent then
			flames[part] = nil
		elseif part:GetAttribute("Lit") and (part.Position - cameraPosition).Magnitude < ANIMATE_DISTANCE then
			local noise = math.noise(t * 5, flame.phase) + 0.5 * math.noise(t * 13, flame.phase + 7)
			local strength = math.clamp(0.7 + noise, 0.35, 1.1)
			if flame.light then
				flame.light.Brightness = flame.brightness * strength
			end
			if not flame.glass then
				part.Size = Vector3.new(flame.size.X, flame.size.Y * (0.8 + 0.3 * strength), flame.size.Z)
			end
			part.Color = THEME.GlowDim:Lerp(THEME.GlowBright, math.clamp(strength, 0, 1))
		end
	end
end

---------------------------------------------------------------- the gate

-- When you walk into the courtyard the gate slams shut behind you, then creaks
-- open again a little later. This only changes your own view and collisions,
-- so other players can still come through.
local SLAM_TIME = 0.9
local BOUNCE_TIME = 0.45
local REOPEN_TIME = 2.2
local gates = {} -- [GateId] = { leaves, frame, state, changedAt, ... }

local shakeUntil, shakeLength, shakeStrength = 0, 1, 0
RunService:BindToRenderStep("HalloweenGateShake", Enum.RenderPriority.Camera.Value + 1, function()
	local left = shakeUntil - os.clock()
	local camera = Workspace.CurrentCamera
	if left > 0 and camera then
		local amount = shakeStrength * left / shakeLength
		camera.CFrame *= CFrame.new((math.random() - 0.5) * amount, (math.random() - 0.5) * amount, 0)
	end
end)

local function addGateLeaf(model)
	local hinge = model:GetAttribute("Hinge")
	local openAngle = model:GetAttribute("OpenAngle")
	local frame = model:GetAttribute("GateFrame")
	local id = model:GetAttribute("GateId")
	if not (model:IsA("Model") and hinge and openAngle and frame and id) then
		return
	end
	local gate = gates[id]
	if not gate then
		gate = {
			leaves = {},
			frame = frame,
			depth = model:GetAttribute("CourtDepth") or 40,
			halfWidth = model:GetAttribute("CourtHalfWidth") or 25,
			reopenAfter = model:GetAttribute("ReopenAfter") or 12,
			state = "open",
			changedAt = 0,
			seenOutside = false,
		}
		gates[id] = gate
	end
	local openFrame = hinge * CFrame.Angles(0, openAngle, 0)
	local leaf = { hinge = hinge, openAngle = openAngle, parts = {}, offsets = {} }
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(leaf.parts, part)
			table.insert(leaf.offsets, openFrame:ToObjectSpace(part.CFrame))
		end
	end
	gate.leaves[model] = leaf
	gate.lastAmount = nil
end
CollectionService:GetInstanceAddedSignal("HalloweenGate"):Connect(addGateLeaf)
for _, model in CollectionService:GetTagged("HalloweenGate") do
	addGateLeaf(model)
end

-- 0 = standing open, 1 = shut.
local function gateClosedAmount(gate, clock)
	local elapsed = clock - gate.changedAt
	if gate.state == "closing" then
		if elapsed < SLAM_TIME then
			return (elapsed / SLAM_TIME) ^ 2.2 -- a slow creak that speeds into a slam
		end
		local u = math.min((elapsed - SLAM_TIME) / BOUNCE_TIME, 1)
		return 1 - 0.07 * math.exp(-5 * u) * math.abs(math.sin(u * math.pi * 2.5)) -- rattles against the latch
	elseif gate.state == "closed" then
		return 1
	elseif gate.state == "opening" then
		return 1 - TweenService:GetValue(math.min(elapsed / REOPEN_TIME, 1), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	end
	return 0
end

local function setGateState(gate, state, clock)
	gate.state = state
	gate.changedAt = clock
end

local function updateGates(clock)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	for _, gate in gates do
		for model in gate.leaves do
			if not model.Parent then
				gate.leaves[model] = nil
			end
		end

		if root then
			local p = gate.frame:PointToObjectSpace(root.Position)
			if p.Z < -1 then
				gate.seenOutside = true
			end
			local inCourtyard = p.Z > 9 and p.Z < gate.depth and math.abs(p.X) < gate.halfWidth and math.abs(p.Y) < 40
			if gate.state == "open" and gate.seenOutside and inCourtyard then
				gate.seenOutside = false
				gate.slammed = false
				setGateState(gate, "closing", clock)
			end
		end

		local elapsed = clock - gate.changedAt
		if gate.state == "closing" then
			if not gate.slammed and elapsed >= SLAM_TIME then
				gate.slammed = true
				dustPoint.WorldPosition = (gate.frame * CFrame.new(0, 0.5, 0)).Position
				dust:Emit(40)
				shakeLength, shakeStrength = 0.35, 0.7
				shakeUntil = clock + shakeLength
			end
			if elapsed >= SLAM_TIME + BOUNCE_TIME then
				setGateState(gate, "closed", clock)
			end
		elseif gate.state == "closed" and elapsed >= gate.reopenAfter then
			setGateState(gate, "opening", clock)
		elseif gate.state == "opening" and elapsed >= REOPEN_TIME then
			setGateState(gate, "open", clock)
		end

		local amount = gateClosedAmount(gate, clock)
		if amount ~= gate.lastAmount then
			gate.lastAmount = amount
			for _, leaf in gate.leaves do
				local frame = leaf.hinge * CFrame.Angles(0, leaf.openAngle * (1 - amount), 0)
				for i, part in leaf.parts do
					queueMove(part, frame * leaf.offsets[i])
				end
			end
		end
	end
end

player.CharacterAdded:Connect(function()
	-- Respawned: the gate is open again.
	for _, gate in gates do
		gate.seenOutside = false
		setGateState(gate, "open", os.clock())
	end
end)

RunService.Heartbeat:Connect(function()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local t = now - epoch
	local cameraPosition = camera.CFrame.Position
	for model, record in tracked do
		if model.Parent then
			record.update(record, t, cameraPosition, now)
		else
			tracked[model] = nil
		end
	end
	updateFlames(t, cameraPosition)
	updateGates(os.clock())
	if #moveParts > 0 then
		Workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
		table.clear(moveParts)
		table.clear(moveCFrames)
	end
end)

---------------------------------------------------------------- trip screen effects

local function newFrame(name, parent, props)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BorderSizePixel = 0
	for key, value in props do
		frame[key] = value
	end
	frame.Parent = parent
	return frame
end

local screen = Instance.new("ScreenGui")
screen.Name = "HalloweenPortalFX"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true -- the swirl and the fade cover the whole screen, top bar included
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.DisplayOrder = 50

local FULL = UDim2.fromScale(1, 1)
local CENTER = UDim2.fromScale(0.5, 0.5)
local MIDDLE = Vector2.new(0.5, 0.5)

local swirl = newFrame("Swirl", screen, { Size = FULL, BackgroundTransparency = 1, Visible = false, ZIndex = 1 })

local wash = newFrame("Wash", swirl, { Size = FULL, BackgroundColor3 = THEME.White, BackgroundTransparency = 1 })
local washGradient = Instance.new("UIGradient")
washGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, THEME.Purple),
	ColorSequenceKeypoint.new(0.5, THEME.Orange),
	ColorSequenceKeypoint.new(1, THEME.Purple),
})
washGradient.Parent = wash

-- Bars through the middle, see-through at the centre, spinning both ways.
local rays = {}
for i = 1, 8 do
	local ray = newFrame("Ray", swirl, {
		AnchorPoint = MIDDLE,
		Position = CENTER,
		BackgroundColor3 = i % 2 == 1 and THEME.Orange or THEME.Purple,
		BackgroundTransparency = 1,
	})
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	fade.Parent = ray
	table.insert(rays, { frame = ray, base = (i - 1) * 22.5, speed = i % 2 == 1 and 80 or -55 })
end

-- Rings rushing towards the middle, like falling down a tunnel.
local rings = {}
for i = 1, 6 do
	local ring = newFrame("Ring", swirl, { AnchorPoint = MIDDLE, Position = CENTER, BackgroundTransparency = 1 })
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Color = i % 2 == 1 and THEME.Purple or THEME.Orange
	stroke.Transparency = 1
	stroke.Parent = ring
	table.insert(rings, { frame = ring, stroke = stroke })
end

local blackout = newFrame("Blackout", screen, {
	Size = FULL,
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 2,
})

local TITLE_POSITION = UDim2.fromScale(0.5, 0.36)
local title = Instance.new("TextLabel")
title.Name = "WorldTitle"
title.AnchorPoint = MIDDLE
title.Position = TITLE_POSITION
title.Size = UDim2.fromScale(0.9, 0.2)
title.BackgroundTransparency = 1
title.FontFace = THEME.TitleFont
title.TextColor3 = THEME.Orange
title.TextScaled = true
title.TextTransparency = 1
title.Visible = false
title.ZIndex = 3
title.Parent = screen
local titleSize = Instance.new("UITextSizeConstraint")
titleSize.MinTextSize = 32
titleSize.MaxTextSize = 120
titleSize.Parent = title
local titleStroke = Instance.new("UIStroke")
titleStroke.Color = THEME.DeepPurple
titleStroke.Thickness = 4
titleStroke.Transparency = 1
titleStroke.Parent = title
local titleScale = Instance.new("UIScale")
titleScale.Parent = title

screen.Parent = player:WaitForChild("PlayerGui")

local titleTweens = {}
local titleToken = 0

local function showTitle(text)
	for _, tween in titleTweens do
		tween:Cancel()
	end
	titleToken += 1
	local token = titleToken

	title.Text = text
	title.Position = TITLE_POSITION
	title.TextTransparency = 1
	titleStroke.Transparency = 1
	titleScale.Scale = 0.82
	title.Visible = true

	local enter = TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	titleTweens = {
		TweenService:Create(title, enter, { TextTransparency = 0 }),
		TweenService:Create(titleStroke, enter, { Transparency = 0 }),
		TweenService:Create(titleScale, TweenInfo.new(0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = 1 }),
	}
	for _, tween in titleTweens do
		tween:Play()
	end

	task.delay(2.8, function()
		if token ~= titleToken then
			return
		end
		local leave = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local fadeOut = TweenService:Create(title, leave, {
			TextTransparency = 1,
			Position = TITLE_POSITION - UDim2.fromScale(0, 0.04),
		})
		titleTweens = { fadeOut, TweenService:Create(titleStroke, leave, { Transparency = 1 }) }
		for _, tween in titleTweens do
			tween:Play()
		end
		fadeOut.Completed:Wait()
		if token == titleToken then
			title.Visible = false
		end
	end)
end

-- One trip at a time: "enter" (zoom, swirl, fade to black), "hold" (black
-- until the server has moved us), "arrive" (fade back in), then the title.
local trip = { phase = "idle" }
local diagonal = 1000

local function drawSwirl(level, black, clock)
	wash.BackgroundTransparency = 1 - 0.6 * level
	washGradient.Rotation = (clock * 120) % 360
	for _, ray in rays do
		ray.frame.Rotation = (ray.base + clock * ray.speed) % 360
		ray.frame.BackgroundTransparency = 1 - 0.85 * level
	end
	for i, ring in rings do
		local progress = (clock * 0.75 + i / #rings) % 1
		local size = diagonal * (1 - progress) ^ 1.7
		ring.frame.Size = UDim2.fromOffset(size, size)
		ring.stroke.Thickness = 3 + 16 * (1 - progress)
		ring.stroke.Transparency = 1 - level * 0.85 * math.sin(progress * math.pi)
	end
	blackout.BackgroundTransparency = 1 - black
end

local function endTrip(showWorldTitle)
	if trip.connection then
		trip.connection:Disconnect()
	end
	if trip.cameraTween then
		trip.cameraTween:Cancel()
	end
	local camera = Workspace.CurrentCamera
	if trip.phase ~= "arrive" and camera then
		-- Cut short: hand the camera straight back.
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = trip.fieldOfView or camera.FieldOfView
	end
	local text = trip.title
	trip = { phase = "idle" }
	swirl.Visible = false
	blackout.Visible = false
	blackout.BackgroundTransparency = 1
	if showWorldTitle and text then
		showTitle(text)
	end
end

local function arrive(text)
	if trip.phase ~= "enter" and trip.phase ~= "hold" then
		return
	end
	if trip.cameraTween then
		trip.cameraTween:Cancel()
	end
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = trip.fieldOfView
	trip.title = text
	trip.phase = "arrive"
	trip.started = os.clock()
end

local function renderTrip()
	local clock = os.clock()
	local elapsed = clock - trip.started
	local level, black = 1, 1
	if trip.phase == "enter" then
		level = math.clamp((elapsed - 0.15) / 0.9, 0, 1)
		black = math.clamp((elapsed - 1) / 0.45, 0, 1)
		if black >= 1 then
			trip.phase = "hold"
			trip.started = clock
			remote:FireServer("Ready")
		end
	elseif trip.phase == "hold" then
		if elapsed > HOLD_TIMEOUT then
			arrive(nil)
		end
	elseif trip.phase == "arrive" then
		-- Stay black a moment while the camera settles behind the character.
		level = 1 - math.clamp(elapsed / 0.6, 0, 1)
		black = 1 - math.clamp((elapsed - 0.3) / 0.7, 0, 1)
		if black <= 0 then
			endTrip(true)
			return
		end
	end
	drawSwirl(level, black, clock)
end

local function enter(portalCFrame)
	local camera = Workspace.CurrentCamera
	if trip.phase ~= "idle" or not camera then
		return
	end

	-- Push the camera into the middle of the portal from whichever side we're on.
	local center = portalCFrame.Position
	local normal = portalCFrame.LookVector
	local side = (camera.CFrame.Position - center):Dot(normal) >= 0 and 1 or -1
	local goal = CFrame.lookAt(center + normal * side * 2.5, center - normal * side * 10)

	trip = { phase = "enter", started = os.clock(), fieldOfView = camera.FieldOfView }
	camera.CameraType = Enum.CameraType.Scriptable
	trip.cameraTween = TweenService:Create(
		camera,
		TweenInfo.new(1.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ CFrame = goal, FieldOfView = trip.fieldOfView * 0.6 }
	)
	trip.cameraTween:Play()

	diagonal = camera.ViewportSize.Magnitude * 1.05
	for _, ray in rays do
		ray.frame.Size = UDim2.fromOffset(diagonal, 28)
	end
	swirl.Visible = true
	blackout.Visible = true
	trip.connection = RunService.RenderStepped:Connect(renderTrip)
end

remote.OnClientEvent:Connect(function(action, data)
	if action == "Enter" and typeof(data) == "CFrame" then
		enter(data)
	elseif action == "Arrived" then
		arrive(type(data) == "string" and data or nil)
	end
end)

-- Respawning mid-trip: drop the effect and give the camera back.
player.CharacterAdded:Connect(function()
	if trip.phase ~= "idle" then
		endTrip(false)
	end
end)
