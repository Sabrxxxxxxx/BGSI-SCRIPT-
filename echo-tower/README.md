# Echo Tower (Roblox Studio)

A co-op time-loop puzzle climb. Everything is built from parts by the scripts, so you don't need any models, decals, sounds or other assets.

## How it plays

- Every floor is a neon corridor of **gates**: walls that slide down, or bridges that appear over a void. A gate only opens while its **glowing plate** (same color) is being stood on.
- Everyone in the server shares one **32 second loop**. When it ends, everybody goes back to the start.
- Press **E** to **save your run as an echo**. Next loop a ghost of you repeats that exact run, standing on the plate for you, while you walk through the gate.
- Stack echoes: echo 1 holds gate 1 so echo 2 can reach plate 2, and so on. The last run is yours, straight to the **exit portal**.
- Later floors have more gates and gates that need **two plates** held at once. A floor never needs more plates than the players in the server can cover with their echoes (4 each), so it can always be solved, solo or in a group.
- A run starts with 2:30 on the clock and every cleared floor adds 35 seconds. When the clock hits zero the run ends and everyone starts again at floor 1.
- Falling into a gap sends you back to the start of the floor.

**Controls:** `E` save echo and restart the loop, `R` retry (discard) and restart, `Q` undo your last echo. On touch there are buttons on the right edge, on gamepad `X`, `Y` and `L1`. The loop restarts early when every player has pressed E or R.

## Paste steps

1. In the Explorer, hover over **ServerScriptService**, click **+**, choose **Script**, name it `EchoTowerServer`, delete the default line and paste in [`EchoTowerServer.lua`](EchoTowerServer.lua).
2. Open **StarterPlayer**, hover over **StarterPlayerScripts**, click **+**, choose **LocalScript**, name it `EchoTowerClient` and paste in [`EchoTowerClient.lua`](EchoTowerClient.lua).
3. Press **Play** (or **Start** with 2 players in the Test tab to try co-op).

It has to be a **Script** on the server and a **LocalScript** on the client, or nothing happens. You can leave the default baseplate: the tower is built 600 studs in the air, far from it, and the script turns off any other SpawnLocation so everyone spawns on the tower.

To keep best-floor scores between sessions, publish the place and turn on **Game Settings > Security > Enable Studio Access to API Services**. Without it the game still works, scores just don't save.

## Tuning

Everything is in `CONFIG` and `SHAPE` at the top of `EchoTowerServer`:

| Setting | What it does |
| --- | --- |
| `LoopLength` | Seconds per loop. Longer makes room for more complex runs. |
| `MaxEchoesPerPlayer` | Echo slots per player. This also decides how hard floors can get for a given number of players. |
| `MaxSegments` | Most gates on one floor. |
| `StartTime`, `ClearBonus`, `MaxTime` | The run clock. |
| `ArenaOrigin` | Where the tower is built. |
| `SHAPE.Approach`, `SHAPE.Gap` | Length of the platform before each gate, and the size of the gate zone. |

## What was tested, and what wasn't

Tested outside Roblox:

- Both scripts compile as Luau.
- The puzzle logic (floor generator, plate and gate rules, echo recording and playback): 4,800 generated layouts for 1 to 8 players are valid, and 150 floors were solved by a simulated solo player using only echoes, the slowest run taking 11.4 s of the 32 s loop. A runner with no echoes is correctly blocked at the first gate, and two-plate gates need both plates.
- The network format for echoes: a 32 second echo is about 2.5 KB and decodes to within 0.025 studs.

**Not tested: the game has not been run in Roblox Studio.** I couldn't launch Studio here, so the building, physics, HUD and animation code is checked by reading, not by playing. Expect to fix small things on the first playtest, and tell me what the Output window says if anything errors. The first things to check are the gates sliding and bridges appearing, the HUD layout on a phone-sized emulator, and how the echo ghosts look and move.

## Known limits

- No sounds, because Roblox audio needs asset IDs from your own game.
- Echoes are ghosts: they don't collide with anything and only press plates.
- If players leave a server and the floor now needs more plates than the remaining players can cover, use **NEW LAYOUT** (costs 15 seconds on the clock).
- There is one shared run per server. Joining mid-loop means you start recording from the next loop.

## Ideas for later

More gate types (laser sweeps, timed switches, lifts), a daily seeded tower with a global leaderboard, cosmetic ghost trails and avatar skins, and a hard mode where your echoes can also be blocked by gates.
