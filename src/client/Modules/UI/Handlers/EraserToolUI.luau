local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local Panel = require("../Components/Panel")
local Slider = require("../Components/Slider")
local ToolFrame = require("../Components/ToolFrame")

export type EraserToolUI = {
	-- vars
	panel: Panel.Panel,
	maid: Maid.Maid,
	-- methods
	open: (self: EraserToolUI) -> (),
	close: (self: EraserToolUI) -> (),
	destroy: (self: EraserToolUI) -> (),
}

--[=[
	@class EraserToolUI
	@client

	The eraser panel: a size slider. Owned by [EditingUI].
]=]
local function EraserToolUI(
	_creationInput: any,
	onClosePanelCallback: () -> (),
	onDeleteCallback: () -> (),
	defaultSliderVal: number,
	onSliderChangedCallback: (number, boolean) -> ()
): EraserToolUI
	local maid = Maid.new()
	local object = {} :: EraserToolUI

	object.maid = maid

	local slider = maid:add(Slider(defaultSliderVal, onSliderChangedCallback))
	local sliderTool = ToolFrame(slider.frame, "Brush Size")

	object.panel = maid:add(Panel("Eraser", onClosePanelCallback, onDeleteCallback, { sliderTool }))
	object.panel.frame.Name = "EraserToolPanel"
	object.panel.frame.Visible = false

	--[=[
		@within EraserToolUI
	]=]
	function object:open()
		self.panel.frame.Visible = true
	end

	--[=[
		@within EraserToolUI
	]=]
	function object:close()
		self.panel.frame.Visible = false
	end

	function object:destroy()
		maid:doCleaning()
	end

	return object
end

return EraserToolUI
