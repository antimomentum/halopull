--[[
--======================================================================================================--
Script Name: Uber (v1.2), for SAPP (PC & CE)
Description: Inject yourself into a teammate's vehicle by typing "uber" or crouching.
             This script will scan all available vehicles that are occupied by teammates.
             The first scan checks available gunner seats. If one is available, you will enter into it.
             If no gunner seats are available, the script will then scan for available passenger seats and
			 insert you into one. If neither gunner or passenger seats are vacant the script will send you an error.
            Features:
            * Customizable activation keywords: i,e "uber", "taxi", "cab"
            * Limit uber calls per game (20 by default)
            * Crouch to call an uber (on by default)
            * Auto Ejector: Vehicle occupants without a driver will be ejected after X seconds (on by default)
            * Cooldowns (you have to wait 10 seconds before attempting to call an uber) - on by default
            * Works on most custom maps
            * Compatible with any team-based game type (incl CTF, Oddball)
            * Customizable messages
            * Option to prevent players holding the objective from calling an uber (applies to CTF and Oddball)
Copyright (c) 2020, Jericho Crosby <jericho.crosby227@gmail.com>
* Notice: You can use this document subject to the following conditions:
https://github.com/Chalwk77/HALO-SCRIPT-PROJECTS/blob/master/LICENSE
--======================================================================================================--
]]--

api_version = "1.12.0.0"
local uber = {

    -- Configuration Starts --
    command = { "uber", "taxi", "cab", "taxo", "taxii", "taxci", "taci", "takse" },

    -- Maximum number of uber calls per game:
    calls_per_game = 10000000000000000,

    -- If true, players holding the flag or oddball will not be able to call an uber.
    block_objective = true,

    -- If true, players will be able to call an uber by crouching
    crouch_to_uber = false,

    -- If true, you will have to wait X seconds before attempting to call an uber
    use_cooldown = true,
    cooldown_period = 10,

    -- If true, Vehicle Occupants without a driver will be ejected
    eject_players_without_driver = false,
    -- Vehicle Occupants without a driver will be ejected after this amount of time (in seconds)
    ejection_period = 5,

    -- Custom Message
    messages = {
        [1] = "There are no ubers available right now",
        [2] = "You are already in a vehicle!",
        [3] = "You have used up your uber calls for this game!",
        [4] = "Please wait until you respawn.",
        [5] = "[No Driver] You will be ejected in %seconds% seconds.",
        [6] = "You cannot call an uber while holding the objective",
        [7] = "Please wait another %seconds% seconds to call an uber",
        [8] = "[Protected Map] Uber is unavailable on this map.",
        [9] = { --< on vehicle entry
            "--- UBER ---",
            "Driver: %dname%",
            "Gunner: %gname%",
            "Passenger: %pname%",
            "Uber Calls remaining: %remaining%"
        }
    }
    -- Configuration Ends --
}

local floor = math.floor
local time_scale = 1 / 30
local players, vehicles = {}
local lower, upper, gsub = string.lower, string.upper, string.gsub

function OnScriptLoad()
    register_callback(cb['EVENT_GAME_START'], "OnGameStart")
    OnGameStart()
end

function OnScriptUnload()
    -- N/A
end

function OnGameStart()
    if (get_var(0, "$gt") ~= "n/a") then
        if RegisterSAPPEvents() then
            for i = 1, 16 do
                if player_present(i) then
                    uber:InitPlayer(i, true)
                end
            end
        end
    end
end

function OnPlayerConnect(Ply)
    uber:InitPlayer(Ply, true)
end

function OnPlayerDisconnect(Ply)
    uber:InitPlayer(Ply, false)
    CheckSeats(Ply, true)
end

function OnPlayerDeath(Ply)
    CheckSeats(Ply, true)
end

function OnTick()
    for i, player in pairs(players) do
        if player_present(i) and player_alive(i) then
            local dynamic_player = get_dynamic_player(i)
            if (dynamic_player ~= 0) then
                local CurrentVehicle, VehicleObjectMemory = uber:isInVehicle(i)
                if (uber.crouch_to_uber) then
                    if not (CurrentVehicle) then
                        local crouching = read_float(dynamic_player + 0x50C)
                        if (crouching ~= player.crouch_state and crouching == 1) then
                            if (not uber.protected) then
                                if (player.calls > 0) then
                                    if (not player.cooldown) then
                                        uber:CheckVehicles(i)
                                    else
                                        cls(i, 25)
                                        local delta_time = floor(uber.cooldown_period - player.cooldown_timer)
                                        local msg = gsub(uber.messages[7], "%%seconds%%", delta_time)
                                        rprint(i, msg)
                                    end
                                else
                                    cls(i, 25)
                                    rprint(i, uber.messages[3])
                                end
                            else
                                cls(i, 25)
                                rprint(i, uber.messages[8])
                            end
                        end
                        if (player.cooldown) and (not uber.protected) then
                            player.cooldown_timer = player.cooldown_timer + time_scale
                            if (player.cooldown_timer >= uber.cooldown_period) then
                                player.cooldown, player.cooldown_timer = false, 0
                            end
                        end
                        player.crouch_state = crouching
                    end
                end
                if (uber.eject_players_without_driver) and (not uber.protected) then
                    if (CurrentVehicle) then
                        local driver = read_dword(VehicleObjectMemory + 0x324)
                        if (not player.eject) then
                            if (driver == 0xFFFFFFFF or driver == 0) then
                                player.eject = true
                                local ejection_warning_message = gsub(uber.messages[5], "%%seconds%%", uber.ejection_period)
                                rprint(i, ejection_warning_message)
                            end
                        elseif (player.eject) and (driver ~= 0xFFFFFFFF) then
                            player.eject = false
                            player.eject_timer = 0
                        else
                            player.eject_timer = player.eject_timer + time_scale
                            if (player.eject_timer >= uber.ejection_period) then
                                exit_vehicle(i)
                                player.eject = false
                                player.eject_timer = 0
                                CheckSeats(i, true)
                            end
                        end
                    elseif (player.eject) then
                        player.eject = false
                        player.eject_timer = 0
                    end
                end
            end
        end
    end
    uber:CheckForReset()
end

function OnPlayerSpawn(Ply)
    players[Ply].crouch_state = 0
    players[Ply].cooldown = false
    players[Ply].cooldown_timer = 0
end

function OnServerChat(Ply, Message, Type)
    local Str = StrSplit(Message)
    if (#Str == 0) then
        return
    elseif (Type ~= 6) then
        Str[1] = lower(Str[1]) or upper(Str[1])
        for i = 1, #uber.command do
            if (Str[1] == uber.command[i]) then
                if (Ply ~= 0) then
                    cls(Ply, 25)
                    if (not uber.protected) then
                        if player_alive(Ply) then
                            if (players[Ply].calls > 0) then
                                if (not uber:isInVehicle(Ply)) then
                                    uber:CheckVehicles(Ply)
                                else
                                    rprint(Ply, uber.messages[2])
                                end
                            else
                                rprint(Ply, uber.messages[3])
                            end
                        else
                            rprint(Ply, uber.messages[4])
                        end
                    else
                        rprint(Ply, uber.messages[8])
                    end
                else
                    cprint("This command can only be executed by a player", 4 + 8)
                end
                return false
            end
        end
    end
end

function uber:CheckVehicles(Ply)
    if (not uber.block_objective) or (uber.block_objective and not uber:HasObjective(Ply)) then
        local driver_count = 0
        local team = get_var(Ply, "$team")
        if (uber.use_cooldown) then
            players[Ply].cooldown, players[Ply].cooldown_timer = true, 0
        else
            players[Ply].cooldown = false
        end
        for _, v in pairs(vehicles) do
            if (v.driver and v.team == team and v.valid) then
                driver_count = driver_count + 1
                if (v.gunner) then
                    v.gunner = false
                    uber:InsertPlayer(v.vehicle, Ply, 2)
                    break
                elseif (v.passenger) then
                    v.passenger = false
                    uber:InsertPlayer(v.vehicle, Ply, 1)
                    break
                else
                    count = 0
                end
            end
        end
        if (driver_count == 0) then
            cls(Ply, 25)
            rprint(Ply, uber.messages[1])
        end
    end
end

function uber:InsertPlayer(Vehicle, Ply, Seat)
    players[Ply].calls = players[Ply].calls - 1
    enter_vehicle(Vehicle, Ply, Seat)
end

function OnVehicleEntry(Ply)
    CheckSeats(Ply, false, true)
end

function OnVehicleExit(Ply)
    CheckSeats(Ply, true)
    players[Ply].eject = false
    players[Ply].eject_timer = 0
end

local SetTeam = function(State, Vehicle)
    local reset = (State and not Vehicle.driver) or (not State and not Vehicle.driver)
    local previous_team = (State and Vehicle.driver) or (not State and Vehicle.driver)
    if (reset) then
        return "N/A"
    elseif (previous_team) then
        return Vehicle.team
    end
end

function CheckSeats(Ply, State, Enter)
    if (not uber.protected) then
        local dynamic_player = get_dynamic_player(Ply)
        if (dynamic_player ~= 0) then
            local CurrentVehicle = read_dword(dynamic_player + 0x11C)
            local VehicleObjectMemory = get_object_memory(CurrentVehicle)
            if (VehicleObjectMemory ~= 0 and CurrentVehicle ~= 0xFFFFFFFF) then

                local team = get_var(Ply, "$team")
                local name = get_var(Ply, "$name")

                local seat = read_word(dynamic_player + 0x2F0)
                local previous_state = vehicles[VehicleObjectMemory]

                previous_state = previous_state or { -- table index is nil, create new:
                    driver = false, gunner = true, passenger = true,
                    d_name = "N/A", g_name = "N/A", p_name = "N/A",
                    team = "N/A", valid = false
                }

                if (seat == 0) then
                    if (not State) then
                        State = true
                    else
                        State = false
                    end
                    -- driver
                    vehicles[VehicleObjectMemory] = {
                        d_name = name,
                        team = team,
                        g_name = previous_state.g_name,
                        p_name = previous_state.p_name,
                        valid = uber:ValidateVehicle(VehicleObjectMemory),

                        driver = State, -- true if occupied
                        vehicle = CurrentVehicle,
                        gunner = previous_state.gunner,
                        passenger = previous_state.passenger
                    }
                elseif (seat == 1) then
                    -- passenger
                    vehicles[VehicleObjectMemory] = {
                        team = SetTeam(State, previous_state),
                        d_name = previous_state.d_name,
                        g_name = previous_state.g_name,
                        p_name = name,
                        valid = previous_state.valid,

                        passenger = State, -- false if occupied
                        vehicle = CurrentVehicle,
                        gunner = previous_state.gunner,
                        driver = previous_state.driver
                    }
                elseif (seat == 2) then
                    -- gunner
                    vehicles[VehicleObjectMemory] = {
                        team = SetTeam(State, previous_state),
                        d_name = previous_state.d_name,
                        g_name = name,
                        p_name = previous_state.p_name,
                        valid = previous_state.valid,

                        gunner = State, -- false if occupied
                        vehicle = CurrentVehicle,
                        driver = previous_state.driver,
                        passenger = previous_state.passenger
                    }
                end
                if (Enter) then
                    cls(Ply, 25)
                    local t, msg = vehicles[VehicleObjectMemory], ""
                    for i = 1, #uber.messages[9] do
                        msg = gsub(gsub(gsub(gsub(uber.messages[9][i],
                                "%%dname%%", t.d_name),
                                "%%gname%%", t.g_name),
                                "%%pname%%", t.p_name),
                                "%%remaining%%", players[Ply].calls)
                        rprint(Ply, msg)
                    end
                end
            end
        end
    end
end

function uber:isInVehicle(Ply)
    local dynamic_player = get_dynamic_player(Ply)
    local CurrentVehicle = read_dword(dynamic_player + 0x11C)
    local VehicleObjectMemory = get_object_memory(CurrentVehicle)
    if (CurrentVehicle ~= 0xFFFFFFFF) then
        return CurrentVehicle, VehicleObjectMemory
    end
    return false
end

function uber:CheckForReset()
    if (vehicles ~= nil) then
        for k, v in pairs(vehicles) do
            if (k) then
                local count = 0
                local driver = read_dword(k + 0x324)
                local gunner = read_dword(k + 0x328)
                local passenger = read_dword(k + 0x32C)
                if (driver == 0xFFFFFFFF or driver == 0) then
                    count, v.d_name, v.team = count + 1, "N/A", "N/A"
                end
                if (gunner == 0xFFFFFFFF or passenger == 0) then
                    count, v.g_name = count + 1, "N/A"
                end
                if (passenger == 0xFFFFFFFF or passenger == 0) then
                    count, v.p_name = count + 1, "N/A"
                end
                if (count == 3) then
                    vehicles[k] = nil
                end
            end
        end
    end
end

function StrSplit(STR)
   local Args = { }
    for Param in STR:gmatch("([^%s]+)") do
        Args[#Args+1] = Param
    end
    return Args
end

function uber:InitPlayer(Ply, Reset)
    if (Reset) then
        players[Ply] = {
            cooldown = false,
            cooldown_timer = 0,
            crouch_state = 0,
            calls = uber.calls_per_game,
            eject = false,
            eject_timer = 0
        }
    else
        players[Ply] = nil
    end
end

function cls(Ply, Count)
    for _ = 1, Count do
        rprint(Ply, " ")
    end
end

function uber:ValidateVehicle(VehicleObjectMemory)
    local vehicle = read_string(read_dword(read_word(VehicleObjectMemory) * 32 + 0x40440038))
    local keywords = {
        "hog", "hawg", "civi", "civvi", "vulcan",
        "puma", "scorpion", "lav", "sult", "rancher",
        "walton", "snow_civ", "glendale", "jeep",
        "mesa", "spectre"
    }
    for _, word in pairs(keywords) do
        if (vehicle:find(word)) then
            return true
        end
    end
    return false
end

function RegisterSAPPEvents()
    if (get_var(0, "$ffa") == "0") then

        local tag_address = read_dword(0x40440000)
        local tag_count = read_dword(0x4044000C)
        for i = 0, tag_count - 1 do
            local tag = tag_address + 0x20 * i
            local tag_name = read_string(read_dword(tag + 0x10))
            local tag_class = read_dword(tag)
            if (tag_class == 1885895027 and tag_name:find("protected")) then
                uber.protected = true
            end
        end

        players, vehicles = {}, {}
        register_callback(cb["EVENT_TICK"], "OnTick")
        register_callback(cb['EVENT_DIE'], "OnPlayerDeath")
        register_callback(cb["EVENT_CHAT"], "OnServerChat")
        register_callback(cb['EVENT_SPAWN'], "OnPlayerSpawn")
        register_callback(cb["EVENT_JOIN"], "OnPlayerConnect")
        register_callback(cb["EVENT_LEAVE"], "OnPlayerDisconnect")
        register_callback(cb['EVENT_VEHICLE_EXIT'], "OnVehicleExit")
        register_callback(cb['EVENT_VEHICLE_ENTER'], "OnVehicleEntry")
        return true
    else
        unregister_callback(cb['EVENT_DIE'])
        unregister_callback(cb["EVENT_CHAT"])
        unregister_callback(cb["EVENT_JOIN"])
        unregister_callback(cb['EVENT_SPAWN'])
        unregister_callback(cb["EVENT_LEAVE"])
        unregister_callback(cb["EVENT_TICK"])
        unregister_callback(cb['EVENT_VEHICLE_EXIT'])
        unregister_callback(cb['EVENT_VEHICLE_ENTER'])
    end
    return false
end

function uber:HasObjective(Ply)
    -- Credits to Kavawuvi for this block of code:
    local has_objective
    if (get_var(0, "$gt") == "ctf") or (get_var(0, "$gt") == "oddball") then
        local player_object = get_dynamic_player(Ply)
        if player_alive(Ply) then
            for i = 0, 3 do
                local weapon_id = read_dword(player_object + 0x2F8 + 0x4 * i)
                if (weapon_id ~= 0xFFFFFFFF) then
                    local weap_object = get_object_memory(weapon_id)
                    if (weap_object ~= 0) then
                        local tag_address = read_word(weap_object)
                        local tagdata = read_dword(read_dword(0x40440000) + tag_address * 0x20 + 0x14)
                        if (read_bit(tagdata + 0x308, 3) == 1) then
                            has_objective = true
                        end
                    end
                end
            end
        end
    else
        has_objective = false
    end
    --
    --
    if (has_objective) then
        cls(Ply, 25)
        rprint(Ply, uber.messages[6])
    end
    return has_objective
end