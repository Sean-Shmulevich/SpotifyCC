while true do
    event, key = os.pullEvent("key")
    print("Key: " .. keys.getName(key))
end
