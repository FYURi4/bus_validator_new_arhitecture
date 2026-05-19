CATEGORY_NAME = "SVAS"
local TABLE_SERVER = "svas_agreelist"

local REQUIRED_COLUMNS = {
    name          = { type = "TEXT", default = "''" },
    class         = { type = "TEXT", default = "''" },
    trailer_class = { type = "TEXT", default = "''" },
    value_valid   = { type = "INTEGER", default = "0" },
    player_added  = { type = "TEXT", default = "''" },
    timestamp     = { type = "INTEGER", default = "0" },
}

-- Helper: ensure table exists and has all columns
local function ensureTable()
    -- Create table if missing
    local _, err = sql.Query([[
        CREATE TABLE IF NOT EXISTS ]] .. TABLE_SERVER .. [[ (
            name TEXT PRIMARY KEY,
            class TEXT NOT NULL,
            trailer_class TEXT DEFAULT '',
            value_valid INTEGER DEFAULT 0,
            player_added TEXT NOT NULL,
            timestamp INTEGER NOT NULL
        )
    ]])
    if err then
        print("[SVAS] ERROR creating table: " .. err)
        return false
    end

    -- Get existing columns
    local existing = sql.Query("PRAGMA table_info(" .. TABLE_SERVER .. ")")
    if not existing then
        print("[SVAS] WARNING: Could not read table_info – migration skipped.")
        return true
    end

    local existingCols = {}
    for _, row in ipairs(existing) do
        existingCols[row.name] = true
    end

    -- Add missing columns
    for colName, colDef in pairs(REQUIRED_COLUMNS) do
        if not existingCols[colName] then
            local alterSQL = "ALTER TABLE " .. TABLE_SERVER .. " ADD COLUMN " ..
                             colName .. " " .. colDef.type .. " DEFAULT " .. colDef.default
            local _, alterErr = sql.Query(alterSQL)
            if alterErr then
                print("[SVAS] Failed to add column '" .. colName .. "': " .. alterErr)
            else
                print("[SVAS] Added missing column '" .. colName .. "'")
                if colName == "name" then
                    print("[SVAS] WARNING: 'name' column added without PRIMARY KEY. Duplicate names are still prevented by Lua check.")
                end
            end
        end
    end
    return true
end

local function nameExists(name)
    local res = sql.Query("SELECT name FROM " .. TABLE_SERVER .. " WHERE name = " .. sql.SQLStr(name))
    return res and #res > 0
end

-- Функция для поиска трейлера по заспавненному транспорту (глобальная)
function FindTrailerForSpawnedVehicle(vehicleClass)
    if not vehicleClass then 
        print("[SVAS] Ошибка: не указан класс транспорта")
        return nil 
    end

    print("[SVAS] Поиск трейлера для класса: " .. vehicleClass)

    -- Ищем заспавненный транспорт этого класса
    local spawnedVehicles = {}
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and ent:GetClass() == vehicleClass then
            table.insert(spawnedVehicles, ent)
            print("[SVAS] Найден заспавненный транспорт: " .. vehicleClass .. " (индекс: " .. ent:EntIndex() .. ")")
        end
    end

    if #spawnedVehicles == 0 then
        print("[SVAS] Нет заспавненного транспорта класса " .. vehicleClass .. " - трейлер не добавлен")
        return nil
    end

    print("[SVAS] Найдено заспавненных транспортов: " .. #spawnedVehicles)

    -- Для каждого транспорта ищем трейлер
    for _, vehicle in ipairs(spawnedVehicles) do
        if IsValid(vehicle) then
            local vehiclePos = vehicle:GetPos()
            local vehicleAng = vehicle:GetAngles()
            local nearbyEnts = ents.FindInSphere(vehiclePos, 300) -- радиус поиска

            for _, ent in ipairs(nearbyEnts) do
                if IsValid(ent) and ent ~= vehicle then
                    local entClass = ent:GetClass()

                    -- Проверяем, является ли энтити трейлером
                    if string.find(entClass, "trailer") or
                       string.find(entClass, "прицеп") or
                       string.find(entClass, "trolleybus_trailer") or
                       string.find(entClass, "bus_trailer") or
                       string.find(entClass, "wagon") then

                        -- Проверяем ориентацию
                        local entAng = ent:GetAngles()
                        local angleDiff = math.abs(math.AngleDifference(entAng.y, vehicleAng.y))

                        if angleDiff < 45 or angleDiff > 315 then
                            print(string.format("[SVAS] Найден трейлер: %s для транспорта индекс %d", entClass, vehicle:EntIndex()))
                            return entClass  -- возвращаем класс первого подходящего трейлера
                        end
                    end
                end
            end
        end
    end

    print("[SVAS] Трейлер для класса " .. vehicleClass .. " не найден")
    return nil
end

function ulx.addagreelist(calling_ply, name, class, trailer_class, validators)
    if not calling_ply:IsSuperAdmin() then
        ULib.tsayError(calling_ply, "You do not have permission to use this command.", true)
        return
    end

    if not ensureTable() then
        ULib.tsayError(calling_ply, "Failed to prepare database table.", true)
        return
    end

    -- Проверка на существование имени (регистронезависимо)
    if nameExists(name) then
        ULib.tsayError(calling_ply, "An entry with the name \"" .. name .. "\" already exists.", true)
        return
    end

    -- Автоопределение трейлера, если не указан
    if trailer_class == nil or trailer_class == "" then
        ULib.tsay(calling_ply, "Trailer class not specified. Trying to auto‑detect...", true)
        local detected = FindTrailerForSpawnedVehicle(class)
        if detected then
            trailer_class = detected
            ULib.tsay(calling_ply, "Auto‑detected trailer class: " .. trailer_class, true)
        else
            trailer_class = ""
            ULib.tsay(calling_ply, "No trailer found – field will remain empty.", true)
        end
    end

    local valid = tonumber(validators) or 0
    if valid < 0 then valid = 0 end

    local sName = sql.SQLStr(name)
    local sClass = sql.SQLStr(class)
    local sTrailer = sql.SQLStr(trailer_class)
    local sPlayer = sql.SQLStr(calling_ply:SteamID())
    local stamp = os.time()

    local q = "INSERT INTO " .. TABLE_SERVER ..
              " (name, class, trailer_class, value_valid, player_added, timestamp) VALUES (" ..
              sName .. ", " .. sClass .. ", " .. sTrailer .. ", " .. valid .. ", " .. sPlayer .. ", " .. stamp .. ")"
    local _, err = sql.Query(q)
    if err then
        ULib.tsayError(calling_ply, "Database error: " .. err, true)
        print("[SVAS] addagreelist error: " .. err)
        return
    end

    ULib.tsay(calling_ply, "Vehicle \"" .. name .. "\" added successfully (trailer: " .. (trailer_class ~= "" and trailer_class or "none") .. ").", true)
    print("[SVAS] " .. calling_ply:Nick() .. " added vehicle \"" .. name .. "\"")
end

function ulx.readagreelist(calling_ply, name)
    if not ensureTable() then
        ULib.tsayError(calling_ply, "Database error.", true)
        return
    end

    local rows = sql.Query("SELECT * FROM " .. TABLE_SERVER)
    if not rows or #rows == 0 then
        ULib.tsay(calling_ply, "The agree list is empty.", true)
        print("[SVAS] Agree list is empty.")
        return
    end

    print("=== SVAS Agree List (all entries) ===")
    local count = 0
    for _, row in ipairs(rows) do
        count = count + 1
        local line = string.format("%d. name=%s, class=%s, trailer=%s, valid=%d, added by=%s, timestamp=%s",
            count,
            row.name,
            row.class,
            row.trailer_class or "none",
            tonumber(row.value_valid) or 0,
            row.player_added,
            os.date("%Y-%m-%d %H:%M:%S", tonumber(row.timestamp) or 0)
        )
        print(line)
        ULib.tsay(calling_ply, line, true)
    end
    print("=== End of list (" .. count .. " entries) ===")
    ULib.tsay(calling_ply, "Total entries: " .. count, true)
end

function ulx.rmagreelist(calling_ply, class_or_name)
    if not ensureTable() then
        ULib.tsayError(calling_ply, "Database error.", true)
        return
    end

    -- Приводим поисковую строку к нижнему регистру
    local searchLower = string.lower(class_or_name)

    -- Проверяем наличие записей (регистронезависимо)
    local checkQuery = "SELECT COUNT(*) as cnt FROM " .. TABLE_SERVER ..
                       " WHERE LOWER(name) = " .. sql.SQLStr(searchLower) ..
                       " OR LOWER(class) = " .. sql.SQLStr(searchLower)
    local checkRes = sql.Query(checkQuery)
    if not checkRes or not checkRes[1] then
        ULib.tsayError(calling_ply, "Database error during check.", true)
        return
    end

    local count = tonumber(checkRes[1].cnt) or 0
    if count == 0 then
        ULib.tsayError(calling_ply, "No entries found with name or class \"" .. class_or_name .. "\".", true)
        return
    end

    -- Удаляем найденные записи (регистронезависимо)
    local deleteQuery = "DELETE FROM " .. TABLE_SERVER ..
                        " WHERE LOWER(name) = " .. sql.SQLStr(searchLower) ..
                        " OR LOWER(class) = " .. sql.SQLStr(searchLower)
    local _, err = sql.Query(deleteQuery)
    if err then
        ULib.tsayError(calling_ply, "Failed to remove entries: " .. err, true)
        print("[SVAS] rmagreelist error: " .. err)
        return
    end

    ULib.tsay(calling_ply, "Removed " .. count .. " entry(ies) matching name or class \"" .. class_or_name .. "\".", true)
    print("[SVAS] " .. calling_ply:Nick() .. " removed " .. count .. " entries with name/class = " .. class_or_name)
end

-- Registration (unchanged parameter structure)
local addagreelist = ulx.command(CATEGORY_NAME, "ulx addagreelist", ulx.addagreelist, "!addagreelist")
addagreelist:addParam{ type=ULib.cmds.StringArg, hint="name" }
addagreelist:addParam{ type=ULib.cmds.StringArg, hint="class" }
addagreelist:addParam{ type=ULib.cmds.StringArg, hint="nil" }
addagreelist:addParam{ type=ULib.cmds.StringArg, hint="6" }
addagreelist:defaultAccess(ULib.ACCESS_SUPERADMIN)
addagreelist:help("SVAS AUDIT 3DEMC\nMachine name, Machine class, Trailer class attached to the machine (optional, but the machine must be spawned), Number of validators allowed to spawn (it is not recommended to set more than 6)")

local readagreelist = ulx.command(CATEGORY_NAME, "ulx readagreelist", ulx.readagreelist, "!readagreelist")
readagreelist:defaultAccess(ULib.ACCESS_SUPERADMIN)
readagreelist:help("SVAS AUDIT 3DEMC")

local rmagreelist = ulx.command(CATEGORY_NAME, "ulx rmagreelist", ulx.rmagreelist, "!rmagreelist")
rmagreelist:addParam{ type=ULib.cmds.StringArg, hint="class_or_name" }
rmagreelist:defaultAccess(ULib.ACCESS_SUPERADMIN)
rmagreelist:help("SVAS AUDIT 3DEMC\nSpecify the car's class or name")
