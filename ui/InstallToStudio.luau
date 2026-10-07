-- Paste this whole script into Roblox Studio's Command Bar (View > Command Bar) and press Enter.
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

local Style = {}

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
	return f
end

----------------------------------------------------
-- Button: same look as a tile, plus hover / click scale tweens
-- Returns the ImageButton; the label (if any) is button.Label.
----------------------------------------------------
local HOVER = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RELEASE = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

function Style.bindButton(btn, hover, press)
	local scale = btn:FindFirstChild("ButtonScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "ButtonScale"
		scale.Parent = btn
	end
	hover = hover or 1.06
	press = press or 0.94
	btn.MouseEnter:Connect(function()
		TweenService:Create(scale, HOVER, { Scale = hover }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(scale, HOVER, { Scale = 1 }):Play()
	end)
	btn.MouseButton1Down:Connect(function()
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

	Style.bindButton(b, props.Hover, props.Press)
	if props.OnClick then
		b.Activated:Connect(props.OnClick)
	end
	return b
end

-- Red "!" notification badge (circle) that can be shown/hidden.
function Style.badge(parent, position)
	local b = Instance.new("Frame")
	b.Name = "Badge"
	b.Size = UDim2.new(0, 34, 0, 34)
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = position
	b.BackgroundColor3 = Color3.fromRGB(235, 25, 40)
	b.BorderSizePixel = 0
	b.ZIndex = 30
	b.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = b
	Style.stroke(b, 3, Color3.fromRGB(255, 255, 255))
	Style.label({ Parent = b, Text = "!", TextSize = 26, ZIndex = 31, StrokeThickness = 2 })
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

function Style.closeButton(parent, onClick)
	local b = Style.button({
		Name = "CloseButton",
		Parent = parent,
		Size = UDim2.new(0, 50, 0, 50),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 14, 0, -22),
		Gradient = Style.Gradients.Red,
		Text = "X",
		TextSize = 40,
		ZIndex = 40,
		BorderThickness = 3.5,
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
		Size = UDim2.new(0, props.HeaderWidth or 250, 0, 62),
		Position = UDim2.new(0, -14, 0, 0),
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
		TextSize = 40,
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

	function window.Open()
		if open then
			return
		end
		open = true
		local target = Style.deviceScale(props.Camera)
		scale.Scale = target * 0.75
		frame.Visible = true
		TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = target,
		}):Play()
		if window.OnOpen then
			window.OnOpen()
		end
	end

	function window.Close()
		if not open then
			return
		end
		open = false
		local t = TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Scale = scale.Scale * 0.75,
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

	Style.closeButton(frame, window.Close)

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
-- Builds the full menu set: main button grid, currency HUD, Rebirth, Pets and Shop windows.
-- Every piece of game logic is a callback / setter, so you can wire it to your own remotes:
--
--   local GameUI = require(path.to.GameUI)
--   local ui = GameUI.new(playerGui, {
--       OnRebirth = function() ... end,
--       OnSkipRebirth = function() ... end,
--       OnEquipBest = function() ... end,
--       OnUnequipAll = function() ... end,
--       OnDeletePets = function() ... end,
--       OnTogglePet = function(petId, equipped) ... end,
--       OnPurchase = function(product) ... end,  -- product.ProductId / product.Kind
--   })
--   ui.SetTrophies(100); ui.SetRebirths(0); ui.SetPets({...}); ui.SetRebirthData({...})

local Style = require(script.Parent.Style)

local GameUI = {}

local ORANGE_TEXT = Color3.fromRGB(255, 176, 0)
local TILE_TEXT_SIZE = 26

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

-- A button wrapper that does NOT clip, so badges / big icons can overhang the tile.
local function menuTile(props)
	local wrapper = Instance.new("Frame")
	wrapper.Name = props.Name .. "Slot"
	wrapper.Size = props.Size
	wrapper.Position = props.Position
	wrapper.BackgroundTransparency = 1
	wrapper.ZIndex = 5
	wrapper.Parent = props.Parent

	local btn = Style.button({
		Name = props.Name,
		Parent = wrapper,
		Size = UDim2.new(1, 0, 1, 0),
		Gradient = props.Gradient,
		ZIndex = 6,
		BorderThickness = 4,
		OnClick = props.OnClick,
	})
	return wrapper, btn
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

	local function register(name, window)
		ui.Windows[name] = window
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

	------------------------------------------------
	-- 1. Main button grid (Store / Pets / Rebirth / Items / Worlds)
	------------------------------------------------
	local hud = Instance.new("Frame")
	hud.Name = "MainButtons"
	hud.Size = UDim2.new(0, 250, 0, 390)
	hud.AnchorPoint = Vector2.new(0, 0.5)
	hud.Position = UDim2.new(0, 16, 0.5, 0)
	hud.BackgroundTransparency = 1
	hud.Parent = gui
	local hudScale = Instance.new("UIScale")
	hudScale.Scale = Style.deviceScale(camera)
	hudScale.Parent = hud
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		hudScale.Scale = Style.deviceScale(camera)
	end)

	local function gridTile(name, text, icon, gradient, x, y, onClick)
		local wrapper, btn = menuTile({
			Name = name,
			Parent = hud,
			Size = UDim2.new(0, 118, 0, 118),
			Position = UDim2.new(0, x, 0, y),
			Gradient = gradient,
			OnClick = onClick,
		})
		Style.icon({
			Parent = btn,
			Image = icon,
			Size = UDim2.new(0, 78, 0, 78),
			Position = UDim2.new(0.5, 0, 0.4, 0),
			ZIndex = 9,
		})
		Style.label({
			Parent = btn,
			Name = "Label",
			Text = text,
			TextSize = TILE_TEXT_SIZE,
			Position = UDim2.new(0, 0, 1, -34),
			Size = UDim2.new(1, 0, 0, 30),
			ZIndex = 10,
		})
		return wrapper, btn
	end

	local storeWrapper, storeBtn = menuTile({
		Name = "Store",
		Parent = hud,
		Size = UDim2.new(0, 250, 0, 76),
		Position = UDim2.new(0, 0, 0, 50),
		Gradient = Style.Gradients.Orange,
		OnClick = function()
			ui.Windows.Shop.Toggle()
		end,
	})
	Style.label({
		Parent = storeBtn,
		Name = "Label",
		Text = "Store",
		TextSize = 44,
		StrokeThickness = 4,
		ZIndex = 10,
	})
	Style.icon({
		Parent = storeWrapper,
		Image = Style.Icons.Cart,
		Size = UDim2.new(0, 96, 0, 96),
		Position = UDim2.new(0.5, 0, 0, -22),
		ZIndex = 12,
	})
	ui.StoreBadge = Style.badge(storeWrapper, UDim2.new(1, -12, 0, 10))

	gridTile("Pets", "Pets", Style.Icons.Pet, Style.Gradients.Green, 0, 142, function()
		ui.Windows.Pets.Toggle()
	end)
	local rebirthWrapper = gridTile("RebirthOpen", "Rebirth", Style.Icons.Rebirth,
		Style.Gradients.Blue, 132, 142, function()
			ui.Windows.Rebirth.Toggle()
		end)
	ui.RebirthBadge = Style.badge(rebirthWrapper, UDim2.new(1, -4, 0, 4))
	local rebirthPercent = Style.label({
		Parent = rebirthWrapper,
		Name = "Percent",
		Text = "0%",
		TextSize = 26,
		XAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 8, 0.45, 0),
		Size = UDim2.new(0, 100, 0, 30),
		ZIndex = 14,
	})
	rebirthPercent.Rotation = -6

	gridTile("Items", "Items", Style.Icons.Backpack, Style.Gradients.Orange, 0, 274, function()
		if callbacks.OnItems then
			callbacks.OnItems()
		end
	end)
	gridTile("Worlds", "Worlds", Style.Icons.World, Style.Gradients.Purple, 132, 274, function()
		if callbacks.OnWorlds then
			callbacks.OnWorlds()
		end
	end)

	------------------------------------------------
	-- 2. Currency HUD (trophies / rebirths / friend boost)
	------------------------------------------------
	local stats = Instance.new("Frame")
	stats.Name = "Currencies"
	stats.Size = UDim2.new(0, 250, 0, 168)
	stats.AnchorPoint = Vector2.new(0, 1)
	stats.Position = UDim2.new(0, 16, 1, -16)
	stats.BackgroundTransparency = 1
	stats.Parent = gui
	local statsScale = Instance.new("UIScale")
	statsScale.Scale = Style.deviceScale(camera)
	statsScale.Parent = stats
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		statsScale.Scale = Style.deviceScale(camera)
	end)

	local function statRow(y, icon)
		Style.icon({
			Parent = stats,
			Image = icon,
			Size = UDim2.new(0, 68, 0, 68),
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 0, y),
			ZIndex = 6,
		})
		return Style.label({
			Parent = stats,
			Text = "0",
			TextSize = 46,
			Color = ORANGE_TEXT,
			XAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 78, 0, y),
			Size = UDim2.new(1, -78, 0, 68),
			StrokeThickness = 4,
			ZIndex = 6,
		})
	end
	local trophyLabel = statRow(0, Style.Icons.Trophy)
	local rebirthLabel = statRow(66, Style.Icons.Rebirth)

	local boostLabel = Style.label({
		Parent = stats,
		Text = "Friend Boost +0%",
		TextSize = 24,
		XAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 0, 0, 138),
		Size = UDim2.new(0, 205, 0, 30),
		ZIndex = 6,
	})
	local plus = Style.button({
		Name = "FriendBoostAdd",
		Parent = stats,
		Size = UDim2.new(0, 34, 0, 34),
		Position = UDim2.new(0, 214, 0, 136),
		Gradient = Style.Gradients.Lime,
		ZIndex = 6,
		BorderThickness = 3,
		OnClick = function()
			if callbacks.OnInviteFriends then
				callbacks.OnInviteFriends()
			end
		end,
	})
	Style.icon({ Parent = plus, Image = Style.Icons.Plus, Size = UDim2.new(0, 22, 0, 22), ZIndex = 9 })

	function ui.SetTrophies(n)
		trophyLabel.Text = formatNumber(n)
	end
	function ui.SetRebirths(n)
		rebirthLabel.Text = formatNumber(n)
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
	-- 3. Rebirth window
	------------------------------------------------
	do
		local w = register("Rebirth", Style.window({
			Name = "RebirthWindow",
			Parent = gui,
			Camera = camera,
			Size = UDim2.new(0, 580, 0, 420),
			Title = "REBIRTH",
			TitleIcon = Style.Icons.Rebirth,
			HeaderWidth = 290,
			HeaderGradient = Style.Gradients.BluePurple,
		}))
		local p = w.Panel

		local leftTitle = Style.label({
			Parent = p, Text = "Rebirth 0:", TextSize = 32,
			Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(0, 240, 0, 36), ZIndex = 15,
		})
		local rightTitle = Style.label({
			Parent = p, Text = "Rebirth 1:", TextSize = 32,
			Position = UDim2.new(1, -254, 0, 8), Size = UDim2.new(0, 240, 0, 36), ZIndex = 15,
		})

		local function statCard(x, y, w2, h, icon, text, gradient)
			local t = Style.tile({
				Parent = p,
				Size = UDim2.new(0, w2, 0, h),
				Position = UDim2.new(0, x, 0, y),
				Gradient = gradient or Style.Gradients.Orange,
				ZIndex = 14,
			})
			Style.icon({
				Parent = t, Image = icon,
				Size = UDim2.new(0, h - 6, 0, h - 6),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 4),
				ZIndex = 16,
			})
			local l = Style.label({
				Parent = t, Text = text, TextSize = 28, ZIndex = 18,
			})
			return l
		end

		local dmgNow = statCard(14, 52, 236, 62, Style.Icons.Sword, "X1 Damage")
		local dmgNext = statCard(330, 52, 236, 62, Style.Icons.Sword, "X2 Damage")
		local lvlNow = statCard(14, 124, 236, 62, Style.Icons.Star, "MAX Level 10")
		local lvlNext = statCard(330, 124, 236, 62, Style.Icons.Star, "MAX Level 20")

		for _, y in ipairs({ 62, 134 }) do
			Style.label({
				Parent = p, Text = ">>", TextSize = 52,
				Color = Color3.fromRGB(190, 235, 255),
				StrokeColor = Color3.fromRGB(40, 90, 150), StrokeThickness = 4,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, y - 6),
				Size = UDim2.new(0, 80, 0, 62),
				ZIndex = 15,
			})
		end

		local levelBar = Style.tile({
			Parent = p,
			Size = UDim2.new(1, -28, 0, 56),
			Position = UDim2.new(0, 14, 0, 198),
			Gradient = Style.Gradients.Yellow,
			ZIndex = 14,
		})
		Style.icon({
			Parent = levelBar, Image = Style.Icons.Star,
			Size = UDim2.new(0, 46, 0, 46),
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 108, 0.5, 0), ZIndex = 16,
		})
		local levelText = Style.label({
			Parent = levelBar, Text = "Level 10 / Level 10", TextSize = 30,
			XAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 166, 0, 0), Size = UDim2.new(1, -170, 1, 0), ZIndex = 18,
		})

		local skipBtn = Style.button({
			Name = "SkipRebirth", Parent = p,
			Size = UDim2.new(0, 252, 0, 78), Position = UDim2.new(0, 14, 0, 268),
			Gradient = Style.Gradients.Red, Text = "SKIP REBIRTH", TextSize = 30,
			ZIndex = 14, BorderThickness = 4,
			OnClick = function()
				if callbacks.OnSkipRebirth then
					callbacks.OnSkipRebirth()
				end
			end,
		})
		skipBtn.Fill.Color = Style.Rainbow
		skipBtn.Fill.Rotation = 25

		local rebirthAction = Style.button({
			Name = "DoRebirth", Parent = p,
			Size = UDim2.new(0, 262, 0, 78), Position = UDim2.new(1, -276, 0, 268),
			Gradient = Style.Gradients.Lime, Text = "REBIRTH", TextSize = 46,
			ZIndex = 14, BorderThickness = 4,
			OnClick = function()
				if w.CanRebirth and callbacks.OnRebirth then
					callbacks.OnRebirth()
				end
			end,
		})
		w.CanRebirth = true

		Style.label({
			Parent = p, Text = "KEEP ALL STATS!", TextSize = 20,
			Color = Color3.fromRGB(255, 220, 20),
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 352),
			Size = UDim2.new(0, 300, 0, 24), ZIndex = 15,
		})
		Style.label({
			Parent = w.Frame, Text = "Rebirth resets your Damage, Level, Wins ONLY!", TextSize = 24,
			Color = Color3.fromRGB(255, 40, 40),
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 8),
			Size = UDim2.new(1, 0, 0, 30), ZIndex = 40,
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
			rebirthAction.Fill.Color = ColorSequence.new(
				table.unpack(w.CanRebirth and Style.Gradients.Lime or { Color3.fromRGB(150, 155, 160), Color3.fromRGB(95, 100, 105) })
			)
			ui.SetRebirths(data.Current or 0)
			ui.SetRebirthProgress(math.clamp(level / math.max(required, 1), 0, 1) * 100)
		end
	end

	------------------------------------------------
	-- 4. Pets window
	------------------------------------------------
	do
		local w = register("Pets", Style.window({
			Name = "PetsWindow",
			Parent = gui,
			Camera = camera,
			Size = UDim2.new(0, 780, 0, 480),
			Title = "PETS",
			TitleIcon = Style.Icons.Pet,
			HeaderWidth = 280,
			HeaderGradient = Style.Gradients.Green,
			PanelTransparency = 0.12,
		}))
		w.Header.Position = UDim2.new(0, 160, 0, 0)
		local panel = w.Panel
		panel.Position = UDim2.new(0, 176, 0, 34)
		panel.Size = UDim2.new(1, -176, 1, -86)

		local function sideButton(text, y, gradient, cb)
			return Style.button({
				Name = text, Parent = w.Frame,
				Size = UDim2.new(0, 158, 0, 56), Position = UDim2.new(0, 0, 0, y),
				Gradient = gradient, Text = text, TextSize = 26, ZIndex = 20,
				OnClick = function()
					if cb then
						cb()
					end
				end,
			})
		end
		sideButton("Equip Best", 96, Style.Gradients.Lime, callbacks.OnEquipBest)
		sideButton("Unequip All", 160, Style.Gradients.Red, callbacks.OnUnequipAll)
		sideButton("Delete", 224, Style.Gradients.Red, callbacks.OnDeletePets)

		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "PetGrid"
		scroll.Size = UDim2.new(1, -20, 1, -20)
		scroll.Position = UDim2.new(0, 10, 0, 10)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 8
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.ZIndex = 13
		scroll.Parent = panel
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.new(0, 104, 0, 104)
		grid.CellPadding = UDim2.new(0, 10, 0, 10)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = scroll

		-- footer: backpack capacity + equipped pets
		local footer = Style.tile({
			Name = "Footer", Parent = w.Frame,
			Size = UDim2.new(0, 280, 0, 46), Position = UDim2.new(0, 176, 1, -50),
			Gradient = { Color3.fromRGB(110, 120, 128), Color3.fromRGB(70, 78, 86) },
			ZIndex = 20, BorderThickness = 4,
		})
		Style.icon({ Parent = footer, Image = Style.Icons.Backpack, Size = UDim2.new(0, 38, 0, 38),
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), ZIndex = 24 })
		local capacityLabel = Style.label({ Parent = footer, Text = "0/100", TextSize = 28,
			XAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 52, 0, 0),
			Size = UDim2.new(0, 90, 1, 0), ZIndex = 24 })
		Style.icon({ Parent = footer, Image = Style.Icons.Pet, Size = UDim2.new(0, 38, 0, 38),
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 146, 0.5, 0), ZIndex = 24 })
		local equippedLabel = Style.label({ Parent = footer, Text = "0/4", TextSize = 28,
			XAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 190, 0, 0),
			Size = UDim2.new(0, 80, 1, 0), ZIndex = 24 })

		local capacity, maxEquipped = 100, 4
		local cells = {}

		local function refreshCounts()
			local equipped = 0
			for _, cell in pairs(cells) do
				if cell.Equipped then
					equipped += 1
				end
			end
			local total = 0
			for _ in pairs(cells) do
				total += 1
			end
			capacityLabel.Text = string.format("%d/%d", total, capacity)
			equippedLabel.Text = string.format("%d/%d", equipped, maxEquipped)
		end

		local function setEquippedVisual(cell)
			cell.Tag.Visible = cell.Equipped
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
					Size = UDim2.new(0, 104, 0, 104), Gradient = rarityGradient(pet.Rarity),
					ZIndex = 14, LayoutOrder = i, BorderThickness = 3.5,
				})
				Style.icon({ Parent = btn, Image = pet.Icon or Style.Icons.Pet,
					Size = UDim2.new(0, 70, 0, 70), Position = UDim2.new(0.5, 0, 0.44, 0), ZIndex = 18 })
				Style.label({ Parent = btn, Text = pet.Name or "Pet", TextSize = 14,
					Position = UDim2.new(0, 0, 1, -22), Size = UDim2.new(1, 0, 0, 20), ZIndex = 19 })
				local tag = Style.label({ Name = "EquippedTag", Parent = btn, Text = "E", TextSize = 18,
					Color = Color3.fromRGB(190, 255, 30), Position = UDim2.new(0, 6, 0, 4),
					Size = UDim2.new(0, 20, 0, 20), ZIndex = 20 })
				local cell = { Button = btn, Tag = tag, Equipped = pet.Equipped == true, Id = pet.Id }
				cells[pet.Id] = cell
				setEquippedVisual(cell)
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
							return
						end
					end
					cell.Equipped = want
					setEquippedVisual(cell)
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
				setEquippedVisual(cell)
				refreshCounts()
			end
		end
	end

	------------------------------------------------
	-- 5. Shop window
	------------------------------------------------
	do
		local w = register("Shop", Style.window({
			Name = "ShopWindow",
			Parent = gui,
			Camera = camera,
			Size = UDim2.new(0, 600, 0, 470),
			Title = "SHOP",
			TitleIcon = Style.Icons.Cart,
			HeaderWidth = 250,
			HeaderGradient = Style.Gradients.Orange,
			PanelTransparency = 0.02,
		}))
		w.Header.Position = UDim2.new(0, -14, 0, 0)

		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "Products"
		scroll.Size = UDim2.new(1, -16, 1, -36)
		scroll.Position = UDim2.new(0, 8, 0, 28)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 8
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.ZIndex = 13
		scroll.Parent = w.Panel
		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 10)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = scroll

		local function priceButton(parent, product, size, position, anchor)
			local btn = Style.button({
				Name = "Buy", Parent = parent, Size = size, Position = position,
				AnchorPoint = anchor or Vector2.new(0, 0),
				Gradient = Style.Gradients.Lime, ZIndex = 20, BorderThickness = 3,
				OnClick = function()
					if callbacks.OnPurchase then
						callbacks.OnPurchase(product)
					end
				end,
			})
			Style.icon({ Parent = btn, Image = Style.Icons.Robux, Size = UDim2.new(0, 28, 0, 28),
				AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), ZIndex = 24 })
			Style.label({ Parent = btn, Text = tostring(product.Price), TextSize = 28,
				Position = UDim2.new(0, 36, 0, 0), Size = UDim2.new(1, -40, 1, 0), ZIndex = 24 })
			return btn
		end

		-- Wide featured card (e.g. VIP bundle)
		-- product = { Name, Lines = {..}, Price, OldPrice, Icon, ProductId, Kind }
		local function featuredCard(product, order)
			local card = Style.tile({
				Name = "Featured_" .. tostring(product.ProductId or order), Parent = scroll,
				Size = UDim2.new(1, -14, 0, 160), Gradient = Style.Gradients.Yellow, ZIndex = 14,
			})
			card.LayoutOrder = order
			Style.icon({ Parent = card, Image = product.Icon or Style.Icons.Star,
				Size = UDim2.new(0, 120, 0, 120), AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 14, 0.5, 0), ZIndex = 17 })
			Style.label({ Parent = card, Text = product.Name or "Bundle", TextSize = 28,
				XAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 150, 0, 8),
				Size = UDim2.new(1, -330, 0, 34), ZIndex = 18 })
			local lines = {}
			for _, line in ipairs(product.Lines or {}) do
				table.insert(lines, "- " .. line)
			end
			Style.label({ Parent = card, Text = table.concat(lines, "\n"), TextSize = 20,
				XAlignment = Enum.TextXAlignment.Left, YAlignment = Enum.TextYAlignment.Top,
				Position = UDim2.new(0, 150, 0, 44), Size = UDim2.new(1, -330, 1, -52), ZIndex = 18 })
			if product.OldPrice then
				Style.label({ Parent = card, RichText = true,
					Text = string.format("<s>%d</s>", product.OldPrice), TextSize = 26,
					Color = Color3.fromRGB(255, 50, 50), AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -16, 0, 8), Size = UDim2.new(0, 120, 0, 30), ZIndex = 20 })
			end
			priceButton(card, product, UDim2.new(0, 170, 0, 54), UDim2.new(1, -14, 1, -12), Vector2.new(1, 1))
			return card
		end

		local gridHolder = Instance.new("Frame")
		gridHolder.Name = "ProductGrid"
		gridHolder.Size = UDim2.new(1, -14, 0, 0)
		gridHolder.AutomaticSize = Enum.AutomaticSize.Y
		gridHolder.BackgroundTransparency = 1
		gridHolder.LayoutOrder = 100
		gridHolder.ZIndex = 14
		gridHolder.Parent = scroll
		local productGrid = Instance.new("UIGridLayout")
		productGrid.CellSize = UDim2.new(0.5, -6, 0, 168)
		productGrid.CellPadding = UDim2.new(0, 10, 0, 10)
		productGrid.SortOrder = Enum.SortOrder.LayoutOrder
		productGrid.Parent = gridHolder

		-- product = { Name, Description, Price, Icon, Tag ("X2"/"OP"), Gradient, ProductId, Kind }
		local function productCard(product, order)
			local card = Style.tile({
				Name = "Product_" .. tostring(product.ProductId or order), Parent = gridHolder,
				Size = UDim2.new(1, 0, 1, 0), Gradient = product.Gradient or Style.Gradients.Red, ZIndex = 15,
			})
			card.LayoutOrder = order
			if product.Gradient == Style.Rainbow then
				card.Fill.Color = Style.Rainbow
				card.Fill.Rotation = 20
			end
			Style.icon({ Parent = card, Image = product.Icon or Style.Icons.Star,
				Size = UDim2.new(0, 118, 0, 118), AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 6, 0.46, 0), ZIndex = 18 })
			if product.Tag then
				Style.label({ Parent = card, Text = product.Tag, TextSize = 26,
					Color = Color3.fromRGB(255, 200, 20), XAlignment = Enum.TextXAlignment.Left,
					AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -10),
					Size = UDim2.new(0, 60, 0, 32), ZIndex = 21 })
			end
			Style.label({ Parent = card, Text = product.Name or "Product", TextSize = 26,
				XAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0, 70, 0, 6),
				Size = UDim2.new(1, -78, 0, 32), ZIndex = 20 })
			Style.label({ Parent = card, Text = product.Description or "", TextSize = 16, Wrapped = true,
				XAlignment = Enum.TextXAlignment.Right, YAlignment = Enum.TextYAlignment.Top,
				Position = UDim2.new(0, 110, 0, 40), Size = UDim2.new(1, -118, 0, 50), ZIndex = 20 })
			priceButton(card, product, UDim2.new(0, 150, 0, 42), UDim2.new(1, -10, 1, -10), Vector2.new(1, 1))
			return card
		end

		local featuredCount = 0
		local productCount = 0
		function ui.ClearShop()
			for _, child in ipairs(scroll:GetChildren()) do
				if child:IsA("Frame") and child ~= gridHolder then
					child:Destroy()
				end
			end
			for _, child in ipairs(gridHolder:GetChildren()) do
				if child:IsA("Frame") then
					child:Destroy()
				end
			end
			featuredCount, productCount = 0, 0
		end
		function ui.AddFeaturedProduct(product)
			featuredCount += 1
			return featuredCard(product, featuredCount)
		end
		function ui.AddProduct(product)
			productCount += 1
			return productCard(product, productCount)
		end
	end

	return ui
end

return GameUI
]==])

add('Main', 'LocalScript', [==[
--!nonstrict
-- Main.client.luau
-- Demo LocalScript with placeholder data. Replace the callbacks with your own remotes.
-- Setup in Studio:
--   StarterPlayerScripts/GameUI (Folder)
--     Main (LocalScript)   <- this file
--     GameUI (ModuleScript)
--     Style  (ModuleScript)

local Players = game:GetService("Players")
local GameUI = require(script.Parent.GameUI)
local Style = require(script.Parent.Style)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

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
	OnSkipRebirth = function()
		print("Prompt Skip Rebirth developer product here")
	end,
	OnEquipBest = function() print("Equip best") end,
	OnUnequipAll = function() print("Unequip all") end,
	OnDeletePets = function() print("Delete mode") end,
	OnTogglePet = function(id, equipped) print("Pet", id, equipped and "equipped" or "unequipped") end,
	OnPurchase = function(product)
		-- Real game: MarketplaceService:PromptProductPurchase(player, product.ProductId)
		-- or PromptGamePassPurchase for product.Kind == "GamePass".
		print("Purchase requested:", product.Name, product.ProductId)
	end,
})

ui.SetTrophies(state.Trophies)
ui.SetFriendBoost(0)
ui.SetRebirthData({
	Current = 0, DamageNow = 1, DamageNext = 2, MaxLevelNow = 10, MaxLevelNext = 20,
	Level = state.Level, LevelRequired = 10,
})

ui.SetPets({
	{ Id = 1, Name = "Dog", Rarity = "Common", Equipped = true },
	{ Id = 2, Name = "Cat", Rarity = "Rare", Icon = "rbxassetid://126233304381053" },
	{ Id = 3, Name = "Bunny", Rarity = "Epic", Icon = "rbxassetid://107471473111631" },
	{ Id = 4, Name = "Golden Dog", Rarity = "Legendary", Icon = "rbxassetid://104095781189267" },
})

ui.AddFeaturedProduct({
	Name = "VIP Bundle", Price = 199, OldPrice = 490, Icon = Style.Icons.Star, ProductId = 0, Kind = "GamePass",
	Lines = { "VIP Chat Tag!", "1.5 Eggs Luck!", "Exclusive Backpack!" },
})
ui.AddProduct({ Name = "X2 Health", Description = "Get Twice more Health!", Price = 275,
	Icon = Style.Icons.Heart, Gradient = Style.Gradients.Red, ProductId = 1 })
ui.AddProduct({ Name = "Auto Clicker", Description = "Gain damage automatically", Price = 49, Tag = "OP",
	Icon = Style.Icons.AutoClick, Gradient = Style.Rainbow, ProductId = 2 })
ui.AddProduct({ Name = "X2 Wins", Description = "Earn Twice More Wins! (ALL TYPES)", Price = 99, Tag = "X2",
	Icon = Style.Icons.Trophy, Gradient = Style.Gradients.Orange, ProductId = 3 })
ui.AddProduct({ Name = "X2 Items Chance", Description = "Get twice more Eggs luck", Price = 249, Tag = "X2",
	Icon = Style.Icons.Chest, Gradient = Style.Gradients.Cyan, ProductId = 4 })
]==])

print('GameUI installed in StarterPlayerScripts. Press Play to test.')