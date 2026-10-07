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
	list.SortOrder = Enum.SortOrder.LayoutOrder
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
	-- The reference hides the whole HUD while a window is open.
	local hudFrames = {}
	local hudExtraVisible = {} -- frame -> false when the HUD element itself wants to stay hidden
	local hudHidden = false
	local function refreshHud()
		for _, f in ipairs(hudFrames) do
			f.Visible = not hudHidden and hudExtraVisible[f] ~= false
		end
	end
	local function refreshBlur()
		local anyOpen = false
		for _, window in pairs(ui.Windows) do
			if window.IsOpen() then
				anyOpen = true
			end
		end
		hudHidden = anyOpen
		refreshHud()
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
		table.insert(hudFrames, f)
		return f
	end

	------------------------------------------------
	-- 1. Main button grid (Store / Pets / Rebirth / Items / Worlds)
	------------------------------------------------
	local hud = scaledHud({
		Parent = gui, Name = "MainButtons", Size = UDim2.new(0, 141, 0, 194),
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.0786, 0, 0.5, 0),
	})

	local function menuTile(props)
		local wrapper = newFrame({
			Parent = hud, Name = props.Name .. "Slot", Size = props.Size, Position = props.Position, ZIndex = 5,
		})
		local btn = Style.button({
			Name = props.Name, Parent = wrapper, Size = UDim2.new(1, 0, 1, 0),
			Gradient = props.Gradient, ZIndex = 6, BorderThickness = 2, Shine = false, OnClick = props.OnClick,
		})
		btn.ClipsDescendants = false
		return wrapper, btn
	end

	local function gridTile(name, text, icon, gradient, x, y, onClick)
		local wrapper, btn = menuTile({
			Name = name, Size = UDim2.new(0, 66, 0, 66), Position = UDim2.new(0, x, 0, y),
			Gradient = gradient, OnClick = onClick,
		})
		Style.icon({
			Parent = btn, Image = icon, Size = UDim2.new(0, 50, 0, 50),
			Position = UDim2.new(0.5, 0, 0.45, 0), ZIndex = 9,
		})
		Style.label({
			Parent = btn, Name = "Label", Text = text, TextSize = 16, StrokeThickness = 2.5,
			Position = UDim2.new(0, 0, 1, -14), Size = UDim2.new(1, 0, 0, 22), ZIndex = 10,
		})
		return wrapper, btn
	end

	local storeWrapper, storeBtn = menuTile({
		Name = "Store", Size = UDim2.new(0, 141, 0, 42), Position = UDim2.new(0, 0, 0, 0),
		Gradient = Style.Gradients.Orange,
		OnClick = function()
			ui.Windows.Shop.Toggle()
		end,
	})
	Style.label({
		Parent = storeBtn, Name = "Label", Text = "Store", TextSize = 25, StrokeThickness = 2.6,
		Position = UDim2.new(0, 0, 0, 9), ZIndex = 10,
	})
	local cartIcon = Style.icon({
		Parent = storeWrapper, Image = Style.Icons.Cart, Size = UDim2.new(0, 52, 0, 52),
		Position = UDim2.new(0.5, 0, 0, -2), ZIndex = 12, NoShadow = true,
	})
	Style.onIdle(cartIcon, function(t)
		cartIcon.Position = UDim2.new(0.5, 0, 0, -2 + math.sin(t * 2.5) * 3)
		cartIcon.Rotation = math.sin(t * 1.8) * 5
	end)
	ui.StoreBadge = Style.badge(storeWrapper, UDim2.new(1, -5, 0, 4), 22)

	gridTile("Pets", "Pets", Style.Icons.Pet, Style.Gradients.Green, 0, 51, function()
		ui.Windows.Pets.Toggle()
	end)
	local rebirthWrapper = gridTile("RebirthOpen", "Rebirth", Style.Icons.Rebirth, Style.Gradients.Blue, 74, 51,
		function()
			ui.Windows.Rebirth.Toggle()
		end)
	ui.RebirthBadge = Style.badge(rebirthWrapper, UDim2.new(1, -1, 0, 7), 22)
	local rebirthPercent = Style.label({
		Parent = rebirthWrapper, Name = "Percent", Text = "0%", TextSize = 14, StrokeThickness = 2.2,
		XAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 12, 0.62, 0), Size = UDim2.new(0, 80, 0, 20), ZIndex = 14,
	})
	rebirthPercent.Rotation = -8

	gridTile("Items", "Items", Style.Icons.Backpack, Style.Gradients.Orange, 0, 126, function()
		ui.Windows.Items.Toggle()
		if callbacks.OnItems then
			callbacks.OnItems()
		end
	end)
	gridTile("Worlds", "Worlds", Style.Icons.World, Style.Gradients.Purple, 74, 126, function()
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
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 98, 1, 4),
	})
	-- dark translucent band behind the trophy row, fading out to the right
	local band = Instance.new("Frame")
	band.Name = "Backdrop"
	band.Size = UDim2.new(0, 230, 0, 42)
	band.Position = UDim2.new(0, 0, 0, 2)
	band.BackgroundColor3 = Color3.new(0, 0, 0)
	band.BackgroundTransparency = 0
	band.BorderSizePixel = 0
	band.ZIndex = 4
	band.Parent = stats
	local bandGrad = Instance.new("UIGradient")
	bandGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	bandGrad.Parent = band
	local bandCorner = Instance.new("UICorner")
	bandCorner.CornerRadius = UDim.new(0, 8)
	bandCorner.Parent = band

	local function statRow(y, icon)
		Style.icon({
			Parent = stats, Image = icon, Size = UDim2.new(0, 46, 0, 46),
			AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 0, 0, y), ZIndex = 6,
		})
		return Style.label({
			Parent = stats, Text = "0", TextSize = 25, Color = Style.White,
			XAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 54, 0, y),
			Size = UDim2.new(1, -54, 0, 46), StrokeThickness = 2, StrokeColor = Color3.fromRGB(60, 30, 0), ZIndex = 6,
			TextGradient = { Color3.fromRGB(255, 214, 40), Color3.fromRGB(255, 140, 0) },
		})
	end
	local trophyLabel = statRow(0, Style.Icons.Trophy)
	local rebirthLabel = statRow(48, Style.Icons.Rebirth)
	local boostLabel = Style.label({
		Parent = stats, Text = "Friend Boost +0%", TextSize = 15, XAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 0, 0, 91), Size = UDim2.new(0, 136, 0, 22), ZIndex = 6, StrokeThickness = 2,
	})
	local plus = Style.button({
		Name = "FriendBoostAdd", Parent = stats, Size = UDim2.new(0, 18, 0, 18),
		Position = UDim2.new(0, 141, 0, 93), Gradient = Style.Gradients.Lime, ZIndex = 6,
		BorderThickness = 2, Shine = false,
		OnClick = function()
			if callbacks.OnInviteFriends then
				callbacks.OnInviteFriends()
			end
		end,
	})
	Style.icon({ Parent = plus, Image = Style.Icons.Plus, NoShadow = true, Size = UDim2.new(0, 11, 0, 11), ZIndex = 9 })

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
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -109, 0.5, 21),
	})
	local quickCount = 0

	-- product = { Name, Price, Gradient, SubText ("PERMANENT!"), ProductId, Icon, Compact }
	-- The 3rd tile (or any with Compact = true) is the narrower/shorter one from the reference.
	function ui.AddQuickBuy(product)
		local y = quickCount * 75
		quickCount += 1
		local compact = product.Compact == true or quickCount == 3
		local btnW = compact and 138 or 150
		local btnH = compact and 38 or 50
		local btn = Style.button({
			Name = "Quick_" .. tostring(product.ProductId or quickCount), Parent = quick,
			Size = UDim2.new(0, btnW, 0, btnH), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -1, 0, y),
			Gradient = product.Gradient or Style.Gradients.Orange, Text = product.Name, TextSize = 22,
			ZIndex = 6, BorderThickness = 2, Shine = false,
			OnClick = function()
				if callbacks.OnPurchase then
					callbacks.OnPurchase(product)
				end
			end,
		})
		btn.ClipsDescendants = false -- the product icon overhangs the top edge
		if product.Icon then
			Style.icon({
				Parent = btn, Image = product.Icon, Size = UDim2.new(0, 54, 0, 54),
				AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -14), ZIndex = 8,
			})
		end
		local row = newFrame({
			Parent = quick, Name = "PriceTag", Size = UDim2.new(0, btnW, 0, 18),
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -1, 0, y + btnH - 4), ZIndex = 8,
		})
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.Padding = UDim.new(0, 3)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = row
		local only = Style.label({ Parent = row, Text = "ONLY", TextSize = 18, Color = GREEN_TEXT, Size = UDim2.new(0, 0, 1, 0), ZIndex = 8 })
		only.AutomaticSize = Enum.AutomaticSize.X
		only.LayoutOrder = 1
		local rb = Style.icon({ Parent = row, Image = Style.Icons.Robux, NoShadow = true, Size = UDim2.new(0, 18, 0, 18), ZIndex = 8 })
		rb.AnchorPoint = Vector2.new(0, 0)
		rb.Position = UDim2.new(0, 0, 0, 0)
		rb.ImageColor3 = GREEN_TEXT
		rb.LayoutOrder = 2
		local price = Style.label({ Parent = row, Text = tostring(product.Price), TextSize = 18, Color = GREEN_TEXT, Size = UDim2.new(0, 0, 1, 0), ZIndex = 8 })
		price.AutomaticSize = Enum.AutomaticSize.X
		price.LayoutOrder = 3
		if product.SubText then
			Style.label({
				Parent = quick, Text = product.SubText, TextSize = 16, Color = YELLOW_TEXT,
				AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -1, 0, y + btnH + 17),
				Size = UDim2.new(0, btnW, 0, 16), ZIndex = 8,
			})
		end
		return btn
	end

	local rewards = scaledHud({
		Parent = gui, Name = "Rewards", Size = UDim2.new(0, 140, 0, 120),
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -236, 0, 44),
	})
	local rewardsBtn = Instance.new("ImageButton")
	rewardsBtn.Name = "RewardsButton"
	rewardsBtn.Size = UDim2.new(0, 140, 0, 120)
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
		Parent = rewardsBtn, Image = "rbxassetid://96888229999409", Size = UDim2.new(0, 76, 0, 76),
		Position = UDim2.new(0.5, 0, 0, 42), ZIndex = 8, NoShadow = true,
	})
	Style.onIdle(gift, function(t)
		gift.Rotation = math.sin(t * 3) * 6
	end)
	local rewardsBadge = Style.badge(rewardsBtn, UDim2.new(0.5, 53, 0, 21), 43, "0")
	rewardsBadge.Text.TextSize = 30
	Style.label({
		Parent = rewardsBtn, Name = "Caption", Text = "REWARDS\nREADY!", TextSize = 21,
		Position = UDim2.new(0, 0, 0, 70), Size = UDim2.new(1, 0, 0, 48), ZIndex = 8, Wrapped = true,
	})
	function ui.SetRewards(count)
		hudExtraVisible[rewards] = count > 0
		refreshHud()
		rewardsBadge.Text.Text = tostring(count)
		rewardsBtn.Caption.Text = string.format("%d REWARD%s\nREADY!", count, count == 1 and "" or "S")
	end

	------------------------------------------------
	-- 4. Bottom bar: damage, level, stat boosts, auto clicker
	------------------------------------------------
	local bottom = scaledHud({
		Parent = gui, Name = "BottomBar", Size = UDim2.new(0, 360, 0, 114),
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -13),
	})
	local multiplierLabel = Style.label({
		Parent = bottom, Text = "Multiplier: 1x", TextSize = 14, Color = YELLOW_TEXT,
		Size = UDim2.new(1, 0, 0, 16), ZIndex = 6,
	})
	local damageLabel = Style.label({
		Parent = bottom, Text = "0 DAMAGE", TextSize = 20, Color = ORANGE_TEXT,
		Position = UDim2.new(0, 0, 0, 16), Size = UDim2.new(1, 0, 0, 26), ZIndex = 6,
	})
	local speedLabel = Style.label({
		Parent = bottom, Text = "Speed: 16", TextSize = 14, Color = Color3.fromRGB(90, 190, 255),
		XAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 0, 0, 25),
		Size = UDim2.new(0, 100, 0, 16), ZIndex = 6,
	})
	Style.icon({
		Parent = bottom, Name = "SpeedIcon", Image = Style.Icons.Shoe, Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(0, -18, 0, 32), ZIndex = 6, NoShadow = true,
	})

	local trough = Instance.new("Frame")
	trough.Name = "LevelBar"
	trough.Size = UDim2.new(1, 0, 0, 28)
	trough.Position = UDim2.new(0, 0, 0, 46)
	trough.BackgroundColor3 = Color3.fromRGB(22, 28, 36)
	trough.BorderSizePixel = 0
	trough.ClipsDescendants = true
	trough.ZIndex = 5
	trough.Parent = bottom
	Style.stroke(trough, 2, Style.Black)
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
		Parent = trough, Text = "LEVEL 1", TextSize = 18, XAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(0.6, 0, 1, 0), ZIndex = 8,
	})
	local maxText = Style.label({
		Parent = trough, Text = "", TextSize = 18, XAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(0.4, -8, 0, 0), Size = UDim2.new(0.6, 0, 1, 0), ZIndex = 8,
	})

	local boostButtons = {}
	local boostGradients = { Style.Gradients.Orange, Style.Gradients.Blue, Style.Gradients.Purple }
	local boostLayout = { { x = 28, w = 90 }, { x = 130, w = 100 }, { x = 240, w = 104 } }
	for i = 1, 3 do
		local cell = boostLayout[i]
		boostButtons[i] = Style.button({
			Name = "StatBoost" .. i, Parent = bottom, Size = UDim2.new(0, cell.w, 0, 32),
			Position = UDim2.new(0, cell.x, 0, 82), Gradient = boostGradients[i],
			Text = "+0", TextSize = 17, ZIndex = 6, BorderThickness = 2, Shine = false,
			OnClick = function()
				if callbacks.OnStatBoost then
					callbacks.OnStatBoost(i)
				end
			end,
		})
		boostButtons[i].ClipsDescendants = false -- the arm icon overhangs the left edge
		boostButtons[i].Label.Position = UDim2.new(0, 30, 0, -1)
		boostButtons[i].Label.Size = UDim2.new(1, -30, 1, 0) -- text sits right of the arm
		Style.icon({
			Parent = boostButtons[i], Name = "Arm", Image = Style.Icons.Muscle, Size = UDim2.new(0, 50, 0, 50),
			Position = UDim2.new(0, 10, 0.5, 0), ZIndex = 7, NoShadow = true,
		})
	end

	-- Auto clicker: paid (rainbow) tile with a free toggle below it.
	local autoState = { Paid = false, Free = false }
	local autoLabels = {}
	local function autoTile(key, props)
		local btn = Style.button({
			Name = props.Name, Parent = bottom, Size = props.Size, Position = props.Position,
			Gradient = props.Gradient, BorderThickness = 2, Shine = false, ZIndex = 6,
			OnClick = function()
				autoState[key] = not autoState[key]
				autoLabels[key].Text = autoState[key] and "ON" or "OFF"
				autoLabels[key].TextColor3 = autoState[key] and GREEN_TEXT or Color3.fromRGB(230, 30, 30)
				if callbacks.OnAutoClicker then
					callbacks.OnAutoClicker(key == "Paid", autoState[key])
				end
			end,
		})
		return btn
	end
	local autoPaid = autoTile("Paid", {
		Name = "AutoClickPaid", Size = UDim2.new(0, 66, 0, 36), Position = UDim2.new(0, 386, 0, 20),
		Gradient = Style.Rainbow,
	})
	autoPaid.Fill.Rotation = 0
	Style.icon({
		Parent = autoPaid, Image = Style.Icons.AutoClick, Size = UDim2.new(0, 36, 0, 36),
		Position = UDim2.new(0.5, 0, 0.4, 0), ZIndex = 8, NoShadow = true,
	})
	autoLabels.Paid = Style.label({
		Parent = autoPaid, Name = "State", Text = "OFF", TextSize = 18, Color = Color3.fromRGB(230, 30, 30),
		Position = UDim2.new(0, 0, 0, 8), ZIndex = 10, StrokeThickness = 2.2,
	})
	Style.label({
		Parent = autoPaid, Name = "Price", Text = "49", TextSize = 11, Color = GREEN_TEXT,
		XAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -3, 0, 1), Size = UDim2.new(0, 30, 0, 12), ZIndex = 10, StrokeThickness = 1.6,
	})
	Style.label({
		Parent = bottom, Name = "AutoCaption", Text = "FREE Auto Clicker", TextSize = 12,
		Position = UDim2.new(0, 366, 0, 66), Size = UDim2.new(0, 106, 0, 14), ZIndex = 8, StrokeThickness = 2,
	})
	local autoFree = autoTile("Free", {
		Name = "AutoClickFree", Size = UDim2.new(0, 66, 0, 32), Position = UDim2.new(0, 386, 0, 80),
		Gradient = Style.Gradients.SlotGrey,
	})
	autoLabels.Free = Style.label({
		Parent = autoFree, Name = "State", Text = "OFF", TextSize = 18, Color = Color3.fromRGB(230, 30, 30),
		ZIndex = 10, StrokeThickness = 2.2,
	})

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
	-- paid / free auto clicker toggles (true = ON)
	function ui.SetAutoClicker(paidOn, freeOn)
		for key, on in pairs({ Paid = paidOn == true, Free = freeOn == true }) do
			autoState[key] = on
			autoLabels[key].Text = on and "ON" or "OFF"
			autoLabels[key].TextColor3 = on and GREEN_TEXT or Color3.fromRGB(230, 30, 30)
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
			Size = UDim2.new(0, 552, 0, 415), Position = UDim2.new(0.5, 0, 0.5, -40),
			Title = "REBIRTH", TitleIcon = Style.Icons.Rebirth, HeaderWidth = 310, HeaderHeight = 60,
			HeaderGradient = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 230, 250)),
				ColorSequenceKeypoint.new(0.55, Color3.fromRGB(66, 160, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(105, 115, 255)),
			}),
			TitleSize = 38, TitleStroke = 2.5, TitleStrokeColor = Color3.fromRGB(20, 40, 110),
			TitleGradient = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 240, 250) },
			CloseSize = 54, ClosePosition = UDim2.new(1, 16, 0, 13),
			PanelTransparency = 0.02,
		})
		local p = w.Panel

		local leftTitle = Style.label({
			Parent = p, Text = "Rebirth 0:", TextSize = 31, StrokeThickness = 2.6,
			Position = UDim2.new(0, 15, 0, 31), Size = UDim2.new(0, 216, 0, 36), ZIndex = 15,
		})
		local rightTitle = Style.label({
			Parent = p, Text = "Rebirth 1:", TextSize = 31, StrokeThickness = 2.6,
			Position = UDim2.new(0, 321, 0, 31), Size = UDim2.new(0, 216, 0, 36), ZIndex = 15,
		})

		local function statCard(x, y, icon, text)
			local t = Style.tile({
				Parent = p, Size = UDim2.new(0, 216, 0, 74), Position = UDim2.new(0, x, 0, y),
				Gradient = Style.Gradients.Orange, ZIndex = 14, BorderThickness = 2.5,
			})
			Style.icon({
				Parent = t, Image = icon, Size = UDim2.new(0, 68, 0, 68),
				Position = UDim2.new(0.5, 0, 0.5, 0), ZIndex = 16, NoShadow = true,
			})
			return Style.label({ Parent = t, Text = text, TextSize = 31, ZIndex = 18, StrokeThickness = 2.6 })
		end

		local dmgNow = statCard(15, 69, Style.Icons.Sword, "X1 Damage")
		local dmgNext = statCard(321, 69, Style.Icons.Sword, "X2 Damage")
		local lvlNow = statCard(15, 153, Style.Icons.Star, "MAX Level 10")
		local lvlNext = statCard(321, 153, Style.Icons.Star, "MAX Level 20")

		for _, y in ipairs({ 69, 153 }) do
			local arrow = Style.label({
				Parent = p, Text = "\u{00BB}", TextSize = 66,
				Color = Color3.fromRGB(235, 248, 255),
				StrokeColor = Color3.fromRGB(110, 185, 235), StrokeThickness = 1.5,
				TextGradient = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 215, 250) },
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0, y + 37),
				Size = UDim2.new(0, 70, 0, 70), ZIndex = 15,
			})
			Style.onIdle(arrow, function(t)
				arrow.Position = UDim2.new(0.5, math.sin(t * 4) * 3, 0, y + 37)
			end)
		end

		local levelBar = Style.tile({
			Parent = p, Size = UDim2.new(0, 528, 0, 49), Position = UDim2.new(0, 12, 0, 239),
			Gradient = Style.Gradients.Orange, ZIndex = 14, BorderThickness = 2.5,
		})
		Style.icon({
			Parent = levelBar, Image = Style.Icons.Star, Size = UDim2.new(0, 38, 0, 38),
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 101, 0.5, 0), ZIndex = 16,
		})
		local levelText = Style.label({
			Parent = levelBar, Text = "Level 10 / Level 10", TextSize = 31, StrokeThickness = 2.6,
			XAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 149, 0, 0), Size = UDim2.new(1, -153, 1, 0), ZIndex = 18,
		})

		local skipBtn = Style.button({
			Name = "SkipRebirth", Parent = p,
			Size = UDim2.new(0, 256, 0, 74), Position = UDim2.new(0, 15, 0, 302),
			Gradient = Style.Rainbow, Text = "SKIP REBIRTH", TextSize = 34,
			ZIndex = 14, BorderThickness = 2.5,
			OnClick = function()
				if callbacks.OnSkipRebirth then
					callbacks.OnSkipRebirth()
				end
			end,
		})
		skipBtn.Fill.Rotation = 0 -- the rainbow runs horizontally, crimson on the left
		-- parented to the panel so it can straddle the button's bottom border (buttons clip their children)
		Style.label({
			Parent = p, Name = "KeepStats", Text = "KEEP ALL STATS!", TextSize = 15,
			Color = Color3.fromRGB(255, 200, 20), XAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0, 15 + 256 - 2, 0, 302 + 74 + 6),
			Size = UDim2.new(0, 150, 0, 16), ZIndex = 22,
		})

		local rebirthAction = Style.button({
			Name = "DoRebirth", Parent = p,
			Size = UDim2.new(0, 256, 0, 74), Position = UDim2.new(0, 282, 0, 302),
			Gradient = Style.Gradients.LimeGreen, Text = "REBIRTH", TextSize = 49,
			ZIndex = 14, BorderThickness = 2.5,
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
		rebirthAction.Label.TextStroke.Thickness = 3.6

		Style.label({
			Parent = w.Frame, Text = "Rebirth resets your Damage, Level, Wins ONLY!", TextSize = 19,
			Color = Color3.fromRGB(255, 40, 40),
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 10),
			Size = UDim2.new(1, 0, 0, 26), ZIndex = 40, StrokeThickness = 2.5,
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
			local g = w.CanRebirth and Style.Gradients.LimeGreen or { Color3.fromRGB(150, 155, 160), Color3.fromRGB(95, 100, 105) }
			rebirthAction.Fill.Color = ColorSequence.new(g[1], g[2])
			ui.SetRebirths(data.Current or 0)
			ui.SetRebirthProgress(math.clamp(level / math.max(required, 1), 0, 1) * 100)
		end
	end

	------------------------------------------------
	-- shared: Equip Best / Unequip All / Delete side buttons
	------------------------------------------------
	local SIDE = 156 -- width reserved left of the panel for the side buttons
	local function sideButtons(w)
		local function sideButton(text, y, gradient, cb)
			local b = Style.button({
				Name = text, Parent = w.Frame,
				Size = UDim2.new(0, 148, 0, 38), Position = UDim2.new(0, 0, 0, y),
				Gradient = gradient, Text = text, TextSize = 23, ZIndex = 20, BorderThickness = 2.5,
				OnClick = function()
					if cb then
						cb()
					end
				end,
			})
			b.Label.TextStroke.Thickness = 2.2
			return b
		end
		sideButton("Equip Best", 71, Style.Gradients.YellowGreen, callbacks.OnEquipBest)
		sideButton("Unequip All", 121, Style.Gradients.Red, callbacks.OnUnequipAll)
		sideButton("Delete", 171, Style.Gradients.Red, callbacks.OnDeletePets)
	end

	------------------------------------------------
	-- 6. Pets window
	------------------------------------------------
	do
		local w = makeWindow("Pets", {
			Size = UDim2.new(0, SIDE + 548, 0, 458),
			-- anchor on the panel centre so the panel itself is centred on screen
			AnchorPoint = Vector2.new((SIDE + 274) / (SIDE + 548), (30 + 190.5) / 458),
			Title = "PETS", TitleIcon = Style.Icons.Pet, HeaderWidth = 300, HeaderHeight = 56, HeaderX = SIDE - 18,
			HeaderGradient = Style.Gradients.Green, PanelTransparency = 0.12,
			PanelColor = Color3.fromRGB(12, 14, 17),
			TitleSize = 38, TitleIconSize = 46, TitleIconX = 6, TitleX = 58, TitleStroke = 2.5,
			TitleGradient = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 250, 205) },
			CloseSize = 55, ClosePosition = UDim2.new(1, 16, 0, 14),
		})
		local panel = w.Panel
		panel.Position = UDim2.new(0, SIDE, 0, 30)
		panel.Size = UDim2.new(1, -SIDE, 1, -77)
		sideButtons(w)

		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "PetGrid"
		scroll.Size = UDim2.new(1, -10, 1, -45)
		scroll.Position = UDim2.new(0, 5, 0, 37)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 8
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.ZIndex = 13
		scroll.Parent = panel
		-- padding so cell borders / hover scale are not clipped by the scroll frame
		local gridPad = Instance.new("UIPadding")
		gridPad.PaddingLeft = UDim.new(0, 5)
		gridPad.PaddingTop = UDim.new(0, 5)
		gridPad.PaddingRight = UDim.new(0, 5)
		gridPad.Parent = scroll
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.new(0, 100, 0, 100)
		grid.CellPadding = UDim2.new(0, 8, 0, 8)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = scroll

		-- footer: backpack capacity + equipped pets
		local footer = Style.tile({
			Name = "Footer", Parent = w.Frame,
			Size = UDim2.new(0, 212, 0, 37), Position = UDim2.new(0, SIDE, 1, -37),
			Gradient = { Color3.fromRGB(70, 78, 88), Color3.fromRGB(40, 46, 54) }, ZIndex = 20, BorderThickness = 2.5,
		})
		footer.BackgroundTransparency = 0.3 -- semi-transparent slate: the world shows through
		Style.icon({ Parent = footer, Image = Style.Icons.Backpack, Size = UDim2.new(0, 30, 0, 30),
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), ZIndex = 24 })
		local capacityLabel = Style.label({ Parent = footer, Text = "0/100", TextSize = 24, StrokeThickness = 2,
			XAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 42, 0, 0),
			Size = UDim2.new(0, 78, 1, 0), ZIndex = 24 })
		Style.icon({ Parent = footer, Image = Style.Icons.Pet, Size = UDim2.new(0, 30, 0, 30),
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 123, 0.5, 0), ZIndex = 24 })
		local equippedLabel = Style.label({ Parent = footer, Text = "0/4", TextSize = 24, StrokeThickness = 2,
			XAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 159, 0, 0),
			Size = UDim2.new(0, 48, 1, 0), ZIndex = 24 })

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
			Size = UDim2.new(0, SIDE + 541, 0, 30 + 381),
			AnchorPoint = Vector2.new((SIDE + 270.5) / (SIDE + 541), (30 + 190.5) / (30 + 381)),
			Title = "ITEMS", TitleIcon = Style.Icons.Backpack, HeaderWidth = 300, HeaderHeight = 58, HeaderX = SIDE - 18,
			HeaderGradient = Style.Gradients.Yellow, PanelTransparency = 0.08,
			PanelColor = Color3.fromRGB(22, 25, 28),
			TitleSize = 38, TitleIconSize = 50, TitleIconX = 4, TitleX = 62,
			CloseSize = 54, ClosePosition = UDim2.new(1, 18, 0, 5),
		})
		local panel = w.Panel
		panel.Position = UDim2.new(0, SIDE, 0, 30)
		panel.Size = UDim2.new(1, -SIDE, 1, -30)
		sideButtons(w)

		-- left: equipped slots on a ring + additional slots
		local left = Instance.new("Frame")
		left.Name = "Loadout"
		left.Size = UDim2.new(0, 250, 1, -34)
		left.Position = UDim2.new(0, 0, 0, 34)
		left.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
		left.BorderSizePixel = 0
		left.ZIndex = 13
		left.Parent = panel
		Style.stroke(left, 2.5, Style.Black)
		local leftRim = Instance.new("Frame")
		leftRim.Name = "Rim"
		leftRim.BackgroundTransparency = 1
		leftRim.Size = UDim2.new(1, -5, 1, -5)
		leftRim.Position = UDim2.new(0.5, 0, 0.5, 0)
		leftRim.AnchorPoint = Vector2.new(0.5, 0.5)
		leftRim.ZIndex = 13
		leftRim.Parent = left
		Style.stroke(leftRim, 2.5, Color3.fromRGB(64, 65, 68))

		local ring = Instance.new("Frame")
		ring.Name = "Ring"
		ring.Size = UDim2.new(0, 172, 0, 172)
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.new(0, 125, 0, 129)
		ring.BackgroundTransparency = 1
		ring.ZIndex = 14
		ring.Parent = left
		local ringCorner = Instance.new("UICorner")
		ringCorner.CornerRadius = UDim.new(1, 0)
		ringCorner.Parent = ring
		Style.stroke(ring, 3, Style.White).Transparency = 0.1

		local innerRing = Instance.new("Frame")
		innerRing.Name = "InnerRing"
		innerRing.Size = UDim2.new(0, 100, 0, 100)
		innerRing.AnchorPoint = Vector2.new(0.5, 0.5)
		innerRing.Position = UDim2.new(0, 125, 0, 129)
		innerRing.BackgroundTransparency = 1
		innerRing.ZIndex = 14
		innerRing.Parent = left
		local innerCorner = Instance.new("UICorner")
		innerCorner.CornerRadius = UDim.new(1, 0)
		innerCorner.Parent = innerRing
		Style.stroke(innerRing, 2.5, Style.White).Transparency = 0.1

		local slotPositions = {
			UDim2.new(0, 125, 0, 53), UDim2.new(0, 57, 0, 156), UDim2.new(0, 193, 0, 156),
		}
		-- white triangle joining the three slot centres
		local function slotLine(name, x1, y1, x2, y2)
			local dx, dy = x2 - x1, y2 - y1
			local line = Instance.new("Frame")
			line.Name = name
			line.AnchorPoint = Vector2.new(0.5, 0.5)
			line.Size = UDim2.new(0, math.sqrt(dx * dx + dy * dy), 0, 3)
			line.Position = UDim2.new(0, (x1 + x2) / 2, 0, (y1 + y2) / 2)
			line.Rotation = math.deg(math.atan2(dy, dx))
			line.BackgroundColor3 = Style.White
			line.BackgroundTransparency = 0.1
			line.BorderSizePixel = 0
			line.ZIndex = 14
			line.Parent = left
		end
		slotLine("LineBottom", 57, 156, 193, 156)
		slotLine("LineLeft", 125, 53, 57, 156)
		slotLine("LineRight", 125, 53, 193, 156)
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
				gradient = Style.Gradients.SlotGrey
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
				Style.label({ Parent = btn, Text = "Empty", TextSize = 18, ZIndex = 20,
					Position = UDim2.new(0, 0, 0.55, 0), Size = UDim2.new(1, 0, 0.45, 0) })
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
				Parent = left, Name = "SlotFrame" .. i, Size = UDim2.new(0, 78, 0, 78),
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
			Parent = left, Text = "Additional Slots:", TextSize = 22,
			Position = UDim2.new(0, 0, 0, 234), Size = UDim2.new(1, 0, 0, 26), ZIndex = 15,
		})
		for i = 1, 3 do
			local unlock = Style.button({
				Name = "Unlock" .. i, Parent = left, Size = UDim2.new(0, 66, 0, 66),
				Position = UDim2.new(0, 12 + (i - 1) * 78, 0, 266), Gradient = Style.Gradients.SlotGrey,
				ZIndex = 16, BorderThickness = 2.5, Shine = false,
				OnClick = function()
					if callbacks.OnUnlockSlot then
						callbacks.OnUnlockSlot(i)
					end
				end,
			})
			unlock:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(255, 170, 0)
			local unlockText = Style.label({
				Parent = unlock, Text = "UNLOCK\nNOW", TextSize = 13, Color = GREEN_TEXT, Wrapped = true,
				Position = UDim2.new(0, 0, 0, 6), Size = UDim2.new(1, 0, 0, 30), ZIndex = 20,
			})
			unlockText.LineHeight = 0.9
			addPrice(unlock, 99, 17, 20, 18)
		end

		-- right: item grid
		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "ItemGrid"
		scroll.Size = UDim2.new(1, -251, 1, -55)
		scroll.Position = UDim2.new(0, 251, 0, 48)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 5
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.ZIndex = 13
		scroll.Parent = panel
		-- 541 - 251 = 290 px wide; minus 4 px left padding = 286, enough for 3 x 90 + 2 x 5 = 280 plus the scrollbar
		local gridPad = Instance.new("UIPadding")
		gridPad.PaddingLeft = UDim.new(0, 4)
		gridPad.PaddingTop = UDim.new(0, 4)
		gridPad.Parent = scroll
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.new(0, 90, 0, 89)
		grid.CellPadding = UDim2.new(0, 5, 0, 5)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = scroll

		local itemColors = {
			Blue = Style.Gradients.Blue, Green = Style.Gradients.Green, Grey = Style.Gradients.ItemGrey,
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
					Name = "Item_" .. tostring(item.Id), Parent = scroll, Size = UDim2.new(0, 90, 0, 89),
					Gradient = itemColors[item.Color or "Grey"] or Style.Gradients.ItemGrey,
					ZIndex = 14, LayoutOrder = i, BorderThickness = 2, Shine = false,
					OnClick = function()
						if callbacks.OnToggleItem then
							callbacks.OnToggleItem(item.Id)
						end
					end,
				})
				Style.icon({ Parent = btn, Image = item.Icon or Style.Icons.Star, Size = UDim2.new(0, 66, 0, 66),
					Position = UDim2.new(0.5, 0, 0.44, 0), ZIndex = 18 })
				local text = item.Name or "Item"
				if item.Count and item.Count > 1 then
					text = text .. "\nx" .. tostring(item.Count)
				end
				local nameLabel = Style.label({ Parent = btn, Text = text, TextSize = 16, Wrapped = true,
					YAlignment = Enum.TextYAlignment.Top,
					Position = UDim2.new(0, 0, 0.5, 6), Size = UDim2.new(1, 0, 0, 40), ZIndex = 20 })
				nameLabel.LineHeight = 0.95
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
			Size = UDim2.new(0, 482, 0, 399), Position = UDim2.new(0.5, 0, 0.5, -6), PanelTop = 65,
			Title = "Worlds", TitleIcon = Style.Icons.World, HeaderWidth = 482, HeaderX = 0, HeaderHeight = 65,
			HeaderGradient = { Color3.fromRGB(170, 250, 25), Color3.fromRGB(125, 220, 10) },
			PanelTransparency = 0.1, PanelColor = Color3.fromRGB(78, 90, 104), PanelStroke = 3, HeaderBorder = 3,
			NoRim = true,
			TitleSize = 44, TitleIconSize = 50, TitleIconX = 4, TitleX = 60, TitleStroke = 3,
			CloseSize = 49, ClosePosition = UDim2.new(1, -6, 0, 7),
		})
		local panel = w.Panel
		panel.Position = UDim2.new(0, 18, 0, 65)
		panel.Size = UDim2.new(1, -36, 1, -65)
		local panelChecker = panel:FindFirstChild("Checkerboard")
		if panelChecker then
			panelChecker:Destroy()
		end

		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "WorldList"
		scroll.Size = UDim2.new(1, 0, 1, -3)
		scroll.Position = UDim2.new(0, 0, 0, 3)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 0
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.ZIndex = 13
		scroll.Parent = panel
		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 3)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = scroll
		local worldPad = Instance.new("UIPadding")
		worldPad.PaddingLeft = UDim.new(0, 15)
		worldPad.PaddingRight = UDim.new(0, 15)
		worldPad.PaddingTop = UDim.new(0, 5) -- room for the 3 px card border
		worldPad.Parent = scroll

		local worldCards = {}

		-- worlds = { { Id, Name, Image (optional rbxassetid), Gradient, Unlocked, Requirement } }
		function ui.SetWorlds(worlds)
			for _, c in ipairs(worldCards) do
				c:Destroy()
			end
			worldCards = {}
			for i, world in ipairs(worlds) do
				local card = Style.tile({
					Name = "World_" .. tostring(world.Id), Parent = scroll, Size = UDim2.new(1, 0, 0, 115),
					Gradient = world.Gradient or Style.Gradients.Blue, ZIndex = 14, LayoutOrder = i,
					BorderThickness = 3, Checker = false, -- scene preview, never a brick pattern
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
					Parent = card, Text = world.Name, TextSize = 33, XAlignment = Enum.TextXAlignment.Left,
					Position = UDim2.new(0, 8, 0, 4), Size = UDim2.new(0.7, 0, 0, 44), ZIndex = 20, StrokeThickness = 3,
				})
				local unlocked = world.Unlocked ~= false
				Style.button({
					Name = "Teleport", Parent = card,
					Size = UDim2.new(0, 148, 0, 42),
					AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, -8),
					Gradient = unlocked and Style.Gradients.Lime or Style.Gradients.Orange,
					Text = unlocked and "Teleport" or (world.Requirement or "Locked"),
					TextSize = unlocked and 25 or 22, ZIndex = 22, BorderThickness = 2.5,
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
			Size = UDim2.new(0, 608, 0, 30 + 424), Position = UDim2.new(0.5, 0, 0.5, 4),
			Title = "SHOP", TitleIcon = Style.Icons.Cart, HeaderWidth = 302, HeaderHeight = 58,
			HeaderGradient = { Color3.fromRGB(255, 238, 45), Color3.fromRGB(255, 138, 22) },
			PanelTransparency = 0.02,
			TitleSize = 42, TitleIconSize = 47, TitleX = 58,
			CloseSize = 56, ClosePosition = UDim2.new(1, 22, 0, 9),
		})

		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "Products"
		scroll.Size = UDim2.new(1, -8, 1, -42)
		scroll.Position = UDim2.new(0, 0, 0, 38)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 5
		scroll.ScrollBarImageColor3 = Color3.fromRGB(120, 76, 4)
		scroll.VerticalScrollBarInset = Enum.ScrollBarInset.None
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
			local row = newFrame({ Parent = scroll, Name = "FeaturedRow", Size = UDim2.new(1, -14, 0, 244), ZIndex = 14 })
			for i, card in ipairs(cards) do
				local tile = Style.tile({
					Name = "Pet_" .. tostring(card.ProductId or i), Parent = row,
					Size = UDim2.new(0, 201, 0, 251),
					AnchorPoint = Vector2.new(i == 1 and 1 or 0, 0),
					Position = UDim2.new(0.5, i == 1 and -15 or 15, 0, 0),
					Gradient = card.Gradient or Style.Gradients.Pink, ZIndex = 15, BorderThickness = 3,
				})
				tile.ClipsDescendants = false -- the pet art spills over the card border
				Style.label({ Parent = tile, Text = card.Name, TextSize = 26, Position = UDim2.new(0, 0, 0, 4),
					Size = UDim2.new(1, 0, 0, 30), ZIndex = 20 })
				Style.label({ Parent = tile, Text = card.Stock or "", TextSize = 21, Color = Color3.fromRGB(214, 36, 62),
					StrokeColor = Color3.fromRGB(120, 10, 40), StrokeThickness = 2.5,
					Position = UDim2.new(0, 0, 0, 43), Size = UDim2.new(1, 0, 0, 24), ZIndex = 22 }) -- above the pet art (18)
				Style.icon({ Parent = tile, Image = card.Icon or Style.Icons.Pet, Size = UDim2.new(0, 236, 0, 206),
					Position = UDim2.new(0.5, -2, 0.5, 17), ZIndex = 18 })
				local footerText = card.Footer or ""
				local plainFooter = string.gsub(footerText, "<[^>]+>", "")
				Style.label({ Parent = tile, Text = footerText, RichText = true, TextSize = #plainFooter > 14 and 18 or 23,
					Color = YELLOW_TEXT, Position = UDim2.new(0, 0, 1, -76), Size = UDim2.new(1, 0, 0, 26), ZIndex = 20 })
				buyButton({
					Parent = tile, Size = UDim2.new(0, 114, 0, 33), AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -14), Price = card.Price, TextSize = 24, ZIndex = 21,
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
				Size = UDim2.new(1, -14, 0, 180), Gradient = Style.Rainbow, ZIndex = 15, BorderThickness = 3,
			})
			card.Fill.Rotation = 10
			Style.onIdle(card, function(t)
				card.Fill.Rotation = 10 + math.sin(t * 1.5) * 4
			end)
			for i, item in ipairs(bundle.Items or {}) do
				local box = Style.tile({
					Parent = card, Size = UDim2.new(0, 121, 0, 121),
					Position = UDim2.new(0, 14 + (i - 1) * 129, 0, 30), Gradient = { Color3.fromRGB(0, 0, 0), Color3.fromRGB(0, 0, 0) },
					ZIndex = 17, BorderThickness = 2.5, Checker = false,
				})
				box.BackgroundTransparency = 0.5 -- translucent black: the rainbow shows through
				Style.icon({ Parent = box, Image = item.Icon, Size = UDim2.new(0, 96, 0, 96),
					Position = UDim2.new(0.5, 0, 0.44, 0), ZIndex = 20 })
				if item.Label then
					Style.label({ Parent = box, Text = item.Label, TextSize = 17, Position = UDim2.new(0, 0, 1, -26),
						Size = UDim2.new(1, 0, 0, 22), ZIndex = 22 })
				end
			end
			Style.label({ Parent = card, Text = bundle.Name or "Bundle", TextSize = 34,
				XAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 0), Size = UDim2.new(0, 150, 0, 80), Wrapped = true, ZIndex = 20, StrokeThickness = 3.4 })
			if bundle.OldPrice then
				local old = newFrame({
					Parent = card, Name = "OldPrice", Size = UDim2.new(0, 150, 0, 30),
					AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -17, 0, 79), ZIndex = 20,
				})
				local oldList = Instance.new("UIListLayout")
				oldList.FillDirection = Enum.FillDirection.Horizontal
				oldList.HorizontalAlignment = Enum.HorizontalAlignment.Right
				oldList.VerticalAlignment = Enum.VerticalAlignment.Center
				oldList.Padding = UDim.new(0, 3)
				oldList.SortOrder = Enum.SortOrder.LayoutOrder
				oldList.Parent = old
				local oldIcon = Style.icon({
					Parent = old, Image = Style.Icons.Robux, NoShadow = true, Size = UDim2.new(0, 24, 0, 24), ZIndex = 20,
				})
				oldIcon.AnchorPoint = Vector2.new(0, 0)
				oldIcon.Position = UDim2.new(0, 0, 0, 0)
				oldIcon.ImageColor3 = Color3.fromRGB(255, 50, 50)
				oldIcon.LayoutOrder = 1
				local oldLabel = Style.label({ Parent = old, RichText = true, Text = string.format("<s>%d</s>", bundle.OldPrice),
					TextSize = 26, Color = Color3.fromRGB(255, 50, 50), Size = UDim2.new(0, 0, 1, 0), ZIndex = 20 })
				oldLabel.AutomaticSize = Enum.AutomaticSize.X
				oldLabel.LayoutOrder = 2
			end
			buyButton({
				Parent = card, Size = UDim2.new(0, 166, 0, 52), AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -8, 1, -13), Price = bundle.Price, TextSize = 30, ZIndex = 21,
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
			local cardHeight = hasButtons and 214 or 168
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
				Style.icon({ Parent = card, Image = crate.Icon, Size = UDim2.new(0, 205, 0, 175),
					AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -2, 0.5, 6), ZIndex = 18 })
			end
			if crate.Footer then
				Style.label({ Parent = card, Text = crate.Footer, TextSize = 31, Color = YELLOW_TEXT,
					XAlignment = Enum.TextXAlignment.Left, AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 8, 1, -21), Size = UDim2.new(0, 230, 0, 34), ZIndex = 21 })
			end

			local slots = crate.Slots or {}
			local n = math.max(#slots, 1)
			local gap = 4
			-- long pet names (Lava Egg) need a taller caption above the tile
			local topH = 16
			for _, slot in ipairs(slots) do
				if #(slot.Top or "") > 9 then
					topH = 36
				end
			end
			local areaY = topH == 16 and 4 or 12
			local areaH = hasButtons and 109 or (cardHeight - areaY - 12)
			local slotArea = newFrame({
				Parent = card, Name = "Slots", Size = UDim2.new(1, -210, 0, areaH),
				Position = UDim2.new(0, 204, 0, areaY), ZIndex = 17,
			})
			local grid = Instance.new("UIGridLayout")
			-- 1 px safety margin: float rounding must never push the last cell onto a new row
			grid.CellSize = UDim2.new(1 / n, -(gap * (n - 1) / n) - 1, 1, 0)
			grid.CellPadding = UDim2.new(0, gap, 0, 0)
			grid.SortOrder = Enum.SortOrder.LayoutOrder
			grid.Parent = slotArea
			for i, slot in ipairs(slots) do
				local cell = newFrame({ Parent = slotArea, Name = "Slot" .. i, Size = UDim2.new(0, 60, 1, 0), ZIndex = 18 })
				cell.LayoutOrder = i
				Style.label({ Parent = cell, Text = slot.Top or "", TextSize = 12, Color = YELLOW_TEXT, Wrapped = true,
					YAlignment = Enum.TextYAlignment.Bottom, Size = UDim2.new(1, 0, 0, topH), ZIndex = 22 })
				local tile = Style.tile({
					Parent = cell, Size = UDim2.new(1, 0, 1, -topH), Position = UDim2.new(0, 0, 0, topH),
					Gradient = slot.Gradient or Style.Gradients.Green, ZIndex = 19, BorderThickness = 2.5,
				})
				if slot.Sub then
					Style.label({ Parent = tile, Text = slot.Sub, TextSize = 12, Size = UDim2.new(1, 0, 0, 14),
						Position = UDim2.new(0, 0, 0, 0), ZIndex = 24, StrokeThickness = 1.8 })
				end
				if slot.Icon then
					Style.icon({ Parent = tile, Image = slot.Icon, Size = UDim2.new(0.82, 0, 0, 44),
						Position = UDim2.new(0.5, 0, 0.46, 0), ZIndex = 22 })
				end
				Style.label({ Parent = tile, Text = slot.Percent or "", TextSize = 18, Size = UDim2.new(1, 0, 0, 22),
					Position = UDim2.new(0, 0, 1, -24), ZIndex = 24, StrokeThickness = 2.6 })
			end

			if hasButtons then
				local bn = #crate.Buttons
				local rowPos, rowSize = UDim2.new(0, 222, 0, 146), UDim2.new(1, -232, 0, 46)
				local function cellGrid(parent)
					local bgrid = Instance.new("UIGridLayout")
					bgrid.CellSize = UDim2.new(1 / bn, -(8 * (bn - 1) / bn) - 1, 1, 0)
					bgrid.CellPadding = UDim2.new(0, 8, 0, 0)
					bgrid.SortOrder = Enum.SortOrder.LayoutOrder
					bgrid.Parent = parent
				end
				local rowF = newFrame({ Parent = card, Name = "Buttons", Size = rowSize, Position = rowPos, ZIndex = 17 })
				cellGrid(rowF)
				-- same grid, drawn above the buttons (which clip their children), holds the struck-through old prices
				local overlay = newFrame({ Parent = card, Name = "OldPrices", Size = rowSize, Position = rowPos, ZIndex = 27 })
				cellGrid(overlay)
				for i, b in ipairs(crate.Buttons) do
					local gradient = i == 1 and Style.Gradients.Yellow or Style.Gradients.Lime
					local btn = Style.button({
						Name = "Open" .. i, Parent = rowF, Size = UDim2.new(0, 100, 1, 0), Gradient = gradient,
						ZIndex = 20, LayoutOrder = i, BorderThickness = 2.5, OnClick = purchase(b),
					})
					local slotHolder = newFrame({ Parent = overlay, Name = "Old" .. i, Size = UDim2.new(0, 60, 1, 0), ZIndex = 27 })
					slotHolder.LayoutOrder = i
					if b.OldPrice then
						local old = newFrame({
							Parent = slotHolder, Name = "OldPrice", Size = UDim2.new(0, 90, 0, 22),
							AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 26, 0, -3), ZIndex = 27,
						})
						local oldList = Instance.new("UIListLayout")
						oldList.FillDirection = Enum.FillDirection.Horizontal
						oldList.HorizontalAlignment = Enum.HorizontalAlignment.Center
						oldList.VerticalAlignment = Enum.VerticalAlignment.Center
						oldList.Padding = UDim.new(0, 2)
						oldList.SortOrder = Enum.SortOrder.LayoutOrder
						oldList.Parent = old
						local oldIcon = Style.icon({
							Parent = old, Image = Style.Icons.Robux, NoShadow = true, Size = UDim2.new(0, 16, 0, 16), ZIndex = 27,
						})
						oldIcon.AnchorPoint = Vector2.new(0, 0)
						oldIcon.Position = UDim2.new(0, 0, 0, 0)
						oldIcon.ImageColor3 = Color3.fromRGB(255, 50, 50)
						oldIcon.LayoutOrder = 1
						local oldLabel = Style.label({ Parent = old, RichText = true,
							Text = string.format("<s>%s</s>", tostring(b.OldPrice)), TextSize = 17,
							Color = Color3.fromRGB(255, 50, 50), Size = UDim2.new(0, 0, 1, 0), ZIndex = 27, StrokeThickness = 2 })
						oldLabel.AutomaticSize = Enum.AutomaticSize.X
						oldLabel.LayoutOrder = 2
					end
					btn.ClipsDescendants = false -- "Open xN" overhangs the bottom edge like the reference
					addPrice(btn, b.Price, 22, 25, -5)
					Style.label({ Parent = btn, Text = b.Text or "Open", TextSize = 15, Size = UDim2.new(1, 0, 0, 16),
						Position = UDim2.new(0, 0, 1, -11), ZIndex = 26, StrokeThickness = 2.2 })
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
				productGrid.CellSize = UDim2.new(0.5, -6, 0, 158)
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
				card.Fill.Rotation = 10
				Style.onIdle(card, function(t)
					card.Fill.Rotation = 10 + math.sin(t * 1.5) * 4
				end)
			end
			Style.icon({ Parent = card, Image = product.Icon or Style.Icons.Star,
				Size = UDim2.new(0, 128, 0, 128), AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 4, 0.48, 0), ZIndex = 18 })
			if product.Tag then
				Style.label({ Parent = card, Text = product.Tag, TextSize = 26, Color = YELLOW_TEXT,
					XAlignment = Enum.TextXAlignment.Left, AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 100, 1, -8), Size = UDim2.new(0, 60, 0, 32), ZIndex = 21 })
			end
			Style.label({ Parent = card, Text = product.Name or "Product", TextSize = 26,
				XAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0, 70, 0, 6),
				Size = UDim2.new(1, -78, 0, 32), ZIndex = 20 })
			Style.label({ Parent = card, Text = product.Description or "", TextSize = 16, Wrapped = true,
				XAlignment = Enum.TextXAlignment.Right, YAlignment = Enum.TextYAlignment.Top,
				Position = UDim2.new(0, 90, 0, 40), Size = UDim2.new(1, -98, 0, 50), ZIndex = 20 })
			buyButton({
				Parent = card, Size = UDim2.new(0, 120, 0, 36), AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -8, 1, -12), Price = product.Price, TextSize = 24, ZIndex = 21,
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
