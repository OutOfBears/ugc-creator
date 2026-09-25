export type SpatialGrid<T, D> = {
	insert: (self: SpatialGrid<T, D>, key: T, pos: Vector3, data: D) -> (),
	remove: (self: SpatialGrid<T, D>, key: T) -> (),
	clear: (self: SpatialGrid<T, D>) -> (),
	nearest: (self: SpatialGrid<T, D>, pos: Vector3, radius: number?) -> (D, number?),
	forEachWithin: (
		self: SpatialGrid<T, D>,
		pos: Vector3,
		radius: number,
		callback: (data: D, neighborPos: Vector3, distSq: number) -> ()
	) -> (),
	within: (self: SpatialGrid<T, D>, pos: Vector3, radius: number) -> () -> (T, D),
	countWithin: (self: SpatialGrid<T, D>, pos: Vector3, radius: number, limit: number) -> number,
}

local function SpatialGrid<T, D>(cellSize: number): SpatialGrid<T, D>
	local cells: { [number]: { [number]: { { key: T, pos: Vector3 } } } } = {}
	local entries: { [T]: { pos: Vector3, data: D, cx: number, cz: number } } = {}

	local object = {} :: SpatialGrid<T, D>

	local function cellOf(pos: Vector3): (number, number)
		return math.floor(pos.X / cellSize), math.floor(pos.Z / cellSize)
	end

	function object:insert(key: T, pos: Vector3, data: D)
		if entries[key] then
			self:remove(key)
		end

		local cx, cz = cellOf(pos)
		if not cells[cx] then
			cells[cx] = {}
		end

		if not cells[cx][cz] then
			cells[cx][cz] = {}
		end

		table.insert(cells[cx][cz], { key = key, pos = pos })
		entries[key] = { pos = pos, data = data, cx = cx, cz = cz }
	end

	function object:remove(key: T)
		local e = entries[key]
		if not e then
			return
		end

		local col = cells[e.cx]
		local cell = col and col[e.cz]

		if cell then
			for i, item in cell do
				if item.key == key then
					table.remove(cell, i)
					break
				end
			end
		end

		entries[key] = nil
	end

	-- Resets all cells in-place — avoids allocating a new SpatialGrid object each frame.
	function object:clear()
		table.clear(entries)
		table.clear(cells)
	end

	-- Returns (data, distance) for the nearest entry.
	-- If radius is provided, only searches within that radius.
	-- If radius is omitted, iterates all entries for the globally nearest result.
	function object:nearest(pos: Vector3, radius: number?): (D, number?)
		local bestDist = math.huge
		local bestData = nil

		if radius then
			local cx, cz = cellOf(pos)
			local span = math.ceil(radius / cellSize) + 1

			for dx = -span, span do
				local col = cells[cx + dx]
				if not col then
					continue
				end

				for dz = -span, span do
					local cell = col[cz + dz]
					if not cell then
						continue
					end

					for _, item in cell do
						local d = (item.pos - pos).Magnitude
						if d < bestDist and d <= radius then
							bestDist = d
							bestData = entries[item.key] and entries[item.key].data
						end
					end
				end
			end
		else
			for _, e in entries do
				local d = (e.pos - pos).Magnitude
				if d < bestDist then
					bestDist = d
					bestData = e.data
				end
			end
		end

		return bestData, if bestData then bestDist else nil
	end

	-- Calls `callback(data, pos, distSq)` for every entry within `radius` of `pos`.
	function object:forEachWithin(pos, radius, callback)
		local cx, cz = cellOf(pos)
		local span = math.ceil(radius / cellSize) + 1
		local r2 = radius * radius

		for dx = -span, span do
			local col = cells[cx + dx]
			if not col then
				continue
			end

			for dz = -span, span do
				local cell = col[cz + dz]
				if not cell then
					continue
				end

				for _, item in cell do
					local diff = item.pos - pos
					local d2 = diff.X * diff.X + diff.Y * diff.Y + diff.Z * diff.Z
					if d2 <= r2 then
						local e = entries[item.key]
						if e then
							callback(e.data, item.pos, d2)
						end
					end
				end
			end
		end
	end

	-- Returns a `(key, data)` iterator over entries within `radius` of `pos`, for a generic
	-- `for` loop. Unlike `forEachWithin`, the caller can `break` to stop early.
	function object:within(pos, radius)
		local cx, cz = cellOf(pos)
		local span = math.ceil(radius / cellSize) + 1
		local r2 = radius * radius

		return coroutine.wrap(function()
			for dx = -span, span do
				local col = cells[cx + dx]
				if not col then
					continue
				end

				for dz = -span, span do
					local cell = col[cz + dz]
					if not cell then
						continue
					end

					for _, item in cell do
						local diff = item.pos - pos
						local d2 = diff.X * diff.X + diff.Y * diff.Y + diff.Z * diff.Z
						if d2 <= r2 then
							local e = entries[item.key]
							if e then
								coroutine.yield(item.key, e.data)
							end
						end
					end
				end
			end
		end)
	end

	-- Counts entries within `radius` of `pos`, stopping early once `limit` is reached.
	function object:countWithin(pos, radius, limit)
		local cx, cz = cellOf(pos)
		local span = math.ceil(radius / cellSize) + 1
		local r2 = radius * radius
		local count = 0

		for dx = -span, span do
			local col = cells[cx + dx]
			if not col then
				continue
			end

			for dz = -span, span do
				local cell = col[cz + dz]
				if not cell then
					continue
				end

				for _, item in cell do
					local diff = item.pos - pos
					local d2 = diff.X * diff.X + diff.Y * diff.Y + diff.Z * diff.Z
					if d2 <= r2 then
						count += 1
						if count >= limit then
							return count
						end
					end
				end
			end
		end

		return count
	end

	return object
end

return SpatialGrid
