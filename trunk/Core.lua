--[[--------------------------------------------------------------------
	oUF_Phanx
	A layout for oUF.
	by Phanx < addons@phanx.net >
	http://www.wowinterface.com/downloads/info13993-oUF_Phanx.html
	Copyright ©2009–2010 Alyssa "Phanx" Kinley. All rights reserved.
	See README for license terms and additional information.
----------------------------------------------------------------------]]

local settings = {
	font           = "Expressway",
	outline        = "OUTLINE", -- NONE, OUTLINE, THICKOUTLINE

	statusbar      = "Gradient",

	borderStyle    = "TEXTURE", -- GLOW, NONE, TEXTURE
	borderColor    = { 0.5, 0.5, 0.5 }, -- only applies to TEXTURE border
	borderSize     = 14, -- only applies to TEXTURE border

	focusPlacement = "LEFT", -- LEFT, RIGHT

	threatLevels   =  true,
}

------------------------------------------------------------------------

local defaultFonts = {
	["Expressway"] = [[Interface\AddOns\oUF_Phanx\media\Expressway.ttf]],
	["Arial Narrow"] = [[Fonts\ARIALN.TTF]],
	["Friz Quadrata TT"] = [[Fonts\FRIZQT__.TTF]],
	["Morpheus"] = [[Fonts\MORPHEUS.ttf]],
	["Skurri"] = [[Fonts\skurri.ttf]],
}

local defaultStatusbars = {
	["Gradient"] = [[Interface\AddOns\oUF_Phanx\media\gradient]],
	["Blizzard"] = [[Interface\TargetingFrame\UI-StatusBar]],
}

------------------------------------------------------------------------

local ADDON_NAME, namespace = ...
if not namespace.L then namespace.L = { } end

local L = setmetatable(namespace.L, { __index = function(t, k) t[k] = k return k end })
L["Dead"]    = DEAD
L["Ghost"]   = GetSpellInfo(8326)
L["Offline"] = PLAYER_OFFLINE

------------------------------------------------------------------------

local colors = oUF.colors

colors.dead = { 0.6, 0.6, 0.6 }
colors.ghost = { 0.6, 0.6, 0.6 }
colors.offline = { 0.6, 0.6, 0.6 }

colors.civilian = { 0.2, 0.4, 1 }
colors.friendly = { 0.2, 1, 0.2 }
colors.hostile = { 1, 0.1, 0.1 }
colors.neutral = { 1, 1, 0.2 }

colors.power.AMMOSLOT = { 0.8, 0.6, 0 }
colors.power.ENERGY = { 1, 1, 0.2 }
colors.power.FOCUS = { 1, 0.5, 0.25 }
colors.power.FUEL = { 0, 0.5, 0.5 }
colors.power.MANA = { 0, 0.8, 1 }
colors.power.RAGE = { 1, 0.2, 0.2 }
colors.power.RUNIC_POWER = { 0.4, 0.4, 1 }

colors.unknown = { 1, 0.2, 1 }

colors.threat = {
	{ 1, 1, 0.47 }, -- not tanking, high threat
	{ 1, 0.6, 0 },  -- tanking, insecure threat
	{ 1, 0, 0 },    -- tanking, secure threat
}

colors.debuff = { }
for type, color in pairs(DebuffTypeColor) do
	if type ~= "none" then
		colors.debuff[type] = { color.r, color.g, color.b }
	end
end

------------------------------------------------------------------------

local SharedMedia
local oUF_Phanx = CreateFrame("Frame")
local playerClass = select(2, UnitClass("player"))
local MAX_LEVEL = MAX_PLAYER_LEVEL_TABLE[GetAccountExpansionLevel()]

------------------------------------------------------------------------

local function debug(str, ...)
	if ... then
		if str:match("%%") then
			str = str:format(...)
		else
			str = string.join(", ", str, ...)
		end
	end
	print(("|cffffcc00[DEBUG] oUF_Phanx:|r %s"):format(str))
end

------------------------------------------------------------------------

local function si(n, plus)
	if type(n) ~= "number" then return n end

	local sign
	if n < 0 then
		sign = "-"
		n = -n
	elseif plus then
		sign = "+"
	else
		sign = ""
	end

	if n >= 10000000 then
		return ("%s%.1fm"):format(sign, n / 1000000)
	elseif n >= 1000000 then
		return ("%s%.2fm"):format(sign, n / 1000000)
	elseif n >= 100000 then
		return ("%s%.0fk"):format(sign, n / 1000)
	elseif n >= 10000 then
		return ("%s%.1fk"):format(sign, n / 1000)
	else
		return ("%s%d"):format(sign, n)
	end
end

------------------------------------------------------------------------

local function GetDifficultyColor(level)
	if level < 1 then
		level = 100
	end
	local levelDiff = level - UnitLevel("player")
	if levelDiff >= 5 then
		return 1.00, 0.10, 0.10
	elseif levelDiff >= 3 then
		return 1.00, 0.50, 0.25
	elseif levelDiff >= -2 then
		return 1.00, 1.00, 0.00
	elseif -levelDiff <= GetQuestGreenRange() then
		return 0.25, 0.75, 0.25
	end
	return 0.70, 0.70, 0.70
end

------------------------------------------------------------------------

local function GetUnitColor(unit)
	if UnitIsPlayer(unit) then
		local _, class = UnitClass(unit)
		return colors.class[class] or colors.unknown
	elseif UnitPlayerControlled(unit) then
		if UnitCanAttack(unit, "player") then
			-- they can attack me
			if UnitCanAttack("player", unit) then
				-- and I can attack them
				return colors.hostile
			else
				-- but I can't attack them
				return colors.civilian
			end
		elseif UnitCanAttack("player", unit) then
			-- they can't attack me, but I can attack them
			return colors.neutral
		elseif UnitIsPVP(unit) and not UnitIsPVPSanctuary(unit) and not UnitIsPVPSanctuary("player") then
			-- on my team
			return colors.friendly
		else
			-- either enemy or friend, no violence
			return colors.civilian
		end
	elseif UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) then
		return colors.tapped
	else
		local reaction = UnitReaction(unit, "player")
		if reaction then
			if reaction >= 5 then
				return colors.friendly
			elseif reaction == 4 then
				return colors.neutral
			else
				return colors.hostile
			end
		else
			return colors.unknown
		end
	end
end

------------------------------------------------------------------------

local AddBorder

local function SetBorderColor(self, r, g, b)
	if not self or type(self) ~= "table" then return end
	if not self.borderTextures then
		AddBorder(self)
	end
	if not r then
		r, g, b = unpack(settings.borderColor)
	end
	-- debug("SetBorderColor: %s, %s, %s", r, g, b)

	for i, tex in ipairs(self.borderTextures) do
		tex:SetVertexColor(r, g, b)
	end
end

local function SetBorderSize(self, size)
	if not self or type(self) ~= "table" then return end
	if not self.borderTextures then
		AddBorder(self, size)
	end
	if not size then
		size = settings.borderSize
	end
	-- debug("SetBorderSize: %s", size)

	local x = size / 2 - 6
	local t = self.borderTextures

	for i, tex in ipairs(t) do
		tex:SetWidth(size)
		tex:SetHeight(size)
	end

	t[1]:SetPoint("TOPLEFT", self, -4 - x, 4 + x)
	t[2]:SetPoint("TOPRIGHT", self, 4 + x, 4 + x)

	t[3]:SetPoint("TOPLEFT", t[1], "TOPRIGHT")
	t[3]:SetPoint("TOPRIGHT", t[2], "TOPLEFT")

	t[4]:SetPoint("BOTTOMLEFT", self, -4 - x, -4 - x)
	t[5]:SetPoint("BOTTOMRIGHT", self, 4 + x, -4 - x)

	t[6]:SetPoint("BOTTOMLEFT", t[4], "BOTTOMRIGHT")
	t[6]:SetPoint("BOTTOMRIGHT", t[5], "BOTTOMLEFT")

	t[7]:SetPoint("TOPLEFT", t[1], "BOTTOMLEFT")
	t[7]:SetPoint("BOTTOMLEFT", t[4], "TOPLEFT")

	t[8]:SetPoint("TOPRIGHT", t[2], "BOTTOMRIGHT")
	t[8]:SetPoint("BOTTOMRIGHT", t[5], "TOPRIGHT")
end

function AddBorder(frame, size)
	if not frame or type(frame) ~= "table" or frame.borderTextures then return end
	-- debug("AddBorder: %s", frame.unit or "")

	frame.borderTextures = { }

	local t = frame.borderTextures
	for i = 1, 8 do
		t[i] = frame:CreateTexture(nil, "BORDER")
		t[i]:SetTexture([[Interface\AddOns\oUF_Phanx\media\border]])
	end

	t[1].id = "TOPLEFT"
	t[1]:SetTexCoord(0, 1/3, 0, 1/3)

	t[2].id = "TOPRIGHT"
	t[2]:SetTexCoord(2/3, 1, 0, 1/3)

	t[3].id = "TOP"
	t[3]:SetTexCoord(1/3, 2/3, 0, 1/3)

	t[4].id = "BOTTOMLEFT"
	t[4]:SetTexCoord(0, 1/3, 2/3, 1)

	t[5].id = "BOTTOMRIGHT"
	t[5]:SetTexCoord(2/3, 1, 2/3, 1)

	t[6].id = "BOTTOM"
	t[6]:SetTexCoord(1/3, 2/3, 2/3, 1)

	t[7].id = "LEFT"
	t[7]:SetTexCoord(0, 1/3, 1/3, 2/3)

	t[8].id = "RIGHT"
	t[8]:SetTexCoord(2/3, 1, 1/3, 2/3)

	SetBorderColor(frame, unpack(settings.borderColor))
	SetBorderSize(frame, size)

	frame.SetBorderColor = SetBorderColor
	frame.SetBorderSize = SetBorderSize
end

------------------------------------------------------------------------

local IsTanking
if playerClass == "DEATHKNIGHT" then
	local FROST_PRESENCE = GetSpellInfo(48263)
	function IsTanking()
		local form = GetShapeshiftForm() or 0
		if form > 0 then
			local _, name = GetShapeshiftFormInfo(form)
			if name == FROST_PRESENCE then
				return true
			end
		end
	end
elseif playerClass == "DRUID" then
	local BEAR_FORM = GetSpellInfo(5487)
	local DIRE_BEAR_FORM = GetSpellInfo(9634)
	function IsTanking()
		local form = GetShapeshiftForm() or 0
		if form > 0 then
			local _, name = GetShapeshiftFormInfo(form)
			if name == DIRE_BEAR_FORM or name == BEAR_FORM then
				return true
			end
		end
	end
elseif playerClass == "PALADIN" then
	local RIGHTEOUS_FURY = GetSpellInfo(25780)
	function IsTanking()
		return UnitAura("player", RIGHTEOUS_FURY, "HELPFUL") and true
	end
elseif playerClass == "WARRIOR" then
	local DEFENSIVE_STANCE = GetSpellInfo(71)
	function IsTanking()
		local form = GetShapeshiftForm() or 0
		if form > 0 then
			local _, name = GetShapeshiftFormInfo(form)
			if name == DEFENSIVE_STANCE then
				return true
			end
		end
	end
else
	function IsTanking() end
end

local function UpdateBorder(self)
--	if not self.unit:match("target$") then
--		debug("UpdateBorder: %s, IsTanking: %s, threatStatus %d, debuffType %s, dispellable %s", self.unit, IsTanking() and "true" or "false", self.threatStatus or -1, self.debuffType or "none", self.dispellable and "true" or "false")
--	end

	local color, important

	if IsTanking() then
		if self.threatStatus and self.threatStatus > 0 then
			color = colors.threat[self.threatStatus]
			important = true
		elseif self.debuffType then
			color = colors.debuff[self.debuffType]
			important = self.debuffDispellable
		end
	else
		if self.debuffDispellable then
			color = colors.debuff[self.debuffType]
			important = true
		elseif self.threatStatus and self.threatStatus > 0 then
			color = colors.threat[self.threatStatus]
			important = true
		elseif self.debuffType then
			color = colors.debuff[self.debuffType]
			important = false
		end
	end

	if self.SetBorderColor then -- settings.borderStyle == "TEXTURE" then -- check for .SetBorderColor instead of setting, since setting might be changed
		local r, g, b = unpack(color or settings.borderColor)
		self:SetBorderColor(r, g, b, 1)
		self:SetBorderSize(settings.borderSize * (important and 1.25 or 1))
	else
		if important then
			local r, g, b = unpack(color)
			self:SetBackdropBorderColor(r, g, b, 1)
		elseif color then
			local r, g, b = unpack(color)
			self:SetBackdropBorderColor(r, g, b, 0.5)
		else
			self:SetBackdropBorderColor(0, 0, 0, 0)
		end
		if self.BorderGlow then -- settings.borderStyle == "GLOW" then -- check for .BorderGlow instead of setting, since setting might be changed
			if color then
				self.BorderGlow:SetPoint("TOPLEFT", -3, 3)
				self.BorderGlow:SetPoint("BOTTOMRIGHT", 3, -3)
			else
				self.BorderGlow:SetPoint("TOPLEFT", 0, 0)
				self.BorderGlow:SetPoint("BOTTOMRIGHT", 0, 0)
			end
		end
	end
end

------------------------------------------------------------------------

local function UpdateName(self, event, unit)
	if self.unit ~= unit then return end
	-- debug("UpdateName: %s, %s", event, unit)

	local r, g, b
	if UnitIsDead(unit) then
		r, g, b = unpack(colors.dead)
	elseif UnitIsGhost(unit) then
		r, g, b = unpack(colors.ghost)
	elseif not UnitIsConnected(unit) then
		r, g, b = unpack(colors.offline)
	elseif UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) then
		r, g, b = unpack(colors.tapped)
	else
		r, g, b = unpack(GetUnitColor(unit))
	end

	self.Name:SetText(UnitName(unit))
	self.Name:SetTextColor(r, g, b)

--	if self.Info then
--		UpdateInfo(self, event, unit)
--	end

--	UpdateBorder(self)
end

------------------------------------------------------------------------

local function UpdateHealth(self, event, unit, bar, min, max)
	if self.unit ~= unit then return end
	-- debug("UpdateHealth: %s, %s", event, unit)

	local r, g, b

	if not UnitIsConnected(unit) then
		r, g, b = unpack(colors.offline)
		bar:SetValue(self.reverse and 0 or max)
		bar.value:SetText("Offline")
		bar.value:SetTextColor(r, g, b)
	elseif UnitIsGhost(unit) then
		r, g, b = unpack(colors.ghost)
		bar:SetValue(self.reverse and 0 or max)
		bar.value:SetText("Ghost")
		bar.value:SetTextColor(r, g, b)
	elseif UnitIsDead(unit) then
		r, g, b = unpack(colors.dead)
		bar:SetValue(self.reverse and 0 or max)
		bar.value:SetText("Dead")
		bar.value:SetTextColor(r, g, b)
	else
		r, g, b = unpack(GetUnitColor(unit))
		bar:SetValue(self.reverse and max - min or min)
		if min < max then
			if unit == "player" or unit == "pet" then
				bar.value:SetFormattedText("-%s", si(max - min))
			elseif unit == "targettarget" or unit == "focustarget" then
				bar.value:SetFormattedText("%s%%", ceil(min / max * 100))
			elseif (UnitIsPlayer(unit) or UnitPlayerControlled(unit)) and UnitIsFriend(unit, "player") then
				bar.value:SetFormattedText("%s|cffff6666-%s|r", si(max), si(max - min))
			else
				bar.value:SetFormattedText("%s (%d%%)", si(min), ceil(min / max * 100))
			end
		elseif unit == "target" or unit == "focus" then
			bar.value:SetText(si(max))
		else
			bar.value:SetText()
		end
		bar.value:SetTextColor(r, g, b)
	end

	if self.reverse then
		bar:SetStatusBarColor(r, g, b)
		bar.bg:SetVertexColor(r * .2, g * .2, b * .2)
	else
		bar:SetStatusBarColor(r * .2, g * .2, b * .2)
		bar.bg:SetVertexColor(r, g, b)
	end

	if self.Name then
		self.Name:SetTextColor(r, g, b)
	end
end

------------------------------------------------------------------------

local UpdateDruidMana
do
	local time = 0
	local SPELL_POWER_MANA = SPELL_POWER_MANA
	function UpdateDruidMana(self, elapsed)
		time = time + (elapsed or 1000)
		if time > 0.5 then
			-- debug("UpdateDruidMana")
			local frame = self:GetParent()
			if frame.shapeshifted then
				local min, max = UnitPower("player", SPELL_POWER_MANA), UnitPowerMax("player", SPELL_POWER_MANA)
				if min < max then
					return frame.DruidMana:SetText(si(min))
				--	return frame.DruidMana:SetFormattedText("%d%%", floor(min / max * 100))
				end
			end
			frame.DruidMana:SetText()
			time = 0
		end
	end
end

------------------------------------------------------------------------

local function UpdatePower(self, event, unit, bar, min, max)
	if self.unit ~= unit then return end
	-- debug("UpdatePower: %s, %s", tostring(event), tostring(unit))

	if max == 0 then
		self.Health:SetPoint("TOP", self.Power, "TOP")
		bar:Hide()
		bar.hidden = true
		return
	elseif self.Power.hidden then
		self.Health:SetPoint("TOP", self.Power, "BOTTOM", 0, -1)
		bar:Show()
		bar.hidden = nil
	end

	if UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit) then
		bar:SetValue(0)
		bar:SetStatusBarColor(0, 0, 0)
		bar.bg:SetVertexColor(0, 0, 0)
		if bar.value then
			bar.value:SetText()
		end
		if bar.DruidMana then
			self.shapeshifted = false
			self.overlay:SetScript("OnUpdate", nil)
			UpdateDruidMana(self.overlay)
		end
		return
	end

	local r, g, b

	if unit == "pet" and playerClass == "HUNTER" and self.power then
		r, g, b = unpack(colors.happiness[GetPetHappiness()] or colors.power.FOCUS)
		if min < max and bar.value then
			bar.value:SetText(min)
		end
	else
		local _, type = UnitPowerType(unit)
		r, g, b = unpack(colors.power[type] or colors.unknown)
		if self.DruidMana then
			if type == "MANA" then
				if self.shapeshifted then
					self.shapeshifted = false
					self.overlay:SetScript("OnUpdate", nil)
					UpdateDruidMana(self.overlay)
				end
			else
				if not self.shapeshifted then
					self.shapeshifted = true
					self.overlay:SetScript("OnUpdate", UpdateDruidMana)
					UpdateDruidMana(self.overlay)
				end
			end
		end
		if bar.value then
			if unit == "player" or unit == "pet" then
				if type == "RAGE" or type == "RUNIC_POWER" then
					if min > 0 then
						bar.value:SetText(min)
					else
						bar.value:SetText()
					end
				else
					if min < max then
						bar.value:SetText(si(min))
					else
						bar.value:SetText()
					end
				end
			else
				if type == "MANA" then
					if min < max then
						if UnitHealth(unit) == UnitHealthMax(unit) then
							bar.value:SetFormattedText("%s|cff%02x%02x%02x.%s|r", si(min), r * 255, g * 255, b * 255, si(max))
						else
							bar.value:SetText(si(min))
						end
					else
						bar.value:SetText(si(max))
					end
				elseif type == "ENERGY" then
					if min < max then
						bar.value:SetText(min)
					else
						bar.value:SetText()
					end
				else -- FOCUS, RAGE, or RUNIC_POWER
					if min > 0 then
						bar.value:SetText(min)
					else
						bar.value:SetText()
					end
				end
			end
			bar.value:SetTextColor(r, g, b)
		end
	end

	if self.reverse then
		bar:SetValue(max - min)

		bar:SetStatusBarColor(r * .2, g * .2, b * .2)
		bar.bg:SetVertexColor(r, g, b)
	else
		bar:SetValue(min)

		bar:SetStatusBarColor(r, g, b)
		bar.bg:SetVertexColor(r * .2, g * .2, b * .2)
	end
end

------------------------------------------------------------------------

local function UpdateDispelHighlight(self, event, unit, debuffType, canDispel)
	if self.unit ~= unit then return end
	-- debug("UpdateDispelHighlight", unit, tostring(debuffType), tostring(canDispel))

	if self.debuffType == debuffType then return end -- no change

	self.debuffType = debuffType
	self.debuffDispellable = canDispel

	self:UpdateBorder()
end

------------------------------------------------------------------------

local function UpdateThreatHighlight(self, event, unit, status)
	if self.unit ~= unit then return end
	-- debug("UpdateThreatHighlight", unit, tostring(status))

	if not status then
		status = 0
	elseif status > 1 and not settings.threatLevel then
		status = 3
	end

	if self.threatStatus == status then return end -- no change

	self.threatStatus = status

	self:UpdateBorder()
end

------------------------------------------------------------------------

local usettings = {
	player = {
		width = 200,
		height = 24,
		func = function(self)
			self.Health.value:SetPoint("BOTTOMRIGHT", self, -3, 0)
			self.Health.value:SetJustifyH("RIGHT")

			self.Power.value:SetPoint("BOTTOMLEFT", self, 3, 1)
			self.Power.value:SetPoint("BOTTOMRIGHT", self.Health.value, "BOTTOMLEFT", -2, -1)
			self.Power.value:SetJustifyH("LEFT")
		end,
	},
	pet = {
		width = 200,
		height = 16,
	},
	target = {
		width = 200,
		height = 24,
		func = function(self)
			self.Health.value:SetPoint("BOTTOMLEFT", self, 3, 0)
			self.Health.value:SetJustifyH("LEFT")

			self.Power.value:SetPoint("BOTTOMRIGHT", self, -3, 1)
			self.Power.value:SetPoint("BOTTOMLEFT", self.Health.value, "BOTTOMRIGHT", 2, 1)
			self.Power.value:SetJustifyH("RIGHT")

			self.Name:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 3, settings.borderStyle == "TEXTURE" and -5 or -7)
			self.Name:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", -3, settings.borderStyle == "TEXTURE" and -5 or -7)
			self.Name:SetJustifyH("RIGHT")
		end,
	},
	targettarget = {
		width = 160,
		height = 16,
		func = function(self)
			self.Name:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 3, settings.borderStyle == "TEXTURE" and -5 or -7)
			self.Name:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", -3, settings.borderStyle == "TEXTURE" and -5 or -7)
			self.Name:SetJustifyH("RIGHT")

			self.Health.value:SetPoint("TOPLEFT", self, 2, 2)
		end,
	},
	focus = {
		width = 200,
		height = 24,
		func = function(self)
			if self.reverse then
				self.Health.value:SetPoint("BOTTOMLEFT", self, 3, 0)
				self.Health.value:SetJustifyH("LEFT")

				self.Power.value:SetPoint("BOTTOMRIGHT", self, -3, 1)
				self.Power.value:SetPoint("BOTTOMLEFT", self.Health.value, "BOTTOMRIGHT", 2, 1)
				self.Power.value:SetJustifyH("RIGHT")

				self.Name:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 3, settings.borderStyle == "TEXTURE" and -5 or -7)
				self.Name:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", -3, settings.borderStyle == "TEXTURE" and -5 or -7)
				self.Name:SetJustifyH("RIGHT")
			else
				self.Health.value:SetPoint("BOTTOMRIGHT", self, -3, 0)
				self.Health.value:SetJustifyH("RIGHT")

				self.Power.value:SetPoint("BOTTOMLEFT", self, 3, 1)
				self.Power.value:SetPoint("BOTTOMRIGHT", self.Health.value, "BOTTOMLEFT", -2, 1)
				self.Power.value:SetJustifyH("LEFT")

				self.Name:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 3, settings.borderStyle == "TEXTURE" and -5 or -7)
				self.Name:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", -3, settings.borderStyle == "TEXTURE" and -5 or -7)
				self.Name:SetJustifyH("LEFT")
			end
		end,
	},
	focustarget = {
		width = 160,
		height = 16,
		func = function(self)
			if self.reverse then
				self.Name:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 3, settings.borderStyle == "TEXTURE" and -5 or -7)
				self.Name:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", -3, settings.borderStyle == "TEXTURE" and -5 or -7)
				self.Name:SetJustifyH("RIGHT")

				self.Health.value:SetPoint("TOPLEFT", self, 3, 0)
			else
				self.Name:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 3, settings.borderStyle == "TEXTURE" and -5 or -7)
				self.Name:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", -3, settings.borderStyle == "TEXTURE" and -5 or -7)
				self.Name:SetJustifyH("LEFT")

				self.Health.value:SetPoint("TOPRIGHT", self, -3, 0)
			end
		end,
	},
	party = {
		width = 160,
		height = 24,
	},
	partypet = {
		width = 160,
		height = 16,
	},
}

------------------------------------------------------------------------

local backdrop = {
	bgFile = [[Interface\AddOns\oUF_Phanx\media\solid]], tile = true, tileSize = 16,
	edgeFile = [[Interface\AddOns\oUF_Phanx\media\solid]], edgeSize = 3,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local backdrop_glow = {
	edgeFile = [[Interface\AddOns\oUF_Phanx\media\glow]],
	edgeSize = 5,
	insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

local INSET = backdrop.insets.left + 1

local H_DIV = 5
	-- for units with a power bar, power bar height = (settings.height / H_DIV) and health bar becomes correspondingly smaller

------------------------------------------------------------------------

local fakeThreat
do
	local noop = function() return end
	fakeThreat = { Hide = noop, GetTexture = noop, IsObjectType = noop }
end

------------------------------------------------------------------------

local function menu(self)
	local unit = self.unit:sub(1, -2)
	if unit == "party" or unit == "partypet" then
		ToggleDropDownMenu(1, nil, _G["PartyMemberFrame"..self.id.."DropDown"], "cursor", 0, 0)
	else
		local cunit = self.unit:gsub("(.)", string.upper, 1)
		if _G[cunit.."FrameDropDown"] then
			ToggleDropDownMenu(1, nil, _G[cunit.."FrameDropDown"], "cursor", 0, 0)
		end
	end
end

------------------------------------------------------------------------

local function Spawn(self, unit)
	if not unit then
		local template = self:GetParent():GetAttribute("template")
		if template == "SecureUnitButtonTemplate" then
			unit = "party"
		else
			unit = "partypet"
		end
	end
	-- debug("Spawn", unit)

	self.menu = menu

	self:SetScript("OnEnter", UnitFrame_OnEnter)
	self:SetScript("OnLeave", UnitFrame_OnLeave)

	self:RegisterForClicks("anyup")
	self:SetAttribute("*type2", "menu")

	self.reverse = not (unit == "player" or unit == "pet" or (settings.focusPlacement == "LEFT" and unit:match("^focus")))

	local c = usettings[unit]
	local hasPower = unit == "player" or unit == "pet" or unit == "target" or unit == "focus" or unit == "party"

	local FONT = oUF_Phanx:GetFont(settings.font)
	local STATUSBAR = oUF_Phanx:GetStatusBarTexture(settings.statusbar)

	local width = INSET + c.width + INSET
	local height = INSET + c.height + INSET
	if hasPower then
		height = height + 1
	end

	self:SetAttribute("initial-width", width)
	self:SetAttribute("initial-height", height)

	self:SetFrameStrata("BACKGROUND")

	self:SetBackdrop(backdrop)
	self:SetBackdropColor(0, 0, 0, 1)
	self:SetBackdropBorderColor(0, 0, 0, 0)

	self.Health = CreateFrame("StatusBar", nil, self)
	self.Health:SetStatusBarTexture(STATUSBAR)
	self.Health:SetPoint("BOTTOMLEFT", INSET, INSET)
	self.Health:SetPoint("BOTTOMRIGHT", -INSET, INSET)
	self.Health:SetHeight(c.height - (hasPower and (c.height / H_DIV) or 0))

	self.Health.bg = self.Health:CreateTexture(nil, "BACKGROUND")
	self.Health.bg:SetTexture(STATUSBAR)
	self.Health.bg:SetAllPoints(self.Health)

	self.Health.value = self.Health:CreateFontString(nil, "OVERLAY")
	self.Health.value:SetFont(FONT, 26, settings.outline)
	self.Health.value:SetShadowOffset(1, -1)

	self.Health.smoothUpdates = true
	self.OverrideUpdateHealth = UpdateHealth

	if hasPower then
		self.Power = CreateFrame("StatusBar", nil, self)
		self.Power:SetStatusBarTexture(STATUSBAR)
		self.Power:SetPoint("TOPLEFT", INSET, -INSET)
		self.Power:SetPoint("TOPRIGHT", -INSET, -INSET)
		self.Power:SetHeight(c.height / H_DIV)

		self.Power.bg = self.Power:CreateTexture(nil, "BACKGROUND")
		self.Power.bg:SetTexture(STATUSBAR)
		self.Power.bg:SetAllPoints(self.Power)

		self.Power.value = self.Power:CreateFontString(nil, "OVERLAY")
		self.Power.value:SetFont(FONT, 20, settings.outline)
		self.Power.value:SetShadowOffset(1, -1)

		self.frequentPower = unit == "player" or unit == "pet"
		self.Power.smoothUpdates = true
		self.OverrideUpdatePower = UpdatePower
	end

	if unit ~= "player" and unit ~= "pet" then
		self.Name = self.Health:CreateFontString(nil, "OVERLAY")
		self.Name:SetFont(FONT, 20, settings.outline)
		self.Name:SetShadowOffset(1, -1)

		self:RegisterEvent("UNIT_NAME_UPDATE", UpdateName)
		table.insert(self.__elements, UpdateName)
	end

	if unit == "target" then
		self.CPoints = self.Health:CreateFontString(nil, "OVERLAY")
		self.CPoints:SetFont(FONT, 32, settings.outline)
		self.CPoints:SetShadowOffset(1, -1)
		self.CPoints:SetPoint("RIGHT", self, "LEFT", 0, 0)
	end

	if unit == "player" or unit == "pet" or unit == "target" then
		self.Assistant = self.Health:CreateTexture(nil, "OVERLAY")
		self.Assistant:SetPoint("LEFT", self.Health, "BOTTOMLEFT", 1, settings.borderStyle == "TEXTURE" and -1 or 1)
		self.Assistant:SetWidth(16)
		self.Assistant:SetHeight(16)

		self.Leader = self.Health:CreateTexture(nil, "OVERLAY")
		self.Leader:SetPoint("LEFT", self.Health, "BOTTOMLEFT", 1, settings.borderStyle == "TEXTURE" and -1 or 1)
		self.Leader:SetWidth(16)
		self.Leader:SetHeight(16)

		self.MasterLooter = self.Health:CreateTexture(nil, "OVERLAY")
		self.MasterLooter:SetPoint("BOTTOMLEFT", self.Leader, "BOTTOMRIGHT", 0, 2)
		self.MasterLooter:SetWidth(14)
		self.MasterLooter:SetHeight(14)
	end

	if unit == "player" then
		self.Combat = self.Health:CreateTexture(nil, "OVERLAY")
		self.Combat:SetPoint("CENTER", self.Health, "TOP", 2, 4)
		self.Combat:SetWidth(32)
		self.Combat:SetHeight(32)

		self.Resting = self.Health:CreateTexture(nil, "OVERLAY")
		self.Resting:SetPoint("RIGHT", self.Health, "BOTTOMRIGHT", 2, settings.borderStyle == "TEXTURE" and -1 or 1)
		self.Resting:SetWidth(24)
		self.Resting:SetHeight(24)
		self.Resting:SetTexture([[Interface\CharacterFrame\UI-StateIcon]])
		self.Resting:SetTexCoord(.5, 0, 0, .421875)
	end

	if unit == "player" or unit == "party" then
		self.LFDRole = self.Health:CreateTexture(nil, "OVERLAY")
		self.LFDRole:SetPoint("CENTER", self, unit == "player" and "LEFT" or "RIGHT", unit == "player" and INSET or -INSET, 0)
		self.LFDRole:SetWidth(20)
		self.LFDRole:SetHeight(20)
	end

	self.RaidIcon = self.Health:CreateTexture(nil, "OVERLAY")
	self.RaidIcon:SetPoint("CENTER", self, "BOTTOM", -INSET, 0)
	self.RaidIcon:SetWidth(24)
	self.RaidIcon:SetHeight(24)

	if unit == "pet" or unit == "party" or unit == "partypet" then
		self.Range = true
		self.inRangeAlpha = 1
		self.outsideRangeAlpha = 0.65
	end

	if not unit:match("^.+target$") then
		self.Threat = fakeThreat
		self.OverrideUpdateThreat = UpdateThreatHighlight
	end

	if settings.borderStyle == "TEXTURE" then
		AddBorder(self)
		for i, tex in ipairs(self.borderTextures) do
			tex:SetParent(self.Health)
		end
	elseif settings.borderStyle == "GLOW" then
		self.BorderGlow = CreateFrame("Frame", nil, self)
		self.BorderGlow:SetFrameStrata("BACKGROUND")
		self.BorderGlow:SetFrameLevel(self:GetFrameLevel() - 1)
		self.BorderGlow:SetAllPoints(self)
		self.BorderGlow:SetBackdrop(backdrop_glow)
		self.BorderGlow:SetBackdropColor(0, 0, 0, 0)
		self.BorderGlow:SetBackdropBorderColor(0, 0, 0, 1)
	end
	self.UpdateBorder = UpdateBorder

	if c.func then
		c.func(self)
	end

	--
	-- Module: DispelHighlight
	--
	self.DispelHighlight = UpdateDispelHighlight

	--
	-- Module: GlobalCooldown
	--
	self.GlobalCooldown = CreateFrame("Frame", nil, self.Power)
	self.GlobalCooldown:SetAllPoints(self.Power)

	self.GlobalCooldown.spark = self.GlobalCooldown:CreateTexture(nil, "OVERLAY")
	self.GlobalCooldown.spark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
	self.GlobalCooldown.spark:SetBlendMode("ADD")
	self.GlobalCooldown.spark:SetHeight(self.GlobalCooldown:GetHeight() * 5)
	self.GlobalCooldown.spark:SetWidth(10)

	--
	-- Module: IncomingHeals
	--
	self.HealCommBar = self.Health:CreateTexture(nil, "OVERLAY")
	self.HealCommBar:SetTexture(STATUSBAR)
	self.HealCommBar:SetVertexColor(0, 1, 0)
	self.HealCommBar:SetAlpha(0.35)
	self.HealCommBar:SetHeight(self.Health:GetHeight())

	self.HealCommIgnoreHoTs = true
	self.HealCommNoOverflow = true

	--[[
	self.IncomingHeals = { }
	for i = 1, 3 do
		self.IncomingHeals[i] = self.Health:CreateTexture(nil, "OVERLAY")
		self.IncomingHeals[i]:SetTexture(STATUSBAR)
		self.IncomingHeals[i]:SetHeight(self.Health:GetHeight())
	end
	self.IncomingHeals.hideOverflow = true
	self.IncomingHeals.ignoreBombs = true
	self.IncomingHeals.ignoreHoTs = true
	]]

	--
	-- Module: Resurrection
	--
	self.ResurrectionText = self.Health:CreateFontString(nil, "OVERLAY")
	self.ResurrectionText:SetFont(FONT, 20, settings.outline)
	self.ResurrectionText:SetPoint("BOTTOM", 0, 1)

	--
	-- Plugin: oUF_AFK
	--
	if select(4, GetAddOnInfo("oUF_AFK")) and (unit == "player" or unit == "party") then
		self.AFK = self.Health:CreateFontString(nil, "OVERLAY")
		self.AFK:SetFont(FONT, 12, settings.outline)
		self.AFK:SetPoint("CENTER", self, "BOTTOM", 0, INSET)
		self.AFK.fontFormat = "AFK %s:%s"
	end

	--
	-- Plugin: oUF_ReadyCheck
	--
	if select(4, GetAddOnInfo("oUF_ReadyCheck")) and (unit == "player" or unit == "party") then
		self.ReadyCheck = self.Health:CreateTexture(nil, "OVERLAY")
		self.ReadyCheck:SetPoint("CENTER")
		self.ReadyCheck:SetWidth(32)
		self.ReadyCheck:SetHeight(32)

		self.ReadyCheck.delayTime = 5
		self.ReadyCheck.fadeTime = 1
	end

	--
	-- Disable plugin: oUF_QuickHealth2
	-- Worthless waste of resources, used by idiots for placebo effect.
	--
	if select(4, GetAddOnInfo("oUF_QuickHealth2")) then
		self.ignoreQuickHealth = true
	end

	return self
end

------------------------------------------------------------------------

oUF_Phanx:RegisterEvent("ADDON_LOADED")
oUF_Phanx:SetScript("OnEvent", function(self, event, addon)
	if addon ~= ADDON_NAME then return end

	if not oUF_Phanx_Settings then
		oUF_Phanx_Settings = { }
	end
	for k, v in pairs(settings) do
		if type(v) ~= type(oUF_Phanx_Settings[k]) then
			oUF_Phanx_Settings[k] = v
		end
	end
	settings = oUF_Phanx_Settings
	self.settings = settings

	----------------------------------------------------------------

	if settings.borderStyle == "TEXTURE" then
		INSET = INSET - 2
		for point in pairs(backdrop.insets) do
			backdrop.insets[point] = 0
		end
	end

	----------------------------------------------------------------

	self.fontList = { }
	self.statusbarList = { }

	SharedMedia = LibStub("LibSharedMedia-3.0", true)
	if SharedMedia then
		for name, file in pairs(defaultFonts) do
			if file:match("^Interface\\AddOns") then
				SharedMedia:Register("font", name, file)
			end
		end
		for i, v in pairs(SharedMedia:List("font")) do
			table.insert(self.fontList, v)
		end
		table.sort(self.fontList)

		for name, file in pairs(defaultStatusbars) do
			if file:match("^Interface\\AddOns") then
				SharedMedia:Register("statusbar", name, file)
			end
		end
		for i, v in pairs(SharedMedia:List("statusbar")) do
			table.insert(self.statusbarList, v)
		end
		table.sort(self.statusbarList)

		function oUF_Phanx:SharedMedia_Registered(_, mediaType, mediaName)
			if mediaType == "font" then
				table.insert(self.fontList, mediaName)
				table.sort(self.fontList)
				self:SetFont()
			elseif mediaType == "statusbar" then
				table.insert(self.statusbarList, mediaName)
				table.sort(self.statusbarList)
				self:SetStatusBarTexture()
			end
		end
		SharedMedia.RegisterCallback(self, "LibSharedMedia_Registered", "SharedMedia_Registered")

		function oUF_Phanx:SharedMedia_SetGlobal(_, mediaType)
			if mediaType == "font" then
				self:SetFont()
			elseif mediaType == "statusbar" then
				self:SetStatusBarTexture()
			end
		end
		SharedMedia.RegisterCallback(self, "LibSharedMedia_SetGlobal",  "SharedMedia_SetGlobal")
	else
		for k, v in pairs(defaultFonts) do
			table.insert(self.fontList, k)
		end
		table.sort(self.fontList)

		for k, v in pairs(defaultStatusbars) do
			table.insert(self.statusbarList, k)
		end
		table.sort(self.statusbarList)
	end

	----------------------------------------------------------------

	oUF:RegisterStyle("Phanx", Spawn)
	oUF:SetActiveStyle("Phanx")

	oUF:Spawn("player", "oUF_Phanx_Player"):SetPoint("TOP", UIParent, "CENTER", 0, -200)
	oUF:Spawn("pet", "oUF_Phanx_Pet"):SetPoint("TOP", oUF.units.player, "BOTTOM", 0, settings.borderStyle == "TEXTURE" and -24 or -16)

	oUF:Spawn("target", "oUF_Phanx_Target"):SetPoint("TOPLEFT", UIParent, "CENTER", 200, -100)
	oUF:Spawn("targettarget", "oUF_Phanx_TargetTarget"):SetPoint("BOTTOMRIGHT", oUF.units.target, "TOPRIGHT", 0, settings.borderStyle == "TEXTURE" and 24 or 16)

	if settings.focusPlacement == "LEFT" then
		oUF:Spawn("focus", "oUF_Phanx_Focus"):SetPoint("TOPRIGHT", UIParent, "CENTER", -200, -100)
		oUF:Spawn("focustarget", "oUF_Phanx_FocusTarget"):SetPoint("BOTTOMLEFT", oUF.units.focus, "TOPLEFT", 0, settings.borderStyle == "TEXTURE" and 24 or 16)
	else
		oUF:Spawn("focus", "oUF_Phanx_Focus"):SetPoint("TOPLEFT", UIParent, "CENTER", 200, -300 + oUF.units.target:GetHeight())
		oUF:Spawn("focustarget", "oUF_Phanx_FocusTarget"):SetPoint("TOPRIGHT", oUF.units.focus, "BOTTOMRIGHT", 0, settings.borderStyle == "TEXTURE" and -24 or -16)
	end

	----------------------------------------------------------------

	self:UnregisterEvent("ADDON_LOADED")
end)

oUF_Phanx.debug = debug

oUF_Phanx.defaultFonts = defaultFonts
oUF_Phanx.defaultStatusbars = defaultStatusbars

namespace.oUF_Phanx = oUF_Phanx
_G.oUF_Phanx = oUF_Phanx

------------------------------------------------------------------------

SLASH_RELOADUI1 = "/rl"
SlashCmdList.RELOADUI = ReloadUI
