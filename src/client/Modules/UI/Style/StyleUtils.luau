local StyleConsts = require("./StyleConsts")

--[=[
	@class StyleUtils
	@client

	Helpers for working with the style system: tagging components so [StyleRules] can select them,
	and the screen-size and pointer maths the components share.
]=]
local StyleUtils = {}

--[=[
	@within StyleUtils
	@param component Instance -- the component to tag
	@param tag string -- a value from [StyleConsts].tags
]=]
function StyleUtils.addStyleTag(component: Instance, tag: string)
	if not tag then
		warn(`Cannot tag {component.Name}: tag is nil`)
	else
		component:AddTag(tag)
	end
end

--[=[
	@within StyleUtils
	@param component Instance -- the component to untag
	@param tag string -- a value from [StyleConsts].tags
]=]
function StyleUtils.removeStyleTag(component: Instance, tag: string)
	if not tag then
		warn(`Cannot untag {component.Name}: tag is nil`)
	else
		component:RemoveTag(tag)
	end
end

--[=[
	@within StyleUtils
	@param component GuiObject -- the component to measure against
	@param mousePosition Vector2 | Vector3 -- a screen-space pointer position
	@return Vector2 -- the pointer position within the component, clamped to 0-1 on both axes
]=]
function StyleUtils.getMousePositionScaleOnComponent(component: GuiObject, mousePosition: Vector2 | Vector3): Vector2
	local distanceFromLeft = mousePosition.X - component.AbsolutePosition.X
	local mousePositionXScale = math.clamp(distanceFromLeft / component.AbsoluteSize.X, 0, 1)

	local distanceFromTop = mousePosition.Y - component.AbsolutePosition.Y
	local mousePositionYScale = math.clamp(distanceFromTop / component.AbsoluteSize.Y, 0, 1)

	return Vector2.new(mousePositionXScale, mousePositionYScale)
end

--[=[
	@within StyleUtils
	@param screenGui ScreenGui -- the gui to measure
	@return boolean -- true when both axes fall under [StyleConsts].mobileWidthCutoff
]=]
function StyleUtils.getIsMobile(screenGui: ScreenGui): boolean
	if not screenGui then
		return false
	end

	return screenGui.AbsoluteSize.X <= StyleConsts.mobileWidthCutoff
		and screenGui.AbsoluteSize.Y <= StyleConsts.mobileWidthCutoff
end

return StyleUtils
