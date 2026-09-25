local MAX_DEPTH = 2

local function tableFormat(value: any, indent: number?, seen: { [any]: boolean }?)
	indent = indent or 0
	seen = seen or {}
	local pad = string.rep("  ", indent)
	local valueType = typeof(value)

	if valueType == "string" then
		return string.format("%q", value)
	elseif valueType == "number" or valueType == "boolean" or valueType == "nil" then
		return tostring(value)
	elseif valueType == "table" then
		if seen[value] then
			return "<cycle: " .. tostring(value) .. ">"
		end
		seen[value] = true

		if next(value) == nil then
			return "{}"
		end

		if indent > MAX_DEPTH then
			return "{...}"
		end

		local lines = { "{" }
		local innerPad = string.rep("  ", indent + 1)

		local arrayKeys = {}
		for i, v in ipairs(value) do
			arrayKeys[i] = true
			table.insert(lines, innerPad .. tableFormat(v, indent + 1, seen) .. ",")
		end

		local hashKeys = {}
		for k in pairs(value) do
			if not arrayKeys[k] then
				table.insert(hashKeys, k)
			end
		end
		table.sort(hashKeys, function(a, b)
			return tostring(a) < tostring(b)
		end)

		for _, k in ipairs(hashKeys) do
			local keyStr
			if type(k) == "string" and k:match("^[%a_][%w_]*$") then
				keyStr = k
			else
				keyStr = "[" .. tableFormat(k, indent + 1, seen) .. "]"
			end
			table.insert(lines, innerPad .. keyStr .. " = " .. tableFormat(value[k], indent + 1, seen) .. ",")
		end

		table.insert(lines, pad .. "}")
		return table.concat(lines, "\n")
	elseif valueType == "Instance" then
		return string.format("%s(%s)", value.ClassName, value:GetFullName())
	else
		local valueStr = tostring(value)
		-- trim whitespace at the start and end of the string, and replace newlines with \n
		valueStr = valueStr:gsub("^%s+", ""):gsub("%s+$", ""):gsub("\n", "\\n"):gsub("%s+", " ")
		return string.format("%s(%s)", valueType, valueStr)
	end
end

local function prettyPrint(...)
	local args = table.pack(...)
	local parts = {}

	for i = 1, args.n do
		table.insert(parts, tableFormat(args[i]))
	end

	print(table.concat(parts, "\t"))
end

return prettyPrint
