local MarketplaceService = game:GetService("MarketplaceService")

local Promise = require("../Promise")

--[=[
	@class ProductInfoUtil

	Throttled, cached wrapper over [MarketplaceService:GetProductInfo]. Every lookup is funneled
	through one shared queue that fires at most one request every `STAGGER_SECONDS`, so opening a
	catalog full of cards never bursts Roblox's marketplace rate limit. Results are cached for the
	session and duplicate in-flight requests coalesce onto one fetch; a rejected fetch is dropped
	from the cache so a later call retries instead of caching the failure.
]=]

export type ProductInfo = {
	Name: string,
	Description: string,
	PriceInRobux: number?,
	IconImageAssetId: number?,
	ProductId: number?,
	[string]: any,
}

-- GetProductInfo is rate-limited; spacing successive calls keeps a whole shop's worth of lookups
-- under the cap when the panel opens.
local STAGGER_SECONDS = 0.1

local cache: { [string]: Promise.Promise<ProductInfo> } = {}
local queue: { () -> () } = {}
local draining = false

local function drain()
	if draining then
		return
	end
	draining = true

	task.spawn(function()
		while #queue > 0 do
			local job = table.remove(queue, 1) :: () -> ()
			job()
			task.wait(STAGGER_SECONDS)
		end
		draining = false
	end)
end

--[=[
	@within ProductInfoUtil
	@param id number -- the gamepass or developer-product asset id
	@param infoType Enum.InfoType -- `GamePass` or `Product`, matching `id`
	@return Promise<ProductInfo> -- resolves with the Roblox product info, rejects if the fetch fails
]=]
local function get(id: number, infoType: Enum.InfoType): Promise.Promise<ProductInfo>
	local key = `{infoType.Name}:{id}`
	local cached = cache[key]
	if cached then
		return cached
	end

	local promise = Promise.new(function(resolve, reject)
		table.insert(queue, function()
			local ok, result = pcall(function()
				return MarketplaceService:GetProductInfoAsync(id, infoType)
			end)
			if ok then
				resolve(result)
			else
				reject(result)
			end
		end)
		drain()
	end)

	promise:catch(function()
		cache[key] = nil
	end)

	cache[key] = promise
	return promise
end

return {
	get = get,
}
