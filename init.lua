local POIS_FILE = minetest.get_worldpath() .. "/points_of_interest.txt"
local POIS_TABLE = {}
local MAX_POIS = 64 --MUST be multiple of 8 or things might not work!
local POIS_FORM_NAME = "points_of_interest:pois_form"
local TELEPORT_BUTTON_LABEL = "Teleport"
local POIS_FORM_TITLE = "Choose a Point of Interest to teleport to"
local ERR_MSG_RANGE = " Index can range from 1 to "..MAX_POIS.."!"

--------------------------------
-- Context used for storing per-player info of page
--------------------------------

local _contexts = {}
local function get_context(name)
    local context = _contexts[name] or {}
    _contexts[name] = context
    return context
end

minetest.register_on_leaveplayer(function(player)
    _contexts[player:get_player_name()] = nil
end)


--------------------------------
-- Utility funcs
--------------------------------

local function is_invalid_page(pageStr)
	local number = tonumber(pageStr)
	if not number then return true end
	if number < 1 or number > MAX_POIS then return true end
	return false
end

function clamp(value, min, max)
	if value == nil then return nil; end
	if max == nil and min == nil then return value; end
	if min == nil then return math.min(value, max); end
	if max == nil then return math.max(value, min); end
	return math.max(math.min(value, max), min);
end
--------------------------------
-- Load/Save functions
--------------------------------

local function load_pois()
	local input = io.open(POIS_FILE, "r")
	if not input then
		return
	end

	-- Iterate over all stored positions in the format "x y z player" for each line
	for id, pos, name in input:read("*a"):gmatch("(%d+)%s(%S+ %S+ %S+)%s+([^\r\n]*)[\r\n]") do
		POIS_TABLE[id] = {minetest.string_to_pos(pos), name}
	end
	input:close()
end

local function save_pois() 
	local data = {}
	local output = io.open(POIS_FILE, "w")
	if output then
		for i, v in pairs(POIS_TABLE) do
			if not v then goto continue end
			local line = string.format("%d %.1f %.1f %.1f %s\n", i, v[1].x, v[1].y, v[1].z, v[2])
			table.insert(data, line)
			::continue::
		end
		output:write(table.concat(data))
		io.close(output)
		return true
	end
end

--------------------------------
-- POIS commands functions
--------------------------------

local function set_poi(name, param)
	name = name or ""
	local player = minetest.get_player_by_name(name)
	if not player then
		return false, "Error: No player."
	end
	local posString = minetest.pos_to_string(player:get_pos())
	local index, description = string.match(param, "(%d+)%s+(.*)")
	if not index or not description or is_invalid_page(index) then
		return false, "Error: Incorrect params!"..ERR_MSG_RANGE
	end
	POIS_TABLE[index] = {player:get_pos(), description}
	save_pois()
end

local function remove_poi(name, param)
	local index = string.match(param, "(%d+)")
	if not index or is_invalid_page(index) then
		return false, "Error: missing or invalid paramters!"..ERR_MSG_RANGE
	end
	POIS_TABLE[index] = nil
	save_pois()
end

local function move_poi(name, param)
	local index1, index2 = string.match(param, "(%d+)%s+(%d+).*")
	if not index1 or not index2 then 
		return false, "Error: missing paramters!"
	end
	if is_invalid_page(index1) or is_invalid_page(index2) then
		return false, "Error: invalid paramter format or range!"..ERR_MSG_RANGE
	end
	local orig1 = POIS_TABLE[index1]
	local orig2 = POIS_TABLE[index2]
	if orig1 then
		POIS_TABLE[index2] = orig1
	else
		POIS_TABLE[index2] = nil
	end
	if orig2 then
		POIS_TABLE[index1] = orig2
	elseif orig1 then
		POIS_TABLE[index1] = nil
	end
	save_pois()
end

local function edit_poi(name, param)
	local index, description = string.match(param, "(%d+)%s+(.*)")
	if not index or not description or is_invalid_page(index) then
		return false, "Error: invalid paramters or index!"..ERR_MSG_RANGE
	end
	local poi = POIS_TABLE[index]
	if not poi then
		return false, "Error: POI at index "..index.." does not exist!"
	end
	poi[2] = description
	save_pois()
end

--------------------------------
-- POIs User dialog functions
--------------------------------

local function get_poi_line(offset, btnNum)
	local index = offset + btnNum
	local lineNumberLabel="label[0.2,"..(btnNum+0.25)..";"..index.."]"
	
	local lineInfo = POIS_TABLE[tostring(index)]
	if not lineInfo then return lineNumberLabel end
	
	local description = lineInfo[2]
	if not description then return lineNumberLabel end
	
	local text = TELEPORT_BUTTON_LABEL
	return lineNumberLabel..
		"button_exit[0.8,"..btnNum..";2,0.5;teleport_"..btnNum..";"..text.."]"..
		"label[3,"..(btnNum + 0.25)..";"..description.."]"
end

local function show_poi_formspec(name)
	local numPages = math.ceil(MAX_POIS / 8.0)
	local page = get_context(name).pageNumber or 1
	local lastLine = ""
	if page > 1 then
		lastLine = lastLine.."button[2,9;2,0.5;prev_page;<]"
	end
	lastLine = lastLine.."button_exit[5,9;2,0.5;cancel_button;Cancel]"
	if page < numPages then
		lastLine = lastLine.."button[8,9;2,0.5;next_page;>]"
	end
	local startOffset = (page - 1) * 8 
	local lineA = get_poi_line(startOffset, 1)
	local lineB = get_poi_line(startOffset, 2)
	local lineC = get_poi_line(startOffset, 3)
	local lineD = get_poi_line(startOffset, 4)
	local lineE = get_poi_line(startOffset, 5)
	local lineF = get_poi_line(startOffset, 6)
	local lineG = get_poi_line(startOffset, 7)
	local lineH = get_poi_line(startOffset, 8)
	minetest.show_formspec(name, POIS_FORM_NAME,
		"formspec_version[6]"..
		"size[12,10]"..
		"bgcolor[#777777AA;;]"..
		"label[1,0.5;"..POIS_FORM_TITLE.."]"..
		lineA..lineB..lineC..lineD..lineE..lineF..lineG..lineH..
		lastLine
	);

end

local function show_poi_dialog(name, param)
	local player = minetest.get_player_by_name(name)
	if not player then
		return false, "Error: No player."
	end
	show_poi_formspec(name)

	return true, ""

end

local function on_poi_dialog_callback(player, formname, fields)
	if formname ~= POIS_FORM_NAME then return false end
	if not player then return false end

	local playerName = player:get_player_name()
	local context = get_context(playerName)
	local pageNum = context.pageNumber or 1

	local teleportIndex = 0
	if fields.prev_page then
		context.pageNumber = clamp(pageNum - 1, 1, MAX_POIS)
		show_poi_formspec(playerName)
	elseif fields.next_page then
		context.pageNumber = clamp(pageNum + 1, 1, MAX_POIS)
		show_poi_formspec(playerName)
	elseif fields.teleport_1 then
		teleportIndex = 1
	elseif fields.teleport_2 then
		teleportIndex = 2
	elseif fields.teleport_3 then
		teleportIndex = 3
	elseif fields.teleport_4 then
		teleportIndex = 4
	elseif fields.teleport_5 then
		teleportIndex = 5
	elseif fields.teleport_6 then
		teleportIndex = 6
	elseif fields.teleport_7 then
		teleportIndex = 7
	elseif fields.teleport_8 then
		teleportIndex = 8
	end

	if teleportIndex > 0 then
		local poiIndex = (pageNum - 1)*8 + teleportIndex
		local data = POIS_TABLE[tostring(poiIndex)]
		if data and data[1] then
			minetest.chat_send_player(playerName, "Teleported to "..(data[2] or "").."!")
			player:set_pos(data[1])
		end
	end

	return true
end


--------------------------------
-- Startup calls
--------------------------------

load_pois()

--------------------------------
-- Minetest callbacks
--------------------------------

minetest.register_privilege("manage_pois", {
	description = "Allows usage of commands to manage points of interest.",
	give_to_singleplayer = true,
	give_to_admin = false,
})

minetest.register_chatcommand("points_of_interest", {
	params = "", 
	description = "See a list of Points of Interest to teleport to",
	func = show_poi_dialog,
})

minetest.register_chatcommand("pois", {
	params = "", 
	description = "Shorthand for points_of_interest command.",
	func = show_poi_dialog,
})

minetest.register_chatcommand("setpoi", {
	params = "<index 1-"..MAX_POIS.."> <short description to show users>", 
	description = "Sets the POI at the given index to teleport to the current location.",
	privs = {manage_pois=true},
	func = set_poi,
})

minetest.register_chatcommand("rmpoi", {
	params = "<index 1-"..MAX_POIS..">", 
	description = "Removes the point of interest from the list shown to user",
	privs = {manage_pois=true},
	func = remove_poi,
})

minetest.register_chatcommand("swappoi", {
	params = "<first index 1-"..MAX_POIS.."> <second index 0-99>", 
	description = "Swaps the points of interest at the two given indeces.",
	privs = {manage_pois=true},
	func = move_poi,
})

minetest.register_chatcommand("editpoi", {
	params = "<first index 1-"..MAX_POIS.."> <New one-line description>", 
	description = "Allows editing the description of a POI without changing its location.",
	privs = {manage_pois=true},
	func = edit_poi,
})

minetest.register_on_player_receive_fields(on_poi_dialog_callback)