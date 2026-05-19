include('shared.lua')

surface.CreateFont("ValidatorTimeFont", {
    font = "Arial",
    size = 70,
    weight = 40,
    antialias = false,
    additive = true
})

function ENT:GetCurrentTime()
    return os.date("%H:%M")
end

function ENT:GetRouteInfo()
    -- Проверяем, что система троллейбусов существует
    if not Trolleybus_System then return "00" end

    -- Получаем родительский объект
    local parent = self:GetParent()
    if not IsValid(parent) then return "00" end

    local routeID
    -- Попытка через систему Nameplates
    if parent.GetSystem then
        local nameplates = parent:GetSystem("Nameplates")
        if nameplates and nameplates.GetRoute then
            routeID = nameplates:GetRoute(1)
        end

        local agit132 = parent:GetSystem("Agit-132")
        if agit132 and agit132.GetRoute then
            routeID = agit132:GetRoute(1)
        end
    end

    -- В случае если ничего не получено
    if not routeID then return "00" end

    -- Преобразуем в имя, если доступна система маршрутов
    if Trolleybus_System.Routes and Trolleybus_System.Routes.GetRouteName then
        return Trolleybus_System.Routes.GetRouteName(routeID) or routeID
    end

    return routeID
end

function ENT:Draw()
    local dist = LocalPlayer():EyePos():Distance(self:GetPos())
    local viewdist = 200
    local viewdistmax = viewdist
    local viewdistmin = viewdist * 0.80

    local alpha = 0

    if dist < viewdistmin then
        alpha = 255
    elseif dist > viewdistmax then
        alpha = 0 
    else
        alpha = 255 * (1 - (dist - viewdistmin) / (viewdistmax - viewdistmin))
    end

    self:DrawModel()

    local pos = self:GetPos() + self:GetUp() * 4.7 + self:GetForward() * 1.55 + self:GetRight() * 2.05
    local ang = self:GetAngles() 
    ang:RotateAroundAxis(self:GetUp(), -180)
    ang:RotateAroundAxis(self:GetRight(), -180)
    ang:RotateAroundAxis(self:GetForward(), -100)
    
    
    if alpha > 0 then
        cam.Start3D2D(pos, ang, 0.0033)
            local routeName = self:GetRouteInfo() 
            local parent = self:GetParent()
            draw.SimpleText("#"..self:EntIndex().." | Автобус № ".. routeName .." |  " .. self:GetCurrentTime(), "ValidatorTimeFont", -40, 0, Color(255, 255, 255, 79), TEXT_ALIGN_RIGHT, TEXT_ALIGN_RIGHT)
            
            if self:GetMaterial() == "gemc/bm20/BM20_Validator_Agree" then
                draw.SimpleText("Карта: №" ..self:GetNWInt("player_id"), "ValidatorTimeFont", -750, 70, Color(255, 255, 255, 79),  TEXT_ALIGN_LEFT,  TEXT_ALIGN_LEFT)
            end
        cam.End3D2D()
    end
end
