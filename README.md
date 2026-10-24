# STCampfireSync

A small example of the **Skyrim Together Plugin API**: a plugin that syncs its own state to the party through
Skyrim Together (ST), with no ESP and no Papyrus. It is deliberately simple. The whole thing is
[`src/main.cpp`](src/main.cpp).

Press a hotkey to place a campfire in front of you. Everyone in your party sees it. Press the hotkey while facing
a campfire to pick it up, yours or anyone else's.

## What it shows

| API feature | Where it is used |
| --- | --- |
| `SkyrimTogetherRequestPluginAPI` lookup, staying inactive without ST | `SKSEPluginLoad` |
| `RegisterChannel` with a message and a party callback | `SKSEPluginLoad` |
| `Send` to the party | placing and picking up (`OnHotkey`) |
| `SendTo` one member (late joiners) | `OnPartyChanged`, `joined=true` |
| Party-change callbacks (leave, disconnect) | `OnPartyChanged`, `joined=false` |
| Callbacks are not on the main thread | both callbacks only validate and queue with `SKSE::GetTaskInterface()->AddTask` |
| Untrusted payloads | `HandleMessage` rejects anything that is not exactly `place` / `remove` with numeric fields |

### The protocol

Two text Mod Messages on the channel `DJL.CampfireSync` (well under the 256 byte limit):

```
place <id> <x> <y> <z> <rotZ>
remove <id>
```

`<id>` is a random 32-bit number picked by the placer. It deliberately does **not** contain a player ID: Skyrim
Together hands out a new player ID on every connection, while a campfire outlives a reconnect. Instead, each
remote copy remembers its owner, which is the Sender that ST stamped on the latest `place` for it. When a placer
reconnects and re-announces their campfires, the owner moves to their new ID, so their copies are still removed
when they leave. A `place` for one of your own campfires is ignored.

### Behavior

- **Place / pick up:** the hotkey picks up the nearest known campfire within 300 units and 30 degrees of where you
  face. If there is none, it places a new one 150 units in front of you.
- **Receive:** `place` spawns a remote copy, `remove` deletes it (an unknown ID is fine).
- **Late join:** when a player joins your party you `SendTo` them one `place` per campfire you placed and still have.
- **Leave:** when a player leaves, their remote copies are deleted. When you leave the party or disconnect, all
  remote copies are deleted.
- **Saves:** campfires last one game session. Every campfire, your own included, is flagged so it is never
  written to a save (`TESForm::inGameFormFlags` bit `0x80`, which makes `TESObjectREFR::CheckSaveGame` return
  false). A saved campfire would come back after a reload without the plugin knowing about it: nobody else would
  see it, and the hotkey would stack a new one on top. Persisting them properly needs SKSE's co-save, which this
  example leaves out.

## Build

Requires xmake, MSVC and a [CommonLibSSE-NG](https://github.com/CharmedBaryon/CommonLibSSE-NG) checkout next to
this repo (`../CommonLibSSE-NG`; edit the `includes` line in `xmake.lua` otherwise).

```sh
xmake f -m release -y
xmake -y
```

The output is `build/windows/x64/release/STCampfireSync.dll`. It uses Address Library, so it is not tied to one game
version.

`include/SkyrimTogetherAPI.h` is the public ST header, copied unchanged.

## Try it

1. Install the DLL as `Data/SKSE/Plugins/STCampfireSync.dll`, and optionally `STCampfireSync.ini` next to it.
   Install it on **every** client; the plugin is the other half of its own protocol.
2. Run two clients against the same server and put them in a party.
3. Stand in the same spot on both, press **F8** on one. The campfire appears on both.
4. Press F8 on the *other* client while facing it. It disappears on both.
5. Place one, then have a third client join the party. It sees the campfire.
6. Check `Documents/My Games/Skyrim Special Edition/SKSE/STCampfireSync.log`. Without ST it says it is inactive.

## Config (`STCampfireSync.ini`)

- `HotkeyScanCode`: DirectInput scan code. Default `66` (F8).
- `CampfireBaseFormID`: the form to place. Default `0x00035F49`, Skyrim.esm `Campfire01Burning`.

## Limits

This is an example, not a polished mod.

- Positions are sent without a cell, so it assumes the party is in the same cell or worldspace. A copy placed
  for a player in another place appears at those coordinates in *your* cell.
- Campfires do not survive a save and reload (see **Saves** above).
- Copies are not rebuilt when a cell resets, and rotation is applied on a best-effort basis.
