local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StyleLayouts = require(ReplicatedStorage.Shared.Data.StyleLayouts)

export type StyleThemes = {
	themeTokens: { [string]: string },
	mobileThemeTokens: { [string]: any },
	desktopThemeTokens: { [string]: any },
}

local THEME_TOKENS = {}
for tokenName in StyleLayouts.mobile do
	THEME_TOKENS[tokenName] = tokenName
end

--[=[
	@class StyleThemes
	@client

	The mobile and desktop token sets [StyleSheet] swaps between as the screen resizes, sourced from
	[StyleLayouts] so the React UI reads the same values. The tokens become attributes on a
	`StyleSheet` instance, and a missing one leaves the rule referencing `${Token}` unresolved.
]=]
local StyleThemes: StyleThemes = {
	themeTokens = THEME_TOKENS,
	mobileThemeTokens = StyleLayouts.mobile,
	desktopThemeTokens = StyleLayouts.desktop,
}

return StyleThemes
