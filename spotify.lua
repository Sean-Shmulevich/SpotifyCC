local dfpwm = require("cc.audio.dfpwm")

local myURL = "wss://b192-2601-547-780-c5a0-8db3-ddc7-b116-791c.ngrok-free.app/ws"
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
            local event, arg1 = os.pullEvent()
            if event == "websocket_message" and arg1 == myURL then
                print("Received new song while playing")
                return false -- Stop current playback to handle the new message
            elseif event == "speaker_audio_empty" then
                -- Continue playing
            end
        end

        start = start + chunk_size
    end

    return true
end

repeat
    local event, socketUrl, message = os.pullEvent("websocket_message")
    if socketUrl == myURL then
        print("Received message from " .. socketUrl .. " with contents " .. message)
        speaker.stop() -- Stop any currently playing audio

        local content = download_audio(message)
        if content then
            while not play_audio(content) do
                -- Handle new WebSocket messages during playback
                local event, socketUrl, message = os.pullEvent("websocket_message")
                if socketUrl == myURL then
                    print("Received new song while another was playing")
                    speaker.stop() -- Stop current playback
                    content = download_audio(message) -- Download new audio
                end
            end
        end
    end
until false

ws.close()