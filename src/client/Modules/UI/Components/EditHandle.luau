local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local CreationIcons = require(ReplicatedStorage.Shared.Data.CreationIcons)
local IconButton = require("./IconButton")
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local StyleConsts = require("../Style/StyleConsts")
local StyleTokens = require(ReplicatedStorage.Shared.Data.StyleTokens)
local StyleUtils = require("../Style/StyleUtils")

export type EditHandle = {
	-- vars
	moveHandle: TextButton,
	rotateHandle: TextButton,
	scaleHandle: TextButton,
	maid: Maid.Maid,
	-- methods
	refresh: (self: EditHandle, screenPos: Vector2, scale: number, rotation: number) -> (),
	destroy: (self: EditHandle) -> (),
}

--[=[
	@class EditHandle
	@client

	The handle used to move, rotate and resize stickers and kitbashing parts. It only draws itself —
	the tool that owns it connects the drag behaviour to the three buttons.

	@return EditHandle
]=]
local function EditHandle(): EditHandle
	local maid = Maid.new()
	local object = {} :: EditHandle

	object.maid = maid

	object.moveHandle = maid:add(Create("TextButton", {
		Name = "MoveHandle",
		Text = "",
		Tags = { StyleConsts.tags.MainHandle },
	}) :: TextButton)

	object.rotateHandle = IconButton(CreationIcons.icons.Rotate)
	object.rotateHandle.Name = "RotateHandle"
	StyleUtils.addStyleTag(object.rotateHandle, StyleConsts.tags.SmallHandle)
	object.rotateHandle.Parent = object.moveHandle

	object.scaleHandle = IconButton(CreationIcons.icons.Scale)
	object.scaleHandle.Name = "ScaleHandle"
	StyleUtils.addStyleTag(object.scaleHandle, StyleConsts.tags.SmallHandle)
	object.scaleHandle.Parent = object.moveHandle

	--[=[
		@within EditHandle
		@param screenPos Vector2 -- top-left offset of the handle in screen space
		@param scale number -- multiplier on the handle's default radius
		@param rotation number -- rotation of the handle in degrees
	]=]
	function object:refresh(screenPos: Vector2, scale: number, rotation: number)
		local defaultHandleRadius = StyleTokens.style.MainHandleDefaultRadius

		self.moveHandle.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
		self.moveHandle.Rotation = rotation
		self.moveHandle.Size = UDim2.fromOffset(defaultHandleRadius * scale, defaultHandleRadius * scale)

		local currentHandleRadius = defaultHandleRadius * scale / 2

		local rotateRadians = math.rad(StyleTokens.style.RotateHandlePosDegrees)
		local rotateHandlePos = Vector2.new(math.cos(rotateRadians), -math.sin(rotateRadians)) * currentHandleRadius
		rotateHandlePos = rotateHandlePos + Vector2.new(currentHandleRadius, currentHandleRadius)
		self.rotateHandle.Position = UDim2.fromOffset(rotateHandlePos.X, rotateHandlePos.Y)

		local scaleRadians = math.rad(StyleTokens.style.ScaleHandlePosDegrees)
		local scaleHandlePos = Vector2.new(math.cos(scaleRadians), -math.sin(scaleRadians)) * currentHandleRadius
		scaleHandlePos = scaleHandlePos + Vector2.new(currentHandleRadius, currentHandleRadius)
		self.scaleHandle.Position = UDim2.fromOffset(scaleHandlePos.X, scaleHandlePos.Y)
	end

	function object:destroy()
		maid:doCleaning()
	end

	return object
end

return EditHandle
