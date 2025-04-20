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

local MODNAME = "Interrupt"
local Interrupt = Quartz3:NewModule(MODNAME, "AceEvent-3.0")
local Player = Quartz3:GetModule("Player")
local Target = Quartz3:GetModule("Target")
local Pet =  Quartz3:GetModule("Pet")

local db, getOptions

----------------------------
-- Upvalues
local GetTime = GetTime
local unpack = unpack
local SPELLINTERRUPTOTHERSELF, UNKNOWN = SPELLINTERRUPTOTHERSELF, UNKNOWN

local defaults = {
	profile = {
		interruptcolor = {0,0,0},
	},
}

local Interrupts = {
  ["Shield Bash"] = true;
  ["Pummel"] = true;
  ["Kick"] = true;
  ["Earth Shock"] = true;
  ["Concussion Blow"] = true;
  ["Charge Stun"] = true;
  ["Intercept Stun"] = true;
  ["Hammer of Justice"] = true;
  ["Cheap Shot"] = true;
  ["Gouge"] = true;
  ["Kidney Shot"] = true;
  ["Silence"] = true;
  ["Counterspell"] = true;
  ["Spell lock"] = true;
  ["Counterspell - Silenced"] = true;
  ["Bash"] = true;
  ["Fear"] = true;
  ["Howl of Terror"] = true;
  ["Psychic Scream"] = true;
  ["Intimidating Shout"] = true;
  ["Starfire Stun"] = true;
  ["Revenge Stun"] = true;
  ["Improved Concussive Shot"] = true;
  ["Impact"] = true;
  ["Pyroclasm"] = true;
  ["Blackout"] = true;
  ["Stun"] = true;
  ["Mace Stun Effect"] = true;
  ["Earthshaker"] = true;
  ["Repentance"] = true;
  ["Scatter Shot"] = true;
  ["Blind"] = true;
  ["Hibernate"] = true;
  ["Wyvern Sting"] = true;
  ["Rough Copper Bomb"] = true;
  ["Large Copper Bomb"] = true;
  ["Small Bronze Bomb"] = true;
  ["Big Bronze Bomb"] = true;
  ["Big Iron Bomb"] = true;
  ["Mithril Frag Bomb"] = true;
  ["Hi-Explosive Bomb"] = true;
  ["Dark Iron Bomb"] = true;
  ["Iron Grenade"] = true;
  ["M73 Frag Grenade"] = true;
  ["Thorium Grenade"] = true;
  ["Goblin Mortar"] = true;
  ["Polymorph"] = true;
}

function Interrupt:OnInitialize()
	self.db = Quartz3.db:RegisterNamespace(MODNAME, defaults)
	db = self.db.profile
	
	self:SetEnabledState(Quartz3:GetModuleEnabled(MODNAME))
	Quartz3:RegisterModuleOptions(MODNAME, getOptions, L["Interrupt"])
end

function Interrupt:OnEnable()
	self:RegisterEvent("UNIT_CASTEVENT")
end

function Interrupt:ApplySettings()
	db = self.db.profile
end

function Interrupt:UNIT_CASTEVENT()
	local caster, target, eventType, spellId, start, duration = arg1, arg2, arg3, arg4, GetTime(), arg5 / 1000
--	printT({"Interrupt:UNIT_CASTEVENT",caster, target, eventType, spellId})
	if eventType == "CAST" then
		local spell = SpellInfo(spellId)
		if (Interrupts[spell] ~= nil ) then
			local unit = Quartz3:GetUnitFromGuid(target)
			local bar
	--		printT({unit,spell})
			if unit == "player" then 
				bar = Player.Bar
			elseif unit == "target" then
				bar = Target.Bar
			elseif unit == "pet" then
				bar = Pet.Bar
			else
				return
			end
			local sourceName = UnitName(caster)
			bar.Text:SetText(format(L["INTERRUPTED (%s)"], sourceName or UNKNOWN))
			bar.Bar:SetStatusBarColor(unpack(db.interruptcolor))
			bar.stopTime = GetTime()
		end
	end
end

do
	local options
	function getOptions()
		options = options or {
		type = "group",
		name = L["Interrupt"],
		order = 600,
		args = {
			toggle = {
				type = "toggle",
				name = L["Enable"],
				get = function()
					return Quartz3:GetModuleEnabled(MODNAME)
				end,
				set = function(info, v)
					Quartz3:SetModuleEnabled(MODNAME, v)
				end,
				order = 100,
			},
			interruptcolor = {
				type = "color",
				name = L["Interrupt Color"],
				desc = L["Set the color the cast bar is changed to when you have a spell interrupted"],
				set = function(info, ...)
					db.interruptcolor = {unpack(arg)}
				end,
				get = function()
					return unpack(db.interruptcolor)
				end,
				order = 101,
			},
		},
	}
	return options
	end
end
