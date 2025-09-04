local utils = { }

function utils.Contains(list, element)
    for _, value in ipairs(list) do
        if value == element then
            return true
        end
    end
    return false
end

function utils.PercentToReal(pct)
    -- Ensure the input is within the valid range of 0 to 100
    if pct < 0 then
        return 0
    end
    
    if pct > 100 then
        return 100
    end
    -- Convert the integer to a real number between 0 and 1
    return pct / 100
end

---Delay a function call by the given time
---@param ms integer
---@param func function
function utils.DelayedCall(ms, func)
    local Time = 0
    local handler
    handler = Ext.Events.Tick:Subscribe(function(e)
        Time = Time + e.Time.DeltaTime * 1000 -- Convert seconds to milliseconds

        if (Time >= ms) then
            func()
            Ext.Events.Tick:Unsubscribe(handler)
        end
    end)
end

function utils.GetTags(object)
    local tags = {
        Tags = {},
        OsirisTags = {},
        TemplateTags = {},
    }
    local esvObject = Ext.Entity.Get(object)
    if object ~= nil then
        for _, tag in pairs(esvObject.Tag.Tags) do
            local tagData = Ext.StaticData.Get(tag, "Tag")
            if tagData ~= nil then
                tags.Tags[tagData.Name] = tag
            end
        end

        for _, tag in pairs(esvObject.ServerOsirisTag.Tags) do
            local tagData = Ext.StaticData.Get(tag, "Tag")
            if tagData ~= nil then
                tags.OsirisTags[tagData.Name] = tag
            end
        end

        for _, tag in pairs(esvObject.ServerTemplateTag.Tags) do
            local tagData = Ext.StaticData.Get(tag, "Tag")
            if tagData ~= nil then
                tags.TemplateTags[tagData.Name] = tag
            end
        end
    end

    return tags
end

return utils