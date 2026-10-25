-- LobbyMapServer (Script)
-- Put this in ServerScriptService.
--
-- Builds a Halloween duel lobby floating on the sea, in classic studded bricks:
-- a checkered deck with a fence, string lights, lamps, dead trees and pumpkins,
-- rows of 2-seat duel tables and a 6-seat party table (a light per seat shows
-- who is sitting), booths marked with brick icons, swings, and four
-- leaderboards (wins, streaks, cash, Robux spent) that save and rank players
-- across servers. The only text anywhere is the names and numbers on the boards.
--
-- Other scripts can change a player's stats by editing the values the script
-- creates: player.leaderstats.Wins / .Streak / .Cash, and
-- player.HiddenStats.RobuxSpent. The boards pick the changes up on their next refresh.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local DataStoreService = game:GetService("DataStoreService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CONFIG = {
	Origin = Vector3.new(0, 0, 0), -- centre of the deck, at sea level
	HideBaseplate = true, -- hides a part named "Baseplate" so the sea shows
	DeckSize = Vector2.new(160, 144), -- studs, x by z
	DeckHeight = 8, -- deck surface above the sea
	BoardRefresh = 60, -- seconds between leaderboard refreshes
	SpinCooldown = 24 * 60 * 60, -- seconds between daily spins
	SpinRewards = { 50, 100, 150, 250, 500, 750, 1000, 2500 }, -- cash per wheel slice, in slice order
	SpinWeights = { 30, 25, 18, 12, 7, 4, 3, 1 }, -- how likely each slice is
	GiftCooldown = 10 * 60, -- seconds between free gifts
	GiftReward = 250,
	WallHeight = 80, -- invisible walls above the fence keep everyone on the deck
	DataStoreName = "LobbyStats_v1",
}

local COLORS = {
	TileA = Color3.fromRGB(204, 122, 72),
	TileB = Color3.fromRGB(188, 108, 62),
	DeckSide = Color3.fromRGB(150, 86, 50),
	Wood = Color3.fromRGB(206, 128, 64),
	DarkWood = Color3.fromRGB(70, 46, 34),
	Snow = Color3.fromRGB(236, 240, 246),
	Ice = Color3.fromRGB(196, 206, 224),
	Tree = Color3.fromRGB(78, 56, 44),
	Pumpkin = Color3.fromRGB(240, 120, 24),
	Stem = Color3.fromRGB(80, 100, 40),
	Iron = Color3.fromRGB(40, 38, 48),
	Lamp = Color3.fromRGB(255, 200, 80),
	LampPurple = Color3.fromRGB(170, 90, 255),
	Seat = Color3.fromRGB(60, 58, 70),
	SeatEmpty = Color3.fromRGB(90, 90, 100),
	SeatTaken = Color3.fromRGB(80, 255, 120),
	PartyRim = Color3.fromRGB(170, 90, 255),
	FullRim = Color3.fromRGB(255, 150, 40),
	Panel = Color3.fromRGB(18, 16, 34),
	Text = Color3.fromRGB(245, 245, 255),
}

-- The four boards, left to right as you face them.
local STATS = {
	{ key = "Wins", icon = "Trophy", color = Color3.fromRGB(255, 200, 40), shown = true },
	{ key = "Streak", icon = "Flame", color = Color3.fromRGB(255, 120, 40), shown = true },
	{ key = "Cash", icon = "Cash", color = Color3.fromRGB(90, 220, 90), shown = true },
	{ key = "RobuxSpent", icon = "Robux", color = Color3.fromRGB(60, 160, 255), shown = false },
}

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- stands a cylinder's axis up
local rng = Random.new(1031)

local lobby = Instance.new("Folder")
lobby.Name = "Lobby"
lobby.Parent = Workspace

-- Server to clients: "Spin" (slice), "Reward" (player), "Denied" (what). Clients animate.
local remote = Instance.new("RemoteEvent")
remote.Name = "LobbyEvent"
remote.Parent = ReplicatedStorage

local pedestals = {} -- [-3..3] stage pedestals, 0 is the middle
local updateStatues, applyAura -- defined further down
local interactive = {} -- parts the prompts hang off

---------------------------------------------------------------- helpers

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
	if part.Material ~= Enum.Material.Neon and part.Material ~= Enum.Material.Glass then
		part.Material = Enum.Material.Plastic -- studs only show on plastic
	end
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Inlet
	part.Parent = parent
	return part
end

local function decor(props)
	props.CanCollide = false
	props.CanQuery = false
	props.CastShadow = false
	return props
end

local DECK_TOP = CONFIG.Origin.Y + CONFIG.DeckHeight

-- A point on the deck: x across, z from the front (spawn side, -z) to the back.
local function onDeck(x, y, z)
	return CFrame.new(CONFIG.Origin + Vector3.new(x, CONFIG.DeckHeight + y, z))
end

-- A part stretched from a to b, for tree branches.
local function limb(parent, a, b, width, color)
	local up = math.abs((b - a).Unit.Y) > 0.999 and Vector3.xAxis or Vector3.yAxis
	return newPart(parent, "Branch", {
		Size = Vector3.new(width, width, (b - a).Magnitude),
		CFrame = CFrame.lookAt((a + b) / 2, b, up),
		Material = Enum.Material.Wood,
		Color = color,
	})
end

-- Little brick sculptures that say what something is without words.
local function icon(parent, kind, cframe, scale)
	local model = Instance.new("Model")
	model.Name = kind .. "Icon"
	model.Parent = parent
	local function brick(size, offset, color, neon, shape)
		return newPart(model, "Brick", decor({
			Shape = shape,
			Size = size * scale,
			CFrame = cframe * CFrame.new(offset.Position * scale) * offset.Rotation,
			Material = neon and Enum.Material.Neon or Enum.Material.Plastic,
			Color = color,
		}))
	end
	local gold = Color3.fromRGB(255, 200, 40)
	if kind == "Trophy" then
		brick(Vector3.new(3, 2.6, 3), CFrame.new(0, 3, 0), gold)
		brick(Vector3.new(3.6, 0.5, 3.6), CFrame.new(0, 4.5, 0), gold)
		for _, x in { -2, 2 } do
			brick(Vector3.new(0.6, 1.8, 0.6), CFrame.new(x, 3.2, 0), gold)
			brick(Vector3.new(0.9, 0.6, 0.6), CFrame.new(x * 0.85, 4, 0), gold)
		end
		brick(Vector3.new(1, 1.4, 1), CFrame.new(0, 1.2, 0), gold)
		brick(Vector3.new(2.6, 0.6, 2.6), CFrame.new(0, 0.3, 0), Color3.fromRGB(150, 100, 30))
	elseif kind == "Flame" then
		local colors = { Color3.fromRGB(255, 70, 30), Color3.fromRGB(255, 130, 30), Color3.fromRGB(255, 200, 50), Color3.fromRGB(255, 240, 150) }
		for i, size in { 3.4, 2.6, 1.8, 1 } do
			brick(Vector3.new(size, 1.4, size), CFrame.new(0, 0.7 + (i - 1) * 1.3, 0) * CFrame.Angles(0, math.rad(i * 20), 0), colors[i], true)
		end
	elseif kind == "Cash" then
		for i = 0, 3 do
			brick(Vector3.new(4, 0.6, 2.2), CFrame.new(0, 0.3 + i * 0.6, 0) * CFrame.Angles(0, math.rad(i * 6), 0), Color3.fromRGB(70, 200, 80))
			brick(Vector3.new(1, 0.62, 2.24), CFrame.new(0, 0.3 + i * 0.6, 0) * CFrame.Angles(0, math.rad(i * 6), 0), Color3.fromRGB(230, 240, 200))
		end
	elseif kind == "Robux" then
		for i = 0, 5 do
			brick(Vector3.new(0.8, 1.9, 0.8), CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.rad(i * 60 + 30)) * CFrame.new(0, 1.65, 0), Color3.fromRGB(60, 160, 255), true)
		end
		brick(Vector3.new(1.1, 1.1, 0.9), CFrame.new(0, 2, 0), Color3.fromRGB(230, 245, 255), true)
	elseif kind == "Gift" then
		local red, white = Color3.fromRGB(240, 60, 70), Color3.fromRGB(255, 255, 255)
		brick(Vector3.new(3, 3, 3), CFrame.new(0, 1.5, 0), red)
		brick(Vector3.new(0.7, 3.1, 3.1), CFrame.new(0, 1.5, 0), white)
		brick(Vector3.new(3.1, 3.1, 0.7), CFrame.new(0, 1.5, 0), white)
		for _, angle in { 40, -40 } do
			brick(Vector3.new(1.4, 0.9, 0.5), CFrame.new(0, 3.3, 0) * CFrame.Angles(0, 0, math.rad(angle)) * CFrame.new(0.6, 0, 0), white)
		end
	elseif kind == "Wheel" then
		local colors = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 200, 40), Color3.fromRGB(90, 220, 90), Color3.fromRGB(60, 160, 255),
			Color3.fromRGB(170, 90, 255), Color3.fromRGB(255, 130, 40), Color3.fromRGB(40, 220, 220), Color3.fromRGB(255, 90, 200) }
		for i, color in colors do
			brick(Vector3.new(0.5, 0.7, 1.8), CFrame.new(0, 2, 0) * CFrame.Angles(math.rad(i * 45), 0, 0) * CFrame.new(0, 0, 0.9), color, true)
		end
		brick(Vector3.new(0.7, 0.7, 0.7), CFrame.new(0, 2, 0), Color3.fromRGB(255, 255, 255))
	elseif kind == "Hat" then
		local black = Color3.fromRGB(30, 28, 36)
		brick(Vector3.new(0.4, 4, 4), CFrame.new(0, 0.2, 0) * UPRIGHT, black, false, Enum.PartType.Cylinder)
		brick(Vector3.new(2.8, 2.6, 2.6), CFrame.new(0, 1.8, 0) * UPRIGHT, black, false, Enum.PartType.Cylinder)
		brick(Vector3.new(0.6, 2.7, 2.7), CFrame.new(0, 0.8, 0) * UPRIGHT, Color3.fromRGB(240, 60, 70), false, Enum.PartType.Cylinder)
	end
	return model
end

local function abbreviate(n)
	n = math.floor(n)
	for _, unit in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if n >= unit[1] then
			return string.format("%.2f", n / unit[1]):gsub("%.?0+$", "") .. unit[2]
		end
	end
	return tostring(n)
end

---------------------------------------------------------------- sea, deck and shore

local function buildSeaAndDeck()
	if CONFIG.HideBaseplate then
		local baseplate = Workspace:FindFirstChild("Baseplate")
		if baseplate and baseplate:IsA("BasePart") then
			baseplate.Transparency = 1
			baseplate.CanCollide = false
		end
	end
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") then
			descendant.Enabled = false
		end
	end

	local o = CONFIG.Origin
	Workspace.Terrain:FillBlock(CFrame.new(o + Vector3.new(0, -14, 0)), Vector3.new(1600, 28, 1600), Enum.Material.Water)
	Workspace.Terrain:FillBlock(CFrame.new(o + Vector3.new(0, -34, 0)), Vector3.new(1600, 12, 1600), Enum.Material.Sand)
	Workspace.Terrain.WaterColor = Color3.fromRGB(40, 200, 220)
	Workspace.Terrain.WaterTransparency = 0.3
	Workspace.Terrain.WaterWaveSize = 0.15
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.6
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.25
	atmosphere.Haze = 0.6
	atmosphere.Color = Color3.fromRGB(200, 235, 255)
	atmosphere.Decay = Color3.fromRGB(120, 170, 220)
	atmosphere.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Saturation = 0.18
	grade.Contrast = 0.06
	grade.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 20
	bloom.Threshold = 1.2
	bloom.Parent = Lighting

	local map = Instance.new("Model")
	map.Name = "Deck"
	map.Parent = lobby

	local size = CONFIG.DeckSize
	newPart(map, "DeckBase", {
		Size = Vector3.new(size.X, CONFIG.DeckHeight + 6, size.Y),
		CFrame = onDeck(0, -(CONFIG.DeckHeight + 6) / 2 - 0.5, 0),
		Material = Enum.Material.Wood,
		Color = COLORS.DeckSide,
	})

	-- Checkered tiles.
	local tile = 8
	for ix = 0, size.X / tile - 1 do
		for iz = 0, size.Y / tile - 1 do
			newPart(map, "Tile", {
				Size = Vector3.new(tile, 1, tile),
				CFrame = onDeck(-size.X / 2 + tile / 2 + ix * tile, -0.5, -size.Y / 2 + tile / 2 + iz * tile),
				Material = Enum.Material.SmoothPlastic,
				Color = (ix + iz) % 2 == 0 and COLORS.TileA or COLORS.TileB,
			})
		end
	end

	-- Fence around the edge, with lamps every few posts.
	local fence = Instance.new("Model")
	fence.Name = "Fence"
	fence.Parent = map
	local hx, hz = size.X / 2 - 1.5, size.Y / 2 - 1.5
	local sides = {
		{ Vector3.new(-hx, 0, -hz), Vector3.new(hx, 0, -hz) },
		{ Vector3.new(hx, 0, -hz), Vector3.new(hx, 0, hz) },
		{ Vector3.new(hx, 0, hz), Vector3.new(-hx, 0, hz) },
		{ Vector3.new(-hx, 0, hz), Vector3.new(-hx, 0, -hz) },
	}
	local postCount = 0
	for _, side in sides do
		local a, b = side[1], side[2]
		local length = (b - a).Magnitude
		local steps = math.floor(length / 8)
		for i = 0, steps - 1 do
			local p = a + (b - a) * (i / steps)
			postCount += 1
			newPart(fence, "Post", {
				Size = Vector3.new(0.9, 4.4, 0.9),
				CFrame = onDeck(p.X, 2.2, p.Z),
				Material = Enum.Material.Wood,
				Color = COLORS.Wood,
			})
			if postCount % 4 == 0 then
				newPart(fence, "LampPost", decor({
					Size = Vector3.new(0.5, 3, 0.5),
					CFrame = onDeck(p.X, 5.9, p.Z),
					Material = Enum.Material.Metal,
					Color = COLORS.Iron,
				}))
				local lamp = newPart(fence, "Lamp", decor({
					Size = Vector3.new(1.3, 1.6, 1.3),
					CFrame = onDeck(p.X, 8.2, p.Z),
					Material = Enum.Material.Neon,
					Color = postCount % 8 == 0 and COLORS.LampPurple or COLORS.Lamp,
				}))
				local light = Instance.new("PointLight")
				light.Color = lamp.Color
				light.Range = 14
				light.Brightness = 1.4
				light.Parent = lamp
			end
		end
		local bulbColors = { Color3.fromRGB(255, 140, 40), Color3.fromRGB(170, 90, 255), Color3.fromRGB(80, 255, 120) }
		for i = 0, math.floor(length / 3) do
			local p = a + (b - a) * (i * 3 / length)
			newPart(fence, "Bulb", decor({
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.5,
				CFrame = onDeck(p.X, 4.15, p.Z),
				Material = Enum.Material.Neon,
				Color = bulbColors[i % #bulbColors + 1],
			}))
		end
		local mid = (a + b) / 2
		for _, y in { 1.4, 3.6 } do
			newPart(fence, "Rail", {
				Size = Vector3.new(0.5, 0.5, length),
				CFrame = CFrame.lookAt(onDeck(mid.X, y, mid.Z).Position, onDeck(b.X, y, b.Z).Position),
				Material = Enum.Material.Wood,
				Color = COLORS.Wood,
			})
		end
	end

	-- Snowy rocks stacked around the deck, half in the water.
	local shore = Instance.new("Model")
	shore.Name = "Shore"
	shore.Parent = map
	for _ = 1, 90 do
		local edge = rng:NextInteger(1, 4)
		local along = rng:NextNumber(-1, 1)
		local out = rng:NextNumber(4, 34)
		local x, z
		if edge == 1 then
			x, z = along * (size.X / 2 + 20), -(size.Y / 2 + out)
		elseif edge == 2 then
			x, z = along * (size.X / 2 + 20), size.Y / 2 + out
		elseif edge == 3 then
			x, z = -(size.X / 2 + out), along * (size.Y / 2 + 20)
		else
			x, z = size.X / 2 + out, along * (size.Y / 2 + 20)
		end
		local block = Vector3.new(rng:NextNumber(10, 22), rng:NextNumber(6, 13), rng:NextNumber(10, 22))
		newPart(shore, "Rock", {
			Size = block,
			CFrame = CFrame.new(CONFIG.Origin + Vector3.new(x, block.Y / 2 - rng:NextNumber(3, 6), z))
				* CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0),
			Material = Enum.Material.Snow,
			Color = rng:NextNumber() < 0.6 and COLORS.Snow or COLORS.Ice,
		})
	end

	-- Dead trees at the corners and halfway along the sides, just outside the fence.
	local trees = Instance.new("Model")
	trees.Name = "Trees"
	trees.Parent = map
	for _, spot in {
		Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1),
		Vector3.new(-1, 0, 0), Vector3.new(1, 0, 0), Vector3.new(0, 0, -1),
	} do
		local base = Vector3.new(spot.X * (size.X / 2 + 6), CONFIG.DeckHeight - 3, spot.Z * (size.Y / 2 + 6)) + CONFIG.Origin
		if spot.Z == -1 and spot.X == 0 then
			base += Vector3.new(30, 0, 0) -- keep the front entrance clear
		end
		local height = rng:NextNumber(14, 20)
		local top = base + Vector3.new(rng:NextNumber(-1.5, 1.5), height, rng:NextNumber(-1.5, 1.5))
		limb(trees, base, top, 1.8, COLORS.Tree)
		for b = 1, 4 do
			local from = base:Lerp(top, 0.45 + b * 0.12)
			local angle = b * 1.7 + rng:NextNumber(-0.4, 0.4)
			local reach = rng:NextNumber(4, 7)
			local tip = from + Vector3.new(math.cos(angle) * reach, rng:NextNumber(2, 5), math.sin(angle) * reach)
			limb(trees, from, tip, 0.7, COLORS.Tree)
			limb(trees, tip, tip + Vector3.new(math.cos(angle + 0.8) * 2, 2, math.sin(angle + 0.8) * 2), 0.35, COLORS.Tree)
		end
	end

	-- Pumpkins scattered along the fence.
	for _ = 1, 26 do
		local side = rng:NextInteger(1, 4)
		local t = rng:NextNumber(-0.95, 0.95)
		local x, z
		if side == 1 then
			x, z = t * (size.X / 2 - 5), -(size.Y / 2 - 5)
		elseif side == 2 then
			x, z = t * (size.X / 2 - 5), size.Y / 2 - 5
		elseif side == 3 then
			x, z = -(size.X / 2 - 5), t * (size.Y / 2 - 5)
		else
			x, z = size.X / 2 - 5, t * (size.Y / 2 - 5)
		end
		if not (side == 1 and math.abs(x) < 14) then -- not in the entrance
			local s = rng:NextNumber(1.6, 3)
			local body = newPart(map, "Pumpkin", {
				Size = Vector3.new(s * 1.2, s, s * 1.2),
				CFrame = onDeck(x, s / 2, z),
				Material = Enum.Material.SmoothPlastic,
				Color = COLORS.Pumpkin,
			})
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = body
			newPart(map, "Stem", decor({
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(s * 0.35, s * 0.18, s * 0.18),
				CFrame = onDeck(x, s + s * 0.1, z) * UPRIGHT,
				Material = Enum.Material.Wood,
				Color = COLORS.Stem,
			}))
		end
	end

	-- Spawn at the front of the deck.
	newPart(map, "LobbySpawn", {
		Size = Vector3.new(10, 1, 10),
		CFrame = onDeck(0, 0.5, -size.Y / 2 + 12),
		Transparency = 1,
		CanCollide = false,
		Neutral = true,
		Duration = 0,
	}, "SpawnLocation")
end

---------------------------------------------------------------- tables

-- A table with seats on both long sides. Shows "taken/total" above it.
local function buildTable(name, center, length, seatsPerSide, isParty)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = lobby

	local top = newPart(model, "TableTop", {
		Size = Vector3.new(length, 0.8, 4.4),
		CFrame = center * CFrame.new(0, 3.2, 0),
		Material = Enum.Material.Wood,
		Color = COLORS.DarkWood,
	})
	for _, corner in { Vector3.new(1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(-1, 0, -1) } do
		newPart(model, "Leg", {
			Size = Vector3.new(0.6, 2.8, 0.6),
			CFrame = center * CFrame.new(corner.X * (length / 2 - 0.6), 1.4, corner.Z * 1.6),
			Material = Enum.Material.Wood,
			Color = COLORS.DarkWood,
		})
	end

	local rim = newPart(model, "Rim", decor({
		Size = Vector3.new(length + 0.4, 0.3, 4.8),
		CFrame = center * CFrame.new(0, 2.7, 0),
		Material = Enum.Material.Neon,
		Color = isParty and COLORS.PartyRim or COLORS.SeatEmpty,
	}))
	local seats, lights = {}, {}
	for _, side in { -1, 1 } do
		for i = 1, seatsPerSide do
			local x = (i - (seatsPerSide + 1) / 2) * (length / seatsPerSide)
			-- Each seat faces the table.
			local seatFrame = center * CFrame.new(x, 1.7, side * 4) * CFrame.Angles(0, side > 0 and 0 or math.pi, 0)
			local seat = newPart(model, "Seat", {
				Size = Vector3.new(2.6, 0.6, 2.4),
				CFrame = seatFrame,
				Material = Enum.Material.SmoothPlastic,
				Color = COLORS.Seat,
			}, "Seat")
			newPart(model, "SeatBack", {
				Size = Vector3.new(2.6, 3, 0.4),
				CFrame = seatFrame * CFrame.new(0, 1.6, 1.1),
				Material = Enum.Material.SmoothPlastic,
				Color = COLORS.Seat,
			})
			newPart(model, "SeatLeg", {
				Size = Vector3.new(0.6, 1.4, 0.6),
				CFrame = seatFrame * CFrame.new(0, -1, 0),
				Material = Enum.Material.Metal,
				Color = COLORS.Iron,
			})
			table.insert(seats, seat)
			table.insert(lights, newPart(model, "SeatLight", decor({
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.8,
				CFrame = center * CFrame.new(x, 3.8, side * 1.5),
				Material = Enum.Material.Neon,
				Color = COLORS.SeatEmpty,
			})))
		end
	end

	local function refresh()
		local taken = 0
		for i, seat in seats do
			local sitting = seat.Occupant ~= nil
			lights[i].Color = sitting and COLORS.SeatTaken or COLORS.SeatEmpty
			if sitting then
				taken += 1
			end
		end
		rim.Color = taken == #seats and COLORS.FullRim or (isParty and COLORS.PartyRim or COLORS.SeatEmpty)
	end
	for _, seat in seats do
		seat:GetPropertyChangedSignal("Occupant"):Connect(refresh)
	end
	return model
end

local function buildTables()
	local size = CONFIG.DeckSize
	local number = 0
	for _, z in { -6, 18, 42 } do
		for _, x in { -42, -16, 10, 36 } do
			number += 1
			buildTable("DuelTable" .. number, onDeck(x - 4, 0, z), 7, 1)
		end
	end
	buildTable("PartyTable", onDeck(-3, 0, -size.Y / 2 + 34), 13, 3, true)
end

---------------------------------------------------------------- booths, swings, stage

local function booth(name, center, color, iconKind)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = lobby
	newPart(model, "Counter", {
		Size = Vector3.new(10, 3.5, 4),
		CFrame = center * CFrame.new(0, 1.75, 0),
		Material = Enum.Material.Wood,
		Color = COLORS.Wood,
	})
	for _, x in { -4.6, 4.6 } do
		newPart(model, "Pole", {
			Size = Vector3.new(0.5, 8, 0.5),
			CFrame = center * CFrame.new(x, 4, 1.6),
			Material = Enum.Material.Wood,
			Color = COLORS.Wood,
		})
	end
	-- Striped awning.
	for i = 0, 4 do
		newPart(model, "Awning", {
			Size = Vector3.new(2.2, 0.4, 5),
			CFrame = center * CFrame.new(-4.4 + i * 2.2, 8.2, 0.6) * CFrame.Angles(math.rad(-12), 0, 0),
			Material = Enum.Material.SmoothPlastic,
			Color = i % 2 == 0 and color or Color3.new(1, 1, 1),
		})
	end
	local glow = newPart(model, "Glow", decor({
		Size = Vector3.new(12, 0.2, 7),
		CFrame = center * CFrame.new(0, 0.1, -3.5),
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.4,
	}))
	icon(model, iconKind, center * CFrame.new(0, 9.2, 0.6), 1)
	return model, model.Counter
end

local function buildExtras()
	local size = CONFIG.DeckSize
	local left = -size.X / 2 + 12
	-- Booths down the left side, facing into the deck.
	local facing = CFrame.Angles(0, -math.pi / 2, 0)
	_, interactive.Spin = booth("DailySpins", onDeck(left, 0, 40) * facing, Color3.fromRGB(170, 90, 255), "Wheel")
	_, interactive.Gift = booth("FreeRewards", onDeck(left, 0, 14) * facing, Color3.fromRGB(255, 210, 40), "Gift")
	_, interactive.Cosmetics = booth("Cosmetics", onDeck(left, 0, -12) * facing, Color3.fromRGB(255, 70, 90), "Hat")

	-- Spin wheel beside the Daily Spins booth.
	local wheelCenter = onDeck(left - 3, 9, 52)
	local wheel = Instance.new("Model")
	wheel.Name = "SpinWheel"
	wheel:SetAttribute("Center", wheelCenter)
	wheel.Parent = lobby
	local wheelColors = {
		Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 200, 40), Color3.fromRGB(90, 220, 90), Color3.fromRGB(60, 160, 255),
		Color3.fromRGB(170, 90, 255), Color3.fromRGB(255, 130, 40), Color3.fromRGB(40, 220, 220), Color3.fromRGB(255, 90, 200),
	}
	for i, color in wheelColors do
		local slice = newPart(wheel, "WheelSlice", {
			Size = Vector3.new(0.4, 0.9, 5.2),
			CFrame = wheelCenter * CFrame.Angles(math.rad(i * 45), 0, 0) * CFrame.new(0, 0, 2.6),
			Material = Enum.Material.Neon,
			Color = color,
		})
		slice:SetAttribute("Slice", i)
	end
	newPart(wheel, "WheelHub", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 1.8, 1.8),
		CFrame = wheelCenter,
		Material = Enum.Material.Metal,
		Color = COLORS.Iron,
	})
	newPart(lobby, "WheelPointer", {
		Size = Vector3.new(0.6, 1.4, 0.6),
		CFrame = wheelCenter * CFrame.new(0, 6, 0) * CFrame.Angles(0, 0, math.rad(45)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 255, 255),
	})
	newPart(lobby, "WheelStand", {
		Size = Vector3.new(0.8, 9, 0.8),
		CFrame = onDeck(left - 3, 4.5, 52),
		Material = Enum.Material.Metal,
		Color = COLORS.Iron,
	})

	-- Swing set near the front right.
	local swingBase = onDeck(34, 0, -size.Y / 2 + 30)
	for _, x in { -6, 6 } do
		for _, z in { -2, 2 } do
			newPart(lobby, "SwingLeg", {
				Size = Vector3.new(0.5, 9.4, 0.5),
				CFrame = swingBase * CFrame.new(x, 4.5, z * 0.6) * CFrame.Angles(math.rad(z * 6), 0, 0),
				Material = Enum.Material.Metal,
				Color = COLORS.Iron,
			})
		end
	end
	newPart(lobby, "SwingBar", {
		Size = Vector3.new(12.5, 0.5, 0.5),
		CFrame = swingBase * CFrame.new(0, 9, 0),
		Material = Enum.Material.Metal,
		Color = COLORS.Iron,
	})
	for _, x in { -3, 3 } do
		for _, side in { -0.9, 0.9 } do
			newPart(lobby, "SwingChain", decor({
				Size = Vector3.new(0.12, 6, 0.12),
				CFrame = swingBase * CFrame.new(x + side, 6, 0),
				Material = Enum.Material.Metal,
				Color = COLORS.Iron,
			}))
		end
		newPart(lobby, "SwingSeat", {
			Size = Vector3.new(2.2, 0.3, 1.2),
			CFrame = swingBase * CFrame.new(x, 3, 0),
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(40, 60, 150),
		}, "Seat")
	end

	-- Stage with a rainbow brick banner at the back.
	local back = size.Y / 2 - 9
	newPart(lobby, "Stage", {
		Size = Vector3.new(70, 1.6, 10),
		CFrame = onDeck(0, 0.8, back),
		Material = Enum.Material.Wood,
		Color = COLORS.DarkWood,
	})
	for i = -3, 3 do
		pedestals[i] = newPart(lobby, "Pedestal", {
			Size = Vector3.new(5, 2 + (3 - math.abs(i)) * 0.6, 5),
			CFrame = onDeck(i * 9, 1.6 + (2 + (3 - math.abs(i)) * 0.6) / 2, back),
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(236, 236, 244),
		})
	end
	newPart(lobby, "WinnerBeam", decor({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(40, 6, 6),
		CFrame = pedestals[0].CFrame * CFrame.new(0, 20, 0) * UPRIGHT,
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 210, 80),
		Transparency = 0.85,
	}))

	-- Two trampolines; the client bounces whoever lands on one.
	for _, x in { -50, -34 } do
		newPart(lobby, "TrampolineFrame", {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, 9, 9),
			CFrame = onDeck(x, 0.5, -size.Y / 2 + 22) * UPRIGHT,
			Color = Color3.fromRGB(40, 60, 150),
		})
		newPart(lobby, "Trampoline", {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 7.6, 7.6),
			CFrame = onDeck(x, 1.1, -size.Y / 2 + 22) * UPRIGHT,
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(80, 255, 200),
		})
	end

	local rainbow = {
		Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 160, 40), Color3.fromRGB(255, 220, 60),
		Color3.fromRGB(90, 220, 90), Color3.fromRGB(60, 160, 255), Color3.fromRGB(150, 90, 255),
	}
	for i, color in rainbow do
		newPart(lobby, "Banner", {
			Size = Vector3.new(56, 2, 1),
			CFrame = onDeck(0, 22 - i * 2, size.Y / 2 - 3),
			Color = color,
		})
	end
	for _, x in { -18, 0, 18 } do
		icon(lobby, x == 0 and "Trophy" or "Gift", onDeck(x, 22, size.Y / 2 - 3), x == 0 and 1.4 or 0.8)
	end
	for _, x in { -27, 27 } do
		newPart(lobby, "SignPost", {
			Size = Vector3.new(1.2, 22, 1.2),
			CFrame = onDeck(x, 11, size.Y / 2 - 2.4),
			Material = Enum.Material.Metal,
			Color = COLORS.Iron,
		})
	end
end

---------------------------------------------------------------- leaderboards

local boards = {}

local function buildBoard(stat, cframe)
	local frame = newPart(lobby, stat.key .. "Board", {
		Size = Vector3.new(16, 28, 1.4),
		CFrame = cframe * CFrame.new(0, 15, 0),
		Material = Enum.Material.SmoothPlastic,
		Color = COLORS.Panel,
	})
	newPart(lobby, stat.key .. "BoardGlow", decor({
		Size = Vector3.new(16.8, 28.8, 1),
		CFrame = cframe * CFrame.new(0, 15, 0.4),
		Material = Enum.Material.Neon,
		Color = stat.color,
	}))
	newPart(lobby, stat.key .. "BoardFoot", {
		Size = Vector3.new(6, 1, 3),
		CFrame = cframe * CFrame.new(0, 0.5, 0),
		Material = Enum.Material.Metal,
		Color = COLORS.Iron,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.LightInfluence = 0
	gui.Parent = frame

	icon(lobby, stat.icon, cframe * CFrame.new(0, 29.6, 0), 1.3)
	local band = Instance.new("Frame")
	band.Size = UDim2.new(1, 0, 0.03, 0)
	band.BackgroundColor3 = stat.color
	band.BorderSizePixel = 0
	band.Parent = gui

	local rows = {}
	for i = 1, 10 do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(0.94, 0, 0.085, 0)
		row.Position = UDim2.new(0.03, 0, 0.06 + (i - 1) * 0.094, 0)
		row.BackgroundColor3 = i % 2 == 0 and Color3.fromRGB(32, 28, 56) or Color3.fromRGB(26, 22, 46)
		row.BorderSizePixel = 0
		row.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.2, 0)
		corner.Parent = row
		local function cell(name, x, width, align, color)
			local text = Instance.new("TextLabel")
			text.Name = name
			text.Position = UDim2.fromScale(x, 0.1)
			text.Size = UDim2.fromScale(width, 0.8)
			text.BackgroundTransparency = 1
			text.FontFace = Font.fromEnum(Enum.Font.GothamBold)
			text.TextScaled = true
			text.TextXAlignment = align
			text.TextColor3 = color
			text.Text = ""
			text.Parent = row
			return text
		end
		local rankColor = i == 1 and Color3.fromRGB(255, 210, 40)
			or i == 2 and Color3.fromRGB(210, 214, 230)
			or i == 3 and Color3.fromRGB(220, 140, 70)
			or COLORS.Text
		rows[i] = {
			rank = cell("Rank", 0.03, 0.12, Enum.TextXAlignment.Left, rankColor),
			name = cell("Player", 0.16, 0.56, Enum.TextXAlignment.Left, COLORS.Text),
			value = cell("Value", 0.7, 0.27, Enum.TextXAlignment.Right, stat.color),
		}
		rows[i].rank.Text = "#" .. i
	end
	boards[stat.key] = rows
end

local function buildBoards()
	local size = CONFIG.DeckSize
	local x = size.X / 2 - 9
	for i, stat in STATS do
		local z = -36 + (i - 1) * 22
		-- Stand on the right edge, turned a little towards the middle of the deck.
		local spot = onDeck(x, 0, z).Position
		local cframe = CFrame.lookAt(spot, spot + Vector3.new(-1, 0, -0.25))
		buildBoard(stat, cframe)
	end
end

local function renderBoard(key, entries)
	local rows = boards[key]
	for i, row in rows do
		local entry = entries[i]
		row.name.Text = entry and entry.name or "-"
		row.value.Text = entry and abbreviate(entry.value) or ""
	end
end

---------------------------------------------------------------- stats and saving

local playerStore, orderedStores = nil, {}
pcall(function()
	playerStore = DataStoreService:GetDataStore(CONFIG.DataStoreName)
	for _, stat in STATS do
		orderedStores[stat.key] = DataStoreService:GetOrderedDataStore(CONFIG.DataStoreName .. "_" .. stat.key)
	end
end)

local function statValue(player, key)
	local holder = player:FindFirstChild("leaderstats")
	local value = holder and holder:FindFirstChild(key)
	if not value then
		holder = player:FindFirstChild("HiddenStats")
		value = holder and holder:FindFirstChild(key)
	end
	return value
end

local function onPlayerAdded(player)
	player:SetAttribute("GiftReadyAt", 0) -- the first gift is ready straight away
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		applyAura(player)
	end)
	local shown = Instance.new("Folder")
	shown.Name = "leaderstats"
	local hidden = Instance.new("Folder")
	hidden.Name = "HiddenStats"
	for _, stat in STATS do
		local value = Instance.new("IntValue")
		value.Name = stat.key
		value.Parent = stat.shown and shown or hidden
	end
	shown.Parent = player
	hidden.Parent = player

	if playerStore then
		local ok, saved = pcall(playerStore.GetAsync, playerStore, "u_" .. player.UserId)
		if ok and type(saved) == "table" then
			for _, stat in STATS do
				local value = statValue(player, stat.key)
				if value and tonumber(saved[stat.key]) then
					value.Value = saved[stat.key]
				end
			end
			player:SetAttribute("LastSpin", tonumber(saved.lastSpin) or 0)
		end
	end
end

local function savePlayer(player)
	if not playerStore then
		return
	end
	local data = { version = 1, lastSpin = player:GetAttribute("LastSpin") or 0 }
	for _, stat in STATS do
		local value = statValue(player, stat.key)
		data[stat.key] = value and value.Value or 0
	end
	pcall(playerStore.SetAsync, playerStore, "u_" .. player.UserId, data)
end

local nameCache = {}
local function nameOf(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	nameCache[userId] = ok and name or "Player"
	return nameCache[userId]
end

-- Ranks just the people in this server: used when saving is unavailable (for
-- example in Studio without API access).
local function localRanking(key)
	local entries = {}
	for _, player in Players:GetPlayers() do
		local value = statValue(player, key)
		if value then
			table.insert(entries, { name = player.DisplayName, value = value.Value, userId = player.UserId })
		end
	end
	table.sort(entries, function(a, b)
		return a.value > b.value
	end)
	return entries
end

---------------------------------------------------------------- winner statues

-- The top three by wins stand on the middle pedestals as their real avatars.
local statueFolder = Instance.new("Folder")
statueFolder.Name = "Statues"
statueFolder.Parent = lobby
local statueIds, statueModels = {}, {}
local STATUE_SPOTS = { 0, -1, 1 } -- rank 1 in the middle, 2 left, 3 right

updateStatues = function(entries)
	for rank, spot in STATUE_SPOTS do
		local userId = entries[rank] and entries[rank].userId
		if statueIds[rank] ~= userId then
			statueIds[rank] = userId
			if statueModels[rank] then
				statueModels[rank]:Destroy()
				statueModels[rank] = nil
			end
			if userId then
				task.spawn(function()
					local ok, model = pcall(Players.CreateHumanoidModelFromUserId, Players, userId)
					if not ok or not model or statueIds[rank] ~= userId then
						return
					end
					model.Name = "Statue" .. rank
					local humanoid = model:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- no name above it
					end
					for _, part in model:GetDescendants() do
						if part:IsA("BasePart") then
							part.Anchored = true
							part.CanCollide = false
						elseif part:IsA("Script") or part:IsA("LocalScript") then
							part:Destroy()
						end
					end
					local box, boxSize = model:GetBoundingBox()
					local lift = boxSize.Y / 2 + (model:GetPivot().Y - box.Y)
					local pedestal = pedestals[spot]
					local top = pedestal.Position + Vector3.new(0, pedestal.Size.Y / 2 + lift, 0)
					model:PivotTo(CFrame.lookAt(top, top + Vector3.new(0, 0, -1)))
					model.Parent = statueFolder
					statueModels[rank] = model
				end)
			end
		end
	end
end

---------------------------------------------------------------- keeping players in

local deckSize = CONFIG.DeckSize
local function buildWalls()
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = lobby
	local h = CONFIG.WallHeight
	local function wall(size, x, y, z)
		newPart(walls, "Wall", {
			Size = size,
			CFrame = onDeck(x, y, z),
			Transparency = 1,
			CanQuery = false,
			CastShadow = false,
		})
	end
	wall(Vector3.new(2, h, deckSize.Y + 4), -deckSize.X / 2 - 1, h / 2, 0)
	wall(Vector3.new(2, h, deckSize.Y + 4), deckSize.X / 2 + 1, h / 2, 0)
	wall(Vector3.new(deckSize.X + 4, h, 2), 0, h / 2, -deckSize.Y / 2 - 1)
	wall(Vector3.new(deckSize.X + 4, h, 2), 0, h / 2, deckSize.Y / 2 + 1)
	wall(Vector3.new(deckSize.X + 4, 2, deckSize.Y + 4), 0, h + 1, 0)
end

local spawnFrame = onDeck(0, 3.5, -deckSize.Y / 2 + 12)
local function sendHome(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		character:PivotTo(spawnFrame)
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

-- Anyone who somehow ends up outside the fence or in the sea goes back to spawn.
task.spawn(function()
	while true do
		task.wait(0.5)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				local p = root.Position - CONFIG.Origin
				local outside = math.abs(p.X) > deckSize.X / 2 + 2 or math.abs(p.Z) > deckSize.Y / 2 + 2
				if outside or p.Y < CONFIG.DeckHeight - 6 then
					sendHome(player)
				end
			end
		end
	end
end)

---------------------------------------------------------------- spin, gift, cosmetics

local function addPrompt(part, hold)
	local point = Instance.new("Attachment")
	point.Position = Vector3.new(0, 3, 0)
	point.Parent = part
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "" -- only the key shows, no words
	prompt.ObjectText = ""
	prompt.HoldDuration = hold or 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = point
	return prompt
end

local function weightedSlice()
	local total = 0
	for _, weight in CONFIG.SpinWeights do
		total += weight
	end
	local roll = rng:NextNumber(0, total)
	for i, weight in CONFIG.SpinWeights do
		roll -= weight
		if roll <= 0 then
			return i
		end
	end
	return 1
end

local function giveCash(player, amount)
	local cash = statValue(player, "Cash")
	if cash then
		cash.Value += amount
	end
	remote:FireAllClients("Reward", player)
end

local AURAS = {
	ColorSequence.new(Color3.fromRGB(255, 140, 40), Color3.fromRGB(255, 220, 80)),
	ColorSequence.new(Color3.fromRGB(170, 90, 255), Color3.fromRGB(80, 200, 255)),
	ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 220, 90)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 160, 255)),
	}),
}

applyAura = function(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	for _, old in root:GetChildren() do
		if old.Name == "LobbyAura" then
			old:Destroy()
		end
	end
	local colors = AURAS[player:GetAttribute("Aura") or 0]
	if not colors then
		return
	end
	local top = Instance.new("Attachment")
	top.Name = "LobbyAura"
	top.Position = Vector3.new(0, 1.2, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "LobbyAura"
	bottom.Position = Vector3.new(0, -1.6, 0)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "LobbyAura"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = colors
	trail.LightEmission = 1
	trail.Lifetime = 0.45
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = root
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "LobbyAura"
	sparkles.Color = colors
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new(0.3, 0)
	sparkles.Lifetime = NumberRange.new(0.6, 1)
	sparkles.Speed = NumberRange.new(1, 2)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Rate = 12
	sparkles.Parent = top
end

local spinning = false
local function setUpPrompts()
	addPrompt(interactive.Spin, 0.3).Triggered:Connect(function(player)
		local last = player:GetAttribute("LastSpin") or 0
		if spinning or os.time() - last < CONFIG.SpinCooldown then
			remote:FireClient(player, "Denied", "Spin")
			return
		end
		spinning = true
		player:SetAttribute("LastSpin", os.time())
		local slice = weightedSlice()
		remote:FireAllClients("Spin", slice)
		task.delay(3.6, function()
			spinning = false
			if player.Parent then
				giveCash(player, CONFIG.SpinRewards[slice])
			end
		end)
	end)

	addPrompt(interactive.Gift, 0.3).Triggered:Connect(function(player)
		if os.time() < (player:GetAttribute("GiftReadyAt") or 0) then
			remote:FireClient(player, "Denied", "Gift")
			return
		end
		player:SetAttribute("GiftReadyAt", os.time() + CONFIG.GiftCooldown)
		giveCash(player, CONFIG.GiftReward)
	end)

	addPrompt(interactive.Cosmetics).Triggered:Connect(function(player)
		player:SetAttribute("Aura", ((player:GetAttribute("Aura") or 0) + 1) % (#AURAS + 1))
		applyAura(player)
	end)
end

local pushed = {} -- [userId .. key] = last value written, so unchanged stats aren't rewritten

local function refreshBoards()
	for _, stat in STATS do
		local store = orderedStores[stat.key]
		local entries
		if store then
			for _, player in Players:GetPlayers() do
				local value = statValue(player, stat.key)
				local id = player.UserId .. stat.key
				if value and value.Value > 0 and pushed[id] ~= value.Value then
					if pcall(store.SetAsync, store, tostring(player.UserId), value.Value) then
						pushed[id] = value.Value
					end
				end
			end
			local ok, pages = pcall(store.GetSortedAsync, store, false, 10)
			if ok and pages then
				entries = {}
				for _, item in pages:GetCurrentPage() do
					table.insert(entries, { name = nameOf(tonumber(item.key)), value = item.value, userId = tonumber(item.key) })
				end
			end
		end
		entries = entries or localRanking(stat.key)
		renderBoard(stat.key, entries)
		if stat.key == "Wins" then
			updateStatues(entries)
		end
	end
end

---------------------------------------------------------------- start

buildSeaAndDeck()
buildTables()
buildExtras()
buildBoards()
buildWalls()
setUpPrompts()

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerRemoving:Connect(savePlayer)
game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		savePlayer(player)
	end
end)

task.spawn(function()
	task.wait(3)
	while true do
		refreshBoards()
		task.wait(CONFIG.BoardRefresh)
	end
end)
