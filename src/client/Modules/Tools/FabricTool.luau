local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actions = require(ReplicatedStorage.Shared.Modules.Actions)
local ImageEditActions = require(ReplicatedStorage.Shared.Modules.Actions.ImageEditActions)
local ModelInfo = require(ReplicatedStorage.Shared.Modules.ModelInfo)
local Network = require(ReplicatedStorage.Shared.Modules.Network).client()
local StyleConsts = require("../UI/Style/StyleConsts")
local TextureInfo = require(ReplicatedStorage.Shared.Modules.TextureInfo)

export type FabricTool = {
	-- vars
	modelInfo: ModelInfo.ModelInfo,
	fillOpacity: number,
	isReflectiveMode: boolean,
	lastAppliedColor: Color3,
	selectedRegionName: string?,
	-- methods
	applyColorRegion: (self: FabricTool, color: Color3, isFinalInput: boolean) -> (),
	setOpacity: (self: FabricTool, newOpacity: number) -> (),
	setIsReflective: (self: FabricTool, isReflectiveMode: boolean) -> (),
	reapplyFillForReflectivity: (self: FabricTool) -> (),
	applyColor: (self: FabricTool, color: Color3, isFinalInput: boolean) -> (),
	clearAll: (self: FabricTool) -> (),
	setSelectedRegion: (self: FabricTool, regionName: string) -> (),
	destroy: (self: FabricTool) -> (),
}

--[=[
	@class FabricTool
	@client

	Changes the base color of a creation, either across the whole model or within the selected
	region.
]=]
local function FabricTool(modelInfo: ModelInfo.ModelInfo): FabricTool
	local object = {} :: FabricTool

	object.modelInfo = modelInfo
	object.fillOpacity = 1
	object.isReflectiveMode = false
	object.lastAppliedColor = Color3.fromHSV(
		StyleConsts.defaultColorPickerColor.h,
		StyleConsts.defaultColorPickerColor.s,
		StyleConsts.defaultColorPickerColor.v
	)

	object.selectedRegionName = nil

	--[=[
		@within FabricTool
		@param color Color3 -- the fill color
		@param isFinalInput boolean -- true on the last input of a drag, which is what mirrors to the server

		Recolors only the selected region.
	]=]
	function object:applyColorRegion(color: Color3, isFinalInput: boolean)
		local recolorActionMetadata: ImageEditActions.RecolorRegionActionMetadata = {
			regionName = self.selectedRegionName,
			color = color,
			opacity = self.fillOpacity,
			isReflectiveMode = self.isReflectiveMode,
		}

		local recolorAction = Actions.createAction(Actions.ActionTypes.RecolorRegion, recolorActionMetadata)

		Actions.executeAction(self.modelInfo, recolorAction)

		if isFinalInput then
			Network.fire("SubmitAction", recolorAction)
		end

		local textureInfo: TextureInfo.TextureInfo = self.modelInfo:getTextureInfo()
		local region: TextureInfo.Region = textureInfo:getRegion(self.selectedRegionName)
		local uniqueLayersForMeshParts = textureInfo:getUniqueLayerMapForMeshPartNames(region.meshPartNames)

		for meshPart, _ in uniqueLayersForMeshParts do
			textureInfo:updateOutputColorMap(meshPart)
		end
	end

	--[=[
		@within FabricTool
		@param newOpacity number -- opacity subsequent fills are drawn with
	]=]
	function object:setOpacity(newOpacity: number)
		self.fillOpacity = newOpacity
	end

	--[=[
		@within FabricTool
		@param isReflectiveMode boolean -- whether fills also write the reflective PBR maps
	]=]
	function object:setIsReflective(isReflectiveMode: boolean)
		self.isReflectiveMode = isReflectiveMode
	end

	--[=[
		@within FabricTool

		Updates metalness/roughness for the current fill when only reflectivity toggles. Region
		fills go through ApplyPBRToRegion so no pixel is recolored; a whole-body fill has to
		re-run the recolor.
	]=]
	function object:reapplyFillForReflectivity()
		if self.selectedRegionName then
			local pbrMetadata: ImageEditActions.ApplyPBRToRegionActionMetadata = {
				regionName = self.selectedRegionName,
				isReflectiveMode = self.isReflectiveMode,
			}

			local pbrAction = Actions.createAction(Actions.ActionTypes.ApplyPBRToRegion, pbrMetadata)

			Actions.executeAction(self.modelInfo, pbrAction)
			Network.fire("SubmitAction", pbrAction)

			local textureInfo: TextureInfo.TextureInfo = self.modelInfo:getTextureInfo()
			local region: TextureInfo.Region = textureInfo:getRegion(self.selectedRegionName)
			local uniqueLayersForMeshParts = textureInfo:getUniqueLayerMapForMeshPartNames(region.meshPartNames)

			for meshPart, _ in uniqueLayersForMeshParts do
				textureInfo:updateOutputColorMap(meshPart)
			end
		else
			self:applyColor(self.lastAppliedColor, true)
		end
	end

	--[=[
		@within FabricTool
		@param color Color3 -- the fill color
		@param isFinalInput boolean -- true on the last input of a drag, which is what mirrors to the server

		Fills the selected region, or every layer on the model when nothing is selected.
	]=]
	function object:applyColor(color: Color3, isFinalInput: boolean)
		self.lastAppliedColor = color
		if self.selectedRegionName then
			self:applyColorRegion(color, isFinalInput)
			return
		end

		local textureInfo: TextureInfo.TextureInfo = self.modelInfo:getTextureInfo()

		local uniqueLayerMap = textureInfo:getUniqueLayerMap()
		for meshPart, _ in uniqueLayerMap do
			local recolorActionMetadata: ImageEditActions.RecolorActionMetadata = {
				targetMeshPartName = meshPart.Name,
				color = color,
				opacity = self.fillOpacity,
				isReflectiveMode = self.isReflectiveMode,
			}

			local recolorAction = Actions.createAction(Actions.ActionTypes.Recolor, recolorActionMetadata)

			Actions.executeAction(self.modelInfo, recolorAction)

			if isFinalInput then
				Network.fire("SubmitAction", recolorAction)
			end

			textureInfo:updateOutputColorMap(meshPart)
		end
	end

	--[=[
		@within FabricTool

		Clears every fill layer on the model.
	]=]
	function object:clearAll()
		local textureInfo: TextureInfo.TextureInfo = self.modelInfo:getTextureInfo()

		local uniqueLayerMap = textureInfo:getUniqueLayerMap()
		for meshPart, _ in uniqueLayerMap do
			local clearActionMetadata: ImageEditActions.ClearActionMetadata = {
				targetMeshPartName = meshPart.Name,
			}

			local clearAction = Actions.createAction(Actions.ActionTypes.Clear, clearActionMetadata)

			Actions.executeAction(self.modelInfo, clearAction)

			Network.fire("SubmitAction", clearAction)

			textureInfo:updateOutputColorMap(meshPart)
		end
	end

	--[=[
		@within FabricTool
		@param regionName string -- the region to fill; a whole-model name clears the selection
	]=]
	function object:setSelectedRegion(regionName: string)
		if regionName and string.find(regionName, "Model") then
			self.selectedRegionName = nil
			return
		end

		self.selectedRegionName = regionName
	end

	function object:destroy() end

	return object
end

return FabricTool
