# Duel Lobby Map (Roblox Studio)

One server Script that builds a Halloween duel lobby floating on the sea, built from parts (no assets).

- Checkered wooden deck in turquoise water, snowy rocks around it, a fence with lamps, dead trees and pumpkins.
- 12 duel tables with 2 seats and a 6-seat **PARTY** table. Each shows how many seats are taken (`0/2`, `1/6`...), red when full.
- 4 leaderboards on the right edge: **TOP WINS**, **TOP STREAKS**, **TOP CASH**, **TOP ROBUX**. They save between sessions and rank players across all servers, refreshing every 60 seconds. Without saving (Studio with API access off) they rank the players in the current server.
- Decorative booths (Daily Spins with a wheel, Free Rewards, Cosmetics), swings, and a stage with a title sign at the back.

## Paste steps

1. Explorer: hover **ServerScriptService**, click **+**, pick **Script**, rename it `LobbyMapServer`.
2. Delete the default line, paste in all of [`LobbyMapServer.lua`](LobbyMapServer.lua).
3. Press **Play**. You spawn at the front of the deck.

The script hides a part named `Baseplate` so the sea shows (set `HideBaseplate = false` to keep it) and turns off other SpawnLocations.

To save stats and fill the boards across servers: publish the place and turn on **Game Settings > Security > Enable Studio Access to API Services**.

## Changing things

`CONFIG` at the top: `Title` (the sign), `Origin` (where the deck sits), `DeckSize`, `DeckHeight`, `BoardRefresh`.

## Using the stats from your game

Each player gets `leaderstats.Wins`, `leaderstats.Streak`, `leaderstats.Cash` (shown in the player list) and `HiddenStats.RobuxSpent`. Change them from your other scripts, for example `player.leaderstats.Wins.Value += 1` when someone wins a duel, or add the Robux price in your purchase handler. The boards pick up the new values on the next refresh, and they save when the player leaves.

Booths, the wheel and the swings are decoration for now.

Not run in Studio yet: checked by compiling and by running the script against a fake Roblox engine.
