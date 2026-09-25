local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

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
]=]
local initialViewportSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)

return {
	viewportSize = Charm.atom(initialViewportSize :: Vector2),
	toasts = Charm.atom({} :: { Toast }),
	cash = Charm.atom(0),
	pending = Charm.atom(0),
}
