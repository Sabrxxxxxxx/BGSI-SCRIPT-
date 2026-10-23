# Halloween Portal (Roblox Studio)

A glowing build spot appears near your spawn with a **Press E to build** prompt.

- **Build:** pressing E makes the portal build itself. Stone ring pieces burst out of the ground one by one, land, flash, and light up orange and purple. Then the middle swirls open.
- **Travel:** walking into the portal zooms the camera into it. The screen swirls purple and orange, fades to black, then fades back in on the Halloween island with a big **Halloween World** title.
- **Ghosts:** see-through ghosts drift and bob around the island and the portal, slowly waving their arms.
- **Pumpkins:** jack-o'-lanterns with carved glowing faces bounce, wobble and flicker like candles.

You don't need any models, decals or other assets. Everything is built from parts by the scripts.

## Paste steps

1. **Server script**
   - In the Explorer, hover over **ServerScriptService**, click **+** and pick **Script**.
   - Rename it `HalloweenPortalServer`.
   - Delete the `print("Hello world!")` line and paste in everything from [`HalloweenPortalServer.lua`](HalloweenPortalServer.lua).
2. **Client script**
   - In the Explorer, open **StarterPlayer**, hover over **StarterPlayerScripts**, click **+** and pick **LocalScript**.
   - Rename it `HalloweenPortalClient`.
   - Delete the starter line and paste in everything from [`HalloweenPortalClient.lua`](HalloweenPortalClient.lua).
3. Press **Play**. The glowing pad is about 40 studs in front of your SpawnLocation. Walk onto it, press **E**, wait for the portal to open, then walk into it.

It must be a **Script** in ServerScriptService and a **LocalScript** in StarterPlayerScripts. If you swap them, nothing happens.

## Changing things

The `CONFIG` table at the top of `HalloweenPortalServer` controls the main settings:

| Setting | What it does |
| --- | --- |
| `BuildSpotDistance` | How far in front of the spawn the build pad appears. |
| `IslandCenter` | Where the Halloween island floats. The default is high up and 3000 studs away. Move it if your map is that big. |
| `WorldTitle` | The title shown when you arrive. |
| `PortalRadius`, `RingPieces` | Portal size and how many ring pieces fly in. |
| `PieceDelay`, `FlyTime`, `LightTime`, `OpenTime` | Build animation timing in seconds. |
| `IslandGhosts`, `IslandPumpkins`, `PortalGhosts` | How many ghosts and pumpkins to spawn. |

**Choose the build spot yourself:** add a small Part named `PortalBuildSpot` to Workspace. Place it on the ground and turn its front face toward where players walk in from. The script hides it and builds the pad there. The portal goes up just behind the pad.

**Use your own island:** add a Part named `HalloweenSpawn` where players should land. The script then skips building its own island and lands players on top of that part. It also scatters ghosts and pumpkins around it.

## Good to know

- **Getting back:** there's no return portal yet. Players get back to spawn by resetting their character (Esc, then R) or by jumping off the island.
- **One portal per server:** once someone builds it, it stays built for everyone in that server.
- **Sounds:** no sounds are included, because Roblox audio needs asset IDs from your own game.
- **Faraway animations pause:** ghosts and pumpkins more than 350 studs from your camera stop moving to save performance.
- **StreamingEnabled:** works on or off. The island loads around a player just before they arrive.
