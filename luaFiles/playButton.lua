-- upload play and pause images to the bucket and draw/redraw.
local lzw = require("lzw")
local pixelbox = require("pixelbox_lite")

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
        return 10
    elseif space_left >= 35 then
        return 35
    end
    return space_left
end

local function load_img_sized(img_name, imageSize)
    local img_url = "https://amused-consideration-production.up.railway.app/luaImages/" .. img_name .."_" .. tostring(imageSize) .. ".lzw"
    local compressed_img_data = httpGetWrapper(img_url)
    -- print("Downloading image from " .. img_url)

    local decompressed_data, err = lzw.decompress(compressed_img_data)
    return paintutils.parseImage(decompressed_data)
end

local function load_img(img_name)
    local img_url = "https://amused-consideration-production.up.railway.app/luaImages/" .. img_name .. ".lzw"
    local compressed_img_data = httpGetWrapper(img_url)
    -- print("Downloading image from " .. img_url)

    local decompressed_data, err = lzw.decompress(compressed_img_data)
    return paintutils.parseImage(decompressed_data)
end



local function add_playback_buttons(img, temp_canvas, box, next_song, prev_song)
    local img_width, img_height = #img[1], #img-1

    local media_button_width, media_button_height, media_button_offset, next_start, prev_start
    local start_y = math.floor(box.height - img_height)
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


return {
    get_touch_boundry = get_touch_boundry,
    animation = animation,
    load_img = load_img,
    load_img_sized = load_img_sized,
    calculateHeight = calculateHeight,
    add_playback_buttons = add_playback_buttons
}
