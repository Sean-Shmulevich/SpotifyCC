local dfpwm = require("cc.audio.dfpwm")

local baseURL = "https://racer-ultimate-literally.ngrok-free.app"
local myURL = "wss://racer-ultimate-literally.ngrok-free.app/ws"
local ws = assert(http.websocket(myURL))
local once = true



-- Ensure the speaker peripheral is attached
local speaker = peripheral.find("speaker")
if not speaker then
    print("No speaker found. Please attach a speaker.")
    return
end

local function httpGetWrapper(url)
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

local function spotify_play()
    return httpGetWrapper(baseURL .. "/play")
end

local function spotify_pause()
    return httpGetWrapper(baseURL .. "/pause")
end

local function spotify_next_track()
    return httpGetWrapper(baseURL .. "/nextTrack")
end

local function download_audio(url)
    local song_data = httpGetWrapper(url)
    return song_data
end



function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k,v in pairs(o) do
            if type(k) ~= 'number' then k = '"'..k..'"' end
            s = s .. '['..k..'] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

local function play_audio(content, chunk_start)
    local decoder = dfpwm.make_decoder()
    local chunk_size = 16 * 1024
    local chunk_idx = chunk_start
    local playback_state = "playing"
    local prev_playback_state = "playing"
    local speaker_audio = nil
    local prevChunk = nil


    -- these nested loops are a bit confusing but essentially, audio is buffered, by the outter loop in increments of chunk size
    -- and then the inner loop goes until all of the data in that buffer is played.
    while chunk_idx <= #content do
        -- splitting the .dfpwn file into chunks 
        local chunk = content:sub(chunk_idx, chunk_idx + chunk_size - 1)
        local buffer = decoder(chunk)


        -- everything inside of this loop happens while the song is playing-
        -- for each filling and clearing of the chunked buffer
        -- speaker.playAudio(buffer) returns a boolean value, true if there is room to accept audio data.

        while true do
            
            if(playback_state == "playing" and speaker.playAudio(buffer)) then
                break
            end

            local event, arg1, arg2 = os.pullEvent() -- os.pullEvent() is a blocking function that waits for an event to occur, and then returns the event and its arguments
            -- if we are paused 
            -- only run this when playing or when paused but prev is playing

            -- -- so its essentially pausing and checking for any events that are within its scope.
            -- -- since play_audio function is nested in the websocket event loop it will be able to see when a websocket message is received when it pauses.
            -- -- because of this, this loop will run essentially once per event recieved.
            -- event, arg1, arg2 = os.pullEvent() -- os.pullEvent() is a blocking function that waits for an event to occur, and then returns the event and its arguments

            if event == "websocket_message" and arg1 == myURL then -- arg1 represents the url of the websocket that sent the message
                print("Received new song while playing")
                -- message could be next song or song change.
                -- pause and skip are not played with this current implementation.
                -- this contains the message sent from the websocket which in this case is the url of the new song created on the python server.
                return arg2, "newSong" -- Stop current playback to handle the new message
            elseif event == "mouse_click" and playback_state ~= "paused" then
                -- how to get it to know when it stops
                print("mouse event pause")
                return chunk_idx - ( chunk_size*2 ), "pause"

                -- os.pullEvent("speaker_audio_empty") -- os.pullEvent() is a blocking function that waits for an event to occur, and then returns the event and its arguments
                -- playback_state = "paused"
                -- -- prev_playback_state = "playing"
                -- print("speaker empty")
                -- os.startTimer(2.7)
                -- os.pullEvent("timer")
                -- print("playback pause end of chunk data sent")

                -- spotify_pause()
                -- you can only check if theres more room basically.
                -- print("empty buffer: " tostring(empty_buffer))
                -- if(not empty_buffer) then
                --     print("speaker audio from pause")

                -- else
                --     print("speaker audio not done yet")
                -- end
                -- write binary to a temp file maybe
            elseif event == "key" and playback_state ~= "playing" then
                -- run unpause logic
                print("Key event play")

                -- spotify_play()
                -- it takes a sec for the pause route to run and the spotify api to respond.
                -- I could maybe get rid of this for a websocket message right after play succeeds.
                -- os.pullEvent("websocket_message") this might just skew the delay towards the lua client.
                -- os.startTimer(0.1)
                -- os.pullEvent("timer")
                playback_state = "playing"
                -- the chunk stops incrementing when paused. so it will likely start over that chunk.
            elseif event == "speaker_audio_empty" then -- there is more space in the speaker for audio.
                -- Continue playing
            end
        end

        
        -- if(playback_state == "paused") then
        --     local event, arg1, arg2 = os.pullEvent() -- os.pullEvent() is a blocking function that waits for an event to occur, and then returns the event and its arguments
            
        print("chunk done" .. tostring(chunk_idx))

        -- increment current position of song by chunk size
        -- dont increment when paused.
        if playback_state == "playing" then
            chunk_idx = chunk_idx + chunk_size
        end

    end

    print("Song finished")
    spotify_next_track()
    -- send skip to next song on spotify
    return nil
end

-- I want to make it so that when you skip a song, 
-- The web player pauses until speaker.playAudio is called for the first time.

-- runs the song until websocket message is recieved then stops the current song and plays the song that is the target of the new message, the message being a link to an audio file on the python server.
local function handle_websocket_message(message)
    -- i think i can omit this
    speaker.stop() -- Stop any currently playing audio

    local song_content = download_audio(message)

    if song_content then
        local song_replacement_url, state = play_audio(song_content, 1) -- if not nil websocket message was recieved while playing audio
        -- this loop will wait until playAudio is interrupted by a websocket message, then it will stop the current playback and download the new song and play it.
        while song_replacement_url do
            if song_content and state == "newSong" then
                speaker.stop() -- Stop current playback
                print("Received new song while another was playing")
                song_content = download_audio(song_replacement_url) -- Download new audio
                once = true
                song_replacement_url, state = play_audio(song_content, 1)
            elseif song_content and state == "pause" then
                -- i feel like it wont get the right buffer.
                -- encoder = dfpwm.make_encoder()
                -- local encoded = encoder(song_content)
                speaker.stop() -- Stop current playback
                local keyUnpause = os.pullEvent("key")
                if keyUnpause == "key" then
                    print("Key event play")
                    song_replacement_url, state = play_audio(song_content, song_replacement_url)
                end
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