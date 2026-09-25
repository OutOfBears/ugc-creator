local function EnumCreator<T>(name: string, values: T)
	local reverse = {}
	local newValue = {}

	local function toString(value: number): string
		return reverse[tonumber(value)]
	end

	local function nextValue(currentValue: number): T
		currentValue = (tonumber(currentValue) :: number) + 1
		if currentValue > #(values :: any) then
			currentValue = 1
		end

		return values
	end

	local function hasValue(value: number): boolean
		return reverse[tonumber(value)] ~= nil
	end

	local function hasKey(key: string): boolean
		return newValue[key] ~= nil
	end

	local function getEnumItems(): { number }
		local items = {}
		for _, val in values :: any do
			table.insert(items, val)
		end
		return items
	end

	local function getEnumKeys(): { string }
		local keys = {}
		for key, _ in values :: any do
			table.insert(keys, key)
		end
		return keys
	end

	for key, val in values :: any do
		reverse[tonumber(val)] = key
		newValue[key] = val
	end

	newValue.Next = nextValue
	newValue.ToString = toString
	newValue.HasValue = hasValue
	newValue.HasKey = hasKey
	newValue.GetEnumItems = getEnumItems
	newValue.GetEnumKeys = getEnumKeys

	setmetatable(newValue, {
		__index = function(self, key: string)
			error(`"{key}" is not a valid member of "{name}"`, 3)
		end,
		__tostring = function()
			return `CustomEnum.{name}`
		end,
	})

	table.freeze(newValue)

	return (newValue :: any) :: typeof(values) & {
		Next: typeof(newValue.Next),
		ToString: typeof(newValue.ToString),
		HasValue: typeof(newValue.HasValue),
		HasKey: typeof(newValue.HasKey),
		GetEnumItems: typeof(newValue.GetEnumItems),
		GetEnumKeys: typeof(newValue.GetEnumKeys),
	}
end

return EnumCreator
