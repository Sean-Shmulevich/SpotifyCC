local baseURL = "amused-consideration-production.up.railway.app"
local myURL = string.format("wss://%s/ws/luaclient", baseURL)
local ws = assert(http.websocket(myURL))
local dfpwm = require("cc.audio.dfpwm")
local lzw = require("lzw")

local pixelbox = require("pixelbox_lite")
local box = pixelbox.new(term.current())

local playButton = require("playButton")

local terminate = false

local paused_img = playButton.load_img("paused")
local playing_img = playButton.load_img("playing")

local start_x, start_y, end_x, end_y = playButton.get_touch_boundry(playing_img, "bottom-middle",box)
local prev_start_x, prev_start_y, prev_end_x, prev_end_y = playButton.get_touch_boundry(playing_img, "left",box)
local next_start_x, next_start_y, next_end_x, next_end_y = playButton.get_touch_boundry(paused_img, "right",box)

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

local function spotify_next_track()
    return httpGetWrapper("https://"..baseURL .. "/nextTrack")
end

local function download_audio(url)
    local song_data = httpGetWrapper(url)

    if(song_data == nil) then
        return nil
    end

    return song_data
end

local function get_album_img(url)
    local compressed_img_data = httpGetWrapper(url)
    local decompressed_data, err = lzw.decompress(compressed_img_data)
    return paintutils.parseImage(decompressed_data)
end

local function download_artwork(url)
    local song_data = httpGetWrapper(url)
    io.open('temp.nfp', 'w+b'):write(song_data):close()
    return "temp.nfp"
end



local function play_audio(content, chunk_start)
    local decoder = dfpwm.make_decoder()
    local chunk_size = 16 * 1024
    local chunk_idx = chunk_start
    local playback_state = "playing"
    local prev_playback_state = "playing"
    local first_three_chunks = 0
    local speaker_audio = nil
    local prevChunk = nil


    -- these nested loops are a bit confusing but essentially, audio is buffered, by the outter loop in increments of chunk size
    -- and then the inner loop goes until all of the data in that buffer is played.
    while chunk_idx <= #content do
        -- splitting the .dfpwn file into chunks 
        local chunk = content:sub(chunk_idx, chunk_idx + chunk_size - 1)
        local buffer = decoder(chunk)

        local startTime = os.epoch("utc") / 1000

        -- everything inside of this loop happens while the song is playing-
        -- for each filling and clearing of the chunked buffer
        -- speaker.playAudio(buffer) returns a boolean value, true if there is room to accept audio data.

        while true do
            if(playback_state == "playing" and speaker.playAudio(buffer)) then
                break
            end

            local event, arg1, arg2, arg3 = os.pullEventRaw() -- os.pullEvent() is a blocking function that waits for an event to occur, and then returns the event and its arguments

            if event == "websocket_message" and arg1 == myURL then -- arg1 represents the url of the websocket that sent the message
                return arg2, "newSong" -- Stop current playback to handle the new message

            elseif event == "monitor_touch" and playback_state ~= "paused" then
                -- how to get it to know when it stops
                -- print("mouse event pause")
                playback_state = "paused"
                -- each loop iteration takes about 2.6 seconds to run.
                local chunk_pause = os.epoch("utc") / 1000

                -- this code is fucked up but it came from a lot of testing.
                local percent = 1 + (((chunk_pause - startTime) / 2.65))

                if(percent < 1.4) then
                    percent = 3 - percent
                end

                local x = arg2
                local y = arg3
                if x >= start_x and x <= end_x and y >= start_y and y <= end_y then
                    return math.floor(chunk_idx - (chunk_size * percent)), "paused"
                elseif x >= next_start_x and x <= next_end_x and y >= next_start_y and y <= next_end_y then
                elseif x >= prev_start_x and x <= prev_end_x and y >= prev_start_y and y <= prev_end_y then
                    -- animation()
                end


                -- end

                -- print("percent: " .. percent)
                -- have to go almost 2 chunks back because chunk was just incremented at begining of loop.

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
            elseif event=="terminate" then
                ws.close()
                speaker.stop()
                terminate = true
                return nil
            elseif event == "key" and playback_state ~= "playing" then
                -- run unpause logic
                -- print("Key event play")

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

        if playback_state == "playing" then
            chunk_idx = chunk_idx + chunk_size
        end
    end

    -- print("Song finished")
    spotify_next_track()
    -- send skip to next song on spotify
    return nil
end

local function setPaletteColors(colors)
    for i=0,15 do
        -- print(colors[i+1])
        term.setPaletteColor(2^i, colors[i+1])
        -- palette[2^i] = {term.getPaletteColor(2^i)}
    end
end

-- Load the PNG image

-- Create a bare canvas and set it up
-- local bare_canvas = pixelbox.make_canvas()
-- local usable_canvas = pixelbox.setup_canvas(box, bare_canvas)
local function load_album(img, palette)
    local img_size = #img[1]
    local term_width, term_height = box.width, box.height

    if #img < #img[1] then
        img_size = #img
    end

    local center_offset = math.floor((term_width - img_size)/2)

    local bare_canvas   = pixelbox.make_canvas()
    local temp_canvas = pixelbox.setup_canvas(box,bare_canvas,colors.black)
    -- for i = 1, img_size^2 do
    --     local x = math.floor((i - 1) / img_size) + 1
    --     local y = ((i - 1) % img_size) + 1
    --     box.canvas[y][x] = img[y][x + center_offset]
    -- end


    setPaletteColors(palette)

    for y = 1, img_size do
        for x = 1, img_size do
            -- local r,g,b = img:get_pixel(x,y):unpack()

            -- print(colors.toBlit(colors.packRGB(r,g,b)))
            -- print(find_closest_color(r*255, g*255, b*255))
            temp_canvas[y+2][x+center_offset] = img[y][x]
            -- print(img[y][x])
        end
    end
    return temp_canvas
end



-- I want to make it so that when you skip a song, 
-- The web player pauses until speaker.playAudio is called for the first time.

-- runs the song until websocket message is recieved then stops the current song and plays the song that is the target of the new message, the message being a link to an audio file on the python server.
local function handle_websocket_message(message)
    -- i think i can omit this
    speaker.stop() -- Stop any currently playing audio

    local song_data = textutils.unserializeJSON(message)

    local audio_url = song_data["audio_file"]
    local song_content = download_audio(audio_url)
    local payload, state

    if song_content then
        local img_palette = textutils.unserialize(song_data["palette"])
        -- try streaming the image using LZW.
        local img = get_album_img(audio_url:sub(1, #audio_url - 5) .. "lzw")

        local album_canvas = load_album(img, img_palette)
        album_canvas = playButton.add_playback_buttons(playing_img, album_canvas, box)
        box:set_canvas(album_canvas)
        box:render()

        payload, state = play_audio(song_content, 1)
        -- parallel.waitForAll(playSongInit, displayArtworkInit)

        -- this loop will wait until playAudio is interrupted by a websocket message, then it will stop the current playback and download the new song and play it.
        while payload do
            if song_content and state == "newSong" then
                speaker.stop() -- Stop current playback
                -- print("Received new song while another was playing")
                -- song_artwork = download_artwork()

                song_data = textutils.unserializeJSON(payload)
                audio_url = song_data["audio_file"]
                song_content = download_audio(audio_url) -- Download new audio
                img_palette = textutils.unserialize(song_data["palette"])

                img = get_album_img( audio_url:sub(1, #audio_url - 5) .. "lzw" )

                album_canvas = load_album(img, img_palette)
                album_canvas = playButton.add_playback_buttons(playing_img, album_canvas, box)
                box:set_canvas(album_canvas)
                box:render()

                payload, state = play_audio(song_content, 1)


            elseif song_content and state == "paused" then
                speaker.stop() -- Stop current playback
                album_canvas = playButton.add_playback_buttons(paused_img, album_canvas, box)
                box:set_canvas(album_canvas)
                box:render()
                local event, side, x, y = os.pullEvent("monitor_touch")
                if x >= start_x and x <= end_x and y >= start_y and y <= end_y then
                    album_canvas = playButton.add_playback_buttons(playing_img, album_canvas, box)
                    box:set_canvas(album_canvas)
                    box:render()
                elseif x >= next_start_x and x <= next_end_x and y >= next_start_y and y <= next_end_y then
                elseif x >= prev_start_x and x <= prev_end_x and y >= prev_start_y and y <= prev_end_y then
                end
                payload, state = play_audio(song_content, payload)
            else
                -- i know we hit this when we finish a song but when else
                spotify_next_track()
                -- break out of loop and wait for new message.
                payload = nil
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
    -- make THIS ONE never time out.
    local event, socketUrl, message = os.pullEvent("websocket_message")
    --listens for websocket messages 
    if socketUrl == myURL then
        -- this will only ever run once becasue then the execution gets stuck in the handle_websocket_message function (on purpose)
        print("Received message from " .. socketUrl .. " with contents " .. message)
        -- this function wont ever return.
        handle_websocket_message(message)
    end
until terminate

--todo listen for termination, make sure websocket is closed.
-- todo, what happens when you get a 403 from youtube?
