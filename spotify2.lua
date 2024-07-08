local dfpwm = require("cc.audio.dfpwm")

local myURL = "wss://racer-ultimate-literally.ngrok-free.app/ws"
local ws = assert(http.websocket(myURL))

-- Ensure the speaker peripheral is attached
local speaker = peripheral.find("speaker")
if not speaker then
    print("No speaker found. Please attach a speaker.")
    return
end

local function download_audio(url)
    local response = http.get(url)
    if response then
        local content = response.readAll()
        response.close()
        return content
    else
        print("Failed to download the file from URL: " .. url)
        return nil
    end
end

local function play_audio(content)
    local decoder = dfpwm.make_decoder()
    local chunk_size = 16 * 1024
    local start = 1

    while start <= #content do
        local chunk = content:sub(start, start + chunk_size - 1)
        local buffer = decoder(chunk)

        while not speaker.playAudio(buffer) do
            local event, arg1, arg2 = os.pullEvent()
            if event == "websocket_message" and arg1 == myURL then
                print("Received new song while playing")
                return arg2 -- Stop current playback to handle the new message
            elseif event == "speaker_audio_empty" then
                -- Continue playing
            end
        end

        start = start + chunk_size
    end

    return nil
end

local function handle_websocket_message(message)
    speaker.stop() -- Stop any currently playing audio

    local content = download_audio(message)
    if content then
        local new_message = play_audio(content)
        while new_message do
            print("Received new song while another was playing")
            speaker.stop() -- Stop current playback
            content = download_audio(new_message) -- Download new audio
            if content then
                new_message = play_audio(content)
            else
                new_message = nil
            end
        end
    end
end

repeat
    local event, socketUrl, message = os.pullEvent("websocket_message")
    if socketUrl == myURL then
        print("Received message from " .. socketUrl .. " with contents " .. message)
        handle_websocket_message(message)
    end
until false

ws.close()
shell.execute("player.lua")