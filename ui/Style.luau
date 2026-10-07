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
