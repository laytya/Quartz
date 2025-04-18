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

local MODNAME = "Swing"
local Swing = Quartz3:NewModule(MODNAME, "AceEvent-3.0")
local Player = Quartz3:GetModule("Player")

local media = LibStub("LibSharedMedia-3.0")
local lsmlist = AceGUIWidgetLSMlists

----------------------------
-- Upvalues
local CreateFrame, GetTime, UIParent = CreateFrame, GetTime, UIParent
local UnitClass, UnitDamage, UnitAttackSpeed, UnitRangedDamage = UnitClass, UnitDamage, UnitAttackSpeed, UnitRangedDamage
local math_abs, bit_band, unpack = math.abs, bit.band, unpack
local COMBATLOG_FILTER_ME = COMBATLOG_FILTER_ME

local getn, format = table.getn, string.format

local playerclass, playerGuid
local autoshotname = SpellInfo(75)
local slam = SpellInfo(1464)
local swordprocname = SpellInfo(12281) --??
local resetspells 

local resetautoshotspells = {
	--[GetSpellInfo(19434)] = true, -- Aimed Shot
}

local swingbar, swingbar_width, swingstatusbar, remainingtext, durationtext, combat
swingbar = {}
local swingmode -- nil is none, 0 is meleeing, 1 is autoshooting
local timer, duration = {}, {}
local slamstart
local MAINHAND, OFFHAND, RANGED = 1, 2, 3
local rangeSlot = nil
local db, getOptions
local range_fader = 0
local flurry_fresh = nil
local flurry_count = -1

local defaults = {
	profile = {
		barcolor = {1, 1, 1},
		outrangecolor = {1, 0, 0},
		swingalpha = 1,
		swingheight = 4,
		swingposition = "top",
		swinggap = -4,
		
		durationtext = true,
		remainingtext = true,
		
		x = 300,
		y = 300,
	}
}

local function getWeaponSpeed(slot)
	local speedMH, speedOH = UnitAttackSpeed("player")
	if slot == offHand then
		return speedOH
	elseif slot == ranged then
		local rangedAttackSpeed = UnitRangedDamage("player")
		return rangedAttackSpeed
	else
		return speedMH
	end
end

local function isDualWield()
	return (getWeaponSpeed(offHand) ~= nil)
end

local function hasRanged()
	return (GetWeaponSpeed(ranged) ~= nil)
end



	local instants = {
		[53] = true, --["Backstab"] = 1,
		[1752] = true, --["Sinister Strike"] = 1,
		[1766] = true, --["Kick"] = 1,
		[8647] = true, --["Expose Armor"] = 1,
		[2098] = true, --["Eviscerate"] = 1,
		[1943] = true, --["Rupture"] = 1,
		[8676] = true, --	["Ambush"] = 1,
		[1776] = true, --["Gouge"] = 1,
		[1966] = true, --["Feint"] = 1,
		[16511] = true, --["Hemorrhage"] = 1,
		[703] = true, --["Garrote"] = 1,

		[1715] = true, --["Hamstring"] = 1,
		[7386] = true, --["Sunder Armor"] = 1,
		[13331] = true, --["Bloodthirst"] = 1,
		[9347] = true, --["Mortal Strike"] = 1,
		[8242] = true, --["Shield Slam"] = 1,
		[7384] = true, --["Overpower"] = 1,
		[6572] = true, --["Revenge"] = 1,
		[6552] = true, --["Pummel"] = 1,
		[72] = true, --["Shield Bash"] = 1,
		[676] = true, --["Disarm"] = 1,
		[5283] = true, --["Execute"] = 1,
		[355] = true, --["Taunt"] = 1,
		[694] = true, --["Mocking Blow"] = 1,
		[1464] = true, --["Slam"] = 1,
		[772] = true, --["Rend"] = 1,

		[8824] = true, --["Crusader Strike"] = 1,
		[678] = true, --["Holy Strike"] = 1,

		[17364] = true, --["Stormstrike"] = 1, 
		[16614] = true, --["Lightning Strike"] = 1, 

		[45736] = true, --["Savage Bite"] = 1,
		[1853] = true, --["Growl"] = 1,
		[5211] = true, --["Bash"] = 1,
		[769] = true, --["Swipe"] = 1,
		[1082] = true, --["Claw"] = 1,
		[1079] = true, --["Rip"] = 1,
		[22557] = true, --["Ferocious Bite"] = 1,
		[3252] = true, --["Shred"] = 1,
		[1822] = true, --["Rake"] = 1,
		[1742] = true, --["Cower"] = 1,
		[3242] = true, --["Ravage"] = 1,
		[9005] = true, --["Pounce"] = 1,

		[2974] = true, --["Wing Clip"] = 1,
		[781] = true, --["Disengage"] = 1,
		[51575] = true, --["Carve"] = 1, -- twow

	}

	local function findRangeAction()
		rangeSlot = nil
		for  k,v in pairs(instants) do
			rangeSlot = Quartz3.getSlot(k)
			if rangeSlot then
				break
			end
		end
	end


local function inRange()
	-- if the slot is nil anyway then there's no sense being red all the time

		return rangeSlot == nil or IsActionInRange(rangeSlot) == 1
	
end

local function ResetTimer(slot)
	local speed =  getWeaponSpeed(slot)
	timer[slot], duration[slot] = speed, speed
	if  slot == RANGED then
		range_fader = GetTime()
	end
	swingbar[slot].swingstatusbar:SetValue(1)
	swingbar[slot].durationtext:SetText(format("%.1f", duration[slot]))
	swingbar[slot]:Show()
end


local function OnUpdate()

	local slot = this.slot
	if timer[slot] and timer[slot] > 0 then
		timer[slot] = timer[slot] - arg1
		--if timer[slot] < 0 then timer[slot] = 0 end
		this.remainingtext:SetText(format("%.1f", timer[slot]))
		this.durationtext:SetText(format("%.1f", duration[slot]))
		local perc = (duration[slot] - timer[slot] )/ duration[slot]
		this.swingstatusbar:SetValue(perc)
	end
	if not combat  then
		this:Hide()
	end
	this.elapsed  = this.elapsed  + arg1
	if this.elapsed  >= 0.03 then
		if (slot == 1 or slot == 2) then
			if inRange() then
				this.swingstatusbar:SetStatusBarColor(unpack(db.barcolor))
			else
				this.swingstatusbar:SetStatusBarColor(unpack(db.outrangecolor))
			end
		else
			if CheckInteractDistance("target",4) then
				this.swingstatusbar:SetStatusBarColor(unpack(db.barcolor))
		else
				this.swingstatusbar:SetStatusBarColor(unpack(db.outrangecolor))
			end
		end
		this.elapsed = 0 
	end

end

local function OnHide()
	this:SetScript("OnUpdate", nil)
end

local function OnShow()
	this.elapsed = 0
	this:SetScript("OnUpdate", OnUpdate)
end

function Swing:OnInitialize()
	self.db = Quartz3.db:RegisterNamespace(MODNAME, defaults)
	db = self.db.profile
	
	self:SetEnabledState(Quartz3:GetModuleEnabled(MODNAME))
	Quartz3:RegisterModuleOptions(MODNAME, getOptions, L["Swing"])

	

end

function Swing:OnEnable()
	local _, c = UnitClass("player")
	playerclass = playerclass or c
	-- fired when autoattack is enabled/disabled.
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterEvent("UNIT_INVENTORY_CHANGED")
	self:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES", "COMBAT_MSG")
	self:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE", "COMBAT_MSG")
	self:RegisterEvent("CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES", "COMBAT_MSG")
	self:RegisterEvent("CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE", "COMBAT_MSG")
	self:RegisterEvent("UNIT_CASTEVENT")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
	
	if getn(swingbar) == 0 then
		for i=1,3 do
	
			swingbar[i] = CreateFrame("Frame", "Quartz3SwingBar", UIParent)
			swingbar[i].slot = i
			swingbar[i]:SetFrameStrata("HIGH")
			swingbar[i]:SetScript("OnShow", OnShow)
			swingbar[i]:SetScript("OnHide", OnHide)
			if i == 1 then
				swingbar[i]:SetMovable(true)
				swingbar[i]:RegisterForDrag("LeftButton")
				swingbar[i]:SetClampedToScreen(true)
	end
			swingbar[i].swingstatusbar = CreateFrame("StatusBar", nil, swingbar[i])
	
			swingbar[i].durationtext = swingbar[i].swingstatusbar:CreateFontString(nil, "OVERLAY")
			swingbar[i].remainingtext = swingbar[i].swingstatusbar:CreateFontString(nil, "OVERLAY")
			swingbar[i]:Hide()
		end
	end
	self:ApplySettings()

	resetspells = {
		[SpellInfo(845)] = true, -- Cleave
		[SpellInfo(78)] = true, -- Heroic Strike
		[SpellInfo(6807)] = true, -- Maul
		[SpellInfo(2973)] = true, -- Raptor Strike
		--[SpellInfo(56815)] = true, -- Rune Strike
	}
end

function Swing:OnDisable()
	for i=1,3 do
		swingbar[i]:Hide()
	end
end

function Swing:PLAYER_ENTERING_WORLD()
	local _
	_, playerGuid = UnitExists("player")
	if UnitAffectingCombat('player') then combat = true else combat = false end
	findRangeAction()
end

function Swing:PLAYER_REGEN_ENABLED()
	combat = false
	findRangeAction()
end

function Swing:PLAYER_REGEN_DISABLED()
	combat = true
end

function Swing:ACTIONBAR_SLOT_CHANGED()
	Quartz3:DeCacheActionSlotIds()
	findRangeAction()
end

function Swing:UNIT_INVENTORY_CHANGED()
end

function Swing:UNIT_CASTEVENT()
	if arg1 ~= playerGuid then return end

	local spell = SpellInfo(arg4)
	if spell == "Flurry" then
		if flurry_count < 1 then -- track a completely fresh flurry for timing
			flurry_fresh = true
		end
		flurry_count = 3
	end
	if arg4 == 6603 then -- 6603 == autoattack then
		if arg3 == "MAINHAND" then
			ResetTimer(MAINHAND)

			if flurry_fresh then -- fresh flurry, decrease the swing cooldown of the next swing
				timer[MAINHAND] = timer[MAINHAND] / 1.3
				duration[MAINHAND] = duration[MAINHAND] / 1.3
				flurry_fresh = false
			end
			if flurry_count == 0 then -- used up last flurry
				timer[MAINHAND] = timer[MAINHAND] * 1.3
				duration[MAINHAND] = duration[MAINHAND] * 1.3
end
		elseif arg3 == "OFFHAND" then
			ResetTimer(OFFHAND)

			if flurry_fresh then -- fresh flurry, decrease the swing cooldown of the next swing
				timer[OFFHAND] = timer[OFFHAND] / 1.3
				duration[OFFHAND] = duration[OFFHAND] / 1.3
				flurry_fresh = false
			end
			if flurry_count == 0 then -- used up last flurry
				timer[OFFHAND] = timer[OFFHAND] * 1.3
				duration[OFFHAND] = duration[OFFHAND] * 1.3
	end
end
		flurry_count = flurry_count - 1 -- swing occured, reduce flurry counter
		return
	elseif arg3 == "CAST" and arg4 == 5019 then
	-- wand shoot
		ResetTimer(RANGED)
		return
	end
	
	local spellname = SpellInfo(arg4)
	for v in resetspells do
		if spellname == v and arg3 == "CAST" then

			ResetTimer(MAINHAND)
			if flurry_fresh then
				timer[MAINHAND] = timer[MAINHAND] / 1.3
				duration[MAINHAND] = duration[MAINHAND] / 1.3
			end
			if flurry_count == 0 then -- used up last flurry
				timer[MAINHAND] = timer[MAINHAND] * 1.3
				duration[MAINHAND] = duration[MAINHAND] * 1.3
			end
			flurry_count = flurry_count - 1 -- swing occured, reduce flurry counter
			return
		end
	end
end

function Swing:COMBAT_MSG()
	if (string.find(arg1, ".* attacks. You parry.")) or (string.find(arg1, ".* was parried.")) then
		-- Only the upcoming swing gets parry haste benefit
		if (isDualWield()) then
			if timer[OFFHAND] < timer[MAINHAND] then
				local minimum = GetWeaponSpeed(OFFHAND) * 0.20
				local reduct = GetWeaponSpeed(OFFHAND) * 0.40
				timer[OFFHAND] = timer[OFFHAND] - reduct
				if timer[OFFHAND] < minimum then
					timer[MAINHAND] = minimum
				end
				return -- offhand gets the parry haste benefit, return
	end
end

		local minimum = GetWeaponSpeed(MAINHAND) * 0.20
		if (timer[MAINHAND] > minimum) then
			local reduct = GetWeaponSpeed(MAINHAND) * 0.40
			local newTimer = timer[MAINHAND] - reduct
			if (newTimer < minimum) then
				timer[MAINHAND] = minimum
			else
				timer[MAINHAND] = newTimer
			end
		end
	end
end
--[[
function Swing:START_AUTOREPEAT_SPELL()
	swingmode = 1
end

function Swing:STOP_AUTOREPEAT_SPELL()
	if not swingmode or swingmode == 1 then
		swingmode = nil
	end
end

do
	local swordspecproc = false
	function Swing:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, combatevent, srcGUID, srcName, srcFlags, dstName, dstGUID, dstFlags, spellID, spellName)
		if swingmode ~= 0 then return end
		if combatevent == "SPELL_EXTRA_ATTACKS" and spellName == swordprocname and (bit_band(srcFlags, COMBATLOG_FILTER_ME) == COMBATLOG_FILTER_ME) then
			swordspecproc = true
		elseif (combatevent == "SWING_DAMAGE" or combatevent == "SWING_MISSED") and (bit_band(srcFlags, COMBATLOG_FILTER_ME) == COMBATLOG_FILTER_ME) then
			if swordspecproc then
				swordspecproc = false
			else
				self:MeleeSwing()
			end
		elseif (combatevent == "SWING_MISSED") and (bit_band(dstFlags, COMBATLOG_FILTER_ME) == COMBATLOG_FILTER_ME) and spellID == "PARRY" and duration then
			duration = duration * 0.6
		end
	end
end

function Swing:UNIT_SPELLCAST_SUCCEEDED(event, unit, spell)
	if unit ~= "player" then return end
	if swingmode == 0 then
		if resetspells[spell] then
			self:MeleeSwing()
		elseif spell == slam and slamstart then
			starttime = starttime + GetTime() - slamstart
			slamstart = nil
		end
	elseif swingmode == 1 then
		if spell == autoshotname then
			self:Shoot()
		end
	end
	if resetautoshotspells[spell] then
		swingmode = 1
		self:Shoot()
	end
end

function Swing:UNIT_SPELLCAST_START(event, unit, spell) 
	if unit == "player" and spell == slam then
		slamstart = GetTime()
	end
end 

function Swing:UNIT_SPELLCAST_INTERRUPTED(event, unit, spell) 
	if unit == "player" and spell == slam and slamstart then 
		slamstart = nil
	end 
end 

function Swing:UNIT_ATTACK(event, unit)
	if unit == "player" then
		if not swingmode then
			return
		elseif swingmode == 0 then
			duration = UnitAttackSpeed("player")
		else
			duration = UnitRangedDamage("player")
		end
		durationtext:SetFormattedText("%.1f", duration)
	end
end
]]
--[[
function Swing:MeleeSwing()
	duration = UnitAttackSpeed("player")
	durationtext:SetFormattedText("%.1f", duration)
	starttime = GetTime()
	swingbar:Show()
end

function Swing:Shoot()
	duration = UnitRangedDamage("player")
	durationtext:SetFormattedText("%.1f", duration)
	starttime = GetTime()
	swingbar:Show()
end
]]
function Swing:ApplySettings()
	db = self.db.profile
	if getn(swingbar) > 0 and self:IsEnabled() then
		for i=1,3 do
			local bar = swingbar[i]
			bar:ClearAllPoints()
			bar:SetHeight(db.swingheight)
		swingbar_width = Player.Bar:GetWidth() - 8
			bar:SetWidth(swingbar_width)
			bar:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16})
			bar:SetBackdropColor(0,0,0)
			bar:SetAlpha(db.swingalpha)
			bar:SetScale(Player.db.profile.scale)

			local parent = i == 1 and Player.Bar or swingbar[i-1]
		if db.swingposition == "bottom" then
				bar:SetPoint("TOP", parent, "BOTTOM", 0, -1 * db.swinggap )
		elseif db.swingposition == "top" then
				bar:SetPoint("BOTTOM", parent, "TOP", 0, db.swinggap )
		else -- L["Free"]
				if i == 1 then
					bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", db.x, db.y )
				else
					bar:SetPoint("TOP", swingbar[i-1], "BOTTOM", 0, -1 * db.swinggap )
				end
		end
		
			bar.swingstatusbar:SetAllPoints(bar)
			bar.swingstatusbar:SetStatusBarTexture(media:Fetch("statusbar", Player.db.profile.texture))
			--swingstatusbar:GetStatusBarTexture():SetHorizTile(false)
			--swingstatusbar:GetStatusBarTexture():SetVertTile(false)
			bar.swingstatusbar:SetStatusBarColor(unpack(db.barcolor))
			bar.swingstatusbar:SetMinMaxValues(0, 1)
		
		if db.durationtext then
				bar.durationtext:Show()
				bar.durationtext:ClearAllPoints()
				bar.durationtext:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT")
				bar.durationtext:SetJustifyH("LEFT")
		else
				bar.durationtext:Hide()
		end
			bar.durationtext:SetFont(media:Fetch("font", Player.db.profile.font), 9)
			bar.durationtext:SetShadowColor( 0, 0, 0, 1)
			bar.durationtext:SetShadowOffset( 0.8, -0.8 )
			bar.durationtext:SetTextColor(1,1,1)
			bar.durationtext:SetNonSpaceWrap(false)
			bar.durationtext:SetWidth(swingbar_width)
		
		if db.remainingtext then
				bar.remainingtext:Show()
				bar.remainingtext:ClearAllPoints()
				bar.remainingtext:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
				bar.remainingtext:SetJustifyH("RIGHT")
		else
				bar.remainingtext:Hide()
			end
			bar.remainingtext:SetFont(media:Fetch("font", Player.db.profile.font), 9)
			bar.remainingtext:SetShadowColor( 0, 0, 0, 1)
			bar.remainingtext:SetShadowOffset( 0.8, -0.8 )
			bar.remainingtext:SetTextColor(1,1,1)
			bar.remainingtext:SetNonSpaceWrap(false)
			bar.remainingtext:SetWidth(swingbar_width)
		end
	end
end

do
	local locked = true
	local function nothing()
	end
	local function dragstart()
		this:StartMoving()
	end
	local function dragstop()
		db.x = this:GetLeft()
		db.y = this:GetBottom()
		this:StopMovingOrSizing()
	end
	
	local function setOpt(info, value)
		db[info[getn(info)]] = value
		Swing:ApplySettings()
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
		options = options or {
		type = "group",
		name = L["Swing"],
		desc = L["Swing"],
		get = getOpt,
		set = setOpt,
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
				order = 100,
			},
			barcolor = {
				type = "color",
				name = L["Bar Color"],
				desc = L["Set the color of the swing timer bar"],
				get = getColor,
				set = setColor,
				order = 102,
			},
			outrangecolor = {
				type = "color",
				name = L["Out of Range Color"],
				desc = L["Set the color to turn the cast bar when the target is out of range"],
				get = getColor,
				set = setColor,
				order = 103,
			},
			swingheight = {
				type = "range",
				name = L["Height"],
				desc = L["Set the height of the swing timer bar"],
				min = 1, max = 20, step = 1,
				order = 104,
			},
			swingalpha = {
				type = "range",
				name = L["Alpha"],
				desc = L["Set the alpha of the swing timer bar"],
				min = 0.05, max = 1, bigStep = 0.05,
				isPercent = true,
				order = 105,
			},
			swingposition = {
				type = "select",
				name = L["Bar Position"],
				desc = L["Set the position of the swing timer bar"],
				values = {["top"] = L["Top"], ["bottom"] = L["Bottom"], ["free"] = L["Free"]},
				order = 106,
			},
			lock = {
				type = "toggle",
				name = L["Lock"],
				desc = L["Toggle Cast Bar lock"],
				get = function()
					return locked
				end,
				set = function(info, v)
					for i=1,3 do
					if v then
							swingbar[i].Hide = nil
							if i==1 then
								swingbar[i]:EnableMouse(false)
								swingbar[i]:SetScript("OnDragStart", nil)
								swingbar[i]:SetScript("OnDragStop", nil)
						end
							swingbar[i]:Hide()
							
					else
							swingbar[i]:Show()
							if i==1 then
								swingbar[i]:EnableMouse(true)
								swingbar[i]:SetScript("OnDragStart", dragstart)
								swingbar[i]:SetScript("OnDragStop", dragstop)
							end
							swingbar[i]:SetAlpha(1)
							swingbar[i].Hide = nothing
						end
					end
					locked = v
				end,
				hidden = function()
					return db.swingposition ~= "free"
				end,
				order = 107,
			},
			x = {
				type = "range",
				name = L["X"],
				desc = L["Set an exact X value for this bar's position."],
				min = -2560, max = 2560, bigStep = 1,
				order = 108,
				hidden = function()
					return db.swingposition ~= "free"
				end,
			},
			y = {
				type = "range",
				name = L["Y"],
				desc = L["Set an exact Y value for this bar's position."],
				min = -2560,
				max = 2560,
				order = 108,
				hidden = function()
					return db.swingposition ~= "free"
				end,
			},
			swinggap = {
				type = "range",
				name = L["Gap"],
				desc = L["Tweak the distance of the swing timer bar from the cast bar"],
				min = -35, max = 35, step = 1,
				order = 108,
			},
			durationtext = {
				type = "toggle",
				name = L["Duration Text"],
				desc = L["Toggle display of text showing your total swing time"],
				order = 109,
			},
			remainingtext = {
				type = "toggle",
				name = L["Remaining Text"],
				desc = L["Toggle display of text showing the time remaining until you can swing again"],
				order = 110,
			},
		},
	}
	return options
	end
end
