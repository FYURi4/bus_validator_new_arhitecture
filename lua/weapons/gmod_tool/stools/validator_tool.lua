TOOL.Category = "Validator"
TOOL.Name = "Validator Tool"
TOOL.Command = nil
TOOL.ConfigName = ""

if CLIENT then
    surface.CreateFont("ValidatorFontClass", {
        font = "Roboto Bold",
        size = 60,
        weight = 1000
    })

    surface.CreateFont("ValidatorFontName", {
        font = "Roboto",
        size = 50,
        weight = 600
    })

    surface.CreateFont("ValidatorFontStatus", {
        font = "Roboto Black",
        size = 66,
        weight = 1000
    })

    surface.CreateFont("ValidatorFontSmall", {
        font = "Roboto",
        size = 42,
        weight = 500
    })
end

local LastCheck = 0
local CheckDelay = 0.5

function TOOL:Think()
    if not IsValid(self:GetOwner()) then return end
    local ply = self:GetOwner()
    local tr = ply:GetEyeTrace()

    if not IsValid(tr.Entity) then
        if SERVER then
            net.Start("validator_tool_clear")
            net.Send(ply)
        end
        return
    end

    local ent = tr.Entity
    if not ent:GetClass() then return end
    if CurTime() - LastCheck < CheckDelay then return end
    LastCheck = CurTime()

    if SERVER then
        local class = ent:GetClass()
        local data = sql.QueryRow("SELECT * FROM ulx_validators_vehicles WHERE vehicle_class = " .. sql.SQLStr(class))
        local allowed = data ~= nil

        net.Start("validator_tool_check_result")
        net.WriteEntity(ent)
        net.WriteBool(allowed)
        if data then
            net.WriteString(data.vehicle_class or "")
            net.WriteString(data.vehicle_name or "")
        else
            net.WriteString(class or "")
            net.WriteString("Not found")
        end
        net.Send(ply)
    end
end

if SERVER then
    util.AddNetworkString("validator_tool_check_result")
    util.AddNetworkString("validator_tool_clear")
    util.AddNetworkString("validator_tool_request_gui")
    util.AddNetworkString("validator_tool_open_gui")
    util.AddNetworkString("validator_tool_install")
    util.AddNetworkString("validator_tool_remove")
    util.AddNetworkString("validator_tool_get_templates")
    util.AddNetworkString("validator_tool_get_vehicle_info")
    util.AddNetworkString("validator_tool_apply_template")
    
    net.Receive("validator_tool_request_gui", function(len, ply)
        local ent = net.ReadEntity()
        if not IsValid(ent) then
            ply:ChatPrint("[Validator] Invalid target.")
            return
        end

        local class = ent:GetClass()
        local data = sql.QueryRow("SELECT * FROM ulx_validators_vehicles WHERE vehicle_class = " .. sql.SQLStr(class))
        local allowed = data ~= nil

        if not allowed then
            ply:ChatPrint("[Validator] Vehicle not allowed for validators.")
            return
        end

        ent._Validators = ent._Validators or {}
        local installed_count = #ent._Validators
        local max_count = 6

        net.Start("validator_tool_open_gui")
            net.WriteEntity(ent)
            net.WriteString(class or "")
            net.WriteString(data.vehicle_name or "")
            net.WriteInt(installed_count, 16)
            net.WriteInt(max_count, 16)
        net.Send(ply)
    end)

    net.Receive("validator_tool_install", function(len, ply)
        local ent = net.ReadEntity()
        local validatorName = net.ReadString()
        local validatorModel = net.ReadString()

        if not IsValid(ent) then
            ply:ChatPrint("[Validator] Invalid target.")
            return
        end

        local class = ent:GetClass()
        local data = sql.QueryRow("SELECT * FROM ulx_validators_vehicles WHERE vehicle_class = " .. sql.SQLStr(class))
        if not data then
            ply:ChatPrint("[Validator] Class not allowed.")
            return
        end

        ent._Validators = ent._Validators or {}
        if #ent._Validators >= 6 then
            ply:ChatPrint("[Validator] Maximum validators reached.")
            return
        end

        table.insert(ent._Validators, { name = validatorName or "Unknown", model = validatorModel or "" })

        ply:ChatPrint("[Validator] Validator installed: " .. (validatorName or "Unknown"))

        net.Start("validator_tool_open_gui")
            net.WriteEntity(ent)
            net.WriteString(class or "")
            net.WriteString(data.vehicle_name or "")
            net.WriteInt(#ent._Validators, 16)
            net.WriteInt(6, 16)
        net.Send(ply)
    end)

    net.Receive("validator_tool_remove", function(len, ply)
        local ent = net.ReadEntity()
        local index = net.ReadInt(16)

        if not IsValid(ent) then
            ply:ChatPrint("[Validator] Invalid target.")
            return
        end

        ent._Validators = ent._Validators or {}
        if not ent._Validators[index] then
            ply:ChatPrint("[Validator] Validator not found.")
            return
        end

        table.remove(ent._Validators, index)
        ply:ChatPrint("[Validator] Validator removed.")

        local class = ent:GetClass()
        local data = sql.QueryRow("SELECT * FROM ulx_validators_vehicles WHERE vehicle_class = " .. sql.SQLStr(class))
        net.Start("validator_tool_open_gui")
            net.WriteEntity(ent)
            net.WriteString(class or "")
            net.WriteString((data and data.vehicle_name) or "")
            net.WriteInt(#ent._Validators, 16)
            net.WriteInt(6, 16)
        net.Send(ply)
    end)

    net.Receive("validator_tool_get_templates", function(len, ply)
        local templates = sql.Query("SELECT * FROM ulx_shablon_valid_sv") or {}
        net.Start("validator_tool_get_templates")
        net.WriteTable(templates)
        net.Send(ply)
    end)

    net.Receive("validator_tool_get_vehicle_info", function(len, ply)
        local class = net.ReadString()
        local data = sql.QueryRow("SELECT * FROM ulx_validators_vehicles WHERE vehicle_class = " .. sql.SQLStr(class)) or {}
        net.Start("validator_tool_get_vehicle_info")
        net.WriteTable(data)
        net.Send(ply)
    end)

    net.Receive("validator_tool_apply_template", function(len, ply)
        local ent = net.ReadEntity()
        local templateName = net.ReadString()
        
        if not IsValid(ent) then
            ply:ChatPrint("[Validator] Invalid target.")
            return
        end

        local template = sql.QueryRow("SELECT * FROM ulx_shablon_valid_sv WHERE name_shablon_valid = " .. sql.SQLStr(templateName))
        
        if not template then
            ply:ChatPrint("[Validator] Template not found: " .. templateName)
            return
        end

        if ent:GetClass() ~= template.class_ent then
            ply:ChatPrint("[Validator] Template not compatible with this vehicle.")
            return
        end

        ent._Validators = ent._Validators or {}
        ent._Validators = {}

        local appliedCount = 0
        for i = 1, 6 do
            local pos_x = template["val"..i.."_pos_x"]
            local pos_y = template["val"..i.."_pos_y"]
            local pos_z = template["val"..i.."_pos_z"]
            
            if pos_x ~= nil and pos_y ~= nil and pos_z ~= nil then
                table.insert(ent._Validators, {
                    name = template.name_shablon_valid .. " Val" .. i,
                    model = template.validator_model_path or "models/props_lab/reciever01b.mdl",
                    pos = Vector(
                        tonumber(pos_x) or 0,
                        tonumber(pos_y) or 0, 
                        tonumber(pos_z) or 0
                    ),
                    ang = Angle(
                        tonumber(template["val"..i.."_ang_p"]) or 0,
                        tonumber(template["val"..i.."_ang_y"]) or 0,
                        tonumber(template["val"..i.."_ang_r"]) or 0
                    )
                })
                appliedCount = appliedCount + 1
            end
        end

        ply:ChatPrint("[Validator] Template '" .. templateName .. "' applied. Installed " .. appliedCount .. " validators.")

        local class = ent:GetClass()
        local data = sql.QueryRow("SELECT * FROM ulx_validators_vehicles WHERE vehicle_class = " .. sql.SQLStr(class))
        net.Start("validator_tool_open_gui")
            net.WriteEntity(ent)
            net.WriteString(class or "")
            net.WriteString((data and data.vehicle_name) or "")
            net.WriteInt(#ent._Validators, 16)
            net.WriteInt(6, 16)
        net.Send(ply)
    end)
    
else
    net.Receive("validator_tool_check_result", function()
        local ent = net.ReadEntity()
        local allowed = net.ReadBool()
        local vehicleClass = net.ReadString()
        local vehicleName = net.ReadString()

        if not IsValid(ent) then return end

        LocalPlayer().ValidatorTarget = ent
        LocalPlayer().ValidatorAllowed = allowed
        LocalPlayer().ValidatorClass = vehicleClass
        LocalPlayer().ValidatorName = vehicleName
        LocalPlayer().ValidatorAlpha = 255
        LocalPlayer().ValidatorLastSeen = CurTime()
    end)

    net.Receive("validator_tool_clear", function()
        LocalPlayer().ValidatorTarget = nil
        LocalPlayer().ValidatorAllowed = nil
        LocalPlayer().ValidatorClass = nil
        LocalPlayer().ValidatorName = nil
        LocalPlayer().ValidatorLastSeen = CurTime()
    end)
end

if CLIENT then
    hook.Add("PostDrawTranslucentRenderables", "ValidatorTool3D2D", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not IsValid(ply:GetActiveWeapon()) then return end
        local wep = ply:GetActiveWeapon()
        if not wep:IsValid() or wep:GetClass() ~= "gmod_tool" or wep:GetMode() ~= "validator_tool" then return end

        local ent = ply.ValidatorTarget
        local allowed = ply.ValidatorAllowed
        local class = ply.ValidatorClass
        local name = ply.ValidatorName

        if not IsValid(ent) or allowed == nil then return end

        ply.ValidatorAlpha = Lerp(FrameTime() * 5, ply.ValidatorAlpha or 0, (CurTime() - (ply.ValidatorLastSeen or 0) > 1 and 0) or 255)
        local alpha = math.Clamp(ply.ValidatorAlpha, 0, 255)
        if alpha < 5 then return end

        local classText = class or "unknown_class"
        local subText = allowed and "ALLOWED FOR VALIDATORS" or "NOT ALLOWED FOR VALIDATORS"
        local nameText = (allowed and name and name ~= "" and name ~= "Not found") and name or nil
        local countText = allowed and "Validators: 0 / 6" or nil

        local maxW = 0
        local function GetWidth(font, text)
            surface.SetFont(font)
            return surface.GetTextSize(text)
        end

        maxW = math.max(maxW, GetWidth("ValidatorFontClass", classText))
        if nameText then maxW = math.max(maxW, GetWidth("ValidatorFontName", nameText)) end
        if countText then maxW = math.max(maxW, GetWidth("ValidatorFontSmall", countText)) end
        maxW = math.max(maxW, GetWidth("ValidatorFontStatus", subText))

        local padding = 180
        local bgW = maxW + padding
        local bgH = allowed and 300 or 200

        local pos = ent:LocalToWorld(ent:OBBCenter() + Vector(0, 0, 40))
        local ang = Angle(0, ply:EyeAngles().y - 90, 90)

        local bgColor = Color(0, 0, 0, 170 * (alpha / 255))
        local borderColor = allowed and Color(0, 255, 0, 220 * (alpha / 255)) or Color(255, 0, 0, 220 * (alpha / 255))
        local subColor = allowed and Color(0, 255, 0, alpha) or Color(255, 0, 0, alpha)
        local textColor = Color(255, 255, 255, alpha)

        cam.IgnoreZ(true)

        cam.Start3D2D(pos, ang, 0.09)
            surface.SetDrawColor(bgColor)
            surface.DrawRect(-bgW / 2, -bgH / 2, bgW, bgH)

            surface.SetDrawColor(borderColor)
            surface.DrawOutlinedRect(-bgW / 2, -bgH / 2, bgW, bgH, 4)

            local y = -60
            draw.SimpleText(classText, "ValidatorFontClass", 0, y, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            if allowed and nameText then
                y = y + 55
                draw.SimpleText(nameText, "ValidatorFontName", 0, y, Color(220, 220, 220, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            if allowed and countText then
                y = y + 45
                draw.SimpleText(countText, "ValidatorFontSmall", 0, y, Color(240, 240, 240, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            y = (allowed and y + 55 or y + 110)
            draw.SimpleText(subText, "ValidatorFontStatus", 0, y, subColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()

        cam.IgnoreZ(false)
    end)
end

function TOOL:LeftClick(trace)
    local ply = self:GetOwner()
    if not IsValid(ply) then return false end

    if CLIENT then
        local ent = LocalPlayer().ValidatorTarget
        if not IsValid(ent) then
            chat.AddText(Color(255,100,100), "[Validator] ", Color(200,200,200), "No target selected.")
            return true
        end

        if LocalPlayer().ValidatorAllowed == false then
            Derma_Message("Vehicle not allowed for validators.", "Validator", "OK")
            return true
        end

        net.Start("validator_tool_request_gui")
        net.WriteEntity(ent)
        net.SendToServer()
        return true
    end

    return true
end

if CLIENT then
    local blur = Material("pp/blurscreen")

    local function DrawBlur(panel, amount)
        local x, y = panel:LocalToScreen(0, 0)
        local scrW, scrH = ScrW(), ScrH()

        surface.SetDrawColor(255, 255, 255)
        surface.SetMaterial(blur)

        for i = 1, 3 do
            blur:SetFloat("$blur", (i / 3) * (amount or 6))
            blur:Recompute()
            render.UpdateScreenEffectTexture()
            surface.DrawTexturedRect(-x, -y, scrW, scrH)
        end
    end

    local CurrentTemplates = {}
    local CurrentVehicleInfo = {}
    local ActiveTimers = {}

    local function RequestTemplates()
        net.Start("validator_tool_get_templates")
        net.SendToServer()
    end

    local function RequestVehicleInfo(class)
        net.Start("validator_tool_get_vehicle_info")
        net.WriteString(class)
        net.SendToServer()
    end

    local function StopAllTimers()
        for timerName, _ in pairs(ActiveTimers) do
            timer.Remove(timerName)
        end
        ActiveTimers = {}
    end

    local function HasValidatorCoordinates(template, index)
        local pos_x = template["val"..index.."_pos_x"]
        local pos_y = template["val"..index.."_pos_y"]
        local pos_z = template["val"..index.."_pos_z"]
        
        if pos_x == nil or pos_y == nil or pos_z == nil then
            return false
        end
        
        local num_x = tonumber(pos_x)
        local num_y = tonumber(pos_y)
        local num_z = tonumber(pos_z)
        
        return num_x ~= nil and num_y ~= nil and num_z ~= nil
    end

    local function CountValidatorsInTemplate(template)
        local count = 0
        for i = 1, 6 do
            if HasValidatorCoordinates(template, i) then
                count = count + 1
            end
        end
        return count
    end

    net.Receive("validator_tool_get_templates", function()
        CurrentTemplates = net.ReadTable() or {}
    end)

    net.Receive("validator_tool_get_vehicle_info", function()
        CurrentVehicleInfo = net.ReadTable() or {}
    end)

    local function OpenValidatorMenu(class, vehicle_name, ent, installed_count, max_count)
        if not IsValid(ent) then return end

        if IsValid(ValidatorMenu) then
            ValidatorMenu:Remove()
            StopAllTimers()
        end

        local w, h = 970, 750
        local frame = vgui.Create("DFrame")
        ValidatorMenu = frame
        frame:SetSize(w, h)
        frame:Center()
        frame:MakePopup()
        frame:SetDraggable(false)
        frame:ShowCloseButton(false)
        frame:SetTitle("")
        
        local contentPanel
        
        frame.Paint = function(s, ww, hh)
            DrawBlur(s, 6)
            surface.SetDrawColor(15, 15, 15, 230)
            surface.DrawRect(0, 0, ww, hh)
            surface.SetDrawColor(0, 180, 255, 4)
            surface.DrawOutlinedRect(0, 0, ww, hh, 2)
        end

        local header = vgui.Create("DPanel", frame)
        header:Dock(TOP)
        header:SetTall(70)
        header.Paint = function(s, ww, hh)
            surface.SetDrawColor(25, 25, 25, 240)
            surface.DrawRect(0, 0, ww, hh)
            draw.SimpleText("VALIDATOR MANAGER", "Trebuchet24", ww / 2, hh / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        local infoPanel = vgui.Create("DPanel", frame)
        infoPanel:Dock(TOP)
        infoPanel:SetTall(50)
        infoPanel:DockMargin(10, 5, 10, 5)
        infoPanel.Paint = function(s, ww, hh)
            surface.SetDrawColor(35, 35, 35, 220)
            surface.DrawRect(0, 0, ww, hh)
            surface.SetDrawColor(0, 150, 255, 40)
            surface.DrawOutlinedRect(0, 0, ww, hh, 1)
            
            draw.SimpleText("Class: " .. (class or "N/A"), "DermaDefault", 10, hh / 2 - 8, Color(255,255,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("Vehicle: " .. (vehicle_name or "Unknown"), "DermaDefault", 10, hh / 2 + 8, Color(200,200,200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("Validators: " .. (installed_count or 0) .. " / " .. (max_count or 6), "DermaDefault", ww - 10, hh / 2, Color(180, 180, 180), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        local tabPanel = vgui.Create("DPanel", frame)
        tabPanel:Dock(TOP)
        tabPanel:SetTall(45)
        tabPanel:DockMargin(10, 0, 10, 5)
        tabPanel.Paint = function(s, ww, hh)
            surface.SetDrawColor(30, 30, 30, 200)
            surface.DrawRect(0, 0, ww, hh)
        end

        local tabs = {
            {"INSTALLED VALIDATORS", true},
            {"TEMPLATES", false},
            {"NEW TEMPLATE", false},
            {"SETTINGS", false},
            {"VEHICLE INFO", false}
        }

        local tabButtons = {}
        local activeTab = 1

        local tabWidths = {200, 130, 140, 110, 140}

        contentPanel = vgui.Create("DPanel", frame)
        contentPanel:Dock(FILL)
        contentPanel:DockMargin(10, 0, 10, 10)
        contentPanel.Paint = function(s, ww, hh)
            surface.SetDrawColor(25, 25, 25, 200)
            surface.DrawRect(0, 0, ww, hh)
        end

        local function UpdateContent()
            if not IsValid(contentPanel) then return end
            
            contentPanel:Clear()
            
            if activeTab == 1 then
                local listHeader = vgui.Create("DLabel", contentPanel)
                listHeader:SetText("Installed Validators:")
                listHeader:SetFont("DermaDefaultBold")
                listHeader:SetTextColor(Color(255, 255, 255))
                listHeader:Dock(TOP)
                listHeader:SetTall(30)
                listHeader:DockMargin(10, 10, 10, 5)

                local installedScroll = vgui.Create("DScrollPanel", contentPanel)
                installedScroll:Dock(FILL)
                installedScroll:DockMargin(10, 0, 10, 10)

                local function RefreshInstalledList()
                    if not IsValid(installedScroll) then return end
                    
                    installedScroll:Clear()
                    
                    local vals = ent._Validators or {}
                    if #vals == 0 then
                        local emptyLabel = vgui.Create("DLabel", installedScroll)
                        emptyLabel:SetText("No validators installed")
                        emptyLabel:SetFont("DermaDefault")
                        emptyLabel:SetTextColor(Color(150, 150, 150))
                        emptyLabel:SetContentAlignment(5)
                        emptyLabel:Dock(TOP)
                        emptyLabel:SetTall(60)
                        emptyLabel:DockMargin(0, 10, 0, 0)
                        return
                    end

                    for i, validator in ipairs(vals) do
                        local validatorPanel = vgui.Create("DPanel", installedScroll)
                        validatorPanel:Dock(TOP)
                        validatorPanel:SetTall(80)
                        validatorPanel:DockMargin(0, 0, 0, 5)
                        validatorPanel.Paint = function(s, ww, hh)
                            surface.SetDrawColor(40, 40, 40, 220)
                            surface.DrawRect(0, 0, ww, hh)
                            surface.SetDrawColor(0, 120, 255, 60)
                            surface.DrawOutlinedRect(0, 0, ww, hh, 1)
                        end

                        local modelPanel = vgui.Create("DModelPanel", validatorPanel)
                        modelPanel:SetSize(70, 70)
                        modelPanel:SetPos(5, 5)
                        modelPanel:SetModel(validator.model or "models/props_lab/reciever01b.mdl")
                        function modelPanel:LayoutEntity() return end

                        local nameLabel = vgui.Create("DLabel", validatorPanel)
                        nameLabel:SetText(validator.name or "Unknown Validator")
                        nameLabel:SetFont("DermaDefaultBold")
                        nameLabel:SetTextColor(Color(255, 255, 255))
                        nameLabel:SetPos(85, 15)
                        nameLabel:SizeToContents()

                        local modelLabel = vgui.Create("DLabel", validatorPanel)
                        modelLabel:SetText("Model: " .. (validator.model or "Unknown"))
                        modelLabel:SetFont("DermaDefault")
                        modelLabel:SetTextColor(Color(180, 180, 180))
                        modelLabel:SetPos(85, 35)
                        modelLabel:SizeToContents()

                        local removeBtn = vgui.Create("DButton", validatorPanel)
                        removeBtn:SetText("Remove")
                        removeBtn:SetFont("DermaDefault")
                        removeBtn:SetSize(100, 30)
                        removeBtn:SetPos(validatorPanel:GetWide() - 110, 25)
                        removeBtn.Paint = function(s, ww, hh)
                            surface.SetDrawColor(200, 60, 60, 180)
                            surface.DrawRect(0, 0, ww, hh)
                        end
                        removeBtn.DoClick = function()
                            Derma_Query("Remove validator '" .. (validator.name or "Unknown") .. "'?", "Confirmation",
                                "Yes", function()
                                    net.Start("validator_tool_remove")
                                    net.WriteEntity(ent)
                                    net.WriteInt(i, 16)
                                    net.SendToServer()
                                end,
                                "No", function() end
                            )
                        end
                    end
                end
                RefreshInstalledList()

            elseif activeTab == 2 then
                RequestTemplates()
                
                local listHeader = vgui.Create("DLabel", contentPanel)
                listHeader:SetText("Available Templates:")
                listHeader:SetFont("DermaDefaultBold")
                listHeader:SetTextColor(Color(255, 255, 255))
                listHeader:Dock(TOP)
                listHeader:SetTall(30)
                listHeader:DockMargin(10, 10, 10, 5)

                local templatesScroll = vgui.Create("DScrollPanel", contentPanel)
                templatesScroll:Dock(FILL)
                templatesScroll:DockMargin(10, 0, 10, 10)

                local function RefreshTemplatesList()
                    if not IsValid(templatesScroll) then return end
                    
                    templatesScroll:Clear()
                    
                    if #CurrentTemplates == 0 then
                        local emptyLabel = vgui.Create("DLabel", templatesScroll)
                        emptyLabel:SetText("No templates available")
                        emptyLabel:SetFont("DermaDefault")
                        emptyLabel:SetTextColor(Color(150, 150, 150))
                        emptyLabel:SetContentAlignment(5)
                        emptyLabel:Dock(TOP)
                        emptyLabel:SetTall(60)
                        emptyLabel:DockMargin(0, 10, 0, 0)
                        return
                    end

                    for i, template in ipairs(CurrentTemplates) do
                        local templatePanel = vgui.Create("DPanel", templatesScroll)
                        templatePanel:Dock(TOP)
                        templatePanel:SetTall(140)
                        templatePanel:DockMargin(0, 0, 0, 5)
                        templatePanel.Paint = function(s, ww, hh)
                            surface.SetDrawColor(40, 40, 40, 220)
                            surface.DrawRect(0, 0, ww, hh)
                            surface.SetDrawColor(0, 150, 255, 60)
                            surface.DrawOutlinedRect(0, 0, ww, hh, 1)
                        end

                        local nameLabel = vgui.Create("DLabel", templatePanel)
                        nameLabel:SetText(template.name_shablon_valid or "Unnamed")
                        nameLabel:SetFont("DermaDefaultBold")
                        nameLabel:SetTextColor(Color(255, 255, 255))
                        nameLabel:SetPos(15, 15)
                        nameLabel:SizeToContents()

                        local classLabel = vgui.Create("DLabel", templatePanel)
                        classLabel:SetText("Class: " .. (template.class_ent or "N/A"))
                        classLabel:SetFont("DermaDefault")
                        classLabel:SetTextColor(Color(200, 200, 200))
                        classLabel:SetPos(15, 35)
                        classLabel:SizeToContents()

                        local sideLabel = vgui.Create("DLabel", templatePanel)
                        sideLabel:SetText("Side: " .. (template.installation_side or "N/A"))
                        sideLabel:SetFont("DermaDefault")
                        sideLabel:SetTextColor(Color(200, 200, 200))
                        sideLabel:SetPos(15, 55)
                        sideLabel:SizeToContents()

                        local modelLabel = vgui.Create("DLabel", templatePanel)
                        modelLabel:SetText("Model: " .. (template.validator_model_path or "N/A"))
                        modelLabel:SetFont("DermaDefault")
                        modelLabel:SetTextColor(Color(200, 200, 200))
                        modelLabel:SetPos(15, 75)
                        modelLabel:SizeToContents()

                        local validatorCount = CountValidatorsInTemplate(template)

                        local countLabel = vgui.Create("DLabel", templatePanel)
                        countLabel:SetText("Validators: " .. validatorCount .. " / 6")
                        countLabel:SetFont("DermaDefault")
                        countLabel:SetTextColor(validatorCount > 0 and Color(100, 255, 100) or Color(255, 100, 100))
                        countLabel:SetPos(15, 95)
                        countLabel:SizeToContents()

                        local buttonPanel = vgui.Create("DPanel", templatePanel)
                        buttonPanel:SetSize(200, 80)
                        buttonPanel:SetPos(templatePanel:GetWide() - 210, 30)
                        buttonPanel.Paint = function() end

                        local infoBtn = vgui.Create("DButton", buttonPanel)
                        infoBtn:SetText("Info")
                        infoBtn:SetFont("DermaDefault")
                        infoBtn:SetSize(60, 35)
                        infoBtn:SetPos(0, 0)
                        infoBtn.Paint = function(s, ww, hh)
                            surface.SetDrawColor(0, 100, 200, 180)
                            surface.DrawRect(0, 0, ww, hh)
                        end
                        infoBtn.DoClick = function()
                            local validatorDetails = ""
                            for j = 1, 6 do
                                if HasValidatorCoordinates(template, j) then
                                    local pos_x = template["val"..j.."_pos_x"] or 0
                                    local pos_y = template["val"..j.."_pos_y"] or 0
                                    local pos_z = template["val"..j.."_pos_z"] or 0
                                    validatorDetails = validatorDetails .. string.format("\nValidator %d: (%.1f, %.1f, %.1f)", j, pos_x, pos_y, pos_z)
                                end
                            end
                            
                            local infoText = string.format(
                                "Template: %s\nClass: %s\nSide: %s\nModel: %s\nValidators: %d/6%s\n\n%s",
                                template.name_shablon_valid or "N/A",
                                template.class_ent or "N/A", 
                                template.installation_side or "N/A",
                                template.validator_model_path or "N/A",
                                validatorCount,
                                validatorDetails,
                                template.class_ent == class and "✓ Compatible with this vehicle" or "✗ Not compatible with this vehicle"
                            )
                            
                            Derma_Message(infoText, "Template Information", "OK")
                        end

                        local useBtn = vgui.Create("DButton", buttonPanel)
                        useBtn:SetText("Apply")
                        useBtn:SetFont("DermaDefault")
                        useBtn:SetSize(120, 35)
                        useBtn:SetPos(70, 0)
                        useBtn:SetEnabled(validatorCount > 0 and template.class_ent == class)
                        useBtn.Paint = function(s, ww, hh)
                            if s:IsEnabled() then
                                surface.SetDrawColor(0, 150, 50, 180)
                            else
                                surface.SetDrawColor(100, 100, 100, 100)
                            end
                            surface.DrawRect(0, 0, ww, hh)
                        end
                        useBtn.DoClick = function()
                            if not useBtn:IsEnabled() then return end
                            
                            Derma_Query("Apply template '" .. (template.name_shablon_valid or "Unknown") .. "'?\nWill install " .. validatorCount .. " validators.", "Confirmation",
                                "Yes", function()
                                    net.Start("validator_tool_apply_template")
                                    net.WriteEntity(ent)
                                    net.WriteString(template.name_shablon_valid or "")
                                    net.SendToServer()
                                end,
                                "No", function() end
                            )
                        end

                        local warnings = {}
                        if template.class_ent ~= class then
                            table.insert(warnings, "✗ Incompatible vehicle")
                        end
                        if validatorCount == 0 then
                            table.insert(warnings, "✗ No validators configured")
                        end

                        if #warnings > 0 then
                            local warningText = table.concat(warnings, " | ")
                            local warningLabel = vgui.Create("DLabel", templatePanel)
                            warningLabel:SetText(warningText)
                            warningLabel:SetFont("DermaDefault")
                            warningLabel:SetTextColor(Color(255, 100, 100))
                            warningLabel:SetPos(15, 115)
                            warningLabel:SizeToContents()
                        end
                    end
                end

                timer.Remove("RefreshTemplates")
                ActiveTimers["RefreshTemplates"] = true
                timer.Create("RefreshTemplates", 0.5, 0, RefreshTemplatesList)
                RefreshTemplatesList()

            elseif activeTab == 3 then
                local newTemplateLabel = vgui.Create("DLabel", contentPanel)
                newTemplateLabel:SetText("Create New Template")
                newTemplateLabel:SetFont("DermaDefaultBold")
                newTemplateLabel:SetTextColor(Color(255, 255, 255))
                newTemplateLabel:Dock(TOP)
                newTemplateLabel:SetTall(40)
                newTemplateLabel:DockMargin(10, 20, 10, 10)
                newTemplateLabel:SetContentAlignment(5)

                local infoLabel = vgui.Create("DLabel", contentPanel)
                infoLabel:SetText("Feature in development")
                infoLabel:SetFont("DermaDefault")
                infoLabel:SetTextColor(Color(150, 150, 150))
                infoLabel:Dock(TOP)
                infoLabel:SetTall(30)
                infoLabel:DockMargin(10, 0, 10, 10)
                infoLabel:SetContentAlignment(5)

            elseif activeTab == 4 then
                local settingsLabel = vgui.Create("DLabel", contentPanel)
                settingsLabel:SetText("Validator Settings")
                settingsLabel:SetFont("DermaDefaultBold")
                settingsLabel:SetTextColor(Color(255, 255, 255))
                settingsLabel:Dock(TOP)
                settingsLabel:SetTall(40)
                settingsLabel:DockMargin(10, 20, 10, 10)
                settingsLabel:SetContentAlignment(5)

                local infoLabel = vgui.Create("DLabel", contentPanel)
                infoLabel:SetText("Feature in development")
                infoLabel:SetFont("DermaDefault")
                infoLabel:SetTextColor(Color(150, 150, 150))
                infoLabel:Dock(TOP)
                infoLabel:SetTall(30)
                infoLabel:DockMargin(10, 0, 10, 10)
                infoLabel:SetContentAlignment(5)

            elseif activeTab == 5 then
                RequestVehicleInfo(class)
                
                local infoLabel = vgui.Create("DLabel", contentPanel)
                infoLabel:SetText("Vehicle Information")
                infoLabel:SetFont("DermaDefaultBold")
                infoLabel:SetTextColor(Color(255, 255, 255))
                infoLabel:Dock(TOP)
                infoLabel:SetTall(40)
                infoLabel:DockMargin(10, 20, 10, 10)
                infoLabel:SetContentAlignment(5)

                local infoScroll = vgui.Create("DScrollPanel", contentPanel)
                infoScroll:Dock(FILL)
                infoScroll:DockMargin(20, 0, 20, 20)

                local function RefreshVehicleInfo()
                    if not IsValid(infoScroll) then return end
                    
                    infoScroll:Clear()
                    
                    local infoPanel = vgui.Create("DPanel", infoScroll)
                    infoPanel:Dock(TOP)
                    infoPanel:SetTall(300)
                    infoPanel:DockMargin(0, 0, 0, 10)
                    infoPanel.Paint = function(s, ww, hh)
                        surface.SetDrawColor(40, 40, 40, 220)
                        surface.DrawRect(0, 0, ww, hh)
                        surface.SetDrawColor(0, 120, 255, 60)
                        surface.DrawOutlinedRect(0, 0, ww, hh, 1)
                    end

                    local yPos = 20
                    local function AddInfoLine(text, value, color)
                        color = color or Color(255, 255, 255)
                        local label = vgui.Create("DLabel", infoPanel)
                        label:SetText(text .. ": " .. (value or "N/A"))
                        label:SetFont("DermaDefault")
                        label:SetTextColor(color)
                        label:SetPos(20, yPos)
                        label:SizeToContents()
                        yPos = yPos + 25
                    end

                    AddInfoLine("Vehicle Class", CurrentVehicleInfo.vehicle_class)
                    AddInfoLine("Vehicle Name", CurrentVehicleInfo.vehicle_name)
                    AddInfoLine("Added By", CurrentVehicleInfo.added_by_steamid or "Unknown")
                    AddInfoLine("Date Added", CurrentVehicleInfo.added_date or "Unknown")
                    AddInfoLine("Has Trailer", CurrentVehicleInfo.has_trailer and "Yes" or "No")
                    
                    if CurrentVehicleInfo.has_trailer then
                        AddInfoLine("Trailer Class", CurrentVehicleInfo.trailer_class)
                    end
                end

                timer.Remove("RefreshVehicleInfo")
                ActiveTimers["RefreshVehicleInfo"] = true
                timer.Create("RefreshVehicleInfo", 0.5, 0, RefreshVehicleInfo)
                RefreshVehicleInfo()
            end
        end

        for i, tabData in ipairs(tabs) do
            local tabName, isActive = tabData[1], tabData[2]
            local btn = vgui.Create("DButton", tabPanel)
            btn:SetText(tabName)
            btn:SetFont("DermaDefault")
            btn:SetTextColor(isActive and Color(255, 255, 255) or Color(150, 150, 150))
            btn:Dock(LEFT)
            btn:SetWide(tabWidths[i])
            btn:DockMargin(2, 2, 2, 2)
            btn.Paint = function(s, ww, hh)
                if activeTab == i then
                    surface.SetDrawColor(0, 120, 255, 200)
                    surface.DrawRect(0, 0, ww, hh)
                else
                    surface.SetDrawColor(50, 50, 50, 150)
                    surface.DrawRect(0, 0, ww, hh)
                end
            end
            btn.DoClick = function()
                activeTab = i
                for j, tabBtn in ipairs(tabButtons) do
                    tabBtn:SetTextColor(j == i and Color(255, 255, 255) or Color(150, 150, 150))
                end
                UpdateContent()
            end
            tabButtons[i] = btn
        end

        UpdateContent()

        local bottomPanel = vgui.Create("DPanel", frame)
        bottomPanel:Dock(BOTTOM)
        bottomPanel:SetTall(50)
        bottomPanel.Paint = function(s, ww, hh)
            surface.SetDrawColor(20, 20, 20, 220)
            surface.DrawRect(0, 0, ww, hh)
        end

        local closeBtn = vgui.Create("DButton", bottomPanel)
        closeBtn:SetText("CLOSE")
        closeBtn:SetFont("DermaDefault")
        closeBtn:SetTextColor(Color(255, 255, 255))
        closeBtn:SetWide(150)
        closeBtn:Dock(RIGHT)
        closeBtn:DockMargin(0, 10, 10, 10)
        closeBtn.Paint = function(s, ww, hh)
            surface.SetDrawColor(200, 40, 40, 180)
            surface.DrawRect(0, 0, ww, hh)
        end
        closeBtn.DoClick = function()
            StopAllTimers()
            frame:Close()
        end
    end

    net.Receive("validator_tool_open_gui", function()
        local ent = net.ReadEntity()
        local class = net.ReadString()
        local vehicle_name = net.ReadString()
        local installed_count = net.ReadInt(16)
        local max_count = net.ReadInt(16)

        ent._Validators = ent._Validators or {}
        OpenValidatorMenu(class, vehicle_name, ent, installed_count, max_count)
    end)
end
