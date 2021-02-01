-- ------------------------------------------------------------------------------ --
--                                   Bagonizer                                    --
-- ------------------------------------------------------------------------------ --
-- Set up frames and other local variables
local bgnzr = CreateFrame("FRAME")
bgnzr:RegisterEvent("PLAYER_ENTERING_WORLD")
bgnzr:RegisterEvent("ADDON_LOADED")
bgnzr:RegisterEvent("MERCHANT_SHOW")

local AddonPath = "Interface\\AddOns\\Bagonizer\\"
local Config = {}
local Show = {}
local Hide = {}
local BgnzrDB = {}


-- ============================================================================
-- Utility Functions
-- ============================================================================

function contains(list, item)
    for _, v in pairs(list) do
        if v == item then
            return true
        end
    end
    return false
end

-- Settings
function Config.Save()
    BagonizerDB = BgnzrDB
end

function Config.Load()
    if not BagonizerDB then
        BagonizerDB = {
            ["threshold"] = 5000000, -- stored in copper
            ["priceSource"] = "DBMarket"
        }
        BgnzrDB = BagonizerDB
    else
        BgnzrDB = BagonizerDB
    end
end


-- ============================================================================
-- Module Functions
-- ============================================================================

-- Textures
local function SetTexture(itemButton, texturePath, textureType, position, xOffset, yOffset)
    local texture = itemButton:CreateTexture(nil, tostring(textureType))
    texture:SetTexture(tostring(texturePath))
    texture:SetPoint(tostring(position), xOffset, yOffset)
    return texture
end

function Show.Coins(itemButton)
    itemButton.coins = SetTexture(itemButton, AddonPath .. "media\\vendor", "OVERLAY", "TOPLEFT", 1, -1.5)
    itemButton.coins:Show()
end

function Show.Disenchants(itemButton)
    itemButton.disenchant = SetTexture(itemButton, AddonPath .. "media\\disenchant", "OVERLAY", "TOPLEFT", 1, -1.5)
    itemButton.disenchant:Show()
end

function Hide.Coins(itemButton)
    if itemButton.coins then
        itemButton.coins:Hide()
    end
end

function Hide.Disenchants(itemButton)
    if itemButton.disenchant then
        itemButton.disenchant:Hide()
    end
end

local function getContainerFrame(bagID, slots, slotIndex)
    if IsAddOnLoaded("ElvUI") and _G["ElvUI_ContainerFrame"] then
        return "ElvUI_ContainerFrameBag" .. bagID .. "Slot" .. slotIndex
        -- "ElvUI_BankContainerFrame"
    else
        return "ContainerFrame" .. bagID + 1 .. "Item" .. slots - slotIndex + 1
    end
end

local function isItemSoulbound(bagID, slotIndex)
    local item = Item:CreateFromBagAndSlot(bagID, slotIndex)
    local isSoulbound = C_Item.IsBound(item:GetItemLocation())
    return isSoulbound
end

local function markItems()
    for bagID = 0, 4 do
        local bagSlots = GetContainerNumSlots(bagID)
        for bagSlot = 1, bagSlots do
            repeat

                local quality, _, _, itemLink, _, _, itemID = select(4, GetContainerItemInfo(bagID, bagSlot))
                local containerFrame = getContainerFrame(bagID, slots, bagSlot)
                local itemButton = _G[containerFrame]

                -- Clear any existing textures
                Hide.Coins(itemButton)
                Hide.Disenchants(itemButton)

                if not itemID then -- does the itemID exist
                    break
                end

                local sellPrice, classID, subclassID, bindType =
                    select(11, GetItemInfo(Item:CreateFromBagAndSlot(bagID, bagSlot):GetItemLink()))

                if quality > 4 or quality < 2 then -- uncommon, rare or epic quality
                    break
                end

                if classID ~= LE_ITEM_CLASS_ARMOR and classID ~= LE_ITEM_CLASS_WEAPON then -- armor or weapon class
                    break
                end

                if subclassID == LE_ITEM_ARMOR_COSMETIC then -- not cosmetic subclass
                    break
                end

                if contains({LE_ITEM_BIND_NONE, LE_ITEM_BIND_QUEST}, bindType) then -- not quest item, or no bind type
                    break
                end

                local itemString = TSM_API.ToItemString(itemLink)
                local itemValue = TSM_API.GetCustomPriceValue(BgnzrDB.priceSource, itemString)
                local itemDestroyValue = TSM_API.GetCustomPriceValue("Destroy", itemString)

                if sellPrice < 1 then -- is item vendorable? noValue doesn't catch Legendary base items or marks of honor
                    break
                end

                if itemValue and itemValue > BgnzrDB.threshold then -- should item be auctioned?
                    break
                end

                if sellPrice > itemDestroyValue then -- vendor item
                    Show.Coins(itemButton)
                else -- disenchant item
                    Show.Disenchants(itemButton)
                end

            until true
        end
    end
end


-- ============================================================================
-- Slash-Command & Event Handlers
-- ============================================================================

-- Handle events
local function handleEvent(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "Bagonizer" then
        bgnzr:UnregisterEvent("ADDON_LOADED")
        Config.Load()

    elseif event == "PLAYER_ENTERING_WORLD" then
        bgnzr:RegisterEvent("BAG_UPDATE")
        bgnzr:RegisterEvent("BAG_OPEN")
        markItems()

    elseif event == "BAG_UPDATE" or event == "BAG_OPEN" then
        markItems()

    elseif event == "PLAYER_LOGOUT" or event == "PLAYER_LEAVING_WORLD" then
        Config.Save()
    end
end

bgnzr:SetScript("OnEvent", handleEvent)

local function DispatchCommand(message, commandTable)
    local command, parameters = string.split(" ", message, 2)
    local entry = commandTable[command:lower()]
    local entryType = type(entry)

    if entryType == "function" then
        entry(parameters)

    elseif entryType == "table" then
        DispatchCommand(parameters or "", entry)

    elseif entryType == "string" then
        print(entry)

    elseif message ~= "help" then
        DispatchCommand("help", commandTable)

    end
end

local Commands = {
    ["threshold"] = function(arg)
        if tonumber(arg) then
            BgnzrDB.threshold = arg * 10000
            print("Threshold was updated to: " .. tostring(TSM_API.FormatMoneyString(BgnzrDB.threshold)))
            markItems()
        else
            print("Threshold: " .. tostring(TSM_API.FormatMoneyString(BgnzrDB.threshold)))
        end
    end,
    ["pricesource"] = function(arg)
        if arg then
            BgnzrDB.priceSource = arg
            print("Price Source was updated to: " .. tostring(BgnzrDB.priceSource))
            markItems()
        else
            print("Price Source: " .. tostring(BgnzrDB.priceSource))
        end
    end,
    ["help"] = "Bagonizer Help:\n  /bgr threshold <value> - Items below this gold value will be checked for vendoring or disenchanting.\n  /bgr pricesource <value> - The price source used to mark items."
}

SLASH_BAGONIZER1 = "/bagonizer"
SLASH_BAGONIZER2 = "/bgr"
SlashCmdList["BAGONIZER"] = function(message)
    DispatchCommand(message, Commands)
end

SLASH_UTILS1 = "/rl"
SlashCmdList["UTILS"] = function()
    ReloadUI()
end
