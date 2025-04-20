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

local MODNAME = "Tradeskill"
local Tradeskill = Quartz3:NewModule(MODNAME, "AceEvent-3.0", "AceHook-3.0")
local Player = Quartz3:GetModule("Player")

local TimeFmt = Quartz3.Util.TimeFormat

----------------------------
-- Upvalues
local GetTime, UnitCastingInfo = GetTime, UnitCastingInfo
local unpack, tonumber, format = unpack, tonumber, format
local getn, format = table.getn, string.format

local getOptions

local castBar, castBarText, castBarTimeText, castBarIcon, castBarSpark, castBarParent

local repeattimes, castname, duration, totaltime, starttime, casting, bail
local completedcasts = 0
local restartdelay = 1
local tradeSkill = nil
local recast, waitRecast = 0, GetTime()

local function tradeskillOnUpdate()
	local currentTime = GetTime()
	if casting then
		if (repeattimes > 1 ) and (currentTime - (waitRecast + duration)) > 0.5 then
			bail =  true
			casting  = false
			tradeSkill = false
		end
		local elapsed = duration * completedcasts + currentTime - starttime
		castBar:SetValue(elapsed)
		
		local perc = (currentTime - starttime) / duration
		castBarSpark:ClearAllPoints()
		castBarSpark:SetPoint("CENTER", castBar, "LEFT", perc * Player.db.profile.w, 0)
		
		if Player.db.profile.hidecasttime then
			castBarTimeText:SetText(format(TimeFmt(totaltime - elapsed)))
		else
			castBarTimeText:SetText(format("%s / %s", format(TimeFmt(totaltime - elapsed)), format(TimeFmt(totaltime))))
		end
	else
		if (starttime + duration + restartdelay < currentTime) or (completedcasts >= (repeattimes - 1) ) or bail or completedcasts == 0 then
			Player.Bar.fadeOut = true
			Player.Bar.stopTime = currentTime
			Player.Bar.endTime = currentTime
			castBar:SetValue(duration * repeattimes)
			castBarTimeText:SetText("")
			castBarSpark:Hide()
			if bail then castBar:SetStatusBarColor(unpack(Quartz3.db.profile.failcolor)) end
			castBarParent:SetScript("OnUpdate", Player.Bar.OnUpdate)
			castBar:SetMinMaxValues(0, 1)
		else
			local elapsed = duration * (completedcasts + 1)
			castBar:SetValue(elapsed)
			if (repeattimes > 1 ) and (currentTime - (waitRecast + duration)) > 0.5 then
				bail =  true
				tradeSkill = false
			end
			castBarSpark:ClearAllPoints()
			castBarSpark:SetPoint("CENTER", castBar, "LEFT", Player.db.profile.w, 0)
			
			if Player.db.profile.hidecasttime then
				castBarTimeText:SetText(format(TimeFmt(totaltime - elapsed)))
			else
				castBarTimeText:SetText(format("%s / %s", format(TimeFmt(totaltime - elapsed)), format(TimeFmt(totaltime))))
			end
		end
	end
end

function Tradeskill:OnInitialize()
	self:SetEnabledState(Quartz3:GetModuleEnabled(MODNAME))
	Quartz3:RegisterModuleOptions(MODNAME, getOptions, L["Tradeskill Merge"])
end


function Tradeskill:OnEnable()
	self:RawHook(Player, "UNIT_SPELLCAST_START")
	self:RawHook(Player.Bar, "UNIT_SPELLCAST_STOP")
	--self:RegisterEvent("SPELLCAST_STOP")
	self:RegisterEvent("SPELLCAST_CHANNEL_STOP")
	self:RegisterEvent("SPELLCAST_INTERRUPTED")
	self:RegisterEvent("UPDATE_TRADESKILL_RECAST")
	
	self:Hook("DoTradeSkill", true)
	--self:SecureHook("UIErrorsFrame_OnEvent")
end

function Tradeskill:UNIT_SPELLCAST_START(object, event, unit, spell)
	if unit ~= "player" then
		return self.hooks[object].UNIT_SPELLCAST_START(object, event, unit, spell)
	end
	local spellName, _, icon = SpellInfo(spell.id)

	local displayName = spellName
	if tradeSkill then --or isTradeskill print
		repeattimes = repeattimes or 1
		if repeattimes > 1 then
			waitRecast = GetTime()
			completedcasts = completedcasts + recast
			recast = 0
		end
		if completedcasts == -1 then
			completedcasts = 0 
		end
		
		duration = (spell.endTime - spell.startTime)
		totaltime = duration * (repeattimes or 1)
		starttime = GetTime()
		casting = true
		Player.Bar.fadeOut = nil
		castname = spell
		bail = nil
		Player.Bar.endTime = nil
		
		castBar:SetStatusBarColor(unpack(Quartz3.db.profile.castingcolor))
		castBar:SetMinMaxValues(0, totaltime)
		
		castBar:SetValue(0)
		castBarParent:Show()
		castBarParent:SetScript("OnUpdate", tradeskillOnUpdate)
		castBarParent:SetAlpha(Player.db.profile.alpha)
		
		local numleft = repeattimes - completedcasts
		if numleft <= 1 then
			castBarText:SetText(displayName)
		else
			castBarText:SetText(format("%s (%s)", displayName, numleft))
		end
		castBarSpark:Show()
		castBarIcon:SetTexture(icon)
	else
		castBar:SetMinMaxValues(0, 1)
		return self.hooks[object].UNIT_SPELLCAST_START(object, event, unit, spell)
	end
end

function Tradeskill:UNIT_SPELLCAST_STOP(object, event, unit)
	if unit ~= "player" then
		return self.hooks[object].UNIT_SPELLCAST_STOP(object, event, unit)
	end
	--print("Tradeskill:UNIT_SPELLCAST_STOP")
	--self.hooks[object].UNIT_SPELLCAST_STOP(object, event, unit)
	--print( casting , repeattimes , completedcasts )
	if casting and repeattimes and completedcasts then
		if  repeattimes - completedcasts < 2 then 
	casting = false
			tradeSkill =  false
			self.hooks[object].UNIT_SPELLCAST_STOP(object, event, unit)
		end
	else
		self.hooks[object].UNIT_SPELLCAST_STOP(object, event, unit) 
	end
end
--[[
function Tradeskill:UIErrorsFrame_OnEvent(event, message, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
	--print("UIErrorsFrame_OnEvent",event, message, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
	if tradeSkill then

		if message and ( message == L["Interrupted"] 
		or message == INVENTORY_FULL
		or (string.find(message, string.sub(SPELL_FAILED_REAGENTS, 1, string.len(SPELL_FAILED_REAGENTS)-2), 1, true) ~= nil)
		or (string.find(message, string.sub(SPELL_FAILED_REQUIRES_SPELL_FOCUS,1,string.len(SPELL_FAILED_REQUIRES_SPELL_FOCUS)-4), 1, true) ~= nil))
		then
			Tradeskill:SPELLCAST_STOP()
			Tradeskill:SPELLCAST_INTERRUPTED()
		end
	end
end
]]
function Tradeskill:SPELLCAST_STOP()
	--print("SPELLCAST_STOP")
	if repeattimes and completedcasts and (repeattimes - completedcasts < 1) then 
		casting = false
		tradeSkill =  false
	end
end
Tradeskill.SPELLCAST_CHANNEL_STOP = Tradeskill.SPELLCAST_STOP

function Tradeskill:UPDATE_TRADESKILL_RECAST()
	--print("UPDATE_TRADESKILL_RECAST")
	recast =  1
	end

function Tradeskill:SPELLCAST_INTERRUPTED()
	bail = true
	casting = false
	tradeSkill = false
end

function Tradeskill:DoTradeSkill(index, num)
	tradeSkill =  true
	completedcasts = -1
	repeattimes = tonumber(num) or 1
end

function Tradeskill:ApplySettings()
	castBarParent = Player.Bar
	castBar = Player.Bar.Bar
	castBarText = Player.Bar.Text
	castBarTimeText = Player.Bar.TimeText
	castBarIcon = Player.Bar.Icon
	castBarSpark = Player.Bar.Spark
end

do
	local options
	function getOptions()
		if not options then
			options = {
				type = "group",
				name = L["Tradeskill Merge"],
				order = 600,
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
					},
				},
			}
		end
		return options
	end
end
