local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ColorPicker = require("../Components/ColorPicker")
local Create = require(ReplicatedStorage.Shared.Modules.Create)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local Panel = require("../Components/Panel")
local ReflectivityToggle = require("../Components/ReflectivityToggle")
local Slider = require("../Components/Slider")
local StyleConsts = require("../Style/StyleConsts")
local ToolFrame = require("../Components/ToolFrame")

export type BrushToolUI = {
	-- vars
	panel: Panel.Panel,
	maid: Maid.Maid,
	-- methods
	open: (self: BrushToolUI) -> (),
	close: (self: BrushToolUI) -> (),
	destroy: (self: BrushToolUI) -> (),
}

--[=[
	@class BrushToolUI
	@client

	The paintbrush panel: a size slider and a color picker. Owned by [EditingUI].
]=]
local function BrushToolUI(
	_creationInput: any,
	onClosePanelCallback: () -> (),
	onDeleteCallback: () -> (),
	defaultSliderVal: number,
	onSliderChangedCallback: (number, boolean) -> (),
	onColorChangedCallback: (Color3, boolean) -> (),
	onReflectiveModeChangedCallback: (boolean) -> (),
	onTransparencyChangedCallback: (number) -> ()
): BrushToolUI
	local maid = Maid.new()
	local object = {} :: BrushToolUI

	object.maid = maid

	local scrollingFrame = Create("ScrollingFrame", {
		Tags = { StyleConsts.tags.ScrollFrame },
	})

	local slider = maid:add(Slider(defaultSliderVal, onSliderChangedCallback))
	local sliderTool = ToolFrame(slider.frame, "Brush Size")
	sliderTool.Parent = scrollingFrame
	sliderTool.LayoutOrder = 1

	local colorPicker = maid:add(ColorPicker(onColorChangedCallback, onTransparencyChangedCallback))
	local reflectivityToggle = ReflectivityToggle(onReflectiveModeChangedCallback, false)
	local colorPickerTool = ToolFrame(colorPicker.frame, "Color", reflectivityToggle)
	colorPickerTool.Parent = scrollingFrame
	colorPickerTool.LayoutOrder = 2

	object.panel = maid:add(Panel("Paintbrush", onClosePanelCallback, onDeleteCallback, { scrollingFrame }))
	object.panel.frame.Name = "BrushToolPanel"
	object.panel.frame.Visible = false

	--[=[
		@within BrushToolUI
	]=]
	function object:open()
		self.panel.frame.Visible = true
	end

	--[=[
		@within BrushToolUI
	]=]
	function object:close()
		self.panel.frame.Visible = false
	end

	function object:destroy()
		maid:doCleaning()
	end

	return object
end

return BrushToolUI
