# Avorion Auto Research

Avorion mod to allow the user to automatically research items saving lots of clicks

Before:

![](https://i.imgur.com/2wXhc5l.png)

After:

![](https://i.imgur.com/icmnhPe.png)

## Features

* Will not remove favorited items! Research without worry :)
* Allows you to limit how high of rarity it will auto-research items (capped at Exceptional since I didn't want people accidently making all their exotics into one legendary, you can add it if you want!)
* Allows you to select all systems or specific ones
* Will research from lowest to highest, so only one click needed!


## Install

Backup your "Steam\steamapps\common\Avorion\data\scripts\entity\merchants\researchstation.lua" file

Download the latest release from https://github.com/draconb/avorion-autoresearch/releases and unzip it or just download the lua script and place it in "Steam\steamapps\common\Avorion\data\scripts\entity\merchants\researchstation.lua".

It will replace the existing researchstation.lua file in there, so make sure to back it up.

## Usage

Fly to research station (found at faction "home" sectors and randomly through the galaxy)

Select MAX item rarity to research (capped at Exceptional so you don't research away your exotics!)

Select the system or leave it at All

Click on "Auto Research", it will disable the button and re-enable once completed. Depending on how many items you might have quite a delay on the right side of the screen of it showing the added/removed items.

## Uninstall

To uninstall, replace the file with the original one you backed up, or verify files in steam (will remove all mods!)

## Requirements

Needs to be installed on both **client and server**.


## Known issues

* Some systems don't properly combine if they have differing attributes, the names are different so they don't get grouped together.

## TODO

* Add extra UI space for placing the minimum required. Currently only researches if 5 are available (for 100% success).
* Add auto researching for weapons as well? Have to determine how and also need custom UI for the options.
