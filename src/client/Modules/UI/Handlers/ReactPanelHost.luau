local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local CreationScope = require(ReplicatedStorage.Interfaces.Components.CreationScope)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local StyleLayouts = require(ReplicatedStorage.Shared.Data.StyleLayouts)
local StyleUtils = require("../Style/StyleUtils")

local createElement = React.createElement

export type ReactPanelHost = {
	-- vars
	panel: { frame: Frame },
	maid: Maid.Maid,
	-- methods
	open: (self: ReactPanelHost) -> (),
	close: (self: ReactPanelHost) -> (),
	destroy: (self: ReactPanelHost) -> (),
}

--[=[
	@class ReactPanelHost
	@client

	Temporary bridge that lets [EditingUI] own a React panel view while the rest of the editor is
	still vanilla. The view renders in its own ScreenGui laid over `panelParent`, because the
	editor's StyleSheet would restyle any of its properties left at their engine default. A
	transparent placeholder takes the panel's slot in `panelParent` so the toolbar layout and the UV
	canvas anchor behave as they did.

	@param editingUI any -- the owning [EditingUI]; its `screenGui`, `panelParent` and `session` are read
	@param view any -- a React panel view taking `{ visible: boolean, onClose: () -> () }`
	@param onClose () -> () -- fired by the panel's close button
	@return ReactPanelHost
]=]
local function ReactPanelHost(editingUI: any, view: any, onClose: () -> ()): ReactPanelHost
	local maid = Maid.new()
	local object = {} :: ReactPanelHost

	local editingGui: ScreenGui = editingUI.screenGui
	local panelParent: Frame = editingUI.panelParent
	local session = editingUI.session

	local isVisible = false

	object.maid = maid

	local placeholder = maid:add(Create("Frame", {
		Name = "ReactPanelPlaceholder",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		Parent = panelParent,
	})) :: Frame
	object.panel = { frame = placeholder }

	local hostGui = maid:add(Create("ScreenGui", {
		Name = "ReactPanelHost",
		DisplayOrder = editingGui.DisplayOrder,
		IgnoreGuiInset = editingGui.IgnoreGuiInset,
		ScreenInsets = editingGui.ScreenInsets,
		ResetOnSpawn = false,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})) :: ScreenGui

	local root = ReactRoblox.createRoot(hostGui)
	maid:add(function()
		root:unmount()
	end)

	local function render()
		local isMobile = StyleUtils.getIsMobile(editingGui)
		local layout = if isMobile then StyleLayouts.mobile else StyleLayouts.desktop

		placeholder.AnchorPoint = layout.PanelAnchorPoint
		placeholder.Position = layout.PanelPosition
		placeholder.Size = layout.PanelSize
		placeholder.Visible = isVisible

		hostGui.Enabled = editingGui.Enabled

		root:render(createElement("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(panelParent.AbsolutePosition.X, panelParent.AbsolutePosition.Y),
			Size = UDim2.fromOffset(panelParent.AbsoluteSize.X, panelParent.AbsoluteSize.Y),
		}, {
			scope = createElement(CreationScope, {
				key = session.id,
				session = session,
				isMobile = isMobile,
			}, {
				panel = createElement(view, {
					visible = isVisible,
					onClose = onClose,
				}),
			}),
		}))
	end

	maid:add(panelParent:GetPropertyChangedSignal("AbsolutePosition"):Connect(render))
	maid:add(panelParent:GetPropertyChangedSignal("AbsoluteSize"):Connect(render))
	maid:add(editingGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(render))
	maid:add(editingGui:GetPropertyChangedSignal("Enabled"):Connect(render))

	--[=[
		@within ReactPanelHost
	]=]
	function object:open()
		isVisible = true
		render()
	end

	--[=[
		@within ReactPanelHost
	]=]
	function object:close()
		isVisible = false
		render()
	end

	function object:destroy()
		maid:doCleaning()
	end

	render()

	return object
end

return ReactPanelHost
