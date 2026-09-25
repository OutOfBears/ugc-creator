local BezierBrush = require("./Brushes/BezierBrush")
local LinearBrush = require("./Brushes/LinearBrush")
local ProjectionBrush = require("./Brushes/ProjectionBrush")

export type DrawInfo = {
	textureDrawPosition: Vector2,
	cameraCFrame: CFrame,
	castedPoint: Vector3,
	isVirtualCursorMovement: boolean,
	alwaysConnect: boolean?,
}

--[=[
	@class Brushes

	The paint brushes, plus the [Brushes.DrawInfo] sample the paint tool feeds them. Each brush is
	a constructor: `Brushes.LinearBrush(targetEditableImage, textureInfo)`.

	They share one surface — `setColor`, `setSize`, `setTransparency`, `setCurrentMeshPart`,
	`setColorBlendType`, `setAlphaBlendType`, `setAllMeshPart`, `setCommitBrushStrokeCallback`,
	`getRequireLocalExecute`, `penDown`, `movePen`, `penUp`, `destroy` — so the tool can swap one
	for another. A brush reports through `getRequireLocalExecute` whether its committed action
	also has to be replayed locally.
]=]
return {
	BezierBrush = BezierBrush,
	LinearBrush = LinearBrush,
	ProjectionBrush = ProjectionBrush,
}
