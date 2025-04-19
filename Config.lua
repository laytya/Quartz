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
local AceCore = LibStub("AceCore-3.0")
local ACD3 = LibStub("AceConfigDialog-3.0")
local LDB = LibStub("LibDataBroker-1.1", true)
local ldbIcon = LibStub("LibDBIcon-1.0", true)
local trim = AceCore.strtrim
----------------------------
-- Upvalues
-- GLOBALS: LibStub, InterfaceOptionsFrame_OpenToCategory
local pairs, unpack, type = pairs, unpack, type
local getn, format = table.getn, string.format
local getOpt, setOpt, getColor, setColor
do
	function getOpt(info)
		local key = info[getn(info)] 
		return Quartz3.db.profile[key]
	end
	
	function setOpt(info, value)
		local key = info[getn(info)]
		Quartz3.db.profile[key] = value
		Quartz3:ApplySettings()
	end
	
	function getColor(info)
		return unpack(getOpt(info))
	end
	
	function setColor(info, r, g, b, a)
		setOpt(info, {r, g, b, a})
	end
end

local options, moduleOptions = nil, {}
local function getOptions()
	if not options then
		 options = {
			type = "group",
			args = {
				general = {
					type = "group",
					inline = true,
					name = "",
					args = {
						unlock = {
							type = "execute",
							name = L["Toggle Bar Lock"],
							desc = L["Unlock the Bars to be able to move them around."],
							func = function()
								Quartz3:ToggleLock(true)
							end,
							order = 50,
						},
						nllock = {
							type = "description",
							name = "",
							order = 51,
						},
						hidesamwise = {
							type = "toggle",
							name = L["Hide Samwise Icon"],
							desc = L["Hide the icon for spells with no icon"],
							order = 101,
							get = getOpt,
							set = setOpt,
						},
						casttimeprecision = {
							type = "range",
							name = L["Cast Time Precision"],
							desc = L["Number of decimals to show for the Cast Time"],
							min = 0, max = 3, step = 1,
							get = getOpt,
							set = setOpt,
							order = 102,
						},
						colors = {
							type = "group",
							name = L["Colors"],
							desc = L["Colors"],
							guiInline = true,
							order = 450,
							get = getColor,
							set = setColor,
							args = {
								spelltextcolor = {
									type = "color",
									name = L["Spell Text"],
									desc = format(L["Set the color of the %s"], L["Spell Text"]),
									order = 98,
								},
								timetextcolor = {
									type = "color",
									name = L["Time Text"],
									desc = format(L["Set the color of the %s"],L["Time Text"]),
									order = 98,
								},
								header = {
									type = "header",
									name = "",
									order = 99,
								},
								castingcolor = {
									type = "color",
									name = L["Casting"],
									desc = format(L["Set the color of the cast bar when %s"],L["Casting"]),
								},
								channelingcolor = {
									type = "color",
									name = L["Channeling"],
									desc = format(L["Set the color of the cast bar when %s"],L["Channeling"]),
								},
								completecolor = {
									type = "color",
									name = L["Complete"],
									desc = format(L["Set the color of the cast bar when %s"],L["Complete"]),
								},
								failcolor = {
									type = "color",
									name = L["Failed"],
									desc = format(L["Set the color of the cast bar when %s"],L["Failed"]),
								},
								sparkcolor = {
									type = "color",
									name = L["Spark Color"],
									desc = L["Set the color of the casting bar spark"],
									hasAlpha = true,
								},
								nl1 = {
									type = "description",
									name = "",
									order = 101,
								},
								backgroundcolor = {
									type = "color",
									name = L["Background"],
									desc = L["Set the color of the casting bar background"],
									order = 102,
								},
								backgroundalpha = {
									type = "range",
									name = L["Background Alpha"],
									desc = L["Set the alpha of the casting bar background"],
									isPercent = true,
									min = 0, max = 1, bigStep = 0.025,
									get = getOpt,
									set = setOpt,
									order = 103,
								},
								bordercolor = {
									type = "color",
									name = L["Border"],
									desc = L["Set the color of the casting bar border"],
									order = 104,
								},
								borderalpha = {
									type = "range",
									name = L["Border Alpha"],
									desc = L["Set the alpha of the casting bar border"],
									isPercent = true,
									min = 0, max = 1, bigStep = 0.025,
									get = getOpt,
									set = setOpt,
									order = 105,
								},
							},
						},
					},
				},
			},
		}
		for k,v in pairs(moduleOptions) do
			options.args[k] = (type(v) == "function") and v() or v
		end
	end
	return options
end

function Quartz3:ChatCommand(input)
	if not input or trim(input) == "" then
		InterfaceOptionsFrame_OpenToCategory("Quartz3","Profiles")
		InterfaceOptionsFrame_OpenToCategory("Quartz3")
	else
		LibStub("AceConfigCmd-3.0").HandleCommand(Quartz3, "quartz", "Quartz3", input)
	end
end

function Quartz3:SetupOptions()
	self.optFrames = {}
	self.options = getOptions()
	--LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("Quartz3", getOptions)
	LibStub('AceConfig-3.0').RegisterOptionsTable(self, "Quartz3", self.options)
	self.optFrames.Quartz3 = ACD3:AddToBlizOptions("Quartz3", "Quartz 3", nil, "general")
	self:RegisterModuleOptions("Profiles", LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db) , "Profiles")
	self:RegisterChatCommand("quartz", "ChatCommand")
	self:RegisterChatCommand("q3", "ChatCommand")

	self:InitDBIcon()
end

function Quartz3:RegisterModuleOptions(name, optTable, displayName)
	moduleOptions[name] = optTable
	self.optFrames[name] = ACD3:AddToBlizOptions("Quartz3", displayName or name, "Quartz3", name)
end

local hintString = "|cffffffff%s:|r %s"
local hintText = {
	"Quartz3",
	format(hintString, "Left-Click", L["Show/Hide Quartz3 options"]),
	--format(hintString, "Right-Click", L["Config"]),

}

local function LDBOnClick(self, button)
	Quartz3:ChatCommand()
end

function Quartz3:InitDBIcon()

	if (LDB) then
		local ldbQuartz3 = LibStub("LibDataBroker-1.1"):NewDataObject("Quartz3", {
			type = "launcher",
			icon = "Interface\\Icons\\Spell_Frost_FrostBolt02",
			tocname = "Quartz3",
			label = "Quartz3",
			OnClick = LDBOnClick,
			OnTooltipShow = function(tooltip)
				
				if (tooltip and tooltip.AddLine) then
					for _i, text in ipairs(hintText) do
						tooltip:AddLine(text)
					end
				end
			end,
		})

		if (ldbIcon) then
			if (not Quartz3.db.profile.ldbIcon) then
				Quartz3.db.profile.ldbIcon = {}
			end
			ldbIcon:Register("Quartz3", ldbQuartz3, Quartz3.db.profile.ldbIcon)

			self.options.args.general.args.ldbIcon = {
				type = "toggle",
				order = 80,
				width = "normal",
				name = L["Show Minimap Icon"],
				desc = L["Show Minimap Icon"],
				get = function() return not Quartz3.db.profile.ldbIcon.hide end,
				set = function(info, value)
					value = not value
					Quartz3.db.profile.ldbIcon.hide = value
					if (value) then
						ldbIcon:Hide("Quartz3")
					else
						ldbIcon:Show("Quartz3")
					end
				end,
			}
		end
	end
end