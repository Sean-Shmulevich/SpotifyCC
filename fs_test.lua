local disk_path = nil

if disk.isPresent("left") then 
    disk_path = disk.getMountPath("left")
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