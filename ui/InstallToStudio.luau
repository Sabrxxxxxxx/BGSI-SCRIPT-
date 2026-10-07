-- Paste this whole script into Roblox Studio's Command bar and press Ctrl+Enter.
-- It creates StarterPlayer.StarterPlayerScripts.GameUI with Main, GameUI and Style.

local sps = game:GetService('StarterPlayer'):WaitForChild('StarterPlayerScripts')
local old = sps:FindFirstChild('GameUI') if old then old:Destroy() end
local folder = Instance.new('Folder') folder.Name = 'GameUI' folder.Parent = sps

local function add(name, className, source)
	local s = Instance.new(className) s.Name = name s.Source = source s.Parent = folder
end

add('Style', 'ModuleScript', [==[
--!nonstrict
-- Style.luau
-- Shared builders for the chunky "checker tile" look: GothamBlack text, thick black borders,
-- gradient tiles with a faint checkerboard overlay, 3D-ish hover/click scaling.
-- Follows the Check-UI rules (GothamBlack everywhere, center-anchored UIScale animations,
-- ScaleType.Fit icons, responsive UIScale) but with the dark-panel look of the reference screens.

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Style = {}

----------------------------------------------------
-- Sound effects (swap the ids for your own UI sounds)
----------------------------------------------------
Style.SoundIds = {
	Click = "rbxassetid://6895079853",
	Hover = "rbxassetid://6895079853",
}
local SOUND_SPECS = {
	hover = { key = "Hover", speed = 1.35, volume = 0.22 },
	click = { key = "Click", speed = 1.0, volume = 0.5 },
	open = { key = "Click", speed = 0.78, volume = 0.6 },
	close = { key = "Click", speed = 1.25, volume = 0.5 },
	success = { key = "Click", speed = 1.7, volume = 0.7 },
	error = { key = "Click", speed = 0.55, volume = 0.5 },
}
local soundCache = {}

function Style.play(kind)
	local spec = SOUND_SPECS[kind]
	if not spec then
		return
	end
	local snd = soundCache[kind]
	if not snd then
		snd = Instance.new("Sound")
		snd.Name = "UI_" .. kind
		snd.SoundId = Style.SoundIds[spec.key]
		snd.Volume = spec.volume
		snd.PlaybackSpeed = spec.speed
		snd.Parent = SoundService
		soundCache[kind] = snd
	end
	snd.TimePosition = 0
	snd:Play()
end

----------------------------------------------------
-- One shared loop for idle animations (bobbing icons, shine sweeps, ...)
----------------------------------------------------
local idleList = {}
local idleStarted = false

function Style.onIdle(instance, fn)
	table.insert(idleList, { instance = instance, fn = fn })
	if idleStarted then
		return
	end
	idleStarted = true
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for i = #idleList, 1, -1 do
			local entry = idleList[i]
			if not entry.instance:IsDescendantOf(game) then
				table.remove(idleList, i)
			else
				entry.fn(t)
			end
		end
	end)
end

Style.Font = Enum.Font.GothamBlack
Style.Checker = "rbxassetid://385956923"
Style.Black = Color3.fromRGB(0, 0, 0)
Style.White = Color3.fromRGB(255, 255, 255)
Style.PanelColor = Color3.fromRGB(24, 28, 33)

-- Asset ids come from the Check-UI icon registry (CheckUIIcons.luau).
Style.Icons = {
	Cart = "rbxassetid://82781328025500",       -- Golden_Shopping_Cart_1st
	Pet = "rbxassetid://94720044097792",        -- Dog_1st
	Rebirth = "rbxassetid://113853797647690",   -- Rebirth_1st
	Backpack = "rbxassetid://125244480696413",  -- Backpack_1st
	World = "rbxassetid://99800203121460",      -- Green_Planet_1st
	Trophy = "rbxassetid://95627251936493",     -- Golden_Trophy_1st
	Star = "rbxassetid://93302981101722",       -- Golden_Star_1st
	Robux = "rbxassetid://132185731364109",     -- Robux_White
	Heart = "rbxassetid://93345130450401",      -- Angel_Heart_1st
	Chest = "rbxassetid://122517779292851",     -- Chest_1st
	AutoClick = "rbxassetid://95896876064200",  -- Auto_Open_1st
	Sword = "rbxassetid://82457981839848",      -- Sword_1st
	Plus = "rbxassetid://74804085353767",       -- Plus_White
}

-- Gradients: { top, bottom } (rotated 90 so they run top -> bottom)
Style.Gradients = {
	Orange = { Color3.fromRGB(255, 214, 20), Color3.fromRGB(255, 130, 0) },
	Yellow = { Color3.fromRGB(255, 236, 40), Color3.fromRGB(255, 176, 0) },
	Green = { Color3.fromRGB(120, 235, 40), Color3.fromRGB(30, 190, 20) },
	Lime = { Color3.fromRGB(190, 255, 30), Color3.fromRGB(100, 225, 0) },
	Red = { Color3.fromRGB(255, 70, 70), Color3.fromRGB(225, 10, 20) },
	Purple = { Color3.fromRGB(190, 90, 255), Color3.fromRGB(120, 30, 220) },
	Blue = { Color3.fromRGB(70, 200, 255), Color3.fromRGB(30, 120, 240) },
	Cyan = { Color3.fromRGB(150, 235, 255), Color3.fromRGB(70, 190, 250) },
	BluePurple = { Color3.fromRGB(0, 220, 255), Color3.fromRGB(150, 70, 255) },
	Pink = { Color3.fromRGB(255, 90, 200), Color3.fromRGB(215, 20, 110) },
	Gold = { Color3.fromRGB(255, 214, 70), Color3.fromRGB(235, 160, 10) },
	RedOrange = { Color3.fromRGB(255, 80, 40), Color3.fromRGB(255, 150, 20) },
	Grey = { Color3.fromRGB(205, 210, 218), Color3.fromRGB(135, 143, 156) },
	DarkGrey = { Color3.fromRGB(118, 124, 132), Color3.fromRGB(78, 84, 92) },
	Navy = { Color3.fromRGB(52, 58, 92), Color3.fromRGB(26, 30, 56) },
}

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 30, 70)),
	ColorSequenceKeypoint.new(0.20, Color3.fromRGB(255, 150, 0)),
	ColorSequenceKeypoint.new(0.38, Color3.fromRGB(255, 240, 0)),
	ColorSequenceKeypoint.new(0.55, Color3.fromRGB(40, 230, 60)),
	ColorSequenceKeypoint.new(0.72, Color3.fromRGB(0, 200, 255)),
	ColorSequenceKeypoint.new(0.88, Color3.fromRGB(110, 60, 255)),
	ColorSequenceKeypoint.new(1.00, Color3.fromRGB(230, 0, 230)),
})
Style.Rainbow = RAINBOW

local function toSequence(grad)
	if typeof(grad) == "ColorSequence" then
		return grad
	end
	return ColorSequence.new(grad[1], grad[2])
end

----------------------------------------------------
-- Primitives
----------------------------------------------------
function Style.stroke(parent, thickness, color, mode)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color or Style.Black
	s.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

-- White GothamBlack text with a black outline.
function Style.label(props)
	local l = Instance.new("TextLabel")
	l.Name = props.Name or "Label"
	l.Text = props.Text or ""
	l.Font = Style.Font
	l.TextSize = props.TextSize or 24
	l.TextColor3 = props.Color or Style.White
	l.TextXAlignment = props.XAlignment or Enum.TextXAlignment.Center
	l.TextYAlignment = props.YAlignment or Enum.TextYAlignment.Center
	l.TextWrapped = props.Wrapped or false
	l.RichText = props.RichText or false
	l.BackgroundTransparency = 1
	l.Size = props.Size or UDim2.new(1, 0, 1, 0)
	l.Position = props.Position or UDim2.new(0, 0, 0, 0)
	l.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	l.ZIndex = props.ZIndex or 5
	l.Parent = props.Parent
	local s = Style.stroke(l, props.StrokeThickness or math.max(2, (props.TextSize or 24) / 9), props.StrokeColor,
		Enum.ApplyStrokeMode.Contextual)
	s.Name = "TextStroke"
	return l
end

function Style.icon(props)
	if not props.NoShadow then
		local pos = props.Position or UDim2.new(0.5, 0, 0.5, 0)
		local sh = Instance.new("ImageLabel")
		sh.Name = (props.Name or "Icon") .. "Shadow"
		sh.Image = props.Image
		sh.BackgroundTransparency = 1
		sh.ImageColor3 = Style.Black
		sh.ImageTransparency = 0.6
		sh.ScaleType = Enum.ScaleType.Fit
		sh.Size = props.Size or UDim2.new(0, 48, 0, 48)
		sh.Position = UDim2.new(pos.X.Scale, pos.X.Offset + 2, pos.Y.Scale, pos.Y.Offset + 4)
		sh.AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5)
		sh.Rotation = props.Rotation or 0
		sh.ZIndex = (props.ZIndex or 5) - 1
		sh.Parent = props.Parent
	end
	local i = Instance.new("ImageLabel")
	i.Name = props.Name or "Icon"
	i.Image = props.Image
	i.BackgroundTransparency = 1
	i.ScaleType = Enum.ScaleType.Fit -- never stretched
	i.Size = props.Size or UDim2.new(0, 48, 0, 48)
	i.Position = props.Position or UDim2.new(0.5, 0, 0.5, 0)
	i.AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5)
	i.Rotation = props.Rotation or 0
	i.ZIndex = props.ZIndex or 5
	i.Parent = props.Parent
	return i
end

-- Faint checkerboard laid over a tile, fading from the top down.
function Style.checker(parent, zIndex, topTransparency, bottomTransparency)
	local c = Instance.new("ImageLabel")
	c.Name = "Checkerboard"
	c.Size = UDim2.new(1, 0, 1, 0)
	c.BackgroundTransparency = 1
	c.Image = Style.Checker
	c.ImageColor3 = Style.Black
	c.ScaleType = Enum.ScaleType.Tile
	c.TileSize = UDim2.new(0, 19, 0, 19)
	c.ZIndex = zIndex or 2
	c.Active = false
	c.Parent = parent

	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Transparency = NumberSequence.new(topTransparency or 0.93, bottomTransparency or 0.78)
	g.Parent = c
	return c
end

-- Inner highlight rim, darker bottom edge and (optionally) a sweeping shine.
function Style.finish(parent, zIndex, shine)
	local rim = Instance.new("Frame")
	rim.Name = "InnerHighlight"
	rim.Size = UDim2.new(1, -6, 1, -6)
	rim.Position = UDim2.new(0.5, 0, 0.5, 0)
	rim.AnchorPoint = Vector2.new(0.5, 0.5)
	rim.BackgroundTransparency = 1
	rim.ZIndex = zIndex
	rim.Active = false
	rim.Parent = parent
	Style.stroke(rim, 1.5, Style.White).Transparency = 0.55

	local bottom = Instance.new("Frame")
	bottom.Name = "Bevel"
	bottom.Size = UDim2.new(1, 0, 0, 5)
	bottom.Position = UDim2.new(0, 0, 1, -5)
	bottom.BackgroundColor3 = Style.Black
	bottom.BackgroundTransparency = 0.78
	bottom.BorderSizePixel = 0
	bottom.ZIndex = zIndex
	bottom.Parent = parent

	if shine then
		local sweep = Instance.new("Frame")
		sweep.Name = "Shine"
		sweep.Size = UDim2.new(0.22, 0, 2.4, 0)
		sweep.AnchorPoint = Vector2.new(0.5, 0.5)
		sweep.Position = UDim2.new(-0.5, 0, 0.5, 0)
		sweep.Rotation = 20
		sweep.BackgroundColor3 = Style.White
		sweep.BackgroundTransparency = 0
		sweep.BorderSizePixel = 0
		sweep.ZIndex = zIndex + 1
		sweep.Active = false
		sweep.Parent = parent
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.62),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = sweep
		local offset = math.random() * 4
		Style.onIdle(sweep, function(t)
			-- one 0.6s sweep every ~4s
			local phase = ((t + offset) % 4) / 0.6
			if phase < 1 then
				sweep.Position = UDim2.new(-0.2 + phase * 1.4, 0, 0.5, 0)
			else
				sweep.Position = UDim2.new(-0.5, 0, 0.5, 0)
			end
		end)
	end
end

----------------------------------------------------
-- Tile: gradient rectangle + black border + checker (non-interactive)
----------------------------------------------------
function Style.tile(props)
	local f = Instance.new("Frame")
	f.Name = props.Name or "Tile"
	f.Size = props.Size
	f.Position = props.Position or UDim2.new(0, 0, 0, 0)
	f.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	f.BackgroundColor3 = Style.White
	f.BorderSizePixel = 0
	f.ClipsDescendants = true
	f.ZIndex = props.ZIndex or 3
	if props.LayoutOrder then
		f.LayoutOrder = props.LayoutOrder
	end
	f.Parent = props.Parent

	local g = Instance.new("UIGradient")
	g.Name = "Fill"
	g.Color = toSequence(props.Gradient or Style.Gradients.Orange)
	g.Rotation = props.Rotation or 90
	g.Parent = f

	Style.stroke(f, props.BorderThickness or 3.5, Style.Black)
	if props.Checker ~= false then
		Style.checker(f, (props.ZIndex or 3) + 1)
	end
	Style.finish(f, (props.ZIndex or 3) + 1, false)
	return f
end

----------------------------------------------------
-- Button: same look as a tile, plus hover / click scale tweens
-- Returns the ImageButton; the label (if any) is button.Label.
----------------------------------------------------
local HOVER = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RELEASE = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

function Style.bindButton(btn, hover, press, hoverRotation)
	local scale = btn:FindFirstChild("ButtonScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "ButtonScale"
		scale.Parent = btn
	end
	hover = hover or 1.06
	press = press or 0.94
	hoverRotation = hoverRotation or 3
	btn.MouseEnter:Connect(function()
		Style.play("hover")
		TweenService:Create(scale, HOVER, { Scale = hover }):Play()
		TweenService:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Rotation = hoverRotation,
		}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(scale, HOVER, { Scale = 1 }):Play()
		TweenService:Create(btn, HOVER, { Rotation = 0 }):Play()
	end)
	btn.MouseButton1Down:Connect(function()
		Style.play("click")
		TweenService:Create(scale, PRESS, { Scale = press }):Play()
	end)
	btn.MouseButton1Up:Connect(function()
		TweenService:Create(scale, RELEASE, { Scale = hover }):Play()
	end)
end

function Style.button(props)
	local b = Instance.new("ImageButton")
	b.Name = props.Name or "Button"
	b.Size = props.Size
	b.Position = props.Position or UDim2.new(0, 0, 0, 0)
	b.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	b.BackgroundColor3 = Style.White
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.ClipsDescendants = true
	b.ZIndex = props.ZIndex or 5
	if props.LayoutOrder then
		b.LayoutOrder = props.LayoutOrder
	end
	b.Parent = props.Parent

	local g = Instance.new("UIGradient")
	g.Name = "Fill"
	g.Color = toSequence(props.Gradient or Style.Gradients.Green)
	g.Rotation = 90
	g.Parent = b

	Style.stroke(b, props.BorderThickness or 3, Style.Black)
	Style.checker(b, (props.ZIndex or 5) + 1)
	Style.finish(b, (props.ZIndex or 5) + 1, props.Shine ~= false)

	if props.Text then
		Style.label({
			Parent = b,
			Name = "Label",
			Text = props.Text,
			TextSize = props.TextSize or 26,
			ZIndex = (props.ZIndex or 5) + 3,
			Position = UDim2.new(0, 0, 0, -1),
		})
	end

	Style.bindButton(b, props.Hover, props.Press, props.HoverRotation)
	if props.OnClick then
		b.Activated:Connect(props.OnClick)
	end
	return b
end

-- Red "!" notification badge (circle) that can be shown/hidden.
function Style.badge(parent, position, size, text)
	size = size or 34
	local b = Instance.new("Frame")
	b.Name = "Badge"
	b.Size = UDim2.new(0, size, 0, size)
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = position
	b.BackgroundColor3 = Color3.fromRGB(235, 25, 40)
	b.BorderSizePixel = 0
	b.ZIndex = 30
	b.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = b
	Style.stroke(b, 2.5, Color3.fromRGB(255, 255, 255))
	local badgeText = Style.label({
		Parent = b,
		Name = "Text",
		Text = text or "!",
		TextSize = math.floor(size * 0.76),
		ZIndex = 31,
		StrokeThickness = 2,
	})
	local pulse = Instance.new("UIScale")
	pulse.Parent = b
	Style.onIdle(b, function(t)
		pulse.Scale = 1 + 0.12 * math.abs(math.sin(t * 4))
	end)
	return b
end

----------------------------------------------------
-- Window: dark bordered panel + overhanging header tab + red X close button.
-- Returns a table { Frame, Panel, Header, Open(), Close(), Toggle(), IsOpen() }.
----------------------------------------------------
function Style.deviceScale(camera)
	local v = camera.ViewportSize
	if v.X <= 0 or v.Y <= 0 then
		return 1
	end
	return math.clamp(math.min(v.X / 1050, v.Y / 620), 0.52, 1.18)
end

function Style.closeButton(parent, onClick, size, position)
	size = size or 60
	local b = Style.button({
		Name = "CloseButton",
		Parent = parent,
		Size = UDim2.new(0, size, 0, size),
		AnchorPoint = Vector2.new(1, 0),
		Position = position or UDim2.new(1, 18, 0, 6),
		Gradient = Style.Gradients.Red,
		Text = "X",
		TextSize = math.floor(size * 0.8),
		ZIndex = 40,
		BorderThickness = 3.5,
		HoverRotation = 90,
		Shine = false,
		OnClick = onClick,
	})
	return b
end

function Style.window(props)
	-- props: Name, Size (UDim2 offsets), Parent (ScreenGui), Title, TitleIcon, HeaderGradient,
	--        HeaderWidth, Camera, Position
	local frame = Instance.new("Frame")
	frame.Name = props.Name
	frame.Size = props.Size
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = props.Position or UDim2.new(0.5, 0, 0.5, 0)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.ZIndex = 10
	frame.Parent = props.Parent

	local scale = Instance.new("UIScale")
	scale.Name = "WindowScale"
	scale.Scale = Style.deviceScale(props.Camera)
	scale.Parent = frame

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(1, 0, 1, -34)
	panel.Position = UDim2.new(0, 0, 0, 34)
	panel.BackgroundColor3 = Style.PanelColor
	panel.BackgroundTransparency = props.PanelTransparency or 0.05
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.ZIndex = 11
	panel.Parent = frame
	Style.stroke(panel, 4, Style.Black)
	Style.checker(panel, 12, 0.95, 0.88)

	local header = Style.tile({
		Name = "Header",
		Parent = frame,
		Size = UDim2.new(0, props.HeaderWidth or 250, 0, props.HeaderHeight or 64),
		Position = UDim2.new(0, props.HeaderX or -20, 0, 0),
		Gradient = props.HeaderGradient or Style.Gradients.Orange,
		ZIndex = 30,
		BorderThickness = 4,
	})
	local titleX = 14
	if props.TitleIcon then
		Style.icon({
			Parent = header,
			Image = props.TitleIcon,
			Size = UDim2.new(0, 56, 0, 56),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			ZIndex = 34,
		})
		titleX = 72
	end
	Style.label({
		Parent = header,
		Name = "Title",
		Text = props.Title,
		TextSize = props.TitleSize or 42,
		XAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, titleX, 0, 0),
		Size = UDim2.new(1, -titleX - 8, 1, 0),
		ZIndex = 34,
		StrokeThickness = 4,
	})

	local window = { Frame = frame, Panel = panel, Header = header, Scale = scale }
	local open = false

	function window.IsOpen()
		return open
	end

	local goals = setmetatable({}, { __mode = "k" })
	local function intro()
		local index = 0
		for _, child in ipairs(panel:GetChildren()) do
			if child:IsA("GuiObject") and child.Name ~= "Checkerboard" then
				index += 1
				local goal = goals[child] or child.Position
				goals[child] = goal
				child.Position = UDim2.new(goal.X.Scale, goal.X.Offset, goal.Y.Scale, goal.Y.Offset + 26)
				task.delay(0.04 * index, function()
					TweenService:Create(child, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
						Position = goal,
					}):Play()
				end)
			end
		end
		local headerGoal = goals[header] or header.Position
		goals[header] = headerGoal
		header.Position = UDim2.new(headerGoal.X.Scale, headerGoal.X.Offset - 60, headerGoal.Y.Scale, headerGoal.Y.Offset)
		TweenService:Create(header, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = headerGoal,
		}):Play()
	end

	function window.Open()
		if open then
			return
		end
		open = true
		Style.play("open")
		local target = Style.deviceScale(props.Camera)
		scale.Scale = target * 0.7
		frame.Visible = true
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = target,
		}):Play()
		intro()
		if window.OnOpen then
			window.OnOpen()
		end
	end

	function window.Close()
		if not open then
			return
		end
		open = false
		Style.play("close")
		if window.OnClose then
			window.OnClose()
		end
		local t = TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Scale = scale.Scale * 0.7,
		})
		t.Completed:Connect(function()
			if not open then
				frame.Visible = false
			end
		end)
		t:Play()
	end

	function window.Toggle()
		if open then
			window.Close()
		else
			window.Open()
		end
	end

	Style.closeButton(frame, window.Close, props.CloseSize, props.ClosePosition)

	if props.Camera then
		props.Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if open then
				scale.Scale = Style.deviceScale(props.Camera)
			end
		end)
	end

	return window
end

return Style
]==])

add('GameUI', 'ModuleScript', [==[
--!nonstrict
-- GameUI.luau
-- Builds the full menu set, laid out to match the reference game:
--   HUD: main button grid, currency counters, right-side quick buys, rewards, level/damage bar
--   Windows: Rebirth, Pets, Items, Worlds, Shop
-- Every piece of game logic is a callback / setter, so you can wire it to your own remotes:
--
--   local GameUI = require(path.to.GameUI)
--   local ui = GameUI.new(playerGui, { OnRebirth = function() ... end, ... })
--   ui.SetTrophies(100); ui.SetRebirths(0); ui.SetPets({...}); ui.SetRebirthData({...}) ...
--
-- Callbacks: OnRebirth, OnSkipRebirth, OnEquipBest, OnUnequipAll, OnDeletePets, OnTogglePet(id, equipped),
--   OnPurchase(product), OnItems, OnWorlds, OnTeleport(worldId), OnUnlockSlot(index), OnToggleItem(id),
--   OnRewards, OnInviteFriends, OnStatBoost(index)

local Style = require(script.Parent.Style)
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local GameUI = {}

local ORANGE_TEXT = Color3.fromRGB(255, 176, 0)
local GREEN_TEXT = Color3.fromRGB(70, 235, 70)
local YELLOW_TEXT = Color3.fromRGB(255, 222, 40)
local SUNBURST = "rbxassetid://130563114903838"

----------------------------------------------------
-- helpers
----------------------------------------------------
local function formatNumber(n)
	n = tonumber(n) or 0
	local suffixes = { "", "K", "M", "B", "T", "Qa" }
	local i = 1
	local v = math.abs(n)
	while v >= 1000 and i < #suffixes do
		v /= 1000
		i += 1
	end
	if i == 1 then
		return tostring(math.floor(n))
	end
	local s = string.format("%.2f", v):gsub("%.?0+$", "")
	return (n < 0 and "-" or "") .. s .. suffixes[i]
end
GameUI.formatNumber = formatNumber

-- Smoothly counts a label's number up/down to a new value.
local function countTo(label, target)
	local from = label:GetAttribute("Value") or 0
	label:SetAttribute("Value", target)
	local token = (label:GetAttribute("Token") or 0) + 1
	label:SetAttribute("Token", token)
	task.spawn(function()
		local start = os.clock()
		while label:GetAttribute("Token") == token do
			local a = math.min((os.clock() - start) / 0.5, 1)
			label.Text = formatNumber(from + (target - from) * a)
			if a >= 1 then
				break
			end
			task.wait()
		end
	end)
end

local function rarityGradient(rarity)
	local map = {
		Common = Style.Gradients.Cyan,
		Rare = Style.Gradients.Blue,
		Epic = Style.Gradients.Purple,
		Legendary = Style.Gradients.Orange,
		Mythic = Style.Rainbow,
	}
	return map[rarity] or Style.Gradients.Cyan
end

local function newFrame(props)
	local f = Instance.new("Frame")
	f.Name = props.Name or "Frame"
	f.Size = props.Size
	f.Position = props.Position or UDim2.new(0, 0, 0, 0)
	f.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	f.BackgroundTransparency = 1
	f.ZIndex = props.ZIndex or 5
	f.Parent = props.Parent
	return f
end

-- Robux icon + price number inside a (usually green) button.
local function addPrice(btn, price, textSize, zIndex, yOffset)
	textSize = textSize or 26
	local row = newFrame({
		Parent = btn,
		Name = "PriceRow",
		Size = UDim2.new(1, 0, 0, textSize + 6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, yOffset or 0),
		ZIndex = zIndex,
	})
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 4)
	list.Parent = row
	local icon = Style.icon({
		Parent = row, Image = Style.Icons.Robux, NoShadow = true,
		Size = UDim2.new(0, textSize, 0, textSize), ZIndex = zIndex,
	})
	icon.AnchorPoint = Vector2.new(0, 0)
	icon.Position = UDim2.new(0, 0, 0, 0)
	icon.LayoutOrder = 1
	local label = Style.label({
		Parent = row, Text = tostring(price), TextSize = textSize, ZIndex = zIndex,
		Size = UDim2.new(0, 0, 1, 0),
	})
	label.AutomaticSize = Enum.AutomaticSize.X
	label.LayoutOrder = 2
	return label
end

-- A green buy button ("⊚ 499").
local function buyButton(props)
	local btn = Style.button({
		Name = props.Name or "Buy", Parent = props.Parent, Size = props.Size,
		Position = props.Position, AnchorPoint = props.AnchorPoint,
		Gradient = props.Gradient or Style.Gradients.Lime, ZIndex = props.ZIndex or 20,
		BorderThickness = 3,
		OnClick = props.OnClick,
	})
	addPrice(btn, props.Price, props.TextSize or 26, (props.ZIndex or 20) + 4, props.PriceOffset)
	return btn
end

----------------------------------------------------
-- GameUI.new
----------------------------------------------------
function GameUI.new(playerGui, callbacks)
	callbacks = callbacks or {}
	local camera = workspace.CurrentCamera

	local gui = Instance.new("ScreenGui")
	gui.Name = "GameUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local ui = { Gui = gui, Windows = {} }

	-- Background blur while any window is open
	local blur = Lighting:FindFirstChild("MenuBlur") or Instance.new("BlurEffect")
	blur.Name = "MenuBlur"
	blur.Size = 0
	blur.Parent = Lighting
	local function refreshBlur()
		local anyOpen = false
		for _, window in pairs(ui.Windows) do
			if window.IsOpen() then
				anyOpen = true
			end
		end
		TweenService:Create(blur, TweenInfo.new(0.25), { Size = anyOpen and 14 or 0 }):Play()
	end

	local function register(name, window)
		ui.Windows[name] = window
		window.OnOpen = refreshBlur
		window.OnClose = refreshBlur
		local open = window.Open
		window.Open = function()
			for otherName, other in pairs(ui.Windows) do
				if otherName ~= name then
					other.Close()
				end
			end
			open()
		end
		window.Toggle = function()
			if window.IsOpen() then
				window.Close()
			else
				window.Open()
			end
		end
		return window
	end

	local function scaledHud(props)
		local f = newFrame(props)
		local sc = Instance.new("UIScale")
		sc.Scale = Style.deviceScale(camera)
		sc.Parent = f
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			sc.Scale = Style.deviceScale(camera)
		end)
		return f
	end

	------------------------------------------------
	-- 1. Main button grid (Store / Pets / Rebirth / Items / Worlds)
	------------------------------------------------
	local hud = scaledHud({
		Parent = gui, Name = "MainButtons", Size = UDim2.new(0, 166, 0, 262),
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.47, 0),
	})

	local function menuTile(props)
		local wrapper = newFrame({
			Parent = hud, Name = props.Name .. "Slot", Size = props.Size, Position = props.Position, ZIndex = 5,
		})
		local btn = Style.button({
			Name = props.Name, Parent = wrapper, Size = UDim2.new(1, 0, 1, 0),
			Gradient = props.Gradient, ZIndex = 6, BorderThickness = 3, OnClick = props.OnClick,
		})
		return wrapper, btn
	end

	local function gridTile(name, text, icon, gradient, x, y, onClick)
		local wrapper, btn = menuTile({
			Name = name, Size = UDim2.new(0, 80, 0, 80), Position = UDim2.new(0, x, 0, y),
			Gradient = gradient, OnClick = onClick,
		})
		Style.icon({
			Parent = btn, Image = icon, Size = UDim2.new(0, 54, 0, 54),
			Position = UDim2.new(0.5, 0, 0.38, 0), ZIndex = 9,
		})
		Style.label({
			Parent = btn, Name = "Label", Text = text, TextSize = 19,
			Position = UDim2.new(0, 0, 1, -24), Size = UDim2.new(1, 0, 0, 22), ZIndex = 10,
		})
		return wrapper, btn
	end

	local storeWrapper, storeBtn = menuTile({
		Name = "Store", Size = UDim2.new(0, 166, 0, 50), Position = UDim2.new(0, 0, 0, 36),
		Gradient = Style.Gradients.Orange,
		OnClick = function()
			ui.Windows.Shop.Toggle()
		end,
	})
	Style.label({
		Parent = storeBtn, Name = "Label", Text = "Store", TextSize = 30, StrokeThickness = 3.4,
		Position = UDim2.new(0, 0, 0, 8), ZIndex = 10,
	})
	local cartIcon = Style.icon({
		Parent = storeWrapper, Image = Style.Icons.Cart, Size = UDim2.new(0, 62, 0, 62),
		Position = UDim2.new(0.5, 0, 0, -4), ZIndex = 12, NoShadow = true,
	})
	Style.onIdle(cartIcon, function(t)
		cartIcon.Position = UDim2.new(0.5, 0, 0, -4 + math.sin(t * 2.5) * 3)
		cartIcon.Rotation = math.sin(t * 1.8) * 5
	end)
	ui.StoreBadge = Style.badge(storeWrapper, UDim2.new(1, -8, 0, 8), 24)

	gridTile("Pets", "Pets", Style.Icons.Pet, Style.Gradients.Green, 0, 92, function()
		ui.Windows.Pets.Toggle()
	end)
	local rebirthWrapper = gridTile("RebirthOpen", "Rebirth", Style.Icons.Rebirth, Style.Gradients.Blue, 86, 92,
		function()
			ui.Windows.Rebirth.Toggle()
		end)
	ui.RebirthBadge = Style.badge(rebirthWrapper, UDim2.new(1, -2, 0, 2), 24)
	local rebirthPercent = Style.label({
		Parent = rebirthWrapper, Name = "Percent", Text = "0%", TextSize = 19,
		XAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 12, 0.46, 0), Size = UDim2.new(0, 80, 0, 24), ZIndex = 14,
	})
	rebirthPercent.Rotation = -6

	gridTile("Items", "Items", Style.Icons.Backpack, Style.Gradients.Orange, 0, 178, function()
		ui.Windows.Items.Toggle()
		if callbacks.OnItems then
			callbacks.OnItems()
		end
	end)
	gridTile("Worlds", "Worlds", Style.Icons.World, Style.Gradients.Purple, 86, 178, function()
		ui.Windows.Worlds.Toggle()
		if callbacks.OnWorlds then
			callbacks.OnWorlds()
		end
	end)

	------------------------------------------------
	-- 2. Currency counters (trophies / rebirths / friend boost)
	------------------------------------------------
	local stats = scaledHud({
		Parent = gui, Name = "Currencies", Size = UDim2.new(0, 210, 0, 120),
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -12),
	})
	local function statRow(y, icon)
		Style.icon({
			Parent = stats, Image = icon, Size = UDim2.new(0, 46, 0, 46),
			AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 0, 0, y), ZIndex = 6,
		})
		return Style.label({
			Parent = stats, Text = "0", TextSize = 34, Color = ORANGE_TEXT,
			XAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 54, 0, y),
			Size = UDim2.new(1, -54, 0, 46), StrokeThickness = 3.4, ZIndex = 6,
		})
	end
	local trophyLabel = statRow(0, Style.Icons.Trophy)
	local rebirthLabel = statRow(48, Style.Icons.Rebirth)
	local boostLabel = Style.label({
		Parent = stats, Text = "Friend Boost +0%", TextSize = 17, XAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 0, 0, 98), Size = UDim2.new(0, 170, 0, 22), ZIndex = 6,
	})
	local plus = Style.button({
		Name = "FriendBoostAdd", Parent = stats, Size = UDim2.new(0, 22, 0, 22),
		Position = UDim2.new(0, 172, 0, 98), Gradient = Style.Gradients.Lime, ZIndex = 6,
		BorderThickness = 2.5, Shine = false,
		OnClick = function()
			if callbacks.OnInviteFriends then
				callbacks.OnInviteFriends()
			end
		end,
	})
	Style.icon({ Parent = plus, Image = Style.Icons.Plus, NoShadow = true, Size = UDim2.new(0, 14, 0, 14), ZIndex = 9 })

	function ui.SetTrophies(n)
		countTo(trophyLabel, n)
	end
	function ui.SetRebirths(n)
		countTo(rebirthLabel, n)
	end
	function ui.SetFriendBoost(percent)
		boostLabel.Text = string.format("Friend Boost +%d%%", percent)
	end
	function ui.SetRebirthProgress(percent)
		rebirthPercent.Text = string.format("%d%%", math.clamp(math.floor(percent), 0, 100))
		ui.RebirthBadge.Visible = percent >= 100
	end
	function ui.SetStoreBadge(visible)
		ui.StoreBadge.Visible = visible
	end

	------------------------------------------------
	-- 3. Right-side quick buys + rewards
	------------------------------------------------
	local quick = scaledHud({
		Parent = gui, Name = "QuickBuys", Size = UDim2.new(0, 170, 0, 230),
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 6),
	})
	local quickCount = 0

	-- product = { Name, Price, Gradient, SubText ("PERMANENT!"), ProductId }
	function ui.AddQuickBuy(product)
		local y = quickCount * 74
		quickCount += 1
		local btn = Style.button({
			Name = "Quick_" .. tostring(product.ProductId or quickCount), Parent = quick,
			Size = UDim2.new(0, 168, 0, 50), Position = UDim2.new(0, 1, 0, y),
			Gradient = product.Gradient or Style.Gradients.Orange, Text = product.Name, TextSize = 24,
			ZIndex = 6, BorderThickness = 3,
			OnClick = function()
				if callbacks.OnPurchase then
					callbacks.OnPurchase(product)
				end
			end,
		})
		if product.Icon then
			Style.icon({
				Parent = btn, Image = product.Icon, Size = UDim2.new(0, 44, 0, 44),
				Position = UDim2.new(0.5, 0, 0.5, 2), ZIndex = 8,
			})
		end
		local row = newFrame({
			Parent = quick, Name = "PriceTag", Size = UDim2.new(0, 168, 0, 18),
			Position = UDim2.new(0, 1, 0, y + 52), ZIndex = 6,
		})
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.Padding = UDim.new(0, 3)
		list.Parent = row
		local only = Style.label({ Parent = row, Text = "ONLY", TextSize = 16, Color = GREEN_TEXT, Size = UDim2.new(0, 0, 1, 0), ZIndex = 6 })
		only.AutomaticSize = Enum.AutomaticSize.X
		only.LayoutOrder = 1
		local rb = Style.icon({ Parent = row, Image = Style.Icons.Robux, NoShadow = true, Size = UDim2.new(0, 16, 0, 16), ZIndex = 6 })
		rb.AnchorPoint = Vector2.new(0, 0)
		rb.Position = UDim2.new(0, 0, 0, 0)
		rb.ImageColor3 = GREEN_TEXT
		rb.LayoutOrder = 2
		local price = Style.label({ Parent = row, Text = tostring(product.Price), TextSize = 16, Color = GREEN_TEXT, Size = UDim2.new(0, 0, 1, 0), ZIndex = 6 })
		price.AutomaticSize = Enum.AutomaticSize.X
		price.LayoutOrder = 3
		if product.SubText then
			Style.label({
				Parent = quick, Text = product.SubText, TextSize = 15, Color = YELLOW_TEXT,
				Position = UDim2.new(0, 0, 0, y + 70), Size = UDim2.new(0, 170, 0, 16), ZIndex = 6,
			})
		end
		return btn
	end

	local rewards = scaledHud({
		Parent = gui, Name = "Rewards", Size = UDim2.new(0, 120, 0, 110),
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -150, 0, 44),
	})
	local rewardsBtn = Instance.new("ImageButton")
	rewardsBtn.Name = "RewardsButton"
	rewardsBtn.Size = UDim2.new(0, 120, 0, 110)
	rewardsBtn.BackgroundTransparency = 1
	rewardsBtn.AutoButtonColor = false
	rewardsBtn.ZIndex = 6
	rewardsBtn.Parent = rewards
	Style.bindButton(rewardsBtn, 1.08, 0.94, 0)
	rewardsBtn.Activated:Connect(function()
		if callbacks.OnRewards then
			callbacks.OnRewards()
		end
	end)
	local gift = Style.icon({
		Parent = rewardsBtn, Image = "rbxassetid://96888229999409", Size = UDim2.new(0, 66, 0, 66),
		Position = UDim2.new(0.5, 0, 0, 34), ZIndex = 8, NoShadow = true,
	})
	Style.onIdle(gift, function(t)
		gift.Rotation = math.sin(t * 3) * 6
	end)
	local rewardsBadge = Style.badge(rewardsBtn, UDim2.new(0.5, 36, 0, 8), 28, "0")
	Style.label({
		Parent = rewardsBtn, Name = "Caption", Text = "REWARDS\nREADY!", TextSize = 17,
		Position = UDim2.new(0, 0, 0, 68), Size = UDim2.new(1, 0, 0, 40), ZIndex = 8, Wrapped = true,
	})
	function ui.SetRewards(count)
		rewards.Visible = count > 0
		rewardsBadge.Text.Text = tostring(count)
		rewardsBtn.Caption.Text = string.format("%d REWARD%s\nREADY!", count, count == 1 and "" or "S")
	end

	------------------------------------------------
	-- 4. Bottom bar: damage, level, stat boosts
	------------------------------------------------
	local bottom = scaledHud({
		Parent = gui, Name = "BottomBar", Size = UDim2.new(0, 400, 0, 110),
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8),
	})
	local multiplierLabel = Style.label({
		Parent = bottom, Text = "Multiplier: 1x", TextSize = 13, Color = YELLOW_TEXT,
		Size = UDim2.new(1, 0, 0, 16), ZIndex = 6,
	})
	local damageLabel = Style.label({
		Parent = bottom, Text = "0 DAMAGE", TextSize = 22, Color = ORANGE_TEXT,
		Position = UDim2.new(0, 0, 0, 14), Size = UDim2.new(1, 0, 0, 26), ZIndex = 6,
	})
	local speedLabel = Style.label({
		Parent = bottom, Text = "Speed: 16", TextSize = 13, Color = Color3.fromRGB(90, 190, 255),
		XAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 0, 0, 20),
		Size = UDim2.new(0, 100, 0, 16), ZIndex = 6,
	})
	speedLabel.Position = UDim2.new(0, -40, 0, 12)

	local trough = Instance.new("Frame")
	trough.Name = "LevelBar"
	trough.Size = UDim2.new(1, 0, 0, 30)
	trough.Position = UDim2.new(0, 0, 0, 42)
	trough.BackgroundColor3 = Color3.fromRGB(22, 28, 36)
	trough.BorderSizePixel = 0
	trough.ClipsDescendants = true
	trough.ZIndex = 5
	trough.Parent = bottom
	Style.stroke(trough, 3, Style.Black)
	local levelFill = Instance.new("Frame")
	levelFill.Name = "Fill"
	levelFill.Size = UDim2.new(1, 0, 1, 0)
	levelFill.BackgroundColor3 = Style.White
	levelFill.BorderSizePixel = 0
	levelFill.ZIndex = 6
	levelFill.Parent = trough
	local fillGrad = Instance.new("UIGradient")
	fillGrad.Rotation = 90
	fillGrad.Color = ColorSequence.new(Color3.fromRGB(255, 190, 0), Color3.fromRGB(255, 110, 0))
	fillGrad.Parent = levelFill
	Style.checker(levelFill, 7)
	local levelText = Style.label({
		Parent = trough, Text = "LEVEL 1", TextSize = 20, XAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(0.6, 0, 1, 0), ZIndex = 8,
	})
	local maxText = Style.label({
		Parent = trough, Text = "", TextSize = 20, XAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(0.4, -8, 0, 0), Size = UDim2.new(0.6, 0, 1, 0), ZIndex = 8,
	})

	local boostButtons = {}
	local boostGradients = { Style.Gradients.Orange, Style.Gradients.Blue, Style.Gradients.Purple }
	for i = 1, 3 do
		boostButtons[i] = Style.button({
			Name = "StatBoost" .. i, Parent = bottom, Size = UDim2.new(0, 124, 0, 32),
			Position = UDim2.new(0, 2 + (i - 1) * 134, 0, 78), Gradient = boostGradients[i],
			Text = "+0", TextSize = 20, ZIndex = 6, BorderThickness = 2.5,
			OnClick = function()
				if callbacks.OnStatBoost then
					callbacks.OnStatBoost(i)
				end
			end,
		})
	end

	function ui.SetDamage(text)
		damageLabel.Text = tostring(text) .. " DAMAGE"
	end
	function ui.SetMultiplier(text)
		multiplierLabel.Text = "Multiplier: " .. tostring(text)
	end
	function ui.SetSpeed(n)
		speedLabel.Text = "Speed: " .. tostring(n)
	end
	-- progress 0..1; maxed shows "MAX"
	function ui.SetLevel(level, progress, maxed)
		levelText.Text = "LEVEL " .. tostring(level)
		maxText.Text = maxed and "MAX" or ""
		TweenService:Create(levelFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
			Size = UDim2.new(math.clamp(progress or 1, 0, 1), 0, 1, 0),
		}):Play()
	end
	function ui.SetStatBoosts(texts)
		for i, text in ipairs(texts) do
			if boostButtons[i] then
				boostButtons[i].Label.Text = tostring(text)
			end
		end
	end

	------------------------------------------------
	-- window helper
	------------------------------------------------
	local function makeWindow(name, props)
		props.Name = name .. "Window"
		props.Parent = gui
		props.Camera = camera
		return register(name, Style.window(props))
	end

	------------------------------------------------
	-- 5. Rebirth window
	------------------------------------------------
	do
		local w = makeWindow("Rebirth", {
			Size = UDim2.new(0, 582, 0, 407 + 34),
			Title = "REBIRTH", TitleIcon = Style.Icons.Rebirth, HeaderWidth = 325,
			HeaderGradient = Style.Gradients.BluePurple,
			PanelTransparency = 0.02,
		})
		local p = w.Panel

		local leftTitle = Style.label({
			Parent = p, Text = "Rebirth 0:", TextSize = 30,
			Position = UDim2.new(0, 19, 0, 36), Size = UDim2.new(0, 226, 0, 36), ZIndex = 15,
		})
		local rightTitle = Style.label({
			Parent = p, Text = "Rebirth 1:", TextSize = 30,
			Position = UDim2.new(0, 337, 0, 36), Size = UDim2.new(0, 226, 0, 36), ZIndex = 15,
		})

		local function statCard(x, y, icon, text)
			local t = Style.tile({
				Parent = p, Size = UDim2.new(0, 226, 0, 78), Position = UDim2.new(0, x, 0, y),
				Gradient = Style.Gradients.Orange, ZIndex = 14, BorderThickness = 3,
			})
			Style.icon({
				Parent = t, Image = icon, Size = UDim2.new(0, 72, 0, 72),
				Position = UDim2.new(0.66, 0, 0.5, 2), ZIndex = 16,
			})
			return Style.label({ Parent = t, Text = text, TextSize = 32, ZIndex = 18, StrokeThickness = 3.4 })
		end

		local dmgNow = statCard(19, 80, Style.Icons.Sword, "X1 Damage")
		local dmgNext = statCard(337, 80, Style.Icons.Sword, "X2 Damage")
		local lvlNow = statCard(19, 168, Style.Icons.Star, "MAX Level 10")
		local lvlNext = statCard(337, 168, Style.Icons.Star, "MAX Level 20")

		for _, y in ipairs({ 80, 168 }) do
			local arrow = Style.label({
				Parent = p, Text = "»", TextSize = 78,
				Color = Color3.fromRGB(190, 235, 255),
				StrokeColor = Color3.fromRGB(40, 100, 170), StrokeThickness = 4,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0, y + 36),
				Size = UDim2.new(0, 80, 0, 80), ZIndex = 15,
			})
			Style.onIdle(arrow, function(t)
				arrow.Position = UDim2.new(0.5, math.sin(t * 4) * 4, 0, y + 36)
			end)
		end

		local levelBar = Style.tile({
			Parent = p, Size = UDim2.new(0, 551, 0, 54), Position = UDim2.new(0, 16, 0, 256),
			Gradient = Style.Gradients.Orange, ZIndex = 14, BorderThickness = 3,
		})
		Style.icon({
			Parent = levelBar, Image = Style.Icons.Star, Size = UDim2.new(0, 42, 0, 42),
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 122, 0.5, 0), ZIndex = 16,
		})
		local levelText = Style.label({
			Parent = levelBar, Text = "Level 10 / Level 10", TextSize = 32,
			XAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 172, 0, 0), Size = UDim2.new(1, -176, 1, 0), ZIndex = 18,
		})

		local skipBtn = Style.button({
			Name = "SkipRebirth", Parent = p,
			Size = UDim2.new(0, 268, 0, 78), Position = UDim2.new(0, 19, 0, 321),
			Gradient = Style.Gradients.Red, Text = "SKIP REBIRTH", TextSize = 34,
			ZIndex = 14, BorderThickness = 3,
			OnClick = function()
				if callbacks.OnSkipRebirth then
					callbacks.OnSkipRebirth()
				end
			end,
		})
		skipBtn.Label.Position = UDim2.new(0, 0, 0, -6)
		Style.label({
			Parent = skipBtn, Name = "KeepStats", Text = "KEEP ALL STATS!", TextSize = 14,
			Color = YELLOW_TEXT, XAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -3),
			Size = UDim2.new(0, 160, 0, 16), ZIndex = 22,
		})
		skipBtn.Fill.Color = Style.Rainbow
		Style.onIdle(skipBtn, function(t)
			skipBtn.Fill.Rotation = 25 + math.sin(t * 1.5) * 25
		end)

		local rebirthAction = Style.button({
			Name = "DoRebirth", Parent = p,
			Size = UDim2.new(0, 268, 0, 78), Position = UDim2.new(0, 296, 0, 321),
			Gradient = Style.Gradients.Lime, Text = "REBIRTH", TextSize = 50,
			ZIndex = 14, BorderThickness = 3,
			OnClick = function()
				if w.CanRebirth then
					Style.play("success")
					if callbacks.OnRebirth then
						callbacks.OnRebirth()
					end
				else
					Style.play("error")
				end
			end,
		})
		w.CanRebirth = true

		Style.label({
			Parent = w.Frame, Text = "Rebirth resets your Damage, Level, Wins ONLY!", TextSize = 19,
			Color = Color3.fromRGB(255, 40, 40),
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 6),
			Size = UDim2.new(1, 0, 0, 26), ZIndex = 40,
		})

		-- data = { Current, DamageNow, DamageNext, MaxLevelNow, MaxLevelNext, Level, LevelRequired }
		function ui.SetRebirthData(data)
			leftTitle.Text = string.format("Rebirth %d:", data.Current or 0)
			rightTitle.Text = string.format("Rebirth %d:", (data.Current or 0) + 1)
			dmgNow.Text = string.format("X%s Damage", tostring(data.DamageNow or 1))
			dmgNext.Text = string.format("X%s Damage", tostring(data.DamageNext or 2))
			lvlNow.Text = string.format("MAX Level %d", data.MaxLevelNow or 10)
			lvlNext.Text = string.format("MAX Level %d", data.MaxLevelNext or 20)
			local level, required = data.Level or 0, data.LevelRequired or 10
			levelText.Text = string.format("Level %d / Level %d", level, required)
			w.CanRebirth = level >= required
			local g = w.CanRebirth and Style.Gradients.Lime or { Color3.fromRGB(150, 155, 160), Color3.fromRGB(95, 100, 105) }
			rebirthAction.Fill.Color = ColorSequence.new(g[1], g[2])
			ui.SetRebirths(data.Current or 0)
			ui.SetRebirthProgress(math.clamp(level / math.max(required, 1), 0, 1) * 100)
		end
	end

	------------------------------------------------
	-- shared: Equip Best / Unequip All / Delete side buttons
	------------------------------------------------
	local SIDE = 165 -- width reserved left of the panel for the side buttons
	local function sideButtons(w)
		local function sideButton(text, y, gradient, cb)
			return Style.button({
				Name = text, Parent = w.Frame,
				Size = UDim2.new(0, 156, 0, 46), Position = UDim2.new(0, 0, 0, y),
				Gradient = gradient, Text = text, TextSize = 26, ZIndex = 20, BorderThickness = 3,
				OnClick = function()
					if cb then
						cb()
					end
				end,
			})
		end
		sideButton("Equip Best", 74, Style.Gradients.Lime, callbacks.OnEquipBest)
		sideButton("Unequip All", 126, Style.Gradients.Red, callbacks.OnUnequipAll)
		sideButton("Delete", 178, Style.Gradients.Red, callbacks.OnDeletePets)
	end

	------------------------------------------------
	-- 6. Pets window
	------------------------------------------------
	do
		local w = makeWindow("Pets", {
			Size = UDim2.new(0, SIDE + 572, 0, 34 + 400 + 48),
			Title = "PETS", TitleIcon = Style.Icons.Pet, HeaderWidth = 320, HeaderX = SIDE - 18,
			HeaderGradient = Style.Gradients.Green, PanelTransparency = 0.14,
			ClosePosition = UDim2.new(1, 18, 0, 12),
		})
		local panel = w.Panel
		panel.Position = UDim2.new(0, SIDE, 0, 34)
		panel.Size = UDim2.new(1, -SIDE, 1, -34 - 48)
		sideButtons(w)

		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "PetGrid"
		scroll.Size = UDim2.new(1, -20, 1, -50)
		scroll.Position = UDim2.new(0, 10, 0, 42)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 8
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.ZIndex = 13
		scroll.Parent = panel
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.new(0, 100, 0, 100)
		grid.CellPadding = UDim2.new(0, 8, 0, 8)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = scroll

		-- footer: backpack capacity + equipped pets
		local footer = Style.tile({
			Name = "Footer", Parent = w.Frame,
			Size = UDim2.new(0, 224, 0, 42), Position = UDim2.new(0, SIDE, 1, -44),
			Gradient = Style.Gradients.DarkGrey, ZIndex = 20, BorderThickness = 3,
		})
		Style.icon({ Parent = footer, Image = Style.Icons.Backpack, Size = UDim2.new(0, 34, 0, 34),
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), ZIndex = 24 })
		local capacityLabel = Style.label({ Parent = footer, Text = "0/100", TextSize = 26,
			XAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 44, 0, 0),
			Size = UDim2.new(0, 80, 1, 0), ZIndex = 24 })
		Style.icon({ Parent = footer, Image = Style.Icons.Pet, Size = UDim2.new(0, 34, 0, 34),
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 126, 0.5, 0), ZIndex = 24 })
		local equippedLabel = Style.label({ Parent = footer, Text = "0/4", TextSize = 26,
			XAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 164, 0, 0),
			Size = UDim2.new(0, 56, 1, 0), ZIndex = 24 })

		local capacity, maxEquipped = 100, 4
		local cells = {}

		local function refreshCounts()
			local equipped, total = 0, 0
			for _, cell in pairs(cells) do
				total += 1
				if cell.Equipped then
					equipped += 1
				end
			end
			capacityLabel.Text = string.format("%d/%d", total, capacity)
			equippedLabel.Text = string.format("%d/%d", equipped, maxEquipped)
		end

		function ui.SetPetLimits(newCapacity, newMaxEquipped)
			capacity, maxEquipped = newCapacity or capacity, newMaxEquipped or maxEquipped
			refreshCounts()
		end

		-- pets = { { Id, Name, Icon, Rarity, Equipped } }
		function ui.SetPets(pets)
			for _, cell in pairs(cells) do
				cell.Button:Destroy()
			end
			cells = {}
			for i, pet in ipairs(pets) do
				local btn = Style.button({
					Name = "Pet_" .. tostring(pet.Id), Parent = scroll,
					Size = UDim2.new(0, 100, 0, 100), Gradient = rarityGradient(pet.Rarity),
					ZIndex = 14, LayoutOrder = i, BorderThickness = 3,
				})
				Style.icon({ Parent = btn, Image = pet.Icon or Style.Icons.Pet,
					Size = UDim2.new(0, 66, 0, 66), Position = UDim2.new(0.5, 0, 0.44, 0), ZIndex = 18 })
				Style.label({ Parent = btn, Text = pet.Name or "Pet", TextSize = 14,
					Position = UDim2.new(0, 0, 1, -22), Size = UDim2.new(1, 0, 0, 20), ZIndex = 19 })
				local tag = Style.label({ Name = "EquippedTag", Parent = btn, Text = "E", TextSize = 18,
					Color = Color3.fromRGB(190, 255, 30), Position = UDim2.new(0, 6, 0, 4),
					Size = UDim2.new(0, 20, 0, 20), ZIndex = 20 })
				local cell = { Button = btn, Tag = tag, Equipped = pet.Equipped == true, Id = pet.Id }
				cells[pet.Id] = cell
				tag.Visible = cell.Equipped
				btn.Activated:Connect(function()
					local want = not cell.Equipped
					if want then
						local equipped = 0
						for _, c in pairs(cells) do
							if c.Equipped then
								equipped += 1
							end
						end
						if equipped >= maxEquipped then
							Style.play("error")
							return
						end
					end
					cell.Equipped = want
					tag.Visible = want
					refreshCounts()
					if callbacks.OnTogglePet then
						callbacks.OnTogglePet(pet.Id, want)
					end
				end)
			end
			refreshCounts()
		end

		function ui.SetPetEquipped(id, equipped)
			local cell = cells[id]
			if cell then
				cell.Equipped = equipped
				cell.Tag.Visible = equipped
				refreshCounts()
			end
		end
	end

	------------------------------------------------
	-- 7. Items window
	------------------------------------------------
	do
		local w = makeWindow("Items", {
			Size = UDim2.new(0, SIDE + 572, 0, 34 + 403),
			Title = "ITEMS", TitleIcon = Style.Icons.Backpack, HeaderWidth = 320, HeaderX = SIDE - 18,
			HeaderGradient = Style.Gradients.Yellow, PanelTransparency = 0.02,
			ClosePosition = UDim2.new(1, 18, 0, 12),
		})
		local panel = w.Panel
		panel.Position = UDim2.new(0, SIDE, 0, 34)
		panel.Size = UDim2.new(1, -SIDE, 1, -34)
		sideButtons(w)

		-- left: equipped slots on a ring + additional slots
		local left = Instance.new("Frame")
		left.Name = "Loadout"
		left.Size = UDim2.new(0, 262, 1, -36)
		left.Position = UDim2.new(0, 0, 0, 36)
		left.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
		left.BorderSizePixel = 0
		left.ZIndex = 13
		left.Parent = panel
		Style.stroke(left, 3, Style.Black)

		local ring = Instance.new("Frame")
		ring.Name = "Ring"
		ring.Size = UDim2.new(0, 190, 0, 190)
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.new(0, 130, 0, 128)
		ring.BackgroundTransparency = 1
		ring.ZIndex = 14
		ring.Parent = left
		local ringCorner = Instance.new("UICorner")
		ringCorner.CornerRadius = UDim.new(1, 0)
		ringCorner.Parent = ring
		Style.stroke(ring, 3, Style.White).Transparency = 0.15

		local slotPositions = {
			UDim2.new(0, 130, 0, 54), UDim2.new(0, 59, 0, 162), UDim2.new(0, 202, 0, 162),
		}
		local slotFrames = {}

		local function renderSlot(index, data)
			local frame = slotFrames[index]
			for _, child in ipairs(frame:GetChildren()) do
				child:Destroy()
			end
			local gradient = Style.Gradients.Grey
			if data == nil or data == false then
				gradient = { Color3.fromRGB(250, 250, 255), Color3.fromRGB(222, 226, 236) }
			elseif data.Locked then
				gradient = Style.Gradients.DarkGrey
			else
				gradient = data.Gradient or Style.Gradients.Blue
			end
			local btn = Style.button({
				Name = "Slot", Parent = frame, Size = UDim2.new(1, 0, 1, 0), Gradient = gradient,
				ZIndex = 16, BorderThickness = 2.5, Shine = false,
				OnClick = function()
					if callbacks.OnToggleSlot then
						callbacks.OnToggleSlot(index)
					end
				end,
			})
			btn:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(255, 170, 0)
			if data == nil or data == false then
				Style.label({ Parent = btn, Text = "Empty", TextSize = 18, ZIndex = 20, Position = UDim2.new(0, 0, 0.55, 0) })
			elseif data.Locked then
				Style.label({ Parent = btn, Text = "LOCKED", TextSize = 16, Color = Color3.fromRGB(255, 60, 60),
					Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0, 8), ZIndex = 20 })
				Style.label({ Parent = btn, Text = data.Requirement or "5 Rebirths", TextSize = 16, Wrapped = true,
					Size = UDim2.new(1, -6, 0, 40), Position = UDim2.new(0, 3, 0, 30), ZIndex = 20 })
			else
				Style.icon({ Parent = btn, Image = data.Icon or Style.Icons.Star, Size = UDim2.new(0, 50, 0, 50),
					Position = UDim2.new(0.5, 0, 0.42, 0), ZIndex = 18 })
				Style.label({ Parent = btn, Text = data.Name or "Item", TextSize = 15,
					Position = UDim2.new(0, 0, 1, -22), Size = UDim2.new(1, 0, 0, 20), ZIndex = 20 })
			end
		end

		for i = 1, 3 do
			local frame = newFrame({
				Parent = left, Name = "SlotFrame" .. i, Size = UDim2.new(0, 84, 0, 84),
				AnchorPoint = Vector2.new(0.5, 0.5), Position = slotPositions[i], ZIndex = 15,
			})
			slotFrames[i] = frame
		end

		-- slots = array of 3: false/nil (empty) | { Name, Icon, Gradient } | { Locked = true, Requirement = "5 Rebirths" }
		function ui.SetEquipSlots(slots)
			for i = 1, 3 do
				renderSlot(i, slots[i])
			end
		end

		Style.label({
			Parent = left, Text = "Additional Slots:", TextSize = 20,
			Position = UDim2.new(0, 0, 0, 238), Size = UDim2.new(1, 0, 0, 26), ZIndex = 15,
		})
		for i = 1, 3 do
			local unlock = Style.button({
				Name = "Unlock" .. i, Parent = left, Size = UDim2.new(0, 74, 0, 70),
				Position = UDim2.new(0, 12 + (i - 1) * 81, 0, 268), Gradient = Style.Gradients.DarkGrey,
				ZIndex = 16, BorderThickness = 2.5, Shine = false,
				OnClick = function()
					if callbacks.OnUnlockSlot then
						callbacks.OnUnlockSlot(i)
					end
				end,
			})
			unlock:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(255, 170, 0)
			Style.label({
				Parent = unlock, Text = "UNLOCK\nNOW", TextSize = 14, Color = GREEN_TEXT, Wrapped = true,
				Position = UDim2.new(0, 0, 0, 6), Size = UDim2.new(1, 0, 0, 34), ZIndex = 20,
			})
			addPrice(unlock, 99, 17, 20, 18)
		end

		-- right: item grid
		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "ItemGrid"
		scroll.Size = UDim2.new(1, -278, 1, -50)
		scroll.Position = UDim2.new(0, 270, 0, 42)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 8
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.ZIndex = 13
		scroll.Parent = panel
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.new(0, 94, 0, 93)
		grid.CellPadding = UDim2.new(0, 5, 0, 5)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = scroll

		local itemColors = {
			Blue = Style.Gradients.Blue, Green = Style.Gradients.Green, Grey = Style.Gradients.Grey,
			Purple = Style.Gradients.Purple, Orange = Style.Gradients.Orange,
		}
		local itemCells = {}

		-- items = { { Id, Name, Icon, Count, Color = "Blue"/"Green"/"Grey"/... } }
		function ui.SetItems(items)
			for _, cell in ipairs(itemCells) do
				cell:Destroy()
			end
			itemCells = {}
			for i, item in ipairs(items) do
				local btn = Style.button({
					Name = "Item_" .. tostring(item.Id), Parent = scroll, Size = UDim2.new(0, 94, 0, 93),
					Gradient = itemColors[item.Color or "Grey"] or Style.Gradients.Grey,
					ZIndex = 14, LayoutOrder = i, BorderThickness = 2.5, Shine = false,
					OnClick = function()
						if callbacks.OnToggleItem then
							callbacks.OnToggleItem(item.Id)
						end
					end,
				})
				Style.icon({ Parent = btn, Image = item.Icon or Style.Icons.Star, Size = UDim2.new(0, 56, 0, 56),
					Position = UDim2.new(0.5, 0, 0.4, 0), ZIndex = 18 })
				local text = item.Name or "Item"
				if item.Count and item.Count > 1 then
					text = text .. "\nx" .. tostring(item.Count)
				end
				Style.label({ Parent = btn, Text = text, TextSize = 15, Wrapped = true,
					Position = UDim2.new(0, 0, 1, -34), Size = UDim2.new(1, 0, 0, 32), ZIndex = 20 })
				table.insert(itemCells, btn)
			end
		end

		ui.SetEquipSlots({ false, false, { Locked = true, Requirement = "5 Rebirths" } })
	end

	------------------------------------------------
	-- 8. Worlds window
	------------------------------------------------
	do
		local w = makeWindow("Worlds", {
			Size = UDim2.new(0, 508, 0, 66 + 350),
			Title = "Worlds", TitleIcon = Style.Icons.World, HeaderWidth = 508, HeaderX = 0, HeaderHeight = 66,
			HeaderGradient = Style.Gradients.Green, PanelTransparency = 0.02,
			CloseSize = 54, ClosePosition = UDim2.new(1, -8, 0, 6),
		})
		local panel = w.Panel
		panel.Position = UDim2.new(0, 21, 0, 66)
		panel.Size = UDim2.new(1, -42, 1, -66)

		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "WorldList"
		scroll.Size = UDim2.new(1, -8, 1, -8)
		scroll.Position = UDim2.new(0, 4, 0, 4)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 6
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.ZIndex = 13
		scroll.Parent = panel
		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 5)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = scroll

		local worldCards = {}

		-- worlds = { { Id, Name, Image (optional rbxassetid), Gradient, Unlocked, Requirement } }
		function ui.SetWorlds(worlds)
			for _, c in ipairs(worldCards) do
				c:Destroy()
			end
			worldCards = {}
			for i, world in ipairs(worlds) do
				local card = Style.tile({
					Name = "World_" .. tostring(world.Id), Parent = scroll, Size = UDim2.new(1, -8, 0, 118),
					Gradient = world.Gradient or Style.Gradients.Blue, ZIndex = 14, LayoutOrder = i,
					BorderThickness = 3.5, Checker = world.Image == nil,
				})
				if world.Image then
					local img = Instance.new("ImageLabel")
					img.Name = "Preview"
					img.Size = UDim2.new(1, 0, 1, 0)
					img.BackgroundTransparency = 1
					img.Image = world.Image
					img.ScaleType = Enum.ScaleType.Crop
					img.ZIndex = 15
					img.Parent = card
				end
				Style.label({
					Parent = card, Text = world.Name, TextSize = 36, XAlignment = Enum.TextXAlignment.Left,
					Position = UDim2.new(0, 10, 0, 2), Size = UDim2.new(0.7, 0, 0, 44), ZIndex = 20, StrokeThickness = 4,
				})
				local unlocked = world.Unlocked ~= false
				Style.button({
					Name = "Teleport", Parent = card,
					Size = UDim2.new(0, unlocked and 150 or 170, 0, 40),
					AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -6),
					Gradient = unlocked and Style.Gradients.Lime or Style.Gradients.Orange,
					Text = unlocked and "Teleport" or (world.Requirement or "Locked"),
					TextSize = 24, ZIndex = 22, BorderThickness = 3,
					OnClick = function()
						if unlocked then
							if callbacks.OnTeleport then
								callbacks.OnTeleport(world.Id)
							end
						else
							Style.play("error")
						end
					end,
				})
				table.insert(worldCards, card)
			end
		end
	end

	------------------------------------------------
	-- 9. Shop window
	------------------------------------------------
	do
		local w = makeWindow("Shop", {
			Size = UDim2.new(0, 636, 0, 34 + 442),
			Title = "SHOP", TitleIcon = Style.Icons.Cart, HeaderWidth = 319,
			HeaderGradient = Style.Gradients.Orange, PanelTransparency = 0.02,
		})

		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "Products"
		scroll.Size = UDim2.new(1, -12, 1, -42)
		scroll.Position = UDim2.new(0, 6, 0, 38)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 8
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.ZIndex = 13
		scroll.Parent = w.Panel
		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 8)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.Parent = scroll
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 8)
		pad.PaddingBottom = UDim.new(0, 8)
		pad.Parent = scroll

		local order = 0
		local currentGrid = nil
		local function place(inst)
			order += 1
			inst.LayoutOrder = order
			currentGrid = nil
			return inst
		end
		local function purchase(product)
			return function()
				if callbacks.OnPurchase then
					callbacks.OnPurchase(product)
				end
			end
		end

		-- Section heading ("Limited")
		function ui.AddHeading(text)
			local f = newFrame({ Parent = scroll, Name = "Heading", Size = UDim2.new(1, -14, 0, 40), ZIndex = 14 })
			Style.label({ Parent = f, Text = "<i>" .. text .. "</i>", RichText = true, TextSize = 36,
				ZIndex = 15, StrokeThickness = 3.5 })
			return place(f)
		end

		-- Two big portrait cards (e.g. limited pets).
		-- cards = { { Name, Stock ("799/1K LEFT"), Icon, Footer ("+3K / Damage"), Price, Gradient, ProductId } }
		function ui.AddFeaturedPets(cards)
			local row = newFrame({ Parent = scroll, Name = "FeaturedRow", Size = UDim2.new(1, -14, 0, 262), ZIndex = 14 })
			for i, card in ipairs(cards) do
				local tile = Style.tile({
					Name = "Pet_" .. tostring(card.ProductId or i), Parent = row,
					Size = UDim2.new(0, 212, 0, 262),
					AnchorPoint = Vector2.new(i == 1 and 1 or 0, 0),
					Position = UDim2.new(0.5, i == 1 and -14 or 14, 0, 0),
					Gradient = card.Gradient or Style.Gradients.Pink, ZIndex = 15, BorderThickness = 3,
				})
				Style.label({ Parent = tile, Text = card.Name, TextSize = 26, Position = UDim2.new(0, 0, 0, 4),
					Size = UDim2.new(1, 0, 0, 30), ZIndex = 20 })
				Style.label({ Parent = tile, Text = card.Stock or "", TextSize = 20, Color = Color3.fromRGB(255, 70, 90),
					Position = UDim2.new(0, 0, 0, 34), Size = UDim2.new(1, 0, 0, 24), ZIndex = 20 })
				Style.icon({ Parent = tile, Image = card.Icon or Style.Icons.Pet, Size = UDim2.new(0, 190, 0, 160),
					Position = UDim2.new(0.5, 0, 0.5, 2), ZIndex = 18 })
				Style.label({ Parent = tile, Text = card.Footer or "", TextSize = 20, Color = YELLOW_TEXT,
					Position = UDim2.new(0, 0, 1, -76), Size = UDim2.new(1, 0, 0, 26), ZIndex = 20 })
				buyButton({
					Parent = tile, Size = UDim2.new(0, 124, 0, 38), AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -8), Price = card.Price, TextSize = 24, ZIndex = 21,
					OnClick = purchase(card),
				})
			end
			return place(row)
		end

		-- Rainbow bundle card.
		-- bundle = { Name, Items = { { Icon, Label } }, Price, OldPrice, ProductId }
		function ui.AddBundle(bundle)
			local card = Style.tile({
				Name = "Bundle_" .. tostring(bundle.ProductId or order), Parent = scroll,
				Size = UDim2.new(1, -14, 0, 190), Gradient = Style.Rainbow, ZIndex = 15, BorderThickness = 3,
			})
			card.Fill.Rotation = 20
			Style.onIdle(card, function(t)
				card.Fill.Rotation = 20 + math.sin(t * 1.5) * 25
			end)
			for i, item in ipairs(bundle.Items or {}) do
				local box = Style.tile({
					Parent = card, Size = UDim2.new(0, 126, 0, 120),
					Position = UDim2.new(0, 14 + (i - 1) * 134, 0, 28), Gradient = Style.Gradients.Navy,
					ZIndex = 17, BorderThickness = 2.5, Checker = false,
				})
				Style.icon({ Parent = box, Image = item.Icon, Size = UDim2.new(0, 84, 0, 84),
					Position = UDim2.new(0.5, 0, 0.45, 0), ZIndex = 20 })
				if item.Label then
					Style.label({ Parent = box, Text = item.Label, TextSize = 14, Position = UDim2.new(0, 0, 1, -22),
						Size = UDim2.new(1, 0, 0, 20), ZIndex = 22 })
				end
			end
			Style.label({ Parent = card, Text = bundle.Name or "Bundle", TextSize = 36,
				XAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14, 0, 4), Size = UDim2.new(0, 220, 0, 80), Wrapped = true, ZIndex = 20, StrokeThickness = 4 })
			if bundle.OldPrice then
				Style.label({ Parent = card, RichText = true, Text = string.format("<s>%d</s>", bundle.OldPrice),
					TextSize = 26, Color = Color3.fromRGB(255, 50, 50), AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -30, 0, 88), Size = UDim2.new(0, 120, 0, 30), ZIndex = 20 })
			end
			buyButton({
				Parent = card, Size = UDim2.new(0, 180, 0, 44), AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -12, 1, -10), Price = bundle.Price, TextSize = 28, ZIndex = 21,
				OnClick = purchase(bundle),
			})
			return place(card)
		end

		-- Crate / egg card with drop chances.
		-- crate = { Name, Icon, Gradient, Sunburst (bool), Footer ("*OP ITEMS!*"),
		--           Slots = { { Top, Sub, Icon, Percent, Gradient } },
		--           Buttons = { { Price, OldPrice, Text ("Open x20"), ProductId } } }
		function ui.AddCrate(crate)
			local hasButtons = crate.Buttons and #crate.Buttons > 0
			local cardHeight = hasButtons and 226 or 168
			local card = Style.tile({
				Name = "Crate_" .. tostring(crate.Name), Parent = scroll,
				Size = UDim2.new(1, -14, 0, cardHeight), Gradient = crate.Gradient or Style.Gradients.Gold,
				ZIndex = 15, BorderThickness = 3,
			})
			if crate.Sunburst then
				local sun = Instance.new("ImageLabel")
				sun.Name = "Sunburst"
				sun.Image = SUNBURST
				sun.BackgroundTransparency = 1
				sun.ImageTransparency = 0.35
				sun.Size = UDim2.new(0, 420, 0, 420)
				sun.AnchorPoint = Vector2.new(0.5, 0.5)
				sun.Position = UDim2.new(0, 100, 0.5, 0)
				sun.ZIndex = 16
				sun.Parent = card
				Style.onIdle(sun, function(t)
					sun.Rotation = (t * 20) % 360
				end)
			end
			Style.label({ Parent = card, Text = crate.Name, TextSize = 28, XAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.new(0, 10, 0, 4), Size = UDim2.new(0, 200, 0, 34), ZIndex = 20, StrokeThickness = 3.4 })
			if crate.Icon then
				Style.icon({ Parent = card, Image = crate.Icon, Size = UDim2.new(0, 190, 0, 150),
					AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 8), ZIndex = 18 })
			end
			if crate.Footer then
				Style.label({ Parent = card, Text = crate.Footer, TextSize = 28, Color = YELLOW_TEXT,
					XAlignment = Enum.TextXAlignment.Left, AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 10, 1, -6), Size = UDim2.new(0, 210, 0, 34), ZIndex = 21 })
			end

			local slots = crate.Slots or {}
			local n = math.max(#slots, 1)
			local gap = 4
			local slotArea = newFrame({
				Parent = card, Name = "Slots", Size = UDim2.new(1, -226, 0, 114),
				Position = UDim2.new(0, 214, 0, 24), ZIndex = 17,
			})
			local grid = Instance.new("UIGridLayout")
			grid.CellSize = UDim2.new(1 / n, -gap * (n - 1) / n, 1, 0)
			grid.CellPadding = UDim2.new(0, gap, 0, 0)
			grid.SortOrder = Enum.SortOrder.LayoutOrder
			grid.Parent = slotArea
			for i, slot in ipairs(slots) do
				local cell = newFrame({ Parent = slotArea, Name = "Slot" .. i, Size = UDim2.new(0, 60, 1, 0), ZIndex = 18 })
				cell.LayoutOrder = i
				Style.label({ Parent = cell, Text = slot.Top or "", TextSize = 12, Color = YELLOW_TEXT, Wrapped = true,
					Size = UDim2.new(1, 0, 0, 24), ZIndex = 22 })
				local tile = Style.tile({
					Parent = cell, Size = UDim2.new(1, 0, 1, -26), Position = UDim2.new(0, 0, 0, 26),
					Gradient = slot.Gradient or Style.Gradients.Green, ZIndex = 19, BorderThickness = 2.5,
				})
				if slot.Sub then
					Style.label({ Parent = tile, Text = slot.Sub, TextSize = 12, Size = UDim2.new(1, 0, 0, 16),
						Position = UDim2.new(0, 0, 0, 2), ZIndex = 24, StrokeThickness = 1.8 })
				end
				if slot.Icon then
					Style.icon({ Parent = tile, Image = slot.Icon, Size = UDim2.new(0.82, 0, 0, 44),
						Position = UDim2.new(0.5, 0, 0.46, 0), ZIndex = 22 })
				end
				Style.label({ Parent = tile, Text = slot.Percent or "", TextSize = 18, Size = UDim2.new(1, 0, 0, 22),
					Position = UDim2.new(0, 0, 1, -24), ZIndex = 24, StrokeThickness = 2.6 })
			end

			if hasButtons then
				local rowF = newFrame({
					Parent = card, Name = "Buttons", Size = UDim2.new(1, -240, 0, 58),
					Position = UDim2.new(0, 226, 0, 148), ZIndex = 17,
				})
				local bn = #crate.Buttons
				local bgrid = Instance.new("UIGridLayout")
				bgrid.CellSize = UDim2.new(1 / bn, -8 * (bn - 1) / bn, 1, 0)
				bgrid.CellPadding = UDim2.new(0, 8, 0, 0)
				bgrid.SortOrder = Enum.SortOrder.LayoutOrder
				bgrid.Parent = rowF
				for i, b in ipairs(crate.Buttons) do
					local gradient = i == 1 and Style.Gradients.Yellow or Style.Gradients.Lime
					local btn = Style.button({
						Name = "Open" .. i, Parent = rowF, Size = UDim2.new(0, 100, 1, 0), Gradient = gradient,
						ZIndex = 20, LayoutOrder = i, BorderThickness = 3, OnClick = purchase(b),
					})
					if b.OldPrice then
						Style.label({ Parent = btn, RichText = true, Text = string.format("<s>%s</s>", tostring(b.OldPrice)),
							TextSize = 13, Color = Color3.fromRGB(255, 50, 50), Size = UDim2.new(1, 0, 0, 14),
							Position = UDim2.new(0, 0, 0, 1), ZIndex = 26, StrokeThickness = 2 })
					end
					addPrice(btn, b.Price, 22, 25, -4)
					Style.label({ Parent = btn, Text = b.Text or "Open", TextSize = 15, Size = UDim2.new(1, 0, 0, 16),
						Position = UDim2.new(0, 0, 1, -18), ZIndex = 26, StrokeThickness = 2.2 })
				end
			end
			return place(card)
		end

		-- Gamepass-style 2-column product cards.
		-- product = { Name, Description, Price, Icon, Tag ("X2"/"OP"), Gradient, ProductId }
		function ui.AddProduct(product)
			if not currentGrid then
				local holder = Instance.new("Frame")
				holder.Name = "ProductGrid"
				holder.Size = UDim2.new(1, -14, 0, 0)
				holder.AutomaticSize = Enum.AutomaticSize.Y
				holder.BackgroundTransparency = 1
				holder.ZIndex = 14
				holder.Parent = scroll
				local productGrid = Instance.new("UIGridLayout")
				productGrid.CellSize = UDim2.new(0.5, -6, 0, 160)
				productGrid.CellPadding = UDim2.new(0, 10, 0, 10)
				productGrid.SortOrder = Enum.SortOrder.LayoutOrder
				productGrid.Parent = holder
				order += 1
				holder.LayoutOrder = order
				currentGrid = holder
			end
			local card = Style.tile({
				Name = "Product_" .. tostring(product.ProductId or #currentGrid:GetChildren()), Parent = currentGrid,
				Size = UDim2.new(1, 0, 1, 0), Gradient = product.Gradient or Style.Gradients.Red, ZIndex = 15,
				BorderThickness = 3,
			})
			card.LayoutOrder = #currentGrid:GetChildren()
			if product.Gradient == Style.Rainbow then
				card.Fill.Color = Style.Rainbow
				Style.onIdle(card, function(t)
					card.Fill.Rotation = 20 + math.sin(t * 1.5) * 25
				end)
			end
			Style.icon({ Parent = card, Image = product.Icon or Style.Icons.Star,
				Size = UDim2.new(0, 112, 0, 112), AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 6, 0.46, 0), ZIndex = 18 })
			if product.Tag then
				Style.label({ Parent = card, Text = product.Tag, TextSize = 26, Color = YELLOW_TEXT,
					XAlignment = Enum.TextXAlignment.Left, AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 10, 1, -10), Size = UDim2.new(0, 60, 0, 32), ZIndex = 21 })
			end
			Style.label({ Parent = card, Text = product.Name or "Product", TextSize = 26,
				XAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0, 70, 0, 6),
				Size = UDim2.new(1, -78, 0, 32), ZIndex = 20 })
			Style.label({ Parent = card, Text = product.Description or "", TextSize = 16, Wrapped = true,
				XAlignment = Enum.TextXAlignment.Right, YAlignment = Enum.TextYAlignment.Top,
				Position = UDim2.new(0, 110, 0, 40), Size = UDim2.new(1, -118, 0, 50), ZIndex = 20 })
			buyButton({
				Parent = card, Size = UDim2.new(0, 144, 0, 40), AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -10, 1, -10), Price = product.Price, TextSize = 24, ZIndex = 21,
				OnClick = purchase(product),
			})
			return card
		end

		function ui.ClearShop()
			for _, child in ipairs(scroll:GetChildren()) do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end
			order = 0
			currentGrid = nil
		end
	end

	return ui
end

return GameUI
]==])

add('Main', 'LocalScript', [==[
--!nonstrict
-- Main.client.luau
-- Demo LocalScript with placeholder data. Replace the callbacks with your own remotes and
-- the sample data with your game's real pets / items / products.
-- Setup in Studio:
--   StarterPlayerScripts/GameUI (Folder)
--     Main (LocalScript)   <- this file
--     GameUI (ModuleScript)
--     Style  (ModuleScript)

local Players = game:GetService("Players")
local GameUI = require(script.Parent.GameUI)
local Style = require(script.Parent.Style)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local I = Style.Icons

local state = { Trophies = 100, Rebirths = 0, Level = 10 }

local ui
ui = GameUI.new(playerGui, {
	OnRebirth = function()
		state.Rebirths += 1
		state.Level = 0
		ui.SetRebirthData({
			Current = state.Rebirths, DamageNow = state.Rebirths + 1, DamageNext = state.Rebirths + 2,
			MaxLevelNow = 10 + state.Rebirths * 10, MaxLevelNext = 20 + state.Rebirths * 10,
			Level = state.Level, LevelRequired = 10 + state.Rebirths * 10,
		})
	end,
	OnSkipRebirth = function() print("Prompt Skip Rebirth developer product here") end,
	OnEquipBest = function() print("Equip best") end,
	OnUnequipAll = function() print("Unequip all") end,
	OnDeletePets = function() print("Delete mode") end,
	OnTogglePet = function(id, equipped) print("Pet", id, equipped and "equipped" or "unequipped") end,
	OnToggleItem = function(id) print("Item", id) end,
	OnUnlockSlot = function(index) print("Unlock slot", index) end,
	OnTeleport = function(worldId) print("Teleport to world", worldId) end,
	OnRewards = function() print("Open rewards") end,
	OnStatBoost = function(index) print("Stat boost", index) end,
	OnPurchase = function(product)
		-- Real game: MarketplaceService:PromptProductPurchase(player, product.ProductId)
		-- or PromptGamePassPurchase for game passes.
		print("Purchase requested:", product.Name or product.Text, product.ProductId)
	end,
})

-- HUD
ui.SetTrophies(state.Trophies)
ui.SetFriendBoost(0)
ui.SetRewards(5)
ui.SetDamage("69.4K")
ui.SetMultiplier("1x")
ui.SetSpeed(19)
ui.SetLevel(10, 1, true)
ui.SetStatBoosts({ "+83.3K", "+200K", "+1M" })
ui.AddQuickBuy({ Name = "2x Wins", Price = 29, Icon = I.Trophy, Gradient = Style.Gradients.Orange, ProductId = 11 })
ui.AddQuickBuy({ Name = "+2x DAMAGE", Price = 9, Icon = I.Sword, Gradient = Style.Gradients.RedOrange, ProductId = 12 })
ui.AddQuickBuy({ Name = "+5 Speed", Price = 19, Icon = "rbxassetid://135273757224572", Gradient = Style.Gradients.Blue,
	SubText = "PERMANENT!", ProductId = 13 })

-- Rebirth
ui.SetRebirthData({
	Current = 0, DamageNow = 1, DamageNext = 2, MaxLevelNow = 10, MaxLevelNext = 20,
	Level = state.Level, LevelRequired = 10,
})

-- Pets
ui.SetPets({
	{ Id = 1, Name = "Dog", Rarity = "Common", Equipped = true },
	{ Id = 2, Name = "Cat", Rarity = "Rare", Icon = "rbxassetid://126233304381053" },
	{ Id = 3, Name = "Bunny", Rarity = "Epic", Icon = "rbxassetid://107471473111631" },
	{ Id = 4, Name = "Golden Dog", Rarity = "Legendary", Icon = "rbxassetid://104095781189267" },
})

-- Items
ui.SetItems({
	{ Id = 1, Name = "Key", Icon = "rbxassetid://93405174357401", Color = "Blue" },
	{ Id = 2, Name = "Gift", Icon = "rbxassetid://96888229999409", Color = "Green" },
	{ Id = 3, Name = "Egg", Icon = "rbxassetid://94178495605496", Color = "Grey", Count = 2 },
	{ Id = 4, Name = "Rocket", Icon = "rbxassetid://71952601962928", Color = "Grey" },
})
ui.SetEquipSlots({ false, false, { Locked = true, Requirement = "5 Rebirths" } })

-- Worlds (set Image = "rbxassetid://..." to show a preview picture)
ui.SetWorlds({
	{ Id = 1, Name = "World 1", Gradient = Style.Gradients.Green, Unlocked = true },
	{ Id = 2, Name = "World 2", Gradient = Style.Gradients.Blue, Unlocked = false, Requirement = "Beat World 1" },
	{ Id = 3, Name = "World 3", Gradient = Style.Gradients.RedOrange, Unlocked = false, Requirement = "Beat World 2" },
})

-- Shop
ui.AddFeaturedPets({
	{ Name = "Spider Rex", Stock = "799/1K LEFT", Icon = "rbxassetid://104095781189267", Footer = "+3K / Damage",
		Price = 499, Gradient = Style.Gradients.Pink, ProductId = 21 },
	{ Name = "Titan", Stock = "416/1K LEFT", Icon = "rbxassetid://136641367912532", Footer = "ALWAYS 100% BETTER",
		Price = 299, Gradient = Style.Gradients.RedOrange, ProductId = 22 },
})
ui.AddBundle({
	Name = "Starter Pack", Price = 199, OldPrice = 490, ProductId = 23,
	Items = { { Icon = I.Trophy, Label = "Wins x2" }, { Icon = I.Rebirth, Label = "+1 Rebirth" }, { Icon = I.Star, Label = "Level" } },
})
ui.AddHeading("Limited")
ui.AddCrate({
	Name = "Royal Chest", Icon = I.Chest, Footer = "*OP ITEMS!*",
	Slots = {
		{ Top = "+75%", Sub = "All Stats", Icon = I.Trophy, Percent = "50%", Gradient = Style.Gradients.Green },
		{ Top = "+100%", Sub = "All Stats", Icon = I.Star, Percent = "35%", Gradient = Style.Gradients.Yellow },
		{ Top = "+125%", Sub = "All Stats", Icon = I.Heart, Percent = "13%", Gradient = Style.Gradients.Pink },
		{ Top = "+200%", Sub = "All Stats", Icon = "rbxassetid://93317929602850", Percent = "1%", Gradient = Style.Gradients.RedOrange },
		{ Top = "+500%", Sub = "All Stats", Icon = "rbxassetid://120835265944542", Percent = "0.1%", Gradient = Style.Gradients.Purple },
	},
	Buttons = {
		{ Price = "1.2K", OldPrice = 490, Text = "Open x20", ProductId = 31 },
		{ Price = 199, OldPrice = 490, Text = "Open x3", ProductId = 32 },
		{ Price = 79, Text = "Open x1", ProductId = 33 },
	},
})
ui.AddCrate({
	Name = "Lava Egg", Icon = nil, Sunburst = true, Gradient = Style.Gradients.RedOrange,
	Slots = {
		{ Top = "Lava Monkey", Icon = I.Pet, Percent = "34.6%", Gradient = Style.Gradients.Blue },
		{ Top = "Hellhound", Icon = I.Pet, Percent = "28%", Gradient = Style.Gradients.Purple },
		{ Top = "Fire Horse", Icon = I.Pet, Percent = "20%", Gradient = Style.Gradients.Purple },
		{ Top = "Hell Spider", Icon = I.Pet, Percent = "12%", Gradient = Style.Gradients.Yellow },
		{ Top = "Phoenix", Icon = I.Pet, Percent = "5%", Gradient = Style.Gradients.Pink },
		{ Top = "Fire Breathing Dragon", Icon = I.Pet, Percent = "0.4%", Gradient = Style.Gradients.Cyan },
	},
})
ui.AddProduct({ Name = "X2 Health", Description = "Get Twice more Health!", Price = 275,
	Icon = I.Heart, Gradient = Style.Gradients.Red, ProductId = 41 })
ui.AddProduct({ Name = "Auto Clicker", Description = "Gain damage automatically", Price = 49, Tag = "OP",
	Icon = I.AutoClick, Gradient = Style.Rainbow, ProductId = 42 })
ui.AddProduct({ Name = "X2 Wins", Description = "Earn Twice More Wins! (ALL TYPES)", Price = 99, Tag = "X2",
	Icon = I.Trophy, Gradient = Style.Gradients.Orange, ProductId = 43 })
ui.AddProduct({ Name = "X2 Items Chance", Description = "Get twice more Eggs luck", Price = 249, Tag = "X2",
	Icon = I.Chest, Gradient = Style.Gradients.Cyan, ProductId = 44 })
]==])

print('GameUI installed in StarterPlayerScripts. Press Play to test.')