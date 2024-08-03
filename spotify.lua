
local args = {...}
local userHash = args[1]
local baseURL = "amused-consideration-production.up.railway.app"
local terminalMode = false

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

-- lzw.lua

local char = string.char
local type = type
local tconcat = table.concat

local basedictcompress = {}
local basedictdecompress = {}
for i = 0, 255 do
    local ic, iic = char(i), char(i, 0)
    basedictcompress[ic] = iic
    basedictdecompress[iic] = ic
end

local function dictAddB(str, dict, a, b)
    if a >= 256 then
        a, b = 0, b + 1
        if b >= 256 then
            dict = {}
            b = 1
        end
    end
    dict[char(a, b)] = str
    a = a + 1
    return dict, a, b
end

local function decompress(input)
    if type(input) ~= "string" then
        return nil, "string expected, got " .. type(input)
    end

    if #input < 1 then
        return nil, "invalid input - not a compressed string"
    end

    local control = input:sub(1, 1)
    if control == "u" then
        return input:sub(2)
    elseif control ~= "c" then
        return nil, "invalid input - not a compressed string"
    end
    input = input:sub(2)
    local len = #input

    if len < 2 then
        return nil, "invalid input - not a compressed string"
    end

    local dict = {}
    local a, b = 0, 1

    local result = {}
    local n = 1
    local last = input:sub(1, 2)
    result[n] = basedictdecompress[last] or dict[last]
    if not result[n] then
        return nil, "could not find last from dict. Invalid input?"
    end
    n = n + 1

    for i = 3, len, 2 do
        local code = input:sub(i, i + 1)
        local lastStr = basedictdecompress[last] or dict[last]
        if not lastStr then
            return nil, "could not find last from dict. Invalid input?"
        end
        local toAdd = basedictdecompress[code] or dict[code]
        if toAdd then
            result[n] = toAdd
            n = n + 1
            dict, a, b = dictAddB(lastStr .. toAdd:sub(1, 1), dict, a, b)
        else
            local tmp = lastStr .. lastStr:sub(1, 1)
            result[n] = tmp
            n = n + 1
            dict, a, b = dictAddB(tmp, dict, a, b)
        end
        last = code
    end
    return tconcat(result)
end
--lzw.lua end
--- PLAYBUTTON AND SKIP BUTTONS UTILS
local function calculateHeight(box)
    local monitor_width, monitor_height = box.width, box.height

    local smaller_dimention = monitor_height
    local smaller_img_dimention = 640

    if monitor_height > monitor_width then
        smaller_dimention = monitor_width
    end

    smaller_dimention = smaller_dimention*0.9
    local pixel_size = math.floor(smaller_img_dimention/smaller_dimention) + 1
    local actual_img_dimentions = math.floor(smaller_img_dimention/pixel_size)
    local space_left = monitor_height - actual_img_dimentions
    if space_left < 10 then
        return 11
    elseif space_left >= 35 then
        return 35
    end
    return space_left
end

local function load_img_sized(img_name, imageSize)
    local img_url = "https://amused-consideration-production.up.railway.app/luaImages/" .. img_name .."_" .. tostring(imageSize) .. ".lzw"
    local compressed_img_data = httpGetWrapper(img_url)
    -- print("Downloading image from " .. img_url)

    local decompressed_data, err = decompress(compressed_img_data)
    return paintutils.parseImage(decompressed_data)
end

local function load_img(img_name)
    local img_url = "https://amused-consideration-production.up.railway.app/luaImages/" .. img_name .. ".lzw"
    local compressed_img_data = httpGetWrapper(img_url)
    -- print("Downloading image from " .. img_url)

    local decompressed_data, err = decompress(compressed_img_data)
    return paintutils.parseImage(decompressed_data)
end



local function add_playback_buttons(img, temp_canvas, box, next_song, prev_song)
    local img_width, img_height = #img[1], #img-1

    local media_button_width, media_button_height, media_button_offset, next_start, prev_start
    local start_y = math.floor(box.height - img_height) - 3
    local start_x = math.floor((box.width - img_width)/2)
    --next song icon and prev size icons are the same.
    if next_song ~= nil and prev_song ~= nil then
        media_button_width, media_button_height = #next_song[1], #next_song-1
        media_button_offset = math.floor(box.width/10)
        next_start = start_x + media_button_width + media_button_offset
        prev_start = start_x - media_button_width - media_button_offset
    end


    -- for this to work, the height, width of the largest image needs to be used.
    for y = 1, img_height do
        for x = 1, img_width do
            if next_song ~= nil and prev_song ~= nil then
                if x < media_button_width and y < media_button_height  then
                    temp_canvas[y+start_y][x+prev_start] = prev_song[y][x]
                    temp_canvas[y+start_y][x+next_start] = next_song[y][x]
                end
            end
            temp_canvas[y+start_y][x+start_x] = colors.black -- clear before rewriting.
            temp_canvas[y+start_y][x+start_x] = img[y][x]
        end
    end
    return temp_canvas
end

local animation_canvas = {}
for i=1,9 do
    local img = load_img("load"..tostring(i))
    animation_canvas[i] = img
end

local function animation(box, temp_canvas, pos)

    local img = animation_canvas[pos]
    local img_width, img_height = #img[1], #img-1
    local start_y = math.floor(box.height - img_height + 4)
    local start_x = math.floor((box.width - img_width)/2)
    for y = 1, img_height do
        for x = 1, img_width do
            temp_canvas[y+start_y][x+start_x] = colors.black
            temp_canvas[y+start_y][x+start_x] = img[y][x]
        end
    end
    -- box:set_canvas(temp_canvas)
    -- return usable_canvas
end

local function get_touch_boundry(img, loc, box)

    local img_width, img_height = #img[1], #img-1
    -- default middle bottom.
    local start_y = math.floor(( math.floor(box.height - img_height))/3)
    local start_x = math.floor((box.width - img_width)/4)

    local media_offset = math.floor(box.width/10)
    if loc == "top" then
        start_y = 0
    elseif loc == "left" then
        start_x = math.floor((( start_x*2 ) - img_width - media_offset)/2)
    elseif loc == "right" then
        start_x = math.floor((( start_x*2 ) + img_width + media_offset)/2)
    end


    return start_x, start_y, start_x + math.floor(img_width/2), start_y + math.floor(img_height/3)
end
-- PLAYBUTTON UTILS END

local pixelbox = {initialized=false}
local function makePixelBox()
    local box_object = {}

    local t_cat  = table.concat

    local sampling_lookup = {
        {2,3,4,5,6},
        {4,1,6,3,5},
        {1,4,5,2,6},
        {2,6,3,5,1},
        {3,6,1,4,2},
        {4,5,2,3,1}
    }

    local texel_character_lookup  = {}
    local texel_foreground_lookup = {}
    local texel_background_lookup = {}
    local to_blit = {}

    local function generate_identifier(s1,s2,s3,s4,s5,s6)
        return  s2 * 1 +
                s3 * 3 +
                s4 * 4 +
                s5 * 20 +
                s6 * 100
    end

    local function calculate_texel(v1,v2,v3,v4,v5,v6)
        local texel_data = {v1,v2,v3,v4,v5,v6}

        local state_lookup = {}
        for i=1,6 do
            local subpixel_state = texel_data[i]
            local current_count = state_lookup[subpixel_state]

            state_lookup[subpixel_state] = current_count and current_count + 1 or 1
        end

        local sortable_states = {}
        for k,v in pairs(state_lookup) do
            sortable_states[#sortable_states+1] = {
                value = k,
                count = v
            }
        end

        table.sort(sortable_states,function(a,b)
            return a.count > b.count
        end)

        local texel_stream = {}
        for i=1,6 do
            local subpixel_state = texel_data[i]

            if subpixel_state == sortable_states[1].value then
                texel_stream[i] = 1
            elseif subpixel_state == sortable_states[2].value then
                texel_stream[i] = 0
            else
                local sample_points = sampling_lookup[i]
                for sample_index=1,5 do
                    local sample_subpixel_index = sample_points[sample_index]
                    local sample_state          = texel_data   [sample_subpixel_index]

                    local common_state_1 = sample_state == sortable_states[1].value
                    local common_state_2 = sample_state == sortable_states[2].value

                    if common_state_1 or common_state_2 then
                        texel_stream[i] = common_state_1 and 1 or 0

                        break
                    end
                end
            end
        end

        local char_num = 128
        local stream_6 = texel_stream[6]
        if texel_stream[1] ~= stream_6 then char_num = char_num + 1  end
        if texel_stream[2] ~= stream_6 then char_num = char_num + 2  end
        if texel_stream[3] ~= stream_6 then char_num = char_num + 4  end
        if texel_stream[4] ~= stream_6 then char_num = char_num + 8  end
        if texel_stream[5] ~= stream_6 then char_num = char_num + 16 end

        local state_1,state_2
        if #sortable_states > 1 then
            state_1 = sortable_states[  stream_6+1].value
            state_2 = sortable_states[2-stream_6  ].value
        else
            state_1 = sortable_states[1].value
            state_2 = sortable_states[1].value
        end

        return char_num,state_1,state_2
    end

    local function base_n_rshift(n,base,shift)
        return math.floor(n/(base^shift))
    end

    local real_entries = 0
    local function generate_lookups()
        for i = 0, 15 do
            to_blit[2^i] = ("%x"):format(i)
        end

        for encoded_pattern=0,6^6 do
            local subtexel_1 = base_n_rshift(encoded_pattern,6,0) % 6
            local subtexel_2 = base_n_rshift(encoded_pattern,6,1) % 6
            local subtexel_3 = base_n_rshift(encoded_pattern,6,2) % 6
            local subtexel_4 = base_n_rshift(encoded_pattern,6,3) % 6
            local subtexel_5 = base_n_rshift(encoded_pattern,6,4) % 6
            local subtexel_6 = base_n_rshift(encoded_pattern,6,5) % 6

            local pattern_lookup = {}
            pattern_lookup[subtexel_6] = 5
            pattern_lookup[subtexel_5] = 4
            pattern_lookup[subtexel_4] = 3
            pattern_lookup[subtexel_3] = 2
            pattern_lookup[subtexel_2] = 1
            pattern_lookup[subtexel_1] = 0

            local pattern_identifier = generate_identifier(
                pattern_lookup[subtexel_1],pattern_lookup[subtexel_2],
                pattern_lookup[subtexel_3],pattern_lookup[subtexel_4],
                pattern_lookup[subtexel_5],pattern_lookup[subtexel_6]
            )

            if not texel_character_lookup[pattern_identifier] then
                real_entries = real_entries + 1
                local character,sub_state_1,sub_state_2 = calculate_texel(
                    subtexel_1,subtexel_2,
                    subtexel_3,subtexel_4,
                    subtexel_5,subtexel_6
                )

                local color_1_location = pattern_lookup[sub_state_1] + 1
                local color_2_location = pattern_lookup[sub_state_2] + 1

                texel_foreground_lookup[pattern_identifier] = color_1_location
                texel_background_lookup[pattern_identifier] = color_2_location

                texel_character_lookup[pattern_identifier] = string.char(character)
            end
        end
    end

    function pixelbox.make_canvas(source_table)
        local dummy_OOB = {}
        return setmetatable(source_table or {},{__index=function()
            return dummy_OOB
        end})
    end

    function pixelbox.setup_canvas(box,canvas_blank,color)
        for y=1,box.height do
            if not rawget(canvas_blank,y) then rawset(canvas_blank,y,{}) end

            for x=1,box.width do
                canvas_blank[y][x] = color
            end
        end

        return canvas_blank
    end

    function pixelbox.restore(box,color,keep_existing)
        if not keep_existing then
            local new_canvas = pixelbox.setup_canvas(box,pixelbox.make_canvas(),color)

            box.canvas = new_canvas
            box.CANVAS = new_canvas
        else
            pixelbox.setup_canvas(box,box.canvas,color)
        end
    end

    local color_lookup  = {}
    local texel_body    = {0,0,0,0,0,0}
    function box_object:render()
        local t = self.term
        local blit_line,set_cursor = t.blit,t.setCursorPos

        local canv = self.canvas

        local char_line,fg_line,bg_line = {},{},{}

        local width,height = self.width,self.height

        local sy = 0
        for y=1,height,3 do
            sy = sy + 1
            local layer_1 = canv[y]
            local layer_2 = canv[y+1]
            local layer_3 = canv[y+2]

            local n = 0
            for x=1,width,2 do
                local xp1 = x+1
                local b1,b2,b3,b4,b5,b6 =
                    layer_1[x],layer_1[xp1],
                    layer_2[x],layer_2[xp1],
                    layer_3[x],layer_3[xp1]

                local char,fg,bg = " ",1,b1

                local single_color = b2 == b1
                                and  b3 == b1
                                and  b4 == b1
                                and  b5 == b1
                                and  b6 == b1

                if not single_color then
                    color_lookup[b6] = 5
                    color_lookup[b5] = 4
                    color_lookup[b4] = 3
                    color_lookup[b3] = 2
                    color_lookup[b2] = 1
                    color_lookup[b1] = 0

                    local pattern_identifier =
                        color_lookup[b2]       +
                        color_lookup[b3] * 3   +
                        color_lookup[b4] * 4   +
                        color_lookup[b5] * 20  +
                        color_lookup[b6] * 100

                    local fg_location = texel_foreground_lookup[pattern_identifier]
                    local bg_location = texel_background_lookup[pattern_identifier]

                    texel_body[1] = b1
                    texel_body[2] = b2
                    texel_body[3] = b3
                    texel_body[4] = b4
                    texel_body[5] = b5
                    texel_body[6] = b6

                    fg = texel_body[fg_location]
                    bg = texel_body[bg_location]

                    char = texel_character_lookup[pattern_identifier]
                end

                n = n + 1
                char_line[n] = char
                fg_line  [n] = to_blit[fg]
                bg_line  [n] = to_blit[bg]
            end

            set_cursor(1,sy)
            blit_line(
                t_cat(char_line,""),
                t_cat(fg_line,  ""),
                t_cat(bg_line,  "")
            )
        end
    end

    function box_object:clear(color)
        pixelbox.restore(self,to_blit[color or ""] and color or self.background,true)
    end

    function box_object:set_pixel(x,y,color)
        self.canvas[y][x] = color
    end

    function box_object:set_canvas(canvas)
        self.canvas = canvas
        self.CANVAS = canvas
    end

    function box_object:resize(w,h,color)
        self.term_width  = w
        self.term_height = h
        self.width  = w*2
        self.height = h*3

        pixelbox.restore(self,color or self.background,true)
    end

    function box_object:analyze_buffer()
        local canvas = self.canvas
        if not canvas then
            error("Box missing canvas. Possible to regenerate with\n\npixelbox.restore(box,box.background)",0)
        end

        for y=1,self.height do
            local row = canvas[y]
            if not row then
                error(("Box is missing a pixel row: %d"):format(y),0)
            end

            for x=1,self.width do
                local pixel = row[x]
                if not pixel then
                    error(("Box is missing a pixel at:\n\nx:%d y:%d"):format(x,y),0)
                elseif not to_blit[pixel] then
                    error(("Box has an invalid pixel at:\n\nx:%d y:%d. Value: %s"):format(x,y,pixel),0)
                end
            end
        end

        return true
    end

    function pixelbox.new(terminal,bg)
        local box = {}

        box.background = bg or terminal.getBackgroundColor()

        local w,h = terminal.getSize()
        box.term  = terminal

        setmetatable(box,{__index = box_object})

        box.term_width  = w
        box.term_height = h
        box.width       = w*2
        box.height      = h*3

        pixelbox.restore(box,box.background)

        if not pixelbox.initialized then
            generate_lookups()

            pixelbox.initialized = true
        end

        return box
    end

    return pixelbox
end

--- START MUSIC PLAYER LOGIC
local function userHashOk(hash)
    local checkHashOk = httpGetWrapper("https://"..baseURL .. "/checkHash/" .. hash)
    if checkHashOk then
        checkHashOk = textutils.unserialize(checkHashOk)
    end
    if checkHashOk == "ok" then
        return true
    end
    return false
end

local speaker = peripheral.find("speaker")
if not speaker then
    print("No speaker found. Please attach a speaker.")
    return
end

if not userHash then
    print("userHash not provided check the website for your user hash, press any key to continue.")
    os.pullEvent("key")
    do return end
end

if not userHashOk(userHash) then
    print("userHash provided is invalid, please check the website for your correct user hash, press any key to continue")
    os.pullEvent("key")
    do return end
end

local monitor = nil
local playerModeOrLoc = args[2]
local playerMode = "monitor"
local monitorLocation = "top"
-- has monitor attached and no arg3.   
local peripheralArr = { "top", "left", "right", "back", "front", "bottom" }

local function tableContains(table, value)
  for i = 1,#table do
    if (table[i] == value) then
      return true
    end
  end
  return false
end

if playerModeOrLoc then
    if tableContains(peripheralArr, playerModeOrLoc) then
        monitorLocation = playerModeOrLoc
    elseif playerModeOrLoc == "term" or playerModeOrLoc == "terminal" then
        playerMode = "terminal"
    elseif playerModeOrLoc == "monitor" and args[3] then
        if tableContains(peripheralArr, arg[3]) then
            monitorLocation = arg[3]
        else
            print("Invalid argument #3 \""..arg[3].."\"" .. " must be monitor location\n 'top', 'left', 'right', 'back', 'front', 'bottom'")
            do return end
        end
    else
        print("Invalid argument #2 \""..playerModeOrLoc.."\"")
        do return end
    end
end

if playerMode == "monitor" then
    for i,v in pairs(peripheralArr) do
        local peripheralType = peripheral.getType(v)
        if peripheralType and peripheralType == "monitor" then
            if monitorLocation and monitorLocation == v then
                monitor = peripheral.wrap(v)
                print("found specified monitor ".. v)
                break
            end
        end
    end
end

-- for playermode terminal, dont show the media buttons.
if playerMode == "terminal" then
    term.clear()
    terminalMode = true
elseif monitor ~= nil and playerMode == "monitor" then
    monitor.setTextScale(0.5)
    term.redirect(monitor)
elseif monitor == nil and playerMode == "monitor" then
    print("monitor not found press key to end the program\n tip: run 'spotify your_unique_id terminal' to run without monitors\nexample command: spotify 20e44229 terminal")
    os.pullEvent("key")
    do return end
end
-- call validate hash endpoint.
local myURL = string.format("wss://%s/ws/luaclient/%s", baseURL, userHash)
local dfpwm = require("cc.audio.dfpwm")

pixelbox = makePixelBox()
local box = pixelbox.new(term.current())

box:clear(colors.black)
box:render()

local terminate = false
local jsConnected = false

local mediaSize = calculateHeight(box)
local paused_img, playing_img, next_img, prev_img
local next_start_x, next_start_y, next_end_x, next_end_y
local prev_start_x, prev_start_y, prev_end_x, prev_end_y
local start_x, start_y, end_x, end_y

paused_img = load_img_sized("paused", mediaSize)
playing_img = load_img_sized("playing", mediaSize)
if not terminalMode then
    next_img = load_img_sized("next", mediaSize)
    prev_img = load_img_sized("prev", mediaSize)
    start_x, start_y, end_x, end_y = get_touch_boundry(playing_img, "bottom-middle",box)
    prev_start_x, prev_start_y, prev_end_x, prev_end_y = get_touch_boundry(playing_img, "left",box)
    next_start_x, next_start_y, next_end_x, next_end_y = get_touch_boundry(paused_img, "right",box)
end


local ws = assert(http.websocket(myURL))
ws.send(tostring(box.width) .." ".. tostring(box.height))
-- Ensure the speaker peripheral is attached

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
    local decompressed_data, err = decompress(compressed_img_data)
    return paintutils.parseImage(decompressed_data)
end


local function play_audio(content, chunk_start, url)
    local decoder = dfpwm.make_decoder()
    local chunk_size = 16 * 1024
    local chunk_idx = chunk_start
    local playback_state = "playing"
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
            elseif skipOnce and ( event == "monitor_touch" or event =="key" ) and playback_state ~= "paused" then
                -- how to get it to know when it stops
                local key = arg1
                local x = arg2
                local y = arg3
                if event == "key" then
                    key = keys.getName(key)
                end
                if terminalMode and key=="space" or event~="key" and x >= start_x and x <= end_x and y >= start_y and y <= end_y then
                    playback_state = "paused"
                    -- each loop iteration takes about 2.6 seconds to run.
                    local chunk_pause = os.epoch("utc") / 1000

                    -- this code is fucked up but it came from a lot of testing.
                    local percent = 1 + (((chunk_pause - startTime) / 2.65))

                    if(percent < 1.4) then
                        percent = 3 - percent
                    end
                    return math.floor(chunk_idx - (chunk_size * percent)), "paused"
                elseif terminalMode and key=="right" or event~="key" and x >= next_start_x and x <= next_end_x and y >= next_start_y and y <= next_end_y then
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
                elseif terminalMode and key=="left" or event~="key" and x >= prev_start_x and x <= prev_end_x and y >= prev_start_y and y <= prev_end_y then
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
    spotify_next_track()

    -- send skip to next song on spotify
    return nil
end

local function setPaletteColors(colors)
    for i=0,15 do
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

            temp_canvas[y][x+center_offset] = img[y][x]
        end
    end
    return temp_canvas
end



-- I want to make it so that when you skip a song, 
-- The web player pauses until speaker.playAudio is called for the first time.

-- runs the song until websocket message is recieved then stops the current song and plays the song that is the target of the new message, the message being a link to an audio file on the python server.
local function next_song_setup(song_data, pause)
    local img_palette = textutils.unserialize(song_data["palette"])
    local img_url = song_data["album_img"]
    local audio_url = song_data["audio_file"]
    -- try streaming the image using LZW.
    local img = get_album_img(img_url)

    local album_canvas = load_album(img, img_palette)
    local state_img = playing_img
    if pause ~= nil then
        state_img = paused_img
    end
    if not terminalMode then
        album_canvas = add_playback_buttons(state_img, album_canvas, box, next_img, prev_img)
    else
        album_canvas = add_playback_buttons(state_img, album_canvas, box)
    end
    box:set_canvas(album_canvas)
    box:render()
    return img, img_palette, album_canvas, audio_url, img_url
end
local function handle_websocket_message(message)
    -- i think i can omit this
    speaker.stop() -- Stop any currently playing audio

    
    local song_data = textutils.unserializeJSON(message)

    local audio_url = song_data["audio_file"]
    local img_url = song_data["album_img"]
    local song_content = download_audio(audio_url)
    local payload, state, img, img_palette, album_canvas

    if song_content then
        img, img_palette, album_canvas, audio_url, img_url = next_song_setup(song_data)
        payload, state = play_audio(song_content, 1, audio_url)

        while payload do
            if song_content and state == "newSong" then
                speaker.stop() -- Stop current playback

                song_data = textutils.unserializeJSON(payload)
                img, img_palette, album_canvas, audio_url, img_url = next_song_setup(song_data)
                song_content = download_audio(audio_url) -- Download new audio
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
                    song_content = download_audio(song_data['audio_file']) -- Download new audio
                    img, img_palette, album_canvas, audio_url, img_url = next_song_setup(song_data)
                end
                local function showLoading()
                    while true do
                        animation(box, album_canvas, pos)
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
                if not terminalMode then
                    album_canvas = add_playback_buttons(paused_img, album_canvas, box, next_img, prev_img)
                else
                    album_canvas = add_playback_buttons(paused_img, album_canvas, box)
                end
                box:set_canvas(album_canvas)
                box:render()
                local function checkUnpause()
                    while true do
                        local event, side, x, y
                        local key = nil
                        if not terminalMode then
                            event, side, x, y = os.pullEvent("monitor_touch")
                        else
                            event, side, x, y = os.pullEvent("key")
                            key = keys.getName(side)
                            while key ~= "space" do
                                print("press space to unpause")
                                event, side, x, y = os.pullEvent("key")
                                key = keys.getName(side)
                            end

                        end
                        if key=="space" or x >= start_x and x <= end_x and y >= start_y and y <= end_y then
                            if not terminalMode then
                                album_canvas = add_playback_buttons(playing_img, album_canvas, box, next_img, prev_img)
                            else
                                album_canvas = add_playback_buttons(playing_img, album_canvas, box)
                            end
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
                    img, img_palette, album_canvas, audio_url, img_url = next_song_setup(song_data)
                    song_content = download_audio(audio_url) -- Download new audio
                    payload = 1 -- start song from the beginning.
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
