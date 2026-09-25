-- TagSchema for the template project.
--
-- Each top-level key is a CollectionService tag that one or more behaviors
-- (server + client) register against via the shared Behavior factory. The
-- `attributes` list mirrors the merged `state` config of those behaviors
-- (replicated through AttributeReplicator) plus any raw `instance:GetAttribute`
-- values the behavior reads directly off the instance.
--
-- Defaults match what the behavior code falls back to when the attribute is
-- absent. Anything set purely at runtime by code (e.g. generated ids, server
-- stats blobs) is intentionally omitted.

return {
	Character = {
		description = "A character model (player or NPC). Auto-applied alongside Entity.",
	},

	Player = {
		description = "Marks a Player instance for player-scoped systems.",
	},

	Hidden = {
		description = "Marks an instance that should be hidden from the local client.",
	},

	Replicator = {
		description = "Auto-applied by AttributeReplicator to any instance backed by replicated state.",
	},

	TycoonPlot = {
		description = "An empty plot Part in the claim pool; ServerTycoonPlot attaches and owns its economy.",
	},

	TycoonButton = {
		description = "A purchasable button. Author Cost + a Requires Instance attr (its prerequisite button); NodeId is generated.",
	},

	TycoonSeller = {
		description = "The sell stand. Attribute: SellBase; click grants SellBase × the plot's sell multiplier.",
	},

	CreationKiosk = {
		description = "A world kiosk that opens the item creation editor. Author a BlankName attribute naming the blank it starts (RobotModel, TShirtModel or HatModel); the model must contain a ClickDetector.",
	},
}
