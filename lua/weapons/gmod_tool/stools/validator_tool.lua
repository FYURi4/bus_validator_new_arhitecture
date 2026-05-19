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
        success = Color(0, 120, 210, 255),
        error = Color(200, 0, 0, 255),
        border = Color(60, 60, 70, 255),
        disabled = Color(100, 100, 100, 255)
    }

    local CURRENT_ENTITY = nil
    local CURRENT_TRAILER = nil
    local MAIN_VEHICLE = nil -- Основная машина (даже если кликнули по прицепу)
    local VALIDATOR_LIST_PANEL = nil
    local MAIN_TABS = nil

    -- Функция для обновления списка валидаторов
    local function RefreshValidatorList()
        if IsValid(MAIN_VEHICLE) then
            net.Start("svas_refresh_validators")
                net.WriteEntity(MAIN_VEHICLE)
            net.SendToServer()
        end
    end

    -- Функция для создания списка валидаторов
    local function CreateValidatorList(parent, validators)
        parent:Clear()
        
        if not validators or #validators == 0 then
            local emptyLabel = vgui.Create("DLabel", parent)
            emptyLabel:SetText("Нет созданных валидаторов")
            emptyLabel:SetTextColor(THEME.text)
            emptyLabel:SetFont("DermaDefault")
            emptyLabel:SetPos(10, 10)
            emptyLabel:SizeToContents()
            return
        end

        local y = 10

        for i, data in ipairs(validators) do
            local block = vgui.Create("DPanel", parent)
            block:SetPos(10, y)
            block:SetSize(430, 155)
            block.Paint = function(self, w, h)
                draw.RoundedBox(6, 0, 0, w, h, THEME.secondary)
                draw.SimpleText("Валидатор #" .. i, "DermaDefaultBold", 15, 10, THEME.accentLight)
                draw.SimpleText("Модель: " .. (data.model or "неизвестно"), "DermaDefault", 15, 35, THEME.text)
                
                -- Показываем цель (машина или прицеп)
                local targetText = data.target == "trailer" and "Прицеп" or "Машина"
                draw.SimpleText("Цель: " .. targetText, "DermaDefault", 15, 52, THEME.accentLight)
                
                if data.position then
                    draw.SimpleText(
                        "Позиция: " .. string.format("%.1f", data.position.x) .. " " ..
                        string.format("%.1f", data.position.y) .. " " ..
                        string.format("%.1f", data.position.z),
                        "DermaDefault", 15, 69, THEME.text
                    )
                end
                
                if data.angles then
                    draw.SimpleText(
                        "Угол: " .. string.format("%.1f", data.angles.p) .. " " ..
                        string.format("%.1f", data.angles.y) .. " " ..
                        string.format("%.1f", data.angles.r),
                        "DermaDefault", 15, 86, THEME.text
                    )
                end
            end

            -- Кнопка редактирования
            local editBtn = vgui.Create("DButton", block)
            editBtn:SetPos(15, 110)
            editBtn:SetSize(195, 28)
            editBtn:SetText("")
            editBtn.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and THEME.accentLight or THEME.accent)
                draw.SimpleText("РЕДАКТИРОВАТЬ #" .. i, "DermaDefaultBold", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            editBtn.DoClick = function()
                net.Start("svas_edit_validator")
                    net.WriteEntity(MAIN_VEHICLE)
                    net.WriteInt(i, 32)
                net.SendToServer()
            end

            -- Кнопка удаления
            local removeBtn = vgui.Create("DButton", block)
            removeBtn:SetPos(220, 110)
            removeBtn:SetSize(195, 28)
            removeBtn:SetText("")
            removeBtn.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(255,50,50) or THEME.error)
                draw.SimpleText("УДАЛИТЬ #" .. i, "DermaDefaultBold", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            removeBtn.DoClick = function()
                net.Start("svas_remove_validator")
                    net.WriteEntity(MAIN_VEHICLE)
                    net.WriteInt(i, 32)
                net.SendToServer()
                
                timer.Simple(0.2, function()
                    RefreshValidatorList()
                end)
            end

            y = y + 165
        end
    end

    -- Функция для открытия окна редактирования
    local function OpenEditValidatorFrame(validatorId, validatorData)
        if IsValid(EditFrame) then
            EditFrame:Remove()
        end

        local currentPos = Vector(validatorData.position.x, validatorData.position.y, validatorData.position.z)
        local currentAng = Angle(validatorData.angles.p, validatorData.angles.y, validatorData.angles.r)
        local currentTarget = validatorData.target or "vehicle"

        EditFrame = vgui.Create("DFrame")
        EditFrame:SetSize(550, 720)
        EditFrame:Center()
        EditFrame:SetTitle("")
        EditFrame:SetDraggable(true)
        EditFrame:ShowCloseButton(false)
        EditFrame:MakePopup()

        EditFrame.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, THEME.background)
            draw.RoundedBox(8, 0, 0, w, 40, THEME.secondary)
            surface.SetDrawColor(THEME.border)
            surface.DrawOutlinedRect(0, 0, w, h)
            draw.SimpleText("РЕДАКТИРОВАНИЕ ВАЛИДАТОРА", "DermaDefaultBold", 15, 12, THEME.accentLight)
        end

        local close = vgui.Create("DButton", EditFrame)
        close:SetSize(30, 28)
        close:SetPos(EditFrame:GetWide() - 38, 6)
        close:SetText("")
        close.Paint = function(self, w, h)
            if self:IsHovered() then
                draw.RoundedBox(4, 0, 0, w, h, THEME.error)
            else
                draw.RoundedBox(4, 0, 0, w, h, Color(0, 0, 0, 0))
            end
            draw.SimpleText("X", "DermaDefaultBold", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        close.DoClick = function()
            EditFrame:Remove()
        end

        local y = 55
        local spacing = 45

        -- Информационная панель
        local infoPanel = vgui.Create("DPanel", EditFrame)
        infoPanel:SetPos(15, y)
        infoPanel:SetSize(520, 70)
        infoPanel.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, THEME.secondary)
            surface.SetDrawColor(THEME.border)
            surface.DrawOutlinedRect(0, 0, w, h)
        end
        
        local modelIcon = vgui.Create("DLabel", infoPanel)
        modelIcon:SetPos(15, 15)
        modelIcon:SetText("Модель:")
        modelIcon:SetTextColor(THEME.text)
        modelIcon:SetFont("DermaDefaultBold")
        modelIcon:SizeToContents()
        
        local modelValue = vgui.Create("DLabel", infoPanel)
        modelValue:SetPos(80, 15)
        modelValue:SetText(validatorData.model or "aqsi_cube")
        modelValue:SetTextColor(THEME.accentLight)
        modelValue:SetFont("DermaDefault")
        modelValue:SizeToContents()

        -- Переключатель цели в режиме редактирования
        local hasTrailer = IsValid(CURRENT_TRAILER)
        
        local targetLabel = vgui.Create("DLabel", infoPanel)
        targetLabel:SetPos(15, 42)
        targetLabel:SetText("Цель:")
        targetLabel:SetTextColor(THEME.text)
        targetLabel:SetFont("DermaDefaultBold")
        targetLabel:SizeToContents()

        local targetCombo = vgui.Create("DComboBox", infoPanel)
        targetCombo:SetPos(80, 38)
        targetCombo:SetSize(200, 22)
        targetCombo:SetValue(currentTarget == "trailer" and "Прицеп" or "Машина")
        targetCombo:AddChoice("Машина")
        if hasTrailer then
            targetCombo:AddChoice("Прицеп")
        end
        targetCombo:SetTextColor(THEME.text)
        targetCombo.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, THEME.background)
            surface.SetDrawColor(THEME.border)
            surface.DrawOutlinedRect(0, 0, w, h)
        end
        targetCombo.OnSelect = function(panel, index, value)
            if value == "Прицеп" then
                currentTarget = "trailer"
            else
                currentTarget = "vehicle"
            end
        end
        
        y = y + 85

        -- Заголовок позиции
        local posTitle = vgui.Create("DPanel", EditFrame)
        posTitle:SetPos(15, y)
        posTitle:SetSize(520, 30)
        posTitle.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(0, 120, 210, 40))
            draw.SimpleText("ПОЗИЦИЯ", "DermaDefaultBold", 15, h/2, THEME.accentLight, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        y = y + 40

        -- Функция для создания панели с слайдером
        local function CreateSliderPanel(parent, yPos, label, min, max, currentVal, onChanged)
            local panel = vgui.Create("DPanel", parent)
            panel:SetPos(15, yPos)
            panel:SetSize(520, 35)
            panel.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 45, 255))
            end

            local lbl = vgui.Create("DLabel", panel)
            lbl:SetPos(15, 9)
            lbl:SetText(label .. ":")
            lbl:SetTextColor(THEME.text)
            lbl:SetFont("DermaDefaultBold")
            lbl:SizeToContents()

            local slider = vgui.Create("DNumSlider", panel)
            slider:SetPos(50, 2)
            slider:SetSize(380, 25)
            slider:SetText("")
            slider:SetMin(min)
            slider:SetMax(max)
            slider:SetDecimals(1)
            slider:SetValue(currentVal)

            local wang = vgui.Create("DNumberWang", panel)
            wang:SetPos(440, 5)
            wang:SetSize(65, 22)
            wang:SetMin(min)
            wang:SetMax(max)
            wang:SetDecimals(1)
            wang:SetValue(currentVal)

            slider.OnValueChanged = function(sl, val)
                wang:SetValue(val)
                onChanged(val)
            end

            wang.OnValueChanged = function(wng, val)
                slider:SetValue(val)
                onChanged(val)
            end

            return panel
        end

        CreateSliderPanel(EditFrame, y, "X", -165, 165, currentPos.x, function(val) currentPos.x = val end)
        y = y + spacing
        CreateSliderPanel(EditFrame, y, "Y", -43, 43, currentPos.y, function(val) currentPos.y = val end)
        y = y + spacing
        CreateSliderPanel(EditFrame, y, "Z", -20, 35, currentPos.z, function(val) currentPos.z = val end)
        y = y + spacing + 10

        -- Заголовок углов
        local angTitle = vgui.Create("DPanel", EditFrame)
        angTitle:SetPos(15, y)
        angTitle:SetSize(520, 30)
        angTitle.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(0, 120, 210, 40))
            draw.SimpleText("УГЛЫ (Градусы)", "DermaDefaultBold", 15, h/2, THEME.accentLight, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        y = y + 40

        CreateSliderPanel(EditFrame, y, "Pitch", -180, 180, currentAng.p, function(val) currentAng.p = val end)
        y = y + spacing
        CreateSliderPanel(EditFrame, y, "Yaw", -180, 180, currentAng.y, function(val) currentAng.y = val end)
        y = y + spacing
        CreateSliderPanel(EditFrame, y, "Roll", -180, 180, currentAng.r, function(val) currentAng.r = val end)
        y = y + spacing + 20

        -- Кнопка Сохранить
        local saveBtn = vgui.Create("DButton", EditFrame)
        saveBtn:SetPos(15, y)
        saveBtn:SetSize(250, 40)
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
                net.WriteEntity(MAIN_VEHICLE)
                net.WriteInt(validatorId, 32)
                net.WriteVector(currentPos)
                net.WriteAngle(currentAng)
                net.WriteString(currentTarget)
            net.SendToServer()
            EditFrame:Remove()
            
            timer.Simple(0.2, function()
                RefreshValidatorList()
            end)
        end

        -- Кнопка Отмена
        local cancelBtn = vgui.Create("DButton", EditFrame)
        cancelBtn:SetPos(285, y)
        cancelBtn:SetSize(250, 40)
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

    -- Создание вкладки добавления валидатора
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

        -- Переключатель цели
        local hasTrailer = IsValid(CURRENT_TRAILER)
        
        local targetLabel = vgui.Create("DLabel", panel)
        targetLabel:SetPos(20, 100)
        targetLabel:SetSize(380, 20)
        targetLabel:SetText("Выберите цель:")
        targetLabel:SetTextColor(THEME.text)
        targetLabel:SetFont("DermaDefault")

        local targetCombo = vgui.Create("DComboBox", panel)
        targetCombo:SetPos(20, 130)
        targetCombo:SetSize(380, 30)
        targetCombo:SetValue("Машина")
        targetCombo:AddChoice("Машина")
        
        if hasTrailer then
            targetCombo:AddChoice("Прицеп")
        end
        
        targetCombo:SetTextColor(THEME.text)
        targetCombo.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, THEME.background)
            surface.SetDrawColor(THEME.border)
            surface.DrawOutlinedRect(0, 0, w, h)
        end

        if not hasTrailer then
            -- Показываем сообщение, если прицепа нет
            local noTrailerLabel = vgui.Create("DLabel", panel)
            noTrailerLabel:SetPos(20, 165)
            noTrailerLabel:SetSize(380, 20)
            noTrailerLabel:SetText("Прицеп отсутствует")
            noTrailerLabel:SetTextColor(THEME.disabled)
            noTrailerLabel:SetFont("DermaDefault")
        end

        local add = vgui.Create("DButton", panel)
        add:SetPos(20, 200)
        add:SetSize(380, 40)
        add:SetText("")
        add.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and THEME.accentLight or THEME.accent)
            draw.SimpleText("СОЗДАТЬ ВАЛИДАТОР", "DermaDefaultBold", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        add.DoClick = function()
            local selectedModel = string.lower(modelCombo:GetValue())
            if selectedModel == "" then return end

            local target = targetCombo:GetValue() == "Прицеп" and "trailer" or "vehicle"

            net.Start("svas_create_validator")
                net.WriteEntity(MAIN_VEHICLE)
                net.WriteString(selectedModel)
                net.WriteString(target)
            net.SendToServer()
            
            timer.Simple(0.2, function()
                RefreshValidatorList()
            end)
        end

        return panel
    end

    -- Создание главного окна
    local function CreateMainFrame(data)
        CURRENT_ENTITY = data.entity
        CURRENT_TRAILER = data.trailerEntity
        MAIN_VEHICLE = data.mainVehicle -- Основная машина

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
            draw.SimpleText("SVAS VALIDATOR MANAGER", "DermaDefaultBold", 15, 10, THEME.accentLight)
            surface.SetDrawColor(THEME.border)
            surface.DrawOutlinedRect(0, 0, w, h)
        end

        local close = vgui.Create("DButton", SVAS_Frame)
        close:SetSize(30, 25)
        close:SetPos(460, 5)
        close:SetText("")
        close.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and THEME.error or Color(0,0,0,0))
            draw.SimpleText("X", "DermaDefaultBold", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        close.DoClick = function()
            SVAS_Frame:Remove()
        end

        local info = vgui.Create("DPanel", SVAS_Frame)
        info:SetPos(15, 50)
        info:SetSize(470, 100)
        info.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, THEME.secondary)
            draw.SimpleText("Транспорт: " .. data.vehicleClass, "DermaDefaultBold", 15, 20, THEME.text)
            draw.SimpleText("Название: " .. data.vehicleName, "DermaDefault", 15, 45, THEME.text)
            
            local trailerText = data.trailerClass ~= "" and data.trailerClass or "отсутствует"
            if IsValid(CURRENT_TRAILER) then
                trailerText = trailerText .. " (прикреплен)"
            end
            draw.SimpleText("Трейлер: " .. trailerText, "DermaDefault", 15, 70, THEME.text)
        end

        MAIN_TABS = vgui.Create("DPropertySheet", SVAS_Frame)
        MAIN_TABS:SetPos(15, 165)
        MAIN_TABS:SetSize(470, 365)

        -- Создаем панель для списка валидаторов
        VALIDATOR_LIST_PANEL = vgui.Create("DScrollPanel")
        CreateValidatorList(VALIDATOR_LIST_PANEL, data.validators)
        
        local addTab = CreateAddValidatorTab()

        local settings = vgui.Create("DPanel")
        settings.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, THEME.secondary)
            draw.SimpleText("Настройки транспорта", "DermaDefaultBold", w/2, h/2, THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        MAIN_TABS:AddSheet("Валидаторы", VALIDATOR_LIST_PANEL, "icon16/group.png")
        MAIN_TABS:AddSheet("Добавить", addTab, "icon16/add.png")
        MAIN_TABS:AddSheet("Настройки", settings, "icon16/cog.png")
    end

    -- Сетевые обработчики
    net.Receive("svas_refresh_validators_response", function()
        if IsValid(VALIDATOR_LIST_PANEL) then
            local validators = net.ReadTable()
            CreateValidatorList(VALIDATOR_LIST_PANEL, validators)
        end
    end)

    net.Receive("validator_open_menu", function()
        local entity = net.ReadEntity()
        local vehicleClass = net.ReadString()
        local vehicleName = net.ReadString()
        local trailerClass = net.ReadString()
        local trailerEntity = net.ReadEntity()
        local mainVehicle = net.ReadEntity()
        local validators = net.ReadTable()

        CreateMainFrame({
            entity = entity,
            vehicleClass = vehicleClass,
            vehicleName = vehicleName,
            trailerClass = trailerClass,
            trailerEntity = trailerEntity,
            mainVehicle = mainVehicle,
            validators = validators
        })
    end)

    net.Receive("svas_open_edit_menu", function()
        local entity = net.ReadEntity()
        local validatorId = net.ReadInt(32)
        local validatorData = net.ReadTable()

        MAIN_VEHICLE = entity
        CURRENT_ENTITY = entity
        
        -- Получаем прицеп если есть
        if IsValid(entity) then
            CURRENT_TRAILER = entity.SVASTrailer or nil
        end
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
    util.AddNetworkString("svas_refresh_validators")
    util.AddNetworkString("svas_refresh_validators_response")

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

    local function FindTrailer(vehicle)
        if not IsValid(vehicle) then return nil end
        
        -- Способ 1: Поиск через Parent
        local children = vehicle:GetChildren()
        for _, child in ipairs(children) do
            if IsValid(child) then
                local childClass = child:GetClass()
                
                -- Проверяем, является ли ребенок прицепом по данным из БД
                local query = "SELECT class FROM " .. TABLE_SERVER .. " WHERE class = " .. sql.SQLStr(childClass)
                local result = sql.Query(query)
                
                if result and result[1] then
                    -- Проверяем, есть ли у этого класса trailer_class (значит это машина, у которой может быть прицеп)
                    local trailerQuery = "SELECT trailer_class FROM " .. TABLE_SERVER .. " WHERE class = " .. sql.SQLStr(childClass)
                    local trailerResult = sql.Query(trailerQuery)
                    
                    -- Если у найденного энтити нет trailer_class, значит это может быть прицеп
                    if trailerResult and trailerResult[1] and (trailerResult[1].trailer_class == "" or trailerResult[1].trailer_class == nil) then
                        return child
                    end
                end
            end
        end
        
        -- Способ 2: Поиск через trailer_class в БД
        local vehicleClass = vehicle:GetClass()
        local query = "SELECT trailer_class FROM " .. TABLE_SERVER .. " WHERE class = " .. sql.SQLStr(vehicleClass)
        local result = sql.Query(query)
        
        if result and result[1] and result[1].trailer_class and result[1].trailer_class != "" then
            local trailerClass = result[1].trailer_class
            
            -- Ищем среди всех энтити рядом с машиной
            local nearbyEnts = ents.FindInSphere(vehicle:GetPos(), 500)
            for _, ent in ipairs(nearbyEnts) do
                if IsValid(ent) and ent != vehicle then
                    if ent:GetClass() == trailerClass then
                        return ent
                    end
                end
            end
            
            -- Ищем среди детей
            for _, child in ipairs(children) do
                if IsValid(child) and child:GetClass() == trailerClass then
                    return child
                end
            end
        end
        
        -- Способ 3: Поиск через constraints
        local constraints = constraint.GetTable(vehicle)
        if constraints then
            for _, c in ipairs(constraints) do
                local other = nil
                if c.Ent1 == vehicle then
                    other = c.Ent2
                elseif c.Ent2 == vehicle then
                    other = c.Ent1
                end
                
                if IsValid(other) and other != vehicle then
                    local otherClass = other:GetClass()
                    
                    -- Проверяем через БД, является ли это прицепом
                    local checkQuery = "SELECT class FROM " .. TABLE_SERVER .. " WHERE class = " .. sql.SQLStr(otherClass)
                    local checkResult = sql.Query(checkQuery)
                    
                    if checkResult and checkResult[1] then
                        local trailerCheckQuery = "SELECT trailer_class FROM " .. TABLE_SERVER .. " WHERE class = " .. sql.SQLStr(otherClass)
                        local trailerCheckResult = sql.Query(trailerCheckQuery)
                        
                        if trailerCheckResult and trailerCheckResult[1] and (trailerCheckResult[1].trailer_class == "" or trailerCheckResult[1].trailer_class == nil) then
                            return other
                        end
                    end
                end
            end
        end
        
        return nil
    end

    local function FindMainVehicle(ent)
        if not IsValid(ent) then return nil end
        
        -- Проверяем, является ли ent прицепом (ищем его основную машину)
        local entClass = ent:GetClass()
        
        -- Проверяем, есть ли этот класс как trailer_class у какой-либо машины
        local query = "SELECT class FROM " .. TABLE_SERVER .. " WHERE trailer_class = " .. sql.SQLStr(entClass)
        local result = sql.Query(query)
        
        if result and result[1] then
            -- Этот ent - прицеп, ищем основную машину
            local mainClass = result[1].class
            
            -- Ищем основную машину через parent
            local parent = ent:GetParent()
            if IsValid(parent) and parent:GetClass() == mainClass then
                return parent
            end
            
            -- Ищем через constraints
            local constraints = constraint.GetTable(ent)
            if constraints then
                for _, c in ipairs(constraints) do
                    local other = nil
                    if c.Ent1 == ent then
                        other = c.Ent2
                    elseif c.Ent2 == ent then
                        other = c.Ent1
                    end
                    
                    if IsValid(other) and other:GetClass() == mainClass then
                        return other
                    end
                end
            end
            
            -- Ищем рядом
            local nearbyEnts = ents.FindInSphere(ent:GetPos(), 500)
            for _, nearby in ipairs(nearbyEnts) do
                if IsValid(nearby) and nearby:GetClass() == mainClass then
                    return nearby
                end
            end
        end
        
        -- Если не нашли, значит ent сам является основной машиной
        return ent
    end

    local function GetMainVehicle(ent)
        -- Если у ent уже есть ссылка на основную машину, возвращаем её
        if IsValid(ent.SVASMainVehicle) then
            return ent.SVASMainVehicle
        end
        
        local mainVehicle = FindMainVehicle(ent)
        
        if IsValid(mainVehicle) then
            -- Сохраняем ссылки в обе стороны
            mainVehicle.SVASMainVehicle = mainVehicle
            ent.SVASMainVehicle = mainVehicle
            
            -- Если нашли прицеп, сохраняем ссылку и в машине
            if mainVehicle != ent then
                mainVehicle.SVASTrailer = ent
                ent.SVASTrailer = ent
            end
            
            return mainVehicle
        end
        
        return ent
    end

    local function SpawnValidatorOnVehicle(vehicle, validatorData)
        local entityClass = string.lower(validatorData.model) == "bm20" and "bm20" or "aqsi_cube"
        
        -- Получаем основную машину
        local mainVehicle = GetMainVehicle(vehicle)
        
        -- Определяем родительский энтити
        local parentEnt = mainVehicle
        if validatorData.target == "trailer" then
            local trailer = mainVehicle.SVASTrailer
            if not IsValid(trailer) then
                trailer = FindTrailer(mainVehicle)
                if IsValid(trailer) then
                    mainVehicle.SVASTrailer = trailer
                    trailer.SVASMainVehicle = mainVehicle
                end
            end
            
            if IsValid(trailer) then
                parentEnt = trailer
                print("[SVAS] Валидатор прикреплен к прицепу: " .. trailer:GetClass())
            else
                print("[SVAS] Прицеп не найден, валидатор прикреплен к машине")
            end
        end
        
        local worldPos = parentEnt:LocalToWorld(validatorData.position)
        local worldAng = parentEnt:LocalToWorldAngles(validatorData.angles)
        
        local validatorEnt = ents.Create(entityClass)
        if not IsValid(validatorEnt) then 
            print("[SVAS] Ошибка: не удалось создать энтити " .. entityClass)
            return nil
        end
        
        validatorEnt:SetPos(worldPos)
        validatorEnt:SetAngles(worldAng)
        validatorEnt:Spawn()
        validatorEnt:Activate()
        
        validatorEnt:SetMoveType(MOVETYPE_NONE)
        validatorEnt:SetSolid(SOLID_VPHYSICS)
        
        local phys = validatorEnt:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableGravity(false)
            phys:EnableDrag(false)
            phys:Wake()
        end
        
        validatorEnt:SetParent(parentEnt)
        validatorEnt:SetLocalPos(validatorData.position)
        validatorEnt:SetLocalAngles(validatorData.angles)
        
        constraint.Weld(parentEnt, validatorEnt, 0, 0, 0, true, false)
        
        validatorEnt.ValidatorData = {
            model = validatorData.model,
            position = validatorData.position,
            angles = validatorData.angles,
            target = validatorData.target or "vehicle",
            parentVehicle = mainVehicle,
            actualParent = parentEnt
        }
        
        return validatorEnt
    end

    local function RemoveValidatorsFromVehicle(vehicle)
        local mainVehicle = GetMainVehicle(vehicle)
        
        -- Удаляем валидаторы с основной машины
        local children = mainVehicle:GetChildren()
        for i = #children, 1, -1 do
            local child = children[i]
            if IsValid(child) then
                local class = child:GetClass()
                if class == "aqsi_cube" or class == "bm20" then
                    constraint.RemoveConstraints(child, "Weld")
                    child:SetParent(nil)
                    child:Remove()
                end
            end
        end
        
        -- Удаляем валидаторы с прицепа
        local trailer = mainVehicle.SVASTrailer or FindTrailer(mainVehicle)
        if IsValid(trailer) then
            local trailerChildren = trailer:GetChildren()
            for i = #trailerChildren, 1, -1 do
                local child = trailerChildren[i]
                if IsValid(child) then
                    local class = child:GetClass()
                    if class == "aqsi_cube" or class == "bm20" then
                        constraint.RemoveConstraints(child, "Weld")
                        child:SetParent(nil)
                        child:Remove()
                    end
                end
            end
        end
    end

    function addorrm(com, model, imen, ent, num, updateData)
        -- Получаем основную машину
        local mainVehicle = GetMainVehicle(ent)
        
        if com == "add" then
            if IsValid(mainVehicle) then
                if not mainVehicle.Validators then
                    mainVehicle.Validators = {}
                end
                
                local maxValidators = GetMaxValidators(mainVehicle:GetClass())
                
                if #mainVehicle.Validators < maxValidators then
                    local localPos = Vector(0, 0, 0)
                    local localAng = Angle(0, 0, 0)
                    
                    local base = {
                        ["model"] = string.lower(model),
                        ["position"] = localPos,
                        ["angles"] = localAng,
                        ["immedenabled"] = imen,
                        ["target"] = updateData or "vehicle"
                    }
                    table.insert(mainVehicle.Validators, base)
                    SaveValidatorData(mainVehicle, mainVehicle.Validators)
                    
                    SpawnValidatorOnVehicle(mainVehicle, base)
                    
                    return true
                else
                    print("[SVAS] Достигнут максимум валидаторов для " .. mainVehicle:GetClass())
                    return false
                end
            else
                return false
            end
        elseif com == "rm" then
            if IsValid(mainVehicle) and mainVehicle.Validators then
                if num and mainVehicle.Validators[num] then
                    table.remove(mainVehicle.Validators, num)
                    SaveValidatorData(mainVehicle, mainVehicle.Validators)
                    
                    RemoveValidatorsFromVehicle(mainVehicle)
                    
                    for i, validatorData in ipairs(mainVehicle.Validators) do
                        SpawnValidatorOnVehicle(mainVehicle, validatorData)
                    end
                    
                    return true
                end
            end
            return false
        end
        
        return false
    end

    net.Receive("svas_refresh_validators", function(_, ply)
        local vehicle = net.ReadEntity()
        local mainVehicle = GetMainVehicle(vehicle)
        
        if not IsValid(mainVehicle) then return end
        
        if not mainVehicle.Validators then
            mainVehicle.Validators = {}
        end
        
        net.Start("svas_refresh_validators_response")
            net.WriteTable(mainVehicle.Validators)
        net.Send(ply)
    end)

    net.Receive("svas_create_validator", function(_, ply)
        local vehicle = net.ReadEntity()
        local validatorType = net.ReadString()
        local target = net.ReadString() or "vehicle"
        local mainVehicle = GetMainVehicle(vehicle)

        if not IsValid(mainVehicle) then return end

        local success = addorrm("add", validatorType, false, mainVehicle, nil, target)
        
        if success then
            ply:ChatPrint("[SVAS] Валидатор создан на " .. (target == "trailer" and "прицепе" or "машине") .. ".")
        else
            ply:ChatPrint("[SVAS] Не удалось создать валидатор.")
        end
    end)

    net.Receive("svas_remove_validator", function(_, ply)
        local vehicle = net.ReadEntity()
        local num = net.ReadInt(32)
        local mainVehicle = GetMainVehicle(vehicle)

        if not IsValid(mainVehicle) then return end

        local success = addorrm("rm", nil, nil, mainVehicle, num)
        
        if success then
            ply:ChatPrint("[SVAS] Валидатор #" .. num .. " удален.")
        else
            ply:ChatPrint("[SVAS] Не удалось удалить валидатор.")
        end
    end)

    net.Receive("svas_edit_validator", function(_, ply)
        local vehicle = net.ReadEntity()
        local num = net.ReadInt(32)
        local mainVehicle = GetMainVehicle(vehicle)

        if not IsValid(mainVehicle) then return end

        if not mainVehicle.Validators then
            mainVehicle.Validators = {}
        end

        if num and mainVehicle.Validators[num] then
            net.Start("svas_open_edit_menu")
                net.WriteEntity(mainVehicle)
                net.WriteInt(num, 32)
                net.WriteTable(mainVehicle.Validators[num])
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
        local newTarget = net.ReadString() or "vehicle"
        local mainVehicle = GetMainVehicle(vehicle)

        if not IsValid(mainVehicle) then return end

        if not mainVehicle.Validators then
            mainVehicle.Validators = {}
        end

        if num and mainVehicle.Validators[num] then
            mainVehicle.Validators[num].position = newPos
            mainVehicle.Validators[num].angles = newAng
            mainVehicle.Validators[num].target = newTarget
            
            SaveValidatorData(mainVehicle, mainVehicle.Validators)
            
            RemoveValidatorsFromVehicle(mainVehicle)
            for i, validatorData in ipairs(mainVehicle.Validators) do
                SpawnValidatorOnVehicle(mainVehicle, validatorData)
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

        -- Определяем основную машину (даже если кликнули по прицепу)
        local mainVehicle = GetMainVehicle(ent)
        
        if not IsValid(mainVehicle) then
            ply:ChatPrint("[SVAS] Не удалось определить основную машину.")
            return false
        end

        local mainClass = mainVehicle:GetClass()

        local query =
            "SELECT * FROM " .. TABLE_SERVER ..
            " WHERE class = " .. sql.SQLStr(mainClass) ..
            " OR trailer_class = " .. sql.SQLStr(mainClass)

        local rows = sql.Query(query)

        if not rows or not rows[1] then
            ply:ChatPrint("[SVAS] Этот транспорт не разрешен.")
            return true
        end

        local row = rows[1]

        if not mainVehicle.Validators then
            mainVehicle.Validators = {}
        end

        -- Ищем прицеп
        local trailer = FindTrailer(mainVehicle)
        if IsValid(trailer) then
            mainVehicle.SVASTrailer = trailer
            trailer.SVASMainVehicle = mainVehicle
            print("[SVAS] Найден прицеп: " .. trailer:GetClass() .. " для машины: " .. mainClass)
        else
            mainVehicle.SVASTrailer = nil
            print("[SVAS] Прицеп не найден для машины: " .. mainClass)
        end

        local validators = mainVehicle.Validators

        net.Start("validator_open_menu")
            net.WriteEntity(ent) -- Энтити по которому кликнули
            net.WriteString(row.class or mainClass)
            net.WriteString(row.name or mainClass)
            net.WriteString(row.trailer_class or "")
            net.WriteEntity(mainVehicle.SVASTrailer or NULL)
            net.WriteEntity(mainVehicle) -- Основная машина
            net.WriteTable(validators)
        net.Send(ply)

        return true
    end

end
