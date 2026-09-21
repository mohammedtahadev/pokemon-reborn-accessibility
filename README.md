# Pokémon Reborn Accessibility Add-ons

Add-ons for blind players of [Pokémon Reborn](https://www.rebornevo.com/pr/index.html/), built on top of **Lorenzo's [pkreborn-access](https://github.com/fclorenzo/pkreborn-access)** mods and Reborn's own Blindstep accessibility.

Three things are in this pack:

- **A 3D audio beacon.** Pick any door, person, item or exit from the pathfinder's list, press **Shift+B**, and a sound placed in real 3D space (Valve's Steam Audio) guides you there, step by step, along the actual walkable route around walls. It pauses by itself during battles.
- **Spoken damage.** After every hit in battle you hear exactly how much damage was dealt and how much HP is left.
- **An improved version of Lorenzo's pathfinder** (`pra-pathfind.rb`) that is much faster on big, busy maps, and that the beacon needs.

The beacon and spoken damage are independent. If you only want spoken damage, you can copy just `SpokenDamageAccessibility.rb`; it works without Lorenzo's mods.

## Requirements

- **Pokémon Reborn 19.5**, with Blindstep turned on (the password "blindstep" when the game asks for special instructions).
- **Lorenzo's pkreborn-access mods**, installed as his README describes. You need at least `pra-pathfind.rb`. His accessible summary and auto walk (`pra-walk.rb`) work alongside this pack as usual.
- **Windows**, and a screen reader. Speech goes through Reborn's own text-to-speech.
- Headphones, for the 3D beacon.

## Installation

1. First install Lorenzo's mods, following [his installation guide](https://github.com/fclorenzo/pkreborn-access#installation). You will end up with a `Mods` folder inside your game's `patch` folder.
2. Download this pack: activate the **Code** button on this page, then **Download ZIP**, and extract it.
3. Copy the `patch` folder from this pack into your Reborn game folder (the one that contains `Game.exe`), merging when Windows asks. When asked about `pra-pathfind.rb`, choose to **replace** it. This pack's version is Lorenzo's pathfinder with the improvements below.
4. Start the game, open the pause menu, choose **Options**, then **Accessibility**, and set **Directional Beacon** to **On**.

Do not rename any of the files. Reborn loads mods in alphabetical order.

## How to use the beacon

1. On any map, press **J** and **L** to scroll the pathfinder's list of things on the map: doors, people, items, exits. **K** repeats the selected one.
2. Press **Shift+B**. You hear "3D beacon tracking" and the target's name.
3. Walk toward the sound. It always points at your **next step** along the real route, not in a straight line through walls, and it gets louder as you get closer.
4. When you reach the target, a chime plays and you hear "Arrived". Press **Shift+B** again at any time to stop.

The sound works like a compass fixed to the screen: north on the map is always in front of you, south always behind (lower in pitch and muffled), east on your right and west on your left. It does not turn with your character.

If there is no walkable route from where you are standing, you hear "No path to the beacon target from here" once. The beacon tries again after you move.

**P** still does what it does in Lorenzo's pack: it walks you to the target, or gives directions. In this version, P and the beacon use the same route search, so if the beacon can guide you somewhere, P can take you there.

## Spoken damage

In battle, every time a Pokémon loses HP, you hear the exact damage and what is left:

- "Garchomp took 84 damage. 102 HP left." (your own Pokémon)
- "The foe's Rattata took 30 damage and fainted." (a trainer's Pokémon; wild ones are "The wild Rattata")

It covers damage from any source: moves, recoil, poison, burns, weather, hazards. Spoken damage is on by default. To turn it off, open the pause menu, choose **Options**, then **Accessibility**, and set **Spoken Damage** to **Off**.

## What is improved in the pathfinder

All of these are changes to Lorenzo's `pra-pathfind.rb`, listed at the top of the file as the GPL requires.

- **Big maps no longer freeze or crawl.** To find a map's exits and the names of door destinations, the event scan used to *load* the neighbouring maps into the game, and the game then kept those maps running in the background. On a large map with many doors, that meant a freeze when you arrived and a slower game afterwards. Names now come from the game's map list and exits from its connection table, and nothing extra is loaded. On Rhodochrine Jungle, entering the map used to trigger 580 of those loads; now it triggers none.
- **Route searching is faster.** The search keeps its bookkeeping in hash tables and looks up only the events on the tile it is checking, instead of scanning every event on the map for every tile. On Reborn's busiest map it does the same work in about half the time.
- **Identical results.** The old and new pathfinder were run side by side on real Reborn maps: they list the same events and find exactly the same routes.
- **P and the beacon agree.** Both now use one route search. When the target tile itself cannot be stepped on, it tries the target's approach sides and then every tile around it.
- **Standing on an exit no longer breaks navigation.** Previously, standing on a map-connection tile made every direction look blocked.
- **No wasted work in the search loop.** A debug string built from the whole search list on every step is gone.

## The beacon is quiet or uses beeps

The beacon writes what happened to `beacon_error.txt` in the game folder. The 3D sound needs three files from this pack: `patch\lib\beacon.dll`, `patch\lib\phonon.dll` and `patch\audio\beacon.wav`. If any is missing, the beacon falls back to Reborn's directional footstep sounds.

You can use your own beacon sound: replace `patch\audio\beacon.wav` with a short **WAV** or **MP3** file. A mono sound gives the clearest 3D positioning. OGG files are not supported by the beacon's audio engine.

## For developers

- `patch/Mods/pra-beacon.rb` is the beacon: target selection, route following, battle pause, and the fallback sounds.
- `patch/Mods/SpokenDamageAccessibility.rb` is spoken damage. It wraps the battler's `pbReduceHP` and the move's `pbReduceHPDamage`, and speaks the HP that actually changed.
- `beacon_src/` holds the C source of `beacon.dll`, a small wrapper around [Steam Audio](https://valvesoftware.github.io/steam-audio/) and [miniaudio](https://miniaud.io/). `BUILD.txt` explains how to rebuild it.

## Credits

This pack would not exist without **Lorenzo ([fclorenzo](https://github.com/fclorenzo))** and his [pkreborn-access](https://github.com/fclorenzo/pkreborn-access) project. The pathfinder, the event scanner and the list of map targets that the beacon guides you to are his work. This pack's `pra-pathfind.rb` is his file with the improvements listed above, and it remains under his license. If you enjoy this, go star his repository too.

The 3D beacon and spoken damage are by **Mohammed Taha** ([mohammedtahadev](https://github.com/mohammedtahadev)).

Thanks also to the **Pokémon Reborn team** for the game and for Blindstep, its built-in accessibility support.

The 3D beacon uses [Steam Audio](https://valvesoftware.github.io/steam-audio/) by Valve (`phonon.dll`, Apache License 2.0) and [miniaudio](https://miniaud.io/) by David Reid.

## License

GNU General Public License v3.0, the same license as Lorenzo's pkreborn-access, because this pack contains a modified version of his pathfinder. See [LICENSE](LICENSE).

This is a fan-made accessibility project. It is not affiliated with the Pokémon Reborn team, Nintendo, Game Freak or The Pokémon Company. No game files are included.
