local utils = Ext.Require("utils.lua")

function Get(ID_name)
	return Mods.BG3MCM.MCMAPI:GetSettingValue(ID_name, ModuleUUID)
end

-- Define global variables
HasPrinted = {}

ModuleUUID = "c19ca43a-c3c7-4e58-9d00-f7d928e72074"

EASY = {
            DIFFICULTY = "Easy",
            LOCATIONS = { "WLD_Main_A" },
            HEAL_STATUS = "FOOD_FRUIT_GOODBERRY",
            UUID = "23158926-5f3e-4997-a04e-bbebdd914e13"
        }

NORMAL = {  DIFFICULTY = "Normal",
            LOCATIONS = { "CRE_Main_A", "SCL_Main_A", "BGO_Main_A" },
            HEAL_STATUS = "POTION_OF_HEALING",
            UUID = "4f694363-716d-48be-bb05-bfcf558a081f"
        }

HARD = {    DIFFICULTY = "Hard",
            LOCATIONS = { "CTY_Main_A" },
            HEAL_STATUS = "POTION_OF_HEALING_GREATER",
            UUID = "8db79e35-7dca-46e4-9602-d17938237dec"
        }

MimicType = NORMAL

Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function(levelName, _)
    local party = Osi.DB_PartyMembers:Get(nil)
    for i = #party, 1, -1 do
        TryRemovePassive((party[i][1]), "MIMIC_Conversion_Aura")
        TryRemoveStatus((party[i][1]), "MIMIC_AURA")
        TryRemoveStatus((party[i][1]), "AMBUSH_IMMUNITY")
    end
    print("Level Started: ", levelName)
    if utils.Contains(EASY.LOCATIONS, levelName) then
        MimicType = EASY
    elseif utils.Contains(HARD.LOCATIONS, levelName) then
        MimicType = HARD
    else
        MimicType = NORMAL
    end
end)

Ext.Osiris.RegisterListener("CharacterJoinedParty", 1, "after", function(actor)
    TryRemovePassive(actor, "MIMIC_Conversion_Aura")
    TryRemoveStatus(actor, "MIMIC_AURA")
end)

Ext.Osiris.RegisterListener("MovedBy", 2, "before", function(item, character)
    --_P("MovedBy", item, character)
    MarkForMimicConversion(item, character)
end)

Ext.Osiris.RegisterListener("AttackedBy", 7, "before", function(defender, attackerOwner, attacker2, damageType, damageAmount, damageCause, storyActionID)
    --_P("AttackedBy", defender, attackerOwner, attacker2, damageType, damageAmount, damageCause, storyActionID)
    if (damageCause == "Attack" and damageAmount > 0) then
        --_P("AttackedBy", defender, attackerOwner, attacker2, damageType, damageAmount, damageCause, storyActionID)
        MarkForMimicConversion(defender, attackerOwner)
    end
end)

Ext.Osiris.RegisterListener("TemplateOpening", 3, "before", function(itemTemplate, item2, character)
    MarkForMimicConversion(item2, character)
end)

Ext.Osiris.RegisterListener("StatusRemoved", 4, "after", function(object, status, causee, storyActionID)
    --_P("REMOVED:", status)
    if (status == "AMBUSH_HELPER" and Osi.IsInCombat(object) ~= 1) then
        Osi.RemoveStatus(object, "AMBUSH_IMMUNITY")
        return
    end

    if (status == "HAG_MASK_HAGDEAD") then
        Osi.RemoveStatus(object, "MIMIC_AURA")
        return
    end

    if (status == "TRANSFORM_HELPER") then
        TransformIntoMimic(object, causee)
        --Osi.RequestDelete(object)
        return
    end

    if (status == "CALL_NEIGHBOURS_HELPER") then
        Osi.SetFaction(object, "64321d50-d516-b1b2-cfac-2eb773de1ff6")
        Osi.RemoveStatus(object, "SURPRISED")
        CallNeighbours(object)
        return
    end
end)

Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(object, status, causee, storyActionID)
    --_P(object, status)
    -- When the Player wears the Hag Mask, Transform nearby chests to mimics
    if (status == "HAG_MASK_HAGDEAD") then
        Osi.ApplyStatus(object, "MIMIC_AURA", -1)
        return
    end

    if (status == "TRANSFORM_HELPER") then
        if Osi.IsInInventory(object) ~= 1 then
            Osi.Die(object)
            Osi.RemoveStatus(object, "TRANSFORM_HELPER", causee)
        else
            Osi.Drop(object)
        end
    end
    
    if (status == "CONVERT_CHEST_TO_MIMIC") then
        MarkForMimicConversion(object, causee)
        return
    end

    if (status == "AMBUSH_HELPER" and Osi.HasActiveStatus(object, "AMBUSH_IMMUNITY") ~= 1) then
        Osi.ApplyStatus(object, "SURPRISED", 1)
        Osi.ApplyStatus(object, "AMBUSH_IMMUNITY", 60)
        return
    end

    if status == "ARMOR_STEAL_HELPER" then
        local stealList = GetEquippedGearSlots(object)
        --_D(stealList)
        -- if only 1 thing left to steal, steal and knock out
        if #stealList == 1 then
            --_P(stealList[1])

            local stealGear = UnequipGearSlot(object, stealList[1], true)
            if stealGear ~= nil then
                Osi.ApplyStatus(object, "ARMOR_STEAL", 0, 100, causee)
                Osi.ApplyStatus(causee, "ABSORB_ITEM", 0, 100, stealGear)
                Osi.ApplyStatus(causee, MimicType.HEAL_STATUS, 0)
                Osi.ApplyStatus(object, "WYR_POTENTDRINK_BLACKEDOUT", 12)
                --Osi.ApplyStatus(causee, "ABSORB_ITEM", 0, 100, UnequipGearSlot(object, "Underwear", true)) -- ( ͡° ͜ʖ ͡°)
            end
            return
        end

        for i = 1, #stealList do
            local stealGear = UnequipGearSlot(object, stealList[i], true)
            if stealGear ~= nil then
                Osi.ApplyStatus(object, "ARMOR_STEAL", 0)
                Osi.ApplyStatus(causee, "ABSORB_ITEM", 0, 100, stealGear)
                Osi.ApplyStatus(causee, MimicType.HEAL_STATUS, 0)
                return
            end
        end
        return
    end

    -- Move the item into the mimic's inventory. (causee = item in this case)
    if (status == "ABSORB_ITEM") then
        Osi.ToInventory(causee, object, 1, 0, 0)
        return
    end
end)

function GetEquippedGearSlots(character)
    local slots = {"Helmet", "Gloves", "Boots", "Cloak", "Breast"}
    local equippedGearSlots = {}
    for i = 1, #slots do
        local gearPiece = Osi.GetEquippedItem(character, slots[i]);
        if gearPiece ~= nil then
            table.insert(equippedGearSlots, slots[i])
        end
    end
    return equippedGearSlots
end

function UnequipGearSlot(character, slot, forceUnlock)
    local gearPiece = Osi.GetEquippedItem(character, slot);
    if gearPiece ~= nil then
        if forceUnlock then
            Osi.LockUnequip(gearPiece, 0)
        end
        Osi.Unequip(character, gearPiece)
    end

    return gearPiece
end

function CallNeighbours(mimic)
    Osi.ApplyStatus(mimic, "AMBUSH_AURA", 0)
    Osi.ApplyStatus(mimic, "MIMIC_AURA", 0)
end

-- Add spell if actor doesn't have it yet
function TryAddSpell(actor, spellName)
    if  Osi.HasSpell(actor, spellName) == 0 then
        Osi.AddSpell(actor, spellName)
    end
end

-- Uninstall the old passive
function TryRemovePassive(actor, passiveName)
    if Osi.HasPassive(actor, passiveName) ~= 0 then
        Osi.RemovePassive(actor, passiveName)
        --_P("Succesfully removed passive", passiveName, "on", actor)
    end
end

function TryRemoveStatus(actor, statusName)
    if Osi.HasActiveStatus(actor, statusName) ~= 0 then
        Osi.RemoveStatus(actor, statusName)
        --_P("Succesfully removed status", statusName, "on", actor)
    end
end

---Mark a chest to turn into a Mimic after its buff expires
---@param object string
---@param causee string
function MarkForMimicConversion(object, causee)
    -- only transform buried chests or generic chests.
    local substring = (string.find(object, "CONT") and string.find(object, "Chest")) or (string.find(object, "BuriedChest"))
    if substring then
        
        if Osi.HasActiveStatus(object, "TRANSFORM_HELPER") == 1 then
            return false
        end
        --_P("CONVERT", object)
        -- do not mark camp chests
        if string.find(object, "PlayerCampChest") then
            return false
        end

        -- prevent tutorial chest mods / AV Item Shipment mod from converting into a mimic
        if string.find(object, "TutorialChest") then
            return false
        end

        local convertToChestThreshold = GuidToProperty(Get("Seed"), object)
        --_P(object, convertToChestThreshold, utils.PercentToReal(Get("EncounterPercentage")))
        if (utils.PercentToReal(Get("EncounterPercentage")) > convertToChestThreshold) then
            Osi.ApplyStatus(object, "TRANSFORM_HELPER", 1, 100, causee)
        end

        return true
    end

    return false
end

---Attempt to Transform an object into a Mimic
---@param object string
---@param causee string
function TransformIntoMimic(object, causee)
    if Osi.IsDead(object) == 1 then
        --_P((string.format('Object died, wont spawn')))

        return
    end

    local x,y,z = Osi.GetPosition(object)

    local creatureTplId = MimicType.UUID
    local createdGUID = Osi.CreateAt(creatureTplId, x, y, z, 0, 1, '')
    
    if createdGUID then
        Osi.SetTag(createdGUID, "b47643e0-583c-4808-b108-f6d3b605b0a9") -- shadowcurse immune
        --_P(string.format('Successfully spawned %s [%s]', creatureTplId, createdGUID))    
        if (Osi.HasActiveStatus(causee,"AMBUSH_IMMUNITY") == 1 or Osi.HasPassive(causee, "Alert") == 1 or Osi.HasPassive(causee, "Surprise_Immunity") == 1) and Osi.IsPlayer(causee) == 1 then
            Osi.QRY_StartDialogCustom_Fixed("GLO_PAD_Mimic_Revealed_55471c86-3b69-ccae-d0e3-e8749cf41d9e", causee, "NULL_00000000-0000-0000-0000-000000000000", "NULL_00000000-0000-0000-0000-000000000000", "NULL_00000000-0000-0000-0000-000000000000", "NULL_00000000-0000-0000-0000-000000000000", "NULL_00000000-0000-0000-0000-000000000000", 1, 1, -1, 1 )
        end

        if Get("HarderMimics") then
            TryAddSpell(createdGUID, "Target_Vicious_Bite_Mimic_" .. MimicType.DIFFICULTY)
        end
        Osi.MoveAllItemsTo(object, createdGUID, 0, 0, 1)
        -- Surprise player if no mask is worn
        if Osi.HasActiveStatus(causee, "HAG_MASK_HAGDEAD") ~= 1 then
            Osi.ApplyStatus(createdGUID, "CALL_NEIGHBOURS_HELPER", 0)
            if Osi.HasActiveStatus(causee,"AMBUSH_IMMUNITY") ~= 1 and Osi.HasPassive(causee, "Alert") ~= 1 and Osi.HasPassive(causee, "Surprise_Immunity") ~= 1 and Osi.IsPlayer(causee) == 1 then
                Osi.QRY_StartDialogCustom_Fixed("GLO_PAD_Mimic_Surprised_cb5f94c8-ee5b-c17a-959c-64bc6f88b417", causee, "NULL_00000000-0000-0000-0000-000000000000", "NULL_00000000-0000-0000-0000-000000000000", "NULL_00000000-0000-0000-0000-000000000000", "NULL_00000000-0000-0000-0000-000000000000", "NULL_00000000-0000-0000-0000-000000000000", 1, 1, -1, 1 )
            end
        end
    else
        _P((string.format('Failed to spawn %s', creatureTplId)))
    end

    Osi.Die(object)
end

-- Function to convert GUID to a property value in range [0, 1], with an optional seed
function GuidToProperty(guid, seed)
    -- Step 1: Concatenate the seed with the GUID (if a seed is provided)
    local input = guid
    if seed then
        input = seed .. guid
    end
    
    -- Initialize a simple hash value
    local hash = 0

    -- Use a deterministic hash function (e.g., DJB2)
    for i = 1, #input do
        local char = string.byte(input, i)
        hash = ((hash * 33) + char) % 4294967296 -- Ensure the result stays within a 32-bit range
    end

    -- Normalize the hash value to [0, 1]
    local normalized_value = hash / 4294967295 -- 32-bit unsigned max value

    return normalized_value
end

print("MoreMimics is loaded successfully")