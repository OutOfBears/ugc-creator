local TweenService = game:GetService("TweenService")

local function Tween(instance: Instance, tweenInfo: TweenInfo, propertyTable: { [string]: any })
	local tween = TweenService:Create(instance, tweenInfo, propertyTable)

	tween:Play()
	tween.Completed:Once(function()
		tween:Destroy()
	end)

	return tween
end

return Tween
