--[[
Things to do
 Lump close dungeon/raids into one, (nexus/oculus/eoe) (DONE)
 Maybe implement lockout info on tooltip (Don't know if I want too, better addons for tracking it exist)
]]--

local DEBUG = false

local HandyNotes = LibStub("AceAddon-3.0"):GetAddon("HandyNotes", true)
if not HandyNotes then return end
local L = LibStub("AceLocale-3.0"):GetLocale("HandyNotes_DungeonLocations")

local iconDefault = "Interface\\Icons\\TRADE_ARCHAEOLOGY_CHESTOFTINYGLASSANIMALS"
--local iconDungeon = "Interface\\Addons\\HandyNotes_DungeonLocations\\dungeon.tga"
--local iconRaid = "Interface\\Addons\\HandyNotes_DungeonLocations\\raid.tga"
local iconDungeon = "Interface\\MINIMAP\\Dungeon"
local iconRaid = "Interface\\MINIMAP\\Raid"
local iconMerged = "Interface\\Addons\\HandyNotes_DungeonLocations\\merged.tga"
local iconGray = "Interface\\Addons\\HandyNotes_DungeonLocations\\gray.tga"

local db
local mapToContinent = { }
local nodes = { }
local minimap = { } -- For nodes that need precise minimap locations but would look wrong on zone or continent maps
local alterName = { }
local extraInfo = { }
--local lockouts = { }

local MERGED_DUNGEONS = 5 -- Where extra dungeon/raids ids start for merging



if (DEBUG) then
 HNDL_NODES = nodes
 HNDL_MINIMAP = minimap
 HNDL_ALTERNAME = alterName
 --HNDL_LOCKOUTS = lockouts
 
end

local internalNodes = {  -- List of zones to be excluded from continent map
 ["BlackrockMountain"] = true,
 ["CavernsofTime"] = true,
 ["DeadminesWestfall"] = true,
 ["Dalaran"] = true,
 ["MaraudonOutside"] = true,
 ["NewTinkertownStart"] = true,
 ["ScarletMonasteryEntrance"] = true,
 ["WailingCavernsBarrens"] = true,
}

local continents = {
	["Azeroth"] = true, -- Eastern Kingdoms
	["Draenor"] = true,
	["Expansion01"] = true, -- Outland
	["Kalimdor"] = true,
	["Northrend"] = true,
	["Pandaria"] = true,
}

local LOCKOUTS = { }
local function updateLockouts()
 table.wipe(LOCKOUTS)
 for i=1,GetNumSavedInstances() do
  local name, id, reset, difficulty, locked, extended, instanceIDMostSig, isRaid, maxPlayers, difficultyName, numEncounters, encounterProgress = GetSavedInstanceInfo(i)
  if (locked) then
   --print(name, difficultyName, numEncounters, encounterProgress)
   if (not LOCKOUTS[name]) then
    LOCKOUTS[name] = { }
   end
   LOCKOUTS[name][difficultyName] = encounterProgress .. "/" .. numEncounters
  end
 end
end

local pluginHandler = { }
function pluginHandler:OnEnter(mapFile, coord) -- Copied from handynotes
 --GameTooltip:AddLine("text" [, r [, g [, b [, wrap]]]])
 -- Maybe check for situations where minimap and node coord overlaps
    local nodeData = nil
    --if (not nodes[mapFile][coord]) then return end
	if (minimap[mapFile] and minimap[mapFile][coord]) then
	 nodeData = minimap[mapFile][coord]
	end
	if (nodes[mapFile] and nodes[mapFile][coord]) then
	 nodeData = nodes[mapFile][coord]
	end
	if (not nodeData) then return end
	
	local tooltip = self:GetParent() == WorldMapButton and WorldMapTooltip or GameTooltip
	if ( self:GetCenter() > UIParent:GetCenter() ) then -- compare X coordinate
		tooltip:SetOwner(self, "ANCHOR_LEFT")
	else
		tooltip:SetOwner(self, "ANCHOR_RIGHT")
	end

	
	
	--print("Node 1", nodeData[1])
	--table.insert(instances, nodeData[1])
	
	 --tooltip:AddLine(nodeData[3], nil, nil, nil, true)
	local instances = { strsplit("\n", nodeData[1]) }
	

	updateLockouts()
	
	for i, v in pairs(instances) do
	 --print(i, v)
	 if (db.lockouts and (LOCKOUTS[v] or (alterName[v] and LOCKOUTS[alterName[v]]))) then
 	  if (LOCKOUTS[v]) then
	   --print("Dungeon/Raid is locked")
	   for a,b in pairs(LOCKOUTS[v]) do
 	    tooltip:AddLine(v .. ": " .. a .. " " .. b, nil, nil, nil, false)
 	   end
	  end
	  if (alterName[v] and LOCKOUTS[alterName[v]]) then
	   for a,b in pairs(LOCKOUTS[alterName[v]]) do
 	    tooltip:AddLine(v .. ": " .. a .. " " .. b, nil, nil, nil, false)
 	   end
	  end
	 else
	  tooltip:AddLine(v, nil, nil, nil, false)
	 end
	end
	tooltip:Show()
end

function pluginHandler:OnLeave(mapFile, coord)
	if self:GetParent() == WorldMapButton then
		WorldMapTooltip:Hide()
	else
		GameTooltip:Hide()
	end
end

do
 local scale, alpha = 1, 1
 local function iter(t, prestate)
  if not t then return nil end
		
  local state, value = next(t, prestate)
  while state do
   local icon
   if (value[2] == "Dungeon") then
    icon = iconDungeon
   elseif (value[2] == "Raid") then
    icon = iconRaid
   elseif (value[2] == "Merged") then
    icon = iconMerged
   else
    icon = iconDefault
   end
  
   local allLocked = true
   local anyLocked = false
   local instances = { strsplit("\n", value[1]) }
   for i, v in pairs(instances) do
    if (not LOCKOUTS[v] and not LOCKOUTS[alterName[v]]) then
	 allLocked = false
    else
	 anyLocked = true
	end
   end
  
   -- I feel like this inverted lockout thing could be done far better
   if ((anyLocked and db.invertlockout) or (allLocked and not db.invertlockout) and db.lockoutgray) then   
    icon = iconGray
   end
   if ((anyLocked and db.invertlockout) or (allLocked and not db.invertlockout) and db.uselockoutalpha) then
    alpha = db.lockoutalpha
   else
    alpha = isContinent and db.continentAlpha or db.zoneAlpha
   end
		
   return state, nil, icon, scale, alpha
  --state, value = next(t, state)
  end 
 end
 function pluginHandler:GetNodes(mapFile, isMinimapUpdate, dungeonLevel)
  if (DEBUG) then print(mapFile) end
  local isContinent = continents[mapFile]
  scale = isContinent and db.continentScale or db.zoneScale
  alpha = isContinent and db.continentAlpha or db.zoneAlpha
  
  if (isMinimapUpdate and minimap[mapFile]) then
   return iter, minimap[mapFile]
  end
  if (isContinent and not db.continent) then
   return iter
  else
   return iter, nodes[mapFile]
  end
 end
end

local waypoints = {}
local function setWaypoint(mapFile, coord)
	local dungeon = nodes[mapFile][coord]

	local waypoint = nodes[dungeon]
	if waypoint and TomTom:IsValidWaypoint(waypoint) then
		return
	end

	local title = dungeon[1]
	local zone = HandyNotes:GetMapFiletoMapID(mapFile)
	local x, y = HandyNotes:getXY(coord)
	waypoints[dungeon] = TomTom:AddMFWaypoint(zone, nil, x, y, {
		title = dungeon[1],
		persistent = nil,
		minimap = true,
		world = true
	})
end

function pluginHandler:OnClick(button, pressed, mapFile, coord)
 if (not pressed) then return end
 if (button == "RightButton" and db.tomtom and TomTom) then
  setWaypoint(mapFile, coord)
  return
 end
 if (button == "LeftButton" and db.journal) then
  if (not EncounterJournal_OpenJournal) then
   UIParentLoadAddOn('Blizzard_EncounterJournal')
  end
  local dungeonID = nodes[mapFile][coord][4]
  local name, _, _, _, _, _, _, link = EJ_GetInstanceInfo(dungeonID)
  local difficulty = string.match(link, 'journal:.-:.-:(.-)|h') 
  if (not dungeonID or not difficulty) then return end
  EncounterJournal_OpenJournal(difficulty, dungeonID)
 end
end

local defaults = {
 profile = {
  zoneScale = 3,
  zoneAlpha = 1,
  continentScale = 3,
  continentAlpha = 1,
  continent = true,
  tomtom = true,
  journal = true,
  lockouts = true,
  lockoutgray = true,
  uselockoutalpha = false,
  lockoutalpha = 1,
  invertlockout = false,
  hideVanilla = false,
  hideOutland = false,
  hideNorthrend = false,
  hideCata = false,
  hidePandaria = false,
  hideDraenor = false,
  hideBrokenIsles = false,
 },
}

local Addon = CreateFrame("Frame")
Addon:RegisterEvent("PLAYER_LOGIN")
Addon:SetScript("OnEvent", function(self, event, ...) return self[event](self, ...) end)

local function updateStuff()
 updateLockouts()
 HandyNotes:SendMessage("HandyNotes_NotifyUpdate", "DungeonLocations")
end

function Addon:PLAYER_ENTERING_WORLD()
 updateStuff()
end

function Addon:UPDATE_INSTANCE_INFO()
 updateStuff()
end

function Addon:PLAYER_LOGIN()
 local options = {
 type = "group",
 name = "DungeonLocations",
 desc = "Locations of dungeon and raid entrances.",
 get = function(info) return db[info[#info]] end,
 set = function(info, v) db[info[#info]] = v HandyNotes:SendMessage("HandyNotes_NotifyUpdate", "DungeonLocations") end,
 args = {
  desc = {
   name = L["These settings control the look and feel of the icon."],
   type = "description",
   order = 0,
  },
  zoneScale = {
   type = "range",
   name = L["Zone Scale"],
   desc = L["The scale of the icons shown on the zone map"],
   min = 0.2, max = 12, step = 0.1,
   order = 10,
  },
  zoneAlpha = {
   type = "range",
   name = L["Zone Alpha"],
   desc = L["The alpha of the icons shown on the zone map"],
   min = 0, max = 1, step = 0.01,
   order = 20,
  },
  continentScale = {
   type = "range",
   name = L["Continent Scale"],
   desc = L["The scale of the icons shown on the continent map"],
   min = 0.2, max = 12, step = 0.1,
   order = 10,
  },
  continentAlpha = {
   type = "range",
   name = L["Continent Alpha"],
   desc = L["The alpha of the icons shown on the continent map"],
   min = 0, max = 1, step = 0.01,
   order = 20,
  },
  continent = {
   type = "toggle",
   name = L["Show on Continent"],
   desc = L["Show icons on continent map"],
   order = 1,
  },
  tomtom = {
   type = "toggle",
   name = L["Enable TomTom integration"],
   desc = L["Allow right click to create waypoints with TomTom"],
   order = 2,
  },
  journal = {
   type = "toggle",
   name = L["Journal Integration"],
   desc = L["Allow left click to open journal to dungeon or raid"],
   order = 2,
  },
  lockoutheader = {
   type = "header",
   name = L["Lockout Options"],
   order = 25,
  },
  lockouts = {
   type = "toggle",
   name = L["Lockout Tooltip"],
   desc = L["Show lockout information on tooltips"],
   order = 25.1,
  },
  lockoutgray = {
   type = "toggle",
   name = L["Lockout Gray Icon"],
   desc = L["Use gray icon for dungeons and raids that are locked to any extent"],
   order = 25.11,
  },
  uselockoutalpha = {
   type = "toggle",
   name = L["Use Lockout Alpha"],
   desc = L["Use a different alpha for dungeons and raids that are locked to any extent"],
   order = 25.2,
  },
  lockoutalpha = {
   type = "range",
   name = L["Lockout Alpha"],
   desc = L["The alpha of dungeons and raids that are locked to any extent"],
   min = 0, max = 1, step = 0.01,
   order = 25.3,
  },
  invertlockout = {
   type = "toggle",
   name = L["Invert Lockout"],
   desc = L["Turn merged icons grey when ANY dungeon or raid listed is locked"],
   order = 25.4,
  },
  hideheader = {
   type = "header",
   name = L["Hide Instances"],
   order = 26,
  },
  hideVanilla = {
   type = "toggle",
   name = L["Hide Vanilla"],
   desc = L["Hide all Vanilla nodes from the map"],
   order = 26.1,
   set = function(info, v) db[info[#info]] = v self:FullUpdate() HandyNotes:SendMessage("HandyNotes_NotifyUpdate", "DungeonLocations") end,
  },
  hideOutland = {
   type = "toggle",
   name = L["Hide Outland"],
   desc = L["Hide all Outland nodes from the map"],
   order = 26.2,
   set = function(info, v) db[info[#info]] = v self:FullUpdate() HandyNotes:SendMessage("HandyNotes_NotifyUpdate", "DungeonLocations") end,
  },
  hideNorthrend = {
   type = "toggle",
   name = L["Hide Northrend"],
   desc = L["Hide all Northrend nodes from the map"],
   order = 26.3,
   set = function(info, v) db[info[#info]] = v self:FullUpdate() HandyNotes:SendMessage("HandyNotes_NotifyUpdate", "DungeonLocations") end,
  },
  hideCata = {
   type = "toggle",
   name = L["Hide Cataclysm"],
   desc = L["Hide all Cataclysm nodes from the map"],
   order = 26.4,
   set = function(info, v) db[info[#info]] = v self:FullUpdate() HandyNotes:SendMessage("HandyNotes_NotifyUpdate", "DungeonLocations") end,
  },
  hidePandaria = {
   type = "toggle",
   name = L["Hide Pandaria"],
   desc = L["Hide all Pandaria nodes from the map"],
   order = 26.5,
   set = function(info, v) db[info[#info]] = v self:FullUpdate() HandyNotes:SendMessage("HandyNotes_NotifyUpdate", "DungeonLocations") end,
  },
  hideDraenor = {
   type = "toggle",
   name = L["Hide Draenor"],
   desc = L["Hide all Draenor nodes from the map"],
   order = 26.6,
   set = function(info, v) db[info[#info]] = v self:FullUpdate() HandyNotes:SendMessage("HandyNotes_NotifyUpdate", "DungeonLocations") end,
  },
  hideBrokenIsles = {
   type = "toggle",
   name = L["Hide Broken Isles"],
   desc = L["Hide all Broken Isle nodes from the map"],
   order = 26.7,
   set = function(info, v) db[info[#info]] = v self:FullUpdate() HandyNotes:SendMessage("HandyNotes_NotifyUpdate", "DungeonLocations") end,
  },
 },
}


 HandyNotes:RegisterPluginDB("DungeonLocations", pluginHandler, options)
 self.db = LibStub("AceDB-3.0"):New("HandyNotes_DungeonLocationsDB", defaults, true)
 db = self.db.profile
 
 self:PopulateTable()
 self:PopulateMinimap()
 self:ProcessTable()
 --self:ProcessExtraInfo()
 
 --name, description, bgImage, buttonImage, loreImage, dungeonAreaMapID, link = EJ_GetInstanceInfo([instanceID])
 -- Populate Dungeon/Raid names based on Journal
 
 updateLockouts()
 Addon:RegisterEvent("PLAYER_ENTERING_WORLD") -- Check for any lockout changes when we zone
 Addon:RegisterEvent("UPDATE_INSTANCE_INFO") --
end

-- I only put a few specific nodes on the minimap, so if the minimap is used in a zone then I need to add all zone nodes to it except for the specific ones
-- This could also probably be done better maybe
function Addon:PopulateMinimap()
 local temp = { }
 for k,v in pairs(nodes) do
  if (minimap[k]) then
   for a,b in pairs(minimap[k]) do
	temp[b[1]] = true
   end
   for c,d in pairs(v) do
    if (not temp[d[1]]) then
	 minimap[k][c] = d
	end
   end
  end
 end
end

function Addon:PopulateTable()
table.wipe(nodes)
table.wipe(minimap)

-- [COORD] = { Dungeonname/ID, Type(Dungeon/Raid/Merged), hideOnContinent(Bool), nil placeholder for id later, other dungeons }
-- VANILLA
if (not self.db.profile.hideVanilla) then
nodes["AhnQirajTheFallenKingdom"] = {
 [59001430] = { 743, "Raid", true }, -- Ruins of Ahn'Qiraj Silithus 36509410, World 42308650
 [46800750] = { 744, "Raid", true }, -- Temple of Ahn'Qiraj Silithus 24308730, World 40908570
}
nodes["Ashenvale"] = {
 --[16501100] = { 227, "Dungeon" }, -- Blackfathom Deeps 14101440 May look more accurate
 [14001310] = { 227, "Dungeon" }, -- Blackfathom Deeps, not at portal but look
}
nodes["Badlands"] = {
 [41801130] = { 239, "Dungeon" }, -- Uldaman
}
nodes["Barrens"] = {
[42106660] = { 240, "Dungeon" }, -- Wailing Caverns
}
nodes["BurningSteppes"] = {
 [20303260] = { 66, "Merged", true, nil, 228, 229, 559, 741, 742 }, -- Blackrock mountain dungeons and raids
 [23202630] = { 73, "Raid", true }, -- Blackwind Descent
}
nodes["DeadwindPass"] = {
 [46907470] = { 745, "Raid", true }, -- Karazhan
 [46707020] = { 860, "Dungeon", true }, -- Return to Karazhan
}
nodes["Desolace"] = {
 [29106250] = { 232, "Dungeon" }, -- Maraudon 29106250 Door at beginning
}
nodes["DunMorogh"] = {
 [29903560] = { 231, "Dungeon" }, -- Gnomeregan
}
nodes["Dustwallow"] = {
 [52907770] = { 760, "Raid" }, -- Onyxia's Lair
}
nodes["EasternPlaguelands"] = {
 [27201160] = { 236, "Dungeon" }, -- Stratholme World 52902870
}
nodes["Feralas"] = {
 [65503530] = { 230, "Dungeon" }, -- Dire Maul
}
nodes["Orgrimmar"] = {
 [52405800] = { 226, "Dungeon" }, -- Ragefire Chasm Cleft of Shadow 70104880
}
nodes["SearingGorge"] = {
 [41708580] = { 66, "Merged", true, nil, 228, 229, 559, 741, 742 },
 [43508120] = { 73, "Raid", true }, -- Blackwind Descent
}
nodes["Silithus"] = {
 [36208420] = { 743, "Raid" }, -- Ruins of Ahn'Qiraj
 [23508620] =  { 744, "Raid" }, -- Temple of Ahn'Qiraj
}
nodes["Silverpine"] = {
 [44806780] = { 64, "Dungeon" }, -- Shadowfang Keep
}
nodes["SouthernBarrens"] = {
 [40909450] = { 234, "Dungeon" }, -- Razorfen Kraul
}
nodes["StormwindCity"] = {
 [50406640] = { 238, "Dungeon" }, -- The Stockade
}
nodes["StranglethornJungle"] = {
 [72203290] = { 76, "Dungeon" }, -- Zul'Gurub
}
nodes["StranglethornVale"] = { -- Jungle and Cape are subzones of this zone (weird)
 [63402180] = { 76, "Dungeon" }, -- Zul'Gurub
}
nodes["SwampOfSorrows"] = {
 [69505250] = { 237, "Dungeon" }, -- The Temple of Atal'hakkar
}
nodes["Tanaris"] = {
 [65604870] = { 279, "Merged", false, nil, 255, 251, 750, 184, 185, 186, 187 },
 --[[[61006210] = { "The Culling of Stratholme", "Dungeon" },  --65604870 May look more accurate and merge all CoT dungeons/raids
 [57006230] = { "The Black Morass", "Dungeon" },
 [54605880] = { 185, "Dungeon" }, -- Well of Eternity
 [55405350] = { "The Escape from Durnholde", "Dungeon" },
 [57004990] = { "The Battle for Mount Hyjal", "Raid" },
 [60905240] = { 184, "Dungeon" }, -- End Time
 [61705190] = { 187, "Raid" }, -- Dragon Soul
 [62705240] = { 186, "Dungeon" }, -- Hour of Twilight Merge END ]]--
 [39202130] = { 241, "Dungeon" }, -- Zul'Farrak
}
nodes["Tirisfal"] = {
 [85303220] = { 311, "Dungeon", true }, -- Scarlet Halls
 [84903060] = { 316, "Dungeon", true }, -- Scarlet Monastery
}
nodes["ThousandNeedles"] = {
 [47402360] = { 233, "Dungeon" }, -- Razorfen Downs
}
nodes["WesternPlaguelands"] = {
 [69007290] = { 246, "Dungeon" }, -- Scholomance World 50903650
}
nodes["Westfall"] = {
 --[38307750] = { 63, "Dungeon" }, -- Deadmines 43707320  May look more accurate
 [43107390] = { 63, "Dungeon" }, -- Deadmines
}

-- Vanilla Continent, For things that should be shown or merged only at the continent level
 nodes["Azeroth"] = {
  [46603050] = { 311, "Dungeon", false, nil, 316 }, -- Scarlet Halls/Monastery
  [47316942] = { 66, "Merged", false, nil, 73, 228, 229, 559, 741, 742 }, -- Blackrock mount instances, merged in blackwind descent at continent level
  --[38307750] = { 63, "Dungeon" }, -- Deadmines 43707320,
  [49508190] = { 745, "Merged", false, nil, 860 }, -- Karazhan/Return to Karazhan
 }

-- Vanilla Subzone maps
nodes["BlackrockMountain"] = {
 [71305340] = { 66, "Dungeon" }, -- Blackrock Caverns
 [38701880] = { 228, "Dungeon" }, -- Blackrock Depths
 [80504080] = { 229, "Dungeon" }, -- Lower Blackrock Spire
 [79003350] = { 559, "Dungeon" }, -- Upper Blackrock Spire
 [54208330] = { 741, "Raid" }, -- Molten Core
 [64207110] = { 742, "Raid" }, -- Blackwing Lair
}
nodes["CavernsofTime"] = {
 [57608260] = { 279, "Dungeon" }, -- The Culling of Stratholme
 [36008400] = { 255, "Dungeon" }, -- The Black Morass
 [26703540] = { 251, "Dungeon" }, -- Old Hillsbrad Foothills
 [35601540] = { 750, "Raid" }, -- The Battle for Mount Hyjal
 [57302920] = { 184, "Dungeon" }, -- End Time
 [22406430] = { 185, "Dungeon" }, -- Well of Eternity
 [67202930] = { 186, "Dungeon" }, -- Hour of Twilight
 [61702640] = { 187, "Raid" }, -- Dragon Soul
}
nodes["DeadminesWestfall"] = {
 [25505090] = { 63, "Dungeon" }, -- Deadmines
}
nodes["MaraudonOutside"] = {
 [52102390] = { 232, "Dungeon", false, nil, "Purple Entrance" }, -- Maraudon 30205450 
 [78605600] = { 232, "Dungeon", false, nil, "Orange Entrance" }, -- Maraudon 36006430
 [44307680] = { 232, "Dungeon", false, nil, "Earth Song Falls Entrance" },  -- Maraudon
}
nodes["NewTinkertownStart"] = {
 [31703450] = { 231, "Dungeon" }, -- Gnomeregan
}
nodes["ScarletMonasteryEntrance"] = { -- Internal Zone
 [68802420] = { 316, "Dungeon" }, -- Scarlet Monastery
 [78905920] = { 311, "Dungeon" }, -- Scarlet Halls
}
nodes["WailingCavernsBarrens"] = {
 [55106640] = { 240, "Dungeon" }, -- Wailing Caverns
}
end

-- OUTLAND
if (not self.db.profile.hideOutland) then
nodes["BladesEdgeMountains"] = {
 [69302370] = { 746, "Raid" }, -- Gruul's Lair World 45301950
}
nodes["Ghostlands"] = {
 [85206430] = { 77, "Dungeon" }, -- Zul'Aman World 58302480
}
nodes["Hellfire"] = {
 --[47505210] = { 747, "Raid" }, -- Magtheridon's Lair World 56705270
 --[47605360] = { 248, "Dungeon" }, -- Hellfire Ramparts World 56805310 Stone 48405240 World 57005280
 --[47505200] = { 259, "Dungeon" }, -- The Shattered Halls World 56705270
 --[46005180] = { 256, "Dungeon" }, -- The Blood Furnace World 56305260
 [47205220] = { 248, "Merged", false, nil, 256, 259, 747 }, -- Hellfire Ramparts, The Blood Furnace, The Shattered Halls, Magtheridon's Lair
}
nodes["Netherstorm"] = {
 [71705500] = { 257, "Dungeon" }, -- The Botanica
 [70606980] = { 258, "Dungeon" }, -- The Mechanar World 65602540
 [74405770] = { 254, "Dungeon" }, -- The Arcatraz World 66802160
 [73806380] = { 749, "Raid" }, -- The Eye World 66602350
}
nodes["TerokkarForest"] = {
 [34306560] = { 247, "Dungeon" }, -- Auchenai Crypts World 44507890
 [39705770] = { 250, "Dungeon" }, -- Mana-Tombs World 46107640
 [44906560] = { 252, "Dungeon" }, -- Sethekk Halls World 47707890  Summoning Stone For Auchindoun 39806470, World: 46207860 
 [39607360] = { 253, "Dungeon" }, -- Shadow Labyrinth World 46108130
}
nodes["ShadowmoonValley"] = {
 [71004660] = { 751, "Raid" }, -- Black Temple World 72608410
}
nodes["Sunwell"] = {
 [61303090] = { 249, "Dungeon" }, -- Magisters' Terrace
 [44304570] = { 752, "Raid" }, -- Sunwell Plateau World 55300380
}
nodes["Zangarmarsh"] = {
 --[54203450] = { 262, "Dungeon" }, -- Underbog World 35804330
 --[48903570] = { 260, "Dungeon" }, -- Slave Pens World 34204370
 --[51903280] = { 748, "Raid" }, -- Serpentshrine Cavern World 35104280
 [50204100] = { 260, "Merged", false, nil, 261, 262, 748 }, -- Merged Location
}
minimap["Hellfire"] = {
 [47605360] = { 248, "Dungeon" }, -- Hellfire Ramparts World 56805310 Stone 48405240 World 57005280
 [46005180] = { 256, "Dungeon" }, -- The Blood Furnace World 56305260
 [48405180] = { 259, "Dungeon" }, -- The Shattered Halls World 56705270, Old 47505200.  Adjusted for clarity
 [46405290] = { 747, "Raid" }, -- Magtheridon's Lair World 56705270, Old 47505210.  Adjusted for clarity
}
minimap["Zangarmarsh"] = {
 [48903570] = { 260, "Dungeon" }, -- Slave Pens World 34204370
 [50303330] = { 261, "Dungeon" }, -- The Steamvault
 [54203450] = { 262, "Dungeon" }, -- Underbog World 35804330
 [51903280] = { 748, "Raid" }, -- Serpentshrine Cavern World 35104280
}
end

-- NORTHREND (16 Dungeons, 9 Raids)
if (not self.db.profile.hideNorthrend) then
nodes["BoreanTundra"] = {
 [27602660] = { 282, "Merged", false, nil, 756, 281 },
 -- Oculus same as eye of eternity
 --[27502610] = { "The Nexus", "Dungeon" },
}
nodes["CrystalsongForest"] = {
 [28203640] = { 283, "Dungeon" }, -- The Violet Hold
}
nodes["Dragonblight"] = {
 [28505170] = { 271, "Dungeon" }, -- Ahn'kahet: The Old Kingdom
 [26005090] = { 272, "Dungeon" }, -- Azjol-Nerub
 [87305100] = { 754, "Raid" }, -- Naxxramas
 [61305260] = { 761, "Raid" }, -- The Ruby Sanctum
 [60005690] = { 755, "Raid" }, -- The Obsidian Sanctum
}
nodes["HowlingFjord"] = {
 --[57304680] = { 285, "Dungeon" }, -- Utgarde Keep, more accurate but right underneath Utgarde Pinnacle
 [58005000] = { 285, "Dungeon" }, -- Utgarde Keep, at doorway entrance
 [57204660] = { 286, "Dungeon" }, -- Utgarde Pinnacle
}
nodes["IcecrownGlacier"] = { 
 [54409070] = { 276, "Dungeon", false, nil, 278, 280 }, -- The Forge of Souls, Halls of Reflection, Pit of Saron
 [74202040] = { 284, "Dungeon", true }, -- Trial of the Champion
 [75202180] = { 757, "Raid", true }, -- Trial of the Crusader
 [53808720] = { 758, "Raid" }, -- Icecrown Citadel
}
nodes["LakeWintergrasp"] = {
 [50001160] = { 753, "Raid" }, -- Vault of Archavon
}
nodes["TheStormPeaks"] = {
 [45302140] = { 275, "Dungeon" }, -- Halls of Lightning
 [39602690] = { 277, "Dungeon" }, -- Halls of Stone
 [41601770] = { 759, "Raid" }, -- Ulduar
}
nodes["ZulDrak"] = {
 [28508700] = { 273, "Dungeon" }, -- Drak'Tharon Keep 17402120 Grizzly Hills
 [76202110] = { 274, "Dungeon" }, -- Gundrak Left Entrance
 [81302900] = { 274, "Dungeon" }, -- Gundrak Right Entrance
}
nodes["Dalaran"] = {
 [68407000] = { 283, "Dungeon" }, -- The Violet Hold
}

-- NORTHREND MINIMAP, For things that would be too crowded on the continent or zone maps but look correct on the minimap
minimap["IcecrownGlacier"] = {
 [54908980] = { 280, "Dungeon", true }, -- The Forge of Souls
 [55409080] = { 276, "Dungeon", true }, -- Halls of Reflection
 [54809180] = { 278, "Dungeon", true }, -- Pit of Saron 54409070 Summoning stone in the middle of last 3 dungeons
}

-- NORTHREND CONTINENT, For things that should be shown or merged only at the continent level
nodes["Northrend"] = {
 --[80407600] = { 285, "Dungeon", false, 286 }, -- Utgarde Keep, Utgarde Pinnacle CONTINENT MERGE Location is slightly incorrect
 [47501750] = { 757, "Merged", false, nil, 284 }, -- Trial of the Crusader and Trial of the Champion
}
end

-- CATACLYSM
if (not self.db.profile.hideCata) then
nodes["Deepholm"] = {
 [47405210] = { 67, "Dungeon" }, -- The Stonecore (Maelstrom: 51002790)
}
nodes["Hyjal"] = {
 [47307810] = { 78, "Raid" }, -- Firelands
}
nodes["TolBarad"] = {
 [46104790] = { 75, "Raid" }, -- Baradin Hold
}
nodes["TwilightHighlands"] = {
 [19105390] = { 71, "Dungeon" }, -- Grim Batol World 53105610
 [34007800] = { 72, "Raid" }, -- The Bastion of Twilight World 55005920
}
nodes["Uldum"] = {
 [76808450] = { 68, "Dungeon" }, -- The Vortex Pinnacle
 [60506430] = { 69, "Dungeon" }, -- Lost City of Tol'Vir
 [69105290] = { 70, "Dungeon" }, -- Halls of Origination
 [38308060] = { 74, "Raid" }, -- Throne of the Four Winds
}
nodes["Vashjir"] = {
 [48204040] =  { 65, "Dungeon", true }, -- Throne of Tides
}
nodes["VashjirDepths"] = {
 [69302550] = { 65, "Dungeon" }, -- Throne of Tides
}
end

-- PANDARIA
if (not self.db.profile.hidePandaria) then
nodes["DreadWastes"] = {
 [38803500] = { 330, "Raid" }, -- Heart of Fear
}
nodes["IsleoftheThunderKing"] = {
 [63603230] = { 362, "Raid", true }, -- Throne of Thunder
}
nodes["KunLaiSummit"] = {
 [59503920] = { 317, "Raid" }, -- Mogu'shan Vaults
 [36704740] = { 312, "Dungeon" }, -- Shado-Pan Monastery
}
nodes["TheHiddenPass"] = {
 [48306130] = { 320, "Raid" }, -- Terrace of Endless Spring
}
nodes["TheJadeForest"] = {
 [56205790] = { 313, "Dungeon" }, -- Temple of the Jade Serpent
}
nodes["TownlongWastes"] = {
 [34708150] = { 324, "Dungeon" }, -- Siege of Niuzao Temple
}
nodes["ValeofEternalBlossoms"] = {
 [15907410] = { 303, "Dungeon" }, -- Gate of the Setting Sun
 [80803270] = { 321, "Dungeon" }, -- Mogu'shan Palace
 [74104200] = { 369, "Raid" }, -- Siege of Orgrimmar
}
nodes["ValleyoftheFourWinds"] = {
 [36106920] = { 302, "Dungeon" }, -- Stormstout Brewery
}

-- PANDARIA Continent, For things that should be shown or merged only at the continent level
nodes["Pandaria"] = {
 [23100860] = { 362, "Raid" }, -- Throne of Thunder, looked weird so manually placed on continent
}
end

-- DRAENOR
if (not self.db.profile.hideDraenor) then
nodes["FrostfireRidge"] = {
 [49902470] = { 385, "Dungeon" }, -- Bloodmaul Slag Mines
}
nodes["Gorgrond"] = {
 [51502730] = { 457, "Raid" }, -- Blackrock Foundry
 [55103160] = { 536, "Dungeon" }, -- Grimrail Depot
 [59604560] = { 556, "Dungeon" }, -- The Everbloom
 [45401350] = { 558, "Dungeon" }, -- Iron Docks
}
nodes["NagrandDraenor"] = {
 [32903840] = { 477, "Raid" } -- Highmaul
}
nodes["ShadowmoonValleyDR"] = {
 [31904260] = { 537, "Dungeon" }, -- Shadowmoon Burial Grounds
}
nodes["SpiresOfArak"] = {
 [35603360] = { 476, "Dungeon" }, -- Skyreach
}
nodes["Talador"] = {
 [46307390] = { 547, "Dungeon" }, -- Auchindoun
}
nodes["TanaanJungle"] = {
 [45605360] = { 669, "Raid" }, -- Hellfire Citadel
}
end

if (not self.db.profile.hideBrokenIsles) then
-- Legion Dungeons/Raids for minimap and continent map for consistency
-- This seems to be the only legion raid that isn't shown at all
nodes["Dalaran70"] = {
 [66406850] = { 777, "Dungeon", true }, -- Assault on Violet Hold
}
minimap["Azsuna"] = {
 [61204110] = { 716, "Dungeon", true },
 [48308030] = { 707, "Dungeon", true },
}
minimap["BrokenShore"] = {
 [64602070] = { 875, "Raid" },
 [64701660] = { 900, "Dungeon" },
}
minimap["Highmountain"] = {
 [49606860] = { 767, "Dungeon", true },
}
minimap["Stormheim"] = {
 [71107280] = { 861, "Raid", true },
 [72707050] = { 721, "Dungeon", true },
 [52504530] = { 727, "Dungeon", true },
}
minimap["Suramar"] = {
 [41106170] = { 726, "Dungeon", true },
 [50806550] = { 800, "Dungeon", true },
 [44105980] = { 786, "Raid", true },
}
minimap["Valsharah"] = {
 [37205020] = { 740, "Dungeon", true },
 [59003120] = { 762, "Dungeon", true },
 [56303680] = { 768, "Raid", true },
}

nodes["BrokenIsles"] = {
 [38805780] = { 716, "Dungeon" }, -- Eye of Azshara
 [34207210] = { 707, "Dungeon" }, -- Vault of the Wardens
 [47302810] = { 767, "Dungeon" }, -- Neltharion's Lair
 [59003060] = { 727, "Dungeon" }, -- Maw of Souls
 [35402850] = { 762, "Merged", false, nil, 768}, -- The Emerald Nightmare 35102910
 [65003870] = { 721, "Merged", false, nil, 861 }, -- Halls of Valor/Trial of Valor Unmerged: 65203840 64703900
 [46704780] = { 726, "Merged", false, nil, 786 }, -- The Arcway/The Nighthold
 [49104970] = { 800, "Dungeon" }, -- Court of Stars
 [29403300] = { 740, "Dungeon" }, -- Black Rook Hold
 [46606550] = { 777, "Dungeon" }, -- Assault on Violet Hold
 --[56606210] = { 875, "Raid" }, -- Tomb of Sargeras
 --[56706120] = { 900, "Dungeon"}, -- Cathedral of the Night
 [56506240] = { 875, "Merged", false, nil, 900 },
}
end
end

function Addon:ProcessTable()
table.wipe(alterName)

-- These are the same on the english client, I put them here cause maybe they change in other locales.  This list was somewhat automatically generated
-- I may be over thinking this
alterName[321] = 1467 -- Mogu'shan Palace
alterName[758] = 280 -- Icecrown Citadel
alterName[476] = 1010 -- Skyreach
alterName[233] = 20 -- Razorfen Downs
alterName[751] = 196 -- Black Temple
alterName[536] = 1006 -- Grimrail Depot
alterName[861] = 1439 -- Trial of Valor
alterName[756] = 1423 -- The Eye of Eternity
alterName[716] = 1175 -- Eye of Azshara
alterName[76] = 334 -- Zul'Gurub
alterName[77] = 340 -- Zul'Aman
alterName[757] = 248 -- Trial of the Crusader
alterName[236] = 1458 -- Stratholme
alterName[745] = 175 -- Karazhan
alterName[271] = 1016 -- Ahn'kahet: The Old Kingdom
alterName[330] = 534 -- Heart of Fear
alterName[186] = 439 -- Hour of Twilight
alterName[229] = 32 -- Lower Blackrock Spire
alterName[279] = 210 -- The Culling of Stratholme
alterName[385] = 1005 -- Bloodmaul Slag Mines
alterName[253] = 181 -- Shadow Labyrinth
alterName[276] = 256 -- Halls of Reflection
alterName[69] = 1151 -- Lost City of the Tol'vir
alterName[187] = 448 -- Dragon Soul
alterName[274] = 1017 -- Gundrak
alterName[252] = 180 -- Sethekk Halls
alterName[65] = 1150 -- Throne of the Tides
alterName[70] = 321 -- Halls of Origination
alterName[707] = 1044 -- Vault of the Wardens
alterName[283] = 1297 -- The Violet Hold
alterName[875] = 1527 -- Tomb of Sargeras
alterName[75] = 329 -- Baradin Hold
alterName[800] = 1319 -- Court of Stars
alterName[64] = 327 -- Shadowfang Keep
alterName[760] = 257 -- Onyxia's Lair
alterName[777] = 1209 -- Assault on Violet Hold
alterName[311] = 473 -- Scarlet Halls
alterName[755] = 238 -- The Obsidian Sanctum
alterName[726] = 1190 -- The Arcway
alterName[275] = 1018 -- Halls of Lightning
alterName[277] = 213 -- Halls of Stone
alterName[241] = 24 -- Zul'Farrak
alterName[762] = 1202 -- Darkheart Thicket
alterName[786] = 1353 -- The Nighthold
alterName[727] = 1192 -- Maw of Souls
alterName[362] = 634 -- Throne of Thunder
alterName[759] = 244 -- Ulduar
alterName[317] = 532 -- Mogu'shan Vaults
alterName[272] = 241 -- Azjol-Nerub
alterName[558] = 1007 -- Iron Docks
alterName[247] = 178 -- Auchenai Crypts
alterName[273] = 215 -- Drak'Tharon Keep
alterName[324] = 1465 -- Siege of Niuzao Temple
alterName[754] = 227 -- Naxxramas
alterName[753] = 240 -- Vault of Archavon
alterName[286] = 1020 -- Utgarde Pinnacle
alterName[280] = 252 -- The Forge of Souls
alterName[67] = 1148 -- The Stonecore
alterName[747] = 176 -- Magtheridon's Lair
alterName[258] = 192 -- The Mechanar
alterName[281] = 1019 -- The Nexus
alterName[369] = 766 -- Siege of Orgrimmar
alterName[184] = 1152 -- End Time
alterName[740] = 1205 -- Black Rook Hold
alterName[742] = 50 -- Blackwing Lair
alterName[457] = 900 -- Blackrock Foundry
alterName[313] = 1469 -- Temple of the Jade Serpent
alterName[556] = 1003 -- The Everbloom
alterName[248] = 188 -- Hellfire Ramparts
alterName[768] = 1350 -- The Emerald Nightmare
alterName[721] = 1473 -- Halls of Valor
alterName[231] = 14 -- Gnomeregan
alterName[900] = 1488 -- Cathedral of Eternal Night
alterName[257] = 191 -- The Botanica
alterName[302] = 1466 -- Stormstout Brewery
alterName[669] = 989 -- Hellfire Citadel
alterName[559] = 1004 -- Upper Blackrock Spire
alterName[741] = 48 -- Molten Core
alterName[78] = 362 -- Firelands
alterName[547] = 1008 -- Auchindoun
alterName[537] = 1009 -- Shadowmoon Burial Grounds
alterName[477] = 897 -- Highmaul
alterName[261] = 185 -- The Steamvault
alterName[746] = 177 -- Gruul's Lair
alterName[303] = 1464 -- Gate of the Setting Sun
alterName[66] = 323 -- Blackrock Caverns
alterName[249] = 1154 -- Magisters' Terrace
alterName[278] = 1153 -- Pit of Saron
alterName[73] = 314 -- Blackwing Descent
alterName[316] = 474 -- Scarlet Monastery
alterName[246] = 472 -- Scholomance
alterName[226] = 4 -- Ragefire Chasm
alterName[63] = 326 -- Deadmines
alterName[227] = 10 -- Blackfathom Deeps
alterName[285] = 242 -- Utgarde Keep
alterName[185] = 437 -- Well of Eternity
alterName[250] = 1013 -- Mana-Tombs
alterName[312] = 1468 -- Shado-Pan Monastery
alterName[748] = 194 -- Serpentshrine Cavern
alterName[320] = 834 -- Terrace of Endless Spring
alterName[284] = 249 -- Trial of the Champion
alterName[234] = 16 -- Razorfen Kraul
alterName[240] = 1 -- Wailing Caverns
alterName[68] = 1147 -- The Vortex Pinnacle
alterName[74] = 318 -- Throne of the Four Winds
alterName[767] = 1207 -- Neltharion's Lair
alterName[72] = 316 -- The Bastion of Twilight
alterName[239] = 22 -- Uldaman
alterName[282] = 1296 -- The Oculus
alterName[71] = 1149 -- Grim Batol
alterName[254] = 1011 -- The Arcatraz

-- This is a list of the ones that absolutely do not match in the english client
alterName[743] = 160 -- Ruins of Ahn'Qiraj -> Ahn'Qiraj Ruins
alterName[749] = 193 -- The Eye -> Tempest Keep

alterName[761] = 1502 -- The Ruby Sanctum -> Ruby Sanctum
alterName[744] = 161 -- Temple of Ahn'Qiraj -> Ahn'Qiraj Temple

for i,v in pairs(nodes) do
  for j,u in pairs(v) do
   --[[if (type(u[1]) == "number") then
    local name = EJ_GetInstanceInfo(u[1])
    u[1] = name
   end ]]--
   --if (u[2] == "Merged") then
   local n = MERGED_DUNGEONS
   local newName = EJ_GetInstanceInfo(u[1])
   self:UpdateAlter(u[1], newName)
   u[4] = u[1]
   while(u[n]) do
	if (type(u[n]) == "number") then
	 local name = EJ_GetInstanceInfo(u[n])
	 self:UpdateAlter(u[n],name)
	 newName = newName .. "\n" .. name
	else
	 newName = newName .. "\n" .. u[n]
	end
	u[n] = nil
	n = n + 1
   end
   u[1] = newName
  end
 end
 
 for i,v in pairs(minimap) do
  for j,u in pairs(v) do
   if (type(u[1]) == "number") then -- Added because since some nodes are connected to the node table they were being changed before this and this function was then messing it up
    u[4] = u[1]
    u[1] = EJ_GetInstanceInfo(u[1])
   end
  end
 end
 
 local HereBeDragons = LibStub("HereBeDragons-1.0") -- Phanx
 local continents = { GetMapContinents() }
 local temp = { } -- I switched to the temp table because modifying the nodes table while iterating over it sometimes stopped it short for some reason
 for mapFile, coords in pairs(nodes) do
  if not continents[mapFile] and not (internalNodes[mapFile]) then
   if (DEBUG) then print(mapFile) end
   local continentMapID = continents[2 * HandyNotes:GetCZ(mapFile) - 1]
   local continentMapFile = HandyNotes:GetMapIDtoMapFile(continentMapID)
   mapToContinent[mapFile] = continentMapFile
   for coord, criteria in next, coords do
    if (not criteria[3]) then
     local x, y = HandyNotes:getXY(coord)
     x, y = HereBeDragons:GetWorldCoordinatesFromZone(x, y, mapFile)
     x, y = HereBeDragons:GetZoneCoordinatesFromWorld(x, y, continentMapID)
     if x and y then
      temp[continentMapFile] = temp[continentMapFile] or {}
      temp[continentMapFile][HandyNotes:getCoord(x, y)] = criteria
	 end
	end
   end
  end
 end
 for mapFile, coords in pairs(temp) do
   nodes[mapFile] = coords
 end
end


-- The goal here is to have a table of IDs that correspond between the GetLFGDungeonInfo and EJ_GetInstanceInfo functions
-- I check if the names are different and if so then use both when checking for lockouts
-- This can probably be done better but I don't know how
-- I'm putting this in because on the english client, certain raids have a different lockout name than their journal counterpart e.g The Eye and Tempest Keep
-- If it's messed up in english then it's probably messed up elsewhere and I don't even know if this will help
function Addon:UpdateAlter(id, name)
 if (alterName[id]) then
  local alternativeName = GetLFGDungeonInfo(alterName[id])
  if (alternativeName) then
   if (alternativeName == name) then
    --print("EJ and LFG names both match, removing", name, "from table")
	--alterName[id] = nil
   else
    alterName[id] = nil
    alterName[name] = alternativeName
    --print("Changing",id,"to",name,"and setting alter value to",alternativeName)
   end
  end
 end
end

function Addon:ProcessExtraInfo() -- Could use this to add required levels and things, may do later or not
 table.wipe(extraInfo)
 if (true) then return end
 
--[[ for i=1,2000 do -- Do this less stupidly
  local name, typeID, subtypeID, minLevel, maxLevel, recLevel, minRecLevel, maxRecLevel, expansionLevel, groupID, textureFilename, difficulty, maxPlayers, description, isHoliday, bonusRepAmount, minPlayers, isTimeWalker, name2, minGearLevel = GetLFGDungeonInfo(i)
 end]]
end

function Addon:FullUpdate()
 self:PopulateTable()
 self:PopulateMinimap()
 self:ProcessTable()
 --self:ProcessExtraInfo()
end
