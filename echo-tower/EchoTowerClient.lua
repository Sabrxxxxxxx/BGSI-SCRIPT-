-- EchoTowerClient (LocalScript)
-- Put this in StarterPlayer > StarterPlayerScripts.
--
-- Draws everything you see for Echo Tower: the echo ghosts replaying saved
-- runs, the HUD, and the buttons and keys. The Script "EchoTowerServer" builds
-- the tower and runs the rules.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("EchoTowerEvent")

local THEME = {
	Panel = Color3.fromRGB(16, 14, 38),
	PanelSoft = Color3.fromRGB(32, 28, 70),
	Stroke = Color3.fromRGB(86, 76, 170),
	Text = Color3.fromRGB(242, 242, 255),
	Sub = Color3.fromRGB(170, 170, 224),
	Accent = Color3.fromRGB(0, 230, 255),
	Hot = Color3.fromRGB(255, 70, 200),
	Good = Color3.fromRGB(120, 255, 90),
	Warn = Color3.fromRGB(255, 190, 40),
	Radius = UDim.new(0, 10),
	FontBlack = Font.fromEnum(Enum.Font.GothamBlack),
	FontBold = Font.fromEnum(Enum.Font.GothamBold),
	FontMedium = Font.fromEnum(Enum.Font.GothamMedium),
	FontMono = Font.fromEnum(Enum.Font.RobotoMono),
}

local session = {
	origin = Vector3.zero,
	floor = 1,
	phase = "Playing",
	timeLeft = 0,
	clockAt = 0,
	loopStart = 0,
	loopLength = 32,
	sampleRate = 10,
	maxEchoes = 4,
	needed = 0,
	gates = 0,
	recording = false,
}
local echoes = {} -- [id] = { id, ownerId, name, index, track, ghost }

---------------------------------------------------------------- small helpers

local function make(className, props, parent)
	local instance = Instance.new(className)
	for key, value in props do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function ownerColor(ownerId)
	return Color3.fromHSV((ownerId % 360) / 360, 0.55, 1)
end

local function formatClock(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function lerpAngle(a, b, t)
	local diff = (b - a + math.pi) % (math.pi * 2) - math.pi
	return a + diff * t
end

---------------------------------------------------------------- tracks

local function decodeTrack(data, count)
	local track = { count = count, x = {}, y = {}, d = {}, h = {} }
	for i = 1, count do
		local offset = (i - 1) * 8
		track.x[i] = buffer.readi16(data, offset) / 20
		track.y[i] = buffer.readi16(data, offset + 2) / 20
		track.d[i] = buffer.readi16(data, offset + 4) / 20
		track.h[i] = buffer.readi16(data, offset + 6) / 10000
	end
	return track
end

-- Where a saved run is t seconds into the loop. After it ends it stands still.
local function trackAt(track, t)
	local n = track.count
	local f = t * session.sampleRate
	if f <= 0 then
		return track.x[1], track.y[1], track.d[1], track.h[1]
	end
	local i = math.floor(f)
	if i >= n - 1 then
		return track.x[n], track.y[n], track.d[n], track.h[n]
	end
	local a = f - i
	local i1, i2 = i + 1, i + 2
	return track.x[i1] + (track.x[i2] - track.x[i1]) * a,
		track.y[i1] + (track.y[i2] - track.y[i1]) * a,
		track.d[i1] + (track.d[i2] - track.d[i1]) * a,
		lerpAngle(track.h[i1], track.h[i2], a)
end

---------------------------------------------------------------- HUD

local gui = make("ScreenGui", {
	Name = "EchoTowerHUD",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 10,
}, player:WaitForChild("PlayerGui"))

local root = make("Frame", { Name = "Root", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
local uiScale = make("UIScale", {}, root)

local function updateScale()
	local camera = Workspace.CurrentCamera
	if camera then
		local view = camera.ViewportSize
		local scale = math.clamp(math.min(view.X / 1000, view.Y / 620), 0.85, 1.35)
		uiScale.Scale = scale
		root.Size = UDim2.fromScale(1 / scale, 1 / scale) -- scaled back up to exactly the screen
	end
end
updateScale()
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

local function panel(name, parent)
	local frame = make("Frame", {
		Name = name,
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.12,
		AutomaticSize = Enum.AutomaticSize.XY,
	}, parent)
	make("UICorner", { CornerRadius = THEME.Radius }, frame)
	make("UIStroke", { Color = THEME.Stroke, Thickness = 1.5 }, frame)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 18),
		PaddingRight = UDim.new(0, 18),
	}, frame)
	return frame
end

local function label(name, parent, text, size, color, font, order)
	return make("TextLabel", {
		Name = name,
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		FontFace = font,
		TextSize = size,
		TextColor3 = color,
		Text = text,
		LayoutOrder = order,
	}, parent)
end

-- Top card: floor, run clock, how many plates the floor needs, and the loop bar.
local topCard = panel("TopCard", root)
topCard.AnchorPoint = Vector2.new(0.5, 0)
topCard.Position = UDim2.new(0.5, 0, 0, 8)
make("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 2),
}, topCard)
local floorLabel = label("Floor", topCard, "FLOOR 1", 28, THEME.Accent, THEME.FontBlack, 1)
local clockLabel = label("Clock", topCard, "2:30", 22, THEME.Text, THEME.FontMono, 2)
local needLabel = label("Need", topCard, "", 14, THEME.Sub, THEME.FontMedium, 3)
local loopTrack = make("Frame", {
	Name = "LoopBar",
	Size = UDim2.fromOffset(220, 6),
	BackgroundColor3 = THEME.PanelSoft,
	BorderSizePixel = 0,
	LayoutOrder = 4,
}, topCard)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, loopTrack)
local loopFill = make("Frame", {
	Name = "Fill",
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = THEME.Accent,
	BorderSizePixel = 0,
}, loopTrack)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, loopFill)

-- Actions column on the right edge, clear of the thumbstick and the jump button.
local actions = make("Frame", {
	Name = "Actions",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, 0),
	Size = UDim2.fromOffset(176, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
}, root)
make("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 8),
}, actions)

local showKeys = UserInputService.KeyboardEnabled or UserInputService.GamepadEnabled

local function actionButton(name, text, key, color, order, send)
	local button = make("TextButton", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundColor3 = color,
		AutoButtonColor = false,
		FontFace = THEME.FontBold,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(10, 8, 28),
		Text = (showKeys and key) and string.format("%s  [%s]", text, key) or text,
		LayoutOrder = order,
	}, actions)
	make("UICorner", { CornerRadius = THEME.Radius }, button)
	local scale = make("UIScale", {}, button)
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundTransparency = 0.12 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundTransparency = 0 }):Play()
	end)
	button.Activated:Connect(function()
		scale.Scale = 0.94
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		remote:FireServer(send)
	end)
	return button
end

actionButton("SaveButton", "SAVE ECHO", "E", THEME.Accent, 1, "Save")
actionButton("RetryButton", "RETRY", "R", THEME.Warn, 2, "Retry")
actionButton("UndoButton", "UNDO ECHO", "Q", THEME.Hot, 3, "Undo")
actionButton("RerollButton", "NEW LAYOUT", nil, THEME.Sub, 4, "Reroll")

-- Bottom: hint, toast, and your echo slots.
local bottom = make("Frame", {
	Name = "Bottom",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.new(1, -220, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
}, root)
make("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	Padding = UDim.new(0, 8),
}, bottom)

local hintLabel = make("TextLabel", {
	Name = "Hint",
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	FontFace = THEME.FontMedium,
	TextSize = 17,
	TextColor3 = THEME.Text,
	TextStrokeColor3 = Color3.fromRGB(10, 6, 30),
	TextStrokeTransparency = 0.4,
	TextWrapped = true,
	Text = "",
	LayoutOrder = 1,
}, bottom)
make("UISizeConstraint", { MaxSize = Vector2.new(520, math.huge) }, hintLabel)

local toastLabel = make("TextLabel", {
	Name = "Toast",
	AutomaticSize = Enum.AutomaticSize.XY,
	BackgroundColor3 = THEME.Panel,
	BackgroundTransparency = 1,
	FontFace = THEME.FontBold,
	TextSize = 16,
	TextColor3 = THEME.Warn,
	TextTransparency = 1,
	Text = "",
	LayoutOrder = 2,
}, bottom)
make("UICorner", { CornerRadius = THEME.Radius }, toastLabel)
make("UIPadding", {
	PaddingTop = UDim.new(0, 6),
	PaddingBottom = UDim.new(0, 6),
	PaddingLeft = UDim.new(0, 12),
	PaddingRight = UDim.new(0, 12),
}, toastLabel)

local slotRow = make("Frame", {
	Name = "EchoSlots",
	AutomaticSize = Enum.AutomaticSize.XY,
	BackgroundTransparency = 1,
	LayoutOrder = 3,
}, bottom)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 8),
}, slotRow)
local recordDot = make("Frame", {
	Name = "RecordDot",
	Size = UDim2.fromOffset(12, 12),
	BackgroundColor3 = THEME.Hot,
	BorderSizePixel = 0,
	LayoutOrder = 0,
}, slotRow)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, recordDot)
local recordLabel = label("RecordLabel", slotRow, "RECORDING", 14, THEME.Text, THEME.FontBold, 1)

local slots = {}
local function buildSlots(count)
	for _, slot in slots do
		slot.frame:Destroy()
	end
	table.clear(slots)
	for i = 1, count do
		local frame = make("Frame", {
			Name = "Slot" .. i,
			Size = UDim2.fromOffset(38, 38),
			BackgroundColor3 = THEME.PanelSoft,
			LayoutOrder = 10 + i,
		}, slotRow)
		make("UICorner", { CornerRadius = THEME.Radius }, frame)
		local stroke = make("UIStroke", { Color = THEME.Stroke, Thickness = 1.5 }, frame)
		local text = make("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			FontFace = THEME.FontBlack,
			TextSize = 18,
			TextColor3 = THEME.Sub,
			Text = tostring(i),
		}, frame)
		slots[i] = { frame = frame, stroke = stroke, text = text }
	end
end
buildSlots(session.maxEchoes)

-- Big centre banner for cleared floors and the end of a run.
local banner = make("Frame", {
	Name = "Banner",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.new(0.9, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Visible = false,
}, root)
make("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 6),
}, banner)
local bannerTitle = make("TextLabel", {
	Name = "Title",
	Size = UDim2.new(1, 0, 0, 70),
	BackgroundTransparency = 1,
	FontFace = THEME.FontBlack,
	TextSize = 60,
	TextColor3 = THEME.Accent,
	TextStrokeColor3 = Color3.fromRGB(10, 6, 30),
	TextStrokeTransparency = 0.2,
	TextTransparency = 1,
	Text = "",
	LayoutOrder = 1,
}, banner)
make("UISizeConstraint", { MaxSize = Vector2.new(640, math.huge) }, banner)
local bannerSub = make("TextLabel", {
	Name = "Sub",
	Size = UDim2.new(1, 0, 0, 28),
	BackgroundTransparency = 1,
	FontFace = THEME.FontBold,
	TextSize = 22,
	TextColor3 = THEME.Text,
	TextStrokeColor3 = Color3.fromRGB(10, 6, 30),
	TextStrokeTransparency = 0.3,
	TextTransparency = 1,
	Text = "",
	LayoutOrder = 2,
}, banner)
local bannerScale = make("UIScale", {}, bannerTitle)

local flash = make("Frame", {
	Name = "Flash",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 0,
}, root)

local bannerToken = 0
local function showBanner(title, sub, color, hold)
	bannerToken += 1
	local token = bannerToken
	bannerTitle.Text = title
	bannerTitle.TextColor3 = color
	bannerSub.Text = sub or ""
	bannerTitle.TextTransparency = 1
	bannerSub.TextTransparency = 1
	bannerScale.Scale = 0.8
	banner.Visible = true

	local enter = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	TweenService:Create(bannerTitle, enter, { TextTransparency = 0 }):Play()
	TweenService:Create(bannerSub, enter, { TextTransparency = 0 }):Play()
	TweenService:Create(bannerScale, enter, { Scale = 1 }):Play()

	task.delay(hold, function()
		if token ~= bannerToken then
			return
		end
		local leave = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(bannerTitle, leave, { TextTransparency = 1 }):Play()
		local fade = TweenService:Create(bannerSub, leave, { TextTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		if token == bannerToken then
			banner.Visible = false
		end
	end)
end

local function flashScreen(color)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 0.55
	TweenService:Create(flash, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
end

local toastToken = 0
local function toast(text)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = text
	toastLabel.TextTransparency = 0
	toastLabel.BackgroundTransparency = 0.15
	task.delay(2.6, function()
		if token ~= toastToken then
			return
		end
		TweenService:Create(toastLabel, TweenInfo.new(0.3), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
	end)
end

local function myEchoCount()
	local count = 0
	for _, echo in echoes do
		if echo.ownerId == player.UserId then
			count += 1
		end
	end
	return count
end

local function refreshSlots()
	local mine = {}
	for _, echo in echoes do
		if echo.ownerId == player.UserId then
			table.insert(mine, echo)
		end
	end
	table.sort(mine, function(a, b)
		return a.id < b.id
	end)
	for i, slot in slots do
		local echo = mine[i]
		if echo then
			slot.frame.BackgroundColor3 = ownerColor(echo.ownerId)
			slot.text.TextColor3 = Color3.fromRGB(10, 8, 28)
			slot.stroke.Color = Color3.new(1, 1, 1)
		else
			slot.frame.BackgroundColor3 = THEME.PanelSoft
			slot.text.TextColor3 = THEME.Sub
			slot.stroke.Color = THEME.Stroke
		end
	end
end

local function refreshHint()
	local text = ""
	if session.phase == "Playing" then
		if session.floor == 1 then
			if myEchoCount() == 0 then
				text = "Stand on the glowing plate, then press SAVE ECHO. Next loop a ghost of you keeps holding it while you run through the gate to the exit."
			else
				text = "Your echo holds the plate now. Run through the open gate to the exit portal."
			end
		elseif session.floor == 2 then
			text = "Each gate has its own color. Its plate has the same color. Save an echo for every plate."
		end
	end
	hintLabel.Text = text
end

local function refreshNeed()
	if session.needed > 0 then
		needLabel.Text = string.format("%d gate%s . %d plate%s to hold", session.gates, session.gates == 1 and "" or "s", session.needed, session.needed == 1 and "" or "s")
	else
		needLabel.Text = ""
	end
end

local function refreshRecording()
	recordDot.Visible = session.recording
	recordLabel.Text = session.recording and "RECORDING" or "WAIT FOR NEXT LOOP"
	recordLabel.TextColor3 = session.recording and THEME.Text or THEME.Sub
end
refreshRecording()

---------------------------------------------------------------- echo ghosts

local ghostFolder = make("Folder", { Name = "EchoGhosts" }, Workspace)

local function ghostPart(model, name, shape, size, offset, color, transparency)
	local part = make("Part", {
		Name = name,
		Shape = shape,
		Size = size,
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = transparency,
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		CastShadow = false,
	}, model)
	return { part = part, offset = offset, base = transparency }
end

local function buildGhost(echo)
	local color = ownerColor(echo.ownerId)
	local model = make("Model", { Name = "Echo_" .. echo.id }, ghostFolder)
	local parts = {}
	local block, ball = Enum.PartType.Block, Enum.PartType.Ball

	local torso = ghostPart(model, "Torso", block, Vector3.new(2, 2, 1), CFrame.new(), color, 0.35)
	table.insert(parts, torso)
	local head = ghostPart(model, "Head", ball, Vector3.one * 1.3, CFrame.new(0, 1.75, 0), color, 0.3)
	table.insert(parts, head)
	table.insert(parts, ghostPart(model, "Visor", block, Vector3.new(0.9, 0.25, 0.1), CFrame.new(0, 1.8, -0.6), Color3.fromRGB(12, 10, 30), 0.1))

	local limbs = {}
	local function limb(name, x, pivotY, length, width, sign)
		local entry = ghostPart(model, name, block, Vector3.new(width, length, width), CFrame.new(), color, 0.5)
		entry.pivot = CFrame.new(x, pivotY, 0)
		entry.half = length / 2
		entry.sign = sign
		table.insert(parts, entry)
		table.insert(limbs, entry)
	end
	limb("LeftArm", -1.4, 1, 1.8, 0.7, 1)
	limb("RightArm", 1.4, 1, 1.8, 0.7, -1)
	limb("LeftLeg", -0.55, -1, 1.9, 0.85, -1)
	limb("RightLeg", 0.55, -1, 1.9, 0.85, 1)

	make("PointLight", { Color = color, Brightness = 0.9, Range = 9 }, torso.part)
	local trail = make("ParticleEmitter", {
		Color = ColorSequence.new(color),
		LightEmission = 1,
		Size = NumberSequence.new(0.7, 0),
		Transparency = NumberSequence.new(0.4, 1),
		Lifetime = NumberRange.new(0.5, 0.8),
		Speed = NumberRange.new(0, 0.5),
		Rate = 10,
	}, torso.part)
	trail.Name = "Trail"

	local tag = make("BillboardGui", {
		Size = UDim2.fromOffset(150, 26),
		StudsOffset = Vector3.new(0, 2.6, 0),
		AlwaysOnTop = true,
		MaxDistance = 140,
	}, head.part)
	make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		FontFace = THEME.FontBold,
		TextSize = 14,
		TextColor3 = color,
		TextStrokeColor3 = Color3.fromRGB(10, 6, 30),
		TextStrokeTransparency = 0.3,
		Text = string.format("%s #%d", echo.ownerId == player.UserId and "You" or echo.name, echo.index),
	}, tag)

	return { model = model, parts = parts, limbs = limbs, lastPosition = nil }
end

local function addEcho(payload)
	if echoes[payload.id] or payload.count < 1 then
		return
	end
	local echo = {
		id = payload.id,
		ownerId = payload.ownerId,
		name = payload.name,
		index = payload.index,
		track = decodeTrack(payload.data, payload.count),
	}
	echo.ghost = buildGhost(echo)
	echoes[echo.id] = echo
	refreshSlots()
	refreshHint()
end

local function removeEcho(id)
	local echo = echoes[id]
	if echo then
		echo.ghost.model:Destroy()
		echoes[id] = nil
		refreshSlots()
		refreshHint()
	end
end

local function clearEchoes()
	for id in echoes do
		removeEcho(id)
	end
end

local function updateGhost(echo, t, dt, clock)
	local ghost = echo.ghost
	local x, y, d, heading = trackAt(echo.track, t)
	local position = session.origin + Vector3.new(x, y, -d)
	local rootCFrame = CFrame.new(position) * CFrame.Angles(0, heading, 0)

	local moving = false
	if ghost.lastPosition and dt > 0 then
		moving = (position - ghost.lastPosition).Magnitude / dt > 2
	end
	ghost.lastPosition = position
	local swing = moving and math.sin(clock * 11) * 0.7 or 0

	-- Fade in at the start of each loop so the replay reads as a rewind.
	local fade = math.clamp(t / 0.45, 0, 1)

	for _, entry in ghost.parts do
		if entry.pivot then
			entry.part.CFrame = rootCFrame * entry.pivot * CFrame.Angles(swing * entry.sign, 0, 0) * CFrame.new(0, -entry.half, 0)
		else
			entry.part.CFrame = rootCFrame * entry.offset
		end
		if fade < 1 then
			entry.part.Transparency = 1 - (1 - entry.base) * fade
		end
	end
end

---------------------------------------------------------------- messages

local handlers = {}

function handlers.Snapshot(data)
	session.origin = data.origin
	session.floor = data.floor
	session.phase = data.phase
	session.timeLeft = data.timeLeft
	session.clockAt = os.clock()
	session.loopStart = data.loopStart
	session.loopLength = data.loopLength
	session.sampleRate = data.sampleRate
	session.gates = data.gates
	session.needed = data.needed
	if data.maxEchoes ~= session.maxEchoes then
		session.maxEchoes = data.maxEchoes
		buildSlots(session.maxEchoes)
	end
	clearEchoes()
	for _, payload in data.echoes do
		addEcho(payload)
	end
	floorLabel.Text = "FLOOR " .. session.floor
	refreshNeed()
	refreshSlots()
	refreshHint()
end

function handlers.Loop(data)
	session.loopStart = data.loopStart
	session.loopLength = data.loopLength
	loopFill.BackgroundColor3 = THEME.Hot
	TweenService:Create(loopFill, TweenInfo.new(0.5), { BackgroundColor3 = THEME.Accent }):Play()
end

function handlers.Rec(data)
	session.recording = data.valid
	refreshRecording()
end

function handlers.Echo(data)
	addEcho(data)
end

function handlers.EchoGone(data)
	removeEcho(data.id)
end

function handlers.EchoesCleared()
	clearEchoes()
end

function handlers.Floor(data)
	session.floor = data.floor
	session.phase = "Playing"
	session.timeLeft = data.timeLeft
	session.clockAt = os.clock()
	session.gates = data.gates
	session.needed = data.needed
	floorLabel.Text = "FLOOR " .. data.floor
	refreshNeed()
	refreshHint()
	showBanner("FLOOR " .. data.floor, nil, THEME.Accent, 1.1)
end

function handlers.Clock(data)
	session.timeLeft = data.timeLeft
	session.clockAt = os.clock()
end

function handlers.Cleared(data)
	session.phase = "Cleared"
	refreshHint()
	flashScreen(THEME.Good)
	showBanner("FLOOR CLEARED", "Time added to the clock", THEME.Good, 2.2)
end

function handlers.GameOver(data)
	session.phase = "GameOver"
	session.timeLeft = 0
	refreshHint()
	flashScreen(THEME.Hot)
	showBanner("RUN OVER", string.format("You reached floor %d   Best: %d", data.reached, data.best), THEME.Hot, 8)
end

function handlers.Toast(data)
	toast(data.text)
end

remote.OnClientEvent:Connect(function(action, data)
	local handler = handlers[action]
	if handler then
		handler(data or {})
	end
end)

---------------------------------------------------------------- input

local function bind(name, send, ...)
	ContextActionService:BindAction(name, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			remote:FireServer(send)
		end
		return Enum.ContextActionResult.Sink
	end, false, ...)
end
bind("EchoTowerSave", "Save", Enum.KeyCode.E, Enum.KeyCode.ButtonX)
bind("EchoTowerRetry", "Retry", Enum.KeyCode.R, Enum.KeyCode.ButtonY)
bind("EchoTowerUndo", "Undo", Enum.KeyCode.Q, Enum.KeyCode.ButtonL1)

---------------------------------------------------------------- frame loop

local lastClockText = ""
RunService.RenderStepped:Connect(function(dt)
	local now = Workspace:GetServerTimeNow()
	local t = math.max(0, now - session.loopStart)
	local clock = os.clock()

	for _, echo in echoes do
		updateGhost(echo, t, dt, clock)
	end

	loopFill.Size = UDim2.fromScale(math.clamp(t / session.loopLength, 0, 1), 1)

	local shown = session.timeLeft
	if session.phase == "Playing" then
		shown = math.max(0, session.timeLeft - (clock - session.clockAt))
	end
	local text = formatClock(shown)
	if text ~= lastClockText then
		lastClockText = text
		clockLabel.Text = text
		clockLabel.TextColor3 = shown <= 20 and THEME.Hot or THEME.Text
	end
end)

remote:FireServer("Hello")
