--
-- growthcontrol
-- V1.0.0.0
--
-- @author apuehri
-- @date 07/01/2019
--
-- Copyright (C) apuehri
-- V1.0.0.0 ..... FS19 first implementation, integration multiplayer, adding weed control

growthcontrol = {};
growthcontrol.Version = "1.0.0.0";
growthcontrol.debug = false;

function growthcontrol.prerequisitesPresent(specializations)
    return true;
end;

function growthcontrol:loadMap(name)
    -- Only needed for action event for player
	if growthcontrol.debug then
		print("--- growthcontrol Debug ... growthcontrol:loadMap ++ isClient="..tostring(g_currentMission:getIsClient()).." ,isSever="..tostring(g_currentMission:getIsServer()).." ,isMasterUser="..tostring(g_currentMission.isMasterUser).." ---");
	end;		
	Player.registerActionEvents = Utils.appendedFunction(Player.registerActionEvents, growthcontrol.registerActionEventsPlayer);
	Player.removeActionEvents = Utils.appendedFunction(Player.removeActionEvents, growthcontrol.removeActionEventsPlayer);
		
	-- MinuteChangeListener
	g_currentMission.environment:addMinuteChangeListener(growthcontrol);

	-- SaveSettings
	FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, growthcontrol.saveSettings);
	
	--initialize
	growthcontrol.showHud = false;
	growthcontrol.recalculate = false;
	growthcontrol.maxnumfruits = 15;
	growthcontrol.fruitnames = {[0]="wheat",[1]="grass",[2]="canola",[3]="barley",[4]="maize",[5]="not used",[6]="potato",[7]="sugarBeet",[8]="sunflower",[9]="soybean",[10]="oilseedRadish",[11]="poplar",[12]="not used",[13]="oat",[14]="sugarCane",[15]="cotton"};
	growthcontrol.growthhours = {};	
	growthcontrol.growthstatetime = {};
	growthcontrol.growthremtime = {};
	growthcontrol.literPerSqm = {};
	growthcontrol.seedUsagePerSqm = {};
	growthcontrol.showHelp = true;
	growthcontrol.weedUpdateFactor = 1.3;
	growthcontrol.weedUpdateTime = 30000000;
	growthcontrol.weedRemTime = 0;
	
	-- Hud Settings
	local uiScale = g_gameSettings:getValue("uiScale");
	
	growthcontrol.tPos = {};
	growthcontrol.tPos.size = 0.015 * uiScale;				-- TextSize
	growthcontrol.tPos.spacing = 0.003 * uiScale;			-- Spacing
	growthcontrol.tPos.alignment = RenderText.ALIGN_LEFT;	-- Text Alignment
	growthcontrol.tPos.bgoffset = 0.003 * uiScale; 			-- Offset to Background
	growthcontrol.tPos.yoffset = 0.006 * uiScale ; 			-- Offset y-Startpos	
	growthcontrol.tPos.frame = 0.0005 * uiScale; 			-- Frame
	growthcontrol.tPos.h = ((growthcontrol.tPos.size+growthcontrol.tPos.spacing)*growthcontrol.maxnumfruits) + growthcontrol.tPos.size + (2*growthcontrol.tPos.bgoffset); -- height
	growthcontrol.tPos.w = 0.145 * uiScale;	-- width
	growthcontrol.tPos.x = g_currentMission.hud.gameInfoDisplay.weatherBox.overlay.x - growthcontrol.tPos.w; -- x Pos
	growthcontrol.tPos.y = 0.965 -- y Pos

	--Hud Overlay main background
	local ypos = growthcontrol.tPos.y - growthcontrol.tPos.h + growthcontrol.tPos.size;
	growthcontrol.tPosBgOverlayId = Overlay:new("dataS2/menu/white.dds", growthcontrol.tPos.x - growthcontrol.tPos.bgoffset, ypos , growthcontrol.tPos.w , growthcontrol.tPos.h );
	growthcontrol.tPosBgOverlayId:setColor(0.018, 0.016, 0.015, 0.65);
	
	--Hud Overlay top
	ypos = growthcontrol.tPos.y - growthcontrol.tPos.h + growthcontrol.tPos.size + growthcontrol.tPos.h;
	growthcontrol.tPosTopOverlayId = Overlay:new("dataS2/menu/white.dds", growthcontrol.tPos.x - growthcontrol.tPos.bgoffset - growthcontrol.tPos.frame, ypos , growthcontrol.tPos.w + (growthcontrol.tPos.frame*2) , (growthcontrol.tPos.frame * 3));
	growthcontrol.tPosTopOverlayId:setColor(1, 1, 1, 1);	
	
	--Hud Overlay left
	ypos = growthcontrol.tPos.y - growthcontrol.tPos.h + growthcontrol.tPos.size;
	growthcontrol.tPosLeOverlayId = Overlay:new("dataS2/menu/white.dds", growthcontrol.tPos.x - growthcontrol.tPos.bgoffset - growthcontrol.tPos.frame, ypos , growthcontrol.tPos.frame , growthcontrol.tPos.h);
	growthcontrol.tPosLeOverlayId:setColor(1, 1, 1, 1);
	
	--Hud Overlay right
	ypos = growthcontrol.tPos.y - growthcontrol.tPos.h + growthcontrol.tPos.size;
	growthcontrol.tPosRiOverlayId = Overlay:new("dataS2/menu/white.dds", growthcontrol.tPos.x - growthcontrol.tPos.bgoffset + growthcontrol.tPos.w, ypos , growthcontrol.tPos.frame , growthcontrol.tPos.h);
	growthcontrol.tPosRiOverlayId:setColor(1, 1, 1, 1);
	
	--Hud Overlay bottom
	ypos = growthcontrol.tPos.y - growthcontrol.tPos.h + growthcontrol.tPos.size - (growthcontrol.tPos.frame * 9);
	growthcontrol.tPosBoOverlayId = Overlay:new("dataS2/menu/white.dds", growthcontrol.tPos.x - growthcontrol.tPos.bgoffset - growthcontrol.tPos.frame, ypos , growthcontrol.tPos.w + (growthcontrol.tPos.frame*2) , (growthcontrol.tPos.frame * 9));
	growthcontrol.tPosBoOverlayId:setColor(0.9910, 0.3865, 0.0100, 1);
	
		
	--load Savegame
	local savegameIndex = g_currentMission.missionInfo.savegameIndex;
	local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory;
	if savegameFolderPath == nil then
		savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), savegameIndex);
	end;

	if fileExists(savegameFolderPath .. '/careerSavegame.xml') then
		if fileExists(savegameFolderPath .. '/growthcontrol.xml') then
			print("--- loading growthcontrol V"..growthcontrol.Version.." (c) by aPuehri|LS-Modcompany --- loading savegame ---");
			local key = "growthcontrol";
			local xmlFile = loadXMLFile("growthcontrol", savegameFolderPath .. "/growthcontrol.xml", key);
				if xmlFile ~= nil then
					for i=0, growthcontrol.maxnumfruits do
						local frName = growthcontrol.fruitnames[i];
						if (frName ~= nil) and (frName ~= "not used") then
							growthcontrol.growthhours[i] = getXMLFloat(xmlFile, "growthcontrol.fruit("..i..")#hours");
							growthcontrol.growthstatetime[i] = growthcontrol.growthhours[i]*3.6e6;
							growthcontrol.literPerSqm[i] = getXMLFloat(xmlFile, "growthcontrol.fruit("..i..")#literPerSqm");
							growthcontrol.seedUsagePerSqm[i] = getXMLFloat(xmlFile, "growthcontrol.fruit("..i..")#seedUsagePerSqm");
							local frIndex = g_fruitTypeManager.nameToIndex[string.upper(frName)];
							if (frIndex ~= nil) then
								g_fruitTypeManager.fruitTypes[frIndex].growthStateTime = growthcontrol.growthstatetime[i];
								if (growthcontrol.literPerSqm[i] ~= nil) and (growthcontrol.literPerSqm[i] >= 0.1) then
									g_fruitTypeManager.fruitTypes[frIndex].literPerSqm = growthcontrol.literPerSqm[i];
								else
									growthcontrol.literPerSqm[i] = g_fruitTypeManager.fruitTypes[frIndex].literPerSqm;
								end;
								if (growthcontrol.seedUsagePerSqm[i] ~= nil) and (growthcontrol.seedUsagePerSqm[i] >= 0.005) then
									g_fruitTypeManager.fruitTypes[frIndex].seedUsagePerSqm = growthcontrol.seedUsagePerSqm[i];
								else
									growthcontrol.seedUsagePerSqm[i] = g_fruitTypeManager.fruitTypes[frIndex].seedUsagePerSqm;
								end;
							end;
						end;
					end;
					growthcontrol.showHelp = getXMLBool(xmlFile, "growthcontrol.setting" .. "#showHelp");
					growthcontrol.weedUpdateFactor = getXMLFloat(xmlFile, "growthcontrol.setting" .. "#weedGrowthDelayFactor");
				end;
			delete(xmlFile);
		else
			print("--- loading growthcontrol V"..growthcontrol.Version.." (c) by aPuehri|LS-Modcompany --- loading initialvalues ---");		
			for i=0, growthcontrol.maxnumfruits do
				local frName = growthcontrol.fruitnames[i];
				if (frName ~= nil) and (frName ~= "not used") then
					local frIndex = g_fruitTypeManager.nameToIndex[string.upper(frName)];
					if (frIndex ~= nil) then
						growthcontrol.growthstatetime[i] = g_fruitTypeManager.fruitTypes[frIndex].growthStateTime;
						growthcontrol.growthhours[i] = growthcontrol.growthstatetime[i] / 3.6e6;
						growthcontrol.literPerSqm[i] = g_fruitTypeManager.fruitTypes[frIndex].literPerSqm;
						growthcontrol.seedUsagePerSqm[i] = g_fruitTypeManager.fruitTypes[frIndex].seedUsagePerSqm;
					end
					if growthcontrol.debug then					
						print("--- growthcontrol Debug ... growthcontrol:loadMap(frIndex["..tostring(frIndex).."]/fruit["..growthcontrol.fruitnames[i].."]/growthhours["..growthcontrol.growthhours[i].."]/litersPerSqm["..growthcontrol.literPerSqm[i].."]/seedUsagePerSqm["..growthcontrol.seedUsagePerSqm[i].."] ---");
					end;	
				end;
			end;
		end;

		--read values of fruit_density_growthState.xml and calculate remaining growthtime in minutes
		if fileExists(savegameFolderPath .. '/fruit_density_growthState.xml') then
			local key = "foliageCropsUpdater";
			local xmlFile = loadXMLFile("fruit_density_growthState", savegameFolderPath .. "/fruit_density_growthState.xml", key);
			local j = 0;
			for i=0, growthcontrol.maxnumfruits do
				local frName = growthcontrol.fruitnames[i];
				if (frName ~= nil) and (frName ~= "not used") then
					if (i == 0) then
						j = i;
					else
						j = j + 1;
					end;
					growthcontrol.growthremtime[i] = getXMLFloat(xmlFile, "foliageCropsUpdater.cropsState("..j..")#normalizedGrowthTimer");
					if growthcontrol.debug then
						print("--- growthcontrol Debug ... readed cropsState["..tostring(i).."] normalizedGrowthTimer="..tostring(growthcontrol.growthremtime[i]).." ---");
					end;					
					if (growthcontrol.growthremtime[i] ~= nil) and (growthcontrol.growthstatetime[i] ~= nil) then
						growthcontrol.growthremtime[i] = (growthcontrol.growthremtime[i] * growthcontrol.growthstatetime[i]) / 60000;
					else
						growthcontrol.growthremtime[i] = 1;
					end;				
					if growthcontrol.debug then
						print("--- growthcontrol Debug ... calculated Remaining Time["..growthcontrol.fruitnames[i].."]= "..(growthcontrol.growthremtime[i]/60).." hours ---");
					end;
				end;
			end;
			delete(xmlFile);						
		end;
		
		--read values of weed_growthState.xml and set growthtime of weed
		if g_currentMission.missionInfo.weedsEnabled then
			local weedGrowthStateTime = 30000000 * ((growthcontrol.growthhours[0]/6.67) * growthcontrol.weedUpdateFactor); --standard grothhours wheat=6.67
			if (weedGrowthStateTime > 30000000) then
				g_fruitTypeManager.fruitTypes[g_fruitTypeManager.nameToIndex["WEED"]].weed.growthStateTime = weedGrowthStateTime;
				if growthcontrol.debug then
					print("--- growthcontrol Debug ... set weedGrowthStateTime["..tostring(weedGrowthStateTime).."], weedUpdateFactor["..tostring(growthcontrol.weedUpdateFactor).."] ---");
				end;				
			end;
			
			if fileExists(savegameFolderPath .. '/weed_growthState.xml') then
				local key = "currentUpdateTime";
				local xmlFile = loadXMLFile("weed_growthState", savegameFolderPath .. "/weed_growthState.xml", key);
				local readUpdateTime = getXMLFloat(xmlFile, "terrainDetailUpdater#currentUpdateTime");
				if (readUpdateTime ~= nil) then
					growthcontrol.weedUpdateTime = getXMLFloat(xmlFile, "terrainDetailUpdater#currentUpdateTime");
				end;
				if growthcontrol.debug then
					print("--- growthcontrol Debug ... weed currentUpdateTime["..tostring(growthcontrol.weedUpdateTime).."] ---");
				end;
				delete(xmlFile);
			end;
		
			growthcontrol.weedRemTime = ((growthcontrol.weedUpdateTime / 60000) * g_currentMission.missionInfo.timeScale);
			if growthcontrol.debug then
				print("--- growthcontrol Debug ... weed RemainingTime["..tostring(growthcontrol.weedRemTime / 60).." h], actual timescale["..tostring(g_currentMission.missionInfo.timeScale).."] ---");
			end;
		end;
	else
		print("--- loading growthcontrol V"..growthcontrol.Version.." (c) by aPuehri|LS-Modcompany --- loading initialvalues ---");
		for i=0, growthcontrol.maxnumfruits do
			local frName = growthcontrol.fruitnames[i];
			if (frName ~= nil) and (frName ~= "not used") then
				local frIndex = g_fruitTypeManager.nameToIndex[string.upper(frName)];
				if (frIndex ~= nil) then
					growthcontrol.growthstatetime[i] = g_fruitTypeManager.fruitTypes[frIndex].growthStateTime
					growthcontrol.growthhours[i] = growthcontrol.growthstatetime[i] / 3.6e6;
					growthcontrol.literPerSqm[i] = g_fruitTypeManager.fruitTypes[frIndex].literPerSqm;
					growthcontrol.seedUsagePerSqm[i] = g_fruitTypeManager.fruitTypes[frIndex].seedUsagePerSqm;
				end;
				if growthcontrol.debug then					
					print("--- growthcontrol Debug ... growthcontrol:loadMap(frIndex["..tostring(frIndex).."]/fruit["..growthcontrol.fruitnames[i].."]/growthhours["..growthcontrol.growthhours[i].."]/litersPerSqm["..growthcontrol.literPerSqm[i].."]/seedUsagePerSqm["..growthcontrol.seedUsagePerSqm[i].."]");
				end;								
				if (growthcontrol.growthstatetime[i] ~= nil) then
					growthcontrol.growthremtime[i] = 1;			
					growthcontrol.growthremtime[i] = (growthcontrol.growthremtime[i] * growthcontrol.growthstatetime[i]) / 60000;
				end;
				if growthcontrol.debug then
					print("--- growthcontrol Debug ... calculated Remaining Time["..growthcontrol.fruitnames[i].."]= "..(growthcontrol.growthremtime[i]/60).." hours ---");			
				end
			end;
		end;		
	end;
	
	-- SetGrowthRate
	g_currentMission:setPlantGrowthRate(3); --normal
	local chSt = g_currentMission.inGameMenu.pageSettingsGame.checkPlantGrowthRate.canChangeState;
	if (chSt ~= nil)then
		g_currentMission.inGameMenu.pageSettingsGame.checkPlantGrowthRate.canChangeState = false; --not changeable
		g_currentMission.inGameMenu.pageSettingsGame.checkPlantGrowthRate.toolTipText = g_i18n:getText('growthToolTipText');
	end;
	
end;

function growthcontrol:registerActionEventsPlayer()
	-- growthcontrol Gui	
	local result, eventName = InputBinding.registerActionEvent(g_inputBinding, 'Gc_ToggleHud',self, growthcontrol.actionGcToggleHud ,false ,true ,false ,true)
	if result then
        g_inputBinding.events[eventName].displayIsVisible = growthcontrol.showHelp;
    end	
end;

function growthcontrol:removeActionEventsPlayer()
	growthcontrol.showHud = false;
end;

function growthcontrol:mouseEvent(posX, posY, isDown, isUp, button)
end;

function growthcontrol:keyEvent(unicode, sym, modifier, isDown)
end;

function growthcontrol:update(dt)
	if not g_currentMission.isSaving and growthcontrol.recalculate then
		if growthcontrol.debug then
			print("--- growthcontrol Debug ... growthcontrol initialized recalculation: isMultiplayer="..tostring(g_currentMission.missionDynamicInfo.isMultiplayer).." ,isServer="..tostring(g_currentMission:getIsServer()).." ---");
		end;
		if g_currentMission:getIsServer() then
			--load Savegame
			local savegameIndex = g_currentMission.missionInfo.savegameIndex;
			local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory;
			if savegameFolderPath == nil then
				savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), savegameIndex);
			end;

			--read values of fruit_density_growthState.xml and calculate remaining growthtime in minutes		
			if fileExists(savegameFolderPath .. '/fruit_density_growthState.xml') then
				local key = "foliageCropsUpdater";
				local xmlFile = loadXMLFile("fruit_density_growthState", savegameFolderPath .. "/fruit_density_growthState.xml", key);
				local j = 0;
				for i=0, growthcontrol.maxnumfruits do
					local frName = growthcontrol.fruitnames[i];
					if (frName ~= nil) and (frName ~= "not used") then
						if (i == 0) then
							j = i;
						else
							j = j + 1;
						end;
						growthcontrol.growthremtime[i] = getXMLFloat(xmlFile, "foliageCropsUpdater.cropsState("..j..")#normalizedGrowthTimer");
						if growthcontrol.debug then
							print("--- growthcontrol Debug ... readed cropsState["..tostring(i).."] normalizedGrowthTimer="..tostring(growthcontrol.growthremtime[i]).." ---");
						end;					
						if (growthcontrol.growthremtime[i] ~= nil) and (growthcontrol.growthstatetime[i] ~= nil) then
							growthcontrol.growthremtime[i] = (growthcontrol.growthremtime[i] * growthcontrol.growthstatetime[i]) / 60000;
						else
							growthcontrol.growthremtime[i] = 1;
						end;				
						if growthcontrol.debug then
							print("--- growthcontrol Debug ... calculated Remaining Time["..growthcontrol.fruitnames[i].."]= "..(growthcontrol.growthremtime[i]/60).." hours ---");
						end;
					end;
				end;
				delete(xmlFile);
				growthcontrol.recalculate = false;
			end;
			
			--read values of weed_growthState.xml and set growthtime of weed
			if g_currentMission.missionInfo.weedsEnabled then
				if fileExists(savegameFolderPath .. '/weed_growthState.xml') then
					local key = "currentUpdateTime";
					local xmlFile = loadXMLFile("weed_growthState", savegameFolderPath .. "/weed_growthState.xml", key);
					local readUpdateTime = getXMLFloat(xmlFile, "terrainDetailUpdater#currentUpdateTime");
					if (readUpdateTime ~= nil) then
						growthcontrol.weedUpdateTime = getXMLFloat(xmlFile, "terrainDetailUpdater#currentUpdateTime");
					end;
					if growthcontrol.debug then
						print("--- growthcontrol Debug ... readed weed currentUpdateTime["..tostring(growthcontrol.weedUpdateTime).."] ---");
					end;
					growthcontrol.weedRemTime = ((growthcontrol.weedUpdateTime / 60000) * g_currentMission.missionInfo.timeScale);
					if growthcontrol.debug then
						print("--- growthcontrol Debug ... calculated weed RemainingTime["..tostring(growthcontrol.weedRemTime / 60).." h] ---");
					end;
					delete(xmlFile);				
				end;
			end;
			
			-- Multiplayer Sync
			gcMultiplayerSyncEvent.sendEvent();			
		end;
	end;
end

function growthcontrol:draw()
	if g_currentMission.paused or not growthcontrol.showHud then	
		return;
	end;
	
	--respect settings for other mods
	setTextAlignment(0);
	setTextColor(1, 1, 1, 1);
	setTextBold(false);
	
	growthcontrol.tPosBgOverlayId:render();
	growthcontrol.tPosTopOverlayId:render();
	growthcontrol.tPosLeOverlayId:render();
	growthcontrol.tPosRiOverlayId:render();
	growthcontrol.tPosBoOverlayId:render();

	setTextAlignment(growthcontrol.tPos.alignment);
	setTextBold(true);
	renderText(growthcontrol.tPos.x, growthcontrol.tPos.y, growthcontrol.tPos.size , g_i18n:getText('growthstate'));
	setTextBold(false);
	local yPos = growthcontrol.tPos.y - growthcontrol.tPos.size - growthcontrol.tPos.spacing;
	for i=0, growthcontrol.maxnumfruits do
		local frName = growthcontrol.fruitnames[i];
		if (frName ~= nil) and (frName ~= "not used") then
			local frName = g_fruitTypeManager.fruitTypeIndexToFillType[g_fruitTypeManager.nameToIndex[string.upper(frName)]].title;
			if frName == nil then
				frName = growthcontrol.fruitnames[i];
			end;
			if (growthcontrol.growthremtime[i]/60 <= 2.0) and (growthcontrol.growthremtime[i]/60 > 1.0) then
				setTextColor(0.8879, 0.1878, 0.0037, 1);
			elseif (growthcontrol.growthremtime[i]/60 <= 1.0) then
				setTextColor(0.8796, 0.0061, 0.004, 1);
			else
				setTextColor(1,1,1,1);
			end;	
			renderText(growthcontrol.tPos.x, yPos, growthcontrol.tPos.size , tostring(frName).." = "..(string.format("%.4f",growthcontrol.growthremtime[i]/60)).." "..g_i18n:getText('growthhour'));
			yPos = yPos - growthcontrol.tPos.size - growthcontrol.tPos.spacing;
		end;	
	end;
	if g_currentMission.missionInfo.weedsEnabled then
		local frName = g_fruitTypeManager.fruitTypeIndexToFillType[g_fruitTypeManager.nameToIndex["WEED"]].title;
		setTextColor(0.76078, 0.51765, 0.69020, 1);
		renderText(growthcontrol.tPos.x, yPos, growthcontrol.tPos.size , tostring(frName).." = "..(string.format("%.4f",growthcontrol.weedRemTime / 60)).." "..g_i18n:getText('growthhour'));
	end;
	
	--respect settings for other mods
	setTextAlignment(0);
	setTextColor(1, 1, 1, 1);
	setTextBold(false);	
end;

function growthcontrol:deleteMap()
	growthcontrol.showHud = false;
	growthcontrol.recalculate = false;
end

function growthcontrol:minuteChanged()
	local reqSync = false;
	if growthcontrol.debug then
		print("--- growthcontrol Debug ... growthcontrol.minuteChanged: isMultiplayer="..tostring(g_currentMission.missionDynamicInfo.isMultiplayer).." ,isServer="..tostring(g_currentMission:getIsServer()).." ---");
	end;
	-- fruits
	for i=0, growthcontrol.maxnumfruits do
		local frName = growthcontrol.fruitnames[i];
		if (frName ~= nil) and (frName ~= "not used") then	
			if (growthcontrol.growthremtime[i] > 0) then
				growthcontrol.growthremtime[i] = growthcontrol.growthremtime[i]-1;	
				if growthcontrol.debug then
					print("--- growthcontrol Debug ... Remaining Time["..growthcontrol.fruitnames[i].."]= "..(growthcontrol.growthremtime[i]/60).." Stunden ---");
				end;
			else
				growthcontrol.growthremtime[i] = growthcontrol.growthstatetime[i] / 60000;
				reqSync = true; -- ToDo Multiplayer Sync
				if growthcontrol.debug then
					print("--- growthcontrol Debug ... Restart Remaining Time["..growthcontrol.fruitnames[i].."]= "..(growthcontrol.growthremtime[i]/60).." Stunden ---");
				end;
			end;			
		end;
	end;
	-- weed
	if g_currentMission.missionInfo.weedsEnabled then
		if (growthcontrol.weedRemTime > 0) then
			growthcontrol.weedRemTime = growthcontrol.weedRemTime - 1;
			if growthcontrol.debug then
				print("--- growthcontrol Debug ... weed RemainingTime["..tostring(growthcontrol.weedRemTime / 60).." Stunden] ---");
			end;		
		else
			local updateTime = 30000000 * ((growthcontrol.growthhours[0]/6.67) * growthcontrol.weedUpdateFactor);
			if (updateTime > 30000000) then
				growthcontrol.weedRemTime = updateTime / 60000;
			end;
			if growthcontrol.debug then
				print("--- growthcontrol Debug ... weed Restart RemainingTime["..tostring(growthcontrol.weedRemTime / 60).." Stunden] ---");
			end;			
		end;
	end;
		
	-- Multiplayer Sync
	if reqSync then
		gcMultiplayerSyncEvent.sendEvent();
		reqSync = false;
	end;
end;

function growthcontrol:saveSettings()
	if growthcontrol.debug then
		print ("growthcontrol:saveSettings");
	end;	
	local savegameIndex = g_currentMission.missionInfo.savegameIndex;
	local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory;
	if savegameFolderPath == nil then
		savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), savegameIndex);
	end;
	
	local key = "growthcontrol"; 
	local xmlFile = createXMLFile("growthcontrol", savegameFolderPath .. "/growthcontrol.xml", key);
		
	for i=0, growthcontrol.maxnumfruits do
		setXMLString(xmlFile, "growthcontrol.fruit("..i..")#name",growthcontrol.fruitnames[i]);
		if (growthcontrol.fruitnames[i] ~= "not used") then
			setXMLFloat(xmlFile, "growthcontrol.fruit("..i..")#hours",growthcontrol.growthhours[i]);
			setXMLFloat(xmlFile, "growthcontrol.fruit("..i..")#literPerSqm",growthcontrol.literPerSqm[i]);
			setXMLFloat(xmlFile, "growthcontrol.fruit("..i..")#seedUsagePerSqm",growthcontrol.seedUsagePerSqm[i]);
		end;
	end;
	setXMLBool(xmlFile, "growthcontrol.setting" .. "#showHelp",growthcontrol.showHelp);
	setXMLFloat(xmlFile, "growthcontrol.setting" .. "#weedGrowthDelayFactor",growthcontrol.weedUpdateFactor);
	
	saveXMLFile(xmlFile);
	delete(xmlFile);		

	growthcontrol.recalculate = true;
end;

function growthcontrol:actionGcToggleHud(actionName, keyStatus, arg3, arg4, arg5)
	--showHud
	if not g_currentMission.paused and not growthcontrol.showHud then
		growthcontrol.showHud = true;
	elseif growthcontrol.showHud then
		growthcontrol.showHud = false;
	end;	
end;

-- *****+++++*****+++++ Multiplayer *****+++++*****+++++
local origServerSendObjects = Server.sendObjects;

function Server:sendObjects(connection, x, y, z, viewDistanceCoeff)
	connection:sendEvent(gcMultiplayerJoinEvent:new());
	return origServerSendObjects(self, connection, x, y, z, viewDistanceCoeff);
end;

gcMultiplayerJoinEvent = {};
gcMultiplayerJoinEvent_mt = Class(gcMultiplayerJoinEvent, Event);
InitEventClass(gcMultiplayerJoinEvent, 'gcMultiplayerJoinEvent');

function gcMultiplayerJoinEvent:emptyNew()
	local self = Event:new(gcMultiplayerJoinEvent_mt);
	self.className = 'growthcontrol.gcMultiplayerJoinEvent';
	return self;
end;

function gcMultiplayerJoinEvent:new()
	local self = gcMultiplayerJoinEvent:emptyNew()
	return self;
end;

-- Send data from the server to the client gcMultiplayerJoinEvent
function gcMultiplayerJoinEvent:writeStream(streamId, connection)
	if not connection:getIsServer() then	
		for i=0, growthcontrol.maxnumfruits do
			local frName = growthcontrol.fruitnames[i];
			if (frName ~= nil) and (frName ~= "not used") then
				streamWriteFloat32(streamId, growthcontrol.growthremtime[i]);
				streamWriteFloat32(streamId, growthcontrol.growthstatetime[i]);
				if growthcontrol.debug then
					print("--- growthcontrol Debug ... sending data to joining client: "..tostring(growthcontrol.growthremtime[i]).." , "..tostring(growthcontrol.growthstatetime[i]).." ---");
				end;				
			end;
		end;
		streamWriteFloat32(streamId, growthcontrol.weedUpdateFactor);
		streamWriteFloat32(streamId, growthcontrol.weedRemTime);
		if growthcontrol.debug then
			print("--- growthcontrol Debug ... sending data to joining client: weedUpdateFactor["..tostring(growthcontrol.weedUpdateFactor).."], weed RemainingTime["..tostring(growthcontrol.weedRemTime / 60).."h] ---");
		end;		
	end;
end;

-- Read from the server gcMultiplayerJoinEvent
function gcMultiplayerJoinEvent:readStream(streamId, connection)
	if connection:getIsServer() then
		for i=0, growthcontrol.maxnumfruits do
			local frName = growthcontrol.fruitnames[i];
			if (frName ~= nil) and (frName ~= "not used") then
				growthcontrol.growthremtime[i] = streamReadFloat32(streamId);
				growthcontrol.growthstatetime[i] = streamReadFloat32(streamId);
				if growthcontrol.debug then
					print("--- growthcontrol Debug ... reading data from server: "..tostring(growthcontrol.growthremtime[i]).." , "..tostring(growthcontrol.growthstatetime[i]).." ---");
				end;				
			end;
		end;	
	end;
	growthcontrol.weedUpdateFactor = streamReadFloat32(streamId);
	growthcontrol.weedRemTime = streamReadFloat32(streamId);
	if growthcontrol.debug then
		print("--- growthcontrol Debug ... reading data from server: weedUpdateFactor["..tostring(growthcontrol.weedUpdateFactor).."], weed RemainingTime["..tostring(growthcontrol.weedRemTime / 60).."h] ---");
	end;	
end;

gcMultiplayerSyncEvent = {};
gcMultiplayerSyncEvent_mt = Class(gcMultiplayerSyncEvent, Event);
InitEventClass(gcMultiplayerSyncEvent, 'gcMultiplayerSyncEvent');

function gcMultiplayerSyncEvent:emptyNew()
	local self = Event:new(gcMultiplayerSyncEvent_mt);
	self.className = 'growthcontrol.gcMultiplayerSyncEvent';
	return self;
end;

function gcMultiplayerSyncEvent:new()
	local self = gcMultiplayerSyncEvent:emptyNew()
	return self;
end;

-- Send data from the server to the client gcMultiplayerSyncEvent
function gcMultiplayerSyncEvent:writeStream(streamId, connection)
	if not connection:getIsServer() then	
		for i=0, growthcontrol.maxnumfruits do
			local frName = growthcontrol.fruitnames[i];
			if (frName ~= nil) and (frName ~= "not used") then
				streamWriteFloat32(streamId, growthcontrol.growthremtime[i]);
				if growthcontrol.debug then
					print("--- growthcontrol Debug ... sending sync data to client: "..tostring(growthcontrol.growthremtime[i]).." ---");
				end;				
			end;
		end;
	end;
	streamWriteFloat32(streamId, growthcontrol.weedRemTime);
	if growthcontrol.debug then
		print("--- growthcontrol Debug ... sending sync data to client: weed RemainingTime["..tostring(growthcontrol.weedRemTime / 60).."h] ---");
	end;	
end;

-- Read from the server gcMultiplayerSyncEvent
function gcMultiplayerSyncEvent:readStream(streamId, connection)
	if connection:getIsServer() then
		for i=0, growthcontrol.maxnumfruits do
			local frName = growthcontrol.fruitnames[i];
			if (frName ~= nil) and (frName ~= "not used") then
				growthcontrol.growthremtime[i] = streamReadFloat32(streamId);
				if growthcontrol.debug then
					print("--- growthcontrol Debug ... reading sync data from server: "..tostring(growthcontrol.growthremtime[i]).." ---");
				end;				
			end;
		end;	
	end;
	growthcontrol.weedRemTime = streamReadFloat32(streamId);
	if growthcontrol.debug then
		print("--- growthcontrol Debug ... reading sync data from server: weed RemainingTime["..tostring(growthcontrol.weedRemTime / 60).."h] ---");
	end;	
end;

function gcMultiplayerSyncEvent:sendEvent()
	if g_currentMission.missionDynamicInfo.isMultiplayer and g_currentMission:getIsServer() then
		if (g_server ~= nil) then
			g_server:broadcastEvent(gcMultiplayerSyncEvent:new());
		end;
	end;
end

-- *****+++++*****+++++ Multiplayer *****+++++*****+++++

addModEventListener(growthcontrol);