# Pet-simulator style UI

Roblox UI modules in the style of the reference screenshots, built on the Check-UI rules
(`.claude/skills/check-ui-clean-roblox`): GothamBlack text with black outlines, thick black borders,
gradient tiles with a faint checkerboard, center-anchored hover/press scaling, responsive `UIScale`.

Screens: main button grid (Store/Pets/Rebirth/Items/Worlds with "!" badges), currency HUD
(trophies, rebirths, friend boost), Rebirth, Pets and Shop windows.

## Studio setup
`StarterPlayer > StarterPlayerScripts > GameUI` (Folder) containing:
- `Main` (LocalScript) from `Main.client.luau`
- `GameUI` (ModuleScript) from `GameUI.luau`
- `Style` (ModuleScript) from `Style.luau`

`Main` uses placeholder data. Replace its callbacks (`OnRebirth`, `OnPurchase`, ...) with your own
remotes, and use `ui.SetTrophies`, `ui.SetRebirthData`, `ui.SetPets`, `ui.AddProduct`, etc. to push real data.

Not tested in Studio; the files pass `luau-analyze` syntax checks only.
