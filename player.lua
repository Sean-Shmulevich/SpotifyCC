-- how does this pgrm look? hmmm
-- first just connect to the websocket server.
local dfpwm = require("cc.audio.dfpwm")

local myURL = "wss://racer-ultimate-literally.ngrok-free.app/ws"
local ws = assert(http.websocket(myURL))

-- Ensure the speaker peripheral is attached
local speaker = peripheral.find("speaker")
if not speaker then
    print("No speaker found. Please attach a speaker.")
    return
end

local numWebsocketMessage = 0

local function play_audio(url)
    local response = get_response(url)
    if response == nil then
        
    end
        local chunk_size = 16 * 1024
        local start = 1
        while start <= #content do
            local chunk = content:sub(start, start + chunk_size - 1)
            local buffer = decoder(chunk)

            -- run all of my websocket stuff here
            while not speaker.playAudio(buffer) do
                os.pullEvent("speaker_audio_empty")
            end

            start = start + chunk_size
    end
end

local function get_response(url)
    local response = http.get(url)
    if response then
        local decoder = dfpwm.make_decoder()
        local content = response.readAll()
        response.close()
        return content
    else
        print("Failed to download the file from URL: " .. url)
        return nil
    end
end


repeat
    local event, socketUrl, message = os.pullEvent("websocket_message")
    if socketUrl == myURL then
        print("got song")
        local response = http.get(message)
        local decoder = dfpwm.make_decoder()
        local content = nil
        

        --response is absolutely not guaranteed so i should handle this.
        if response then
            content = response.readAll()
            response.close()
        end

        if(content == nil) then
            print("Failed to download audio file")
            return
        end

        -- for chunk in io.lines(message, 16 * 1024) do
        --     local buffer = decoder(chunk)
        
        --     while not speaker.playAudio(buffer) do
        --         os.pullEvent("speaker_audio_empty")
        --     end
        -- end

        -- if numWebsocketMessage == 0 then
        --     speaker.playAudio(content);
        -- else
        --     shell.execute("speaker", "stop") -- Stop the current audio file
        -- end
        speaker.stop() -- Stop any currently playing audio
        play_audio(message) -- Play the new audio file when a message is received


        numWebsocketMessage = numWebsocketMessage + 1
    end
until false

ws.close()
shell.execute("player.lua");
