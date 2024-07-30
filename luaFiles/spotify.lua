local args = {...}
local userHash = args[1]
local baseURL = "amused-consideration-production.up.railway.app"
local myURL = string.format("wss://%s/ws/luaclient/%s", baseURL, userHash)
local dfpwm = require("cc.audio.dfpwm")
local lzw = require("lzw")

local pixelbox = require("pixelbox_lite")
local box = pixelbox.new(term.current())

box:clear(colors.black)
box:render()

local playButton = require("playButton")

local terminate = false
local jsConnected = false

local mediaSize = playButton.calculateHeight(box)
local paused_img = playButton.load_img_sized("paused", mediaSize)
local playing_img = playButton.load_img_sized("playing", mediaSize)
local next_img = playButton.load_img_sized("next", mediaSize)
local prev_img = playButton.load_img_sized("prev", mediaSize)
-- local paused_img = playButton.load_img("paused")
-- local playing_img = playButton.load_img("playing")
-- local next_img = playButton.load_img("next")
-- local prev_img = playButton.load_img("prev")

local start_x, start_y, end_x, end_y = playButton.get_touch_boundry(playing_img, "bottom-middle",box)
local prev_start_x, prev_start_y, prev_end_x, prev_end_y = playButton.get_touch_boundry(playing_img, "left",box)
local next_start_x, next_start_y, next_end_x, next_end_y = playButton.get_touch_boundry(paused_img, "right",box)

local ws = assert(http.websocket(myURL))
ws.send(tostring(box.width) .." ".. tostring(box.height))
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
    return httpGetWrapper("https://"..baseURL .. "/nextTrack/" .. userHash)
end

local function spotify_prev_track()
    return httpGetWrapper("https://"..baseURL .. "/prevTrack/" .. userHash)
end

local function download_audio(url)
    local song_data = httpGetWrapper("https://" .. baseURL .. "/" .. url)

    if(song_data == nil) then
        return nil
    end

    return song_data
end

local function get_album_img(url)
    local compressed_img_data = httpGetWrapper("https://" .. baseURL .. "/" .. url)
    local decompressed_data, err = lzw.decompress(compressed_img_data)
    return paintutils.parseImage(decompressed_data)
end


local function play_audio(content, chunk_start, url)
    local decoder = dfpwm.make_decoder()
    local chunk_size = 16 * 1024
    local chunk_idx = chunk_start
    local playback_state = "playing"
    local prev_playback_state = "playing"
    local first_three_chunks = 0
    local speaker_audio = nil
    local prevChunk = nil
    local skipOnce = true


    -- these nested loops are a bit confusing but essentially, audio is buffered, by the outter loop in increments of chunk size
    -- and then the inner loop goes until all of the data in that buffer is played.
    while chunk_idx <= #content do
        -- splitting the .dfpwn file into chunks 
        local chunk = content:sub(chunk_idx, chunk_idx + chunk_size - 1)
        local buffer = decoder(chunk)

        local startTime = os.epoch("utc") / 1000

        while true do
            if(playback_state == "playing" and speaker.playAudio(buffer)) then
                break
            end



            local event, arg1, arg2, arg3 = os.pullEventRaw() -- os.pullEvent() is a blocking function that waits for an event to occur, and then returns the event and its arguments

            if event == "websocket_message" and arg1 == myURL then -- arg1 represents the url of the websocket that sent the message
                local song_data = arg2
                local audio_url = nil
                if arg2 ~= "jsDisconnect" and arg2 ~= "jsConnected" then
                    song_data = textutils.unserializeJSON(arg2)
                    audio_url = song_data["audio_file"]
                elseif arg2 == "jsDisconnect" then
                    jsConnected = false
                elseif arg2 == "jsConnected" then
                    jsConnected = true
                end

                if audio_url ~= nil and audio_url ~= url then
                    return arg2, "newSong" -- Stop current playback to handle the new message
                end
            elseif skipOnce and event == "monitor_touch" and playback_state ~= "paused" then
                -- how to get it to know when it stops
                -- print("mouse event pause")
                local x = arg2
                local y = arg3
                if x >= start_x and x <= end_x and y >= start_y and y <= end_y then
                    playback_state = "paused"
                    -- each loop iteration takes about 2.6 seconds to run.
                    local chunk_pause = os.epoch("utc") / 1000

                    -- this code is fucked up but it came from a lot of testing.
                    local percent = 1 + (((chunk_pause - startTime) / 2.65))

                    if(percent < 1.4) then
                        percent = 3 - percent
                    end
                    return math.floor(chunk_idx - (chunk_size * percent)), "paused"
                elseif x >= next_start_x and x <= next_end_x and y >= next_start_y and y <= next_end_y then
                    if jsConnected then
                        if skipOnce then
                            skipOnce = false
                        end
                        spotify_next_track()
                        return "", "loading"
                    else
                        print("cannot skip, web is client disconnected. try reloading https://amused-consideration-production.up.railway.app/")
                    end
                    -- add loader until playing and disable button
                elseif x >= prev_start_x and x <= prev_end_x and y >= prev_start_y and y <= prev_end_y then
                    if jsConnected then
                        if skipOnce then
                            skipOnce = false
                        end
                        spotify_prev_track()
                        return "", "loading"
                    else
                        print("cannot skip, web client is disconnected. try reloading https://amused-consideration-production.up.railway.app/")
                    end
                    -- add loader until playing and disable button
                end
            elseif event=="terminate" then
                speaker.stop()
                terminate = true
                return nil
            elseif event == "speaker_audio_empty" then -- there is more space in the speaker for audio.
                -- Continue playing
            end


        end


        if playback_state == "playing" then
            chunk_idx = chunk_idx + chunk_size
        end
    end

    if not jsConnected then
        -- loading until the webplayer is reloaded.
        box:clear(colors.black)
        box:render()
        print("Web client disconnected, try refreshing https://amused-consideration-production.up.railway.app/")
        local _, _, arg2, _ = os.pullEvent("websocket_message") -- pull message to get the new song.
        if arg2 == "jsConnected" then
            jsConnected = true
            _, _, arg2, _ = os.pullEvent("websocket_message")
        end
        return arg2, "newSong"
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
            temp_canvas[y][x+center_offset] = img[y][x]
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
    local img_url = song_data["album_img"]
    local song_content = download_audio(audio_url)
    local payload, state

    if song_content then
        local img_palette = textutils.unserialize(song_data["palette"])
        -- try streaming the image using LZW.
        print(img_url)
        local img = get_album_img(img_url)

        local album_canvas = load_album(img, img_palette)
        album_canvas = playButton.add_playback_buttons(playing_img, album_canvas, box, next_img, prev_img)
        box:set_canvas(album_canvas)
        box:render()

        -- local function wrap_play_audio()
        --     payload, state = play_audio(song_content, 1)
        -- end
        -- local function wrap_check_loading()
            --
        --     checkLoading(album_canvas)
        -- end
        payload, state = play_audio(song_content, 1, audio_url)

        -- this loop will wait until playAudio is interrupted by a websocket message, then it will stop the current playback and download the new song and play it.
        while payload do
            if song_content and state == "newSong" then
                loading = false
                speaker.stop() -- Stop current playback
                -- print("Received new song while another was playing")
                -- song_artwork = download_artwork()

                song_data = textutils.unserializeJSON(payload)
                audio_url = song_data["audio_file"]
                img_url = song_data["album_img"]
                song_content = download_audio(audio_url) -- Download new audio
                img_palette = textutils.unserialize(song_data["palette"])

                img = get_album_img(img_url)

                album_canvas = load_album(img, img_palette)
                album_canvas = playButton.add_playback_buttons(playing_img, album_canvas, box, next_img, prev_img)
                box:set_canvas(album_canvas)
                box:render()

                -- payload, state = play_audio(song_content, 1)
                payload, state = play_audio(song_content, 1, audio_url)
                -- parallel.waitForAny(wrap_play_audio, wrap_check_loading)
            elseif state == "loading" then
                local pos = 1
                local function checkMsg()
                    local event, arg1, arg2 = os.pullEvent("websocket_message")

                    if arg2 == "jsConnected" then
                        jsConnected = true
                        event, arg1, arg2 = os.pullEvent("websocket_message")
                    elseif arg2 == "jsDisconnect" then
                        jsConnected = false
                        event, arg1, arg2 = os.pullEvent("websocket_message")
                    end
                    song_data = textutils.unserializeJSON(arg2)
                    audio_url = song_data["audio_file"]
                    img_url = song_data["album_img"]
                    song_content = download_audio(audio_url) -- Download new audio
                    img_palette = textutils.unserialize(song_data["palette"])

                    img = get_album_img(img_url)
                    album_canvas = load_album(img, img_palette)
                    album_canvas = playButton.add_playback_buttons(playing_img, album_canvas, box, next_img, prev_img)
                    box:set_canvas(album_canvas)
                    box:render()
                end
                local function showLoading()
                    while true do
                        playButton.animation(box, album_canvas, pos)
                        box:set_canvas(album_canvas)
                        box:render()
                        pos = pos + 1
                        if pos == 10 then
                            pos = 1
                        end
                        sleep(0.25)
                    end
                end
                parallel.waitForAny(showLoading, checkMsg)

                -- payload, state = play_audio(song_content, 1)
                payload, state = play_audio(song_content, 1, audio_url)
            elseif song_content and state == "paused" then
                speaker.stop() -- Stop current playback
                album_canvas = playButton.add_playback_buttons(paused_img, album_canvas, box, next_img, prev_img)
                box:set_canvas(album_canvas)
                box:render()
                local function checkUnpause()
                    while true do
                        local event, side, x, y = os.pullEvent("monitor_touch")
                        if x >= start_x and x <= end_x and y >= start_y and y <= end_y then
                            album_canvas = playButton.add_playback_buttons(playing_img, album_canvas, box, next_img, prev_img)
                            break
                        end
                    end
                end
                local function checkMsg()
                    local event, arg1, arg2 = os.pullEvent("websocket_message")
                    if arg2 == "jsConnected" then
                        jsConnected = true
                        event, arg1, arg2 = os.pullEvent("websocket_message")
                    elseif arg2 == "jsDisconnect" then
                        jsConnected = false
                        event, arg1, arg2 = os.pullEvent("websocket_message")
                    end

                    song_data = textutils.unserializeJSON(arg2)
                    audio_url = song_data["audio_file"]
                    img_url = song_data["album_img"]
                    song_content = download_audio(audio_url) -- Download new audio
                    img_palette = textutils.unserialize(song_data["palette"])

                    img = get_album_img(img_url)
                    album_canvas = load_album(img, img_palette)
                    album_canvas = playButton.add_playback_buttons(playing_img, album_canvas, box, next_img, prev_img)
                    payload = 1
                end
                parallel.waitForAny(checkUnpause, checkMsg)
                box:set_canvas(album_canvas)
                box:render()
                payload, state = play_audio(song_content, payload, audio_url)
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
local function main()
    repeat
    -- this is also only called once, most of the event checking is done in the play_audio function
    -- make THIS ONE never time out.
    local event, socketUrl, message = os.pullEvent("websocket_message")
    if message == "jsConnectedOnInit" or message == "jsConnected" then
        jsConnected = true
    elseif socketUrl == myURL then
        handle_websocket_message(message)
    end
    until terminate
end

local ok, errorMessage = pcall(main)

pcall(ws and ws.send("end") and ws.close or function()end)

  -- pcall the ws close function, if it has been created.

if not ok then
  printError(errorMessage) -- print the error like it normally would
end
