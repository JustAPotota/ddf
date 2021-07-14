local protoc = require("pb.protoc")
protoc = protoc.new()
protoc:load(sys.load_resource("/ddf/proto/ddf.proto"))

local M = {}

local function find_message(name, t, path)
	for _,message in ipairs(t) do
		if path .. "." .. message.name == name then
			return message
		elseif message.nested_type then
			local nested = find_message(name, message.nested_type, path .. "." .. message.name)
			if nested then return nested end
		end
	end
end

-- Search through every definition file to find the message table for a given type name
local typemap = {}
local function get_message(name)
	if typemap[name] then return typemap[name] end
	for _,proto in pairs(protoc.loaded) do
		if proto.package then
			local message = find_message(name, proto.message_type, "." .. proto.package)
			if message then
				typemap[name] = message
				return message
			end
		end
	end
	print("Unable to find message " .. name)
end

local function get_field(k, message)
	for _,v in ipairs(message.field) do
		if k == v.name then
			return v
		end
	end
	print("Unable to find field " .. k .. " in message " .. message.name)
end

-- Add n tabs to each line of s
local function indent(s, n)
	local tab = ("  "):rep(n)
	return tab .. s:gsub("\n", "\n" .. tab)
end

function M.encode(t, message)
	local out = ""

	for k,f in pairs(t) do
		local field = get_field(k, message)
		local fields = (field.label == 3 and f or {f})

		for i,v in ipairs(fields) do
			local type_v = type(v)
			if type_v == "string"  then
				if field.type == 9 then -- String
					out = out .. ('%s: "%s"\n'):format(k,v)
				else 					-- Enum
					out = out .. ("%s: %s\n"):format(k,v)
				end

			elseif type_v == "number" then
				if field.type == 2 or field.type == 1 then 	-- Decimal
					out = out .. ("%s: %f\n"):format(k,v)
				else 										-- Integer
					out = out .. ("%s: %i\n"):format(k,v)
				end

			elseif type_v ==  "boolean" then
				out = out .. ("%s: %s\n"):format(k, v and "true" or "false")

			elseif type_v == "table" then
				out = out .. ("%s {\n%s}\n"):format(k,indent(M.encode(v, get_message(field.type_name)), 1):sub(1,-3))
			end
		end
	end

	return out
end

function M.decode(s, message)
	local depth = 0
	local out = {}
	out[0] = {}

	local last_key = ""

	-- Loop through every line
	for line in s:gmatch("[^\n]+") do
		local line = line:gsub("^[\t%s]+", "") -- Remove beginning tabs
		if line:sub(1,1):find("%w") then -- Field
			local key = line:match("^[%w_]+")
			local field = get_field(key, (depth > 0 and out[depth]._message or message))
			local is_array = field.label == 3
			if line:find("^[%w_]+:") then -- Value
				local value = line:match("^[%w_]+: ([^\n]+)")

				local decoded_value
				if field.type == 8 then					-- Bool
					decoded_value = value == "true"
				elseif tonumber(value) then				-- Number
					decoded_value = tonumber(value)
				else									-- String/Enum
					decoded_value = value:match('"?(.*[^\\"])"?') or ""
					last_key = key
				end

				if is_array then
					out[depth][key] = out[depth][key] or {}
					table.insert(out[depth][key], decoded_value)
				else
					out[depth][key] = decoded_value
				end
			else -- Start of message
				depth = depth + 1

				-- Add some extra info we'll need later
				out[depth] = {_key = key, _message = get_message(field.type_name), _is_array = is_array}
			end
		elseif line:sub(1,1) == "}" then -- End of message
			local message = out[depth]
			depth = depth - 1

			local key = message._key
			local is_array = message._is_array

			-- Remove the extra info we added so it doesn't get encoded
			message._key, message._message, message._is_array = nil, nil, nil
			
			if is_array then
				out[depth][key] = out[depth][key] or {}
				table.insert(out[depth][key], message)
			else
				out[depth][key] = message
			end
		elseif line:sub(1,1) == '"' then -- Multi-line string
			-- Just collapse it into a single-line string to make it easy
			out[depth][last_key] = out[depth][last_key] .. line:match('"(.*)[^\\]?"')
		end
	end

	return out[0]
end


-- camera_ddf.proto
function M.encode_camera(t) return M.encode(t, protoc.loaded["/ddf/proto/camera_ddf.proto"].message_type[1]) end
function M.decode_camera(s) return M.decode(s, protoc.loaded["/ddf/proto/camera_ddf.proto"].message_type[1]) end


-- font_ddf.proto
function M.encode_font(t) return M.encode(t, protoc.loaded["/ddf/proto/font_ddf.proto"].message_type[1]) end
function M.decode_font(s) return M.decode(s, protoc.loaded["/ddf/proto/font_ddf.proto"].message_type[1]) end


-- sound_ddf.proto
function M.encode_sound(t) return M.encode(t, protoc.loaded["/ddf/proto/sound_ddf.proto"].message_type[1]) end
function M.decode_sound(s) return M.decode(s, protoc.loaded["/ddf/proto/sound_ddf.proto"].message_type[1]) end


-- gameobject/gameobject_ddf.proto
function M.encode_collection(t) return M.encode(t, protoc.loaded["/ddf/proto/gameobject/gameobject_ddf.proto"].message_type[10]) end
function M.decode_collection(s) return M.decode(s, protoc.loaded["/ddf/proto/gameobject/gameobject_ddf.proto"].message_type[10]) end

function M.encode_go(t) return M.encode(t, protoc.loaded["/ddf/proto/gameobject/gameobject_ddf.proto"].message_type[4]) end
function M.decode_go(s) return M.decode(s, protoc.loaded["/ddf/proto/gameobject/gameobject_ddf.proto"].message_type[4]) end


-- gamesys/atlas_ddf.proto
function M.encode_atlas(t) return M.encode(t, protoc.loaded["/ddf/proto/gamesys/atlas_ddf.proto"].message_type[3]) end
function M.decode_atlas(s) return M.decode(s, protoc.loaded["/ddf/proto/gamesys/atlas_ddf.proto"].message_type[3]) end


-- gamesys/gamesys_ddf.proto
function M.encode_factory(t) return M.encode(t, protoc.loaded["/ddf/proto/gamesys/gamesys_ddf.proto"].message_type[1]) end
function M.decode_factory(s) return M.decode(s, protoc.loaded["/ddf/proto/gamesys/gamesys_ddf.proto"].message_type[1]) end

function M.encode_collectionfactory(t) return M.encode(t, protoc.loaded["/ddf/proto/gamesys/gamesys_ddf.proto"].message_type[2]) end
function M.decode_collectionfactory(s) return M.decode(s, protoc.loaded["/ddf/proto/gamesys/gamesys_ddf.proto"].message_type[2]) end

function M.encode_collectionproxy(t) return M.encode(t, protoc.loaded["/ddf/proto/gamesys/gamesys_ddf.proto"].message_type[4]) end
function M.decode_collectionproxy(s) return M.decode(s, protoc.loaded["/ddf/proto/gamesys/gamesys_ddf.proto"].message_type[4]) end

function M.encode_light(t) return M.encode(t, protoc.loaded["/ddf/proto/gamesys/gamesys_ddf.proto"].message_type[6]) end
function M.decode_light(s) return M.decode(s, protoc.loaded["/ddf/proto/gamesys/gamesys_ddf.proto"].message_type[6]) end


-- gamesys/gui_ddf.proto
function M.encode_gui(t) return M.encode(t, protoc.loaded["/ddf/proto/gamesys/gui_ddf.proto"].message_type[2]) end
function M.decode_gui(s) return M.decode(s, protoc.loaded["/ddf/proto/gamesys/gui_ddf.proto"].message_type[2]) end


-- gamesys/label_ddf.proto
function M.encode_label(t) return M.encode(t, protoc.loaded["/ddf/proto/gamesys/label_ddf.proto"].message_type[1]) end
function M.decode_label(s) return M.decode(s, protoc.loaded["/ddf/proto/gamesys/label_ddf.proto"].message_type[1]) end


-- gamesys/model_ddf.proto
function M.encode_model(t) return M.encode(t, protoc.loaded["/ddf/proto/gamesys/model_ddf.proto"].message_type[1]) end
function M.decode_model(s) return M.decode(s, protoc.loaded["/ddf/proto/gamesys/model_ddf.proto"].message_type[1]) end


-- gamesys/physics_ddf.proto
function M.encode_collisionobject(t) return M.encode(t, protoc.loaded["/ddf/proto/gamesys/physics_ddf.proto"].message_type[3]) end
function M.decode_collisionobject(s) return M.decode(s, protoc.loaded["/ddf/proto/gamesys/physics_ddf.proto"].message_type[3]) end


-- gamesys/spine_ddf.proto
function M.encode_spinescene(t) return M.encode(t, protoc.loaded["/ddf/proto/gamesys/spine_ddf.proto"].message_type[1]) end
function M.decode_spinescene(s) return M.decode(s, protoc.loaded["/ddf/proto/gamesys/spine_ddf.proto"].message_type[1]) end

function M.encode_spinemodel(t) return M.encode(t, protoc.loaded["/ddf/proto/gamesys/spine_ddf.proto"].message_type[2]) end
function M.decode_spinemodel(s) return M.decode(s, protoc.loaded["/ddf/proto/gamesys/spine_ddf.proto"].message_type[2]) end


-- gamesys/sprite_ddf.proto
function M.encode_sprite(t) return M.encode(t, protoc.loaded["/ddf/proto/gamesys/sprite_ddf.proto"].message_type[1]) end
function M.decode_sprite(s) return M.decode(s, protoc.loaded["/ddf/proto/gamesys/sprite_ddf.proto"].message_type[1]) end


-- gamesys/tile_ddf.proto
function M.encode_tilemap(t) return M.encode(t, protoc.loaded["/ddf/proto/gamesys/tile_ddf.proto"].message_type[7]) end
function M.decode_tilemap(s) return M.decode(s, protoc.loaded["/ddf/proto/gamesys/tile_ddf.proto"].message_type[7]) end


-- graphics/graphics_ddf.proto
function M.encode_cubemap(t) return M.encode(t, protoc.loaded["/ddf/proto/graphics/graphics_ddf.proto"].message_type[1]) end
function M.decode_cubemap(s) return M.decode(s, protoc.loaded["/ddf/proto/graphics/graphics_ddf.proto"].message_type[1]) end

function M.encode_texture_profiles(t) return M.encode(t, protoc.loaded["/ddf/proto/graphics/graphics_ddf.proto"].message_type[7]) end
function M.decode_texture_profiles(s) return M.decode(s, protoc.loaded["/ddf/proto/graphics/graphics_ddf.proto"].message_type[7]) end


-- input/input_ddf.proto
function M.encode_input_binding(t) return M.encode(t, protoc.loaded["/ddf/proto/input/input_ddf.proto"].message_type[10]) end
function M.decode_input_binding(s) return M.decode(s, protoc.loaded["/ddf/proto/input/input_ddf.proto"].message_type[10]) end


-- particle/particle_ddf.proto
function M.encode_particlefx(t) return M.encode(t, protoc.loaded["/ddf/proto/particle/particle_ddf.proto"].message_type[4]) end
function M.decode_particlefx(s) return M.decode(s, protoc.loaded["/ddf/proto/particle/particle_ddf.proto"].message_type[4]) end


-- render/material_ddf.proto
function M.encode_material(t) return M.encode(t, protoc.loaded["/ddf/proto/render/material_ddf.proto"].message_type[1]) end
function M.decode_material(s) return M.decode(s, protoc.loaded["/ddf/proto/render/material_ddf.proto"].message_type[1]) end


-- render/render_ddf.proto
function M.encode_render(t) return M.encode(t, protoc.loaded["/ddf/proto/render/render_ddf.proto"].message_type[1]) end
function M.decode_render(s) return M.decode(s, protoc.loaded["/ddf/proto/render/render_ddf.proto"].message_type[1]) end

function M.encode_display_profiles(t) return M.encode(t, protoc.loaded["/ddf/proto/render/render_ddf.proto"].message_type[10]) end
function M.decode_display_profiles(s) return M.decode(s, protoc.loaded["/ddf/proto/render/render_ddf.proto"].message_type[10]) end


-- rig/rig_ddf.proto
function M.encode_animationset(t) return M.encode(t, protoc.loaded["/ddf/proto/rig/rig_ddf.proto"].message_type[12]) end
function M.decode_animationset(s) return M.decode(s, protoc.loaded["/ddf/proto/rig/rig_ddf.proto"].message_type[12]) end


return M