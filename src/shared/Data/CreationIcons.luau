export type CreationIcons = {
	icons: { [string]: string },
	editorIcons: { [string]: string },
	widgetIcons: { [string]: string },
	regionIcons: { [string]: string },
	uiImages: { [string]: string },
	scrollBar: { [string]: string },
}

--[=[
	@class CreationIcons

	Image ids for the creation editor UI. The inner keys are lookup keys, not labels — `editorIcons`
	and the model entries of `regionIcons` are indexed by model name, `widgetIcons` by widget control
	group name, and the rest of `regionIcons` by region name, so renaming a key breaks the lookup.
]=]
local creationIcons: CreationIcons = {
	icons = {
		AvatarPreview = "rbxassetid://101017308725269",
		ExitEditor = "rbxassetid://127961031559745",
		ResetChanges = "rbxassetid://78889107986995",
		XButton = "rbxassetid://71171759549271",
		Delete = "rbxassetid://126203593172385",
		Scale = "rbxassetid://96436562942369",
		Rotate = "rbxassetid://114067372218201",

		Paintbrush = "rbxassetid://105441125994290",
		Eraser = "rbxassetid://78016323272575",
		Recolor = "rbxassetid://133908426980046",
		Decal = "rbxassetid://110475569250921",
		Pattern = "rbxassetid://107153084986708",
		Kitbashing = "rbxassetid://135744896670779",

		PaintbrushMuted = "rbxassetid://114632118377883",
		EraserMuted = "rbxassetid://110165308214781",
		DecalMuted = "rbxassetid://81559320299149",
		PatternMuted = "rbxassetid://72120360636986",
	},

	editorIcons = {
		RobotModel = "rbxassetid://110650241685215",
		TShirtModel = "rbxassetid://90986523398908",
		HatModel = "rbxassetid://116611995772177",
	},

	widgetIcons = {
		Head = "rbxassetid://123921714663008",
		Body = "rbxassetid://112231836235511",
		Shirt = "rbxassetid://112967115722385",

		HeadMuted = "rbxassetid://99155152631918",
		BodyMuted = "rbxassetid://116758126178214",
	},

	regionIcons = {
		RobotModel = "rbxassetid://71345610249564",
		TShirtModel = "rbxassetid://100393568259271",
		HatModel = "rbxassetid://100093471646213",

		Hair = "rbxassetid://93283252230357",
		Head = "rbxassetid://113048719521718",
		LeftArm = "rbxassetid://76154702937073",
		RightArm = "rbxassetid://85624010745922",
		Torso = "rbxassetid://125885421025912",
		LeftLeg = "rbxassetid://89780999293176",
		RightLeg = "rbxassetid://71728202659306",

		Brim = "rbxassetid://99409227712971",
		Band = "rbxassetid://104438137440192",
		Crown = "rbxassetid://110312846318583",
	},

	uiImages = {
		ToggleOff = "rbxassetid://96061243919515",
		ToggleOn = "rbxassetid://129923601024951",
		OpacityPicker = "rbxassetid://79024368709423",
		WidgetHandle = "rbxassetid://14841616292",
	},

	scrollBar = {
		Top = "rbxassetid://76984408878669",
		Middle = "rbxassetid://90051606532809",
		Bottom = "rbxassetid://79403364428324",
	},
}

table.freeze(creationIcons)

return creationIcons
