# Wallwalking by Addi

After having a discussion with Mee12345 (https://github.com/Mee12345/GMod-Seamless-Portals) about changing player hull sizes and locations to allow them to enter portals, I had the idea of making an addon that offsets player hulls to let them walk through walls *without* falling through the floors. Basically, if a player approaches a wall, we check if there is space behind the wall for the player to fit. If so, we offset their hitbox to that spot repeatedly so that they can walk through the wall while still being at approximately the same height as the floor beneath them.

I expected it to be very scuffed and buggy, but it actually turned out pretty well. It's not flawless, but still effective and a lot of fun to play around with.

## **Addon Usage:**
 - Enable or disable wallwalking with the server ConVar **wallwalking_enabled** (set to 1 to enable or 0 to disable)

 ## **Customization:**
 Other ConVars:
  - **wallwalking_max** - How far can you wallwalk?
  - **wallwalking_min** - How close should you be to an obstruction before wallwalking?
  - **wallwalking_gap** - How much of a gap should there be between potential hulls?