TOOL.Category = "Инструмент Валидатора"
TOOL.Name = "Validator Tool"
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.ManualPlacement = TOOL.ManualPlacement or {}

-- Функции для работы с владельцами
local function GetEntityOwner(ent)
    if not IsValid(ent) then return nil end
    return ent:GetNWEntity("Validator_Owner")
end

local function SetEntityOwner(ent, owner)
    if not IsValid(ent) or not IsValid(owner) then return end
    ent:SetNWEntity("Validator_Owner", owner)
end

local MAX_VALIDATORS = 6

-- Шаблоны валидаторов
local ValidatorTypes = {
    ["bm20"] = {
        name = "Валидатор BM20",
        model = "models/validator/validator_bm20.mdl",
        description = "Современный валидатор для безналичной оплаты"
    },
    ["bm10"] = {
        name = "Валидатор BM10", 
        model = "models/validator/validator_bm10.mdl",
        description = "Базовый валидатор для наличной оплаты"
    },
    ["bm30"] = {
        name = "Валидатор BM30",
        model = "models/validator/validator_bm30.mdl", 
        description = "Премиум валидатор с сенсорным экраном"
    }
}

-- Системы оплаты
local PaymentSystems = {
    ["cashless"] = "Безналичная оплата",
    ["cash"] = "Наличная оплата", 
    ["electronic_ticket"] = "Электронный билет",
    ["contact_card"] = "Контактная карта",
    ["qr_code"] = "QR-код"
}

-- Стандартные шаблоны транспорта
local ValidatorTemplates = {
    ["trolleybus_ent_ziu6205"] = {
        name = "ZiU 6205",
        terminals = {
            Left_Position = {
                {pos = Vector(17.6, -18, 25), ang = Angle(0, 60, 0)},
                {pos = Vector(130.5, -21, 25), ang = Angle(0, 120, 0)},
            },
            Right_Position = {
                {pos = Vector(-38.1, -18, 25), ang = Angle(0, 120, 0)},
                {pos = Vector(130.5, -21, 25), ang = Angle(0, 120, 0)},
            }
        }
    },
    ["trolleybus_ent_ziu682v013"] = {
        name = "ZiU 82v013",
        terminals = { 
            Left_Position = {
                {pos = Vector(164.2, -21, 25), ang = Angle(0, 120, 0)},
                {pos = Vector(51.3, -18, 25), ang = Angle(0, 60, 0)},
            },
            Right_Position = {
                {pos = Vector(164.2, -21, 25), ang = Angle(0, 120, 0)},
                {pos = Vector(-4.3, -18, 25), ang = Angle(0, 120, 0)},
            }
        }
    }
}

-- Система сохранения пользовательских шаблонов
local PlayerTemplates = {}

-- Загрузка шаблонов игрока
local function LoadPlayerTemplates(steamID)
    if CLIENT then
        if file.Exists("validator_templates/" .. steamID .. ".txt", "DATA") then
            local data = file.Read("validator_templates/" .. steamID .. ".txt", "DATA")
            PlayerTemplates[steamID] = util.JSONToTable(data) or {}
        else
            PlayerTemplates[steamID] = {}
        end
    end
end

-- Сохранение шаблонов игрока
local function SavePlayerTemplates(steamID, templates)
    if CLIENT then
        if not file.IsDir("validator_templates", "DATA") then
            file.CreateDir("validator_templates")
        end
        file.Write("validator_templates/" .. steamID .. ".txt", util.TableToJSON(templates or {}))
        PlayerTemplates[steamID] = templates or {}
    end
end

-- Функция для проверки доступа к транспорту
local function IsVehicleAllowed(vehicleClass)
    if SERVER then
        if not sql or not sql.Query then return true end
        
        local query = string.format("SELECT * FROM ulx_validators_vehicles WHERE vehicle_class = %s", sql.SQLStr(vehicleClass))
        local result = sql.Query(query)
        
        if result and #result > 0 then return true end
        
        if string.EndsWith(vehicleClass, "_trailer") then
            local mainClass = string.sub(vehicleClass, 1, -8)
            local mainQuery = string.format("SELECT * FROM ulx_validators_vehicles WHERE vehicle_class = %s", sql.SQLStr(mainClass))
            local mainResult = sql.Query(mainQuery)
            
            if mainResult and #mainResult > 0 then return true end
        end
        
        return false
    else
        if not ulx or not ulx.validatorsData or not ulx.validatorsData.vehicles then return true end
        
        for _, vehicleData in ipairs(ulx.validatorsData.vehicles) do
            if vehicleData.vehicle_class and vehicleData.vehicle_class:lower() == vehicleClass:lower() then
                return true
            end
        end
        
        if string.EndsWith(vehicleClass, "_trailer") then
            local mainClass = string.sub(vehicleClass, 1, -8)
            for _, vehicleData in ipairs(ulx.validatorsData.vehicles) do
                if vehicleData.vehicle_class and vehicleData.vehicle_class:lower() == mainClass:lower() then
                    return true
                end
            end
        end
        
        return false
    end
end

-- Функция для получения названия транспорта
local function GetVehicleNameFromDB(vehicleClass)
    if SERVER then
        if not sql or not sql.Query then return vehicleClass end
        
        local query = string.format("SELECT vehicle_name FROM ulx_validators_vehicles WHERE vehicle_class = %s", sql.SQLStr(vehicleClass))
        local result = sql.Query(query)
        
        if result and #result > 0 then return result[1].vehicle_name end
        
        if string.EndsWith(vehicleClass, "_trailer") then
            local mainClass = string.sub(vehicleClass, 1, -8)
            local mainQuery = string.format("SELECT vehicle_name FROM ulx_validators_vehicles WHERE vehicle_class = %s", sql.SQLStr(mainClass))
            local mainResult = sql.Query(mainQuery)
            
            if mainResult and #mainResult > 0 then return mainResult[1].vehicle_name .. " (Прицеп)" end
        end
        
        return vehicleClass
    else
        if not ulx or not ulx.validatorsData or not ulx.validatorsData.vehicles then return vehicleClass end
        
        for _, vehicleData in ipairs(ulx.validatorsData.vehicles) do
            if vehicleData.vehicle_class and vehicleData.vehicle_class:lower() == vehicleClass:lower() then
                return vehicleData.vehicle_name
            end
        end
        
        if string.EndsWith(vehicleClass, "_trailer") then
            local mainClass = string.sub(vehicleClass, 1, -8)
            for _, vehicleData in ipairs(ulx.validatorsData.vehicles) do
                if vehicleData.vehicle_class and vehicleData.vehicle_class:lower() == mainClass:lower() then
                    return vehicleData.vehicle_name .. " (Прицеп)"
                end
            end
        end
        
        return vehicleClass
    end
end

-- Функции уведомлений
local function ShowError(message, ply)
    if SERVER then
        if IsValid(ply) then ply:ChatPrint("❌ " .. message) end
    else
        notification.AddLegacy(message, NOTIFY_ERROR, 5)
        surface.PlaySound("buttons/button10.wav")
    end
end

local function ShowSuccess(message, ply)
    if SERVER then
        if IsValid(ply) then ply:ChatPrint("✅ " .. message) end
    else
        notification.AddLegacy(message, NOTIFY_GENERIC, 5)
        surface.PlaySound("buttons/button14.wav")
    end
end

-- Окно добавления валидатора в шаблон (объявляем ПЕРВЫМ!)
local function OpenAddToTemplateWindow(vehicle, tool, callback)
    if CLIENT then
        local screenW, screenH = ScrW(), ScrH()
        local frame = vgui.Create("DFrame")
        frame:SetTitle("Добавить валидатор в шаблон")
        frame:SetSize(math.min(screenW * 0.5, 500), math.min(screenH * 0.6, 400))
        frame:Center()
        frame:MakePopup()
        
        frame.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(40, 40, 50, 250))
        end
        
        local content = vgui.Create("DPanel", frame)
        content:Dock(FILL)
        content:DockMargin(15, 15, 15, 15)
        content.Paint = nil
        
        -- Выбор типа валидатора
        local typeLabel = vgui.Create("DLabel", content)
        typeLabel:Dock(TOP)
        typeLabel:SetText("Выберите тип валидатора:")
        typeLabel:SetTextColor(Color(255, 255, 255))
        typeLabel:SizeToContents()
        
        local typeCombo = vgui.Create("DComboBox", content)
        typeCombo:Dock(TOP)
        typeCombo:SetTall(25)
        typeCombo:DockMargin(0, 5, 0, 15)
        typeCombo:SetValue("Выберите тип...")
        
        for validatorType, validatorData in pairs(ValidatorTypes) do
            typeCombo:AddChoice(validatorData.name, validatorType)
        end
        
        -- Выбор системы оплаты
        local systemLabel = vgui.Create("DLabel", content)
        systemLabel:Dock(TOP)
        systemLabel:SetText("Выберите систему оплаты:")
        systemLabel:SetTextColor(Color(255, 255, 255))
        systemLabel:SizeToContents()
        
        local systemCombo = vgui.Create("DComboBox", content)
        systemCombo:Dock(TOP)
        systemCombo:SetTall(25)
        systemCombo:DockMargin(0, 5, 0, 15)
        systemCombo:SetValue("Выберите систему...")
        
        for systemID, systemName in pairs(PaymentSystems) do
            systemCombo:AddChoice(systemName, systemID)
        end
        
        -- Кнопки действий
        local buttonPanel = vgui.Create("DPanel", content)
        buttonPanel:Dock(BOTTOM)
        buttonPanel:SetTall(40)
        buttonPanel.Paint = nil
        
        local cancelBtn = vgui.Create("DButton", buttonPanel)
        cancelBtn:SetSize(120, 35)
        cancelBtn:SetPos(0, 0)
        cancelBtn:SetText("ОТМЕНА")
        cancelBtn:SetFont("DermaDefault")
        cancelBtn.DoClick = function() frame:Close() end
        cancelBtn.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(120, 120, 120, 255))
            if self:IsHovered() then
                draw.RoundedBox(6, 0, 0, w, h, Color(150, 150, 150, 255))
            end
        end
        
        local addBtn = vgui.Create("DButton", buttonPanel)
        addBtn:SetSize(120, 35)
        addBtn:SetPos(buttonPanel:GetWide() - 120, 0)
        addBtn:SetText("ДОБАВИТЬ")
        addBtn:SetFont("DermaDefaultBold")
        addBtn.DoClick = function()
            local _, validatorType = typeCombo:GetSelected()
            local _, systemID = systemCombo:GetSelected()
            
            if not validatorType then
                ShowError("Выберите тип валидатора!", LocalPlayer())
                return
            end
            
            if not systemID then
                ShowError("Выберите систему оплаты!", LocalPlayer())
                return
            end
            
            local validatorData = ValidatorTypes[validatorType]
            if not validatorData then return end
            
            -- Создаем данные валидатора
            local validatorInfo = {
                type = validatorType,
                name = validatorData.name,
                model = validatorData.model,
                system = systemID
            }
            
            -- Вызываем callback
            if callback then
                callback(validatorInfo)
            end
            
            frame:Close()
            ShowSuccess("Валидатор добавлен в шаблон!", LocalPlayer())
        end
        addBtn.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(80, 180, 80, 255))
            if self:IsHovered() then
                draw.RoundedBox(6, 0, 0, w, h, Color(100, 200, 100, 255))
            end
        end
    end
end

-- Основной GUI
local function OpenModernValidatorGUI(vehicle, tool)
    if CLIENT then
        local ply = LocalPlayer()
        local vehicleClass = vehicle:GetClass()
        local vehicleName = GetVehicleNameFromDB(vehicleClass)
        
        -- Закрываем предыдущее GUI
        if IsValid(tool.ValidatorGUI) then
            tool.ValidatorGUI:Close()
        end
        
        -- Проверяем доступ
        if not IsVehicleAllowed(vehicleClass) then
            ShowError("Этот транспорт не разрешен для установки валидаторов!", ply)
            return
        end
        
        -- Получаем установленные валидаторы
        local installedValidators = {}
        for _, v in pairs(ents.FindByClass("validator_ent")) do
            if IsValid(v) and IsValid(v:GetVehicle()) and v:GetVehicle() == vehicle then
                table.insert(installedValidators, v)
            end
        end
        
        local validatorCount = #installedValidators
        
        -- Загружаем шаблоны игрока
        local steamID = ply:SteamID()
        LoadPlayerTemplates(steamID)
        local playerTemplates = PlayerTemplates[steamID] or {}
        
        -- Получаем размеры экрана
        local screenW, screenH = ScrW(), ScrH()
        local frameW, frameH = math.min(screenW * 0.8, 900), math.min(screenH * 0.8, 700)
        
        -- Создаем главное окно
        local frame = vgui.Create("DFrame")
        frame:SetTitle("")
        frame:SetSize(frameW, frameH)
        frame:Center()
        frame:MakePopup()
        frame:ShowCloseButton(false)
        
        -- Сохраняем ссылку
        tool.ValidatorGUI = frame
        
        -- Фон окна
        frame.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 40, 250))
            draw.RoundedBoxEx(8, 0, 0, w, 50, Color(45, 45, 55, 255), true, true, false, false)
            draw.SimpleText("УСТАНОВКА ВАЛИДАТОРОВ", "DermaDefaultBold", w/2, 25, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(vehicleName, "DermaDefault", 20, 65, Color(200, 200, 220))
            draw.SimpleText("Установлено: " .. validatorCount .. "/" .. MAX_VALIDATORS, "DermaDefault", 20, 85, Color(150, 200, 255))
        end
        
        -- Кнопка закрытия
        local closeBtn = vgui.Create("DButton", frame)
        closeBtn:SetSize(40, 40)
        closeBtn:SetPos(frameW - 45, 5)
        closeBtn:SetText("✕")
        closeBtn:SetFont("DermaDefaultBold")
        closeBtn:SetTextColor(Color(255, 100, 100))
        closeBtn.DoClick = function() frame:Close() end
        closeBtn.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(60, 60, 70, 200))
            if self:IsHovered() then
                draw.RoundedBox(4, 0, 0, w, h, Color(80, 60, 60, 200))
            end
        end
        
        -- Панель вкладок
        local tabPanel = vgui.Create("DPanel", frame)
        tabPanel:SetPos(10, 110)
        tabPanel:SetSize(frameW - 20, 40)
        tabPanel.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(50, 50, 60, 255))
        end
        
        -- Контентная область
        local contentPanel = vgui.Create("DPanel", frame)
        contentPanel:SetPos(10, 160)
        contentPanel:SetSize(frameW - 20, frameH - 220)
        contentPanel.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(40, 40, 50, 200))
        end
        
        -- Вкладки
        local tabs = {
            {"УСТАНОВЛЕННЫЕ", "installed"},
            {"НОВЫЙ ШАБЛОН", "new_template"},
            {"ГОТОВЫЕ ШАБЛОНЫ", "templates"}, 
            {"ИНФОРМАЦИЯ", "info"}
        }
        
        local activeTab = "installed"
        
        -- Функция обновления контента
        local function UpdateContent()
            contentPanel:Clear()
            
            if activeTab == "installed" then
                -- Вкладка установленных валидаторов
                if #installedValidators == 0 then
                    local noValidators = vgui.Create("DLabel", contentPanel)
                    noValidators:SetPos(20, 20)
                    noValidators:SetSize(contentPanel:GetWide() - 40, 40)
                    noValidators:SetText("На этом транспорте нет установленных валидаторов")
                    noValidators:SetTextColor(Color(200, 200, 200))
                    noValidators:SetFont("DermaDefaultBold")
                    noValidators:SetContentAlignment(5)
                else
                    local scroll = vgui.Create("DScrollPanel", contentPanel)
                    scroll:Dock(FILL)
                    
                    local layout = vgui.Create("DIconLayout", scroll)
                    layout:Dock(FILL)
                    layout:SetSpaceY(10)
                    layout:SetSpaceX(10)
                    
                    for _, validator in ipairs(installedValidators) do
                        if IsValid(validator) then
                            local item = layout:Add("DPanel")
                            item:SetSize(contentPanel:GetWide() - 30, 80)
                            item.Paint = function(self, w, h)
                                draw.RoundedBox(6, 0, 0, w, h, Color(60, 60, 70, 255))
                                
                                local validatorName = validator:GetValidatorType() or "Валидатор BM20"
                                local validatorModel = validator:GetModel() or "models/validator/validator_bm20.mdl"
                                
                                draw.SimpleText(validatorName, "DermaDefaultBold", 70, 15, Color(255, 255, 255))
                                draw.SimpleText("Модель: " .. validatorModel, "DermaDefault", 70, 35, Color(180, 180, 200))
                                
                                local pos = validator:GetPos()
                                draw.SimpleText("Позиция: " .. math.Round(pos.x) .. ", " .. math.Round(pos.y) .. ", " .. math.Round(pos.z), "DermaDefault", 70, 55, Color(180, 180, 200))
                            end
                            
                            -- Иконка валидатора
                            local icon = vgui.Create("DModelPanel", item)
                            icon:SetSize(60, 60)
                            icon:SetPos(5, 10)
                            icon:SetModel(validator:GetModel() or "models/validator/validator_bm20.mdl")
                            
                            function icon:LayoutEntity(Entity) return end
                            
                            local mn, mx = icon.Entity:GetRenderBounds()
                            local size = math.max(math.abs(mn.x) + math.abs(mx.x), math.abs(mn.y) + math.abs(mx.y), math.abs(mn.z) + math.abs(mx.z))
                            
                            icon:SetFOV(40)
                            icon:SetCamPos(Vector(size, size, size))
                            icon:SetLookAt((mn + mx) * 0.5)
                            
                            -- Кнопка удаления
                            local removeBtn = vgui.Create("DButton", item)
                            removeBtn:SetSize(80, 25)
                            removeBtn:SetPos(item:GetWide() - 90, 45)
                            removeBtn:SetText("Удалить")
                            removeBtn:SetFont("DermaDefault")
                            removeBtn.DoClick = function()
                                net.Start("ValidatorTool_Remove")
                                    net.WriteEntity(validator)
                                net.SendToServer()
                                frame:Close()
                                ShowSuccess("Валидатор удален!", ply)
                            end
                            removeBtn.Paint = function(self, w, h)
                                draw.RoundedBox(4, 0, 0, w, h, Color(180, 80, 80, 255))
                                if self:IsHovered() then
                                    draw.RoundedBox(4, 0, 0, w, h, Color(200, 100, 100, 255))
                                end
                            end
                        end
                    end
                end
                
            elseif activeTab == "new_template" then
                -- Вкладка создания нового шаблона
                
                -- Верхняя панель с кнопкой Добавить
                local topPanel = vgui.Create("DPanel", contentPanel)
                topPanel:Dock(TOP)
                topPanel:SetTall(50)
                topPanel.Paint = function(self, w, h)
                    draw.RoundedBox(6, 0, 0, w, h, Color(50, 50, 60, 255))
                end
                
                local addBtn = vgui.Create("DButton", topPanel)
                addBtn:SetSize(120, 35)
                addBtn:SetPos(10, 7)
                addBtn:SetText("ДОБАВИТЬ")
                addBtn:SetFont("DermaDefaultBold")
                addBtn.DoClick = function()
                    OpenAddToTemplateWindow(vehicle, tool, function(validatorData)
                        tool.CurrentTemplate = tool.CurrentTemplate or {}
                        table.insert(tool.CurrentTemplate, validatorData)
                        UpdateContent()
                    end)
                end
                addBtn.Paint = function(self, w, h)
                    draw.RoundedBox(6, 0, 0, w, h, Color(80, 180, 80, 255))
                    if self:IsHovered() then
                        draw.RoundedBox(6, 0, 0, w, h, Color(100, 200, 100, 255))
                    end
                end
                
                local infoLabel = vgui.Create("DLabel", topPanel)
                infoLabel:SetPos(140, 15)
                infoLabel:SetSize(300, 20)
                infoLabel:SetText("Добавьте валидаторы в шаблон и сохраните его")
                infoLabel:SetTextColor(Color(200, 200, 200))
                
                -- Область текущего шаблона
                local currentTemplatePanel = vgui.Create("DPanel", contentPanel)
                currentTemplatePanel:Dock(TOP)
                currentTemplatePanel:SetTall(60)
                currentTemplatePanel:DockMargin(0, 5, 0, 5)
                currentTemplatePanel.Paint = function(self, w, h)
                    draw.RoundedBox(6, 0, 0, w, h, Color(55, 55, 65, 255))
                    draw.SimpleText("ТЕКУЩИЙ ШАБЛОН", "DermaDefaultBold", 10, 10, Color(255, 255, 255))
                end
                
                local templateNameEntry = vgui.Create("DTextEntry", currentTemplatePanel)
                templateNameEntry:SetPos(10, 30)
                templateNameEntry:SetSize(200, 25)
                templateNameEntry:SetPlaceholderText("Название шаблона")
                
                local saveBtn = vgui.Create("DButton", currentTemplatePanel)
                saveBtn:SetSize(100, 25)
                saveBtn:SetPos(220, 30)
                saveBtn:SetText("СОХРАНИТЬ")
                saveBtn:SetFont("DermaDefault")
                saveBtn.DoClick = function()
                    local templateName = templateNameEntry:GetValue()
                    if templateName == "" then
                        ShowError("Введите название шаблона!", ply)
                        return
                    end
                    
                    if not tool.CurrentTemplate or #tool.CurrentTemplate == 0 then
                        ShowError("Добавьте хотя бы один валидатор в шаблон!", ply)
                        return
                    end
                    
                    -- Сохраняем шаблон
                    PlayerTemplates[steamID] = PlayerTemplates[steamID] or {}
                    PlayerTemplates[steamID][templateName] = {
                        name = templateName,
                        validators = table.Copy(tool.CurrentTemplate),
                        created = os.time()
                    }
                    
                    SavePlayerTemplates(steamID, PlayerTemplates[steamID])
                    ShowSuccess("Шаблон '" .. templateName .. "' сохранен!", ply)
                    
                    -- Очищаем текущий шаблон
                    tool.CurrentTemplate = {}
                    templateNameEntry:SetText("")
                    UpdateContent()
                end
                saveBtn.Paint = function(self, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, Color(70, 130, 200, 255))
                    if self:IsHovered() then
                        draw.RoundedBox(4, 0, 0, w, h, Color(90, 150, 220, 255))
                    end
                end
                
                -- Список валидаторов в текущем шаблоне
                local templateScroll = vgui.Create("DScrollPanel", contentPanel)
                templateScroll:Dock(FILL)
                templateScroll:DockMargin(0, 5, 0, 0)
                
                local templateLayout = vgui.Create("DIconLayout", templateScroll)
                templateLayout:Dock(FILL)
                templateLayout:SetSpaceY(5)
                
                -- Отображаем валидаторы в текущем шаблоне
                if tool.CurrentTemplate and #tool.CurrentTemplate > 0 then
                    for i, validatorData in ipairs(tool.CurrentTemplate) do
                        local item = templateLayout:Add("DPanel")
                        item:SetSize(contentPanel:GetWide() - 30, 50)
                        item.Paint = function(self, w, h)
                            draw.RoundedBox(4, 0, 0, w, h, Color(60, 60, 70, 255))
                            draw.SimpleText(validatorData.name, "DermaDefault", 40, 10, Color(255, 255, 255))
                            draw.SimpleText("Система: " .. (PaymentSystems[validatorData.system] or validatorData.system), "DermaDefault", 40, 30, Color(180, 180, 200))
                        end
                        
                        -- Иконка
                        local icon = vgui.Create("DModelPanel", item)
                        icon:SetSize(30, 30)
                        icon:SetPos(5, 10)
                        icon:SetModel(validatorData.model)
                        
                        function icon:LayoutEntity(Entity) return end
                        local mn, mx = icon.Entity:GetRenderBounds()
                        local size = math.max(math.abs(mn.x) + math.abs(mx.x), math.abs(mn.y) + math.abs(mx.y), math.abs(mn.z) + math.abs(mx.z))
                        icon:SetFOV(30)
                        icon:SetCamPos(Vector(size, size, size))
                        icon:SetLookAt((mn + mx) * 0.5)
                        
                        -- Кнопка удаления из шаблона
                        local removeBtn = vgui.Create("DButton", item)
                        removeBtn:SetSize(25, 25)
                        removeBtn:SetPos(item:GetWide() - 30, 12)
                        removeBtn:SetText("✕")
                        removeBtn:SetFont("DermaDefaultBold")
                        removeBtn:SetTextColor(Color(255, 100, 100))
                        removeBtn.DoClick = function()
                            table.remove(tool.CurrentTemplate, i)
                            UpdateContent()
                        end
                        removeBtn.Paint = function(self, w, h)
                            draw.RoundedBox(4, 0, 0, w, h, Color(80, 60, 60, 200))
                            if self:IsHovered() then
                                draw.RoundedBox(4, 0, 0, w, h, Color(100, 80, 80, 200))
                            end
                        end
                    end
                else
                    local emptyLabel = vgui.Create("DLabel", templateLayout)
                    emptyLabel:SetSize(contentPanel:GetWide() - 30, 40)
                    emptyLabel:SetText("Шаблон пуст. Добавьте валидаторы с помощью кнопки 'ДОБАВИТЬ'")
                    emptyLabel:SetTextColor(Color(150, 150, 150))
                    emptyLabel:SetContentAlignment(5)
                end
                
                -- Раздел сохраненных шаблонов
                if table.Count(playerTemplates) > 0 then
                    local savedPanel = vgui.Create("DPanel", contentPanel)
                    savedPanel:Dock(TOP)
                    savedPanel:SetTall(30)
                    savedPanel:DockMargin(0, 10, 0, 0)
                    savedPanel.Paint = function(self, w, h)
                        draw.SimpleText("СОХРАНЕННЫЕ ШАБЛОНЫ", "DermaDefaultBold", 10, 10, Color(255, 255, 255))
                    end
                    
                    local savedScroll = vgui.Create("DScrollPanel", contentPanel)
                    savedScroll:Dock(FILL)
                    savedScroll:DockMargin(0, 5, 0, 0)
                    
                    local savedLayout = vgui.Create("DIconLayout", savedScroll)
                    savedLayout:Dock(FILL)
                    savedLayout:SetSpaceY(5)
                    
                    for templateName, templateData in SortedPairsByMemberValue(playerTemplates, "created", true) do
                        local item = savedLayout:Add("DPanel")
                        item:SetSize(contentPanel:GetWide() - 30, 60)
                        item.Paint = function(self, w, h)
                            draw.RoundedBox(6, 0, 0, w, h, Color(60, 60, 70, 255))
                            draw.SimpleText(templateData.name, "DermaDefaultBold", 10, 10, Color(255, 255, 255))
                            draw.SimpleText("Валидаторов: " .. #templateData.validators, "DermaDefault", 10, 30, Color(180, 180, 200))
                            draw.SimpleText(os.date("%d.%m.%Y %H:%M", templateData.created), "DermaDefault", 10, 45, Color(150, 150, 150))
                        end
                        
                        -- Кнопка применения
                        local applyBtn = vgui.Create("DButton", item)
                        applyBtn:SetSize(80, 25)
                        applyBtn:SetPos(item:GetWide() - 90, 17)
                        applyBtn:SetText("Применить")
                        applyBtn:SetFont("DermaDefault")
                        applyBtn.DoClick = function()
                            net.Start("ValidatorTool_ApplyPlayerTemplate")
                                net.WriteEntity(vehicle)
                                net.WriteString(templateName)
                                net.WriteTable(templateData.validators)
                            net.SendToServer()
                            frame:Close()
                            ShowSuccess("Шаблон '" .. templateName .. "' применен!", ply)
                        end
                        applyBtn.Paint = function(self, w, h)
                            draw.RoundedBox(4, 0, 0, w, h, Color(80, 180, 80, 255))
                            if self:IsHovered() then
                                draw.RoundedBox(4, 0, 0, w, h, Color(100, 200, 100, 255))
                            end
                        end
                        
                        -- Кнопка удаления шаблона
                        local deleteBtn = vgui.Create("DButton", item)
                        deleteBtn:SetSize(25, 25)
                        deleteBtn:SetPos(item:GetWide() - 30, 5)
                        deleteBtn:SetText("✕")
                        deleteBtn:SetFont("DermaDefaultBold")
                        deleteBtn:SetTextColor(Color(255, 100, 100))
                        deleteBtn.DoClick = function()
                            Derma_Query("Удалить шаблон '" .. templateName .. "'?", "Подтверждение",
                                "Да", function()
                                    PlayerTemplates[steamID][templateName] = nil
                                    SavePlayerTemplates(steamID, PlayerTemplates[steamID])
                                    UpdateContent()
                                    ShowSuccess("Шаблон удален!", ply)
                                end,
                                "Нет", function() end
                            )
                        end
                        deleteBtn.Paint = function(self, w, h)
                            draw.RoundedBox(4, 0, 0, w, h, Color(80, 60, 60, 200))
                            if self:IsHovered() then
                                draw.RoundedBox(4, 0, 0, w, h, Color(100, 80, 80, 200))
                            end
                        end
                    end
                end
                
            elseif activeTab == "templates" then
                -- Вкладка готовых шаблонов
                local scroll = vgui.Create("DScrollPanel", contentPanel)
                scroll:Dock(FILL)
                
                local layout = vgui.Create("DIconLayout", scroll)
                layout:Dock(FILL)
                layout:SetSpaceY(10)
                layout:SetSpaceX(10)
                
                for templateClass, templateData in pairs(ValidatorTemplates) do
                    local item = layout:Add("DPanel")
                    item:SetSize(contentPanel:GetWide() - 30, 60)
                    item.Paint = function(self, w, h)
                        draw.RoundedBox(6, 0, 0, w, h, Color(60, 60, 70, 255))
                        draw.SimpleText(templateData.name, "DermaDefaultBold", 50, 15, Color(255, 255, 255))
                        
                        local leftCount = templateData.terminals.Left_Position and #templateData.terminals.Left_Position or 0
                        local rightCount = templateData.terminals.Right_Position and #templateData.terminals.Right_Position or 0
                        draw.SimpleText("Позиции: Л-" .. leftCount .. " | П-" .. rightCount, "DermaDefault", 50, 35, Color(180, 180, 200))
                    end
                    
                    -- Кнопка применения
                    local applyBtn = vgui.Create("DButton", item)
                    applyBtn:SetSize(80, 30)
                    applyBtn:SetPos(item:GetWide() - 90, 15)
                    applyBtn:SetText("Применить")
                    applyBtn:SetFont("DermaDefault")
                    applyBtn.DoClick = function()
                        net.Start("ValidatorTool_Install")
                            net.WriteEntity(vehicle)
                            net.WriteString(templateClass)
                        net.SendToServer()
                        frame:Close()
                        ShowSuccess("Шаблон применен: " .. templateData.name, ply)
                    end
                    applyBtn.Paint = function(self, w, h)
                        draw.RoundedBox(4, 0, 0, w, h, Color(80, 180, 80, 255))
                        if self:IsHovered() then
                            draw.RoundedBox(4, 0, 0, w, h, Color(100, 200, 100, 255))
                        end
                    end
                end
                
            elseif activeTab == "info" then
                -- Вкладка информации
                local infoText = vgui.Create("DLabel", contentPanel)
                infoText:SetPos(20, 20)
                infoText:SetSize(contentPanel:GetWide() - 40, contentPanel:GetTall() - 40)
                infoText:SetText([[
Информация о системе валидаторов:

• Максимальное количество валидаторов на транспорт: ]] .. MAX_VALIDATORS .. [[

• Поддерживаются различные типы валидаторов
• Автоматическая установка по шаблонам
• Ручная настройка позиций

Для установки:
1. Выберите тип валидатора во вкладке "НОВЫЙ ШАБЛОН"
2. Или примените готовый шаблон во вкладке "ГОТОВЫЕ ШАБЛОНЫ"
3. Настройте параметры установки

Управление в ручном режиме:
• ЛКМ - установить валидатор
• R - повернуть валидатор  
• ПКМ - отмена установки
]])
                infoText:SetTextColor(Color(255, 255, 255))
                infoText:SetWrap(true)
                infoText:SetAutoStretchVertical(true)
            end
        end
        
        -- Создаем кнопки вкладок
        for i, tabData in ipairs(tabs) do
            local tabName, tabID = tabData[1], tabData[2]
            local btn = vgui.Create("DButton", tabPanel)
            btn:SetSize((tabPanel:GetWide() - 20) / #tabs, 32)
            btn:SetPos(10 + (i-1) * (btn:GetWide() + 5), 4)
            btn:SetText(tabName)
            btn:SetFont("DermaDefault")
            btn.tabID = tabID
            
            btn.Paint = function(self, w, h)
                if activeTab == self.tabID then
                    draw.RoundedBox(4, 0, 0, w, h, Color(70, 130, 200, 255))
                    self:SetTextColor(Color(255, 255, 255))
                else
                    draw.RoundedBox(4, 0, 0, w, h, Color(70, 70, 80, 200))
                    self:SetTextColor(Color(200, 200, 200))
                end
                if self:IsHovered() and activeTab ~= self.tabID then
                    draw.RoundedBox(4, 0, 0, w, h, Color(90, 90, 100, 200))
                end
            end
            
            btn.DoClick = function(self)
                activeTab = self.tabID
                UpdateContent()
            end
        end
        
        -- Кнопка выхода внизу
        local exitBtn = vgui.Create("DButton", frame)
        exitBtn:SetSize(120, 35)
        exitBtn:SetPos(frameW/2 - 60, frameH - 50)
        exitBtn:SetText("ВЫХОД")
        exitBtn:SetFont("DermaDefaultBold")
        exitBtn.DoClick = function() frame:Close() end
        exitBtn.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(180, 80, 80, 255))
            if self:IsHovered() then
                draw.RoundedBox(6, 0, 0, w, h, Color(200, 100, 100, 255))
            end
        end
        
        -- Инициализируем контент
        UpdateContent()
        
        -- Обработка закрытия
        frame.OnClose = function()
            if tool.ValidatorGUI == frame then
                tool.ValidatorGUI = nil
            end
        end
    end
end

-- Левый клик - открытие GUI
function TOOL:LeftClick(trace)
    if CLIENT then 
        local ent = trace.Entity
        if not IsValid(ent) then
            ShowError("Необходимо выбрать транспортное средство!", LocalPlayer())
            return false
        end
        
        -- Если в режиме ручной установки
        if self.ManualPlacement and self.ManualPlacement.Active then
            if IsValid(self.ManualPlacement.Vehicle) and ent == self.ManualPlacement.Vehicle then
                local pos = trace.HitPos
                local ang = trace.HitNormal:Angle()
                ang:RotateAroundAxis(ang:Right(), -90)
                
                net.Start("ValidatorTool_InstallManual")
                    net.WriteEntity(ent)
                    net.WriteVector(pos)
                    net.WriteAngle(ang)
                    net.WriteString(self.ManualPlacement.ValidatorType or "bm20")
                    net.WriteString(self.ManualPlacement.SystemID or "cashless")
                net.SendToServer()
                
                ShowSuccess("Валидатор установлен вручную!", LocalPlayer())
                self.ManualPlacement.Active = false
            end
            return true
        end
        
        -- Обычный режим - открываем GUI
        OpenModernValidatorGUI(ent, self)
        return true
    end
    
    return true
end

-- Правый клик - отмена ручной установки или информация
function TOOL:RightClick(trace)
    if CLIENT then
        if self.ManualPlacement and self.ManualPlacement.Active then
            self.ManualPlacement.Active = false
            notification.AddLegacy("Ручная установка отменена", NOTIFY_HINT, 3)
            return true
        end
        
        local ent = trace.Entity
        if not IsValid(ent) then 
            notification.AddLegacy("Наведите на транспортное средство", NOTIFY_HINT, 3)
            return false 
        end
        
        local vehicleClass = ent:GetClass()
        local vehicleName = GetVehicleNameFromDB(vehicleClass)
        local isAllowed = IsVehicleAllowed(vehicleClass)
        
        if isAllowed then
            notification.AddLegacy("✅ " .. vehicleName .. " - разрешен для валидаторов", NOTIFY_GENERIC, 5)
        else
            notification.AddLegacy("❌ " .. vehicleName .. " - запрещен для валидаторов", NOTIFY_ERROR, 5)
        end
        
        return true
    end
    
    return true
end

-- Обработка нажатий клавиш
function TOOL:KeyPress(key)
    if CLIENT and self.ManualPlacement and self.ManualPlacement.Active then
        if key == IN_RELOAD then
            if self.ManualPlacement.Angle then
                self.ManualPlacement.Angle:RotateAroundAxis(self.ManualPlacement.Angle:Up(), 45)
                notification.AddLegacy("Повернуто на 45 градусов", NOTIFY_HINT, 1)
            end
        end
    end
end

-- Хук для отрисовки HUD
function TOOL:DrawHUD()
    if CLIENT then
        local trace = self:GetOwner():GetEyeTrace()
        local ent = trace.Entity
        
        if self.ManualPlacement and self.ManualPlacement.Active then
            if IsValid(ent) and ent == self.ManualPlacement.Vehicle then
                local pos = trace.HitPos
                local ang = trace.HitNormal:Angle()
                ang:RotateAroundAxis(ang:Right(), -90)
                
                cam.Start3D()
                    render.SetColorMaterial()
                    render.DrawBox(pos, ang, Vector(-5, -5, 0), Vector(5, 5, 10), Color(0, 255, 0, 100))
                cam.End3D()
                
                local screenPos = pos:ToScreen()
                draw.SimpleText("ЛКМ - установить здесь", "DermaDefault", screenPos.x, screenPos.y + 20, Color(0, 255, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText("R - повернуть", "DermaDefault", screenPos.x, screenPos.y + 35, Color(255, 255, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText("ПКМ - отмена", "DermaDefault", screenPos.x, screenPos.y + 50, Color(255, 100, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            return
        end
        
        if not IsValid(ent) then return end
        
        local vehicleClass = ent:GetClass()
        local vehicleName = GetVehicleNameFromDB(vehicleClass)
        local isAllowed = IsVehicleAllowed(vehicleClass)
        
        local validatorCount = 0
        for _, v in pairs(ents.FindByClass("validator_ent")) do
            if IsValid(v) and IsValid(v:GetVehicle()) and v:GetVehicle() == ent then
                validatorCount = validatorCount + 1
            end
        end
        
        local screenPos = ent:GetPos():ToScreen()
        
        surface.SetDrawColor(0, 0, 0, 200)
        surface.DrawRect(screenPos.x - 150, screenPos.y - 40, 300, 80)
        
        surface.SetDrawColor(isAllowed and Color(0, 255, 0, 255) or Color(255, 0, 0, 255))
        surface.DrawOutlinedRect(screenPos.x - 150, screenPos.y - 40, 300, 80)
        
        draw.SimpleText(vehicleName, "DermaDefaultBold", screenPos.x, screenPos.y - 25, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        if isAllowed then
            draw.SimpleText("Разрешено для валидаторов", "DermaDefault", screenPos.x, screenPos.y - 5, Color(0, 255, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("Валидаторов: " .. validatorCount .. "/" .. MAX_VALIDATORS, "DermaDefault", screenPos.x, screenPos.y + 15, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("ЛКМ - открыть меню установки", "DermaDefault", screenPos.x, screenPos.y + 35, Color(200, 200, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText("ЗАПРЕЩЕНО ДЛЯ ВАЛИДАТОРОВ", "DermaDefault", screenPos.x, screenPos.y, Color(255, 0, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end

-- Сетевые сообщения
if SERVER then
    util.AddNetworkString("ValidatorTool_Remove")
    util.AddNetworkString("ValidatorTool_ApplyPlayerTemplate")
    util.AddNetworkString("ValidatorTool_Install")
    util.AddNetworkString("ValidatorTool_InstallManual")
    
    net.Receive("ValidatorTool_Remove", function(len, ply)
        local validator = net.ReadEntity()
        
        if not IsValid(validator) or not IsValid(ply) then return end
        
        if GetEntityOwner(validator) ~= ply and not ply:IsAdmin() then
            ShowError("Вы не можете удалить этот валидатор!", ply)
            return
        end
        
        validator:Remove()
        ShowSuccess("Валидатор удален!", ply)
    end)
    
    net.Receive("ValidatorTool_ApplyPlayerTemplate", function(len, ply)
        local vehicle = net.ReadEntity()
        local templateName = net.ReadString()
        local validators = net.ReadTable()
        
        if not IsValid(vehicle) or not IsValid(ply) then return end
        
        if not IsVehicleAllowed(vehicle:GetClass()) then
            ShowError("Этот транспорт не разрешен для установки валидаторов!", ply)
            return
        end
        
        local validatorCount = 0
        for _, v in pairs(ents.FindByClass("validator_ent")) do
            if IsValid(v) and IsValid(v:GetVehicle()) and v:GetVehicle() == vehicle then
                validatorCount = validatorCount + 1
            end
        end
        
        if validatorCount + #validators > MAX_VALIDATORS then
            ShowError("Недостаточно места для установки всех валидаторов!", ply)
            return
        end
        
        for _, validatorData in ipairs(validators) do
            local validator = ents.Create("validator_ent")
            if IsValid(validator) then
                local pos = vehicle:GetPos() + vehicle:GetForward() * (100 + #validators * 50)
                local ang = vehicle:GetAngles()
                
                validator:SetPos(pos)
                validator:SetAngles(ang)
                validator:Spawn()
                validator:Activate()
                
                SetEntityOwner(validator, ply)
                validator:SetVehicle(vehicle)
                validator:SetVehicleClass(vehicle:GetClass())
                validator:SetValidatorType(validatorData.type)
                validator:SetModel(validatorData.model)
                
                local vehicleName = GetVehicleNameFromDB(vehicle:GetClass())
                validator:SetVehicleName(vehicleName)
                
                validator:SetParent(vehicle)
            end
        end
        
        ShowSuccess("Шаблон '" .. templateName .. "' применен! Установлено " .. #validators .. " валидаторов", ply)
    end)
    
    -- Остальные сетевые сообщения для установки...
end

-- Панель настроек инструмента
function TOOL.BuildCPanel(panel)
    panel:AddControl("Header", {
        Description = "Инструмент для установки валидаторов на общественный транспорт"
    })
    
    local info = vgui.Create("DLabel", panel)
    info:SetText("ЛКМ - открыть меню установки\nПКМ - показать информацию о транспорте\nR - повернуть (в ручном режиме)")
    info:SetTextColor(Color(0, 0, 0))
    info:SetWrap(true)
    info:SetAutoStretchVertical(true)
    info:SetTall(50)
    panel:AddItem(info)
end

-- Загрузка шаблонов при инициализации
if CLIENT then
    hook.Add("InitPostEntity", "LoadValidatorTemplates", function()
        local ply = LocalPlayer()
        if IsValid(ply) then
            LoadPlayerTemplates(ply:SteamID())
        end
    end)
end