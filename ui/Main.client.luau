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
	OnAutoClicker = function(paid, on) print("Auto clicker", paid and "paid" or "free", on and "on" or "off") end,
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

-- Worlds (set Image = "rbxassetid://..." to show a scene preview picture; the gradients are muted fallbacks)
ui.SetWorlds({
	{ Id = 1, Name = "World 1", Unlocked = true,
		Gradient = { Color3.fromRGB(140, 190, 215), Color3.fromRGB(95, 150, 70) } },
	{ Id = 2, Name = "World 2", Unlocked = false, Requirement = "Beat World 1",
		Gradient = { Color3.fromRGB(70, 110, 120), Color3.fromRGB(150, 110, 70) } },
	{ Id = 3, Name = "World 3", Unlocked = false, Requirement = "Beat World 2",
		Gradient = { Color3.fromRGB(70, 50, 40), Color3.fromRGB(215, 90, 25) } },
})

-- Shop
ui.AddFeaturedPets({
	{ Name = "Spider Rex", Stock = "799/1K LEFT", Icon = "rbxassetid://104095781189267", Footer = "+3K / Damage",
		Price = 499, Gradient = { Color3.fromRGB(255, 100, 245), Color3.fromRGB(205, 25, 60) }, ProductId = 21 },
	{ Name = "Titan", Stock = "416/1K LEFT", Icon = "rbxassetid://136641367912532",
		Footer = '<font color="#c8102e">ALWAYS</font> <font color="#2a6cff">100%</font> <font color="#c8ff20">BETTER</font>',
		Price = 299, Gradient = { Color3.fromRGB(238, 22, 14), Color3.fromRGB(252, 110, 6) }, ProductId = 22 },
})
ui.AddBundle({
	Name = "Starter Pack", Price = 199, OldPrice = 490, ProductId = 23,
	Items = { { Icon = I.Trophy, Label = "1,5K Wins" }, { Icon = I.Rebirth, Label = "+1 Rebirth" }, { Icon = I.Pet, Label = "Fossil" } },
})
ui.AddHeading("Limited")
ui.AddCrate({
	Name = "Royal Chest", Icon = I.Chest, Footer = "*OP ITEMS!*",
	Slots = {
		{ Top = "+75%", Sub = "All Stats", Icon = I.Trophy, Percent = "50%", Gradient = Style.Gradients.Green },
		{ Top = "+100%", Sub = "All Stats", Icon = I.Star, Percent = "35%", Gradient = Style.Gradients.Yellow },
		{ Top = "+125%", Sub = "All Stats", Icon = I.Heart, Percent = "13%", Gradient = { Color3.fromRGB(255, 75, 125), Color3.fromRGB(240, 20, 80) } },
		{ Top = "+200%", Sub = "All Stats", Icon = "rbxassetid://93317929602850", Percent = "1%", Gradient = { Color3.fromRGB(255, 108, 72), Color3.fromRGB(240, 48, 20) } },
		{ Top = "+500%", Sub = "All Stats", Icon = "rbxassetid://120835265944542", Percent = "0.1%", Gradient = Style.Gradients.Purple },
	},
	Buttons = {
		{ Price = "1.2K", OldPrice = 490, Text = "Open x20", ProductId = 31 },
		{ Price = 199, OldPrice = 490, Text = "Open x3", ProductId = 32 },
		{ Price = 79, Text = "Open x1", ProductId = 33 },
	},
})
ui.AddCrate({
	Name = "Lava Egg", Icon = nil, Sunburst = true, Gradient = { Color3.fromRGB(246, 135, 42), Color3.fromRGB(228, 104, 18) },
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
	Icon = I.Chest, Gradient = { Color3.fromRGB(82, 245, 250), Color3.fromRGB(80, 125, 255) }, ProductId = 44 })
