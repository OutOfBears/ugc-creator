local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ColorPicker = require("../Components/ColorPicker")
local Create = require(ReplicatedStorage.Shared.Modules.Create)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local Panel = require("../Components/Panel")
local ReflectivityToggle = require("../Components/ReflectivityToggle")
local RegionPicker = require("../Components/RegionPicker")
local StyleConsts = require("../Style/StyleConsts")
local ToolFrame = require("../Components/ToolFrame")

export type FillToolUI = {
	-- vars
	panel: Panel.Panel,
	maid: Maid.Maid,
	-- methods
	open: (self: FillToolUI) -> (),
	close: (self: FillToolUI) -> (),
	destroy: (self: FillToolUI) -> (),
}

--[=[
	@class FillToolUI
	@client

	The recolor panel: a region selector and a color picker, for filling whole regions of the
	creation. Owned by [EditingUI].
]=]
local function FillToolUI(
	_creationInput: any,
	onClosePanelCallback: () -> (),
	onDeleteCallback: () -> (),
	regionParts: { string },
	onRegionSelectedCallback: (string) -> (),
	onColorChangedCallback: (Color3, boolean) -> (),
	onReflectiveModeChangedCallback: (boolean) -> (),
	onOpacityChangedCallback: (number) -> ()
): FillToolUI
	local maid = Maid.new()
	local object = {} :: FillToolUI

	object.maid = maid

	local scrollingFrame = Create("ScrollingFrame", {
		Tags = { StyleConsts.tags.ScrollFrame },
	})

	local modelDisplayName = StyleConsts.modelDisplayName[regionParts[1]]

	local regionPillbar = RegionPicker(regionParts, onRegionSelectedCallback)
	local regionSelectTool = ToolFrame(regionPillbar, `{modelDisplayName} Section`)
	regionSelectTool.Parent = scrollingFrame
	regionSelectTool.LayoutOrder = 1

	local colorPicker = maid:add(ColorPicker(onColorChangedCallback, onOpacityChangedCallback))
	local reflectivityToggle = ReflectivityToggle(onReflectiveModeChangedCallback, false)
	local colorPickerTool = ToolFrame(colorPicker.frame, "Color", reflectivityToggle)
	colorPickerTool.Parent = scrollingFrame
	colorPickerTool.LayoutOrder = 2

	object.panel = maid:add(Panel("Recolor", onClosePanelCallback, onDeleteCallback, { scrollingFrame }))
	object.panel.frame.Name = "FillToolPanel"
	object.panel.frame.Visible = false

	--[=[
		@within FillToolUI
	]=]
	function object:open()
		self.panel.frame.Visible = true
	end

	--[=[
		@within FillToolUI
	]=]
	function object:close()
		self.panel.frame.Visible = false
	end

	function object:destroy()
		maid:doCleaning()
	end

	return object
end

return FillToolUI
