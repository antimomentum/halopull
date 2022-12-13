-- Hit-reg Fix by Devieth
-- Script for SAPP and Chimera

-- Default = 0.08
-- Recommended = 0.05
-- Minimum = 0.045

-- Above 0.08 hit-reg gets worse, unless you want that...
-- Below 0.03 headshots STOP WORKING ENTIRELY!!!

value = 0.05

-- Force enable the fix every time the script is loaded/reloaded.
-- **Warning** If the script loads and no map is loaded the server WILL crash.
force_enable = false

api_version = "1.10.0.0" -- SAPP
clua_version = 2.05 -- Chimera

if full_build then
	set_callback("map load", "OnGameStart")
end

ce, client_info_size = 0x40, 0xEC

function OnScriptLoad()

	register_callback(cb['EVENT_GAME_START'], "OnGameStart")
	--register_callback(cb['EVENT_TICK'], "loop")
	object_table = read_dword(read_dword(sig_scan("8B0D????????8B513425FFFF00008D") + 2))
	network_struct = read_dword(sig_scan("F3ABA1????????BA????????C740??????????E8????????668B0D") + 3)
	--timer(100, "loop")
end

player_objects = {}


function loop()
	for i = 1,16 do
		if player_present(i) then
			local client_machineinfo_struct = get_client_machine_info(i)
			local melee = read_bit(client_machineinfo_struct + 0x24, 7)

			if melee == 1 then
				write_bit(client_machineinfo_struct + 0x24, 7, 0)
			else
				write_bit(client_machineinfo_struct + 0x24, 7, 1)
			end

		end
	end
	return true
end

function get_client_machine_info(PlayerIndex)
	if player_present(PlayerIndex) then
		return network_struct + 0x3B8 + ce + to_real_index(PlayerIndex) * client_info_size
	else
		return network_struct + 0x3B8 + ce + (tonumber(PlayerIndex) - 1) * client_info_size
	end
end

function get_client_network_struct(PlayerIndex)
	if player_present(PlayerIndex) then
		return network_struct + 0x1AA + ce + to_real_index(PlayerIndex) * 0x20
	else
		return network_struct + 0x1AA + ce + (tonumber(PlayerIndex) - 1) * 0x20
	end
end

function OnScriptUnload() end

function OnGameStart()
	if full_build then
		set_timer(66, "hit_reg_fix")
	else
		timer(66, "hit_reg_fix")
	end
end

function hit_reg_fix()
	-- Lets loop through all the tags (doing this so this script even works on custom maps.)
	for i = 0, read_word(0x4044000C) - 1 do
		local tag = read_dword(0x40440000) + i * 0x20
		local tag_class = string.reverse(string.sub(read_string(tag),1,4))
		local tag_address = read_dword(tag + 0x14)
		-- Is the tag a bipd tag?
		if tag_class == "bipd" then
			-- If the it is a bipd tag lets change the auto_aim_width to a smaller value.
			-- Doing this makes the auto_aim (bullet curving) pull more accurately pull to the body parts.
			write_float(tag_address + 0x458, value)
		end
	end
	return false
end
