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
