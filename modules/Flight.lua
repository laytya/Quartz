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

local MODNAME = "Flight"
local Flight = Quartz3:NewModule(MODNAME, "AceHook-3.0", "AceEvent-3.0")
local Player = Quartz3:GetModule("Player")

----------------------------
-- Upvalues
local GetTime = GetTime
local unpack = unpack
local TimeFmt, RomanFmt = Quartz3.Util.TimeFormat, Quartz3.Util.ConvertRankToRomanNumeral

local db, getOptions
local FlightMapX, FlightMapY = 0,0
local started
local defaults = {
	profile = {
		color = {0.7, 1, 0.7},
		deplete = false,
		},
	}

do
	local options
	function getOptions() 
	options = options or {
		type = "group",
		name = L["Flight"],
		order = 600,
		args = {
			header = {
				type = 'header',
				name = '|cffff0000This module will work only if you have FlightMap addon.|r',
				order =3,
			},
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
			color = {
				type = "color",
				name = L["Flight Map Color"],
				desc = L["Set the color to turn the cast bar when taking a flight path"],
				get = function() return unpack(db.color) end,
				set = function(info, ...) db.color = {unpack(arg)} end,
				order = 101,
			},
			deplete = {
				type = "toggle",
				name = L["Deplete"],
				desc = L["Deplete"],
				get = function() return db.deplete end,
				set = function(info, v) db.deplete = v end,
				order = 102,
			},
		},
	}
	return options
	end
end

function Flight:OnInitialize()
	self.db = Quartz3.db:RegisterNamespace(MODNAME, defaults)
	db = self.db.profile
	
	self:SetEnabledState(Quartz3:GetModuleEnabled(MODNAME))
	Quartz3:RegisterModuleOptions(MODNAME, getOptions, L["Flight"])

end

function Flight:ApplySettings()
	db = self.db.profile
end

	function Flight:OnEnable()
	if (FlightMapFrame) then
		self:RawHook('TakeTaxiNode')
		
	end
	end

function Flight:OnDisable()
	self:UnHook('TakeTaxiNode')
	if FlightMapTimesFrame then
		if FlightMapX and FlightMapY then
      FlightMapTimesFrame:ClearAllPoints()
      FlightMapTimesFrame:SetPoint("BOTTOMLEFT", "UIParent", "BOTTOMLEFT", FlightMapX, FlightMapY )
    end
	end
end

function Flight:TakeTaxiNode(id)
	self.hooks.TakeTaxiNode(id)
	if (FlightMapTimesFrame) then
  	if (FlightMapTimesFrame:IsVisible()) then
        local duration = nil
        if (FlightMapTimesFrame.endTime ~= nil) then
          duration = (FlightMapTimesFrame.endTime - FlightMapTimesFrame.startTime)
        end
				self:BeginFlight(duration, FlightMapTimesFrame.endPoint)
		
        -- store the flight map position
        FlightMapX = FlightMapTimesFrame:GetLeft()
        FlightMapY = FlightMapTimesFrame:GetBottom()

        -- now move the frame off the screen
        FlightMapTimesFrame:ClearAllPoints()
        FlightMapTimesFrame:SetPoint("BOTTOMLEFT", "UIParent", "BOTTOMLEFT", -4000, 4000 )
  	end
	end
	end

function Flight:OnUpdate(frame)
	if (not started) then
		if UnitOnTaxi("player") then started = true; end
		return;
		end
	local currentTime = GetTime()
	if not UnitOnTaxi("player") then
		
		Player.Bar.fadeOut = true
		Player.Bar.stopTime = currentTime
		Player.Bar.endTime = currentTime
		Player.Bar.Bar:SetValue(1)
		Player.Bar.Bar:SetMinMaxValues(0, 1)
		
		Flight.hooks[Player.Bar].OnUpdate(frame)
		Flight:Unhook(Player.Bar, 'OnUpdate')
	end
	Player.Bar.TimeText:SetText(format(TimeFmt(currentTime - Player.Bar.startTime)))
end

function Flight:BeginFlight(duration, destination)
	started = false
	
	Player.Bar.casting = true
	local currentTime = GetTime()
	Player.Bar.startTime = currentTime
	
	Player.Bar.delay = 0
	Player.Bar.fadeOut = nil
	if db.deplete then
		Player.Bar.casting = nil
		Player.Bar.channeling = true
	else
		Player.Bar.casting = true
		Player.Bar.channeling = nil
	end
	
	Player.Bar.Bar:SetStatusBarColor(unpack(db.color))
	Player.Bar.Icon:SetTexture("Interface/Icons/Ability_Hunter_EagleEye")
	Player.Bar.Text:SetText(destination)
	
	local position = Player.db.profile.timetextposition
	
	if position == "caststart" then
        Player.Bar.TimeText:SetPoint("LEFT", Player.Bar.Bar, "LEFT", Player.db.profile.timetextx,
            Player.db.profile.timetexty)
		Player.Bar.TimeText:SetJustifyH("LEFT")
	elseif position == "castend" then
        Player.Bar.TimeText:SetPoint("RIGHT", Player.Bar.Bar, "RIGHT", -1 * Player.db.profile.timetextx,
            Player.db.profile.timetexty)
		Player.Bar.TimeText:SetJustifyH("RIGHT")
	end
	Player.Bar:SetAlpha(Player.db.profile.alpha)

	if not duration then
		Player.Bar.Bar:SetValue(1)
		Player.Bar.Spark:Hide()
		duration = 0
		self:RawHookScript(Player.Bar, 'OnUpdate')
	else
		Player.Bar.Bar:SetValue(0)
		Player.Bar.Spark:Show()
	end
    Player.Bar.endTime = currentTime + duration
	Player.Bar:Show()

end
