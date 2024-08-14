import json
from unidecode import unidecode
from starlette.websockets import WebSocketState
import re
from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from threading import Thread
import uvicorn
import sys
from boto_client import create_presigned_url
from connection_manager import ConnectionManager
from create_media_cc import download_song, download_cc_image_encoded
from boto3 import client

# redirect_uri = 'http://localhost:7777/callback'
redirect_uri = 'https://racer-ultimate-literally.ngrok-free.app/callback'
scope = 'user-read-currently-playing user-read-playback-state streaming user-read-email user-read-private user-modify-playback-state'
BASE_URL = "https://amused-consideration-production.up.railway.app/"

app = FastAPI()
cc_tunnel_manager = {}


@app.get("/songs/{object_key}")
def redirect_presigned_url(object_key: str):
    url = create_presigned_url("cc-spotify", object_key)
    if url is None:
        raise HTTPException(status_code=400)
    return RedirectResponse(url)


# # take success generated hash and add to web-client mapping
# @app.get("/make-user-tunnel/{user_hash}")
# def make_client(user_hash):
#     cc_tunnel_manager[user_hash] = ConnectionManager()
#     return "success"


@app.websocket("/ws/webclient/{user_hash}")
async def websocket_endpoint_webclient(websocket: WebSocket, user_hash):

    if user_hash not in cc_tunnel_manager:
        print("user_hash not in cc_tunnel_manager on webclient connection")
        cc_tunnel_manager[user_hash] = ConnectionManager()

    manager = cc_tunnel_manager[user_hash]

    await manager.connect_js(websocket)

    if manager.lua_connected():
        await manager.forward_to_lua("jsConnected")
        await websocket.send_text("luaConnectedOnInit")
    # else:
    #     manager.forward_to_js("luaNotConnected")
    print("js connected")

    try:
        while websocket.client_state == WebSocketState.CONNECTED:

            data = await websocket.receive_json()
            print(data)
            id, artist, songName, albumName, albumArt = list(data.values())
            albumName = albumName.lower()
            albumName = unidecode(albumName)
            albumName = albumName.replace(" ", "_")
            albumName = re.sub(r'\W+', '_', albumName)  # Replace non-alphanumeric characters with '_'
            converted_song_path = await download_song(id, artist, songName)
            cc_palette, pixel_size = await download_cc_image_encoded(albumArt, albumName, manager.lua_width, manager.lua_height)
            albumName = f"songs/{albumName}_{pixel_size}.lzw"

            webserver_location = f"{converted_song_path}"

            payload = {"audio_file": webserver_location, "palette": cc_palette, "album_img": albumName}
            print(payload)

            if (converted_song_path is not None) and manager.lua_connected():
                await manager.forward_to_lua(json.dumps(payload))
            else:
                print("lua client not connected")
    except WebSocketDisconnect:
        print("js disconnect")
        await manager.disconnect_js()
        if manager.lua_connected():
            await manager.forward_to_lua("jsDisconnect")

    print("js disconnect")
    await manager.disconnect_js()
    if manager.lua_connected():
        await manager.forward_to_lua("jsDisconnect")

@app.websocket("/ws/luaclient/{user_hash}")
async def websocket_endpoint_luaclient(websocket: WebSocket, user_hash):
    if user_hash not in cc_tunnel_manager:
        cc_tunnel_manager[user_hash] = ConnectionManager()

    manager = cc_tunnel_manager[user_hash]

    await manager.connect_lua(websocket)
    if manager.js_connected():
        await websocket.send_text("jsConnectedOnInit")
    lua_monitor_size = await websocket.receive_text()
    manager.set_lua_monitor_size(lua_monitor_size.split(' '))

    print("lua connected")
    # if the js client is not connected, then dont try to connect to the lua client at all.
    if manager.js_connected():
        await manager.forward_to_js("luaConnected")

    try:
        while websocket.client_state == WebSocketState.CONNECTED:
            data = await websocket.receive_text()
            if data == "end":
                print("streaming ended")
                await manager.disconnect_lua()
                if manager.js_connected():
                    await manager.forward_to_js("luaDisconnect")
                return
    except WebSocketDisconnect:
        print("lua disconnect")
        await manager.disconnect_lua()

        if manager.js_connected():
            await manager.forward_to_js("luaDisconnect")

# TODO: make this endpoint send a message to the front-end.
@app.get("/nextTrack/{user_hash}")
async def next_track(user_hash):
    if user_hash not in cc_tunnel_manager:
        cc_tunnel_manager[user_hash] = ConnectionManager()

    manager = cc_tunnel_manager[user_hash]

    await manager.forward_to_js("nextSong")
    return "Playing"


@app.get("/checkHash/{user_hash}")
async def check_hash(user_hash):
    if user_hash not in cc_tunnel_manager:
        return "invalid"
    return "ok"


@app.get("/prevTrack/{user_hash}")
async def prev_track(user_hash):
    if user_hash not in cc_tunnel_manager:
        cc_tunnel_manager[user_hash] = ConnectionManager()

    manager = cc_tunnel_manager[user_hash]

    await manager.forward_to_js("prevSong")
    return "Playing"

app.mount("/luaImages", StaticFiles(directory="luaImages"), name="assets")
app.mount("/", StaticFiles(directory="static", html = True), name="static")

def start_server():
    uvicorn.run(app, host="0.0.0.0", port=7777)


if __name__ == '__main__':
    # Start the FastAPI server in a new thread
    Thread(target=start_server).start()
    # Open the Spotify authentication URL in the default web browser
