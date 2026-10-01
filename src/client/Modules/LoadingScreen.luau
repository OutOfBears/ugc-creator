local ClientAtoms = require("./ClientAtoms")

--[=[
	@class LoadingScreen
	@client

	Full-screen cover shown while a blank's meshes and textures load, rendered by the
	`LoadingScreen` view from `ClientAtoms.loadingVisible`.
]=]
local LoadingScreen = {}

--[=[
	@within LoadingScreen
	@param visible boolean -- whether to cover the screen
]=]
function LoadingScreen.setVisible(visible: boolean)
	ClientAtoms.loadingVisible(visible)
end

return LoadingScreen
