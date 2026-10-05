# Bronzeman Mode
## Different ways of obtaining items
### Killing an NPC, dropping an item
This would be easy to solve if they add something similar like groundItem.getOwnership(), combined with the already existing objStackEntityAddedEvent
### Killing an NPC, opening an interface
This is a common way of giving loot from bosses, like Telos interface or Zamorak chest. Once claimed, these items will simply go into the bank or the inventory.
### Skilling
The item usually goes directly into your inventory, alternatively banked instantly with a porter. If something similar to onItemContainerChanged event exists, this is no problem.
### Banking
This isn't really a way to obtain items, but when the plugin is installed there will probably be items in the bank, and if the plugin has
missed any items then by simply opening the bank it will add any missing items to the list. This solves
the porter and interface issues above as well. 
This requires something like onItemContainerChanged event, but for the bank container instead of the inventory container.
### Pking will NOT count as a valid way to obtain items
Items you have already obtained will be able to be picked up, but items you have not obtained won't be able to, similar to if someone dropped an item.
## Required for progress
I believe that I require two events, onItemContainerChanged and a function call on a ground item like groundItem.getOwnership()
### onItemContainerChanged
This one is 100% required, it will be checked when you open the bank, adding any items that were missed, and adding items that were added to your inventory.
### groundItem.getOwnership()
This one I believe is required to guarantee correctness. In theory, when you kill an NPC it could be tracked where the NPC died and from there predict where the items should be, but it seems prone to difficulties and inaccuracies.
## Features I need to implement
### Completed -- Disable the 'loot all' option on area loot if there is an item you do not have ownership of
Any item that you do own you can pick up, and if you don't have ownership but you have obtained it before you can pick it up.
### Completed -- Adding items when you open the bank and when they appear in your inventory

### Completed -- Disable the 'take' option on ground items you do not have ownership of
If you don't have ownership but you have obtained it previously, you are allowed to pick it up
### Completed -- Disable any item in the grand exchange that you have not obtained
Done!
### Completed -- Disable accepting any trade with a player
Originally, this was disable trade if they gave you an item you didn't have access to, but I don't think I should have trade enabled at all, since it doesn't seem very bronzeman to be able to be given stuff, even if you unlocked it (like let's say someone tries to give you 100m, that shouldn't work imo). The only exception is bonds, bonds should be tradeable to allow someone to give themselves membership with bonds. So basically, disable the "accept button" for any item that isn't a bond.

BUG: It doesn't actually check the other players' items, only your own.
### Completed -- Add text explaining the gamemode

### Completed -- Add a bronzeman icon next to your name, like the ironman gamemode symbol
Fix bug with the wiki search