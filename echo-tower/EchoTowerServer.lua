-- EchoTowerServer (Script)
-- Put this in ServerScriptService.
--
-- Echo Tower: a co-op time-loop puzzle climb. Every floor is a corridor of
-- gates. A gate only opens while its glowing plate is being stood on. Everyone
-- in the server shares one 32 second loop. Press E to save the run you just did
-- as an "echo": next loop a ghost of you repeats it exactly, standing on the
-- plate while you run through the gate. Reach the exit to climb a floor.
--
-- This script builds the tower, records runs, replays them for the puzzle
-- logic, and keeps score. The LocalScript "EchoTowerClient" draws the echoes
-- and the HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local DataStoreService = game:GetService("DataStoreService")
local PhysicsService = game:GetService("PhysicsService")

local CONFIG = {
	ArenaOrigin = Vector3.new(0, 600, -3000), -- the start pad; the tower runs away from it along -Z
	LoopLength = 32, -- seconds before the loop restarts by itself
	SampleRate = 10, -- recorded positions per second
	MaxEchoesPerPlayer = 4,
	MaxSegments = 6, -- gates on the hardest floors
	MinEchoSeconds = 0.8, -- shorter runs are not worth saving
	StartTime = 150, -- seconds on the run clock when a run starts
	ClearBonus = 35, -- seconds added for every floor cleared
	MaxTime = 300,
	ClearedPause = 2.6,
	GameOverPause = 9,
	RerollCost = 15, -- seconds taken off the clock for a new layout
	RerollCooldown = 25,
	ActionCooldown = 0.3, -- per player, so button mashing can't flood the server
	DataStoreName = "EchoTower_v1",
}

local SHAPE = {
	Width = 36,
	StartLength = 22,
	Approach = 26, -- platform before each gate
	Gap = 14, -- the gate zone: a wall to open, or a void to bridge (too wide to jump)
	ExitLength = 28,
	DoorHeight = 14,
	PlateRadius = 3.4,
	VoidDepth = 22, -- falling this far below the floor sends you back to the start
	SpawnDistance = 8,
}

local PALETTE = {
	Color3.fromRGB(0, 230, 255),
	Color3.fromRGB(255, 70, 200),
	Color3.fromRGB(255, 190, 40),
	Color3.fromRGB(120, 255, 90),
	Color3.fromRGB(160, 110, 255),
	Color3.fromRGB(255, 110, 90),
}
local PALETTE_SIZE = #PALETTE

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- stands a cylinder's axis up
local ORIGIN = CONFIG.ArenaOrigin

---------------------------------------------------------------- LOGIC BEGIN
-- Everything between these markers uses plain numbers and tables only, so it can
-- be tested outside Roblox. Positions are (x, y, d): x sideways, y up from the
-- floor surface, d distance along the tower.

local function shuffle(list, rng)
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

-- Builds the layout of one floor. Gates never need more plates held at once
-- than the players present could cover with their echoes, so every floor can be
-- solved by the people who are there.
local function generateFloor(floor, playerCount, rng)
	local capacity = math.max(1, playerCount) * CONFIG.MaxEchoesPerPlayer
	local segments = math.clamp(1 + floor // 2, 1, CONFIG.MaxSegments)
	local doubles = math.clamp((floor - 2) // 2, 0, segments - 1)
	while doubles > 0 and segments + doubles > capacity do
		doubles -= 1
	end
	segments = math.min(segments, capacity)
	doubles = math.min(doubles, segments - 1)

	local order = {}
	for i = 1, segments do
		order[i] = i
	end
	shuffle(order, rng)
	local isDouble = {}
	for i = 1, doubles do
		isDouble[order[i]] = true
	end

	local colors = {}
	for i = 1, PALETTE_SIZE do
		colors[i] = i
	end
	shuffle(colors, rng)

	local gates = {}
	local needed = 0
	for i = 1, segments do
		local d0 = SHAPE.StartLength + (i - 1) * (SHAPE.Approach + SHAPE.Gap)
		local required = isDouble[i] and 2 or 1
		local plates = {}
		local side = rng:NextInteger(1, 2) == 1 and -1 or 1
		for p = 1, required do
			local sign = required == 1 and side or (p == 1 and -1 or 1)
			plates[p] = {
				x = sign * rng:NextNumber(7, 14),
				d = d0 + rng:NextNumber(4, SHAPE.Approach - 4),
			}
		end
		gates[i] = {
			index = i,
			kind = (floor > 1 and rng:NextInteger(1, 2) == 2) and "bridge" or "door",
			required = required,
			plates = plates,
			d0 = d0,
			d = d0 + SHAPE.Approach + SHAPE.Gap / 2,
			color = colors[(i - 1) % PALETTE_SIZE + 1],
		}
		needed += required
	end

	local exitStart = SHAPE.StartLength + segments * (SHAPE.Approach + SHAPE.Gap)
	return {
		floor = floor,
		gates = gates,
		needed = needed,
		exitStart = exitStart,
		exitD = exitStart + 14,
		endD = exitStart + SHAPE.ExitLength,
	}
end

local function pointOnPlate(plate, p)
	local dx, dd = p.x - plate.x, p.d - plate.d
	return dx * dx + dd * dd <= SHAPE.PlateRadius * SHAPE.PlateRadius and p.y > -1 and p.y < 8
end

-- points: everything that can press a plate (live players and echoes).
-- Returns pressed[gate][plate] and open[gate].
local function evaluateGates(layout, points)
	local pressed, open = {}, {}
	for gi, gate in layout.gates do
		local count = 0
		pressed[gi] = {}
		for pi, plate in gate.plates do
			local on = false
			for _, p in points do
				if pointOnPlate(plate, p) then
					on = true
					break
				end
			end
			pressed[gi][pi] = on
			if on then
				count += 1
			end
		end
		open[gi] = count >= gate.required
	end
	return pressed, open
end

local function inExit(layout, p)
	return p.x * p.x + (p.d - layout.exitD) ^ 2 <= 36 and p.y > -1 and p.y < 8
end

local function newTrack()
	return { count = 0, x = {}, y = {}, d = {}, h = {} }
end

-- Where a recorded run is t seconds into the loop. After it ends it stands still.
local function trackAt(track, t)
	local n = track.count
	local f = t * CONFIG.SampleRate
	if f <= 0 then
		return track.x[1], track.y[1], track.d[1]
	end
	local i = math.floor(f)
	if i >= n - 1 then
		return track.x[n], track.y[n], track.d[n]
	end
	local a = f - i
	local i1, i2 = i + 1, i + 2
	return track.x[i1] + (track.x[i2] - track.x[i1]) * a,
		track.y[i1] + (track.y[i2] - track.y[i1]) * a,
		track.d[i1] + (track.d[i2] - track.d[i1]) * a
end
---------------------------------------------------------------- LOGIC END

local remote = Instance.new("RemoteEvent")
remote.Name = "EchoTowerEvent"
remote.Parent = ReplicatedStorage

local world = Instance.new("Folder")
world.Name = "EchoTower"
world.Parent = Workspace

local state = {
	phase = "Playing", -- Playing, Cleared or GameOver
	floor = 1,
	timeLeft = CONFIG.StartTime,
	layout = nil,
	floorModel = nil,
	gates = {}, -- built gate objects, same order as layout.gates
	loopStart = 0, -- server time the current loop began
	nextSample = 0,
	echoes = {},
	nextEchoId = 1,
	votes = {}, -- [player] = "save" or "retry"
	rec = {}, -- [player] = the track being recorded this loop
	rerollReadyAt = 0,
	lastClockSecond = -1,
}

local lastAction = {}
local rng = Random.new()

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

local function glowOnly(props)
	props.CanCollide = false
	props.CanTouch = false
	props.CanQuery = false
	props.CastShadow = false
	return props
end

local function at(x, y, d)
	return CFrame.new(ORIGIN + Vector3.new(x, y, -d))
end

local function relative(position)
	return position.X - ORIGIN.X, position.Y - ORIGIN.Y, ORIGIN.Z - position.Z
end

local function rootOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return root
	end
	return nil
end

local function toast(player, text)
	remote:FireClient(player, "Toast", { text = text })
end

---------------------------------------------------------------- world

local function setUpWorld()
	Lighting.ClockTime = 0
	Lighting.Brightness = 1.2
	Lighting.Ambient = Color3.fromRGB(46, 40, 84)
	Lighting.OutdoorAmbient = Color3.fromRGB(46, 40, 84)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = false

	if not Lighting:FindFirstChildOfClass("Sky") then
		Instance.new("Sky").Parent = Lighting
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(70, 50, 130)
	atmosphere.Decay = Color3.fromRGB(30, 20, 70)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.7
	bloom.Size = 26
	bloom.Threshold = 1
	bloom.Parent = Lighting

	-- Players walk through each other, so a crowded start pad never blocks anyone.
	pcall(PhysicsService.RegisterCollisionGroup, PhysicsService, "EchoPlayers")
	PhysicsService:CollisionGroupSetCollidable("EchoPlayers", "EchoPlayers", false)
	Players.RespawnTime = 2

	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") then
			descendant.Enabled = false
		end
	end
	newPart(world, "EchoSpawn", {
		Size = Vector3.new(6, 1, 6),
		CFrame = at(0, 0.5, SHAPE.SpawnDistance),
		Transparency = 1,
		CanCollide = false,
		Neutral = true,
		Duration = 0,
	}, "SpawnLocation")

	-- Tower walls and the glowing abyss below, so the floor feels like it hangs in a shaft.
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	scenery.Parent = world
	newPart(scenery, "Abyss", glowOnly({
		Size = Vector3.new(1600, 1, 1600),
		CFrame = at(0, -170, 150),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(70, 20, 120),
		Transparency = 0.55,
	}))
	for i = 0, 14 do
		for _, side in { -1, 1 } do
			local d = -30 + i * 32
			newPart(scenery, "Pillar", {
				Size = Vector3.new(6, 320, 6),
				CFrame = at(side * 66, 40, d),
				Material = Enum.Material.Slate,
				Color = Color3.fromRGB(24, 22, 44),
			})
			for band = 0, 7 do
				newPart(scenery, "PillarBand", glowOnly({
					Size = Vector3.new(6.4, 0.8, 6.4),
					CFrame = at(side * 66, -100 + band * 38, d),
					Material = Enum.Material.Neon,
					Color = PALETTE[(i + band) % PALETTE_SIZE + 1],
				}))
			end
		end
	end
end

local function buildFloor(layout)
	if state.floorModel then
		state.floorModel:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "Floor"
	local theme = Color3.fromHSV((layout.floor * 0.09) % 1, 0.65, 1)
	local width = SHAPE.Width

	local function slab(d0, d1)
		local length, mid = d1 - d0, (d0 + d1) / 2
		newPart(model, "Platform", {
			Size = Vector3.new(width, 2, length),
			CFrame = at(0, -1, mid),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(34, 32, 58),
		})
		for _, side in { -1, 1 } do
			newPart(model, "Trim", glowOnly({
				Size = Vector3.new(0.4, 0.3, length),
				CFrame = at(side * (width / 2 - 0.3), 0.1, mid),
				Material = Enum.Material.Neon,
				Color = theme,
			}))
		end
	end

	slab(0, SHAPE.StartLength)
	local gateObjects = {}
	for i, gate in layout.gates do
		local color = PALETTE[gate.color]
		local object = { kind = gate.kind, open = false, plates = {}, layoutGate = gate }

		if gate.kind == "door" then
			slab(gate.d0, gate.d0 + SHAPE.Approach + SHAPE.Gap)
			local doorSize = Vector3.new(width, SHAPE.DoorHeight, 2)
			object.closedCFrame = at(0, SHAPE.DoorHeight / 2, gate.d)
			object.openCFrame = at(0, -SHAPE.DoorHeight / 2 - 1, gate.d)
			object.part = newPart(model, "Door", {
				Size = doorSize,
				CFrame = object.closedCFrame,
				Material = Enum.Material.Neon,
				Color = color,
				Transparency = 0.3,
			})
		else
			slab(gate.d0, gate.d0 + SHAPE.Approach)
			object.part = newPart(model, "Bridge", {
				Size = Vector3.new(14, 1, SHAPE.Gap + 0.2),
				CFrame = at(0, -0.5, gate.d),
				Material = Enum.Material.Neon,
				Color = color,
				Transparency = 0.88,
				CanCollide = false,
			})
		end

		if gate.required > 1 then
			local label = Instance.new("BillboardGui")
			label.Size = UDim2.fromOffset(120, 36)
			label.StudsOffset = Vector3.new(0, SHAPE.DoorHeight / 2 + 3, 0)
			label.AlwaysOnTop = true
			label.Parent = object.part
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.FontFace = Font.fromEnum(Enum.Font.GothamBold)
			text.TextSize = 22
			text.TextColor3 = color
			text.Text = string.format("%d PLATES", gate.required)
			text.Parent = label
		end

		for p, plate in gate.plates do
			object.plates[p] = newPart(model, "Plate", {
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.5, SHAPE.PlateRadius * 2, SHAPE.PlateRadius * 2),
				CFrame = at(plate.x, 0.25, plate.d) * UPRIGHT,
				Material = Enum.Material.SmoothPlastic,
				Color = color:Lerp(Color3.new(0, 0, 0), 0.65),
				CanCollide = false,
			})
			object.plates[p]:SetAttribute("Pressed", false)
		end
		gateObjects[i] = object
	end
	slab(layout.exitStart, layout.endD)

	-- Exit portal.
	local exit = newPart(model, "Exit", glowOnly({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 12, 12),
		CFrame = at(0, 0.3, layout.exitD) * UPRIGHT,
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 255, 255),
	}))
	local exitLight = Instance.new("PointLight")
	exitLight.Color = theme
	exitLight.Brightness = 3
	exitLight.Range = 28
	exitLight.Parent = exit
	local beam = newPart(model, "ExitBeam", glowOnly({
		Size = Vector3.new(10, 40, 10),
		CFrame = at(0, 20, layout.exitD),
		Material = Enum.Material.Neon,
		Color = theme,
		Transparency = 0.8,
	}))
	local sparks = Instance.new("ParticleEmitter")
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Color = ColorSequence.new(theme, Color3.new(1, 1, 1))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.5, 0)
	sparks.Lifetime = NumberRange.new(1.2, 2)
	sparks.Speed = NumberRange.new(6, 10)
	sparks.Rate = 24
	sparks.Parent = beam

	-- Side rails keep people on the floor; the gaps are the only way to fall.
	local totalLength = layout.endD + 4
	for _, side in { -1, 1 } do
		newPart(model, "Rail", glowOnly({
			Size = Vector3.new(1, 10, totalLength),
			CFrame = at(side * (width / 2 + 0.5), 5, layout.endD / 2),
			Material = Enum.Material.Glass,
			Color = theme,
			Transparency = 0.85,
			CanCollide = true,
		}))
	end
	for _, d in { -0.5, layout.endD + 0.5 } do
		newPart(model, "RailEnd", glowOnly({
			Size = Vector3.new(width + 2, 10, 1),
			CFrame = at(0, 5, d),
			Material = Enum.Material.Glass,
			Color = theme,
			Transparency = 0.85,
			CanCollide = true,
		}))
	end

	-- Floor number above the start pad.
	local sign = newPart(model, "FloorSign", glowOnly({
		Size = Vector3.new(1, 1, 1),
		CFrame = at(0, 18, SHAPE.StartLength - 2),
		Transparency = 1,
	}))
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(400, 90)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 400
	billboard.Parent = sign
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.FontFace = Font.fromEnum(Enum.Font.GothamBlack)
	title.TextSize = 64
	title.TextColor3 = theme
	title.TextStrokeColor3 = Color3.fromRGB(10, 6, 30)
	title.TextStrokeTransparency = 0.3
	title.Text = "FLOOR " .. layout.floor
	title.Parent = billboard

	model.Parent = world
	state.floorModel = model
	state.gates = gateObjects
end

local function setGate(object, open)
	if object.open == open then
		return
	end
	object.open = open
	if object.kind == "door" then
		object.part.CanCollide = not open
		TweenService:Create(object.part, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
			CFrame = open and object.openCFrame or object.closedCFrame,
		}):Play()
	else
		object.part.CanCollide = open
		TweenService:Create(object.part, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
			Transparency = open and 0.1 or 0.88,
		}):Play()
	end
end

local function setPlate(plate, color, pressed)
	if plate:GetAttribute("Pressed") == pressed then
		return
	end
	plate:SetAttribute("Pressed", pressed)
	plate.Material = pressed and Enum.Material.Neon or Enum.Material.SmoothPlastic
	plate.Color = pressed and color or color:Lerp(Color3.new(0, 0, 0), 0.65)
end

---------------------------------------------------------------- loop and echoes

local function startCFrame(index, total)
	local columns = 8
	local column = (index - 1) % columns
	local row = (index - 1) // columns
	local x = (column - (math.min(total, columns) - 1) / 2) * 4
	local d = SHAPE.SpawnDistance + row * 4
	return CFrame.lookAt(ORIGIN + Vector3.new(x, 3.2, -d), ORIGIN + Vector3.new(x, 3.2, -(d + 10)))
end

local function sendToStart(player, index, total)
	local character = player.Character
	if not character then
		return
	end
	character:PivotTo(startCFrame(index, total))
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

local function startLoop()
	state.loopStart = Workspace:GetServerTimeNow()
	state.nextSample = 0
	table.clear(state.votes)
	table.clear(state.rec)

	local all = Players:GetPlayers()
	for index, player in all do
		sendToStart(player, index, #all)
		local track = newTrack()
		track.valid = rootOf(player) ~= nil
		state.rec[player] = track
		remote:FireClient(player, "Rec", { valid = track.valid })
	end
	remote:FireAllClients("Loop", { loopStart = state.loopStart, loopLength = CONFIG.LoopLength })
end

local function encodeTrack(track)
	local data = buffer.create(track.count * 8)
	for i = 1, track.count do
		local offset = (i - 1) * 8
		buffer.writei16(data, offset, math.clamp(math.round(track.x[i] * 20), -32768, 32767))
		buffer.writei16(data, offset + 2, math.clamp(math.round(track.y[i] * 20), -32768, 32767))
		buffer.writei16(data, offset + 4, math.clamp(math.round(track.d[i] * 20), -32768, 32767))
		buffer.writei16(data, offset + 6, math.clamp(math.round(track.h[i] * 10000), -32768, 32767))
	end
	return data
end

local function echoPayload(echo)
	return {
		id = echo.id,
		ownerId = echo.ownerId,
		name = echo.name,
		index = echo.index,
		count = echo.track.count,
		data = echo.data,
	}
end

local function echoesOf(player)
	local owned = {}
	for _, echo in state.echoes do
		if echo.ownerId == player.UserId then
			table.insert(owned, echo)
		end
	end
	return owned
end

local function addEcho(player, track)
	local owned = echoesOf(player)
	if #owned >= CONFIG.MaxEchoesPerPlayer then
		toast(player, "Echo slots are full. Press Q to undo one.")
		return
	end
	local echo = {
		id = state.nextEchoId,
		ownerId = player.UserId,
		name = player.DisplayName,
		index = #owned + 1,
		track = track,
		data = encodeTrack(track),
	}
	state.nextEchoId += 1
	table.insert(state.echoes, echo)
	remote:FireAllClients("Echo", echoPayload(echo))
end

local function clearEchoes()
	table.clear(state.echoes)
	remote:FireAllClients("EchoesCleared", {})
end

local function endLoop()
	for player, track in state.rec do
		if
			state.votes[player] == "save"
			and track.valid
			and track.count >= CONFIG.MinEchoSeconds * CONFIG.SampleRate
			and player.Parent == Players
		then
			addEcho(player, track)
		end
	end
	startLoop()
end

local function allVoted()
	local total = 0
	for _, player in Players:GetPlayers() do
		if rootOf(player) then
			total += 1
			if not state.votes[player] then
				return false
			end
		end
	end
	return total > 0
end

local function sampleTracks()
	for player, track in state.rec do
		if track.valid then
			local root = rootOf(player)
			local n = track.count + 1
			if root then
				local x, y, d = relative(root.Position)
				local look = root.CFrame.LookVector
				track.x[n], track.y[n], track.d[n], track.h[n] = x, y, d, math.atan2(-look.X, -look.Z)
				track.count = n
			elseif track.count > 0 then
				track.x[n], track.y[n], track.d[n], track.h[n] = track.x[n - 1], track.y[n - 1], track.d[n - 1], track.h[n - 1]
				track.count = n
			else
				track.valid = false
			end
		end
	end
end

---------------------------------------------------------------- run flow

local function resetRunClock()
	state.timeLeft = CONFIG.StartTime
	state.lastClockSecond = -1
end

local function sendFloor()
	remote:FireAllClients("Floor", {
		floor = state.floor,
		timeLeft = state.timeLeft,
		gates = #state.layout.gates,
		needed = state.layout.needed,
	})
end

local function loadFloor()
	state.layout = generateFloor(state.floor, #Players:GetPlayers(), rng)
	buildFloor(state.layout)
	clearEchoes()
	state.phase = "Playing"
	sendFloor()
	startLoop()
end

local function floorStats(player)
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Floors"), stats and stats:FindFirstChild("Best")
end

local function floorCleared()
	state.phase = "Cleared"
	remote:FireAllClients("Cleared", { floor = state.floor })
	for _, player in Players:GetPlayers() do
		local floors, best = floorStats(player)
		if floors then
			floors.Value += 1
		end
		if best and state.floor > best.Value then
			best.Value = state.floor
		end
	end
	task.delay(CONFIG.ClearedPause, function()
		if state.phase ~= "Cleared" then
			return
		end
		state.floor += 1
		state.timeLeft = math.min(CONFIG.MaxTime, state.timeLeft + CONFIG.ClearBonus)
		loadFloor()
	end)
end

local savePlayer -- defined with the data code below

local function gameOver()
	state.phase = "GameOver"
	local reached = state.floor - 1
	local best = 0
	for _, player in Players:GetPlayers() do
		local _, bestValue = floorStats(player)
		best = math.max(best, bestValue and bestValue.Value or 0)
		task.spawn(savePlayer, player)
	end
	remote:FireAllClients("GameOver", { reached = reached, best = best })
	task.delay(CONFIG.GameOverPause, function()
		if state.phase ~= "GameOver" then
			return
		end
		state.floor = 1
		resetRunClock()
		for _, player in Players:GetPlayers() do
			local floors = floorStats(player)
			if floors then
				floors.Value = 0
			end
		end
		loadFloor()
	end)
end

local function pressPoints(t)
	local points = {}
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root then
			local x, y, d = relative(root.Position)
			table.insert(points, { x = x, y = y, d = d, player = player })
		end
	end
	local livePoints = #points
	for _, echo in state.echoes do
		local x, y, d = trackAt(echo.track, t)
		table.insert(points, { x = x, y = y, d = d })
	end
	return points, livePoints
end

local function evaluate(t)
	local layout = state.layout
	local points, livePoints = pressPoints(t)
	local pressed, open = evaluateGates(layout, points)

	for gi, object in state.gates do
		local gate = layout.gates[gi]
		for pi, plate in object.plates do
			setPlate(plate, PALETTE[gate.color], pressed[gi][pi])
		end
		local wantOpen = open[gi]
		if not wantOpen and object.open and object.kind == "door" then
			-- Never close a door on someone standing in the doorway.
			for i = 1, livePoints do
				local p = points[i]
				if math.abs(p.d - gate.d) < 3.5 and math.abs(p.x) <= SHAPE.Width / 2 and p.y > -2 then
					wantOpen = true
					break
				end
			end
		end
		setGate(object, wantOpen)
	end

	for i = 1, livePoints do
		local p = points[i]
		if inExit(layout, p) then
			floorCleared()
			return
		end
		if p.y < -SHAPE.VoidDepth then
			local all = Players:GetPlayers()
			sendToStart(p.player, table.find(all, p.player) or 1, #all)
		end
	end
end

local logicClock = 0
RunService.Heartbeat:Connect(function(dt)
	if state.phase ~= "Playing" or #Players:GetPlayers() == 0 then
		return
	end
	state.timeLeft -= dt
	if state.timeLeft <= 0 then
		state.timeLeft = 0
		gameOver()
		return
	end
	local second = math.ceil(state.timeLeft)
	if second ~= state.lastClockSecond then
		state.lastClockSecond = second
		remote:FireAllClients("Clock", { timeLeft = state.timeLeft })
	end

	local t = Workspace:GetServerTimeNow() - state.loopStart
	if t >= CONFIG.LoopLength or allVoted() then
		endLoop()
		return
	end
	while t >= state.nextSample do
		sampleTracks()
		state.nextSample += 1 / CONFIG.SampleRate
	end

	logicClock += dt
	if logicClock >= 0.05 then
		logicClock = 0
		evaluate(t)
	end
end)

---------------------------------------------------------------- player actions

local function snapshot(player)
	local echoes = {}
	for _, echo in state.echoes do
		table.insert(echoes, echoPayload(echo))
	end
	remote:FireClient(player, "Snapshot", {
		origin = ORIGIN,
		floor = state.floor,
		timeLeft = state.timeLeft,
		phase = state.phase,
		loopStart = state.loopStart,
		loopLength = CONFIG.LoopLength,
		sampleRate = CONFIG.SampleRate,
		maxEchoes = CONFIG.MaxEchoesPerPlayer,
		gates = state.layout.gates and #state.layout.gates or 0,
		needed = state.layout.needed,
		echoes = echoes,
	})
	local track = state.rec[player]
	remote:FireClient(player, "Rec", { valid = track ~= nil and track.valid })
end

local actions = {}

function actions.Hello(player)
	snapshot(player)
end

function actions.Save(player)
	if state.phase ~= "Playing" then
		return
	end
	local track = state.rec[player]
	if not (track and track.valid) then
		toast(player, "Wait for the next loop to record an echo.")
		return
	end
	if track.count < CONFIG.MinEchoSeconds * CONFIG.SampleRate then
		toast(player, "Do something first, that run is too short.")
		return
	end
	if #echoesOf(player) >= CONFIG.MaxEchoesPerPlayer then
		toast(player, "Echo slots are full. Press Q to undo one.")
		return
	end
	state.votes[player] = "save"
end

function actions.Retry(player)
	if state.phase == "Playing" then
		state.votes[player] = "retry"
	end
end

function actions.Undo(player)
	if state.phase ~= "Playing" then
		return
	end
	local owned = echoesOf(player)
	local last = owned[#owned]
	if last then
		table.remove(state.echoes, table.find(state.echoes, last))
		remote:FireAllClients("EchoGone", { id = last.id })
	end
end

function actions.Reroll(player)
	local now = os.clock()
	if state.phase ~= "Playing" then
		return
	end
	if now < state.rerollReadyAt then
		toast(player, "A new layout is cooling down.")
		return
	end
	if state.timeLeft <= CONFIG.RerollCost + 5 then
		toast(player, "Not enough time left for a new layout.")
		return
	end
	state.rerollReadyAt = now + CONFIG.RerollCooldown
	state.timeLeft -= CONFIG.RerollCost
	for _, other in Players:GetPlayers() do
		toast(other, string.format("%s asked for a new layout (-%ds).", player.DisplayName, CONFIG.RerollCost))
	end
	loadFloor()
end

remote.OnServerEvent:Connect(function(player, action)
	if type(action) ~= "string" or not actions[action] then
		return
	end
	local now = os.clock()
	if action ~= "Hello" and now - (lastAction[player] or 0) < CONFIG.ActionCooldown then
		return
	end
	lastAction[player] = now
	actions[action](player)
end)

---------------------------------------------------------------- players and saving

local store
pcall(function()
	store = DataStoreService:GetDataStore(CONFIG.DataStoreName)
end)

local function keyFor(player)
	return "u_" .. player.UserId
end

local function loadBest(player)
	if not store then
		return 0
	end
	for _ = 1, 3 do
		local ok, value = pcall(store.GetAsync, store, keyFor(player))
		if ok then
			return type(value) == "table" and tonumber(value.best) or 0
		end
		task.wait(1.5)
	end
	return 0
end

function savePlayer(player)
	local _, best = floorStats(player)
	if not (store and best) then
		return
	end
	local value = best.Value
	pcall(store.UpdateAsync, store, keyFor(player), function(old)
		old = type(old) == "table" and old or { version = 1 }
		old.best = math.max(tonumber(old.best) or 0, value)
		return old
	end)
end

local function protectCollision(character)
	local function apply(descendant)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = "EchoPlayers"
		end
	end
	for _, descendant in character:GetDescendants() do
		apply(descendant)
	end
	character.DescendantAdded:Connect(apply)
end

local function onPlayerAdded(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local floors = Instance.new("IntValue")
	floors.Name = "Floors"
	floors.Parent = stats
	local best = Instance.new("IntValue")
	best.Name = "Best"
	best.Parent = stats
	stats.Parent = player
	task.spawn(function()
		best.Value = loadBest(player)
	end)

	player.CharacterAdded:Connect(function(character)
		protectCollision(character)
		if state.rec[player] == nil then
			state.rec[player] = newTrack() -- joined mid-loop: records from the next loop
			state.rec[player].valid = false
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	savePlayer(player)
	state.rec[player] = nil
	state.votes[player] = nil
	lastAction[player] = nil
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		savePlayer(player)
	end
end)

---------------------------------------------------------------- start

setUpWorld()
state.layout = generateFloor(state.floor, 1, rng)
buildFloor(state.layout)
startLoop()
