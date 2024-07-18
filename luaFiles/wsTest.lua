-- local baseURL = "racer-ultimate-literally.ngrok-free.app/api/endpoint"
local myURL = "wss://racer-ultimate-literally.ngrok-free.app/ws/luaclient"
local ws = assert(http.websocket(myURL))

repeat
    -- this is also only called once, most of the event checking is done in the play_audio function
    -- make THIS ONE never time out.
    local event, socketUrl, message = os.pullEvent("websocket_message")
    --listens for websocket messages 
    if socketUrl == myURL then
        -- this will only ever run once becasue then the execution gets stuck in the handle_websocket_message function (on purpose)
        print("Received message from " .. socketUrl .. " with contents " .. message)
        message = textutils.unserializeJSON(message)
        print(message)

        -- this function wont ever return.
    end
until false
