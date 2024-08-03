# Spotify-CC
- What is spotify-cc?
Spotify-CC is a live Spotify music player program which you can run in minecraft!
Spotify-CC uses the Spotify webplayer api to get real time data about the song currently playing on your Spotify account. This api is being used to retrieve the song and send it via web socket to a python fastAPI server. The computer craft computer will also connect to the server via web socket connection and receive messages, 

### Requirements
You must have a Spotify premium account for the Spotify player to work.
Connect to Spotify here [https://amused-consideration-production.up.railway.app/](https://amused-consideration-production.up.railway.app/)

## Supported features:
- Play/Pause
- Next/Prev skip song
- Monitor music player
- All monitor sizes supported
- Terminal music player
- Album art image rendering

## Installation
1. Get an advanced computer in Minecraft
1. Connect a speaker to any side of the advanced computer.
2. run `wget https://amused-consideration-production.up.railway.app/luaImages/spotify.lua` to download the script in lua
3. Visit [this website](https://amused-consideration-production.up.railway.app) to get your user hash, which is needed for starting the program.
4. Connect a monitor and run the command specified on [the website](https://amused-consideration-production.up.railway.app/).
    - The command should be something like,`spotify.lua 5j0adfj`

## Program arguments
- where `user_hash` is a unique id assigned to each user.
- where `monitor_location` is top, left, right, back, front, or bottom
- if you do not specify location, a monitor will be picked for you, in the default order listed above.
- `spotify {user_hash}`
- `spotify {user_hash} {monitor_location}` 
- `spotify {user_hash} monitor {monitor_location}`
- `spotify {user_hash} terminal`
    - run on computer instead of on a monitor.

## Controls
- Terminal/computer music player.
    - Space: to pause and pause
    - Left arrow to go to previous song
    - Right arrow to skip song
- Monitor music player
    - Right click buttons to activate, a 'monitor-touch' event

## Images

![](<screenshots/big.png>)
![](<screenshots/medium.png>)
![](<screenshots/small.png>)
![](<screenshots/mobile.png>)


## Compatibility
- This program was developed with:
- `CC:tweaked version 1.111.0`
- `Minecraft version 1.20.1`

It may work with other versions, let me know if you have any issues.

