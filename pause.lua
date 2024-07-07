local disk_path = nil

if disk.isPresent("left") then 
    disk_path = disk.getMountPath("left")
end

local function download_audio(url)
    local response = http.get(url)
    if response then
        -- todo what if i didnt read this all at once? and it was a stream?
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
    local pause_state = "playing"

    -- these nested loops are a bit confusing but essentially, audio is buffered, by the outter loop in increments of chunk size
    -- and then the inner loop goes until all of the data in that buffer is played.
    while chunk_idx <= #content do
        -- splitting the .dfpwn file into chunks 
        local chunk = content:sub(chunk_idx, chunk_idx + chunk_size - 1)
        local buffer = decoder(chunk)

        -- the declaration in this loop also executes each iteration of the loop
        -- buffer fills by 'chunk_size' chunks per each loop iteration
        -- declaration plays audio.
        -- while not paused, but i still want the loop to run when its paused

        -- everything inside of this loop happens while the song is playing-
        -- for each filling and clearing of the chunked buffer
        -- speaker.playAudio(buffer) returns a boolean value, true if there is room to accept audio data.
        -- in this case true means, end the loop and refill the buffer.
        -- run until what's inside becomes true
        while not false and  do
            -- playing and full
            -- demorgans law bitch
            -- if playing then the code after the "and" will execute even if it is false
            -- for the break to execute, both have to be true which means we are playing and there is more space for audio
            -- if we are not playing then speaker.playAudio does not run. but events are still checked
            -- this cant be in the outter while loop declaration, because then the events part of this loop wont work
            if pause_state=="playing" and speaker.playerAudio(buffer) then
                break
            end

            if pause_state=="paused" then
                chunk_idx = chunk
            end

            -- i want to know if we are playing and speaker.playAudio(buffer) is true becaue then you should break.

            -- to get speaker.play.. out of the loop declaration.
            -- i need to make sure that 
            -- maybe i can get out of it with a second conditional and demorgans law.
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
            else if event === "mouse_click" then

                pause_state = "paused"


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
            else if event == "key" then
                -- run unpause logic
                print("Key event play")
                pause_state = "playing"
                -- the chunk stops incrementing when paused. so it will likely start over that chunk.
                speaker.playAudio(buffer)
            elseif event == "speaker_audio_empty" then
                -- Continue playing
            end
        end

        -- increment current position of song by chunk size
        -- dont increment when paused.
        if(pause_state=="playing") then
            chunk_idx = chunk_idx + chunk_size
        end
    end

    return nil
end

function write_song_to_disk(content)
    local file = fs.open(disk_path.."/song.dfpwm", "w+b")--opens your file in "write" mode, which will create it if it doesn't exist yet, but overwrite it if it does

    file.write() 

    file.seek("set", 0)
    local contents = file.readAll()

    print("Contents: "..contents)

    file.close() --Closes the file and finishes writing. This step is important!!
end


print(disk_path)
print("has data: "..tostring(disk.hasData("left")))
local file = fs.open(disk_path.."/hello.txt", "w+")--opens your file in "write" mode, which will create it if it doesn't exist yet, but overwrite it if it does

file.write("Your text goes here.\nThis text is on a new line") --writes two lines of text, put \n to make a new line

file.seek("set", 0)
local contents = file.readAll()

print("has data: "..tostring(disk.hasData("left")))
print("Contents: "..contents)

file.close() --Closes the file and finishes writing. This step is important!!