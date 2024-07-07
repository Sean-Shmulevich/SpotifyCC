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
    local chunk_idx = 1
    local playback_state = "playing"

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
            -- playing and full
            -- speaker.playAudio will only execute when playback_state is "playing", cause de-morgans law bitch
            if (playback_state=="playing" and speaker.playAudio(buffer)) then
                break -- end loop and load in next buffered chunk.
            end

            -- so its essentially pausing and checking for any events that are within its scope.
            -- since play_audio function is nested in the websocket event loop it will be able to see when a websocket message is received when it pauses.
            local event, arg1, arg2 = os.pullEvent() -- os.pullEvent() is a blocking function that waits for an event to occur, and then returns the event and its arguments

            if event == "websocket_message" and arg1 == myURL then -- arg1 represents the url of the websocket that sent the message
                print("Received new song while playing")
                -- this contains the message sent from the websocket which in this case is the url of the new song created on the python server.
                return arg2 -- Stop current playback to handle the new message
            elseif event == "mouse_click" then

                playback_state = "paused"


                -- During this loop I need to check for any event basically that will pause
                -- I could try a custom event or rednet from a monitor display pgrm.
                -- or i could run a ui player in the console.
                -- save and store chunk idx

                -- if you mouse click, then this loop continues on and does nothing but checks for the next mouseclick.
                -- most importantly speaker.playAudio(buffer) will not be called until the next mouse click.
                -- i kinda do not wanna have the pause execution leave this function because then i will have to redownload from the server.
                -- if i could get the rest of the song saved to a drive in this section, and i did return when recieving mouse)click event
                -- then maybe i could call play_audio to a local file path. thats kinda a good solution because its not redownloading from the server? why is that a good idea?
                -- either way on the unpause, i need to start from the chunk_idx that was saved.


                print("Mouse click event paused")
            elseif event == "key" then
                -- run unpause logic
                print("Key event play")
                playback_state = "playing"
                -- the chunk stops incrementing when paused. so it will likely start over that chunk.
                speaker.playAudio(buffer)
            elseif event == "speaker_audio_empty" then
                -- Continue playing
            end
        end

        -- increment current position of song by chunk size
        -- dont increment when paused.
        if (playback_state=="playing") then
            chunk_idx = chunk_idx + chunk_size
        end
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