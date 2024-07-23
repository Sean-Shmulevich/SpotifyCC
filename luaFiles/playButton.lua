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



local function load_img(img_name)
    local img_url = "https://amused-consideration-production.up.railway.app/assets/" .. img_name .. ".lzw"
    local compressed_img_data = httpGetWrapper(img_url)
    -- print("Downloading image from " .. img_url)

    local decompressed_data, err = lzw.decompress(compressed_img_data)
    return paintutils.parseImage(decompressed_data)
end


local next_song = load_img("next")
local prev_song = load_img("prev")

local function add_playback_buttons(img, temp_canvas, box)
    local img_width, img_height = #img[1], #img-1

    --next song icon and prev size icons are the same.
    local media_button_width, media_button_height = #next_song[1], #next_song-1

    local start_y = math.floor(box.height - img_height)
    local start_x = math.floor((box.width - img_width)/2)

    local next_start = start_x + media_button_width + 32
    local prev_start = start_x - media_button_width - 32

    -- for this to work, the height, width of the largest image needs to be used.
    for y = 1, img_height do
        for x = 1, img_width do
            if x < media_button_width and y < media_button_height  then
                temp_canvas[y+start_y][x+prev_start] = prev_song[y][x]
                temp_canvas[y+start_y][x+next_start] = next_song[y][x]
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

    if loc == "top" then
        start_y = 0
    elseif loc == "left" then
        start_x = math.floor((( start_x*2 ) - img_width - 32)/2)
    elseif loc == "right" then
        start_x = math.floor((( start_x*2 ) + img_width + 32)/2)
    end


    return start_x, start_y, start_x + math.floor(img_width/2), start_y + math.floor(img_height/3)
end


return {
    get_touch_boundry = get_touch_boundry,
    animation = animation,
    load_img = load_img,
    add_playback_buttons = add_playback_buttons
}
