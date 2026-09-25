local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local StyleRules = require("./StyleRules")
local StyleThemes = require("./StyleThemes")
local StyleUtils = require("./StyleUtils")

export type Style = {
	-- vars
	coreSheet: StyleSheet,
	phoneTheme: StyleSheet,
	desktopTheme: StyleSheet,
	themeDerive: StyleDerive,
	maid: Maid.Maid,
	-- methods
	linkGui: (self: Style, screenGui: ScreenGui) -> (),
	updateTheme: (self: Style, screenGui: ScreenGui) -> (),
	addRule: (self: Style, selector: string, properties: { [string]: any }, priority: number?) -> (),
	generateRules: (self: Style) -> (),
	destroy: (self: Style) -> (),
}

local function createTheme(name: string, tokens: { [string]: any }): StyleSheet
	return Create("StyleSheet", {
		Name = name,
		Attributes = tokens,
		Parent = ReplicatedStorage,
	}) :: StyleSheet
end

--[=[
	@class StyleSheet
	@client

	The style manager. Owns the `StyleSheet` instance that drives every visual property in the
	creation UI, the mobile and desktop theme sheets it derives tokens from, and the rules compiled
	out of [StyleRules].

	@return Style -- a style manager with its rules already generated
]=]
local function StyleSheet(): Style
	local maid = Maid.new()
	local object = {} :: Style

	object.maid = maid

	object.coreSheet = maid:add(Create("StyleSheet", {
		Name = "AvatarCreationStyleSheet",
		Parent = ReplicatedStorage,
	}) :: StyleSheet)

	object.phoneTheme = maid:add(createTheme("MobileTheme", StyleThemes.mobileThemeTokens))
	object.desktopTheme = maid:add(createTheme("DesktopTheme", StyleThemes.desktopThemeTokens))

	object.themeDerive = Create("StyleDerive", {
		StyleSheet = object.phoneTheme,
		Parent = object.coreSheet,
	}) :: StyleDerive

	--[=[
		@within StyleSheet
		@param screenGui ScreenGui -- the gui whose descendants should be styled
	]=]
	function object:linkGui(screenGui: ScreenGui)
		maid:add(Create("StyleLink", {
			StyleSheet = self.coreSheet,
			Parent = screenGui,
		}))

		maid:giveTask(screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:updateTheme(screenGui)
		end))

		self:updateTheme(screenGui)
	end

	--[=[
		@within StyleSheet
		@param screenGui ScreenGui -- the gui to size the theme choice against
	]=]
	function object:updateTheme(screenGui: ScreenGui)
		if StyleUtils.getIsMobile(screenGui) then
			self.themeDerive.StyleSheet = self.phoneTheme
		else
			self.themeDerive.StyleSheet = self.desktopTheme
		end
	end

	--[=[
		@within StyleSheet
		@param selector string -- a CSS-like selector, e.g. `.Panel::UIPadding`
		@param properties { [string]: any } -- the properties to apply to matching instances
		@param priority number? -- rule priority, defaults to 0
	]=]
	function object:addRule(selector: string, properties: { [string]: any }, priority: number?)
		local rule = Create("StyleRule", {
			Name = selector,
			Selector = selector,
			Priority = if priority then priority else 0,
			Parent = self.coreSheet,
		}) :: StyleRule

		rule:SetProperties(properties)
	end

	--[=[
		@within StyleSheet

		Compiles every rule set in [StyleRules] onto the core sheet. Called once during construction.
	]=]
	function object:generateRules()
		for selector, props in StyleRules.lowPriorityRules do
			self:addRule(selector, props, 0)
		end

		for selector, props in StyleRules.standardRules do
			self:addRule(selector, props, 50)
		end

		for selector, props in StyleRules.highPriorityRules do
			self:addRule(selector, props, 100)
		end
	end

	function object:destroy()
		maid:doCleaning()
	end

	object:generateRules()

	return object
end

return StyleSheet
