-- LobbyMapServer (Script)
-- Put this in ServerScriptService.
--
-- Builds a Halloween duel lobby floating on the sea: a checkered deck with a
-- fence, lamps, dead trees and pumpkins, rows of 2-seat duel tables and a
-- 6-seat party table (each shows how many seats are taken), decorative booths,
-- swings, and four leaderboards (wins, streaks, cash, Robux spent) that save
-- and rank players across servers.
--
-- Other scripts can change a player's stats by editing the values the script
-- creates: player.leaderstats.Wins / .Streak / .Cash, and
-- player.HiddenStats.RobuxSpent. The boards pick the changes up on their next refresh.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local DataStoreService = game:GetService("DataStoreService")
local Lighting = game:GetService("Lighting")

local CONFIG = {
	Title = "DUEL LOBBY", -- the big sign at the back of the deck
	Origin = Vector3.new(0, 0, 0), -- centre of the deck, at sea level
	HideBaseplate = true, -- hides a part named "Baseplate" so the sea shows
	DeckSize = Vector2.new(160, 144), -- studs, x by z
	DeckHeight = 8, -- deck surface above the sea
	BoardRefresh = 60, -- seconds between leaderboard refreshes
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
	Panel = Color3.fromRGB(18, 16, 34),
	Text = Color3.fromRGB(245, 245, 255),
}

-- The four boards, left to right as you face them.
local STATS = {
	{ key = "Wins", title = "TOP WINS", color = Color3.fromRGB(255, 200, 40), shown = true },
	{ key = "Streak", title = "TOP STREAKS", color = Color3.fromRGB(255, 120, 40), shown = true },
	{ key = "Cash", title = "TOP CASH", color = Color3.fromRGB(90, 220, 90), shown = true },
	{ key = "RobuxSpent", title = "TOP ROBUX", color = Color3.fromRGB(60, 160, 255), shown = false },
}

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- stands a cylinder's axis up
local rng = Random.new(1031)

local lobby = Instance.new("Folder")
lobby.Name = "Lobby"
lobby.Parent = Workspace

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

local function label(parent, text, color, size, offset)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(size.X, size.Y)
	gui.StudsOffset = offset or Vector3.new(0, 3, 0)
	gui.MaxDistance = 160
	gui.Parent = parent
	local text_ = Instance.new("TextLabel")
	text_.Name = "Text"
	text_.Size = UDim2.fromScale(1, 1)
	text_.BackgroundTransparency = 1
	text_.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	text_.TextScaled = true
	text_.TextColor3 = color
	text_.TextStrokeColor3 = Color3.fromRGB(20, 12, 30)
	text_.TextStrokeTransparency = 0
	text_.Text = text
	text_.Parent = gui
	return text_
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
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5

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
local function buildTable(name, center, length, seatsPerSide, title)
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

	local seats = {}
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
		end
	end

	local text
	if title then
		label(top, title, Color3.fromRGB(255, 210, 60), Vector2.new(220, 50), Vector3.new(0, 7, 0))
	end
	text = label(top, "0/" .. #seats, COLORS.Text, Vector2.new(120, 40), Vector3.new(0, title and 4.5 or 4, 0))

	local function refresh()
		local taken = 0
		for _, seat in seats do
			if seat.Occupant then
				taken += 1
			end
		end
		text.Text = taken .. "/" .. #seats
		text.TextColor3 = taken == #seats and Color3.fromRGB(255, 90, 90) or COLORS.Text
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
	buildTable("PartyTable", onDeck(-3, 0, -size.Y / 2 + 34), 13, 3, "PARTY")
end

---------------------------------------------------------------- booths, swings, stage

local function booth(name, center, color, text)
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
	label(glow, text, color, Vector2.new(260, 60), Vector3.new(0, 11, 3))
	return model
end

local function buildExtras()
	local size = CONFIG.DeckSize
	local left = -size.X / 2 + 12
	-- Booths down the left side, facing into the deck.
	local facing = CFrame.Angles(0, -math.pi / 2, 0)
	booth("DailySpins", onDeck(left, 0, 40) * facing, Color3.fromRGB(170, 90, 255), "Daily Spins")
	booth("FreeRewards", onDeck(left, 0, 14) * facing, Color3.fromRGB(255, 210, 40), "Free Rewards")
	booth("Cosmetics", onDeck(left, 0, -12) * facing, Color3.fromRGB(255, 70, 90), "Cosmetics")

	-- Spin wheel beside the Daily Spins booth.
	local wheelCenter = onDeck(left - 3, 9, 52)
	local wheelColors = {
		Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 200, 40), Color3.fromRGB(90, 220, 90), Color3.fromRGB(60, 160, 255),
		Color3.fromRGB(170, 90, 255), Color3.fromRGB(255, 130, 40), Color3.fromRGB(40, 220, 220), Color3.fromRGB(255, 90, 200),
	}
	for i, color in wheelColors do
		newPart(lobby, "WheelSlice", {
			Size = Vector3.new(0.4, 0.9, 5.2),
			CFrame = wheelCenter * CFrame.Angles(math.rad(i * 45), 0, 0) * CFrame.new(0, 0, 2.6),
			Material = Enum.Material.Neon,
			Color = color,
		})
	end
	newPart(lobby, "WheelHub", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 1.8, 1.8),
		CFrame = wheelCenter,
		Material = Enum.Material.Metal,
		Color = COLORS.Iron,
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

	-- Stage with the title sign at the back.
	local back = size.Y / 2 - 9
	newPart(lobby, "Stage", {
		Size = Vector3.new(70, 1.6, 10),
		CFrame = onDeck(0, 0.8, back),
		Material = Enum.Material.Wood,
		Color = COLORS.DarkWood,
	})
	for i = -3, 3 do
		newPart(lobby, "Pedestal", {
			Size = Vector3.new(5, 2 + (3 - math.abs(i)) * 0.6, 5),
			CFrame = onDeck(i * 9, 1.6 + (2 + (3 - math.abs(i)) * 0.6) / 2, back),
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(236, 236, 244),
		})
	end
	local sign = newPart(lobby, "TitleSign", {
		Size = Vector3.new(60, 12, 1),
		CFrame = onDeck(0, 16, size.Y / 2 - 3),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(30, 20, 60),
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.Parent = sign
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0
	text.Text = CONFIG.Title
	text.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 60)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(60, 220, 160)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 90, 255)),
	})
	gradient.Parent = text
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

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.11, 0)
	title.BackgroundColor3 = stat.color
	title.BorderSizePixel = 0
	title.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0
	title.Text = stat.title
	title.Parent = gui

	local rows = {}
	for i = 1, 10 do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(0.94, 0, 0.078, 0)
		row.Position = UDim2.new(0.03, 0, 0.13 + (i - 1) * 0.086, 0)
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
		end
	end
end

local function savePlayer(player)
	if not playerStore then
		return
	end
	local data = { version = 1 }
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
			table.insert(entries, { name = player.DisplayName, value = value.Value })
		end
	end
	table.sort(entries, function(a, b)
		return a.value > b.value
	end)
	return entries
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
					table.insert(entries, { name = nameOf(tonumber(item.key)), value = item.value })
				end
			end
		end
		renderBoard(stat.key, entries or localRanking(stat.key))
	end
end

---------------------------------------------------------------- start

buildSeaAndDeck()
buildTables()
buildExtras()
buildBoards()

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
