TOOL.Category = "Инструмент Валидатора"
TOOL.Name = "Validator Tool"
TOOL.Command = nil
TOOL.ConfigName = ""

local TABLE_SERVER = "svas_agreelist"

if CLIENT then

    local THEME = {
        background = Color(30, 30, 35, 240),
        secondary = Color(45, 45, 50, 255),
        accent = Color(0, 120, 210, 255),
        accentLight = Color(0, 150, 255, 255),
        text = Color(220, 220, 220, 255),
        success = Color(0, 200, 0, 255),
        error = Color(200, 0, 0, 255),
        border = Color(60, 60, 70, 255)
    }

    local CURRENT_ENTITY = nil

    -- Функция для открытия окна редактирования
    local function OpenEditValidatorFrame(validatorId, validatorData)
        if IsValid(EditFrame) then
            EditFrame:Remove()
        end

        -- Текущие значения для редактирования
        local currentPos = Vector(validatorData.position.x, validatorData.position.y, validatorData.position.z)
        local currentAng = Angle(validatorData.angles.p, validatorData.angles.y, validatorData.angles.r)

        EditFrame = vgui.Create("DFrame")
        EditFrame:SetSize(500, 550)
        EditFrame:Center()
        EditFrame:SetTitle("Редактирование")
        EditFrame:SetDraggable(true)
        EditFrame:ShowCloseButton(true)
        EditFrame:MakePopup()

        EditFrame.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, THEME.background)
            surface.SetDrawColor(THEME.border)
            surface.DrawOutlinedRect(0, 0, w, h)
        end

        local y = 50
        local spacing = 45

        -- Информация
        local info = vgui.Create("DLabel", EditFrame)
        info:SetPos(15, y)
        info:SetText("Модель: " .. (validatorData.model or "aqsi_cube"))
        info:SetTextColor(THEME.text)
        info:SizeToContents()
        y = y + 40

        -- Заголовок позиции
        local posTitle = vgui.Create("DLabel", EditFrame)
        posTitle:SetPos(15, y)
        posTitle:SetText("ПОЗИЦИЯ")
        posTitle:SetTextColor(THEME.accentLight)
        posTitle:SetFont("DermaDefaultBold")
        posTitle:SizeToContents()
        y = y + 25

        -- Позиция X
        local xLabel = vgui.Create("DLabel", EditFrame)
        xLabel:SetPos(15, y)
        xLabel:SetText("X:")
        xLabel:SetTextColor(THEME.text)
        xLabel:SizeToContents()

        local xSlider = vgui.Create("DNumSlider", EditFrame)
        xSlider:SetPos(60, y - 5)
        xSlider:SetSize(300, 25)
        xSlider:SetText("")
        xSlider:SetMin(-165)
        xSlider:SetMax(165)
        xSlider:SetDecimals(1)
        xSlider:SetValue(currentPos.x)
        xSlider.OnValueChanged = function(slider, val)
            currentPos.x = math.Round(val)
        end

        local xWang = vgui.Create("DNumberWang", EditFrame)
        xWang:SetPos(370, y - 3)
        xWang:SetSize(110, 22)
        xWang:SetMin(-165)
        xWang:SetMax(165)
        xWang:SetDecimals(1)
        xWang:SetValue(currentPos.x)
        xWang.OnValueChanged = function(wang, val)
            currentPos.x = val
            xSlider:SetValue(val)
        end

        y = y + spacing

        -- Позиция Y
        local yLabel = vgui.Create("DLabel", EditFrame)
        yLabel:SetPos(15, y)
        yLabel:SetText("Y:")
        yLabel:SetTextColor(THEME.text)
        yLabel:SizeToContents()

        local ySlider = vgui.Create("DNumSlider", EditFrame)
        ySlider:SetPos(60, y - 5)
        ySlider:SetSize(300, 25)
        ySlider:SetText("")
        ySlider:SetMin(-43)
        ySlider:SetMax(43)
        ySlider:SetDecimals(1)
        ySlider:SetValue(currentPos.y)
        ySlider.OnValueChanged = function(slider, val)
            currentPos.y = math.Round(val)
        end

        local yWang = vgui.Create("DNumberWang", EditFrame)
        yWang:SetPos(370, y - 3)
        yWang:SetSize(110, 22)
        yWang:SetMin(-43)
        yWang:SetMax(43)
        yWang:SetDecimals(1)
        yWang:SetValue(currentPos.y)
        yWang.OnValueChanged = function(wang, val)
            currentPos.y = val
            ySlider:SetValue(val)
        end

        y = y + spacing

        -- Позиция Z
        local zLabel = vgui.Create("DLabel", EditFrame)
        zLabel:SetPos(15, y)
        zLabel:SetText("Z:")
        zLabel:SetTextColor(THEME.text)
        zLabel:SizeToContents()

        local zSlider = vgui.Create("DNumSlider", EditFrame)
        zSlider:SetPos(60, y - 5)
        zSlider:SetSize(300, 25)
        zSlider:SetText("")
        zSlider:SetMin(-20)
        zSlider:SetMax(20)
        zSlider:SetDecimals(1)
        zSlider:SetValue(currentPos.z)
        zSlider.OnValueChanged = function(slider, val)
            currentPos.z = math.Round(val)
        end

        local zWang = vgui.Create("DNumberWang", EditFrame)
        zWang:SetPos(370, y - 3)
        zWang:SetSize(110, 22)
        zWang:SetMin(-20)
        zWang:SetMax(20)
        zWang:SetDecimals(1)
        zWang:SetValue(currentPos.z)
        zWang.OnValueChanged = function(wang, val)
            currentPos.z = val
            zSlider:SetValue(val)
        end

        y = y + spacing + 10

        -- Заголовок углов
        local angTitle = vgui.Create("DLabel", EditFrame)
        angTitle:SetPos(15, y)
        angTitle:SetText("УГЛЫ (Градусы)")
        angTitle:SetTextColor(THEME.accentLight)
        angTitle:SetFont("DermaDefaultBold")
        angTitle:SizeToContents()
        y = y + 25

        -- Угол Pitch
        local pitchLabel = vgui.Create("DLabel", EditFrame)
        pitchLabel:SetPos(15, y)
        pitchLabel:SetText("Pitch:")
        pitchLabel:SetTextColor(THEME.text)
        pitchLabel:SizeToContents()

        local pitchSlider = vgui.Create("DNumSlider", EditFrame)
        pitchSlider:SetPos(80, y - 5)
        pitchSlider:SetSize(280, 25)
        pitchSlider:SetText("")
        pitchSlider:SetMin(-180)
        pitchSlider:SetMax(180)
        pitchSlider:SetDecimals(0)
        pitchSlider:SetValue(currentAng.p)
        pitchSlider.OnValueChanged = function(slider, val)
            currentAng.p = math.Round(val)
        end

        local pitchWang = vgui.Create("DNumberWang", EditFrame)
        pitchWang:SetPos(370, y - 3)
        pitchWang:SetSize(110, 22)
        pitchWang:SetMin(-180)
        pitchWang:SetMax(180)
        pitchWang:SetDecimals(0)
        pitchWang:SetValue(currentAng.p)
        pitchWang.OnValueChanged = function(wang, val)
            currentAng.p = val
            pitchSlider:SetValue(val)
        end

        y = y + spacing

        -- Угол Yaw
        local yawLabel = vgui.Create("DLabel", EditFrame)
        yawLabel:SetPos(15, y)
        yawLabel:SetText("Yaw:")
        yawLabel:SetTextColor(THEME.text)
        yawLabel:SizeToContents()

        local yawSlider = vgui.Create("DNumSlider", EditFrame)
        yawSlider:SetPos(80, y - 5)
        yawSlider:SetSize(280, 25)
        yawSlider:SetText("")
        yawSlider:SetMin(-180)
        yawSlider:SetMax(180)
        yawSlider:SetDecimals(0)
        yawSlider:SetValue(currentAng.y)
        yawSlider.OnValueChanged = function(slider, val)
            currentAng.y = math.Round(val)
        end

        local yawWang = vgui.Create("DNumberWang", EditFrame)
        yawWang:SetPos(370, y - 3)
        yawWang:SetSize(110, 22)
        yawWang:SetMin(-180)
        yawWang:SetMax(180)
        yawWang:SetDecimals(0)
        yawWang:SetValue(currentAng.y)
        yawWang.OnValueChanged = function(wang, val)
            currentAng.y = val
            yawSlider:SetValue(val)
        end

        y = y + spacing

        -- Угол Roll
        local rollLabel = vgui.Create("DLabel", EditFrame)
        rollLabel:SetPos(15, y)
        rollLabel:SetText("Roll:")
        rollLabel:SetTextColor(THEME.text)
        rollLabel:SizeToContents()

        local rollSlider = vgui.Create("DNumSlider", EditFrame)
        rollSlider:SetPos(80, y - 5)
        rollSlider:SetSize(280, 25)
        rollSlider:SetText("")
        rollSlider:SetMin(-180)
        rollSlider:SetMax(180)
        rollSlider:SetDecimals(0)
        rollSlider:SetValue(currentAng.r)
        rollSlider.OnValueChanged = function(slider, val)
            currentAng.r = math.Round(val)
        end

        local rollWang = vgui.Create("DNumberWang", EditFrame)
        rollWang:SetPos(370, y - 3)
        rollWang:SetSize(110, 22)
        rollWang:SetMin(-180)
        rollWang:SetMax(180)
        rollWang:SetDecimals(0)
        rollWang:SetValue(currentAng.r)
        rollWang.OnValueChanged = function(wang, val)
            currentAng.r = val
            rollSlider:SetValue(val)
        end

        y = y + spacing + 20

        -- Кнопка Сохранить
        local saveBtn = vgui.Create("DButton", EditFrame)
        saveBtn:SetPos(15, y)
        saveBtn:SetSize(230, 40)
        saveBtn:SetText("")
        saveBtn.Paint = function(self, w, h)
            if self:IsHovered() then
                draw.RoundedBox(6, 0, 0, w, h, THEME.accentLight)
            else
                draw.RoundedBox(6, 0, 0, w, h, THEME.success)
            end
            draw.SimpleText("СОХРАНИТЬ", "DermaDefaultBold", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        saveBtn.DoClick = function()
            net.Start("svas_update_validator")
                net.WriteEntity(CURRENT_ENTITY)
                net.WriteInt(validatorId, 32)
                net.WriteVector(currentPos)
                net.WriteAngle(currentAng)
            net.SendToServer()
            EditFrame:Remove()
        end

        -- Кнопка Отмена
        local cancelBtn = vgui.Create("DButton", EditFrame)
        cancelBtn:SetPos(255, y)
        cancelBtn:SetSize(230, 40)
        cancelBtn:SetText("")
        cancelBtn.Paint = function(self, w, h)
            if self:IsHovered() then
                draw.RoundedBox(6, 0, 0, w, h, Color(255, 80, 80))
            else
                draw.RoundedBox(6, 0, 0, w, h, THEME.error)
            end
            draw.SimpleText("ОТМЕНА", "DermaDefaultBold", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        cancelBtn.DoClick = function()
            EditFrame:Remove()
        end
    end

    local function CreateValidatorEditor(parent, validators)

        local panel = vgui.Create("DScrollPanel", parent)
        panel:Dock(FILL)

        if not validators or #validators == 0 then
            local emptyLabel = vgui.Create("DLabel", panel)
            emptyLabel:SetText("Нет созданных валидаторов")
            emptyLabel:SetTextColor(THEME.text)
            emptyLabel:SetFont("DermaDefault")
            emptyLabel:SetPos(10, 10)
            emptyLabel:SizeToContents()
            
            return panel
        end

        local y = 10

        for i, data in ipairs(validators) do

            local block = vgui.Create("DPanel", panel)
            block:SetPos(10, y)
            block:SetSize(430, 140)

            block.Paint = function(self, w, h)

                draw.RoundedBox(6, 0, 0, w, h, THEME.secondary)

                draw.SimpleText(
                    "Валидатор #" .. i,
                    "DermaDefaultBold",
                    15,
                    10,
                    THEME.accentLight
                )

                draw.SimpleText(
                    "Модель: " .. (data.model or "неизвестно"),
                    "DermaDefault",
                    15,
                    35,
                    THEME.text
                )

                if data.position then
                    draw.SimpleText(
                        "Позиция: " ..
                        math.Round(data.position.x) .. " " ..
                        math.Round(data.position.y) .. " " ..
                        math.Round(data.position.z),
                        "DermaDefault",
                        15,
                        55,
                        THEME.text
                    )
                end

                if data.angles then
                    draw.SimpleText(
                        "Угол: " ..
                        math.Round(data.angles.p) .. " " ..
                        math.Round(data.angles.y) .. " " ..
                        math.Round(data.angles.r),
                        "DermaDefault",
                        15,
                        75,
                        THEME.text
                    )
                end

            end

            -- Кнопка редактирования
            local editBtn = vgui.Create("DButton", block)
            editBtn:SetPos(15, 95)
            editBtn:SetSize(195, 28)
            editBtn:SetText("")

            editBtn.Paint = function(self, w, h)
                draw.RoundedBox(
                    4,
                    0,
                    0,
                    w,
                    h,
                    self:IsHovered()
                        and THEME.accentLight
                        or THEME.accent
                )
                draw.SimpleText(
                    "РЕДАКТИРОВАТЬ #" .. i,
                    "DermaDefaultBold",
                    w / 2,
                    h / 2,
                    color_white,
                    TEXT_ALIGN_CENTER,
                    TEXT_ALIGN_CENTER
                )
            end

            editBtn.DoClick = function()
                net.Start("svas_edit_validator")
                    net.WriteEntity(CURRENT_ENTITY)
                    net.WriteInt(i, 32)
                net.SendToServer()
            end

            -- Кнопка удаления
            local removeBtn = vgui.Create("DButton", block)
            removeBtn:SetPos(220, 95)
            removeBtn:SetSize(195, 28)
            removeBtn:SetText("")

            removeBtn.Paint = function(self, w, h)
                draw.RoundedBox(
                    4,
                    0,
                    0,
                    w,
                    h,
                    self:IsHovered()
                        and Color(255,50,50)
                        or THEME.error
                )
                draw.SimpleText(
                    "УДАЛИТЬ #" .. i,
                    "DermaDefaultBold",
                    w / 2,
                    h / 2,
                    color_white,
                    TEXT_ALIGN_CENTER,
                    TEXT_ALIGN_CENTER
                )
            end

            removeBtn.DoClick = function()
                net.Start("svas_remove_validator")
                    net.WriteEntity(CURRENT_ENTITY)
                    net.WriteInt(i, 32)
                net.SendToServer()
                
                block:Remove()
            end

            y = y + 150

        end

        return panel

    end

    local function CreateAddValidatorTab(parent)

        local panel = vgui.Create("DPanel", parent)
        panel:Dock(FILL)

        panel.Paint = function(self, w, h)

            draw.RoundedBox(4, 0, 0, w, h, THEME.secondary)

        end

        local modelLabel = vgui.Create("DLabel", panel)
        modelLabel:SetPos(20, 20)
        modelLabel:SetSize(380, 20)
        modelLabel:SetText("Выберите модель валидатора:")
        modelLabel:SetTextColor(THEME.text)
        modelLabel:SetFont("DermaDefault")

        local modelCombo = vgui.Create("DComboBox", panel)
        modelCombo:SetPos(20, 50)
        modelCombo:SetSize(380, 30)
        modelCombo:SetValue("aqsi_cube")
        modelCombo:AddChoice("aqsi_cube")
        modelCombo:AddChoice("bm20")
        modelCombo:SetTextColor(THEME.text)

        modelCombo.Paint = function(self, w, h)

            draw.RoundedBox(4, 0, 0, w, h, THEME.background)

            surface.SetDrawColor(THEME.border)
            surface.DrawOutlinedRect(0, 0, w, h)

        end

        local add = vgui.Create("DButton", panel)
        add:SetPos(20, 110)
        add:SetSize(380, 40)
        add:SetText("")

        add.Paint = function(self, w, h)

            draw.RoundedBox(
                4,
                0,
                0,
                w,
                h,
                self:IsHovered()
                    and THEME.accentLight
                    or THEME.accent
            )

            draw.SimpleText(
                "СОЗДАТЬ ВАЛИДАТОР",
                "DermaDefaultBold",
                w / 2,
                h / 2,
                color_white,
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER
            )

        end

        add.DoClick = function()
            local selectedModel = string.lower(modelCombo:GetValue())
            if selectedModel == "" then return end

            net.Start("svas_create_validator")
                net.WriteEntity(CURRENT_ENTITY)
                net.WriteString(selectedModel)
            net.SendToServer()
        end

        return panel

    end

    local function CreateMainFrame(data)

        CURRENT_ENTITY = data.entity

        if IsValid(SVAS_Frame) then
            SVAS_Frame:Remove()
        end

        SVAS_Frame = vgui.Create("DFrame")
        SVAS_Frame:SetSize(500, 550)
        SVAS_Frame:Center()
        SVAS_Frame:SetTitle("")
        SVAS_Frame:ShowCloseButton(false)
        SVAS_Frame:MakePopup()

        SVAS_Frame.Paint = function(self, w, h)

            draw.RoundedBox(8, 0, 0, w, h, THEME.background)

            draw.RoundedBox(8, 0, 0, w, 35, THEME.secondary)

            draw.SimpleText(
                "SVAS VALIDATOR MANAGER",
                "DermaDefaultBold",
                15,
                10,
                THEME.accentLight
            )

            surface.SetDrawColor(THEME.border)
            surface.DrawOutlinedRect(0, 0, w, h)

        end

        local close = vgui.Create("DButton", SVAS_Frame)
        close:SetSize(30, 25)
        close:SetPos(460, 5)
        close:SetText("")

        close.Paint = function(self, w, h)

            draw.RoundedBox(
                4,
                0,
                0,
                w,
                h,
                self:IsHovered()
                    and THEME.error
                    or Color(0,0,0,0)
            )

            draw.SimpleText(
                "X",
                "DermaDefaultBold",
                w / 2,
                h / 2,
                color_white,
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER
            )

        end

        close.DoClick = function()

            SVAS_Frame:Remove()

        end

        local info = vgui.Create("DPanel", SVAS_Frame)
        info:SetPos(15, 50)
        info:SetSize(470, 100)

        info.Paint = function(self, w, h)

            draw.RoundedBox(6, 0, 0, w, h, THEME.secondary)

            draw.SimpleText(
                "Транспорт: " .. data.vehicleClass,
                "DermaDefaultBold",
                15,
                20,
                THEME.text
            )

            draw.SimpleText(
                "Название: " .. data.vehicleName,
                "DermaDefault",
                15,
                45,
                THEME.text
            )

            draw.SimpleText(
                "Трейлер: " ..
                (
                    data.trailerClass ~= ""
                    and data.trailerClass
                    or "отсутствует"
                ),
                "DermaDefault",
                15,
                70,
                THEME.text
            )

        end

        local tabs = vgui.Create("DPropertySheet", SVAS_Frame)
        tabs:SetPos(15, 165)
        tabs:SetSize(470, 365)

        local validators = CreateValidatorEditor(tabs, data.validators)
        local create = CreateAddValidatorTab(tabs)

        local settings = vgui.Create("DPanel", tabs)
        settings:Dock(FILL)

        settings.Paint = function(self, w, h)

            draw.RoundedBox(4,0,0,w,h,THEME.secondary)

            draw.SimpleText(
                "Настройки транспорта",
                "DermaDefaultBold",
                w/2,
                h/2,
                THEME.text,
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER
            )

        end

        tabs:AddSheet(
            "Валидаторы",
            validators,
            "icon16/group.png"
        )

        tabs:AddSheet(
            "Добавить",
            create,
            "icon16/add.png"
        )

        tabs:AddSheet(
            "Настройки",
            settings,
            "icon16/cog.png"
        )

    end

    net.Receive("validator_open_menu", function()

        local entity = net.ReadEntity()
        local vehicleClass = net.ReadString()
        local vehicleName = net.ReadString()
        local trailerClass = net.ReadString()
        local validators = net.ReadTable()

        CreateMainFrame({
            entity = entity,
            vehicleClass = vehicleClass,
            vehicleName = vehicleName,
            trailerClass = trailerClass,
            validators = validators
        })

    end)

    net.Receive("svas_open_edit_menu", function()
        local entity = net.ReadEntity()
        local validatorId = net.ReadInt(32)
        local validatorData = net.ReadTable()

        CURRENT_ENTITY = entity
        OpenEditValidatorFrame(validatorId, validatorData)
    end)

end

if SERVER then

    util.AddNetworkString("validator_open_menu")
    util.AddNetworkString("svas_create_validator")
    util.AddNetworkString("svas_remove_validator")
    util.AddNetworkString("svas_edit_validator")
    util.AddNetworkString("svas_update_validator")
    util.AddNetworkString("svas_open_edit_menu")

    local function SaveValidatorData(ent, data)
        ent:SetNW2String("SVAS_Validators", util.TableToJSON(data))
    end

    local function GetMaxValidators(vehicleClass)
        local query = "SELECT value_valid FROM " .. TABLE_SERVER .. " WHERE class = " .. sql.SQLStr(vehicleClass)
        local result = sql.Query(query)
        
        if result and result[1] and result[1].value_valid then
            return tonumber(result[1].value_valid) or 5
        end
        
        return 5
    end

    local function SpawnValidatorOnVehicle(vehicle, validatorData)
        local entityClass = string.lower(validatorData.model) == "bm20" and "bm20" or "aqsi_cube"
        
        local worldPos = vehicle:LocalToWorld(validatorData.position)
        local worldAng = vehicle:LocalToWorldAngles(validatorData.angles)
        
        local validatorEnt = ents.Create(entityClass)
        if not IsValid(validatorEnt) then 
            print("[SVAS] Ошибка: не удалось создать энтити " .. entityClass)
            return nil
        end
        
        validatorEnt:SetPos(worldPos)
        validatorEnt:SetAngles(worldAng)
        validatorEnt:Spawn()
        validatorEnt:SetParent(vehicle)
        validatorEnt:SetMoveType(MOVETYPE_NONE)
        validatorEnt:SetSolid(SOLID_NONE)
        
        validatorEnt.ValidatorData = {
            model = validatorData.model,
            position = validatorData.position,
            angles = validatorData.angles,
            parentVehicle = vehicle
        }
        
        return validatorEnt
    end

    local function RemoveValidatorsFromVehicle(vehicle)
        for _, child in ipairs(vehicle:GetChildren()) do
            if IsValid(child) then
                local class = child:GetClass()
                if class == "aqsi_cube" or class == "bm20" then
                    child:Remove()
                end
            end
        end
    end

    function addorrm(com, model, imen, ent, num, updateData)
        if com == "add" then
            if IsValid(ent) then
                if not ent.Validators then
                    ent.Validators = {}
                end
                
                local maxValidators = GetMaxValidators(ent:GetClass())
                
                if #ent.Validators < maxValidators then
                    local localPos = Vector(0, 0, 0)
                    local localAng = Angle(0, 0, 0)
                    
                    local base = {
                        ["model"] = string.lower(model),
                        ["position"] = localPos,
                        ["angles"] = localAng,
                        ["immedenabled"] = imen
                    }
                    table.insert(ent.Validators, base)
                    SaveValidatorData(ent, ent.Validators)
                    
                    SpawnValidatorOnVehicle(ent, base)
                    
                    return true
                else
                    print("[SVAS] Достигнут максимум валидаторов для " .. ent:GetClass())
                    return false
                end
            else
                return false
            end
        elseif com == "rm" then
            if IsValid(ent) and ent.Validators then
                if num and ent.Validators[num] then
                    table.remove(ent.Validators, num)
                    SaveValidatorData(ent, ent.Validators)
                    
                    RemoveValidatorsFromVehicle(ent)
                    
                    for i, validatorData in ipairs(ent.Validators) do
                        SpawnValidatorOnVehicle(ent, validatorData)
                    end
                    
                    return true
                end
            end
            return false
        end
        
        return false
    end

    net.Receive("svas_create_validator", function(_, ply)
        local vehicle = net.ReadEntity()
        local validatorType = net.ReadString()

        if not IsValid(vehicle) then return end

        local success = addorrm("add", validatorType, false, vehicle, nil)
        
        if success then
            ply:ChatPrint("[SVAS] Валидатор создан.")
        else
            ply:ChatPrint("[SVAS] Не удалось создать валидатор.")
        end
    end)

    net.Receive("svas_remove_validator", function(_, ply)
        local vehicle = net.ReadEntity()
        local num = net.ReadInt(32)

        if not IsValid(vehicle) then return end

        local success = addorrm("rm", nil, nil, vehicle, num)
        
        if success then
            ply:ChatPrint("[SVAS] Валидатор #" .. num .. " удален.")
        else
            ply:ChatPrint("[SVAS] Не удалось удалить валидатор.")
        end
    end)

    net.Receive("svas_edit_validator", function(_, ply)
        local vehicle = net.ReadEntity()
        local num = net.ReadInt(32)

        if not IsValid(vehicle) then return end

        if not vehicle.Validators then
            vehicle.Validators = {}
        end

        if num and vehicle.Validators[num] then
            net.Start("svas_open_edit_menu")
                net.WriteEntity(vehicle)
                net.WriteInt(num, 32)
                net.WriteTable(vehicle.Validators[num])
            net.Send(ply)
        else
            ply:ChatPrint("[SVAS] Валидатор #" .. num .. " не найден!")
        end
    end)

    net.Receive("svas_update_validator", function(_, ply)
        local vehicle = net.ReadEntity()
        local num = net.ReadInt(32)
        local newPos = net.ReadVector()
        local newAng = net.ReadAngle()

        if not IsValid(vehicle) then return end

        if not vehicle.Validators then
            vehicle.Validators = {}
        end

        if num and vehicle.Validators[num] then
            -- Заменяем старые координаты новыми
            vehicle.Validators[num].position = newPos
            vehicle.Validators[num].angles = newAng
            
            SaveValidatorData(vehicle, vehicle.Validators)
            
            -- Пересоздаем валидаторы
            RemoveValidatorsFromVehicle(vehicle)
            for i, validatorData in ipairs(vehicle.Validators) do
                SpawnValidatorOnVehicle(vehicle, validatorData)
            end
            
            ply:ChatPrint("[SVAS] Валидатор #" .. num .. " обновлен!")
        else
            ply:ChatPrint("[SVAS] Валидатор #" .. num .. " не найден!")
        end
    end)

    function TOOL:LeftClick(trace)
        local ply = self:GetOwner()
        local ent = trace.Entity

        if not IsValid(ent) then
            return false
        end

        local clickedClass = ent:GetClass()

        local query =
            "SELECT * FROM " .. TABLE_SERVER ..
            " WHERE class = " .. sql.SQLStr(clickedClass) ..
            " OR trailer_class = " .. sql.SQLStr(clickedClass)

        local rows = sql.Query(query)

        if not rows or not rows[1] then
            ply:ChatPrint("[SVAS] Этот транспорт не разрешен.")
            return true
        end

        local row = rows[1]

        if not ent.Validators then
            ent.Validators = {}
        end

        local validators = ent.Validators

        net.Start("validator_open_menu")
            net.WriteEntity(ent)
            net.WriteString(row.class or clickedClass)
            net.WriteString(row.name or clickedClass)
            net.WriteString(row.trailer_class or "")
            net.WriteTable(validators)
        net.Send(ply)

        return true
    end

end
