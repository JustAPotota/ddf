# DDF
This library provides functions to decode and encode Defold Data Format files (.collection, .sprite, .tilemap, etc.).

## Installation
Use this library in your own project by [adding it as a dependency](https://defold.com/manuals/libraries/#setting-up-library-dependencies) using this URL:
> https://github.com/JustAPotota/ddf/archive/main.zip

This library also currently requires [Defold-Protobuf](https://github.com/Melsoft-Games/defold-protobuf):
> https://github.com/Melsoft-Games/defold-protobuf/archive/master.zip

Lastly, add `/ddf/proto` to the "Custom Resources" field of your `game.project` file.

## Usage
Add the [`ddf` module](ddf/ddf.lua) to your script with:

```lua
local ddf = require("ddf.ddf")
```

The module contains a decode and encode function for each supported type, e.g. `decode_collection()`, `encode_collection()`, `decode_tilemap()`, `encode_tilemap()`. The decode function takes the contents of a DDF file as a string and returns a table with the decoded contents. The encode function takes that table and returns the encoded string.

## Example
```lua
local ddf = require("ddf.ddf")

function init(self)
	-- Load and decode tilemap
	local file = io.open("main/level.tilemap", "r")
	local map = ddf.decode_tilemap(file:read("*a"))
	file:close()

	-- Flip every tile in layer 1 horizontally
	for i, cell in ipairs(map.layers[1].cell) do
		cell.h_flip = 1
	end

	-- Encode and save tilemap
	local file = io.open("main/level.tilemap", "w")
	file:write(ddf.encode_tilemap(map))
	file:close()
end
```
