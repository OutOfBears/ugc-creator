local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local Sift = require(ReplicatedStorage.Packages.Sift)
local Promise = require(ReplicatedStorage.Shared.Modules.Promise)

local CharmUtil = {}

Charm.flags.frozen = false
Charm.flags.strict = false

function CharmUtil.set<K, V>(map: { [K]: V }, key: K, value: V)
	if map[key] == value then
		return map
	end

	local newMap = table.clone(map)
	newMap[key] = value

	return newMap
end

function CharmUtil.deleteKey<K>(map: { [K]: any }, key: K)
	return CharmUtil.set(map, key, nil)
end

function CharmUtil.merge<K, V>(map: { [K]: V }, delta: { [K]: V })
	if next(delta) == nil then
		return map
	end

	local newMap

	for key, value in delta do
		if map[key] == value then
			continue
		end

		if not newMap then
			newMap = table.clone(map)
		end

		newMap[key] = value
	end

	return newMap or map
end

function CharmUtil.mergeDeep<T, U>(target: T, source: U): T & U
	local newTarget = table.clone(target :: any)
	for key, value in source :: any do
		if type(value) == "table" and type(newTarget[key]) == "table" then
			newTarget[key] = CharmUtil.mergeDeep(newTarget[key], value)
		else
			newTarget[key] = value
		end
	end
	return newTarget :: any
end

function CharmUtil.filterArray<T>(array: { T }, predicate: (T, number, { T }) -> boolean)
	local newArray = Sift.Array.filter(array, predicate)
	return if #array ~= #newArray then newArray else array
end

function CharmUtil.clear(table: {})
	return if next(table) == nil then table else {}
end

function CharmUtil.clone(newTbl: {})
	return if next(newTbl) ~= nil then table.clone(newTbl) else newTbl
end

function CharmUtil.change<K, V>(map: { [K]: V }, key: K, update: (V) -> V)
	local value = map[key]
	return if value == nil then map else CharmUtil.set(map, key, update(value))
end

function CharmUtil.map<K, V>(map: { [K]: V }, callback: (V, K) -> V?)
	local newMap

	for key, value in map do
		local newValue = callback(value, key)
		if newValue == value then
			continue
		end

		if not newMap then
			newMap = table.clone(map)
		end

		newMap[key] = newValue :: V
	end

	return newMap or map
end

function CharmUtil.mapArray<T>(array: { T }, callback: (T, number, { T }) -> T?)
	local newArray = {}
	local updated = false

	for index, value in array do
		local newValue = callback(value, index, array)
		if newValue ~= value then
			updated = true
		end

		if newValue ~= nil then
			table.insert(newArray, newValue)
		end
	end

	return if updated then newArray else array
end

function CharmUtil.assign<K, V>(map: { [K]: V }, keyUpdates: { [K]: V | ({ [K]: V }) -> V })
	local delta = {}

	for key, update in keyUpdates do
		delta[key] = if type(update) == "function" then update(map) else update
	end

	return CharmUtil.merge(map, delta)
end

function CharmUtil.watch<T, U...>(callback: () -> T, listener: (T, U...) -> ())
	return Charm.listen(callback, listener)
end

function CharmUtil.promise(condition: () -> boolean)
	if Charm.peek(condition) then
		return Promise.resolve()
	end

	return Promise.new(function(resolve)
		local unsubscribe

		unsubscribe = Charm.subscribe(condition, function(status)
			if status then
				resolve()
				unsubscribe()
			end
		end)

		return unsubscribe
	end)
end

function CharmUtil.insert(array: { any }, value: any, index: number?)
	if table.find(array, value) then
		return array
	end

	local newArray = table.clone(array)

	if index then
		table.insert(newArray, index, value)
	else
		table.insert(newArray, value)
	end

	return newArray
end

function CharmUtil.remove(array: { any }, value: any)
	local cloned = nil
	local index
	repeat
		index = table.find(cloned or array, value)
		if index then
			if not cloned then
				cloned = table.clone(array)
			end

			table.remove(cloned, index)
		end
	until not index
	return cloned or array
end

return CharmUtil
