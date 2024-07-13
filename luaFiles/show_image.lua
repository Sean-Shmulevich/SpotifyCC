local pngImage = require("png")
local box = require("pixelbox_lite").new(term.current())
local monitor = peripheral.find("top")

local palette = {}


local colors = {0xa6a5cd, 0x090e6d, 0xfdfdfc, 0xcf7f41, 0x575da7, 0xf8cf8b, 0x35363d, 0x333994, 0xfab43e, 0x8283c0, 0x0a0b13, 0x929193, 0xc7c4da, 0x63646c, 0x131e88, 0xf2e6d6}

for i=0,15 do
    -- print(colors[i+1])
    term.setPaletteColor(2^i, colors[i+1])
    -- local defaultColor = term.getPaletteColor(2^i)
    palette[2^i] = {term.getPaletteColor(2^i)}
end


-- Load the PNG image
local img = paintutils.loadImage("test.nfp")
print(img)

-- Get the dimensions of the image
local img_width, img_height = #img[1], #img-1
print("Image dimensions: " .. img_width .. "x" .. img_height)
local term_width, term_height = box.width, box.height

-- Calculate new dimensions
local center_offset = math.floor((term_width - img_width)/2)

-- Print the scaled width and height

-- Function to get the scaled pixel
local function get_scaled_pixel(img, x, y, scale)
    local orig_x = math.floor(x / scale) + 1
    local orig_y = math.floor(y / scale) + 1

    -- Ensure coordinates are within bounds
    orig_x = math.max(1, math.min(orig_x, img.width))
    orig_y = math.max(1, math.min(orig_y, img.height))

    return img:get_pixel(orig_x, orig_y):unpack()
end


-- Create a bare canvas and set it up
-- local bare_canvas = pixelbox.make_canvas()
-- local usable_canvas = pixelbox.setup_canvas(box, bare_canvas)

for y = 1, img_height do
    for x = 1, img_width do
        -- local r,g,b = img:get_pixel(x,y):unpack()

        -- print(colors.toBlit(colors.packRGB(r,g,b)))
        -- print(find_closest_color(r*255, g*255, b*255))
        -- print(img[y][x])
    
        box.canvas[y][x] = img[y][x]
    end
end

-- Set the canvas and render the image on the terminal

box:render()
os.pullEvent("char")
-- Print the RGB values of the first pixel
-- local r, g, b, a = img:get_pixel(1, 1):unpack()
-- print(("Pixel 1,1 has the colors r:%d g:%d b:%d a:%d"):format(r * 255, g * 255, b * 255, a * 255))