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
local Gratuity = AceLibrary("Gratuity-2.0")


local MODNAME = "Player"
local Player = Quartz3:NewModule(MODNAME)

----------------------------
-- Upvalues
-- GLOBALS: CastingBarFrame
local unpack = unpack
local getn = table.getn
local UnitChannelInfo = UnitChannelInfo

local db, getOptions, castBar

local defaults = {
	profile = Quartz3:Merge(Quartz3.CastBarTemplate.defaults,
	{
		hideblizz = true,
		showticks = true,
		-- no interrupt is pointless for player, disable all options
		noInterruptBorderChange = false,
		noInterruptColorChange = false,
		noInterruptShield = false,
	})
}

do 
	local function setOpt(info, value)
		db[info[getn(info)]] = value
		Player:ApplySettings()
	end

	local options
	function getOptions()
		if not options then
			options = Player.Bar:CreateOptions()
			options.args.hideblizz = {
				type = "toggle",
				name = L["Disable Blizzard Cast Bar"],
				desc = L["Disable and hide the default UI's casting bar"],
				set = setOpt,
				order = 101,
			}
			options.args.showticks = {
				type = "toggle",
				name = L["Show channeling ticks"],
				desc = L["Show damage / mana ticks while channeling spells like Drain Life or Blizzard"],
				order = 102,
			}
			options.args.targetname = {
				type = "toggle",
				name = L["Show Target Name"],
				desc = L["Display target name of spellcasts after spell name"],
				disabled = function() return db.hidenametext end,
				order = 402,
			}
			options.args.noInterruptGroup = nil
		end
		return options
	end
end
local channelingTicks
function Player:OnInitialize()
	self.db = Quartz3.db:RegisterNamespace(MODNAME, defaults)
	db = self.db.profile

	self:SetEnabledState(Quartz3:GetModuleEnabled(MODNAME))
	Quartz3:RegisterModuleOptions(MODNAME, getOptions, L["Player"])

	self.Bar = Quartz3.CastBarTemplate:new(self, "player", MODNAME, L["Player"], db)
	castBar = self.Bar.Bar

	
end


function Player:OnEnable()
	self.Bar:RegisterEvents()
	self:ApplySettings()
	channelingTicks = {
		-- warlock
		[SpellInfo(1120)] = 5, -- drain soul
		[SpellInfo(689)] = 5, -- drain life
		[SpellInfo(5138)] = 5, -- drain mana
		[SpellInfo(5740)] = 4, -- rain of fire
		-- druid
		[SpellInfo(740)] = 4, -- Tranquility
		[SpellInfo(16914)] = 10, -- Hurricane
		-- priest
		[SpellInfo(15407)] = 3, -- mind flay
		--[SpellInfo(48045)] = 5, -- mind sear
		--[SpellInfo(47540)] = 2, -- penance
		-- mage
		[SpellInfo(5143)] = 5, -- arcane missiles
		["T3" .. SpellInfo(5143)] = 6, -- t3 waist arcane missiles
		[SpellInfo(10)] = 5, -- blizzard
		[SpellInfo(12051)] = 4, -- evocation
		-- hunter
		[SpellInfo(1510)] = 6, -- volley
	} 
end

function Player:OnDisable()
	self.Bar:UnregisterEvents()
	self.Bar:Hide()
end

function Player:ApplySettings()
	db = self.db.profile
	
	-- obey the hideblizz setting no matter if disabled or not
	if db.hideblizz then
		CastingBarFrame.RegisterEvent = function() end
		CastingBarFrame:UnregisterAllEvents()
		CastingBarFrame:Hide()
	else
		CastingBarFrame.RegisterEvent = nil
		CastingBarFrame:UnregisterAllEvents()
		CastingBarFrame:RegisterEvent("SPELLCAST_START")
		CastingBarFrame:RegisterEvent("SPELLCAST_STOP")
		CastingBarFrame:RegisterEvent("SPELLCAST_INTERRUPTED")
		CastingBarFrame:RegisterEvent("SPELLCAST_FAILED")
		CastingBarFrame:RegisterEvent("SPELLCAST_DELAYED")
		CastingBarFrame:RegisterEvent("SPELLCAST_CHANNEL_START")
		CastingBarFrame:RegisterEvent("SPELLCAST_CHANNEL_STOP")
	end
	
	self.Bar:SetConfig(db)
	if self:IsEnabled() then
		self.Bar:ApplySettings()
	end
end

function Player:Unlock()
	self.Bar:Unlock()
end

function Player:Lock()
	self.Bar:Lock()
end

----------------------------
-- Cast Bar Hooks

function Player:OnHide()
	local Latency = Quartz3:GetModule(L["Latency"],true)
	if Latency then
		if Latency:IsEnabled() and Latency.lagbox then
			Latency.lagbox:Hide()
			Latency.lagtext:Hide()
		end
	end
end

local sparkfactory = {
	__index = function(t,k)
		local spark = castBar:CreateTexture(nil, 'OVERLAY')
		t[k] = spark
		spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
		spark:SetVertexColor(unpack(Quartz3.db.profile.sparkcolor))
		spark:SetBlendMode('ADD')
		spark:SetWidth(20)
		spark:SetHeight(db.h*2.2)
		return spark
	end
}
local barticks = setmetatable({}, sparkfactory)

local function setBarTicks(ticknum)
	if( ticknum and ticknum > 0) then
		local delta = ( db.w / ticknum )
		for k = 1,ticknum do
			local t = barticks[k]
			t:ClearAllPoints()
			t:SetPoint("CENTER", castBar, "LEFT", delta * k, 0 )
			t:Show()
		end
	else
		barticks[1].Hide = nil
		for i=1,getn(barticks) do
			barticks[i]:Hide()
		end
	end
end
local function checkMageT3Waist()
	local link = GetInventoryItemLink("player", 6)
	local _, _, link = string.find(link, "|c%x+|H(item:%d+:%d+:%d+:%d+)|h%[.-%]|h|r")
	Gratuity:SetHyperlink(link)
  local found = Gratuity:Find("duration of your Arcane Missiles",10,15,false,true,false)
	return found ~= nil
end

local function getChannelingTicks(spell)
	if not db.showticks then
		return 0
	end
	if spell == SpellInfo(5143) and checkMageT3Waist() then  -- Arcane Missiles
		spell = "T3" .. spell
	end
	return channelingTicks[spell] or 0
end

function Player:UNIT_SPELLCAST_START(bar, unit, spell)
	if bar.channeling then
		local spell = SpellInfo(spell.id)
		bar.channelingTicks = getChannelingTicks(spell)
		setBarTicks(bar.channelingTicks)
	else
		setBarTicks(0)
	end
end

function Player:UNIT_SPELLCAST_STOP(bar, unit)
	setBarTicks(0)
end

function Player:UNIT_SPELLCAST_FAILED(bar, unit)
	setBarTicks(0)
end

function Player:UNIT_SPELLCAST_INTERRUPTED(bar, unit)
	setBarTicks(0)
end

function Player:UNIT_SPELLCAST_DELAYED(bar, unit)

end
