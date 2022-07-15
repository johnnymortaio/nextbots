# Nextbots for GMod

This repo contains some custom [Nextbots](https://wiki.facepunch.com/gmod/NextBot_NPC_Creation), which are described below.
Moreover, here you can find the documented steps to make your own bot.

![Stalin's Nextbot](https://i.giphy.com/media/TfrRHDgovbCqiQZfWk/giphy.webp)

## Disclaimer and Attributions

I do not own this code, I just edited some existing one.

The bots code in this repository comes from a chain of copy-🍝: the most ancient link I managed to find is the [Sanic Hegehog](https://steamcommunity.com/sharedfiles/filedetails/?id=174117071) bot.

You are free to copy-🍝 this code as well.

## Features

### Joseph Vissarionovich Stalin

This bot does pretty much the same things that most simple bots out there already do.
But smiling when sending you to the gulag.

  * Hides in blind spots waiting for a player to enter his search area
  * Makes the player enjoy a [Red Army Choir masterpiece](https://www.youtube.com/watch?v=zgKazTrhXmI) while approaching
  * Chases the player until death by kicking you to the gulag occurs

### FARAOH and Nemesis

Same features as Stalin's Nextbot, but with an animated texture and multiple sounds shouted while chasing.

### Cursed Pingu

This one is cursed.

Do not try it.

![Noot noot](https://media1.giphy.com/media/mVV95S4e083h4HeGBr/giphy.gif?cid=790b7611c64ede89f31888d62ebfb4532455f785c55642f2&rid=giphy.gif&ct=g)

## Development

### Setup

  * Install Visual Studio Code and add "GLua Enhanced (Garry's Mod/Gmod Lua)" extension
  * Install GIMP
  * Install GIMP [VTF plug-in](https://github.com/Artfunkel/gimp-vtf/releases) (unpack the content in `C:\Users\<user>\AppData\Roaming\GIMP\<version>\plug-ins\`)
  * Install [GMPublisher](https://github.com/WilliamVenner/gmpublisher/releases)

### Edit an existing bot

  * Copy Stalin's folder to the GMod addons folder (Game local files > `garrysmod\addons\`), then rename it to something like `dev_nextbot` and open that folder with VS Code
  * Press `Crtl+Shift+H` and replace all `stalin` occurrences to your bot `<name>`
  * Rename also all occurrences of `stalin` in all file and folder names
  * Open `materials\npc_<name>\<name>.vtf` with GIMP and replace that smiling dictator with something of your choice (maybe another smiling dictator)
  * Do the same for file `materials\entities\npc_<name>.png`
  * Replace sounds in `sound\npc_<name>` (NOTE: max supported sample rate is 44100Hz, 48000Hz won't work in Source engine):
    * `panic.mp3` it's the looping music played when the bot is close to a player
    * `taunt.mp3` is played when the bot kills a player
    * `jump.mp3` is pretty clear
  * Edit the file `lua\entities\npc_<name>.lua`:
    * change the bot in-game name editing the line starting with `language.Add`, replacing it with `language.Add("npc_<name>", "<your bot pretty name>")`
    * locate the line starting with `local workshopID` (you must replace the number with the one that Steam assigns to your bot, but you haven't got it yet)

### Testing

You are now able to test your bot within GMod.

Be sure that everything is working fine before going to the final step.

### Deploy

Open GMPublisher and follow the instructions to publish your bot (select the folder, the splash image, the item name and some tags, then publish it).
The tool will open the workshop page containing your item.

Now you have to perform some final steps:

  * edit the `local workshopID` variable mentioned before with the new workshop ID (the last number contained in the workshop URL)
  * use GMPublisher to update the edited file
  * on the workshop page, change your item visibility (hidden by default) and add a description and some screenshots of your creation

## Enjoy

![Off to gulag now](https://c.tenor.com/ZT28EZnoYEwAAAAC/off-to-gulag-gulag.gif)
