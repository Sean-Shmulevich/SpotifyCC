**Attention this project is currently down, I am working on a self-hosted version that redirects audio directly from your device, If you want this, send me an email and say you do and it will be done faster**
# Spotify-CC
- What is spotify-cc?
Spotify-CC is a live Spotify music player program which you can run in minecraft!
Spotify-CC uses the Spotify webplayer api to get real time data about the song currently playing on your Spotify account. This api is being used to retrieve the song and send it via web socket to a python fastAPI server. The computer craft computer will also connect to the server via web socket connection and receive messages, 

### Requirements
You must have a Spotify premium account for the Spotify player to work.
Connect to Spotify here [https://amused-consideration-production.up.railway.app/](https://amused-consideration-production.up.railway.app/)
#### IMPORTANT, Request Access
- This app is not yet approved by Spotify, and is still in developer mode. You will have issues logging into the web browser side of the Spotify player, even if you have a Spotify premium account. For the time being, for the app to work you will need to send a request to `seanshmulevich@gmail.com` containing the email associated with your Spotify premium account. the subject should be, 'Spotify-CC user access request'. I will then add you to the list of approved users and you will be able to use the app.

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
- if you do not specify the location, a monitor will be picked for you, in the default order listed above, in the definition of 'monitor_location'.
- Play on the first available monitor
    - `spotify {user_hash}`
- Play on a specified monitor
    - `spotify {user_hash} {monitor_location}` 
    - `spotify {user_hash} monitor {monitor_location}`
-  Run on the computer terminal screen, this includes the 'advanced noisy pocket computer'.
    - `spotify {user_hash} terminal`

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

## Running the backend server locally
- Not yet possible
