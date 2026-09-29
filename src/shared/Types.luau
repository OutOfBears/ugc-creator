export type LoaderEvent = "RenderStepped" | "Stepped" | "Heartbeat"
export type LoaderModule = {
	name: string,
	priority: number?,
	loadTime: number?,
	onInit: (() -> ())?,
	onRun: (() -> ())?,
	onStepped: ((time: number, deltaTime: number) -> ())?,
	onRenderStepped: ((deltaTime: number) -> ())?,
	onHeartbeat: ((deltaTime: number) -> ())?,
	onPreSimulation: ((deltaTime: number) -> ())?,
	onPostSimulation: ((deltaTime: number) -> ())?,
}

export type Controller = LoaderModule
export type Service = LoaderModule

export type DebugTool = {
	onInit: (() -> ())?,
	onCreateWindow: (() -> ())?,
	canRun: (() -> boolean)?,
}

export type EditHandleState = {
	visible: boolean,
	offset: Vector2,
	scale: number,
	rotation: number,
}

export type GroupRoles = {
	IsMember: string,
	Roles: { [number]: { Id: string, Name: string, Rank: number } },
}

return nil
