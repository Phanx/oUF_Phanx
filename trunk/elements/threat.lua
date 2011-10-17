--[[--------------------------------------------------------------------
	oUF_ThreatHighlight
	Highlights oUF frames by threat level.
	Highlights oUF frames by threat level.

	You may embed this module in your own layout, but please do not
	distribute it as a standalone module.

	Simple usage:
		frame.ThreatHighlight = frame.Health:CreateTexture( nil, "OVERLAY" )
		frame.ThreatHighlight:SetAllPoints( frame.Health:GetStatusBarTexture() )

	Advanced usage:
		frame.ThreatHighlight = function( self, unit, status )
----------------------------------------------------------------------]]

local _, ns = ...
local oUF = ns.oUF or oUF
if not oUF then return end

local function Update( self, event, unit )
	if self.unit ~= unit then return end

	local status = UnitThreatSituation( unit )
	-- print( "ThreatHighlight Update", event, unit, status )

	local element = self.ThreatHighlight
	if element.Override then
		element.Override( self, unit, status )
	elseif status and status > 0 then
		if element.SetVertexColor then
			element:SetVertexColor( GetThreatStatusColor( status ) )
		end
		element:Show()
	else
		element:Hide()
	end
end

local ForceUpdate = function( element )
	return Update( element.__owner, "ForceUpdate", element.__owner.unit )
end

local function Enable( self )
	local element = self.ThreatHighlight
	if not element then return end

	if type( element ) == "table" then
		if not element.Override and not element.Show then return end
	elseif type( element ) == "function" then
		self.ThreatHighlight = {
			Override = element
		}
		element = self.ThreatHighlight
	else
		return
	end

	element.__owner = self
	element.ForceUpdate = ForceUpdate

	self:RegisterEvent( "UNIT_THREAT_SITUATION_UPDATE", Update )

	if element.GetTexture and not element:GetTexture() then
		element:SetTexture( [[Interface\QuestFrame\UI-QuestTitleHighlight]] )
	end

	return true
end

local function Disable( self )
	local element = self.ThreatHighlight
	if not element then return end

	self:UnregisterEvent( "UNIT_THREAT_SITUATION_UPDATE", Update )

	if element.Override then
		element.Override( self, self.unit, 0 )
	else
		element:Hide()
	end
end

oUF:AddElement( "ThreatHighlight", Update, Enable, Disable )