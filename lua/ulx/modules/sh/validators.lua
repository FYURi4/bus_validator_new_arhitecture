CATEGORY_NAME = "Validators"

-- Инициализация базы данных
local function initDatabase()
    if not sql.TableExists("ulx_validators_vehicles") then
        -- Используем правильный SQL запрос в одной строке
        local query = "CREATE TABLE ulx_validators_vehicles (id INTEGER PRIMARY KEY AUTOINCREMENT, vehicle_class TEXT UNIQUE NOT NULL, vehicle_name TEXT UNIQUE NOT NULL, added_by_steamid TEXT NOT NULL, added_date INTEGER NOT NULL)"
        sql.Query(query)
        
        -- Создаем индекс для быстрого поиска
        sql.Query("CREATE INDEX IF NOT EXISTS idx_vehicle_class ON ulx_validators_vehicles(vehicle_class)")
        sql.Query("CREATE INDEX IF NOT EXISTS idx_vehicle_name ON ulx_validators_vehicles(vehicle_name)")
        
        print("[ULX Validators] Database table created successfully")
    else
        print("[ULX Validators] Database table already exists")
    end
end

-- Инициализируем базу данных при старте сервера
if SERVER then
    initDatabase()
end

-- Добавление транспорта
function ulx.addvalidatorvehicle(calling_ply, vehicleClass, vehicleName)
    if not ULib.ucl.query(calling_ply, "ulx managevalidators") then
        ULib.tsayError(calling_ply, "У вас нет доступа к этой команде!", true)
        return
    end

    -- Проверяем, существует ли уже такой транспорт
    local checkQuery = sql.Query("SELECT * FROM ulx_validators_vehicles WHERE vehicle_class = " .. sql.SQLStr(vehicleClass) .. " OR vehicle_name = " .. sql.SQLStr(vehicleName))
    
    if checkQuery then
        ULib.tsayError(calling_ply, "Транспорт с таким классом или названием уже существует!", true)
        return
    end

    -- Добавляем транспорт в базу данных
    local query = string.format([[
        INSERT INTO ulx_validators_vehicles (vehicle_class, vehicle_name, added_by_steamid, added_date) 
        VALUES (%s, %s, %s, %d)
    ]], sql.SQLStr(vehicleClass), sql.SQLStr(vehicleName), sql.SQLStr(calling_ply:SteamID()), os.time())
    
    local result = sql.Query(query)
    
    if result == false then
        local error = sql.LastError()
        ULib.tsayError(calling_ply, "Ошибка при добавлении транспорта в базу данных: " .. (error or "неизвестная ошибка"), true)
        return
    end

    ulx.fancyLogAdmin(calling_ply, "#A добавил транспорт: #s (#s)", vehicleName, vehicleClass)
end

local addvehicle = ulx.command(CATEGORY_NAME, "ulx addvalidatorvehicle", ulx.addvalidatorvehicle, "!addvalidatorvehicle")
addvehicle:addParam{ type=ULib.cmds.StringArg, hint="vehicle_class" }
addvehicle:addParam{ type=ULib.cmds.StringArg, hint="vehicle_name" }
addvehicle:defaultAccess(ULib.ACCESS_SUPERADMIN)
addvehicle:help("Добавить транспорт для валидаторов.\nКласс является четко заданным параметром, название же может быть произвольным.")

-- Удаление транспорта по классу или имени
function ulx.removevalidatorvehicle(calling_ply, searchQuery)
    if not ULib.ucl.query(calling_ply, "ulx managevalidators") then
        ULib.tsayError(calling_ply, "У вас нет доступа к этой команде!", true)
        return
    end

    -- Получаем информацию о транспорте перед удалением для логов
    local getQuery = sql.Query("SELECT * FROM ulx_validators_vehicles WHERE vehicle_class = " .. sql.SQLStr(searchQuery) .. " OR vehicle_name = " .. sql.SQLStr(searchQuery))
    
    if not getQuery then
        ULib.tsayError(calling_ply, "Транспорт с классом или названием '" .. searchQuery .. "' не найден!", true)
        return
    end

    -- Удаляем транспорт из базы данных
    local query = "DELETE FROM ulx_validators_vehicles WHERE vehicle_class = " .. sql.SQLStr(searchQuery) .. " OR vehicle_name = " .. sql.SQLStr(searchQuery)
    local result = sql.Query(query)
    
    if result == false then
        local error = sql.LastError()
        ULib.tsayError(calling_ply, "Ошибка при удалении транспорта из базы данных: " .. (error or "неизвестная ошибка"), true)
        return
    end

    ulx.fancyLogAdmin(calling_ply, "#A удалил транспорт: #s (#s)", getQuery[1].vehicle_name, getQuery[1].vehicle_class)
end

local removevehicle = ulx.command(CATEGORY_NAME, "ulx removevalidatorvehicle", ulx.removevalidatorvehicle, "!removevalidatorvehicle")
removevehicle:addParam{ type=ULib.cmds.StringArg, hint="class_or_name" }
removevehicle:defaultAccess(ULib.ACCESS_SUPERADMIN)
removevehicle:help("Удалить транспорт по классу или названию")

-- Просмотр списка транспорта
function ulx.listvalidatorvehicles(calling_ply)
    if not ULib.ucl.query(calling_ply, "ulx managevalidators") then
        ULib.tsayError(calling_ply, "У вас нет доступа к этой команде!", true)
        return
    end

    local vehicles = sql.Query("SELECT * FROM ulx_validators_vehicles ORDER BY vehicle_name")
    
    if not vehicles or #vehicles == 0 then
        ULib.tsay(calling_ply, "Список транспорта пуст!")
        return
    end

    ULib.tsay(calling_ply, "=== Список транспорта для валидаторов ===")
    for i, v in ipairs(vehicles) do
        ULib.tsay(calling_ply, string.format("%d. %s (%s) - добавлен %s", i, v.vehicle_name, v.vehicle_class, os.date("%d.%m.%Y %H:%M", v.added_date)))
    end
end

local listvehicles = ulx.command(CATEGORY_NAME, "ulx listvalidatorvehicles", ulx.listvalidatorvehicles, "!listvalidatorvehicles")
listvehicles:defaultAccess(ULib.ACCESS_SUPERADMIN)
listvehicles:help("Показать список транспорта для валидаторов")

-- Функция для получения всех транспортных средств (может пригодиться для других частей кода)
function ulx.getValidatorVehicles()
    local vehicles = sql.Query("SELECT * FROM ulx_validators_vehicles ORDER BY vehicle_name") or {}
    return vehicles
end

-- Регистрируем доступ только для суперадминов
if SERVER then
    ULib.ucl.registerAccess("ulx managevalidators", ULib.ACCESS_SUPERADMIN, "Доступ к управлению валидаторами", "Category")
end
