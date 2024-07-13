-- CC: Tweaked script for audio player
-- Monitors optional (recommend advanced)
-- If the computer is not advanced, you must have at least 1 advanced monitor setup
-- At least 1 speaker should be used
-- Works with advanced noisy pocket computers

-- Audio files MUST be proper dfpwm files
-- You can convert files using sites like https://music.madefor.cc/
-- Files can be stored anywhere on the computer including a disk (keep in mind file sizes may max out a disk / computer)

-- Monitor setups
-- Simple (Display current song and controls)
-- XX

-- Controls + Queue
-- XXXX

-- Controls + File Select
-- XX
-- XX

-- Everything
-- XXXX
-- XXXX

local dfpwm = require("cc.audio.dfpwm")
-- Speakers & Monitor
local speakers = { peripheral.find("speaker") }
local monitors = {}
local termPage = 1

function populateMonitors()
    local Ms = { peripheral.find("monitor") }
    monitors = {}
    for i,v in pairs(Ms) do
        table.insert(monitors, {
            ["monitor"] = v,
            ["page"] = 1
        })
    end
end

-- Music Player Enum
local PlayStates = {
    PLAYING = 1,
    PAUSED = 2,
    STOPPED = 3
}
local PlayStatesNames = {
    [PlayStates.PLAYING] = "Playing",
    [PlayStates.PAUSED] = "Paused",
    [PlayStates.STOPPED] = "Stopped"
}
local playState = PlayStates.STOPPED
local PlayModes = {
    NORMAL = 1,
    SINGLE = 2,
    LOOP = 3
}
local PlayModesNames = {
    [PlayModes.NORMAL] = "Normal",
    [PlayModes.SINGLE] = "Single",
    [PlayModes.LOOP] = "Loop"
}
local playMode = PlayModes.NORMAL

local statusText = ""

local displayingQueue = false


-- Current Song
local currentSong = nil
local buffer = {}
local songLength = 0
local songPosition = 0
local queue = {}

-- Loader
local loading = false

function testMediaControls(x,y, monitor)
    if y == 2 then -- Audio controls
        if x >= 2 and x <= 8 then
            if playState == PlayStates.PLAYING then
                playState = PlayStates.PAUSED
            elseif playState == PlayStates.PAUSED then
                playState = PlayStates.PLAYING
            end
            
        elseif x >= 12 and x <= 18 then
            if queue[1] then
                playSong(queue[1])
                table.remove(queue, 1)
            else
                playState = PlayStates.STOPPED
                buffer = {}
                songLength = 0
                songPosition = 0
                currentSong = nil
            end
        end
    end
    if y == 4 then -- Mode controls
        local x2
        if monitor then
            x2 = 18
        else
            x2 = 25
        end
        if x >= 1 and x <= x2 then
            if playMode == PlayModes.NORMAL then
                playMode = PlayModes.SINGLE
            elseif playMode == PlayModes.SINGLE then
                playMode = PlayModes.LOOP
            elseif playMode == PlayModes.LOOP then
                playMode = PlayModes.NORMAL
            end
        end
    end
end

function testQueueControls(x,y)
    local tx, ty = term.getSize()
    if tx > 27 then
        return
    end
    if y == 2 then
        if x >= 19 and x <= 25 then
            displayingQueue = not displayingQueue
        end
    end
end

-- Event triggers
local events = {
    ["speaker_audio_empty"] = function()
    end,
    ["timer"] = function()
    end,
    ["key"] = function(_, key, held)
        if held then 
            print("Key held: " .. key)
            return
        end
        if key == 92 then -- Kill
            playState = PlayStates.STOPPED
            for _,v in pairs(speakers) do
                v.stopAudio()
            end
        else
            print("Key: " .. key)
        end
    end,
    ["char"] = function(_, char)
        if char == "l" then
            loadDemo()
        end
    end,
    ["peripheral"] = function(_)
        speakers = { peripheral.find("speaker") }
        populateMonitors()
    end,
    ["monitor_touch"] = function(_, side, x, y)
        print("Monitor touch: " .. x .. ", " .. y, side)
        testMediaControls(x,y, true)
        if y >= 8 then
            selectDirectory(x,y-8, side)
        end
    end,
    ["mouse_click"] = function(_, side, x, y)
        print("Mouse click: " .. x .. ", " .. y)
        testMediaControls(x,y)
        testQueueControls(x,y)
        if y >= 9 and y <= 15 then
            selectDirectory(x,y-9)
        end
    end,
    ["mouse_up"] = function() end,
    ["mouse_drag"] = function() end,
    ["mouse_scroll"] = function() end,
    ["mouse_down"] = function() end
}

function handleEvents()
    while true do
        local e = { os.pullEvent() }
        if events[e[1]] then
            events[e[1]](unpack(e))
        else
            print("Unknown event: " .. e[1])
            print(unpack(e))
            -- for i,v in pairs(unpack(event)) do
            --     print("Arg " .. i .. ": " .. v)
            -- end
        end
    end
end

-- Player Functions
function playNextBuffer()
    while true do
        if playState == PlayStates.PLAYING then
            if buffer[1] then
                local currentBuffer = buffer[1]
                songPosition = songPosition + 1
                table.remove(buffer, 1)
                -- print("Playing buffer " .. songPosition .. "/" .. songLength)
                for _,v in pairs(speakers) do
                    while not v.playAudio(currentBuffer, 1) do
                        os.sleep(0.1)
                        -- os.pullEvent("speaker_audio_empty")
                        -- waitForEvent("speaker_audio_empty")
                    end
                end
            else
                if playMode == PlayModes.SINGLE then
                    playSong(currentSong)
                elseif playMode == PlayModes.LOOP then
                    table.insert(queue, currentSong)
                    playSong(queue[1])
                    table.remove(queue, 1)
                else
                    if queue[1] then
                        playSong(queue[1])
                        table.remove(queue, 1)
                    else
                        currentSong = nil
                        buffer = {}
                        songLength = 0
                        songPosition = 0
                        playState = PlayStates.STOPPED
                    end
                end
            end
        end
        os.sleep(0.1)
    end
end
function playSong(song)
    -- if currentSong then
    --     os.sleep(5) -- Let buffer play out
    -- end
    -- buffer = song.buffer
    -- Copy the buffer table to a new table
    buffer = {}
    for i,v in pairs(song.buffer) do
        buffer[i] = v
    end
    songLength = #buffer
    songPosition = 0
    currentSong = song
    playState = PlayStates.PLAYING
end
function queueSong(song)
    table.insert(queue, song)
    if playState == PlayStates.STOPPED or not currentSong then
        playSong(queue[1])
        table.remove(queue, 1)
    end
end
function createSong(file)
    if loading then
        return nil
    end
    loading = true
    local decoder = dfpwm.make_decoder()
    local song = {}
    song.buffer = {}
    song.name = file
    -- print("Loading DFPWM song from file: " .. file)
    statusText = "Loading " .. file
    for chunk in io.lines(file, 16 * 1024) do
        table.insert(song.buffer, decoder(chunk))
        parallel.waitForAny(handleEvents, function()
            os.sleep(0)
        end)
    end
    statusText = ""
    loading = false
    return song
end

-- Directory Handling
local currentDir = "/"
local currentFileList = {}

function drawDirectory()
    for i,M in pairs(monitors) do
        local monitor = M.monitor
        monitor.setCursorPos(1,7)
        -- Write "-" for the length of the first column
        local toWrite = ">" .. currentDir .. " "
        monitor.write(toWrite)
        for i=1,18 - #toWrite - 1 do
            monitor.write("-")
        end
        monitor.setCursorPos(1,8)
        monitor.write("Pages -")
        local x, y = monitor.getSize()
        local maxPerPage = y - 8
        local maxPages = math.ceil(#currentFileList / maxPerPage)
        for i=1,maxPages do
            monitor.write(" ")
            if i == M.page then
                monitor.setBackgroundColor(colors.green)
            else
                monitor.setBackgroundColor(colors.black)
            end
            monitor.write(tostring(math.floor(i)):gsub("%.0$", ""))
            monitor.setBackgroundColor(colors.black)
        end


        for i=1, maxPerPage do
            if currentFileList[i + maxPerPage * (M.page - 1)] then
                monitor.setCursorPos(1, i+8)
                monitor.write("|" .. scrollText(currentFileList[i + maxPerPage * (M.page - 1)], 16))
            else
                monitor.setCursorPos(1, i+8)
                monitor.write("| ")
            end
        end
    end

    term.setCursorPos(1,8)
    local toWrite = ">" .. currentDir .. " "
    term.write(toWrite)
    for i=1,25 - #toWrite - 1 do
        term.write("-")
    end
    term.setCursorPos(1,9)
    term.write("Pages -")
    local x, y = term.getSize()
    local maxPerPage = y - 9 - 5
    local maxPages = math.ceil(#currentFileList / maxPerPage)
    for i=1,maxPages do
        term.write(" ")
        if i == termPage then
            term.setBackgroundColor(colors.green)
        else
            term.setBackgroundColor(colors.black)
        end
        term.write(i)
        term.setBackgroundColor(colors.black)
    end

    for i=1, maxPerPage do
        if currentFileList[i + maxPerPage * (termPage - 1)] then
            term.setCursorPos(1, i+9)
            term.write("|" .. scrollText(currentFileList[i + maxPerPage * (termPage - 1)], 23))
        else
            term.setCursorPos(1, i+9)
            term.write("| ")
        end
    end
    term.setCursorPos(1, y - 3)
end

function populateDirectoryList()
    currentFileList = {}
    for i,v in pairs(monitors) do
        v.page = 1
    end
    local files = fs.list(currentDir)
    for i,v in pairs(files) do
        -- if the file is a directory or ends with .dfpwm
        if fs.isDir(currentDir .. "/" .. v) or string.match(v, ".dfpwm$") then
            table.insert(currentFileList, v)
        end
    end
    table.sort(currentFileList)
    if currentDir ~= "/" then
        table.insert(currentFileList, 1, "..")
    end
end

function selectDirectory(x,y, name)
    local M
    if name then
        for i,v in pairs(monitors) do
            if peripheral.getName(v.monitor) == name then
                M = v
                break
            end
        end
    else
        M = {
            ["monitor"] = term,
            ["page"] = termPage
        }
    end
    if not M then
        error("Monitor not found", name)
        return
    end
    print("Selected: " .. x .. ", " .. y)
    if y == 0 then
        local tx = x - 8
        -- tx is x cord on the monitor, 1 will be page 1, 2 is a blank space, 3 is page 2
        local page = math.floor(tx / 2) + 1
        M.page = page
        if not name then termPage = page end
        return
    end
    local tx, ty = M.monitor.getSize()
    local maxPerPage = ty - 8
    if not name then
        maxPerPage = maxPerPage - 6
    end
    -- i + maxPerPage * (page - 1)
    local selection = currentFileList[y + maxPerPage * (M.page - 1)]
    print("Selected:", selection, maxPerPage, M.page)
    if selection then
        if selection == ".." then
            -- Go up a directory
            currentDir = fs.getDir(currentDir)
            if currentDir == "" then
                currentDir = "/"
            end
            print("New dir: ", currentDir)
            populateDirectoryList()
        else
            local path = ""
            if currentDir == "/" then
                path = currentDir .. selection
            else
                path = currentDir .. "/" .. selection
            end
            if fs.isDir(path) then
                currentDir = path
                if currentDir == "" then
                    currentDir = "/"
                end
                populateDirectoryList()
            -- Check if file ends with .dfpwm
            elseif string.match(selection, ".dfpwm$") then
                local song = createSong(path)
                if not song then
                    return
                end
                queueSong(song)
            end
        end
    end
end


-- UI Functions

-- Clear the monitor
function clearMonitor()
    for _,M in pairs(monitors) do
        local monitor = M.monitor
        monitor.clear()
        monitor.setCursorPos(1, 1)
        monitor.write("Music Player")
        monitor.setCursorPos(1, 2)
        -- monitor.write("- <-  Play/Pause  -> ---------------------------------------------")
        monitor.write("-")
        if playState == PlayStates.PLAYING then
            monitor.setBackgroundColor(colors.green)
            monitor.write(" Pause ")
        elseif playState == PlayStates.PAUSED then
            monitor.setBackgroundColor(colors.orange)
            monitor.write(" Play  ")
        end
        monitor.setBackgroundColor(colors.black)
        monitor.write("---")
        if playState ~= PlayStates.STOPPED then
            monitor.setBackgroundColor(colors.lightBlue)
            monitor.write(" skip ")
        end
        monitor.setBackgroundColor(colors.black)
        monitor.write("---------------------------------------------------------------")
    end
    term.clear()
    term.setCursorPos(1, 1)
    print("Music Player")
    term.setCursorPos(1, 2)
    term.write("-")
    if playState == PlayStates.PLAYING then
        term.setBackgroundColor(colors.green)
        term.write(" Pause ")
    elseif playState == PlayStates.PAUSED then
        term.setBackgroundColor(colors.orange)
        term.write(" Play  ")
    else
        term.write("-------")
    end
    term.setBackgroundColor(colors.black)
    term.write("---")
    if playState ~= PlayStates.STOPPED then
        term.setBackgroundColor(colors.lightBlue)
        term.write(" skip ")
    else
        term.write("------")
    end
    term.setBackgroundColor(colors.black)
    term.write("-")
    local x, y = term.getSize()
    if x < 27 then
        term.setBackgroundColor(colors.brown)
        term.write(" Queue ")
    else
        term.write("-------")
    end
    term.setBackgroundColor(colors.black)
    term.write("-------------------------------------------------------")
end

function scrollText(text, length)
    if #text > length then
        local time = os.clock()
        local speed = 1 -- Speed of scroll per second
        local position = math.floor((time * speed) % (#text - (length - 2) )) --time % #text
        -- Prevent the text from scrolling completely off the screen
        position = math.min(position, #text - (length - 2))
        -- term.setCursorPos(1, )
        -- print("Position: " .. position .. " Time: " .. time .. " Speed: " .. speed .. " Length: " .. length .. " Text: " .. text)
        return string.sub(text, position, position + length)
    else
        return text
    end
end

function drawProgressBar(length, percentage)
    local bar = "["
    for i=1,length-2 do
        if i/length <= percentage then
            bar = bar .. "#"
        else
            bar = bar .. "-"
        end
    end
    bar = bar .. "]"
    return bar
end

function drawUI()
    print("Drawing UI")
    clearMonitor()
    for _,M in pairs(monitors) do
        local monitor = M.monitor
        monitor.setCursorPos(1, 3)
        local x, y = monitor.getSize()
        if currentSong then
            if playState == PlayStates.PLAYING then
                monitor.write("Playing: " .. scrollText(currentSong.name, math.min(9, x)))
            else
                monitor.write("Paused: " .. scrollText(currentSong.name, math.min(10, x)))
            end
        else
            monitor.write("Not Playing")
        end
        monitor.setCursorPos(1, 4)
        monitor.write("Mode: " .. PlayModesNames[playMode])
        monitor.setCursorPos(1, 5)
        monitor.write(drawProgressBar(math.min(18, x), songPosition / songLength))
        monitor.setCursorPos(1, 6)
        monitor.write(scrollText(statusText, 18))

        -- Draw the queue from x=13
        monitor.setCursorPos(19, 1)
        monitor.write("| Queue")
        for i=1,y do
            monitor.setCursorPos(19, i+1)
            monitor.write("|")
        end
        for i,v in pairs(queue) do
            monitor.setCursorPos(20, i+2)
            monitor.write(i .. ": " .. scrollText(v.name, x - 20))
        end
        if #queue == 0 then
            monitor.setCursorPos(21, 3)
            monitor.write("Empty")
        end



    end
    term.setCursorPos(1, 3)
    local x = term.getSize()
    if not displayingQueue then
        if currentSong then
            print("Playing: " .. scrollText(currentSong.name, math.min(16, x)))
        else
            print("Not Playing")
        end
        print("Mode: " .. PlayModesNames[playMode])
        print("State: " .. PlayStatesNames[playState])
        print(scrollText(statusText, 25))
        
        print(drawProgressBar(math.min(25, x), songPosition / songLength))
    else
        print("Queue")
        for i,v in pairs(queue) do
            print(i .. ": " .. scrollText(v.name, x - 4))
        end
        if #queue == 0 then
            print("Empty")
        end
    end


    -- Draw the queue from x=26
    term.setCursorPos(26, 1)
    term.write("| Queue")
    for i=1,14 do
        term.setCursorPos(26, i+1)
        term.write("|")
    end
    for i,v in pairs(queue) do
        term.setCursorPos(27, i+2)
        term.write(i .. ": " .. scrollText(v.name, x - 27))
    end
    if #queue == 0 then
        term.setCursorPos(28, 3)
        term.write("Empty")
    end
    -- Set the cursor to 4th last line
    local x, y = term.getSize()
    term.setCursorPos(1, y - 4)
    term.write("-------------------------------------------------------------------")
    term.setCursorPos(1, y - 3)

    drawDirectory()
end

populateMonitors()
populateDirectoryList()
parallel.waitForAll(handleEvents, playNextBuffer, function()
    while true do
        drawUI()
        os.sleep(0.5)
    end
end)