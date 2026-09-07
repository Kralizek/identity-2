local success, message = xpcall(function()
    dofile("tests/compatibility.lua")
end, debug.traceback)

if(not success) then
    print(message)
    os.exit(1)
end