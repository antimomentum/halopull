--[[
BUTTERY SMOOTH
Author: PiRate
Description: Patches the server to force LAN encoding class.

Warning: This script should loaded before the server starts proper (e.g. in an init.txt).

My thanks to Vitor for helping me test this idea and giving me motivation to 
release this script.
--]]

api_version = "1.12.0.0"

local patch_connection_class = {
    name="Upgrade Connection Class",
    signature='41348B702CB0017411C741240000803F',
    offset=7,
    data={0xeb}
}

local patch_negotiated_encoding_class = {
    name="Upgrade Negotiated Encoding Class",
    signature='44243F00B9210000008D7C2448F3A58A0D??????00528D44243C508D8424D800',
    offset=15,
    data={0x30, 0xc9, 0x90, 0x90, 0x90, 0x90}
}

local patch_mdp_encoding_class = {
    name="Upgrade MDP Encoding Class",
    signature='E9E60000008A0D',
    offset=5,
    data={0x30, 0xc9, 0x90, 0x90, 0x90, 0x90}
}

local patches = {
    patch_connection_class, 
    patch_negotiated_encoding_class, 
    patch_mdp_encoding_class
}

local function read_bytes(offset, count)
    local result = {}
    for i=1,count do
        local b = read_byte(offset + i - 1)
        if b == nil then return nil end
        table.insert(result, read_byte(offset + i - 1))
    end
    
    return result
end

local function write_bytes(offset, bytes)
    safe_write(true)
    for i,v in ipairs(bytes) do
        if not write_byte(offset + i - 1, v) then
            return false
        end
    end
    safe_write(false)
    
    return true
end

local function do_patch(patch)
    local name = assert(patch.name, "patch had no name")
    local signature = assert(patch.signature, "patch had no signature")
    local offset = assert(patch.offset, "patch had no offset")
    local data = assert(patch.data, "patch had no data")

    local applied = patch.applied or false
    if applied then return true end
    
    local signature_offset = sig_scan(signature)
    if signature_offset == 0 then
        print("(buttery_smooth) Patch " .. name .. ": scan for signature failed", 2)
        return false
    end
    
    local patch_offset = signature_offset + offset
    local restore_data = read_bytes(patch_offset, #data)
    if not restore_data then
        print("(buttery_smooth) Patch " .. name .. ": could not restore restore data from " .. tostring(patch_offset) .. "(" .. tostring(#data) .. ")")
        return false
    end
    
    if not write_bytes(patch_offset, data) then
        print("(buttery_smooth) Patch " .. name .. ": could not write patch data to " .. tostring(patch_offset) .. "(" .. tostring(#data) .. ")")
        return false
    end
    
    patch.restore_data = restore_data
    patch.restore_offset = patch_offset
    patch.applied = true
    
    return patch.applied
end

local function undo_patch(patch)
    if not patch.applied then return end
    
    local restore_data = patch.restore_data
    local restore_offset = patch.restore_offset
    
    if not restore_data or not restore_offset then return end
    
    write_bytes(restore_offset, restore_data)
    
    patch.applied = false
    patch.restore_data = nil
    patch.restore_offset = nil
end

function OnScriptLoad()
    local count = 0
    for _, patch in ipairs(patches) do
        if not do_patch(patch) then break end
        count = count + 1
    end
    
    if count ~= #patches then
        print("(buttery smooth) some patch failed, undoing all patches")
        for _, patch in ipairs(patches) do
            undo_patch(patch)
        end
        count = 0
    end
end

function OnScriptUnload()
    for _, patch in ipairs(patches) do
        undo_patch(patch)
    end
end

function OnError(Message)

-- This function is not required, but if you want to log errors, use this.

end