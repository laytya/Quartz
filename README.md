# Quartz 
Is a modular approach to a casting bar addon. An overview of (hopefully most of) the modules:
![image](https://github.com/user-attachments/assets/5a13dcfc-7390-4ce6-a86b-8fa2e3f9d374)

## Player

The core of Quartz is lightweight implementation of a standard casting bar, with configurable size, text and icon positioning, and colors. 

## Target
Implementation of target casting bars in similar fashion to the player cast bar. 

## Flight
Hooks into FlightMap or InFlight to display the current flight progress on your casting bar. 

## Global Cooldown
Displays a tiny spark-bar to show your Global Cooldown near the cast bar. Helpful for those who'd rather not squint at their action bars to see when they can cast again. 

## Interrupt
Changes the color and text of your casting bar to help show that your cast has been interrupted (and show who interrupted it). 

## Latency
Displays the amount of time spent between cast send and start events, in the form of a bar at the end of your casting bar, with optional text that displays the actual duration of the lag. This helps in canceling casts when they will not actually be interrupted, especially for users with consistently high pings. 

## Mirror
Shows the 'basic' timers such as breath and feign death, as well as some 'odd' ones such as party invite time, resurrect timeout, and arena game start, and a framework for injecting custom timers into the bars. 

## Range
Recolors the casting bar when your cast target moves out of range mid-cast. 

## Swing
Displays a swing timer for your melee weapon as well as hunter autoshot. 

## Timer
Allows for creating custom timers displayed on the mirror bars. 
Usage:  
Start timer - 
**/quartztimer timername 60** or **/quartztimer 60 timername**
or  **/qt timername 60** or **/qt 60 timername**

Kill timer - **/quartztimer kill timername** or **/qt kill timername**

## Tradeskill Merge
Merges multiple casts of the same tradeskill item into one big cast bar. 

Use /q3 or /quartz to bring up the configuration menu.

## SP_Swingtimer's **st_timer** emulation
Added SP_Swingtimer's **st_timer** emulation. You can use it in your old macros w/out SP_Swingtimer loaded.

## ⚠️ **IMPORTANT: SUPERWOW IS REQUIRED!** ⚠️  
❌ **This addon WILL NOT WORK without [SuperWoW](https://github.com/balakethelock/SuperWoW/releases)!**  
