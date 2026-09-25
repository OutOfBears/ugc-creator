export type UniverseTokens = {
	body: string,
	accessories: { [Enum.AvatarAssetType]: string },
}

export type CreationTokens = { [number]: UniverseTokens }

--[=[
	@class CreationTokens

	`AvatarCreationService` publish tokens, keyed by universe id. A universe with no entry cannot
	publish — [AvatarPublisher] resolves `nil` and the buy button falls back to "Publish".

	These are the tokens shipped with Roblox's template, kept so its own universes keep working.
	**This place needs its own entry added before publishing will succeed** — mint the tokens in
	the Creator Dashboard and add a row keyed by this universe's id.
]=]
local tokens: CreationTokens = {
	[6812969780] = {
		body = "6703e42c-6c3f-42fb-8b35-206c345c9a9f",
		accessories = {
			[Enum.AvatarAssetType.TShirtAccessory] = "80a08bd7-1ec1-46e5-a4d4-fd41ea284f91",
			[Enum.AvatarAssetType.Hat] = "5b074565-de68-4618-a6bc-b1bb3b58f3b9",
		},
	},

	[5113694998] = {
		body = "fd0639ed-595e-42a9-bdd4-8944840c8f52",
		accessories = {},
	},

	[8668915667] = {
		body = "fa957a59-1ae2-4cec-b07d-ab63e71d6662",
		accessories = {
			[Enum.AvatarAssetType.TShirtAccessory] = "b581e120-b70e-4a18-8144-5232d9c25cb0",
			[Enum.AvatarAssetType.Hat] = "c78292a2-3355-49af-a6de-9c1c1dc27d0d",
		},
	},
}

table.freeze(tokens)

return tokens
