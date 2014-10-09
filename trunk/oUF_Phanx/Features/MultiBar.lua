local _, ns = ...

local function Bar_Hide(bar)
	if bar.__hidden then return end
	bar.__hidden = true
	bar:SetValue(0)
end

local function Bar_Show(bar)
	if not bar.__hidden then return end
	bar.__hidden = nil
	local _, value = bar:GetMinMaxValues()
	bar:SetValue(value)
end

local function Bar_IsShown(bar)
	return not bar.__hidden
end

local function Bar_SetShown(bar, show)
	return show and Bar_Show(bar) or Bar_Hide(bar)
end

function ns.CreateMultiBar(frame, numBars, textSize, leftToRight)
	local multibar = CreateFrame("Frame", nil, frame)
	multibar.__owner = frame

	multibar:SetBackdrop(ns.config.backdrop)
	multibar:SetBackdropColor(0, 0, 0, 1)
	multibar:SetBackdropBorderColor(unpack(ns.config.borderColor))

	multibar:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, -1)
	multibar:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, -1)
	multibar:SetHeight(frame:GetHeight() * ns.config.powerHeight + 2)

	multibar:EnableMouse(true)
	multibar:SetScript("OnEnter", ns.UnitFrame_OnEnter)
	multibar:SetScript("OnLeave", ns.UnitFrame_OnLeave)

	multibar:Hide()
	multibar:SetScript("OnShow", ns.ExtraBar_OnShow)
	multibar:SetScript("OnHide", ns.ExtraBar_OnHide)

	local barWidth = floor((frame:GetWidth() - (numBars + 1)) / numBars + 0.5)
	local RIGHT, LEFT = leftToRight and "LEFT" or "RIGHT", leftToRight and "RIGHT" or "LEFT"

	for i = 1, numBars do
		local bar = ns.CreateStatusBar(multibar, textSize, "CENTER")
		bar.bg.multiplier = ns.config.powerBG

		bar:SetWidth(barWidth)
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(1)

		bar.Hide = Bar_Hide
		bar.Show = Bar_Show
		bar.IsShown = Bar_IsShown
		bar.SetShown = Bar_SetShown

		if i > 1 then
			bar:SetPoint("TOP"..RIGHT, multibar[i-1], "TOP"..LEFT, -1, 0)
			bar:SetPoint("BOTTOM"..RIGHT, multibar[i-1], "BOTTOM"..LEFT, -1, 0)
			if i == numBars then
				-- Fill up remaining space left by rounding
				-- the bars down to avoid fuzzy edges.
				bar:SetPoint("TOP"..LEFT, multibar, -1, -1)
				bar:SetPoint("BOTTOM"..LEFT, multibar, -1, 1)
			end
		else
			bar:SetPoint("TOP"..RIGHT, multibar, -1, -1)
			bar:SetPoint("BOTTOM"..RIGHT, multibar, -1, 1)
		end

		bar.__owner = frame
		multibar[i] = bar
	end

	return multibar
end
