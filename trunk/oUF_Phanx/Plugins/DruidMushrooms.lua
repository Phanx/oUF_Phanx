--[[--------------------------------------------------------------------
	oUF_DruidMushrooms
	by Phanx <addons@phanx.net>
	Adds basic support for druid mushrooms. Use it like ClassIcons.

	You may embed this module in your own layout,
	but please do not distribute it as a standalone plugin.
----------------------------------------------------------------------]]

local MAX_MUSHROOMS = 3

local UpdateVisibility, Update, Path, ForceUpdate, Enable, Disable

function UpdateVisibility(self, event)
	local element = self.DruidMushrooms

	local spec = GetSpecialization()
	if spec == 2 or spec == 3 or UnitHasVehicleUI("player") then
		self:UnregisterEvent("PLAYER_TOTEM_UPDATE", Path)
		for i = 1, MAX_MUSHROOMS do
			element[i]:Hide()
		end
		return
	end

	self:RegisterEvent("PLAYER_TOTEM_UPDATE", Path)
	Update(self, event)
end

function Update(self, event)
	local element = self.DruidMushrooms
	for i = 1, MAX_MUSHROOMS do
		local exists, name, start, duration, icon = GetTotemInfo(i)
		if duration > 0 then
			element[i]:Show()
		else
			element[i]:Hide()
		end
	end
end

function Path(self, ...)
	return (self.DruidMushrooms.Override or Update)(self, ...)
end

function ForceUpdate(element)
	return Path(element.__owner, "ForceUpdate")
end

function Enable(self)
	local element = self.DruidMushrooms
	if not element then return end

	element.__owner = self
	element.ForceUpdate = ForceUpdate

	self:RegisterEvent("PLAYER_TALENT_UPDATE", UpdateVisibility)
	self:RegisterEvent("UNIT_ENTERING_VEHICLE", UpdateVisibility)
	self:RegisterEvent("UNIT_EXITED_VEHICLE", UpdateVisibility)

	for i = 1, #element do
		element[i]:Hide()
	end

	UpdateVisibility(self, "Enable")

	TotemFrame.Show = TotemFrame.Hide
	TotemFrame:Hide()

	TotemFrame:UnregisterEvent("PLAYER_TOTEM_UPDATE")
	TotemFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
	TotemFrame:UnregisterEvent("UPDATE_SHAPESHIFT_FORM")
	TotemFrame:UnregisterEvent("PLAYER_TALENT_UPDATE")

	return true
end

function Disable(self)
	local element = self.DruidMushrooms
	if not element then return end

	self:UnregisterEvent("PLAYER_TOTEM_UPDATE", Update)
	self:UnregisterEvent("PLAYER_TALENT_UPDATE", UpdateVisibility)
	self:UnregisterEvent("UNIT_ENTERING_VEHICLE", UpdateVisibility)
	self:UnregisterEvent("UNIT_EXITED_VEHICLE", UpdateVisibility)

	for i = 1, #element do
		element[i]:Hide()
	end

	TotemFrame.Show = nil
	TotemFrame:Show()

	TotemFrame:RegisterEvent("PLAYER_TOTEM_UPDATE")
	TotemFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	TotemFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
	TotemFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
end

oUF:AddElement("DruidMushrooms", Path, Enable, Disable)