# Duel Lobby Map (Roblox Studio)

A Halloween duel lobby floating on the sea, built from classic studded bricks (no assets). The only text anywhere is the names and numbers on the leaderboards.

- **Deck:** checkered deck in turquoise water, snowy rocks around it, a fence with flickering lamps and chasing string lights, dead trees, pumpkins, bats circling overhead. Every part is plastic with studs on top.
- **You can't leave:** invisible walls stand on the fence line, with a ceiling on top. Anyone who still ends up outside or in the sea is put back at spawn.
- **Tables:** 12 two-seat duel tables and a 6-seat party table (purple rim). A light in front of each seat turns green and pulses when someone sits, and the rim glows orange when the table is full.
- **Leaderboards:** 4 boards on the right edge marked by spinning brick icons: trophy (wins), flame (streaks), cash stack (cash), Robux hexagon (Robux spent). They save and rank players across all servers.
- **Winner statues:** the top 3 players by wins stand on the stage as their real avatars, under a gold light beam.
- **Daily spin:** hold E at the wheel booth. The big wheel spins and lands on a cash prize (50 to 2,500, big prizes rarer), once every 24 hours.
- **Free gift:** hold E at the gift booth for 250 cash, every 10 minutes.
- **Cosmetics:** press E at the top-hat booth to cycle glowing trails: orange, purple-blue, rainbow, off.
- **Trampolines:** two near the front launch you into the air.
- **Feedback without words:** confetti bursts on rewards; the booth icon flashes red when it isn't ready yet. Prompts show only the key.

## Paste steps

1. **Server:** Explorer, hover **ServerScriptService**, click **+**, pick **Script**, rename it `LobbyMapServer`, delete the default line, paste in all of [`LobbyMapServer.lua`](LobbyMapServer.lua).
2. **Client:** expand **StarterPlayer**, hover **StarterPlayerScripts**, click **+**, pick **LocalScript**, rename it `LobbyMapClient`, paste in all of [`LobbyMapClient.lua`](LobbyMapClient.lua).
3. Press **Play**. You spawn at the front of the deck.

The script hides a part named `Baseplate` so the sea shows (set `HideBaseplate = false` to keep it) and turns off other SpawnLocations.

To save stats and the daily spin, and fill the boards across servers: publish the place and turn on **Game Settings > Security > Enable Studio Access to API Services**.

## Changing things

`CONFIG` at the top: `Origin` (where the deck sits), `DeckSize`, `DeckHeight`, `BoardRefresh`, `SpinRewards` and `SpinWeights`, `SpinCooldown`, `GiftReward`, `GiftCooldown`, `WallHeight`. Trampoline power is `BOUNCE` at the top of the client script.

## Using the stats from your game

Each player gets `leaderstats.Wins`, `leaderstats.Streak`, `leaderstats.Cash` (shown in the player list) and `HiddenStats.RobuxSpent`. Change them from your other scripts, for example `player.leaderstats.Wins.Value += 1` when someone wins a duel, or add the Robux price in your purchase handler. The boards pick up the new values on the next refresh, and they save when the player leaves.


Not run in Studio yet: checked by compiling and by running the script against a fake Roblox engine.
