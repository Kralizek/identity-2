local openedCategory
local registeredCommands = {}
local registeredOptions = {}
local addon = { hooks = {} }
local legacy = arg[1] == "legacy"
local sentArguments
local sentCount = 0
local inaccessible = {}

local function noop() end

function addon:RawHook(target, method, handler)
    if(type(target) == "string") then
        self.hooks[target] = assert(_G[target])
        _G[target] = function(...) return self[target](self, ...) end
    else
        self.hooks[target] = self.hooks[target] or {}
        self.hooks[target][method] = assert(target[method])
        target[method] = function(...) return self[handler](self, ...) end
    end
end

function addon:RegisterChatCommand(command, handler)
    registeredCommands[command] = handler
end

addon.RegisterEvent = noop
addon.Print = noop

local locale = setmetatable({}, {
    __index = function(_, key)
        return function() return key end
    end
})

local libraries = {
    ["AceAddon-3.0"] = { NewAddon = function() return addon end },
    ["AceLocale-3.0"] = { GetLocale = function() return locale end },
    ["AceDB-3.0"] = {
        New = function(_, _, defaults)
            return { global = defaults.global, profile = defaults.profile, RegisterCallback = noop }
        end
    },
    ["AceConfig-3.0"] = {
        RegisterOptionsTable = function(_, name, options) registeredOptions[name] = options end
    },
    ["AceConfigDialog-3.0"] = {
        AddToBlizOptions = function(_, name, _, parent)
            if(parent) then
                assert(parent == "Identity 2")
                return {}, 43
            end
            assert(name == "Identity2")
            return {}, 42
        end
    },
    ["AceDBOptions-3.0"] = { GetOptionsTable = function() return {} end },
    ["AceConfigRegistry-3.0"] = { NotifyChange = noop }
}

function LibStub(name) return assert(libraries[name], name) end

local function recordSend(...)
    sentArguments = { ... }
    sentCount = sentCount + 1
    return true
end

C_ChatInfo = { SendChatMessage = recordSend }
C_BattleNet = { SendWhisper = recordSend }
C_Club = { SendMessage = recordSend, GetSubscribedClubs = function() return {} end }
Settings = { OpenToCategory = function(category) openedCategory = category end }
date = function() return { day = 2, month = 1 } end
GetChannelName = function(channel)
    local names = { [1] = "General", [2] = "Community:123:456", [3] = "Community:789:456" }
    return channel, names[channel]
end

function canaccessallvalues(...)
    for index = 1, select("#", ...) do
        if(select(index, ...) == inaccessible) then return false end
    end
    return true
end

if(legacy) then
    SendChatMessage = recordSend
    BNSendWhisper = recordSend
    C_ChatInfo = nil
    C_BattleNet = nil
    Settings = nil
    canaccessallvalues = nil
    InterfaceOptionsFrame_OpenToCategory = function(category) openedCategory = category end
end

dofile("Identity-2.lua")
Identity2:OnInitialize()

if(not legacy) then
    assert(InterfaceOptionsFrame_OpenToCategory == nil)
    assert(SendChatMessage == nil and BNSendWhisper == nil, "Modern clients must not need legacy globals")
end
for _, command in ipairs({ "id", "identity" }) do
    openedCategory = nil
    Identity2[registeredCommands[command]](Identity2, "")
    if(legacy) then
        assert(type(openedCategory) == "table", command .. " must open the legacy panel")
    else
        assert(openedCategory == 42, command .. " must open the returned Settings category ID")
    end
end
assert(registeredOptions["Identity2 Profiles"], "Profiles must remain registered")
print("PASS: settings navigation and profile registration")

local sendChat = legacy and SendChatMessage or C_ChatInfo.SendChatMessage
local sendWhisper = legacy and BNSendWhisper or C_BattleNet.SendWhisper
local profile = Identity2.db.profile
profile.identity = "Main"
profile.fun = false

for _, channel in ipairs({ "GUILD", "OFFICER", "PARTY", "RAID", "INSTANCE_CHAT", "WHISPER", "SAY", "YELL" }) do
    profile.channels[channel].enabled = true
    local previousCount = sentCount
    sendChat("hello", channel, 7, "Player-Realm", "extra")
    assert(sentCount == previousCount + 1, "Must send exactly once")
    assert(sentArguments[1] == "[Main] hello", channel)
    assert(sentArguments[2] == channel and sentArguments[3] == 7)
    assert(sentArguments[4] == "Player-Realm" and sentArguments[5] == "extra")
end

sendChat("hello")
assert(sentArguments[1] == "[Main] hello" and sentArguments[2] == nil, "Omitted chat type defaults to SAY")
profile.channels.PARTY.identity = "Nickname"
sendChat("hello", "PARTY")
assert(sentArguments[1] == "[Nickname] hello")
profile.channels.PARTY.enabled = false
sendChat("hello", "PARTY")
assert(sentArguments[1] == "hello")
sendChat("away", "AFK")
assert(sentArguments[1] == "away")
sendChat(string.rep("x", 300), "GUILD")
assert(#sentArguments[1] == 255, "Keep the existing chat length limit")

profile.channels.customs.General = { enabled = true, identity = "Custom" }
sendChat("hello", "CHANNEL", nil, 1)
assert(sentArguments[1] == "[Custom] hello" and sentArguments[4] == 1)
sendChat("hello", "CHANNEL", nil, 99)
assert(sentArguments[1] == "hello", "An unknown channel must not break sending")

profile.channels.communities["123"] = {
    enabled = true, streams = { ["456"] = { enabled = true, identity = "Community", streamId = "456" } }
}
profile.channels.communities[789] = {
    enabled = true, streams = { [456] = { enabled = true, identity = "Legacy", streamId = 456 } }
}
C_Club.GetClubInfo = function() return { name = "Community" } end
C_Club.GetStreams = function(clubId)
    return { { streamId = clubId == "123" and "456" or 456, name = "General" } }
end
Identity2:LoadCommunities()
assert(registeredOptions.Identity2.args.communities.args["123"].args["456"], "String-keyed streams must appear in settings")
assert(registeredOptions.Identity2.args.communities.args["789"].args["456"], "Sparse numeric streams must appear in settings")
sendChat("hello", "CHANNEL", nil, 2)
assert(sentArguments[1] == "[Community] hello", "Use string community IDs")
sendChat("hello", "CHANNEL", nil, 3)
assert(sentArguments[1] == "[Legacy] hello", "Keep numeric saved IDs working")
C_Club.SendMessage("123", "456", "hello")
assert(sentArguments[1] == "123" and sentArguments[2] == "456" and sentArguments[3] == "[Community] hello")
profile.channels.communities["123"].enabled = false
sendChat("hello", "CHANNEL", nil, 2)
assert(sentArguments[1] == "hello")

profile.channels.BN_WHISPER.enabled = true
assert(sendWhisper(42, "hello") == true, "Preserve Battle.net success return value")
assert(sentArguments[1] == 42 and sentArguments[2] == "[Main] hello")
profile.enabled = false
sendChat("hello", "GUILD")
assert(sentArguments[1] == "hello")
sendWhisper(42, "hello")
assert(sentArguments[2] == "hello")
profile.enabled = true
print("PASS: chat channels, overrides, community IDs, length limit, and Battle.net forwarding")

if(not legacy) then
    sendChat(inaccessible, "GUILD")
    assert(sentArguments[1] == inaccessible)
    sendChat("hello", inaccessible)
    assert(sentArguments[1] == "hello" and sentArguments[2] == inaccessible)
    sendChat("hello", "CHANNEL", nil, inaccessible)
    assert(sentArguments[1] == "hello" and sentArguments[4] == inaccessible)
    sendWhisper(42, inaccessible)
    assert(sentArguments[2] == inaccessible)
    C_Club.SendMessage(inaccessible, "456", "hello")
    assert(sentArguments[1] == inaccessible and sentArguments[3] == "hello")
    print("PASS: inaccessible arguments are forwarded without formatting")
end

print("PASS: " .. (legacy and "legacy" or "Midnight") .. " compatibility")