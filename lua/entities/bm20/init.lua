AddCSLuaFile('cl_init.lua')
AddCSLuaFile('shared.lua')
include('shared.lua')

util.AddNetworkString("BusValidator_UpdateOwner")

function ENT:Initialize()
    self:SetModel('models/gemc/bm20/bm20.mdl')
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    self:EntIndex()
    
    -- Текстуры
    self.textureSuccess = "gemc/bm20/BM20_Validator_Agree"
    self.textureDenied = "gemc/bm20/BM20_Validator_Denait"
    
    -- Звуки
    self.soundSuccess = "gemc/aqsi_cube/Agree.mp3"
    self.soundDenied = "gemc/aqsi_cube/Denait.mp3"
    
    self.originalMaterial = self:GetMaterial() or ""
    self.isProcessing = false
    self.showTime = false
    self.timeEnd = 0
    
    -- Просто устанавливаем скины без проверок (если скинов нет - ничего страшного)
    -- Скин 1 - загрузка
    self:SetSkin(1)
    
    -- Через 2 секунды скин 2 - прогрузка
    timer.Simple(2, function()
        if IsValid(self) then
            self:SetSkin(2)
            
            -- Через 2 секунды скин 3 - ожидание
            timer.Simple(2, function()
                if IsValid(self) then
                    self:SetSkin(3)
                end
            end)
        end
    end)
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    local wep = activator:GetActiveWeapon()
    if not IsValid(wep) or wep:GetClass() ~= "transport_card" then return end
    
    if self.isProcessing then return end
    
    local firstRoll = math.random(1, 3)
    
    if firstRoll == 3 then
        self.isProcessing = true
        self.showTime = true
        self.timeEnd = CurTime() + 6
        
        local secondRoll = math.random(1, 4)
        
        -- МГНОВЕННО показываем результат
        if secondRoll == 1 or secondRoll == 2 then
            -- Успешная оплата
            self:SetSkin(4)
            self:SetMaterial(self.textureSuccess)
            self:EmitSound(self.soundSuccess)
            self:SetNWInt("player_id", activator:AccountID())
        elseif secondRoll == 3 or secondRoll == 4 then
            -- Отказ
            self:SetSkin(5)
            self:SetMaterial(self.textureDenied)
            self:EmitSound(self.soundDenied)
        end
        
        -- Сброс валидатора через 6 секунд
        timer.Create("ValidatorReset_"..self:EntIndex(), 6, 1, function()
            if IsValid(self) then
                self:SetSkin(3) -- Возвращаем скин ожидания
                self:SetMaterial("") -- Сбрасываем материал
                self.isProcessing = false
                self.showTime = false
            end
        end)
    end
end

function ENT:OnRemove()
    timer.Remove("ValidatorReset_"..self:EntIndex())
end
