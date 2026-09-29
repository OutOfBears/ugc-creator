local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationIcons = require(ReplicatedStorage.Shared.Data.CreationIcons)
local React = require(ReplicatedStorage.Packages.React)

local HorizontalPillbar = require("./HorizontalPillbar")

local createElement = React.createElement
local memo = React.memo
local useMemo = React.useMemo
local useState = React.useState

export type RegionPickerProps = {
	regionParts: { string },
	onSelect: (regionName: string) -> (),
}

--[=[
	@class RegionPicker
	@client

	A [HorizontalPillbar] of region icons ordered by [CreationConfig].`regionOrdering`, so the whole
	model comes first and starts selected.
]=]
local RegionPicker = memo(function(props: RegionPickerProps)
	local selectedIndex, setSelectedIndex = useState(1)

	local sortedParts = useMemo(function()
		local parts = table.clone(props.regionParts)
		table.sort(parts, function(a, b)
			return CreationConfig.regionOrdering[a] < CreationConfig.regionOrdering[b]
		end)

		return parts
	end, { props.regionParts })

	local icons = {}
	for index, partName in sortedParts do
		icons[index] = CreationIcons.regionIcons[partName]
	end

	return createElement(HorizontalPillbar, {
		icons = icons,
		selectedIndex = selectedIndex,
		onSelect = function(index: number)
			setSelectedIndex(index)
			props.onSelect(sortedParts[index])
		end,
	})
end)

return RegionPicker
