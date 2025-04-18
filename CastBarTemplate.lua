--[[
	Copyright (C) 2006-2007 Nymbia
	Copyright (C) 2010 Hendrik "Nevcairiel" Leppkes < h.leppkes@gmail.com >

	This program is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 2 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program; if not, write to the Free Software Foundation, Inc.,
	51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
]]
local Quartz3 = LibStub("AceAddon-3.0"):GetAddon("Quartz3")
local L = LibStub("AceLocale-3.0"):GetLocale("Quartz3")

local media = LibStub("LibSharedMedia-3.0")
local lsmlist = AceGUIWidgetLSMlists

----------------------------
-- Upvalues
local min, type, format, unpack, setmetatable = math.min, type, string.format, unpack, setmetatable
local CreateFrame, GetTime, UIParent = CreateFrame, GetTime, UIParent
local UnitName, UnitCastingInfo, UnitChannelInfo = UnitName, UnitCastingInfo, UnitChannelInfo
local getn = table.getn

local CastBarTemplate = CreateFrame("Frame")
local CastBarTemplate_MT = {__index = CastBarTemplate}

local TimeFmt, RomanFmt = Quartz3.Util.TimeFormat, Quartz3.Util.ConvertRankToRomanNumeral

local playerName = UnitName("player")

local function call(obj, method, ...)
	if type(obj.parent[method]) == "function" then
		return obj.parent[method](obj.parent, obj, unpack(arg))
	end
end

----------------------------
-- Frame Scripts

-- OnShow and OnHide are not used by the template
-- But forward the call to the embeding module, they might use it.
local function OnShow()
	call(this, "OnShow")
end

local function OnHide()
	call(this, "OnHide")
end

-- OnUpdate handles the bar movement and the text updates
local function OnUpdate()
	local self = this
	local currentTime = GetTime()
	local startTime, endTime, delay = self.startTime, self.endTime, self.delay
	local db = self.config
	if self.channeling or self.casting then
		local perc, remainingTime, delayFormat, delayFormatTime
		if self.casting then
			local showTime = min(currentTime, endTime)
			remainingTime = endTime - showTime
			perc = (showTime - startTime) / (endTime - startTime)

			delayFormat, delayFormatTime = "|cffff0000+%.1f|cffffffff %s", "|cffff0000+%.1f|cffffffff %s / %s"
		elseif self.channeling then
			remainingTime = endTime - currentTime
			perc = remainingTime / (endTime - startTime)
			
			delayFormat, delayFormatTime = "|cffff0000-%.1f|cffffffff %s", "|cffff0000-%.1f|cffffffff %s / %s"
		end

		self.Bar:SetValue(perc)
		self.Spark:ClearAllPoints()
		self.Spark:SetPoint("CENTER", self.Bar, "LEFT", perc * db.w, 0)

		if delay and delay ~= 0 then
			if db.hidecasttime then
				self.TimeText:SetText(format("|cffff0000+%.1f|cffffffff %s", delay, format(TimeFmt(remainingTime))))
			else
				self.TimeText:SetText(format("|cffff0000+%.1f|cffffffff %s / %s", delay, format(TimeFmt(remainingTime)), format(TimeFmt(endTime - startTime, true))))
			end
		else
			if db.hidecasttime then
				self.TimeText:SetText(format(TimeFmt(remainingTime)))
			else
				self.TimeText:SetText(format("%s / %s", format(TimeFmt(remainingTime)), format(TimeFmt(endTime - startTime, true))))
			end
		end

		if currentTime > endTime then
			self.casting, self.channeling = nil, nil
			self.fadeOut = true
			self.stopTime = currentTime
		end
	elseif self.fadeOut then
		self.Spark:Hide()
		local alpha
		local stopTime = self.stopTime
		if stopTime then
			alpha = stopTime - currentTime + 1
		else
			alpha = 0
		end
		if alpha >= 1 then
			alpha = 1
		end
		if alpha <= 0 then
			self.stopTime = nil
			self:Hide()
		else
			self:SetAlpha(alpha*db.alpha)
		end
	else
		self:Hide()
	end
end
CastBarTemplate.OnUpdate = OnUpdate

local function OnEvent()
	if this[event] then
		this[event](this, event, arg1, arg2, arg3, arg4, arg5)
	end
end

----------------------------
-- Template Methods

local function SetNameText(self, name, rank)
	local mask, arg = nil, nil
	if self.config.spellrank and rank then
		mask, arg = RomanFmt(rank, self.config.spellrankstyle)
	end

	if self.config.targetname and self.targetName and self.targetName ~= "" then
		if mask then
			mask = mask .. " -> " .. self.targetName
		else
			name = name .. " -> " .. self.targetName
		end
	end
	if mask then
		self.Text:SetFormattedText(mask, name, arg)
	else
		self.Text:SetText(name)
	end
end
CastBarTemplate.SetNameText = SetNameText

local function ToggleCastNotInterruptible(self, notInterruptible, init)
	if self.unit == "player" and not init then return end
	local db = self.config

	if notInterruptible and db.noInterruptChangeColor then
		self.Bar:SetStatusBarColor(unpack(db.noInterruptColor))
	end

	local r, g, b, a
	if notInterruptible and db.noInterruptChangeBorder then
		self.backdrop.edgeFile = media:Fetch("border", db.noInterruptBorder)
		r,g,b = unpack(db.noInterruptBorderColor)
		a = db.noInterruptBorderAlpha
	else
		self.backdrop.edgeFile = media:Fetch("border", db.border)
		r,g,b = unpack(Quartz3.db.profile.bordercolor)
		a = Quartz3.db.profile.borderalpha
	end
	self:SetBackdrop(self.backdrop)
	self:SetBackdropBorderColor(r, g, b, a)

	r, g, b = unpack(Quartz3.db.profile.backgroundcolor)
	self:SetBackdropColor(r, g, b, Quartz3.db.profile.backgroundalpha)

	if self.Shield then
		if notInterruptible and db.noInterruptShield and not db.hideicon then
			self.Shield:Show()
		else
			self.Shield:Hide()
		end
	end

	self.lastNotInterruptible = notInterruptible
end
CastBarTemplate.ToggleCastNotInterruptible = ToggleCastNotInterruptible

----------------------------
-- Event Handlers


local function getUnitFromGuid(guid)
	local _, unit	= UnitExists("player")
	if unit == guid then
		return "player"
	end
	_, unit = UnitExists("playerpet")
	if unit == guid then
		return "pet"
	end
	_, unit = UnitExists("target")
	if unit == guid then
		return "target"
	end
end


function CastBarTemplate:UNIT_CASTEVENT()

	local caster, target, eventType, spellId, start, duration = arg1, arg2, arg3, arg4, GetTime(), arg5 / 1000
  
	local unit, event = getUnitFromGuid(caster)
	if eventType == "START" then
		event = "UNIT_SPELLCAST_START"
		self:UNIT_SPELLCAST_SENT(eventType, unit, spellId, nil, target)
		self:UNIT_SPELLCAST_START(event, unit, {id = spellId, startTime = start, endTime = start + duration})
	elseif eventType == "CHANNEL" then
		event = "UNIT_SPELLCAST_CHANNEL_START"
		self:UNIT_SPELLCAST_SENT(eventType, unit, spellId, nil, target)
		self:UNIT_SPELLCAST_START(event, unit, {id = spellId, startTime = start, endTime = start + duration})
	elseif eventType == "FAIL" then
		self:UNIT_SPELLCAST_FAILED(event, unit)
	elseif eventType == "CAST" and self.casting  then
		self:UNIT_SPELLCAST_STOP(event, unit)
	end


end

function CastBarTemplate:UNIT_SPELLCAST_SENT(event, unit, spell, rank, target)
	if unit ~= self.unit and not (self.unit == "player" and unit == "vehicle") then
		return
	end
	if target then
		self.targetName = UnitName(target)
	else
		-- auto selfcast? is this needed, even?
		self.targetName = playerName
	end

	call(self, "UNIT_SPELLCAST_SENT", unit, spell, rank, target)
end

function CastBarTemplate:UNIT_SPELLCAST_START(event, unit, spell)
	if (unit ~= self.unit and not (self.unit == "player" and unit == "vehicle")) or call(self, "PreShowCondition", unit) then
		return
	end
	
	local db = self.config
	if event == "UNIT_SPELLCAST_START" then
		self.casting, self.channeling = true, nil
	else
		self.casting, self.channeling = nil, true
	end

	local spellName, rank, icon =  SpellInfo(spell.id)
	local displayName, notInterruptible = spellName, false

	-- in case this returned nothing
	if not spell.startTime then return end

	self.startTime = spell.startTime
	self.endTime = spell.endTime
	self.delay = 0
	self.fadeOut = nil

	self.Bar:SetStatusBarColor(unpack(self.casting and Quartz3.db.profile.castingcolor or Quartz3.db.profile.channelingcolor))

	self.Bar:SetValue(self.casting and 0 or 1)
	self:Show()
	self:SetAlpha(db.alpha)

	SetNameText(self, displayName, rank)

	self.Spark:Show()

	if icon == "Interface\\Icons\\Temp" and Quartz3.db.profile.hidesamwise then
		icon = nil
	end
	self.Icon:SetTexture(icon)

	local position = db.timetextposition
	if position == "caststart" or position == "castend" then
		if (position == "caststart" and self.casting) or (position == "castend" and self.channeling) then
			self.TimeText:SetPoint("LEFT", self.Bar, "LEFT", db.timetextx, db.timetexty)
			self.TimeText:SetJustifyH("LEFT")
		else
			self.TimeText:SetPoint("RIGHT", self.Bar, "RIGHT", -1 * db.timetextx, db.timetexty)
			self.TimeText:SetJustifyH("RIGHT")
		end
	end

	ToggleCastNotInterruptible(self, notInterruptible)

	call(self, "UNIT_SPELLCAST_START", unit, spell)
end
CastBarTemplate.UNIT_SPELLCAST_CHANNEL_START = CastBarTemplate.UNIT_SPELLCAST_START

function CastBarTemplate:UNIT_SPELLCAST_STOP(event, unit)
	if not (self.channeling or self.casting) or (unit ~= self.unit and not (self.unit == "player" and unit == "vehicle")) then
		return
	end

	self.Bar:SetValue(self.casting and 1.0 or 0)
	self.Bar:SetStatusBarColor(unpack(Quartz3.db.profile.completecolor))

	self.casting, self.channeling = nil, nil
	self.fadeOut = true
	self.stopTime = GetTime()

	self.TimeText:SetText("")

	call(self, "UNIT_SPELLCAST_STOP", unit)
end
CastBarTemplate.UNIT_SPELLCAST_CHANNEL_STOP = CastBarTemplate.UNIT_SPELLCAST_STOP

function CastBarTemplate:UNIT_SPELLCAST_FAILED(event, unit)
	if not (self.channeling or self.casting)  or (unit ~= self.unit and not (self.unit == "player" and unit == "vehicle")) then
		return
	end

	self.Bar:SetValue(self.casting and 1.0 or 0)
	self.casting, self.channeling = nil, nil
	self.fadeOut = true
	self.stopTime = GetTime()
	self.Bar:SetStatusBarColor(unpack(Quartz3.db.profile.failcolor))

	self.TimeText:SetText("")

	call(self, "UNIT_SPELLCAST_FAILED", unit)
end

function CastBarTemplate:UNIT_SPELLCAST_INTERRUPTED(event, unit)
	if unit ~= self.unit and not (self.unit == "player" and unit == "vehicle") then
		return
	end
	self.casting, self.channeling = nil, nil
	self.fadeOut = true
	if not self.stopTime then
		self.stopTime = GetTime()
	end
	self.Bar:SetValue(1.0)
	self.Bar:SetStatusBarColor(unpack(Quartz3.db.profile.failcolor))

	self.TimeText:SetText("")

	call(self, "UNIT_SPELLCAST_INTERRUPTED", unit)
end
CastBarTemplate.UNIT_SPELLCAST_CHANNEL_INTERRUPTED = CastBarTemplate.UNIT_SPELLCAST_INTERRUPTED

function CastBarTemplate:SPELLCAST_DELAYED(e,d)
  d=d/1000
  local unit = "player"
	if unit ~= self.unit and not (self.unit == "player" and unit == "vehicle") or call(self, "PreShowCondition", unit) then
		return
	end
	self.startTime = self.startTime + d
	self.endTime = self.endTime + d

	if self.casting then
		self.delay = (self.delay or 0) + d
	else
		self.delay = (self.delay or 0) + d
	end

	call(self, "UNIT_SPELLCAST_DELAYED", unit, d)
end
CastBarTemplate.SPELLCAST_CHANNEL_UPDATE=CastBarTemplate.SPELLCAST_DELAYED

function CastBarTemplate:UNIT_SPELLCAST_DELAYED(event, unit)
	if unit ~= self.unit and not (self.unit == "player" and unit == "vehicle") or call(self, "PreShowCondition", unit) then
		return
	end
	local oldStart = self.startTime
	local spell, rank, displayName, icon, startTime, endTime
	if self.casting then
		spell, rank, displayName, icon, startTime, endTime = UnitCastingInfo(unit)
	else
		spell, rank, displayName, icon, startTime, endTime = UnitChannelInfo(unit)
	end

	if not startTime then
		return self:Hide()
	end

	startTime = startTime / 1000
	endTime = endTime / 1000
	self.startTime = startTime
	self.endTime = endTime

	if self.casting then
		self.delay = (self.delay or 0) + (startTime - (oldStart or startTime))
	else
		self.delay = (self.delay or 0) + ((oldStart or startTime) - startTime)
	end

	call(self, "UNIT_SPELLCAST_DELAYED", unit)
end
CastBarTemplate.UNIT_SPELLCAST_CHANNEL_UPDATE = CastBarTemplate.UNIT_SPELLCAST_DELAYED

function CastBarTemplate:SPELLCAST_START(s,d)
	--printT({event,s,d})
end
function CastBarTemplate:SPELLCAST_CHANNEL_START(s,d)
	--printT({event,s,d})
end
function CastBarTemplate:SPELLCAST_CHANNEL_STOP(s,d)
	self:UNIT_SPELLCAST_STOP(event, "player")
end



function CastBarTemplate:UNIT_SPELLCAST_INTERRUPTIBLE(event, unit)
	if unit ~= self.unit then
		return
	end
	ToggleCastNotInterruptible(self, false)
end

function CastBarTemplate:UNIT_SPELLCAST_NOT_INTERRUPTIBLE(event, unit)
	if unit ~= self.unit then
		return
	end
	ToggleCastNotInterruptible(self, true)
end


function CastBarTemplate:UpdateUnit()
	--[[if UnitCastingInfo(self.unit) then
		self:UNIT_SPELLCAST_START("UNIT_SPELLCAST_START", self.unit)
	elseif UnitChannelInfo(self.unit) then
		self:UNIT_SPELLCAST_START("UNIT_SPELLCAST_CHANNEL_START", self.unit)
	else]]
		self:Hide()
	--end
end

function CastBarTemplate:SetConfig(config)
	self.config = config
end

function CastBarTemplate:ApplySettings()
	local db = self.config

	self:ClearAllPoints()
	if not db.x then
		db.x = (UIParent:GetWidth() / 2 - (db.w * db.scale) / 2) / db.scale
	end
	self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", db.x, db.y)
	self:SetWidth(db.w + 10)
	self:SetHeight(db.h + 10)
	self:SetAlpha(db.alpha)
	self:SetScale(db.scale)

	ToggleCastNotInterruptible(self, self.lastNotInterruptible, true)

	self.Bar:ClearAllPoints()
	self.Bar:SetPoint("CENTER",self,"CENTER")
	self.Bar:SetWidth(db.w)
	self.Bar:SetHeight(db.h)
	self.Bar:SetStatusBarTexture(media:Fetch("statusbar", db.texture))
	--self.Bar:GetStatusBarTexture():SetHorizTile(false)
	--self.Bar:GetStatusBarTexture():SetVertTile(false)
	self.Bar:SetMinMaxValues(0, 1)

	if db.hidetimetext then
		self.TimeText:Hide()
	else
		self.TimeText:Show()
		self.TimeText:ClearAllPoints()
		self.TimeText:SetWidth(db.w)
		local position = db.timetextposition
		if position == "left" then
			self.TimeText:SetPoint("LEFT", self.Bar, "LEFT", db.timetextx, db.timetexty)
			self.TimeText:SetJustifyH("LEFT")
		elseif position == "center" then
			self.TimeText:SetPoint("CENTER", self.Bar, "CENTER", db.timetextx, db.timetexty)
			self.TimeText:SetJustifyH("CENTER")
		elseif position == "right" then
			self.TimeText:SetPoint("RIGHT", self.Bar, "RIGHT", -1 * db.timetextx, db.timetexty)
			self.TimeText:SetJustifyH("RIGHT")
		end -- L["Cast Start Side"], L["Cast End Side"] -- handled at runtime
	end
	self.TimeText:SetFont(media:Fetch("font", db.font), db.timefontsize)
	self.TimeText:SetShadowColor( 0, 0, 0, 1)
	self.TimeText:SetShadowOffset( 0.8, -0.8 )
	self.TimeText:SetTextColor(unpack(Quartz3.db.profile.timetextcolor))
	self.TimeText:SetNonSpaceWrap(false)
	self.TimeText:SetHeight(db.h)

	local temptext = self.TimeText:GetText()
	if db.hidecasttime then
		self.TimeText:SetText(TimeFmt(10))
	else
		self.TimeText:SetText(format("%s / %s", format(TimeFmt(10)), format(TimeFmt(10, true))))
	end
	local normaltimewidth = self.TimeText:GetStringWidth()
	self.TimeText:SetText(temptext)

	if db.hidenametext then
		self.Text:Hide()
	else
		self.Text:Show()
		self.Text:ClearAllPoints()
		local position = db.nametextposition
		if position == "left" then
			self.Text:SetPoint("LEFT", self.Bar, "LEFT", db.nametextx, db.nametexty)
			self.Text:SetJustifyH("LEFT")
			if db.hidetimetext or db.timetextposition ~= "right" then
				self.Text:SetWidth(db.w)
			else
				self.Text:SetWidth(db.w - normaltimewidth - 5)
			end
		elseif position == "center" then
			self.Text:SetPoint("CENTER", self.Bar, "CENTER", db.nametextx, db.nametexty)
			self.Text:SetJustifyH("CENTER")
		else -- L["Right"]
			self.Text:SetPoint("RIGHT", self.Bar, "RIGHT", -1 * db.nametextx, db.nametexty)
			self.Text:SetJustifyH("RIGHT")
			if db.hidetimetext or db.timetextposition ~= "left" then
				self.Text:SetWidth(db.w)
			else
				self.Text:SetWidth(db.w - normaltimewidth - 5)
			end
		end
	end
	self.Text:SetFont(media:Fetch("font", db.font), db.fontsize)
	self.Text:SetShadowColor( 0, 0, 0, 1)
	self.Text:SetShadowOffset( 0.8, -0.8 )
	self.Text:SetTextColor(unpack(Quartz3.db.profile.spelltextcolor))
	self.Text:SetNonSpaceWrap(false)
	self.Text:SetHeight(db.h)

	if db.hideicon then
		self.Icon:Hide()
	else
		self.Icon:Show()
		self.Icon:ClearAllPoints()
		if db.iconposition == "left" then
			self.Icon:SetPoint("RIGHT", self.Bar, "LEFT", -1 * db.icongap, 0)
		else --L["Right"]
			self.Icon:SetPoint("LEFT", self.Bar, "RIGHT", db.icongap, 0)
		end
		self.Icon:SetWidth(db.h)
		self.Icon:SetHeight(db.h)
		self.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		self.Icon:SetAlpha(db.iconalpha)
	end

	self.Spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
	self.Spark:SetVertexColor(unpack(Quartz3.db.profile.sparkcolor))
	self.Spark:SetBlendMode("ADD")
	self.Spark:SetWidth(20)
	self.Spark:SetHeight(db.h*2.2)
end

function CastBarTemplate:RegisterEvents()
--[[	if self.unit == "player" then
		self:RegisterEvent("UNIT_SPELLCAST_SENT")
	end
	self:RegisterEvent("UNIT_SPELLCAST_START")
	self:RegisterEvent("UNIT_SPELLCAST_STOP")
	self:RegisterEvent("UNIT_SPELLCAST_FAILED")
	self:RegisterEvent("UNIT_SPELLCAST_DELAYED")
	self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_INTERRUPTED")
	if self.unit ~= "player" then
		self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
		self:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
	end
]]
	
	self:RegisterEvent("UNIT_CASTEVENT") --SWOW
	if self.unit == "player" then
		self:RegisterEvent("SPELLCAST_INTERRUPTED")
		self:RegisterEvent("SPELLCAST_DELAYED")
		self:RegisterEvent("SPELLCAST_START")
		self:RegisterEvent("SPELLCAST_CHANNEL_START")
		self:RegisterEvent("SPELLCAST_CHANNEL_STOP")
		self:RegisterEvent("SPELLCAST_CHANNEL_UPDATE")
	end

	media.RegisterCallback(self, "LibSharedMedia_SetGlobal", function(mtype, override)
		if mtype == "statusbar" then
			self.Bar:SetStatusBarTexture(media:Fetch("statusbar", override))
		end
	end)

	media.RegisterCallback(self, "LibSharedMedia_Registered", function(mtype, key)
		if mtype == "statusbar" and key == self.config.texture then
			self.Bar:SetStatusBarTexture(media:Fetch("statusbar", self.config.texture))
		end
	end)
end

function CastBarTemplate:UnregisterEvents()
	self:UnregisterAllEvents()
	media.UnregisterCallback(self, "LibSharedMedia_SetGlobal")
	media.UnregisterCallback(self, "LibSharedMedia_Registered")
end

do
	local function dragstart()
		this:StartMoving()
	end

	local function dragstop()
		this.config.x = this:GetLeft()
		this.config.y = this:GetBottom()
		this:StopMovingOrSizing()
	end

	local function nothing()
		this:SetAlpha(this.config.alpha)
	end

	function CastBarTemplate:Unlock()
		self:Show()
		self:EnableMouse(true)
		self:SetScript("OnDragStart", dragstart)
		self:SetScript("OnDragStop", dragstop)
		self:SetAlpha(1)
		self.Hide = nothing
		self.Icon:SetTexture("Interface\\Icons\\Temp")
		self.Text:SetText(self.unit)
	end

	function CastBarTemplate:Lock()
		self.Hide = nil
		self:EnableMouse(false)
		self:SetScript("OnDragStart", nil)
		self:SetScript("OnDragStop", nil)
		if not (self.channeling or self.casting) then
			self:Hide()
		end
	end
end


----------------------------
-- Options

do
	local function getBar(info)
		return Quartz3.CastBarTemplate.bars[info[1]]
	end

	local function hideiconoptions(info)
		local db = getBar(info).config
		return db.hideicon
	end

	local function hidetimetextoptions(info)
		local db = getBar(info).config
		return db.hidetimetext
	end

	local function hidecasttimeprecision(info)
		local db = getBar(info).config
		return db.hidetimetext or db.hidecasttime
	end

	local function hidenametextoptions(info)
		local db = getBar(info).config
		return db.hidenametext
	end

	local function hidespellrankstyle(info)
		local db = getBar(info).config
		return db.hidenametext or not db.spellrank
	end

	local function noInterruptChangeBorder(info)
		local db = getBar(info).config
		return not db.noInterruptChangeBorder
	end

	local function noInterruptChangeColor(info)
		local db = getBar(info).config
		return not db.noInterruptChangeColor
	end
	
	local function icondisabled(info)
		local db = getBar(info).config
		return db.hideicon
	end

	local function snapToCenter(info, v)
		local bar = getBar(info)
		local scale = bar.config.scale
		if v == "horizontal" then
			bar.config.x = (UIParent:GetWidth() / 2 - (bar.config.w * scale) / 2) / scale
		else -- L["Vertical"]
			bar.config.y = (UIParent:GetHeight() / 2 - (bar.config.h * scale) / 2) / scale
		end
		bar:ApplySettings()
	end

	local function copySettings(info, v)
		local bar = getBar(info)
		local from = Quartz3:GetModule(v)
		Quartz3:CopySettings(from.db.profile, bar.config)
		bar:ApplySettings()
	end

	local function getEnabled(info)
		local bar = getBar(info)
		return Quartz3:GetModuleEnabled(bar.modName)
	end

	local function setEnabled(info, v)
		local bar = getBar(info)
		return Quartz3:SetModuleEnabled(bar.modName, v)
	end

	local function getOpt(info)
		local db = getBar(info).config
		return db[info[getn(info)]]
	end

	local function setOpt(info, value)
		local bar = getBar(info)
		bar.config[info[getn(info)]] = value
		bar:ApplySettings()
	end

	local function getColor(info)
		return unpack(getOpt(info))
	end

	local function setColor(info, ...)
		setOpt(info, {unpack(arg)})
	end

	function CastBarTemplate:CreateOptions()
		local options = {
			type = "group",
			name = self.localizedName,
			get = getOpt,
			set = setOpt,
			args = {
				toggle = {
					type = "toggle",
					name = L["Enable"],
					desc = L["Enable"],
					get = getEnabled,
					set = setEnabled,
					order = 99,
					width = "full",
				},
				h = {
					type = "range",
					name = L["Height"],
					desc = L["Height"],
					min = 10, max = 50, step = 1,
					order = 200,
				},
				w = {
					type = "range",
					name = L["Width"],
					desc = L["Width"],
					min = 50, max = 1500, bigStep = 5,
					order = 200,
				},
				x = {
					type = "range",
					name = L["X"],
					desc = L["Set an exact X value for this bar's position."],
					min = -2560, max = 2560, bigStep = 1,
					order = 200,
				},
				y = {
					type = "range",
					name = L["Y"],
					desc = L["Set an exact Y value for this bar's position."],
					min = -1600, max = 1600, bigStep = 1,
					order = 200,
				},
				scale = {
					type = "range",
					name = L["Scale"],
					desc = L["Scale"],
					min = 0.2, max = 1, bigStep = 0.025,
					order = 201,
				},
				alpha = {
					type = "range",
					name = L["Alpha"],
					desc = L["Alpha"],
					isPercent = true,
					min = 0.1, max = 1, bigStep = 0.025,
					order = 202,
				},
				icon = {
					type = "header",
					name = L["Icon"],
					order = 300,
				},
				hideicon = {
					type = "toggle",
					name = L["Hide Icon"],
					desc = L["Hide Spell Cast Icon"],
					order = 301,
				},
				iconposition = {
					type = "select",
					name = L["Icon Position"],
					desc = L["Set where the Spell Cast icon appears"],
					disabled = hideiconoptions,
					values = {["left"] = L["Left"], ["right"] = L["Right"]},
					order = 301,
				},
				iconalpha = {
					type = "range",
					name = L["Icon Alpha"],
					desc = L["Set the Spell Cast icon alpha"],
					isPercent = true,
					min = 0.1, max = 1, bigStep = 0.025,
					order = 302,
					disabled = hideiconoptions,
				},
				icongap = {
					type = "range",
					name = L["Icon Gap"],
					desc = L["Space between the cast bar and the icon."],
					min = -35, max = 35, bigStep = 1,
					order = 302,
					disabled = hideiconoptions,
				},
				fonthead = {
					type = "header",
					name = L["Font and Text"],
					order = 398,
				},
				font = {
					type = "select",
					dialogControl = "LSM30_Font",
					name = L["Font"],
					desc = L["Set the font used in the Name and Time texts"],
					values = lsmlist.font,
					order = 399,
				},
				nlfont = {
					type = "description",
					name = "",
					order = 400,
				},
				hidenametext = {
					type = "toggle",
					name = L["Hide Spell Name"],
					desc = L["Disable the text that displays the spell name/rank"],
					order = 401,
				},
				nlname = {
					type = "description",
					name = "",
					order = 403,
				},
				nametextposition = {
					type = "select",
					name = L["Spell Name Position"],
					desc = L["Set the alignment of the spell name text"],
					values = {["left"] = L["Left"], ["right"] = L["Right"], ["center"] = L["Center"]},
					disabled = hidenametextoptions,
					order = 404,
				},
				fontsize = {
					type = "range",
					name = L["Spell Name Font Size"],
					desc = L["Set the size of the spell name text"],
					min = 7, max = 20, step = 1,
					order = 405,
					disabled = hidenametextoptions,
				},
				nametextx = {
					type = "range",
					name = L["Spell Name X Offset"],
					desc = L["Adjust the X position of the spell name text"],
					min = -35, max = 35, step = 1,
					disabled = hidenametextoptions,
					order = 406,
				},
				nametexty = {
					type = "range",
					name = L["Spell Name Y Offset"],
					desc = L["Adjust the Y position of the name text"],
					min = -35, max = 35, step = 1,
					disabled = hidenametextoptions,
					order = 407,
				},
				spellrank = {
					type = "toggle",
					name = L["Spell Rank"],
					desc = L["Display the rank of spellcasts alongside their name"],
					disabled = hidenametextoptions,
					order = 408,
				},
				spellrankstyle = {
					type = "select",
					name = L["Spell Rank Style"],
					desc = L["Set the display style of the spell rank"],
					disabled = hidespellrankstyle,
					values = {["number"] = L["Number"], ["roman"] = L["Roman"], ["full"] = L["Full Text"], ["romanfull"] = L["Roman Full Text"]},
					order = 409,
				},
				hidetimetext = {
					type = "toggle",
					name = L["Hide Time Text"],
					desc = L["Disable the text that displays the time remaining on your cast"],
					order = 411,
				},
				hidecasttime = {
					type = "toggle",
					name = L["Hide Cast Time"],
					desc = L["Disable the text that displays the total cast time"],
					disabled = hidetimetextoptions,
					order = 412,
				},
				timefontsize = {
					type = "range",
					name = L["Time Font Size"],
					desc = L["Set the size of the time text"],
					min = 7, max = 20, step = 1,
					order = 414,
					disabled = hidetimetextoptions,
				},
				timetextposition = {
					type = "select",
					name = L["Time Text Position"],
					desc = L["Set the alignment of the time text"],
					values = {["left"] = L["Left"], ["right"] = L["Right"], ["center"] = L["Center"], ["caststart"] = L["Cast Start Side"], ["castend"] = L["Cast End Side"]},
					disabled = hidetimetextoptions,
					order = 415,
				},
				timetextx = {
					type = "range",
					name = L["Time Text X Offset"],
					desc = L["Adjust the X position of the time text"],
					min = -35, max = 35, step = 1,
					disabled = hidetimetextoptions,
					order = 416,
				},
				timetexty = {
					type = "range",
					name = L["Time Text Y Offset"],
					desc = L["Adjust the Y position of the time text"],
					min = -35, max = 35, step = 1,
					disabled = hidetimetextoptions,
					order = 417,
				},
				textureheader = {
					type = "header",
					name = L["Texture and Border"],
					order = 450,
				},
				texture = {
					type = "select",
					dialogControl = "LSM30_Statusbar",
					name = L["Texture"],
					desc = L["Set the Cast Bar Texture"],
					values = lsmlist.statusbar,
					order = 451,
				},
				border = {
					type = "select",
					dialogControl = "LSM30_Border",
					name = L["Border"],
					desc = L["Set the border style"],
					values = lsmlist.border,
					order = 452,
				},
				noInterruptGroup = {
					type = "group",
					name = L["No interrupt cast bars"],
					dialogInline = true,
					order = 455,
					args = {
						noInterruptChangeBorder = {
							type = "toggle",
							name = L["Change Border Style"],
							desc = L["Adjust the Border Style for non-interruptible Cast Bars"],
							order = 1,
						},
						noInterruptBorder = {
							type = "select",
							name = L["Border"],
							desc = L["Set the border style for no interrupt casting bars"],
							dialogControl = "LSM30_Border",
							values = lsmlist.border,
							order = 2,
							disabled = noInterruptChangeBorder,
						},
						noInterruptBorderColor = {
							type = "color",
							name = L["Border Color"],
							desc = L["Set the color of the no interrupt casting bar border"],
							get = getColor,
							set = setColor,
							order = 3,
							disabled = noInterruptChangeBorder,
						},
						noInterruptBorderAlpha = {
							type = "range",
							name = L["Border Alpha"],
							desc = L["Set the alpha of the no interrupt casting bar border"],
							isPercent = true,
							min = 0, max = 1, bigStep = 0.025,
							order = 4,
							disabled = noInterruptChangeBorder,
						},
						noInterruptChangeColor = {
							type = "toggle",
							name = L["Change Color"],
							desc = L["Change the color of non-interruptible Cast Bars"],
							order = 10,
						},
						noInterruptColor = {
							type = "color",
							name = L["Cast Bar Color"],
							desc = L["Configure the color of the cast bar."],
							disabled = noInterruptChangeColor,
							set = setColor,
							get = getColor,
							order = 11,
						},
						noInterruptShield = {
							type = "toggle",
							name = L["Show Shield Icon"],
							desc = L["Show the Shield Icon on non-interruptible Cast Bars"],
							disabled = icondisabled,
						},
					},
				},
				toolheader = {
					type = "header",
					name = L["Tools"],
					order = 500,
				},
				snaptocenter = {
					type = "select",
					name = L["Snap to Center"],
					desc = L["Move the CastBar to center of the screen along the specified axis"],
					get = false,
					set = snapToCenter,
					values = {["horizontal"] = L["Horizontal"], ["vertical"] = L["Vertical"]},
					order = 503,
				},
				copysettings = {
					type = "select",
					name = L["Copy Settings From"],
					desc = L["Select a bar from which to copy settings"],
					get = false,
					set = copySettings,
					values = {["Target"] = L["Target"], ["Focus"] = L["Focus"], ["Pet"] = L["Pet"], ["Player"] = L["Player"]},
					order = 504
				}
			}
		}
		return options
	end
end

Quartz3.CastBarTemplate = {}
Quartz3.CastBarTemplate.defaults = {
	--x =  -- applied automatically in applySettings()
	y = 180,
	h = 25,
	w = 250,
	scale = 1,
	texture = "Blizzard",
	hideicon = false,
	alpha = 1,
	iconalpha = 0.9,
	iconposition = "left",
	icongap = 4,
	hidenametext = false,
	nametextposition = "left",
	timetextposition = "right",
	font = "Friz Quadrata TT",
	fontsize = 14,
	hidetimetext = false,
	hidecasttime = false,
	timefontsize = 12,
	targetname = false,
	spellrank = false,
	spellrankstyle = "roman",
	border = "Blizzard Tooltip",
	nametextx = 3,
	nametexty = 0,
	timetextx = 3,
	timetexty = 0,

	noInterruptBorderChange = false,
	noInterruptBorder = "Tooltip enlarged",
	noInterruptBorderColor = {0.71, 0.73, 0.71}, -- Default color chosen by playing around with settings, rounded to 2 significant digits
	noInterruptBorderAlpha = 1,
	noInterruptColorChange = false,
	noInterruptColor = {1.0, 0.49, 0},
	noInterruptShield = true,
}
Quartz3.CastBarTemplate.template = CastBarTemplate
Quartz3.CastBarTemplate.bars = {}
function Quartz3.CastBarTemplate:new(parent, unit, name, localizedName, config)
	local frameName = "Quartz3CastBar" .. name
	local bar = setmetatable(CreateFrame("Frame", frameName, UIParent), CastBarTemplate_MT)
	bar.unit = unit
	bar.parent = parent
	bar.config = config
	bar.modName = name
	bar.localizedName = localizedName
	bar.locked = true

	Quartz3.CastBarTemplate.bars[name] = bar

	bar:SetFrameStrata("MEDIUM")
	bar:SetScript("OnShow", OnShow)
	bar:SetScript("OnHide", OnHide)
	bar:SetScript("OnUpdate", OnUpdate)
	bar:SetScript("OnEvent", OnEvent)
	bar:SetMovable(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetClampedToScreen(true)

	bar.Bar      = CreateFrame("StatusBar", nil, bar)
	bar.Text     = bar.Bar:CreateFontString(nil, "OVERLAY")
	bar.TimeText = bar.Bar:CreateFontString(nil, "OVERLAY")
	bar.Icon     = bar.Bar:CreateTexture(nil, "DIALOG")
	bar.Spark    = bar.Bar:CreateTexture(nil, "OVERLAY")
	if unit ~= "player" then
		bar.Shield = bar.Bar:CreateTexture(nil, "ARTWORK")
		bar.Shield:SetTexture("Interface\\CastingBar\\UI-CastingBar-Small-Shield")
		bar.Shield:SetTexCoord(0, 36/256, 0, 1)
		bar.Shield:SetWidth(36)
		bar.Shield:SetHeight(64)
		bar.Shield:SetPoint("CENTER", bar.Icon, "CENTER", -2, -1)
		bar.Shield:Hide()
	end

	bar.lastNotInterruptible = false

	bar.backdrop = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	                 tile = true, tileSize = 16, edgeSize = 16, --edgeFile = "", -- set by ApplySettings
	                 insets = {left = 4, right = 4, top = 4, bottom = 4} }
	bar:Hide()

	return bar
end
