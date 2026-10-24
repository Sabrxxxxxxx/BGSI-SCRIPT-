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

	PieceDelay = 0.1, -- seconds between arch stones taking off
	FlyTime = 0.8, -- seconds each piece takes to fly into place
	LightTime = 0.35, -- seconds each piece takes to light up after landing
	OpenTime = 1.4, -- seconds the center takes to swirl open
	GateReopenTime = 12, -- seconds the fence gate stays shut behind you

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
	DarkStone = Color3.fromRGB(40, 35, 52),
	Vortex = Color3.fromRGB(150, 70, 255),
	Iron = Color3.fromRGB(30, 28, 36),
	Banner = Color3.fromRGB(78, 32, 128),
	BannerGhost = Color3.fromRGB(226, 214, 255),
	Flame = Color3.fromRGB(255, 170, 60),
	Wax = Color3.fromRGB(238, 228, 200),
	Bone = Color3.fromRGB(225, 215, 190),
	Web = Color3.fromRGB(230, 230, 240),
	Tuft = Color3.fromRGB(66, 86, 42),
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

local function addPumpkin(ground, yaw, scale, rng, still)
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
	model:SetAttribute("Hop", still and 0 or 0.8 * s)
	model:SetAttribute("Wobble", still and 0.25 or 1)
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

-- The portal stands on three steps (0.6 studs each). Everything below is laid
-- out in the portal's own frame: x sideways, y up from the ground, -z towards spawn.
local ARCH = {
	OpeningWidth = 10,
	OpeningHeight = 15,
	DaisHeight = 1.8,
}
local FENCE = {
	Front = -30, -- the gate side, towards spawn
	Back = 14,
	HalfWidth = 28,
	GateHalfWidth = 7,
}

-- A part stretched from a to b: branches, cobweb threads, gate rails.
local function limb(parent, name, a, b, width, props)
	local up = Vector3.yAxis
	if math.abs((b - a).Unit:Dot(up)) > 0.999 then
		up = Vector3.xAxis -- lookAt needs an up direction that isn't along the limb
	end
	props.Size = Vector3.new(width, width, (b - a).Magnitude)
	props.CFrame = CFrame.lookAt((a + b) / 2, b, up)
	return newPart(parent, name, props)
end

-- Two wedges side by side: a triangle facing -z, apex up (or down when flipped).
local function triangle(parent, name, frame, width, height, thickness, props)
	for _, side in { -1, 1 } do
		local half = table.clone(props)
		half.Size = Vector3.new(thickness, height, width / 2)
		half.CFrame = frame * CFrame.new(side * width / 4, 0, 0) * CFrame.Angles(0, -side * math.pi / 2, 0)
		newPart(parent, name, half, "WedgePart")
	end
end

-- Everything around the portal that is there from the start: the steps, dead
-- trees with lanterns, candles, a skull, cobwebs, rocks, and the iron fence
-- whose gate slams shut behind you. Lights marked OnOpen come on with the portal.
local function buildSite(base, rng)
	local site = Instance.new("Model")
	site.Name = "PortalSite"
	site.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	local function toWorld(v)
		return (base * CFrame.new(v)).Position
	end

	-- Steps up to the portal.
	for k = 1, 3 do
		local width = 24 - 3 * (k - 1)
		local front = -7.4 + 1.8 * (k - 1)
		local back = 4
		local height = 0.6 * k
		newPart(site, "Step", {
			Size = Vector3.new(width, height, back - front),
			CFrame = at(0, height / 2, (front + back) / 2),
			Material = Enum.Material.Slate,
			Color = COLORS.DarkStone:Lerp(COLORS.Stone, (k - 1) / 2),
		})
	end

	-- Dead trees either side, with a lantern hanging from each.
	local bark = { Material = Enum.Material.Wood, Color = COLORS.Wood }
	for _, s in { -1, 1 } do
		local function branch(points, widths)
			for i = 1, #points - 1 do
				local a = toWorld(points[i] * Vector3.new(s, 1, 1))
				local b = toWorld(points[i + 1] * Vector3.new(s, 1, 1))
				limb(site, "Branch", a, b, widths[i], table.clone(bark))
				if i > 1 then
					newPart(site, "Knot", {
						Shape = Enum.PartType.Ball,
						Size = Vector3.one * widths[i],
						CFrame = CFrame.new(a),
						Material = bark.Material,
						Color = bark.Color,
					})
				end
			end
		end
		local V = Vector3.new
		branch({ V(12.6, -0.5, 2.5), V(13.4, 6, 2.8), V(12.4, 11, 2.4), V(12.9, 15, 2.0) }, { 2.2, 1.7, 1.2 })
		branch({ V(12.4, 11, 2.4), V(10.6, 14.6, 0.4), V(9.4, 16.6, -0.6), V(8.9, 18.4, -0.8) }, { 0.8, 0.55, 0.35 })
		branch({ V(12.9, 15, 2.0), V(15.6, 18.4, 2.6), V(17.0, 20.8, 2.0), V(16.4, 22.6, 1.6) }, { 0.7, 0.45, 0.3 })
		branch({ V(13.4, 6, 2.8), V(16.2, 8.8, 3.4), V(17.6, 11.2, 3.0) }, { 0.6, 0.35 })
		branch({ V(12.9, 15, 2.0), V(12.2, 18.5, 1.6) }, { 0.5 })
		branch({ V(12.6, 0.4, 2.5), V(14.8, -0.2, 3.8) }, { 0.9 })
		branch({ V(12.6, 0.4, 2.5), V(11.0, -0.2, 4.4) }, { 0.8 })

		-- Lantern on a chain from the branch.
		local x, z, top = s * 10.4, 0, 14.9
		for i = 1, 4 do
			newPart(site, "ChainLink", ghostly({
				Size = Vector3.new(0.12, 0.62, 0.36),
				CFrame = at(x, top - 0.3 - (i - 1) * 0.6, z) * CFrame.Angles(0, i % 2 == 0 and math.pi / 2 or 0, 0),
				Material = Enum.Material.Metal,
				Color = COLORS.Iron,
			}))
		end
		local y0 = top - 2.6
		local iron = { Material = Enum.Material.Metal, Color = COLORS.Iron }
		local function ironPart(name, size, cframe)
			local props = ghostly(table.clone(iron))
			props.Size = size
			props.CFrame = cframe
			return newPart(site, name, props)
		end
		ironPart("LanternCap", Vector3.new(1.5, 0.3, 1.5), at(x, y0 - 0.15, z))
		ironPart("LanternKnob", Vector3.new(0.5, 0.4, 0.5), at(x, y0 + 0.1, z))
		ironPart("LanternBase", Vector3.new(1.3, 0.25, 1.3), at(x, y0 - 2.1, z))
		for _, corner in { Vector3.new(1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(-1, 0, -1) } do
			ironPart("LanternPost", Vector3.new(0.16, 1.7, 0.16), at(x + corner.X * 0.55, y0 - 1.15, z + corner.Z * 0.55))
		end
		local glass = newPart(site, "LanternGlass", ghostly({
			Size = Vector3.new(1, 1.6, 1),
			CFrame = at(x, y0 - 1.15, z),
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(90, 60, 30),
			Transparency = 0.2,
		}))
		glass:SetAttribute("LitColor", COLORS.Flame)
		glass:AddTag("HalloweenFlame")
		local light = Instance.new("PointLight")
		light.Color = COLORS.Flame
		light.Brightness = 2.4
		light.Range = 16
		light.Enabled = false
		light:SetAttribute("OnOpen", true)
		light.Parent = glass
	end

	-- Candles at the foot of the pillars and on the bottom step.
	local function candle(x, y, z, height, radius, withLight)
		newPart(site, "Candle", ghostly({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, radius * 2, radius * 2),
			CFrame = at(x, y + height / 2, z) * UPRIGHT,
			Material = Enum.Material.SmoothPlastic,
			Color = COLORS.Wax,
		}))
		local flame = newPart(site, "Flame", ghostly({
			Size = Vector3.new(0.28, 0.6, 0.28),
			CFrame = at(x, y + height + 0.35, z),
			Material = Enum.Material.Neon,
			Color = COLORS.Flame,
			Transparency = 1,
		}))
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = flame
		flame:SetAttribute("OnOpenTransparency", 0)
		flame:AddTag("HalloweenFlame")
		if withLight then
			local light = Instance.new("PointLight")
			light.Color = COLORS.Flame
			light.Brightness = 1.6
			light.Range = 10
			light.Enabled = false
			light:SetAttribute("OnOpen", true)
			light.Parent = flame
		end
	end
	for _, s in { -1, 1 } do
		candle(s * 6.0, 1.8, -2.6, 2.2, 0.38, true)
		candle(s * 6.85, 1.8, -2.35, 1.4, 0.32)
		candle(s * 5.25, 1.8, -2.15, 1.0, 0.3)
	end
	candle(-10.2, 0.6, -6.0, 1.6, 0.34, true)
	candle(-9.5, 0.6, -5.7, 0.9, 0.28)
	candle(10.4, 0.6, -6.4, 1.3, 0.32, true)
	candle(9.7, 0.6, -6.1, 0.8, 0.28)

	-- A skull on the bottom step.
	local skull = at(8.4, 0.6 + 0.65, -6.6) * CFrame.Angles(0, math.rad(20), 0)
	local bone = { Material = Enum.Material.SmoothPlastic, Color = COLORS.Bone }
	local function skullPart(name, shape, size, offset, color)
		local props = ghostly(table.clone(bone))
		props.Shape = shape
		props.Size = size
		props.CFrame = skull * offset
		props.Color = color or bone.Color
		return newPart(site, name, props)
	end
	skullPart("Skull", Enum.PartType.Ball, Vector3.one * 1.3, CFrame.new())
	skullPart("Jaw", Enum.PartType.Block, Vector3.new(0.85, 0.45, 0.75), CFrame.new(0, -0.55, -0.2))
	for _, s in { -1, 1 } do
		skullPart("EyeSocket", Enum.PartType.Ball, Vector3.one * 0.38, CFrame.new(s * 0.27, 0.05, -0.5), Color3.fromRGB(20, 16, 24))
	end
	skullPart("Nose", Enum.PartType.Block, Vector3.new(0.16, 0.22, 0.1), CFrame.new(0, -0.22, -0.62), Color3.fromRGB(20, 16, 24))

	-- Cobwebs: spokes from a corner joined by three rings of thread.
	local function cobweb(origin, fromDegrees, toDegrees, radius)
		local spokes = {}
		for i = 0, 4 do
			local a = math.rad(fromDegrees + (toDegrees - fromDegrees) * i / 4)
			spokes[i] = Vector3.new(math.cos(a), math.sin(a), 0)
		end
		local function thread(a, b)
			limb(site, "Cobweb", toWorld(a), toWorld(b), 0.06, ghostly({
				Material = Enum.Material.SmoothPlastic,
				Color = COLORS.Web,
				Transparency = 0.25,
			}))
		end
		for i = 0, 4 do
			thread(origin, origin + spokes[i] * radius)
		end
		for _, f in { 0.35, 0.65, 0.95 } do
			for i = 0, 3 do
				thread(origin + spokes[i] * radius * f, origin + spokes[i + 1] * radius * f)
			end
		end
	end
	cobweb(Vector3.new(-8.6, 17.9, -1.6), 180, 270, 2.6)
	cobweb(Vector3.new(8.6, 17.9, -1.6), 270, 360, 2.6)
	cobweb(Vector3.new(11.9, 10.8, 1.2), 180, 260, 2.2)
	cobweb(Vector3.new(-11.9, 10.8, 1.2), 280, 360, 2.2)

	-- Rocks and grass around the steps.
	local rockSpots = {
		Vector3.new(-12.2, 0, -2.4), Vector3.new(-14.6, 0, 1.2), Vector3.new(-11.6, 0, 5.6),
		Vector3.new(12.0, 0, -1.6), Vector3.new(14.8, 0, 0.6), Vector3.new(11.2, 0, 6.0),
		Vector3.new(-6, 0, 5.2), Vector3.new(5.4, 0, 5.4), Vector3.new(-17.2, 0, -8.2), Vector3.new(17.4, 0, -8.4),
	}
	for _, spot in rockSpots do
		local size = Vector3.new(rng:NextNumber(1.4, 3.2), rng:NextNumber(1.0, 2.2), rng:NextNumber(1.4, 3.0))
		newPart(site, "Rock", {
			Size = size,
			CFrame = at(spot.X, size.Y * 0.3, spot.Z)
				* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)),
			Material = Enum.Material.Slate,
			Color = COLORS.DarkStone:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.3)),
		})
		for _ = 1, 3 do
			local blade = rng:NextNumber(0.9, 1.4)
			newPart(site, "Grass", ghostly({
				Size = Vector3.new(0.14, blade, 0.4),
				CFrame = at(spot.X + rng:NextNumber(-1.8, 1.8), blade / 2 - 0.1, spot.Z + rng:NextNumber(-1.8, 1.8))
					* CFrame.Angles(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, math.pi), rng:NextNumber(-0.35, 0.35)),
				Material = Enum.Material.SmoothPlastic,
				Color = COLORS.Tuft,
			}))
		end
	end

	---------------------------------------------------- the fence
	local fence = Instance.new("Model")
	fence.Name = "Fence"
	fence.Parent = site
	local ironLook = { Material = Enum.Material.Metal, Color = COLORS.Iron }

	local pillarTops = {}
	local function fencePillar(x, z, height)
		local key = x .. "," .. z
		if pillarTops[key] then
			return
		end
		pillarTops[key] = true
		newPart(fence, "FencePillar", {
			Size = Vector3.new(2.4, height, 2.4),
			CFrame = at(x, height / 2, z),
			Material = Enum.Material.Slate,
			Color = COLORS.DarkStone,
		})
		newPart(fence, "FenceCap", {
			Size = Vector3.new(3, 0.8, 3),
			CFrame = at(x, height + 0.4, z),
			Material = Enum.Material.Slate,
			Color = COLORS.Stone,
		})
	end

	-- Spear-topped iron bars between two pillars, with one invisible wall to bump into.
	local function bars(a, b)
		local frame = base * CFrame.lookAt(a, b) -- -z runs along the fence
		local length = (b - a).Magnitude
		local count = math.floor(length / 1.6)
		local step = length / count
		for i = 1, count - 1 do
			local t = i * step
			local bar = ghostly(table.clone(ironLook))
			bar.Size = Vector3.new(0.3, 11, 0.3)
			bar.CFrame = frame * CFrame.new(0, 5.5, -t)
			newPart(fence, "Bar", bar)
			local tip = ghostly(table.clone(ironLook))
			tip.Size = Vector3.new(0.3, 0.6, 0.6)
			tip.CFrame = frame * CFrame.new(0, 11.25, -t) * CFrame.Angles(math.rad(45), 0, 0)
			newPart(fence, "Spike", tip)
		end
		for _, y in { 1.4, 9.8 } do
			local rail = ghostly(table.clone(ironLook))
			rail.Size = Vector3.new(0.25, 0.35, length)
			rail.CFrame = frame * CFrame.new(0, y, -length / 2)
			newPart(fence, "Rail", rail)
		end
		newPart(fence, "FenceWall", {
			Size = Vector3.new(0.8, 12, length),
			CFrame = frame * CFrame.new(0, 6, -length / 2),
			Transparency = 1,
			CanQuery = false,
			CastShadow = false,
		})
	end

	local F, B, W, G = FENCE.Front, FENCE.Back, FENCE.HalfWidth, FENCE.GateHalfWidth + 1.2
	local runs = {
		{ Vector3.new(-W, 0, F), Vector3.new(-18, 0, F), Vector3.new(-G, 0, F) },
		{ Vector3.new(G, 0, F), Vector3.new(18, 0, F), Vector3.new(W, 0, F) },
		{ Vector3.new(W, 0, F), Vector3.new(W, 0, -16), Vector3.new(W, 0, -2), Vector3.new(W, 0, B) },
		{ Vector3.new(W, 0, B), Vector3.new(14, 0, B), Vector3.new(0, 0, B), Vector3.new(-14, 0, B), Vector3.new(-W, 0, B) },
		{ Vector3.new(-W, 0, B), Vector3.new(-W, 0, -2), Vector3.new(-W, 0, -16), Vector3.new(-W, 0, F) },
	}
	for _, run in runs do
		for i, point in run do
			fencePillar(point.X, point.Z, math.abs(point.X) == G and 15 or 13)
			if i > 1 then
				bars(run[i - 1], point)
			end
		end
	end

	-- The gate: two tall leaves standing open, swung into the courtyard.
	local gateFrame = at(0, 0, F)
	for _, s in { -1, 1 } do
		local leaf = Instance.new("Model")
		leaf.Name = s < 0 and "GateLeft" or "GateRight"
		local hinge = at(s * FENCE.GateHalfWidth, 0, F)
		local openAngle = s * math.rad(88)
		local openFrame = hinge * CFrame.Angles(0, openAngle, 0)
		local function leafPart(name, size, offset, extra)
			local props = ghostly(table.clone(ironLook))
			props.Size = size
			props.CFrame = openFrame * offset
			for key, value in extra or {} do
				props[key] = value
			end
			return newPart(leaf, name, props)
		end
		local function across(d, y)
			return CFrame.new(-s * d, y, 0) -- d studs from the hinge towards the middle
		end
		local function barHeight(d)
			return 11 + 2.5 * (d / FENCE.GateHalfWidth) ^ 1.5 -- the top curves up towards the middle
		end

		leafPart("Stile", Vector3.new(0.5, 13, 0.5), across(0.3, 6.5))
		local latchHeight = barHeight(6.75)
		leafPart("Stile", Vector3.new(0.5, latchHeight, 0.5), across(6.75, latchHeight / 2))
		local tops = {}
		for i = 0, 6 do
			local d = 1.0 + i * 0.85
			local h = barHeight(d)
			leafPart("Bar", Vector3.new(0.3, h, 0.3), across(d, h / 2))
			leafPart("Spike", Vector3.new(0.55, 0.55, 0.3), across(d, h + 0.25) * CFrame.Angles(0, 0, math.rad(45)))
			table.insert(tops, (openFrame * across(d, h - 0.8)).Position)
		end
		for _, y in { 1.2, 6.2 } do
			leafPart("Rail", Vector3.new(FENCE.GateHalfWidth, 0.4, 0.3), across(FENCE.GateHalfWidth / 2, y))
		end
		for i = 1, #tops - 1 do
			limb(leaf, "Rail", tops[i], tops[i + 1], 0.3, ghostly(table.clone(ironLook)))
		end
		leafPart("Collider", Vector3.new(FENCE.GateHalfWidth, 13, 0.6), across(FENCE.GateHalfWidth / 2, 6.5), {
			Transparency = 1,
			CanCollide = true,
		})

		leaf:SetAttribute("GateId", "Front")
		leaf:SetAttribute("Hinge", hinge)
		leaf:SetAttribute("OpenAngle", openAngle)
		leaf:SetAttribute("GateFrame", gateFrame)
		leaf:SetAttribute("CourtDepth", B - F)
		leaf:SetAttribute("CourtHalfWidth", W)
		leaf:SetAttribute("ReopenAfter", CONFIG.GateReopenTime)
		leaf:AddTag("HalloweenGate")
		leaf.Parent = fence
	end

	site.Parent = world
	return site
end

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

local function timings(count)
	local openAt = (count - 1) * CONFIG.PieceDelay + CONFIG.FlyTime + CONFIG.LightTime
	return openAt + CONFIG.OpenTime
end

-- Every part starts invisible: the client flies the stones in and lights
-- them up, then finishPortal makes the end result solid for everyone.
local function buildPortal(base)
	local width, height, dais = ARCH.OpeningWidth, ARCH.OpeningHeight, ARCH.DaisHeight
	local center = base * CFrame.new(0, dais + height / 2, 0)
	local rng = Random.new(31)

	local portal = Instance.new("Model")
	portal.Name = "HalloweenPortal"
	portal.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	portal:SetAttribute("BuildStart", Workspace:GetServerTimeNow())
	portal:SetAttribute("PieceDelay", CONFIG.PieceDelay)
	portal:SetAttribute("FlyTime", CONFIG.FlyTime)
	portal:SetAttribute("LightTime", CONFIG.LightTime)
	portal:SetAttribute("OpenTime", CONFIG.OpenTime)
	portal:SetAttribute("PortalCFrame", center)
	portal:SetAttribute("GroundY", base.Y)
	portal:SetAttribute("SwirlScaleX", 1)
	portal:SetAttribute("SwirlScaleY", 1.55) -- the vortex is tall, so the swirl is an upright oval

	-- The stone arch: plinths, two pillars, the header over the opening, the
	-- lintel and a broken crown. rune = which face glows purple.
	local stones = {}
	local function stone(cframe, size, rune)
		table.insert(stones, { cframe = cframe, size = size, rune = rune })
	end
	local function tilt(amount)
		return CFrame.Angles(rng:NextNumber(-amount, amount), rng:NextNumber(-amount, amount), rng:NextNumber(-amount, amount))
	end
	local inner = width / 2
	local top = dais + height
	for _, s in { -1, 1 } do
		stone(base * CFrame.new(s * 6.6, dais + 0.7, 0), Vector3.new(4.2, 1.4, 3.6))
		local y = dais + 1.4
		local blockHeight = (top - y) / 5
		for i = 1, 5 do
			local w = i % 2 == 1 and 3.2 or 2.9
			stone(
				base * CFrame.new(s * (inner + w / 2 + rng:NextNumber(0, 0.12)), y + blockHeight / 2, 0) * tilt(0.03),
				Vector3.new(w, blockHeight - 0.08, i % 2 == 1 and 2.8 or 2.6),
				s
			)
			y += blockHeight
		end
		stone(base * CFrame.new(s * 6.6, top + 0.6, 0), Vector3.new(4.0, 1.2, 3.4))
		stone(base * CFrame.new(s * (inner - 0.6), top - 0.6, 0) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(1.7, 1.7, 2.4))
	end
	for _, x in { -3.34, 0, 3.34 } do
		stone(base * CFrame.new(x, top + 0.6, 0) * tilt(0.02), Vector3.new(3.3, 1.16, 2.6), "under")
	end
	for _, x in { -6.88, -3.44, 0, 3.44, 6.88 } do
		local h = rng:NextNumber(2.2, 2.5)
		stone(base * CFrame.new(x, top + 1.2 + h / 2, 0) * tilt(0.03), Vector3.new(3.4, h, 3.0))
	end
	for _, crown in { { -7.0, 2.6, 2.0 }, { -4.3, 2.4, 1.4 }, { 4.3, 2.4, 1.6 }, { 7.0, 2.6, 2.2 } } do
		stone(base * CFrame.new(crown[1], top + 3.6 + crown[3] / 2, 0) * tilt(0.08), Vector3.new(crown[2], crown[3], 2.6))
	end

	-- Stones fly in lowest first, so the arch builds up from the ground.
	table.sort(stones, function(a, b)
		return a.cframe.Y < b.cframe.Y
	end)
	local pieces = Instance.new("Folder")
	pieces.Name = "Pieces"
	pieces.Parent = portal
	for order, data in stones do
		local piece = Instance.new("Model")
		piece.Name = string.format("Piece%02d", order)
		piece:SetAttribute("Index", order)
		local stonePart = newPart(piece, "Stone", {
			Size = data.size,
			CFrame = data.cframe,
			Material = Enum.Material.Slate,
			Color = COLORS.Stone:Lerp(COLORS.DarkStone, rng:NextNumber()),
			Transparency = 1,
			CanCollide = false,
		})
		stonePart:SetAttribute("FinalTransparency", 0)
		stonePart:SetAttribute("Solid", true)
		if data.rune then
			local offset, size
			if data.rune == "under" then
				offset = CFrame.new(0, -data.size.Y / 2 - 0.02, 0)
				size = Vector3.new(data.size.X * 0.85, 0.22, data.size.Z * 0.7)
			else
				offset = CFrame.new(-data.rune * (data.size.X / 2 + 0.02), 0, 0)
				size = Vector3.new(0.22, data.size.Y * 0.85, data.size.Z * 0.7)
			end
			local rune = newPart(piece, "Rune", ghostly({
				Size = size,
				CFrame = data.cframe * offset,
				Material = Enum.Material.Neon,
				Color = COLORS.Vortex,
				Transparency = 1,
			}))
			rune:SetAttribute("FinalTransparency", 0)
		end
		piece.PrimaryPart = stonePart
		piece.Parent = pieces
	end

	local core = newPart(portal, "Core", ghostly({
		Size = Vector3.new(0.3, height - 0.2, width - 0.2),
		CFrame = center * FACING,
		Material = Enum.Material.Neon,
		Color = COLORS.Core,
		Transparency = 1,
	}))
	core:SetAttribute("FinalTransparency", 0.25)
	local glow = Instance.new("PointLight")
	glow.Color = COLORS.Vortex
	glow.Brightness = 4
	glow.Range = 26
	glow.Enabled = false
	glow.Parent = core
	local sparkPoint = Instance.new("Attachment")
	sparkPoint.Parent = core
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.EmissionDirection = Enum.NormalId.Right -- out of the portal's front
	sparks.Color = ColorSequence.new(Color3.fromRGB(220, 170, 255), COLORS.Vortex)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.5, 0)
	sparks.Transparency = NumberSequence.new(0.1, 1)
	sparks.Lifetime = NumberRange.new(1, 1.6)
	sparks.Speed = NumberRange.new(3, 6)
	sparks.SpreadAngle = Vector2.new(40, 60)
	sparks.Drag = 1
	sparks.Rate = 30
	sparks.Enabled = false
	sparks.Parent = sparkPoint

	-- Four spiral arms in shades of purple plus white star specks; the client spins them.
	local swirl = Instance.new("Folder")
	swirl.Name = "Swirl"
	swirl.Parent = portal
	local armColors = {
		Color3.fromRGB(205, 140, 255),
		Color3.fromRGB(150, 70, 255),
		Color3.fromRGB(100, 40, 210),
		Color3.fromRGB(240, 235, 255),
	}
	for arm = 1, 4 do
		for j = 1, 9 do
			local bitRadius = 0.5 + (j - 1) * 4.1 / 8
			local angle = (arm - 1) * math.pi / 2 + bitRadius * 0.6
			local star = arm == 4
			local bit = newPart(swirl, "SwirlBit", ghostly({
				Size = star and Vector3.new(0.25, 0.25, 0.4) or Vector3.new(0.4, 0.3 + bitRadius * 0.22, 0.5),
				CFrame = center * CFrame.new(math.cos(angle) * bitRadius, math.sin(angle) * bitRadius * 1.55, 0) * CFrame.Angles(0, 0, angle),
				Material = Enum.Material.Neon,
				Color = armColors[arm],
				Transparency = 1,
			}))
			bit:SetAttribute("Angle", angle)
			bit:SetAttribute("Radius", bitRadius)
			bit:SetAttribute("FinalTransparency", star and 0 or 0.15)
		end
	end

	-- Banners with a ghost on each pillar; they appear when the portal opens.
	local banners = Instance.new("Folder")
	banners.Name = "Banners"
	banners.Parent = portal
	for _, s in { -1, 1 } do
		local x, front = s * 6.6, -1.55
		local rod = newPart(banners, "BannerRod", ghostly({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3.2, 0.25, 0.25),
			CFrame = base * CFrame.new(x, 15.6, front),
			Material = Enum.Material.Metal,
			Color = COLORS.Iron,
			Transparency = 1,
		}))
		rod:SetAttribute("FinalTransparency", 0)
		local cloth = newPart(banners, "Banner", ghostly({
			Size = Vector3.new(2.6, 6.2, 0.15),
			CFrame = base * CFrame.new(x, 12.4, front),
			Material = Enum.Material.Fabric,
			Color = COLORS.Banner,
			Transparency = 1,
		}))
		cloth:SetAttribute("FinalTransparency", 0)
		triangle(banners, "BannerTip", base * CFrame.new(x, 12.4 - 3.1 - 0.55, front) * CFrame.Angles(0, 0, math.pi), 2.6, 1.1, 0.15, ghostly({
			Material = Enum.Material.Fabric,
			Color = COLORS.Banner,
			Transparency = 1,
		}))

		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.Enabled = false
		gui.Parent = cloth
		local function blob(name, size, position, color, round)
			local frame = Instance.new("Frame")
			frame.Name = name
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.Size = UDim2.fromOffset(size.X, size.Y)
			frame.Position = UDim2.fromOffset(position.X, position.Y)
			frame.BackgroundColor3 = color
			frame.BorderSizePixel = 0
			local corner = Instance.new("UICorner")
			corner.CornerRadius = round and UDim.new(0.5, 0) or UDim.new(0, 10)
			corner.Parent = frame
			frame.Parent = gui
		end
		local ghost = COLORS.BannerGhost
		blob("GhostHead", Vector2.new(64, 64), Vector2.new(52, 86), ghost, true)
		blob("GhostBody", Vector2.new(64, 60), Vector2.new(52, 128), ghost, false)
		for _, hemX in { 31, 52, 73 } do
			blob("GhostHem", Vector2.new(22, 22), Vector2.new(hemX, 158), ghost, true)
		end
		blob("GhostEye", Vector2.new(12, 18), Vector2.new(41, 84), COLORS.Banner, true)
		blob("GhostEye", Vector2.new(12, 18), Vector2.new(63, 84), COLORS.Banner, true)
		blob("GhostMouth", Vector2.new(12, 16), Vector2.new(52, 108), COLORS.Banner, true)
	end
	for _, part in banners:GetDescendants() do
		if part:IsA("WedgePart") then
			part:SetAttribute("FinalTransparency", 0)
		end
	end

	local trigger = newPart(portal, "Trigger", {
		Size = Vector3.new(2, height - 0.6, width - 0.6),
		CFrame = center * FACING,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})

	portal:AddTag("HalloweenPortal")
	portal.Parent = world
	table.insert(noLanding, portal)
	return portal, trigger, center, #stones
end

local function finishPortal(portal, site)
	for _, part in portal:GetDescendants() do
		if part:IsA("BasePart") then
			local final = part:GetAttribute("FinalTransparency")
			if final then
				part.Transparency = final
			end
			if part:GetAttribute("Solid") then
				part.CanCollide = true
			end
		elseif part:IsA("SurfaceGui") then
			part.Enabled = true
		end
	end
	portal.Core.PointLight.Enabled = true
	portal.Core.Attachment.Sparks.Enabled = true
	portal.Trigger.CanTouch = true
	portal:SetAttribute("Open", true)

	-- Light the candles and lanterns around it.
	for _, item in site:GetDescendants() do
		if item:IsA("PointLight") and item:GetAttribute("OnOpen") then
			item.Enabled = true
		elseif item:IsA("BasePart") then
			local onOpen = item:GetAttribute("OnOpenTransparency")
			if onOpen then
				item.Transparency = onOpen
			end
			local litColor = item:GetAttribute("LitColor")
			if litColor then
				item.Color = litColor
				item.Material = Enum.Material.Neon
			end
			if item:HasTag("HalloweenFlame") then
				item:SetAttribute("Lit", true)
			end
		end
	end
end

---------------------------------------------------------------- travel

local destination = setUpDestination()
local spot = findBuildSpot()
local portalGround = spot * CFrame.new(0, 0, 16) -- behind the pad, away from spawn
portalGround = CFrame.new(findGround(portalGround.Position) or portalGround.Position) * portalGround.Rotation

local decorRng = Random.new(2027)
local site = buildSite(portalGround, decorRng)
table.insert(noLanding, site)
local facingYaw = select(2, portalGround:ToOrientation())
for _, spec in {
	{ -14.0, 0, -6.5, 1.35 },
	{ -9.4, 0.6, -6.8, 0.55 },
	{ 14.0, 0, -7.2, 1.2 },
	{ 15.8, 0, -4.0, 0.7 },
	{ 8.6, 1.2, -4.8, 0.55 },
	{ -(FENCE.GateHalfWidth + 1.2), 15.8, FENCE.Front, 0.8 },
	{ FENCE.GateHalfWidth + 1.2, 15.8, FENCE.Front, 0.8 },
} do
	local ground = (portalGround * CFrame.new(spec[1], spec[2], spec[3])).Position
	addPumpkin(ground, facingYaw + decorRng:NextNumber(-0.3, 0.3), spec[4], decorRng, true)
end

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

	local portal, trigger, center, stoneCount = buildPortal(portalGround)
	task.wait(timings(stoneCount))
	finishPortal(portal, site)

	trigger.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if player then
			startTrip(player, center)
		end
	end)

	local rng = Random.new()
	local crownTop = ARCH.DaisHeight + ARCH.OpeningHeight + 3.6
	addPumpkin((portalGround * CFrame.new(0, crownTop, 0)).Position, facingYaw, 1.4, rng, true)
	for _ = 1, CONFIG.PortalGhosts do
		addGhost(portalGround.Position, rng:NextNumber(13, 20), rng:NextNumber(5, 11), rng:NextNumber(0.9, 1.3), rng)
	end
end)
