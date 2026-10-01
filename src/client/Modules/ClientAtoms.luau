local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local StyleLayouts = require(ReplicatedStorage.Shared.Data.StyleLayouts)

export type Message = {
	id: number,
	text: string,
}

export type SwitchEditorsPrompt = {
	creationPrice: number,
	onBuy: () -> (),
	onContinue: () -> (),
	onCancel: () -> (),
}

export type ToastVariant = "success" | "danger"

export type Toast = {
	id: number,
	text: string,
	variant: ToastVariant,
	emoji: string?,
	icon: (string | number)?,
	leaving: boolean?,
}

--[=[
	@class ClientAtoms
	@client

	Shared client state atoms. Add atoms here as client systems need cross-cutting state.

	`creationSession` holds the open [CreationSession] (nil outside the editor); typed `any` because
	the session requires this module. `isMobile` derives the mobile layout from `viewportSize`.
	`loadingVisible`, `messages` and `switchEditorsPrompt` drive the editor's full-screen overlays.
]=]
local initialViewportSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)

local viewportSize = Charm.atom(initialViewportSize :: Vector2)

return {
	viewportSize = viewportSize,
	isMobile = Charm.computed(function()
		local size = viewportSize()
		return size.X <= StyleLayouts.mobileWidthCutoff and size.Y <= StyleLayouts.mobileWidthCutoff
	end),
	creationSession = Charm.atom(nil :: any),
	loadingVisible = Charm.atom(false),
	messages = Charm.atom({} :: { Message }),
	switchEditorsPrompt = Charm.atom(nil :: SwitchEditorsPrompt?),
	toasts = Charm.atom({} :: { Toast }),
	cash = Charm.atom(0),
	pending = Charm.atom(0),
}
