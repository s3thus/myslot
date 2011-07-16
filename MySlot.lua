MySlot = LibStub:NewLibrary("MySlot-4.0", 4)

local crc32 = LibStub:GetLibrary('CRC32-1.0')
local base64 = LibStub:GetLibrary('BASE64-1.0')

local MYSLOT_AUTHOR = "T.G. <farmer1992@gmail.com>"

local MYSLOT_VER = 10
local MYSLOT_ALLOW_VER = {MYSLOT_VER, 6}
local MYSLOT_IS_DEBUG = true

-- 不能大于 7 不含
local MYSLOT_SPELL = 1
local MYSLOT_ITEM = 4
local MYSLOT_MACRO = 3
local MYSLOT_FLYOUT = 5
local MYSLOT_EQUIPMENTSET = 6
local MYSLOT_EMPTY = 0
local MYSLOT_NOTFOUND = "notfound"

MySlot.SLOT_TYPE = {
	["spell"] = MYSLOT_SPELL,
	["companion"] = MYSLOT_SPELL,
	["macro"]= MYSLOT_MACRO,
	["item"]= MYSLOT_ITEM,
	["flyout"] = MYSLOT_FLYOUT,	
	["petaction"] = MYSLOT_EMPTY,
	["futurespell"] = MYSLOT_EMPTY,
	["equipmentset"] = MYSLOT_EQUIPMENTSET,
	[MYSLOT_NOTFOUND] = MYSLOT_EMPTY,
}

local MYSLOT_SLOT_B_SIZE = 4
local MYSLOT_BIND_B_SIZE = 4

local MYSLOT_DEFAULT_MACRO_ID = "QUESTIONMARK"
local function GetMacroIconTable()
	local t = {
		[MYSLOT_DEFAULT_MACRO_ID] = 1
	}
	for i =1,GetNumMacroIcons() do
		t[GetMacroIconInfo(i)] = i
	end
	return t
end
MySlot.MACRO_ICON_TABLE = GetMacroIconTable()

-- return item count merge into target
local function MergeTable(target, source)
	if source then
		assert(type(target) == 'table' and type(source) == 'table')
		for _,b in ipairs(source) do
			target[#target+1] = b
		end
		return #source
	else
		return 0
	end
end

--[[function MySlot:Debug()
	_,_, body = GetMacroInfo("a")
end
]]

function MySlot:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|CFFFF0000<|r|CFFFFD100My Slot 4 beta|r|CFFFF0000>|r"..(msg or "nil"))
end

function MySlot:GetMacroInfo(macroId)
	-- {macroId ,icon high 8, icon low 8 , namelen, ..., bodylen, ...}

	local name, iconTexture, body, isLocal = GetMacroInfo(macroId)
	
	if not name then
		return nil
	end

	local t = {macroId}	
	iconTexture = MySlot.MACRO_ICON_TABLE[iconTexture or MYSLOT_DEFAULT_MACRO_ID]

	-- icon
	t[#t+1] = bit.rshift(iconTexture,8)
	t[#t+1] = bit.band(iconTexture, 255)

	-- name
	local namelen = string.len(name)
	t[#t + 1] = namelen
	MergeTable(t, {string.byte(name ,1 ,namelen)})

	-- body
	local bodylen = string.len(body)
	t[#t + 1] = bodylen 
	MergeTable(t, {string.byte(body , 1 , bodylen)})
	
	return t
end

function MySlot:GetActionInfo(slotId)
	-- { slotId, slotType and high 16 ,high 8 , low 8, }
	local slotType, index = GetActionInfo(slotId)
	if MySlot.SLOT_TYPE[slotType] == MYSLOT_EQUIPMENTSET then
		_, index = GetEquipmentSetInfoByName(index)
		index = index + 1
	elseif not MySlot.SLOT_TYPE[slotType] then
		if slotType then 
			self:Print("[WARN]忽略不支持的按键类型[" .. slotType .."] 请通知作者" .. MYSLOT_AUTHOR)
		end
		return nil
	end
	return { slotId, MySlot.SLOT_TYPE[slotType] * 32 + bit.rshift(index ,16) , bit.rshift(index,8) , bit.band(index, 255) }
end


local function KeyToByte(key , command)
	-- {mod , key , command high 8, command low 8}
	if not key then
		return nil
	end

	local mod,key = nil, key
	local t = {}
	local _,_,_mod,_key = string.find(key ,"(.+)-(.+)") 
	if _mod and _key then
		mod, key = _mod, _key
	end

	if not MySlot.KEYS[key] then
		MySlot:Print("[WARN]忽略不支持的绑定 K = [" .. key .."] 请通知作者" .. MYSLOT_AUTHOR)
		return nil
	end
	mod = mod or "NONE"

	if not MySlot.MOD_KEYS[mod] then
		MySlot:Print("[WARN]忽略不支持的绑定 MK = [" .. key .."] 请通知作者" .. MYSLOT_AUTHOR)
		return nil
	end

	t[#t+1] = MySlot.MOD_KEYS[mod]
	t[#t+1] = MySlot.KEYS[key]

	t[#t+1] = bit.rshift(command,8)
	t[#t+1] = bit.band(command, 255)

	return t
end

function MySlot:GetBindingInfo(index)
	-- might more than 1
	local t = {}
	local _command, key1, key2 = GetBinding(index)
	local command = MySlot.BINDS[_command]

	if not command then
		MySlot:Print("[WARN]忽略不支持的绑定 C = [" .. _command .."] 请通知作者" .. MYSLOT_AUTHOR)
		return nil
	end

	MergeTable(t, KeyToByte(key1, command))
	MergeTable(t, KeyToByte(key2, command))

	return #t > 0 and t or nil
end

function MySlot:Export()
	-- ver nop nop nop crc32 crc32 crc32 crc32
	local i
	local t = {MYSLOT_VER,86,04,22,0,0,0,0}
	
	local head = 9
	-- macro
	-- name limit to 16 and body limit to 255 
	-- (16 + 255 )* 3 *54 < 2 ^ 16 
	local c = 0
	t[head] = 0
	t[head + 1] = 0
	for i = 1,54 do
		c = c + MergeTable(t, self:GetMacroInfo(i))
	end
	t[head] = bit.rshift(c,8)
	t[head + 1] = bit.band(c, 255)

	-- move head
	head = head + c + 2

	-- spell
	t[head] = 0
	local c = 0
	for i = 1,120 do
		c = c + MergeTable(t,self:GetActionInfo(i)) / MYSLOT_SLOT_B_SIZE
	end
	t[head] = c

	-- move head
	head = head + c*4 + 1

	-- keys
	t[head] = 0
	t[head + 1] = 0
	local c = 0
	for i = 1,GetNumBindings() do
		c = c + MergeTable(t,self:GetBindingInfo(i)) / MYSLOT_BIND_B_SIZE
	end
	t[head] = bit.rshift(c,8)
	t[head + 1] = bit.band(c, 255)

	-- crc
	local crc = crc32.enc(t)
	t[5] = bit.rshift(crc , 24)
	t[6] = bit.band(bit.rshift(crc , 16), 255)
	t[7] = bit.band(bit.rshift(crc , 8) , 255)
	t[8] = bit.band(crc , 255)
	
	local s=""
	s = "@ --------------------\n"..s
	s = "@ 问题/建议请联系 farmer1992@gmail.com\n"..s
	s = "@ \n"..s
	s = "@ 等级："..UnitLevel("player").."\n"..s
	s = "@ 职业："..UnitClass("player").."\n"..s
	s = "@ 人物："..UnitName("player").."\n"..s
	-- s = "@ 天赋："..select(3,GetTalentTabInfo(1)).."/"..select(3,GetTalentTabInfo(2)).."/"..select(3,GetTalentTabInfo(3)).."\n"..s
	s = "@ Myslot 导出数据"..date().."\n"..s

	s = s..base64.enc(t)
	MYSLOT_ReportFrame_EditBox:SetText(s)
	MYSLOT_ReportFrame_EditBox:HighlightText()
end

function MySlot:Import()
	if InCombatLockdown() then
		MySlot:Print("请在非战斗时候使用导入功能")
		return
	end

	local s = MYSLOT_ReportFrame_EditBox:GetText() or ""
	s = string.gsub(s,"(@.[^\n]*\n)","")
	s = string.gsub(s,"\n","")
	s = string.gsub(s,"\r","")
	s = base64.dec(s)
	
	if #s < 8  then
		MySlot:Print("导入字符不合法 [TEXT]")
		return
	end

	StaticPopupDialogs["MYSLOT_MSGBOX"].OnAccept = function()
		MySlot:RecoverData(s)
	end
	StaticPopup_Show("MYSLOT_MSGBOX")
end

function MySlot:FindOrCreateMacro(macroInfo)
	local localIndex = macroInfo["localindex"]

	if localIndex then
		return localIndex
	else
		local id = macroInfo["oldid"]
		local name = macroInfo["name"]
		local icon = macroInfo["icon"]
		local body = macroInfo["body"]
		local numglobal,numperchar = GetNumMacros()
		local perchar = id > 36 and 1 or 0

		local newid = CreateMacro(name, icon, body, perchar , 1)
		if not newid then
			self:Print("宏 ["..name.." ] 被忽略，请检查是否有足够的空格创建宏")
			return nil
		else
			return newid
		end
	end
end

function MySlot:RecoverData(s)

	local ver = s[1]
	local crc = s[5] * 2^24 + s[6] * 2^16 + s[7] * 2^8 + s[8]
	s[5], s[6], s[7] ,s[8] = 0, 0 ,0 ,0
	
	if ( crc ~= crc32.enc(s)) then
		MySlot:Print("导入字符码校验不合法 [CRC32]")
		return 
	end

	if not tContains(MYSLOT_ALLOW_VER,ver) then
		MySlot:Print("导入串版本不兼容当前Myslot版本 导入版本号" .. ver )
		return 
	end
	
	--cache spells
	local spells = {}
	local i = 1
	while true do
		local spellType, spellId = GetSpellBookItemInfo(i, BOOKTYPE_SPELL)
		if not spellType then
			break 
		end
		
		spells[MySlot.SLOT_TYPE[string.lower(spellType)] .. "_" .. spellId] = i
		i = i + 1
	end 

	-- cache local macro index
	local localMacro = {}
	for i = 1,54 do
		local name, _, body = GetMacroInfo(i)
		if name then
			localMacro[ name .. "_" .. body ] = i
			localMacro[ body ] = i
		end
	end

	-- cache macro
	local macro = {}
	local macroSize = s[9] * 256 + s[10] -- hard code :P
	local head = 11
	local tail = head +  macroSize -- * 1
	i = head
	while i < tail - 1 do
		macroId = s[i]
		icon = s[i+1] * 256 + s[i+2]

		-- move to name
		i = i + 3

		local namelen = s[i]
		local name = {}
		for j = i + 1,i + namelen do
			name[#name+1] = s[j]
		end
		local name = string.char(unpack(name))
		
		-- move to body
		i = i + namelen + 1

		local bodylen = s[i]
		local body = {}
		for j = i + 1,i + bodylen do
			body[#body+1] = s[j]
		end
		local body = string.char(unpack(body))

		-- move to next block
		i = i + bodylen + 1

		macro[macroId] = {
			["oldid"] = macroId,
			["name"] = name,
			["icon"] = icon,
			["body"] = body,
			["localindex"] = localMacro[ name .. "_" .. body ] or localMacro[ body ]
		}
	end

	local spellCount = s[tail]
	head = tail + 1 -- 1 bit for spellCount
	tail = spellCount * MYSLOT_SLOT_B_SIZE + head

	for i = head, tail - 1 ,4 do
		local slotId = s[i]
		local slotType = bit.rshift(s[i+1], 5)
		local index = bit.band(s[i+1],31) * 65536  + (s[i+2] * 256 + s[i+3])
		
		local curType, curIndex = GetActionInfo(slotId)
		curType = MySlot.SLOT_TYPE[curType or MYSLOT_NOTFOUND]
		if curIndex ~= index or curType ~= slotType or slotType == MYSLOT_MACRO then -- macro always test
			if slotType == MYSLOT_SPELL or slotType == MYSLOT_FLYOUT then
				local newId = spells[slotType .."_" ..index]
				if newId then
					PickupSpellBookItem(newId, BOOKTYPE_SPELL)
				else
					MySlot:Print("忽略未掌握技能：" .. GetSpellLink(index))	
				end
			elseif slotType == MYSLOT_ITEM then
				PickupItem(index)
			elseif slotType == MYSLOT_MACRO then
				PickupMacro(self:FindOrCreateMacro(macro[index]))
			elseif slotType == MYSLOT_EMPTY then
				PickupAction(slotId)
			elseif slotType == MYSLOT_EQUIPMENTSET then
				PickupEquipmentSet(slotId)
			end
			PlaceAction(slotId)	
			ClearCursor()
		end
	end

	local bindCount = s[tail] * 256 + s[tail + 1]
	head = tail + 2 -- 2 bit for bindCount
	tail = bindCount * MYSLOT_BIND_B_SIZE + head
	
	local mode = GetCurrentBindingSet()
	for i = head, tail - 1 ,4 do
		local mod,key,command = MySlot.R_MOD_KEYS[s[i]] , MySlot.R_KEYS[s[i+1]] , MySlot.R_BINDS[s[i+2]*256 + s[i+3]]
		local key = ( mod ~= "NONE" and (mod .. "-") or "" ) .. key
		SetBinding(key ,command, mode)
	end
	SaveBindings(mode)


	MySlot:Print("所有按钮及按键邦定位置恢复完毕")
end

SlashCmdList["Myslot"] = function()
	MYSLOT_ReportFrame:Show()
end
SLASH_Myslot1 = "/Myslot"

StaticPopupDialogs["MYSLOT_MSGBOX"] = {
	text = "你 确定 要导入么？？？",
	button1 = "确定",
	button2 = "取消",
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	multiple = 1,
}
