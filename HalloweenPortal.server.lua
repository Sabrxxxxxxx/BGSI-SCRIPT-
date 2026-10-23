-- Halloween Portal
-- Put this Script in ServerScriptService and press Play.
-- It builds a Halloween portal near spawn and a small Halloween island with
-- a portal back. Touching either portal teleports the player to the other.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- Settings: change these to fit your map.
-- The hub portal stands on the ground at this CFrame and faces its LookVector.
local HUB_PORTAL_CFRAME = CFrame.lookAt(Vector3.new(0, 0, -40), Vector3.new(0, 0, 0))
-- Center of the island's top surface. The return portal stands here.
local ISLAND_CENTER = Vector3.new(800, 300, 800)
local ISLAND_SIZE = 120
local TELEPORT_COOLDOWN = 2

local ORANGE = Color3.fromRGB(255, 117, 24)
local PURPLE = Color3.fromRGB(120, 40, 200)
local DARK = Color3.fromRGB(30, 25, 35)
local STONE = Color3.fromRGB(90, 90, 100)
local STEM = Color3.fromRGB(60, 110, 40)

local RING_RADIUS = 6
local RING_SEGMENTS = 24

local function makePart(parent, size, cframe, color, material, shape)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function makePumpkin(parent, groundCFrame, size)
	local body = makePart(parent, Vector3.new(size, size, size), groundCFrame * CFrame.new(0, size / 2, 0),
		ORANGE, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	body.Name = "Pumpkin"

	-- Cylinders run along X, so turn the stem upright.
	makePart(parent, Vector3.new(size * 0.3, size * 0.15, size * 0.15),
		groundCFrame * CFrame.new(0, size * 1.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		STEM, Enum.Material.Wood, Enum.PartType.Cylinder)

	local glow = Instance.new("PointLight")
	glow.Color = ORANGE
	glow.Range = size * 3
	glow.Brightness = 1
	glow.Parent = body
end

-- Builds one portal and returns its gateway part (the part players touch).
local function buildPortal(name, groundCFrame, labelText)
	local model = Instance.new("Model")
	model.Name = name

	makePart(model, Vector3.new(RING_RADIUS * 2 + 4, 1, 4), groundCFrame * CFrame.new(0, 0.5, 0),
		DARK, Enum.Material.Slate)

	-- Ring of alternating glowing orange and dark stone segments.
	local center = groundCFrame * CFrame.new(0, RING_RADIUS + 1.5, 0)
	local segmentLength = 2 * math.pi * RING_RADIUS / RING_SEGMENTS * 1.15
	for i = 0, RING_SEGMENTS - 1 do
		local angle = i / RING_SEGMENTS * 2 * math.pi
		local glowing = i % 2 == 0
		makePart(model, Vector3.new(1, segmentLength, 1.5),
			center * CFrame.new(math.cos(angle) * RING_RADIUS, math.sin(angle) * RING_RADIUS, 0) * CFrame.Angles(0, 0, angle),
			if glowing then ORANGE else DARK,
			if glowing then Enum.Material.Neon else Enum.Material.Slate)
	end

	-- Turned 90 degrees so the disc faces along the portal's LookVector.
	local gateway = makePart(model, Vector3.new(0.4, RING_RADIUS * 2 - 1, RING_RADIUS * 2 - 1),
		center * CFrame.Angles(0, math.rad(90), 0), PURPLE, Enum.Material.Neon, Enum.PartType.Cylinder)
	gateway.Name = "Gateway"
	gateway.Transparency = 0.25
	gateway.CanCollide = false

	local light = Instance.new("PointLight")
	light.Color = ORANGE
	light.Range = 20
	light.Brightness = 3
	light.Parent = gateway

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(ORANGE, PURPLE)
	particles.LightEmission = 1
	particles.Size = NumberSequence.new(0.8, 0)
	particles.Transparency = NumberSequence.new(0.2, 1)
	particles.Lifetime = NumberRange.new(1, 2)
	particles.Speed = NumberRange.new(1, 3)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Rate = 40
	particles.Parent = gateway

	-- Pulse between purple and orange forever.
	TweenService:Create(gateway, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Color = ORANGE }):Play()

	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(260, 60)
	sign.StudsOffset = Vector3.new(0, RING_RADIUS + 2.5, 0)
	sign.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Creepster
	label.Text = labelText
	label.TextScaled = true
	label.TextColor3 = ORANGE
	label.TextStrokeTransparency = 0
	label.Parent = sign
	sign.Parent = gateway

	makePumpkin(model, groundCFrame * CFrame.new(-(RING_RADIUS + 4), 0, -2), 3)
	makePumpkin(model, groundCFrame * CFrame.new(RING_RADIUS + 4, 0, -2), 3)

	model.Parent = workspace
	return gateway
end

local function buildIsland()
	local model = Instance.new("Model")
	model.Name = "HalloweenIsland"

	makePart(model, Vector3.new(ISLAND_SIZE, 4, ISLAND_SIZE), CFrame.new(ISLAND_CENTER - Vector3.new(0, 2, 0)),
		DARK, Enum.Material.Ground)

	-- Pumpkins and gravestones in a loose circle, clear of the portal in the middle.
	local random = Random.new(31)
	for i = 1, 12 do
		local angle = i / 12 * 2 * math.pi
		local distance = random:NextNumber(20, ISLAND_SIZE / 2 - 8)
		local spot = CFrame.new(ISLAND_CENTER + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance))
		if i % 2 == 0 then
			makePumpkin(model, spot, random:NextNumber(2, 4))
		else
			makePart(model, Vector3.new(3, 4, 0.8), spot * CFrame.new(0, 2, 0) * CFrame.Angles(0, random:NextNumber(0, math.pi), 0),
				STONE, Enum.Material.Slate)
		end
	end

	model.Parent = workspace
end

local lastTeleport = {}

local function connectGateway(gateway, landingCFrame)
	gateway.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end

		local now = os.clock()
		if lastTeleport[player] and now - lastTeleport[player] < TELEPORT_COOLDOWN then
			return
		end
		lastTeleport[player] = now

		character:PivotTo(landingCFrame)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	lastTeleport[player] = nil
end)

local islandPortalCFrame = CFrame.new(ISLAND_CENTER)

buildIsland()
local hubGateway = buildPortal("HalloweenPortal", HUB_PORTAL_CFRAME, "Halloween World")
local returnGateway = buildPortal("ReturnPortal", islandPortalCFrame, "Back to Spawn")

-- Land 10 studs in front of the other portal so players don't bounce straight back.
connectGateway(hubGateway, islandPortalCFrame * CFrame.new(0, 4, -10))
connectGateway(returnGateway, HUB_PORTAL_CFRAME * CFrame.new(0, 4, -10))
