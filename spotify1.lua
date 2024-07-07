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
        -- splitting the .dfpwn file into chunks 
        local chunk = content:sub(start, start + chunk_size - 1)
        local buffer = decoder(chunk)

        -- the declaration in this loop also executes each iteration of the loop
        -- buffer fills by 'chunk_size' chunks per each loop iteration
        -- declaration plays audio.
        while not speaker.playAudio(buffer) do
            -- os.pullEvent() is a blocking function that waits for an event to occur, and then returns the event and its arguments.
            -- so its essentially pausing and checking for any events that are within its scope.
            -- since play_audio function is nested in the websocket event loop it will be able to see when a websocket message is received when it pauses.
            -- the other "speaker_audio_empty" event IDK what it does tbh
            local event, arg1, arg2 = os.pullEvent()
            -- adding a check for the websocket message in the play audio loop, makes it so that with each iteration of the loop, 
            -- it will check if a websocket message has been recevied
            -- for now every message means 
            if event == "websocket_message" and arg1 == myURL then -- arg1 represents the url of the websocket that sent the message
                print("Received new song while playing")
                -- this contains the message sent from the websocket which in this case is the url of the new song created on the python server.
                return arg2 -- Stop current playback to handle the new message
            elseif event == "speaker_audio_empty" then
                -- Continue playing
            end
        end

        -- increment current position of song by chunk size
        start = start + chunk_size
    end

    return nil
end

-- runs the song until websocket message is recieved then stops the current song and plays the song that is the target of the new message, the message being a link to an audio file on the python server.
local function handle_websocket_message(message)
    -- i think i can omit this
    speaker.stop() -- Stop any currently playing audio

    local song_content = download_audio(message)

    if song_content then
        local song_replacement_url = play_audio(song_content) -- if not nil websocket message was recieved while playing audio
        -- this loop will wait until playAudio is interrupted by a websocket message, then it will stop the current playback and download the new song and play it.
        while song_replacement_url do
            print("Received new song while another was playing")
            speaker.stop() -- Stop current playback
            song_content = download_audio(song_replacement_url) -- Download new audio
            if song_content then
                song_replacement_url = play_audio(song_content)
            else
                song_replacement_url = nil
            end
        end
    end
end

-- Note about program structure:
-- it is important that the websocket is the outtermost layer and the play_audio is nested, because of this you can interrupt the play_audio function when you recive a websocket message
-- if they were siblings, as opposed to (parent, child) then you would have no way of checking for a websocket message while playing audio because they do not have access to eachother's variable context.
-- this problem could be avoided if there was any way to do multithreading or asyncronous programming in cc:tweaked.
repeat
    -- this is also only called once, most of the event checking is done in the play_audio function
    local event, socketUrl, message = os.pullEvent("websocket_message")
    --listens for websocket messages 
    if socketUrl == myURL then
        -- this will only ever run once becasue then the execution gets stuck in the handle_websocket_message function (on purpose)
        print("Received message from " .. socketUrl .. " with contents " .. message)
        -- this function wont ever return.
        handle_websocket_message(message)
    end
until false

--todo listen for termination, make sure websocket is closed.
-- todo, what happens when you get a 403 from youtube?
ws.close()