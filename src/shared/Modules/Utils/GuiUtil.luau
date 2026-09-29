local GuiService = game:GetService("GuiService")

--[=[
	@class GuiUtil

	Pointer maths shared by drag-driven GUI controls.
]=]

--[=[
	@within GuiUtil
	@param gui GuiObject -- the control being dragged across
	@param dragPosition Vector2 -- a `UIDragDetector` input position
	@return Vector2 -- the pointer's position within `gui`, clamped to 0-1 on both axes

	`UIDragDetector` positions exclude the top-left screen inset while `AbsolutePosition` includes
	it, so the inset is added back before measuring.
]=]
local function getDragScale(gui: GuiObject, dragPosition: Vector2): Vector2
	local position = dragPosition + GuiService:GetInsetArea(Enum.ScreenInsets.None).Min
	local relative = position - gui.AbsolutePosition
	local size = gui.AbsoluteSize

	return Vector2.new(math.clamp(relative.X / size.X, 0, 1), math.clamp(relative.Y / size.Y, 0, 1))
end

return {
	getDragScale = getDragScale,
}
