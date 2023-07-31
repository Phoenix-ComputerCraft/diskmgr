local filesystem = require "system.filesystem"
local hardware = require "system.hardware"
local syslog = require "system.log"

local log = syslog.create("diskmgr", true)
local mounts = {}
local function mount(device)
    local info = hardware.call(device, "getState")
    if info and info.id then
        local path = "/media/"
        if info.label then path = path .. info.label
        else path = path .. info.id end
        local ok, err = pcall(function()
            filesystem.mkdir(path)
            filesystem.mount("drivefs", device, path, {})
            mounts[device] = path
        end)
        if ok then log.info("Mounted drive " .. device .. " to " .. path)
        else log.error("Could not mount drive: " .. err) end
    end
end

local function search(path, shouldMount)
    if hardware.hasType(path, "drive") or hardware.hasType(path, "modem") then hardware.listen(path) end
    if shouldMount and hardware.hasType(path, "drive") then mount(path) end
    for _, v in ipairs(hardware.children(path)) do search(path .. "/" .. v, shouldMount) end
end
hardware.listen("/")
search("/", true)

while true do
    local event, param = coroutine.yield()
    if event == "disk" then
        mount(param.device)
    elseif event == "disk_eject" and mounts[param.device] then
        filesystem.unmount(mounts[param.device])
        filesystem.remove(mounts[param.device])
        mounts[param.device] = nil
    elseif event == "device_added" then
        search(param.device, false)
    end
end
