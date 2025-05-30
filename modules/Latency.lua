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

local MODNAME = "Latency"
local Latency = Quartz3:NewModule(MODNAME, "AceEvent-3.0", "AceHook-3.0")
local Player = Quartz3:GetModule("Player")

local media = LibStub("LibSharedMedia-3.0")
local lsmlist = AceGUIWidgetLSMlists

----------------------------
-- Upvalues
local GetTime = GetTime
local unpack = unpack
local getn, format = table.getn, string.format
local UnitIsUnit = UnitIsUnit

local lagbox, lagtext, db, timeDiff, sendTime, alignoutside
timeDiff = 0
local getOptions
local dontCatch = false
local defaults = {
	profile = {
		lagcolor = {1, 0, 0},
		lagalpha = 0.6,
		lagtext = true,
		lagfont = "Friz Quadrata TT",
		lagfontsize = 7,
		lagtextcolor = {0.7, 0.7, 0.7, 0.8},
		lagtextalignment = "center", -- L["Left"], L["Right"]
		lagtextposition = "bottom", --L["Top"], L["Above"], L["Below"]
		
		-- With "embed", the lag indicator is placed on the left hand side of the bar instead of right for normal casting 
		-- and the castbar time is shifted so that the end of the time accounting for lag lines up with the right hand side of the castbar
		-- For channeled spells, the lag indicator is shown on the right, and the cast bar is adjusted down from there 
		-- lagpadding is applied only if lagembed is enabled
		lagembed = false,
		lagpadding = 0.0,
	}
}

function Latency:OnInitialize()
	self.db = Quartz3.db:RegisterNamespace(MODNAME, defaults)
	db = self.db.profile
	
	self:SetEnabledState(Quartz3:GetModuleEnabled(MODNAME))
	Quartz3:RegisterModuleOptions(MODNAME, getOptions, L["Latency"])
end

local function saveTime()
	if not SpellIsTargeting() then
		sendTime = GetTime()
	else
		sendTime = nil
	end
	
end

function Latency:OnEnable()
	self:RawHook(Player, "UNIT_SPELLCAST_START")
	self:RawHook(Player, "UNIT_SPELLCAST_DELAYED")

	self:RegisterEvent("UNIT_CASTEVENT")
	self:RegisterEvent("SPELLCAST_CHANNEL_STOP")
	

	self:SecureHook("CastSpellByName", saveTime )
	self:SecureHook("CastSpell", saveTime)
	self:SecureHook("UseAction", saveTime)
	self:SecureHook("UseContainerItem", saveTime)
	self:SecureHook("UseInventoryItem", saveTime)
	self:SecureHook("DoTradeSkill", saveTime)
	self:SecureHook("DoCraft", saveTime)
	self:HookScript(WorldFrame, "OnMouseDown", 'WorldFrame_OnMouseDown')

	media.RegisterCallback(self, "LibSharedMedia_SetGlobal", function(mtype, override)
		if mtype == "statusbar" then
			lagbox:SetTexture(media:Fetch("statusbar", override))
		end
	end)
	if not lagbox then
		lagbox = Player.Bar.Bar:CreateTexture(nil, "BACKGROUND")
		lagtext = Player.Bar.Bar:CreateFontString(nil, "OVERLAY")
		self.lagbox = lagbox
		self.lagtext = lagtext
	end
	self:ApplySettings()
end

function Latency:OnDisable()
	media.UnregisterCallback(self, "LibSharedMedia_SetGlobal")
	lagbox:Hide()
	lagtext:Hide()
end
--[[


function Latency:CastSpellByName(pass, onSelf)
		
end

function Latency:CastSpell(pass, onSelf)
	sendTime = GetTime()	
end

function Latency:UseAction(pass, cursor, onSelf)
	sendTime = GetTime()	
end

function Latency:UseContainerItem(id, index)
	sendTime = GetTime()
end

function Latency:UseInventoryItem(id, index)
	sendTime = GetTime()
end

function Latency:DoTradeSkill(id, index)
	sendTime = GetTime()
end

function Latency:DoCraft(id, index)
	sendTime = nil
end
]]
function Latency:WorldFrame_OnMouseDown()
	saveTime()
end

local gatherSpells = {
	[22810] =  true, -- world objects
	[2366] = true, -- herbalism
	[3365] = true, -- chests
	[2575] = true, -- mining
	[6478] = true, -- opening
	[6477] = true,
	[5206] = true, -- plant seeds
	[5316] =  true,
	[13262] =true,
	[7418] = true,
}

function Latency:UNIT_SPELLCAST_START(object, bar, unit, spell)
	self.hooks[object].UNIT_SPELLCAST_START(object, bar, unit, spell)
	
	
	-- if gatherSpells[spell.id] then return end -- Open world object

	local startTime, endTime = bar.startTime, bar.endTime
	if not sendTime or not endTime then return end
	
	timeDiff = GetTime() - sendTime
	local castlength = endTime - startTime
	timeDiff = timeDiff > castlength and castlength or timeDiff
	local perc = timeDiff / castlength
	
	lagbox:ClearAllPoints()
	local side
	if db.lagembed then
		if bar.casting then
			side = "LEFT"
			lagbox:SetTexCoord(0,perc,0,1)
		else -- channeling
			side = "RIGHT"
			lagbox:SetTexCoord(1-perc,1,0,1)
		end
		
		startTime = startTime - timeDiff + db.lagpadding
		bar.startTime = startTime
		endTime = endTime - timeDiff + db.lagpadding
		bar.endTime = endTime
	else
		if bar.casting then
			side = "RIGHT"
			lagbox:SetTexCoord(1-perc,1,0,1)
		else -- channeling
			side = "LEFT"
			lagbox:SetTexCoord(perc,1,0,1)
		end
	end
	lagbox:SetDrawLayer(side == "LEFT" and "OVERLAY" or "BACKGROUND")
	lagbox:SetPoint(side, Player.Bar.Bar, side)
	lagbox:SetWidth(Player.db.profile.w * perc)
	lagbox:Show()
	
	if db.lagtext then
		if alignoutside then
			lagtext:SetJustifyH(side)
			lagtext:ClearAllPoints()
			local lagtextposition = db.lagtextposition
			local point, relpoint
			if lagtextposition == "bottom" then
				point = "BOTTOM"
				relpoint = "BOTTOM"
			elseif lagtextposition == "top" then
				point = "TOP"
				relpoint = "TOP"
			elseif lagtextposition == "above" then
				point = "BOTTOM"
				relpoint = "TOP"
			else --L["Below"]
				point = "TOP"
				relpoint = "BOTTOM"
			end
			if side == "LEFT" then
				lagtext:SetPoint(point.."LEFT", lagbox, relpoint.."LEFT", 1, 0)
			else
				lagtext:SetPoint(point.."RIGHT", lagbox, relpoint.."RIGHT", -1, 0)
			end
		end
		lagtext:SetText(format(L["%dms"], timeDiff*1000))
		lagtext:Show()
	else
		lagtext:Hide()
	end

	sendTime = nil

end

function Latency:UNIT_SPELLCAST_DELAYED(object, bar, unit, delay)
	--print("UNIT_SPELLCAST_DELAYED",object, bar, unit, delay)
	self.hooks[object].UNIT_SPELLCAST_DELAYED(object, bar, unit, delay)

	if db.lagembed then
		local startTime = bar.startTime - timeDiff + db.lagpadding
		bar.startTime = startTime
		local endTime = bar.endTime - timeDiff + db.lagpadding
		bar.endTime = endTime
	end
end

function Latency:UNIT_CASTEVENT()
	--local caster, target, eventType, spellId, start, duration = arg1, arg2, arg3, arg4, GetTime(), arg5 / 1000
	
	if not UnitIsUnit(arg1,"player") then return end
	
	if eventType == "FAIL" or  (eventType == "CAST" and Player.Bar.casting) then
		lagbox:Hide()
		lagtext:Hide()
		sendTime = nil
	end
end

function Latency:SPELLCAST_CHANNEL_STOP(s,d)
	lagbox:Hide()
	lagtext:Hide()
	sendTime = nil
end

--[[
function Latency:UNIT_SPELLCAST_INTERRUPTED(event, unit)
	if unit ~= "player" and unit ~= "vehicle" then
		return
	end
	lagbox:Hide()
	lagtext:Hide()
end
]]
function Latency:ApplySettings()
	db = self.db.profile
	if lagbox and self:IsEnabled() then
		lagbox:SetHeight(Player.Bar.Bar:GetHeight())
		lagbox:SetTexture(media:Fetch("statusbar", Player.db.profile.texture))
		lagbox:SetAlpha(db.lagalpha)
		lagbox:SetVertexColor(unpack(db.lagcolor))
		
		lagtext:SetFont(media:Fetch("font", db.lagfont), db.lagfontsize)
		lagtext:SetShadowColor( 0, 0, 0, 1)
		lagtext:SetShadowOffset( 0.8, -0.8 )
		lagtext:SetTextColor(unpack(db.lagtextcolor))
		lagtext:SetNonSpaceWrap(false)
		
		local lagtextposition = db.lagtextposition
		local point, relpoint
		if lagtextposition == "bottom" then
			point = "BOTTOM"
			relpoint = "BOTTOM"
		elseif lagtextposition == "top" then
			point = "TOP"
			relpoint = "TOP"
		elseif lagtextposition == "above" then
			point = "BOTTOM"
			relpoint = "TOP"
		else --L["Below"]
			point = "TOP"
			relpoint = "BOTTOM"
		end
		local lagtextalignment = db.lagtextalignment
		if lagtextalignment == "center" then
			lagtext:SetJustifyH("CENTER")
			lagtext:ClearAllPoints()
			lagtext:SetPoint(point, lagbox, relpoint)
			alignoutside = false
		elseif lagtextalignment == "right" then
			lagtext:SetJustifyH("RIGHT")
			lagtext:ClearAllPoints()
			lagtext:SetPoint(point.."RIGHT", lagbox, relpoint.."RIGHT", -1, 0)
			alignoutside = false
		elseif lagtextalignment == "left" then
			lagtext:SetJustifyH("LEFT")
			lagtext:ClearAllPoints()
			lagtext:SetPoint(point.."LEFT", lagbox, relpoint.."LEFT", 1, 0)
			alignoutside = false
		else -- ["Outside"] is set on cast start
			alignoutside = true
		end
	end
end

do
	local function hidelagtextoptions()
		return not db.lagtext
	end

	local function setOpt(info, value)
		db[info[getn(info)]] = value
		Latency:ApplySettings()
	end

	local function getOpt(info)
		return db[info[getn(info)]]
	end

	local function getColor(info)
		return unpack(getOpt(info))
	end

	local function setColor(info, r, g, b, a)
		setOpt(info, {r, g, b, a})
	end

	local options
	function getOptions()
		if not options then
			options = {
				type = "group",
				name = L["Latency"],
				order = 600,
				get = getOpt,
				set = setOpt,
				args = {
					toggle = {
						type = "toggle",
						name = L["Enable"],
						desc = L["Enable"],
						get = function()
							return Quartz3:GetModuleEnabled(MODNAME)
						end,
						set = function(info, v)
							Quartz3:SetModuleEnabled(MODNAME, v)
						end,
						order = 100,
					},
					lagembed = {
						type = "toggle",
						name = L["Embed"],
						desc = L["Include Latency time in the displayed cast bar."],
						order = 101,
					},
					lagalpha ={
						type = "range",
						name = L["Alpha"],
						desc = L["Set the alpha of the latency bar"],
						min = 0.05, max = 1, bigStep = 0.05,
						isPercent = true,
						order = 102,
					},
					lagpadding = {
						type = "range",
						name = L["Embed Safety Margin"],
						desc = L["Embed mode will decrease it's lag estimates by this amount.  Ideally, set it to the difference between your highest and lowest ping amounts.  (ie, if your ping varies from 200ms to 400ms, set it to 0.2)"],
						min = 0, max = 1, bigStep = 0.05,
						disabled = function()
							return not db.lagembed
						end,
						order = 103,
					},
					lagcolor = {
						type = "color",
						name = L["Bar Color"],
						desc = format(L["Set the color of the %s"],L["Latency Bar"]),
						get = getColor,
						set = setColor,
						order = 111,
					},
					header = {
						type = "header",
						name = L["Font and Text"],
						order = 113,
					},
					lagtext = {
						type = "toggle",
						name = L["Show Text"],
						desc = L["Display the latency time as a number on the latency bar"],
						order = 114,
					},
					lagtextcolor = {
						type = "color",
						name = L["Text Color"],
						desc = L["Set the color of the latency text"],
						get = getColor,
						set = setColor,
						disabled = hidelagtextoptions,
						hasAlpha = true,
						order = 115,
					},
					lagfont = {
						type = "select",
						dialogControl = "LSM30_Font",
						name = L["Font"],
						desc = L["Set the font used for the latency text"],
						values = lsmlist.font,
						disabled = hidelagtextoptions,
						order = 116,
					},
					lagfontsize = {
						type = "range",
						name = L["Font Size"],
						desc = L["Set the size of the latency text"],
						min = 3, max = 15, step = 1,
						disabled = hidelagtextoptions,
						order = 117,
					},
					lagtextalignment = {
						type = "select",
						name = L["Text Alignment"],
						desc = L["Set the position of the latency text"],
						values = {["center"] = L["Center"], ["left"] = L["Left"], ["right"] = L["Right"], ["outside"] = L["Outside"]},
						disabled = hidelagtextoptions,
						order = 118,
					},
					lagtextposition = {
						type = "select",
						name = L["Text Position"],
						desc = L["Set the vertical position of the latency text"],
						values = {["above"] = L["Above"], ["top"] = L["Top"], ["bottom"] = L["Bottom"], ["below"] = L["Below"]},
						disabled = hidelagtextoptions,
						order = 119,
					},
				},
			}
		end
		return options
	end
end
