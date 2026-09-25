local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local StyleConsts = require("../Style/StyleConsts")

--[=[
	@class ToolFrame
	@client

	Titled frame housing a single tool inside a panel, such as a color picker or a pillbar.

	@param tool GuiObject -- the tool to display under the title
	@param label string -- the title text
	@param rightContent GuiObject? -- optional content pinned to the right of the title
	@return Frame -- the tool frame, with `tool` already parented
]=]
local function ToolFrame(tool: GuiObject, label: string, rightContent: GuiObject?): Frame
	local frame = Create("Frame", {
		Name = "Tool",
		Tags = { StyleConsts.tags.ToolFrame },
	}) :: Frame

	local toolTitleFrame = Create("Frame", {
		Name = "ToolTitle",
		LayoutOrder = 1,
		Tags = { StyleConsts.tags.ToolTitle },
		Children = {
			Create("TextLabel", {
				Name = "ToolTitleLabel",
				Text = label,
				LayoutOrder = 1,
			}),
		},
		Parent = frame,
	})

	if rightContent then
		rightContent.LayoutOrder = 2
		rightContent.Parent = toolTitleFrame
	end

	tool.LayoutOrder = 2
	tool.Parent = frame

	return frame
end

return ToolFrame
