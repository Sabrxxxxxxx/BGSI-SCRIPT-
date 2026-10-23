-- HalloweenPortalServer (Script)
-- Put this in ServerScriptService.
--
-- Builds a glowing "Press E to build" spot near spawn. Pressing E builds the
-- Halloween portal; walking into it takes you to the Halloween island, where
-- ghosts float and jack-o'-lanterns bounce.
-- This script makes the parts and decides who travels. The LocalScript
-- "HalloweenPortalClient" plays every animation and screen effect.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CONFIG = {
	-- Put a small Part with this name in Workspace to choose where the build
	-- spot goes (it is hidden and its front faces where players come from).
	-- Without one, the spot appears this many studs in front of your SpawnLocation.
	BuildSpotPartName = "PortalBuildSpot",
	BuildSpotDistance = 40,

	-- Put a Part with this name on your own island to land there instead.
	-- Without one, a Halloween island is built at IslandCenter.
	DestinationPartName = "HalloweenSpawn",
	IslandCenter = Vector3.new(0, 150, 3000),
	WorldTitle = "Halloween World",

	PortalRadius = 9,
	RingPieces = 16,
	PieceDelay = 0.15, -- seconds between ring pieces taking off
	FlyTime = 0.8, -- seconds each piece takes to fly into place
	LightTime = 0.35, -- seconds each piece takes to light up after landing
	OpenTime = 1.4, -- seconds the center takes to swirl open

	IslandGhosts = 7,
	IslandPumpkins = 10,
	PortalGhosts = 4,
}

local COLORS = {
	Stone = Color3.fromRGB(46, 38, 56),
	Orange = Color3.fromRGB(255, 122, 24),
	Purple = Color3.fromRGB(168, 64, 255),
	Core = Color3.fromRGB(96, 24, 170),
	Ghost = Color3.fromRGB(232, 240, 255),
	GhostFace = Color3.fromRGB(24, 22, 34),
	GhostLight = Color3.fromRGB(190, 220, 255),
	Pumpkin = Color3.fromRGB(236, 112, 20),
	PumpkinGlow = Color3.fromRGB(255, 196, 70),
	CandleLight = Color3.fromRGB(255, 150, 50),
	Stem = Color3.fromRGB(86, 102, 38),
	Grass = Color3.fromRGB(52, 58, 38),
	Rock = Color3.fromRGB(76, 64, 84),
	Dirt = Color3.fromRGB(48, 38, 32),
	Grave = Color3.fromRGB(112, 112, 122),
	Wood = Color3.fromRGB(58, 42, 34),
}

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- stands a cylinder's axis up
local FACING = CFrame.Angles(0, math.rad(90), 0) -- points a cylinder's axis forward
local ENTRY_TIMEOUT = 6 -- seconds before a trip finishes even if the client never answers

local world = Instance.new("Folder")
world.Name = "HalloweenWorld"
world:SetAttribute("Epoch", Workspace:GetServerTimeNow()) -- shared clock so every player sees ghosts in the same place
world.Parent = Workspace

local remote = Instance.new("RemoteEvent")
remote.Name = "HalloweenPortalEvent"
remote.Parent = ReplicatedStorage

local function newPart(parent, name, props, className)
	local part = Instance.new(className or "Part")
	part.Name = name
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		part.Shape = props.Shape -- before Size, so the shape can't adjust the size afterwards
	end
	for key, value in props do
		if key ~= "Shape" then
			part[key] = value
		end
	end
	part.Parent = parent
	return part
end

-- Decorations nobody bumps into, clicks or gets shadowed by.
local function ghostly(props)
	props.CanCollide = false
	props.CanTouch = false
	props.CanQuery = false
	props.CastShadow = false
	return props
end

local function scaled(cframe, scale)
	return CFrame.new(cframe.Position * scale) * cframe.Rotation
end

local noLanding = {} -- props, the portal and the pad: decorations never land on top of these

local function findGround(position)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = table.clone(noLanding)
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local result = Workspace:Raycast(position + Vector3.new(0, 80, 0), Vector3.new(0, -300, 0), params)
	return result and result.Position
end

local function flatLook(cframe)
	local look = cframe.LookVector * Vector3.new(1, 0, 1)
	return look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
end

---------------------------------------------------------------- ghosts

local function addGhost(center, radius, height, scale, rng)
	local s = scale
	local model = Instance.new("Model")
	model.Name = "Ghost"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local pivot = CFrame.new(center + Vector3.new(radius, height, 0))
	local function skin(props)
		props.Material = Enum.Material.SmoothPlastic
		props.Color = COLORS.Ghost
		props.Transparency = 0.45
		return ghostly(props)
	end

	local head = newPart(model, "Head", skin({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2.6 * s, CFrame = pivot }))
	newPart(model, "Body", skin({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.6, 2.5, 2.5) * s,
		CFrame = pivot * CFrame.new(0, -1.3 * s, 0) * UPRIGHT,
	}))
	for i = 1, 4 do
		local angle = math.rad(45 + i * 90)
		newPart(model, "Hem", skin({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.25 * s,
			CFrame = pivot * CFrame.new(Vector3.new(math.cos(angle) * 0.7, -2.55, math.sin(angle) * 0.7) * s),
		}))
	end

	for _, side in { -1, 1 } do
		newPart(model, side < 0 and "LeftEye" or "RightEye", ghostly({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.5 * s,
			CFrame = pivot * CFrame.new(Vector3.new(0.45 * side, 0.25, -1.08) * s),
			Color = COLORS.GhostFace,
			Material = Enum.Material.SmoothPlastic,
		}))

		-- The client swings each arm around its shoulder attachment.
		local shoulder = Instance.new("Attachment")
		shoulder.Name = side < 0 and "LeftShoulder" or "RightShoulder"
		shoulder.Position = Vector3.new(1.15 * side, -0.85, 0) * s
		shoulder.Parent = head
		local arm = newPart(model, side < 0 and "LeftArm" or "RightArm", skin({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.9, 0.62, 0.62) * s,
			CFrame = pivot
				* shoulder.CFrame
				* CFrame.Angles(0, side * 0.6, 0)
				* CFrame.Angles(0, 0, side * -0.3)
				* CFrame.new(0.85 * side * s, 0, 0),
		}))
		arm:SetAttribute("Side", side)
	end

	newPart(model, "Mouth", ghostly({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.55 * s,
		CFrame = pivot * CFrame.new(Vector3.new(0, -0.35, -1.1) * s),
		Color = COLORS.GhostFace,
		Material = Enum.Material.SmoothPlastic,
	}))

	local light = Instance.new("PointLight")
	light.Color = COLORS.GhostLight
	light.Brightness = 0.8
	light.Range = 9 * s
	light.Parent = head

	model.PrimaryPart = head
	model:SetAttribute("Center", center)
	model:SetAttribute("Radius", radius)
	model:SetAttribute("Height", height)
	model:SetAttribute("Speed", (rng:NextNumber() < 0.5 and -1 or 1) * rng:NextNumber(0.12, 0.25))
	model:SetAttribute("Phase", rng:NextNumber(0, math.pi * 2))
	model:AddTag("HalloweenGhost")
	model.Parent = world
end

---------------------------------------------------------------- pumpkins

-- A pumpkin is three overlapping egg shapes turned 60 degrees apart, which
-- gives it ribs. The face is laid out once on a size-1 pumpkin and scaled.
local LOBE_ANGLES = { 0, math.rad(60), math.rad(120) }
local LOBE_SIZE = Vector3.new(2.8, 3.4, 4.6)

local function insidePumpkin(point)
	local radii = LOBE_SIZE / 2
	for _, angle in LOBE_ANGLES do
		local p = CFrame.Angles(0, angle, 0):PointToObjectSpace(point) / radii
		if p:Dot(p) <= 1 then
			return true
		end
	end
	return false
end

-- How far the pumpkin's front (the -Z side) bulges out at (x, y).
local function surfaceDepth(x, y)
	local depth = 0
	while depth < 3 and insidePumpkin(Vector3.new(x, y, -depth)) do
		depth += 0.02
	end
	return depth
end

-- How far outward from `origin` the surface is, measured along `direction`.
local function surfaceDistance(origin, direction)
	local distance = 0
	while distance < 3 and insidePumpkin(origin + direction * distance) do
		distance += 0.02
	end
	return distance
end

-- A slab tilted to match the curved front under a w x h patch centred on
-- (x, y), poking just out of the skin without a gap behind any edge.
local function faceSlab(x, y, w, h)
	local e = 0.1
	local slopeX = (surfaceDepth(x + e, y) - surfaceDepth(x - e, y)) / (2 * e)
	local slopeY = (surfaceDepth(x, y + e) - surfaceDepth(x, y - e)) / (2 * e)
	local normal = Vector3.new(-slopeX, -slopeY, -1).Unit
	local surface = Vector3.new(x, y, -surfaceDepth(x, y))
	local frame = CFrame.lookAt(surface, surface + normal)

	local front, back = -math.huge, math.huge
	for _, dx in { -w / 2, 0, w / 2 } do
		for _, dy in { -h / 2, 0, h / 2 } do
			local onPlane = frame * Vector3.new(dx, dy, 0)
			local height = surfaceDistance(onPlane - normal, normal) - 1 -- skin height above the plane
			front = math.max(front, height)
			back = math.min(back, height)
		end
	end
	front += 0.06
	back -= 0.3
	return frame * CFrame.new(0, 0, -(front + back) / 2), front - back
end

local PUMPKIN_FACE = {}

-- Two wedges side by side make a triangle pointing up.
local function addTriangle(x, y, w, h)
	local cframe, thickness = faceSlab(x, y, w, h)
	local size = Vector3.new(thickness, h, w / 2)
	table.insert(PUMPKIN_FACE, { class = "WedgePart", size = size, cframe = cframe * CFrame.new(-w / 4, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), glow = true })
	table.insert(PUMPKIN_FACE, { class = "WedgePart", size = size, cframe = cframe * CFrame.new(w / 4, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0), glow = true })
end

local function addBlock(x, y, w, h)
	local cframe, thickness = faceSlab(x, y, w, h)
	table.insert(PUMPKIN_FACE, { class = "Part", size = Vector3.new(w, h, thickness), cframe = cframe, glow = true })
	return cframe, thickness
end

addTriangle(-0.8, 0.35, 0.95, 0.85) -- eyes
addTriangle(0.8, 0.35, 0.95, 0.85)
addTriangle(0, -0.12, 0.5, 0.42) -- nose
-- The grin is three segments so it can follow the curve, plus raised corners.
local mouthCFrame, mouthThickness = addBlock(0, -0.78, 1.1, 0.42)
addBlock(-0.92, -0.74, 0.75, 0.42)
addBlock(0.92, -0.74, 0.75, 0.42)
addBlock(-1.25, -0.56, 0.4, 0.4)
addBlock(1.25, -0.56, 0.4, 0.4)
for _, tooth in { Vector2.new(-0.3, 0.11), Vector2.new(0.3, 0.11), Vector2.new(0, -0.11) } do
	-- Uncarved notches sitting just in front of the glowing mouth.
	table.insert(PUMPKIN_FACE, {
		class = "Part",
		size = Vector3.new(0.3, 0.2, mouthThickness),
		cframe = mouthCFrame * CFrame.new(tooth.X, tooth.Y, -0.04),
		glow = false,
	})
end

local function addPumpkin(ground, yaw, scale, rng)
	local s = scale
	local model = Instance.new("Model")
	model.Name = "Pumpkin"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local pivot = CFrame.new(ground + Vector3.new(0, LOBE_SIZE.Y / 2 * s, 0)) * CFrame.Angles(0, yaw, 0)
	local body
	for i, angle in LOBE_ANGLES do
		local lobe = newPart(model, i == 1 and "Body" or "Lobe", ghostly({
			Size = LOBE_SIZE * s,
			CFrame = pivot * CFrame.Angles(0, angle, 0),
			Color = COLORS.Pumpkin,
			Material = Enum.Material.SmoothPlastic,
		}))
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = lobe
		body = body or lobe
	end

	newPart(model, "Stem", ghostly({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 0.55, 0.55) * s,
		CFrame = pivot * CFrame.new(0, 1.95 * s, 0) * CFrame.Angles(0.2, 0, 0) * UPRIGHT,
		Color = COLORS.Stem,
		Material = Enum.Material.Wood,
	}))

	for _, piece in PUMPKIN_FACE do
		local part = newPart(model, piece.glow and "Glow" or "Tooth", ghostly({
			Size = piece.size * s,
			CFrame = pivot * scaled(piece.cframe, s),
			Color = piece.glow and COLORS.PumpkinGlow or COLORS.Pumpkin,
			Material = piece.glow and Enum.Material.Neon or Enum.Material.SmoothPlastic,
		}), piece.class)
		if piece.glow then
			part:SetAttribute("Glow", true)
		end
	end

	local candle = Instance.new("PointLight")
	candle.Color = COLORS.CandleLight
	candle.Brightness = 1.6
	candle.Range = 10 * s
	candle.Shadows = false
	candle.Parent = body

	model.PrimaryPart = body
	model:SetAttribute("Phase", rng:NextNumber(0, math.pi * 2))
	model:SetAttribute("Speed", rng:NextNumber(2.2, 3.2))
	model:SetAttribute("Hop", 0.8 * s)
	model:AddTag("HalloweenPumpkin")
	model.Parent = world
end

---------------------------------------------------------------- island

local function addGravestone(parent, ground, yaw, tilt)
	local base = CFrame.new(ground) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(tilt, 0, 0)
	newPart(parent, "Gravestone", {
		Size = Vector3.new(2.6, 2.8, 0.7),
		CFrame = base * CFrame.new(0, 1.2, 0),
		Material = Enum.Material.Slate,
		Color = COLORS.Grave,
	})
	newPart(parent, "GravestoneTop", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.7, 2.6, 2.6),
		CFrame = base * CFrame.new(0, 2.6, 0) * FACING,
		Material = Enum.Material.Slate,
		Color = COLORS.Grave,
	})
	newPart(parent, "GraveDirt", {
		Size = Vector3.new(2.4, 0.4, 4),
		CFrame = CFrame.new(ground) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0.1, -2.4),
		Material = Enum.Material.Ground,
		Color = COLORS.Dirt,
	})
end

local function addDeadTree(parent, ground, rng)
	local base = CFrame.new(ground)
		* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		* CFrame.Angles(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.12, 0.12))
	local height = rng:NextNumber(11, 16)
	local bark = { Material = Enum.Material.Wood, Color = COLORS.Wood }
	local trunk = table.clone(bark)
	trunk.Size = Vector3.new(1.6, height, 1.6)
	trunk.CFrame = base * CFrame.new(0, height / 2 - 0.5, 0)
	newPart(parent, "Trunk", trunk)
	for b = 1, 3 do
		local length = rng:NextNumber(3.5, 6)
		local branch = table.clone(bark)
		branch.Size = Vector3.new(0.7, length, 0.7)
		branch.CFrame = base
			* CFrame.new(0, height * (0.5 + 0.15 * b), 0)
			* CFrame.Angles(0, b * 2.1 + rng:NextNumber(-0.4, 0.4), 0)
			* CFrame.Angles(0, 0, -rng:NextNumber(0.7, 1.1))
			* CFrame.new(0, length / 2, 0)
		newPart(parent, "Branch", branch)
	end
end

local function addPad(parent, name, groundCFrame, glowColor)
	local function disc(partName, height, diameter, material, color)
		return newPart(parent, partName, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, diameter, diameter),
			CFrame = groundCFrame * CFrame.new(0, height / 2, 0) * UPRIGHT,
			Material = material,
			Color = color,
		})
	end
	disc(name .. "Base", 0.5, 15, Enum.Material.Slate, COLORS.Stone)
	local glow = disc(name .. "Glow", 0.56, 13, Enum.Material.Neon, glowColor)
	local inner = disc(name .. "Inner", 0.62, 11.6, Enum.Material.Slate, COLORS.Stone)
	return glow, inner
end

local occupied = {}

-- A random spot on solid ground that isn't crowding anything else placed.
local function freeSpot(rng, center, minRadius, maxRadius, spacing)
	for _ = 1, 30 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(minRadius, maxRadius)
		local ground = findGround(center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius))
		if ground then
			local crowded = false
			for _, other in occupied do
				if ((other - ground) * Vector3.new(1, 0, 1)).Magnitude < spacing then
					crowded = true
					break
				end
			end
			if not crowded then
				table.insert(occupied, ground)
				return ground
			end
		end
	end
	return nil
end

-- Returns where players land, and the ground point decorations circle around.
local function setUpDestination()
	local rng = Random.new(2026)
	local custom = Workspace:FindFirstChild(CONFIG.DestinationPartName, true)
	local destination, center

	if custom and custom:IsA("BasePart") then
		local position = custom.Position + Vector3.new(0, custom.Size.Y / 2 + 3.5, 0)
		destination = CFrame.lookAt(position, position + flatLook(custom.CFrame))
		center = custom.Position + Vector3.new(0, custom.Size.Y / 2, 0)
		table.insert(occupied, center)
	else
		center = CONFIG.IslandCenter
		local island = Instance.new("Model")
		island.Name = "HalloweenIsland"
		newPart(island, "Ground", {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(6, 170, 170),
			CFrame = CFrame.new(center - Vector3.new(0, 3, 0)) * UPRIGHT,
			Material = Enum.Material.Grass,
			Color = COLORS.Grass,
		})
		for i, diameter in { 150, 116, 80, 44 } do
			newPart(island, "Rock", {
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(10, diameter, diameter),
				CFrame = CFrame.new(center - Vector3.new(0, 1 + i * 9, 0)) * UPRIGHT,
				Material = Enum.Material.Rock,
				Color = COLORS.Rock,
			})
		end
		addPad(island, "Arrival", CFrame.new(center), COLORS.Purple)
		island.Parent = world -- parented before decorating so the ground raycasts can find it
		table.insert(occupied, center)

		local props = Instance.new("Model")
		props.Name = "Props"
		props.Parent = island
		table.insert(noLanding, props)

		for _ = 1, 9 do
			local ground = freeSpot(rng, center, 16, 62, 7)
			if ground then
				addGravestone(props, ground, rng:NextNumber(-0.5, 0.5) + math.pi, rng:NextNumber(-0.12, 0.12))
			end
		end
		for _ = 1, 5 do
			local ground = freeSpot(rng, center, 22, 70, 12)
			if ground then
				addDeadTree(props, ground, rng)
			end
		end
		destination = CFrame.new(center + Vector3.new(0, 3.5, 0))
	end

	-- Four small pumpkins frame the landing spot, the rest are scattered.
	for i = 1, 4 do
		local angle = math.rad(45 + i * 90)
		local ground = findGround(center + Vector3.new(math.cos(angle) * 9.5, 0, math.sin(angle) * 9.5))
		if ground then
			addPumpkin(ground, math.atan2(math.cos(angle), math.sin(angle)), 0.8, rng)
		end
	end
	for _ = 5, CONFIG.IslandPumpkins do
		local ground = freeSpot(rng, center, 12, 60, 6)
		if ground then
			addPumpkin(ground, rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.8, 1.4), rng)
		end
	end
	for _ = 1, CONFIG.IslandGhosts do
		addGhost(center, rng:NextNumber(15, 55), rng:NextNumber(6, 14), rng:NextNumber(0.9, 1.5), rng)
	end

	return destination
end

---------------------------------------------------------------- portal

-- The ground spot in front of the spawn, facing the spawn.
local function findBuildSpot()
	local marker = Workspace:FindFirstChild(CONFIG.BuildSpotPartName, true)
	if marker and marker:IsA("BasePart") then
		marker.Transparency = 1
		marker.CanCollide = false
		marker.CanQuery = false
		local position = marker.Position - Vector3.new(0, marker.Size.Y / 2, 0)
		return CFrame.lookAt(position, position + flatLook(marker.CFrame))
	end

	local spawnCFrame = CFrame.new(0, 0, 0)
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") then
			spawnCFrame = descendant.CFrame * CFrame.new(0, descendant.Size.Y / 2, 0)
			break
		end
	end
	local guess = spawnCFrame.Position + flatLook(spawnCFrame) * CONFIG.BuildSpotDistance
	local ground = findGround(guess) or guess
	local spawnPosition = spawnCFrame.Position
	return CFrame.lookAt(ground, Vector3.new(spawnPosition.X, ground.Y, spawnPosition.Z))
end

local function timings()
	local openAt = (CONFIG.RingPieces - 1) * CONFIG.PieceDelay + CONFIG.FlyTime + CONFIG.LightTime
	return openAt + CONFIG.OpenTime
end

-- Every part starts invisible: the client flies the pieces in and lights
-- them up, then finishPortal makes the end result solid for everyone.
local function buildPortal(groundCFrame)
	local radius = CONFIG.PortalRadius
	local count = CONFIG.RingPieces
	local center = groundCFrame * CFrame.new(0, radius - 1.2, 0) -- the bottom of the ring sinks into the ground

	local portal = Instance.new("Model")
	portal.Name = "HalloweenPortal"
	portal.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	portal:SetAttribute("BuildStart", Workspace:GetServerTimeNow())
	portal:SetAttribute("PieceDelay", CONFIG.PieceDelay)
	portal:SetAttribute("FlyTime", CONFIG.FlyTime)
	portal:SetAttribute("LightTime", CONFIG.LightTime)
	portal:SetAttribute("OpenTime", CONFIG.OpenTime)
	portal:SetAttribute("PortalCFrame", center)
	portal:SetAttribute("GroundY", groundCFrame.Y)

	-- Pieces fly in lowest first, so the ring builds up from the ground.
	local slots = {}
	for i = 1, count do
		table.insert(slots, { ring = i, angle = (i - 0.5) / count * math.pi * 2 })
	end
	table.sort(slots, function(a, b)
		return math.sin(a.angle) < math.sin(b.angle)
	end)

	local pieces = Instance.new("Folder")
	pieces.Name = "Pieces"
	pieces.Parent = portal
	local length = 2 * (radius + 0.95) * math.sin(math.pi / count) * 1.02
	for order, slot in slots do
		local piece = Instance.new("Model")
		piece.Name = string.format("Piece%02d", order)
		piece:SetAttribute("Index", order)
		local stoneCFrame = center * CFrame.Angles(0, 0, slot.angle) * CFrame.new(radius, 0, 0)
		local stone = newPart(piece, "Stone", {
			Size = Vector3.new(1.9, length, 2.3),
			CFrame = stoneCFrame,
			Material = Enum.Material.Slate,
			Color = COLORS.Stone,
			Transparency = 1,
			CanCollide = false,
		})
		stone:SetAttribute("FinalTransparency", 0)
		stone:SetAttribute("Solid", true)
		local rune = newPart(piece, "Rune", ghostly({
			Size = Vector3.new(0.4, length * 0.8, 2.5),
			CFrame = stoneCFrame * CFrame.new(-0.95, 0, 0),
			Material = Enum.Material.Neon,
			Color = slot.ring % 2 == 0 and COLORS.Orange or COLORS.Purple,
			Transparency = 1,
		}))
		rune:SetAttribute("FinalTransparency", 0)
		if slot.ring % 2 == 0 then
			local spike = newPart(piece, "Spike", {
				Size = Vector3.new(1.3, 1.3, 1.6),
				CFrame = stoneCFrame * CFrame.new(1.05, 0, 0) * CFrame.Angles(0, 0, math.rad(45)),
				Material = Enum.Material.Slate,
				Color = COLORS.Stone,
				Transparency = 1,
				CanCollide = false,
			})
			spike:SetAttribute("FinalTransparency", 0)
			spike:SetAttribute("Solid", true)
		end
		piece.PrimaryPart = stone
		piece.Parent = pieces
	end

	local core = newPart(portal, "Core", ghostly({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, radius * 2 - 1.4, radius * 2 - 1.4),
		CFrame = center * FACING,
		Material = Enum.Material.Neon,
		Color = COLORS.Core,
		Transparency = 1,
	}))
	core:SetAttribute("FinalTransparency", 0.3)
	local glow = Instance.new("PointLight")
	glow.Color = COLORS.Purple
	glow.Brightness = 3
	glow.Range = 22
	glow.Enabled = false
	glow.Parent = core
	local sparkPoint = Instance.new("Attachment")
	sparkPoint.Parent = core
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.EmissionDirection = Enum.NormalId.Right -- out of the portal's front
	sparks.Color = ColorSequence.new(COLORS.Orange, COLORS.Purple)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.6, 0)
	sparks.Transparency = NumberSequence.new(0.1, 1)
	sparks.Lifetime = NumberRange.new(1, 1.6)
	sparks.Speed = NumberRange.new(4, 7)
	sparks.SpreadAngle = Vector2.new(35, 35)
	sparks.Drag = 1
	sparks.Rate = 30
	sparks.Enabled = false
	sparks.Parent = sparkPoint

	-- Three spiral arms of glowing bits; the client spins them.
	local swirl = Instance.new("Folder")
	swirl.Name = "Swirl"
	swirl.Parent = portal
	for arm = 1, 3 do
		for j = 1, 10 do
			local bitRadius = 1 + (j - 1) * (radius - 2.4) / 9
			local angle = (arm - 1) * math.pi * 2 / 3 + bitRadius * 0.33
			local bit = newPart(swirl, "SwirlBit", ghostly({
				Size = Vector3.new(0.45, 0.4 + bitRadius * 0.24, 0.6),
				CFrame = center * CFrame.Angles(0, 0, angle) * CFrame.new(bitRadius, 0, 0),
				Material = Enum.Material.Neon,
				Color = arm == 2 and COLORS.Purple or COLORS.Orange,
				Transparency = 1,
			}))
			bit:SetAttribute("Angle", angle)
			bit:SetAttribute("Radius", bitRadius)
			bit:SetAttribute("FinalTransparency", 0.15)
		end
	end

	local trigger = newPart(portal, "Trigger", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, radius * 2 - 2.4, radius * 2 - 2.4),
		CFrame = center * FACING,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})

	portal:AddTag("HalloweenPortal")
	portal.Parent = world
	table.insert(noLanding, portal)
	return portal, trigger, center
end

local function finishPortal(portal)
	for _, part in portal:GetDescendants() do
		if part:IsA("BasePart") then
			local final = part:GetAttribute("FinalTransparency")
			if final then
				part.Transparency = final
			end
			if part:GetAttribute("Solid") then
				part.CanCollide = true
			end
		end
	end
	portal.Core.PointLight.Enabled = true
	portal.Core.Attachment.Sparks.Enabled = true
	portal.Trigger.CanTouch = true
	portal:SetAttribute("Open", true)
end

---------------------------------------------------------------- travel

local destination = setUpDestination()
local spot = findBuildSpot()
local portalGround = spot * CFrame.new(0, 0, 9) -- just behind the pad, away from spawn
portalGround = CFrame.new(findGround(portalGround.Position) or portalGround.Position) * portalGround.Rotation

local spotModel = Instance.new("Model")
spotModel.Name = "BuildSpot"
local spotGlow, spotInner = addPad(spotModel, "Pad", spot, COLORS.Orange)
local spotLight = Instance.new("PointLight")
spotLight.Color = COLORS.Orange
spotLight.Brightness = 2
spotLight.Range = 16
spotLight.Parent = spotInner
local rising = Instance.new("ParticleEmitter")
rising.EmissionDirection = Enum.NormalId.Right -- the pad is a cylinder on its side, so +X points up
rising.Color = ColorSequence.new(COLORS.Orange, COLORS.Purple)
rising.LightEmission = 1
rising.Size = NumberSequence.new(0.35, 0)
rising.Lifetime = NumberRange.new(1.5, 2.5)
rising.Speed = NumberRange.new(2, 4)
rising.Rate = 10
rising.Parent = spotGlow
local promptPoint = Instance.new("Attachment")
promptPoint.Parent = spotInner
promptPoint.WorldCFrame = spot * CFrame.new(0, 3, 0)
local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "Build"
prompt.ObjectText = "Halloween Portal"
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 14
prompt.RequiresLineOfSight = false
prompt.Parent = promptPoint
spotModel.Parent = world
table.insert(noLanding, spotModel)

local travelling = {} -- [player] = trip in progress

local function finishTrip(player, trip)
	if travelling[player] ~= trip then
		return
	end
	travelling[player] = nil
	local root = trip.character:FindFirstChild("HumanoidRootPart")
	if root then
		if player.Character == trip.character then
			trip.character:PivotTo(destination)
			root.AssemblyLinearVelocity = Vector3.zero
		end
		root.Anchored = false
	end
	remote:FireClient(player, "Arrived", CONFIG.WorldTitle)
end

local function tryFinish(player, trip)
	if trip.ready and trip.streamed then
		finishTrip(player, trip)
	end
end

local function startTrip(player, portalCenter)
	if travelling[player] then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root) or humanoid.Health <= 0 then
		return
	end

	local trip = { character = character }
	travelling[player] = trip
	root.Anchored = true -- hold still while the screen effect plays
	remote:FireClient(player, "Enter", portalCenter)

	-- Load the island around the player before they land on it.
	task.spawn(function()
		pcall(player.RequestStreamAroundAsync, player, destination.Position, 4)
		trip.streamed = true
		tryFinish(player, trip)
	end)
	task.delay(ENTRY_TIMEOUT, finishTrip, player, trip)
end

remote.OnServerEvent:Connect(function(player, action)
	local trip = travelling[player]
	if action == "Ready" and trip then
		trip.ready = true -- the client's screen is black
		tryFinish(player, trip)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	travelling[player] = nil
end)

local portalBuilt = false
prompt.Triggered:Connect(function()
	if portalBuilt then
		return
	end
	portalBuilt = true
	prompt.Enabled = false
	rising.Enabled = false

	local portal, trigger, center = buildPortal(portalGround)
	task.wait(timings())
	finishPortal(portal)

	trigger.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if player then
			startTrip(player, center)
		end
	end)

	local rng = Random.new()
	for _, offset in { Vector3.new(-12.5, 0, -2), Vector3.new(12.5, 0, -2), Vector3.new(-15, 0, 3), Vector3.new(15, 0, 3) } do
		local ground = findGround((portalGround * CFrame.new(offset)).Position)
		if ground then
			addPumpkin(ground, select(2, portalGround:ToOrientation()) + rng:NextNumber(-0.4, 0.4), rng:NextNumber(0.8, 1.2), rng)
		end
	end
	for _ = 1, CONFIG.PortalGhosts do
		addGhost(portalGround.Position, rng:NextNumber(13, 20), rng:NextNumber(5, 11), rng:NextNumber(0.9, 1.3), rng)
	end
end)
