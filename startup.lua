if not ship then
    if term.isColor() then term.setTextColor(colors.red) end
    print("ShipAPI unavailable. Either this computer is not on a ship, or CC-VS is not installed.")
    return
end
if not ship.setStatic then
    if term.isColor() then term.setTextColor(colors.red) end
    print(
        "ExtendedShipAPI unavailable. Requires either disable \"command_only\" in CC-VS config, or a command computer.")
    return
end

---------inner---------
local modelist = {
    { name = "spaceShip",  flag = false },
    { name = "quadFPV",    flag = false },
    { name = "helicopter", flag = false },
    { name = "airShip",    flag = false },
    { name = "hms_fly",    flag = false },
    { name = "follow",     flag = false },
    { name = "goHome",     flag = false },
    { name = "pointLoop ", flag = false }
}

local system, properties, attUtil, monitorUtil, joyUtil, pdControl, rayCaster, scanner, timeUtil
local physics_flag, shutdown_flag = true, false

---------system---------
system = {
    fileName = "dat",
    file = nil,
    modeIndex = 0,
}

system.init = function()
    system.file = io.open(system.fileName, "r")
    if system.file then
        local tmpProp = textutils.unserialise(system.file:read("a"))
        properties = system.reset()
        for k, v in pairs(properties) do
            if tmpProp[k] then
                properties[k] = tmpProp[k]
            end
        end
        tmpProp = system.reset()
        for k, v in pairs(tmpProp.profile.keyboard) do
            if not properties.profile.keyboard[k] then
                properties.profile.keyboard[k] = v
            end
        end
        for k, v in pairs(tmpProp.profile.joyStick) do
            if not properties.profile.joyStick[k] then
                properties.profile.joyStick[k] = v
            end
        end
        if properties.profile.keyboard.spaceShip_D > 3.52 then properties.profile.keyboard.spaceShip_D = 3.52 end
        if properties.profile.keyboard.quad_D > 3.52 then properties.profile.keyboard.quad_D = 3.52 end
        if properties.profile.joyStick.spaceShip_D > 3.52 then properties.profile.joyStick.spaceShip_D = 3.52 end
        if properties.profile.joyStick.quad_D > 3.52 then properties.profile.joyStick.quad_D = 3.52 end
        system.file:close()
    else
        properties = system.reset()
        system.updatePersistentData()
    end
end

system.reset = function()
    local firstMonitor = peripheral.find("monitor")
    local enabledMonitors = { "computer" }
    if firstMonitor then
        table.insert(enabledMonitors, peripheral.getName(firstMonitor))
    end
    return {
        userName = "fashaodesu",
        mode = 1,
        HOME = { x = 0, y = 120, z = 0 },
        homeList = {
            { x = 0, y = 120, z = 0 }
        },
        enabledMonitors = enabledMonitors,
        winIndex = {},
        profileIndex = "joyStick",
        profile = {
            keyboard = {
                spaceShip_P = 1,        --角速度比例, 决定转向快慢
                spaceShip_D = 3.52,     --角速度阻尼, 低了停的慢、太高了会抖动。标准是松杆时快速停下角速度、且停下时不会抖动
                spaceShip_Acc = 2,      --星舰模式油门速度
                spaceShip_SideMove = 2, --星舰模式横移速度
                spaceShip_Burner = 3.0, --星舰模式加力燃烧倍率
                spaceShip_move_D = 1.6, --移动阻尼, 低了停的慢、太高了会抖动。标准是松杆时快速停下、且停下时不会抖动
                quad_P = 1,
                quad_D = 3.52,
                quad_Acc = 1, --四轴FPV模式油门强度
                lock = false,
                helicopt_YAW_P = 0.75,
                helicopt_ROT_P = 0.75,
                helicopt_ROT_D = 0.75,
                helicopt_MAX_ANGLE = 30,
                helicopt_ACC = 0.5,
                helicopt_ACC_D = 0.75,
                airShip_ROT_P = 1,
                airShip_ROT_D = 0.5,
                airShip_MOVE_P = 1,
            },
            joyStick = {
                spaceShip_P = 1,        --角速度比例, 决定转向快慢
                spaceShip_D = 3.52,     --角速度阻尼, 低了停的慢、太高了会抖动。标准是松杆时快速停下角速度、且停下时不会抖动
                spaceShip_Acc = 2,      --星舰模式油门速度
                spaceShip_SideMove = 2, --星舰模式横移速度
                spaceShip_Burner = 3.0, --星舰模式加力燃烧倍率
                spaceShip_move_D = 1.6, --移动阻尼, 低了停的慢、太高了会抖动。标准是松杆时快速停下、且停下时不会抖动
                quad_P = 1,
                quad_D = 3.52,
                quad_Acc = 1, --四轴FPV模式油门强度
                lock = false,
                helicopt_YAW_P = 0.75,
                helicopt_ROT_P = 0.75,
                helicopt_ROT_D = 0.75,
                helicopt_MAX_ANGLE = 30,
                helicopt_ACC = 0.5,
                helicopt_ACC_D = 0.75,
                airShip_ROT_P = 1,
                airShip_ROT_D = 0.5,
                airShip_MOVE_P = 1,
            }
        },
        zeroPoint = 0,
        gravity = -1,
        airMass = 1, --空气密度 (风阻)
        rayCasterRange = 128,
        shipFace = "west",
        bg = "f",
        font = "8",
        title = "3",
        select = "3",
        other = "7",
        MAX_MOVE_SPEED = 99,                    --自动驾驶 (点循环、跟随模式) 最大跟随速度
        pointLoopWaitTime = 60,                 --点循环模式-到达目标点后等待时间 (tick)
        followRange = { x = -1, y = 0, z = 0 }, --跟随距离
        pointList = {                           --点循环模式，按照顺序逐个前往
            { x = -4499, y = 74, z = -896, yaw = 0, flip = false }
        }
    }
end

system.updatePersistentData = function()
    system.write(system.fileName, properties)
end

system.write = function(file, obj)
    system.file = io.open(file, "w")
    system.file:write(textutils.serialise(obj))
    system.file:close()
end

-----------function------------
function tableHasValue(targetTable, targetValue)
    for index, value in ipairs(targetTable) do
        if index ~= 'metatable' and value == targetValue then
            return true
        end
    end
    return false
end

local function joinArrayTables(...)
    local entries = {}
    for i = 1, select('#', ...) do
        local t = select(i, ...)
        for _, v in ipairs(t) do
            table.insert(entries, v)
        end
    end
    return entries
end

local function arrayTableDuplicate(targetTable)
    local entries = {}
    local seenValues = {}
    for i, v in ipairs(targetTable) do
        if not seenValues[v] then
            seenValues[v] = true
            table.insert(entries, v)
        end
    end
    return entries
end

local function arrayTableRemoveElement(targetTable, value)
    for i, v in ipairs(targetTable) do
        if v == value then
            table.remove(targetTable, i)
            return
        end
    end
end

local MatrixMultiplication = function(m, v)
    return {
        x = m[1][1] * v.x + m[1][2] * v.y,
        y = m[2][1] * v.x + m[2][2] * v.y
    }
end

local create_from_axis_angle = function(xx, yy, zz, a)
    local q = {}
    local factor = math.sin(a / 2.0)
    q.x = xx * factor
    q.y = yy * factor
    q.z = zz * factor
    q.w = math.cos(a / 2.0)

    return q
end

local getConjQuat = function(q)
    return {
        w = q.w,
        x = -q.x,
        y = -q.y,
        z = -q.z,
    }
end

function quatMultiply(q1, q2)
    local newQuat = {}
    newQuat.w = -q1.x * q2.x - q1.y * q2.y - q1.z * q2.z + q1.w * q2.w
    newQuat.x = q1.x * q2.w + q1.y * q2.z - q1.z * q2.y + q1.w * q2.x
    newQuat.y = -q1.x * q2.z + q1.y * q2.w + q1.z * q2.x + q1.w * q2.y
    newQuat.z = q1.x * q2.y - q1.y * q2.x + q1.z * q2.w + q1.w * q2.z
    return newQuat
end

function copysign(num1, num2)
    num1 = math.abs(num1)
    num1 = num2 > 0 and num1 or -num1
    return num1
end

function contrarysign(num1, num2)
    if ((num1 > 0 and num2 < 0) or (num1 < 0 and num2 > 0)) then
        return true
    else
        return false
    end
end

function formatN(val, n)
    n = math.pow(10, n or 1)
    val = tonumber(val)
    return math.floor(val * n) / n
end

function resetAngelRange(angle)
    if (math.abs(angle) > 180) then
        angle = math.abs(angle) >= 360 and angle % 360 or angle
        return -copysign(360 - math.abs(angle), angle)
    else
        return angle
    end
end

function RotateVectorByQuat(quat, v)
    local x = quat.x * 2
    local y = quat.y * 2
    local z = quat.z * 2
    local xx = quat.x * x
    local yy = quat.y * y
    local zz = quat.z * z
    local xy = quat.x * y
    local xz = quat.x * z
    local yz = quat.y * z
    local wx = quat.w * x
    local wy = quat.w * y
    local wz = quat.w * z
    local res = {}
    res.x = (1.0 - (yy + zz)) * v.x + (xy - wz) * v.y + (xz + wy) * v.z
    res.y = (xy + wz) * v.x + (1.0 - (xx + zz)) * v.y + (yz - wx) * v.z
    res.z = (xz - wy) * v.x + (yz + wx) * v.y + (1.0 - (xx + yy)) * v.z
    return res
end

function quat2Euler(quat)
    local FPoint = RotateVectorByQuat(quat, { x = 1, y = 0, z = 0 })
    local LPoint = RotateVectorByQuat(quat, { x = 0, y = 0, z = -1 })
    local TopPoint = RotateVectorByQuat(quat, { x = 0, y = 1, z = 0 })
    local ag = {}
    ag.pitch = math.deg(math.atan2(FPoint.y, copysign(math.sqrt(FPoint.x ^ 2 + FPoint.z ^ 2), TopPoint.y)))
    ag.yaw = math.deg(math.atan2(-FPoint.z, FPoint.x))
    ag.roll = math.deg(math.asin(LPoint.y))
    if math.abs(ag.pitch) > 80 then
        ag.yaw = -math.deg(math.atan2(LPoint.x, -LPoint.z))
    end
    if math.abs(ag.pitch) > 90 then
        ag.roll = -ag.roll
        ag.yaw = -ag.yaw
    end
    return ag
end

function getEulerByMatrix(matrix)
    return {
        yaw = math.deg(math.atan2(matrix[1][3], matrix[3][3])),
        pitch = math.deg(math.atan2(matrix[2][1], matrix[2][2])),
        roll = math.deg(math.atan2(-matrix[2][3], matrix[2][2]))
    }
end

function getEulerByMatrixLeft(matrix)
    return {
        yaw = math.deg(math.atan2(matrix[3][3], matrix[1][3])),
        pitch = math.deg(math.atan2(matrix[2][1], matrix[2][2])),
        roll = math.deg(math.atan2(matrix[2][3], matrix[2][2]))
    }
end

function euler2Quat(roll, yaw, pitch)
    local cy = math.cos(math.rad(yaw) * 0.5)
    local sy = math.sin(math.rad(yaw) * 0.5)
    local cp = math.cos(math.rad(pitch) * 0.5)
    local sp = math.sin(math.rad(pitch) * 0.5)
    local cr = math.cos(math.rad(roll) * 0.5)
    local sr = math.sin(math.rad(roll) * 0.5)
    local q = {
        w = cy * cp * cr + sy * sp * sr,
        x = cy * cp * sr - sy * sp * cr,
        y = sy * cp * sr + cy * sp * cr,
        z = sy * cp * cr - cy * sp * sr
    }
    return q
end

function quat2Axis(q)
    local angle = math.deg(math.acos(q.w) * 2)
    local s = math.sqrt(1 - q.w * q.w)
    local result = {}
    if (s < 0.001) then
        result.x = q.x
        result.y = q.y
        result.z = q.z
    else
        result.x = q.x / s
        result.y = q.y / s
        result.z = q.z / s
    end
    result.x = resetAngelRange(result.x * angle)
    result.y = resetAngelRange(result.y * angle)
    result.z = resetAngelRange(result.z * angle)
    return result
end

function genParticle(x, y, z)
    commands.execAsync(string.format("particle electric_spark %0.6f %0.6f %0.6f 0 0 0 0 0 force", x, y, z))
end

function genShootParticle(x, y, z)
    commands.execAsync(string.format("particle sonic_boom %0.6f %0.6f %0.6f 0 0 0 0 0 force", x, y, z))
end

function genParticleBomm(x, y, z)
    commands.execAsync(string.format("summon creeper %0.6f %0.6f %0.6f {ExplosionRadius:6,Fuse:0}", x, y, z))
end

function playFpvFanSound(x, y, z, pitch)
    commands.execAsync(string.format("playsound entity.bee.loop neutral @e[type=minecraft:player] %d %d %d 2 %0.4f 0.5",
        x, y, z, pitch))
end

function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

function split(input, delimiter)
    input = tostring(input)
    delimiter = tostring(delimiter)
    if (delimiter == "") then return false end
    local pos, arr = 0, {}
    for st, sp in function() return string.find(input, delimiter, pos, true) end do
        table.insert(arr, string.sub(input, pos, st - 1))
        pos = sp + 1
    end
    table.insert(arr, string.sub(input, pos))
    return arr
end

function genStr(s, count)
    local result = ""
    for i = 1, count, 1 do
        result = result .. s
    end
    return result
end

function getNextColor(color, index)
    local num = string.byte(string.sub(color, 1, 1))
    num = num + index
    if num < 48 then num = 102 end
    if num == 58 then num = 97 end
    if num == 103 then num = 48 end
    if num == 96 then num = 57 end
    return string.char(num)
end

function getColorDec(paint)
    paint = string.byte(string.sub(paint, 1, 1))
    local result
    if paint == 48 then
        result = 1
    elseif paint > 96 and paint < 103 then
        result = 2 ^ (paint - 87)
    elseif paint > 48 and paint < 58 then
        result = 2 ^ (paint - 48)
    end
    return result
end

-----------rayCaster-----------
rayCaster = {
    block = nil
}

rayCaster.run = function(start, v3Speed, range, showParticle)
    local vec = {}
    vec.x = start.x
    vec.y = start.y
    vec.z = start.z
    for i = 0, range, 1 do
        vec.x = vec.x + v3Speed.x
        vec.y = vec.y + v3Speed.y
        vec.z = vec.z + v3Speed.z

        rayCaster.block = coordinate.getBlock(vec.x - 1, vec.y, vec.z - 1)
        if (rayCaster.block ~= "minecraft:air" or i >= range) then
            break
        end
        if showParticle then
            genParticle(vec.x, vec.y, vec.z)
        end
    end
    return { x = vec.x, y = vec.y, z = vec.z, name = rayCaster.block }
end

rayCaster.runShoot = function(start, v3Speed, range, showParticle)
    local vec = {}
    vec.x = start.x
    vec.y = start.y
    vec.z = start.z
    for i = 0, range, 3 do
        vec.x = vec.x + v3Speed.x * 3
        vec.y = vec.y + v3Speed.y * 3
        vec.z = vec.z + v3Speed.z * 3

        rayCaster.block = coordinate.getBlock(vec.x - 1, vec.y, vec.z - 1)
        if (rayCaster.block ~= "minecraft:air" or i >= range) then
            --commands.execAsync(("say %s"):format(rayCaster.block))
            --commands.execAsync(("say x=%0.2f   y=%0.2f   z=%0.2f"):format(rayCaster.player.x, rayCaster.player.y, rayCaster.player.z))
            break
        end
        if showParticle then
            genShootParticle(vec.x, vec.y, vec.z)
        end
    end
    return { x = vec.x, y = vec.y, z = vec.z, name = rayCaster.block }
end
-----------scanner-----------
scanner = {
    commander = {},
    playerList = {},
    entities = {},
    vsShips = {},
    MONSTER = {
        "minecraft:zombie",
        "minecraft:spider",
        "minecraft:creeper",
        "minecraft:cave_spider",
        "minecraft:husk",
        "minecraft:husk",
        "minecraft:skeleton",
        "minecraft:wither_skeleton",
        "minecraft:guardian",
        "minecraft:phantom",
        "minecraft:pillager",
        "minecraft:ravager",
        "minecraft:vex",
        "minecraft:warden",
        "minecraft:vindicator",
        "minecraft:witch"
    }
}

scanner.scan = function()
    if not coordinate then
        return
    end
    scanner.entities = scanner.scanEntity()
    scanner.commander = scanner.getCommander()
end

scanner.scanShip = function()
    return coordinate.getShips(256)
end

scanner.scanEntity = function()
    return coordinate.getEntities(-1)
end

scanner.getCommander = function()
    local result
    if scanner.entities ~= nil then
        for k, v in pairs(scanner.entities) do
            if v.name == properties.userName then
                result = v

                result.yaw = math.deg(math.atan2(result.raw_euler_z, -result.raw_euler_x))
                if properties.shipFace == "west" then
                    result.pitch = -math.deg(math.asin(result.raw_euler_y))
                    result.roll = 0
                elseif properties.shipFace == "east" then
                    result.pitch = math.deg(math.asin(result.raw_euler_y))
                    result.roll = 0
                elseif properties.shipFace == "north" then
                    result.roll = math.deg(math.asin(result.raw_euler_y))
                    result.pitch = 0
                elseif properties.shipFace == "south" then
                    result.roll = -math.deg(math.asin(result.raw_euler_y))
                    result.pitch = 0
                end
                return result
            end
        end
    end
end

scanner.getRCAngle = function(range)
    local block =
        rayCaster.run(
            scanner.commander,
            {
                x = scanner.commander.raw_euler_x,
                y = scanner.commander.raw_euler_y,
                z = scanner.commander.raw_euler_z
            },
            range,
            false
        )
    local pos, targetAngle = {}, {}
    pos.x = attUtil.position.x - block.x
    pos.y = block.y - attUtil.position.y
    pos.z = attUtil.position.z - block.z

    targetAngle._c = math.sqrt(pos.x ^ 2 + pos.z ^ 2)
    targetAngle.distance = math.sqrt(targetAngle._c ^ 2 + pos.y ^ 2)
    targetAngle.pitch = -math.deg(math.asin(pos.y / targetAngle.distance))
    targetAngle.yaw = -math.deg(math.atan2(pos.z / targetAngle._c, pos.x / targetAngle._c))
    targetAngle.roll = 0
    return targetAngle
end

scanner.scanPlayer = function()
    if scanner.entities ~= nil then
        scanner.playerList = {}
        for k, v in pairs(scanner.entities) do
            if v.isPlayer then
                v.distance = math.sqrt((attUtil.position.x - v.x) ^ 2 +
                    (attUtil.position.y - v.y) ^ 2 + (attUtil.position.z - v.z) ^ 2)
                table.insert(scanner.playerList, 1, v)
            end
        end
        table.sort(scanner.playerList, function(a, b) return a.distance < b.distance end)
    end
end

---------timeUtil---------
timeUtil = {
    SpaceBasedGunCd = 1,
    pointLoopWaitTime = 1
}

---------attUtil---------
attUtil = {
    poseVel = {},
    inertia = {},
    position = {},
    prePos = {},
    size = {},
    mass = 0,
    quat = {},
    preQuat = {},
    matrix = {},
    omega = {},
    eulerAngle = {},
    preEuler = {},
    initPoint = {},
    velocity = {},
    speed = {},
    tmpFlags = {}
}
attUtil.quatList = {
    west  = { w = -1, x = 0, y = 0, z = 0 },
    south = { w = -0.70710678118654752440084436210485, x = 0, y = -0.70710678118654752440084436210485, z = 0 },
    east  = { w = 0, x = 0, y = -1, z = 0 },
    north = { w = -0.70710678118654752440084436210485, x = 0, y = 0.70710678118654752440084436210485, z = 0 },
}

attUtil.getAttWithCCTick = function()
    attUtil.mass = ship.getMass() * ship.getScale().x ^ 3
    attUtil.MomentOfInertiaTensor = ship.getMomentOfInertiaTensor()[1][1] * ship.getScale().x ^ 3

    attUtil.size = ship.getSize()
    attUtil.position = ship.getWorldspacePosition()
    attUtil.quat = quatMultiply(attUtil.quatList[properties.shipFace], ship.getQuaternion())
    attUtil.conjQuat = getConjQuat(ship.getQuaternion())
    attUtil.matrix = ship.getRotationMatrix()
    attUtil.eulerAngle = quat2Euler(attUtil.quat)
    attUtil.pX = RotateVectorByQuat(attUtil.quat, { x = 1, y = 0, z = 0 })
    attUtil.pY = RotateVectorByQuat(attUtil.quat, { x = 0, y = 1, z = 0 })
    attUtil.pZ = RotateVectorByQuat(attUtil.quat, { x = 0, y = 0, z = -1 })
    attUtil.getOmega(attUtil.pX, attUtil.pY, attUtil.pZ)
    attUtil.velocity.x = ship.getVelocity().x / 20
    attUtil.velocity.y = ship.getVelocity().y / 20
    attUtil.velocity.z = ship.getVelocity().z / 20
    attUtil.speed = math.sqrt(ship.getVelocity().x ^ 2 + ship.getVelocity().y ^ 2 + ship.getVelocity().z ^ 2)
    --commands.execAsync(("say roll=%0.2f  yaw=%0.2f  pitch=%0.2f"):format(attUtil.eulerAngle.roll, attUtil.eulerAngle.yaw, attUtil.eulerAngle.pitch))
    --commands.execAsync(("say w = %0.2f x=%0.2f  y=%0.2f  z=%0.2f"):format(attUtil.quat.w, attUtil.quat.x, attUtil.quat.y, attUtil.quat.z))
end

attUtil.getAttWithPhysTick = function()
    attUtil.mass = attUtil.inertia.mass * ship.getScale().x ^ 3
    attUtil.MomentOfInertiaTensor = attUtil.inertia.momentOfInertiaTensor[1][1] * ship.getScale().x ^ 3

    attUtil.size = ship.getSize()
    attUtil.position = attUtil.poseVel.pos
    attUtil.quat = quatMultiply(attUtil.quatList[properties.shipFace], attUtil.poseVel.rot)
    attUtil.conjQuat = getConjQuat(attUtil.poseVel.rot)
    attUtil.matrix = ship.getRotationMatrix()
    attUtil.eulerAngle = quat2Euler(attUtil.quat)
    attUtil.pX = RotateVectorByQuat(attUtil.quat, { x = 1, y = 0, z = 0 })
    attUtil.pY = RotateVectorByQuat(attUtil.quat, { x = 0, y = 1, z = 0 })
    attUtil.pZ = RotateVectorByQuat(attUtil.quat, { x = 0, y = 0, z = -1 })
    attUtil.getOmega(attUtil.pX, attUtil.pY, attUtil.pZ)
    attUtil.velocity.x = attUtil.poseVel.vel.x / 60
    attUtil.velocity.y = attUtil.poseVel.vel.y / 60
    attUtil.velocity.z = attUtil.poseVel.vel.z / 60
    attUtil.speed = math.sqrt(ship.getVelocity().x ^ 2 + ship.getVelocity().y ^ 2 + ship.getVelocity().z ^ 2)
end

attUtil.getOmega = function(xp, yp, zp)
    local XPoint = { x = xp.x, y = xp.y, z = xp.z }
    local ZPoint = { x = zp.x, y = zp.y, z = zp.z }
    attUtil.preQuat.x = -attUtil.preQuat.x
    attUtil.preQuat.y = -attUtil.preQuat.y
    attUtil.preQuat.z = -attUtil.preQuat.z
    XPoint = RotateVectorByQuat(attUtil.preQuat, XPoint)
    ZPoint = RotateVectorByQuat(attUtil.preQuat, ZPoint)
    attUtil.omega.roll = math.deg(math.asin(ZPoint.y))
    attUtil.omega.pitch = math.deg(math.asin(XPoint.y))
    attUtil.omega.yaw = math.deg(math.atan2(-XPoint.z, XPoint.x))
end

attUtil.setPreAtt = function()
    attUtil.prePos         = attUtil.position
    attUtil.preQuat        = attUtil.quat
    attUtil.preEuler.roll  = attUtil.eulerAngle.roll
    attUtil.preEuler.yaw   = attUtil.eulerAngle.yaw
    attUtil.preEuler.pitch = attUtil.eulerAngle.pitch
end

attUtil.init = function()
    attUtil.mass = ship.getMass()
    attUtil.position = ship.getWorldspacePosition()
    attUtil.prePos = attUtil.position
    attUtil.velocity = { x = 0, y = 0, z = 0 }
    attUtil.quat = quatMultiply(attUtil.quatList[properties.shipFace], ship.getQuaternion())
    attUtil.preQuat = attUtil.quat
    attUtil.eulerAngle = quat2Euler(attUtil.quat)
    attUtil.preEuler = { roll = 0, yaw = 0, pitch = 0 }
    attUtil.tmpFlags = {
        lastPos = attUtil.position,
        lastEuler = attUtil.eulerAngle,
        hmsLastAtt = attUtil.eulerAngle,
        followLastAtt = attUtil.position
    }
end

attUtil.setLastPos = function()
    attUtil.tmpFlags.lastPos = attUtil.position
    attUtil.tmpFlags.lastEuler = attUtil.eulerAngle
end

---------joyUtil---------
joyUtil = {
    joy = nil,
    LB = 0,
    RB = 0,
    LT = 0,
    RT = 0,
    back = 0,
    start = 0,
    LeftStick = { x = 0, y = 0 },
    RightStick = { x = 0, y = 0 },
    BTStick = { x = 0, y = 0 },
    faceList = {
        west  = { { 1, 0 }, { 0, 1 } },
        east  = { { -1, 0 }, { 0, -1 } },
        south = { { 0, 1 }, { -1, 0 } },
        north = { { 0, -1 }, { 1, 0 } },
    },
    faceListLeft = {
        west  = { { 1, 0 }, { 0, 1 } },
        east  = { { -1, 0 }, { 0, -1 } },
        south = { { 0, -1 }, { 1, 0 } },
        north = { { 0, 1 }, { -1, 0 } },
    },
    up = false,
    down = false,
    right = false,
    left = false,
    cd = 0,
    flag = false
}

joyUtil.getJoyInput = function()
    if not joyUtil.joy or not peripheral.hasType(joyUtil.joy, "tweaked_controller") then
        joyUtil.joy = peripheral.find("tweaked_controller")
    else
        joyUtil.defaultOutput()
    end
    if joyUtil.joy then
        joyUtil.flag = pcall(joyUtil.joy.hasUser)
        if not joyUtil.flag then
            return
        end
        if joyUtil.joy.hasUser() then
            joyUtil.LeftStick.x = -joyUtil.joy.getAxis(1)
            joyUtil.LeftStick.y = -joyUtil.joy.getAxis(2)
            joyUtil.RightStick.x = -joyUtil.joy.getAxis(3)
            joyUtil.RightStick.y = -joyUtil.joy.getAxis(4)
            joyUtil.LB = joyUtil.joy.getButton(5)
            joyUtil.RB = joyUtil.joy.getButton(6)
            joyUtil.LT = joyUtil.joy.getAxis(5)
            joyUtil.RT = joyUtil.joy.getAxis(6)
            joyUtil.back = joyUtil.joy.getButton(7)
            joyUtil.start = joyUtil.joy.getButton(8)
            joyUtil.up = joyUtil.joy.getButton(12)
            joyUtil.down = joyUtil.joy.getButton(14)
            joyUtil.left = joyUtil.joy.getButton(15)
            joyUtil.right = joyUtil.joy.getButton(13)
            joyUtil.LeftJoyClick = joyUtil.joy.getButton(10)
        else
            joyUtil.defaultOutput()
        end

        joyUtil.LB = joyUtil.LB and 1 or 0
        joyUtil.RB = joyUtil.RB and 1 or 0
        joyUtil.BTStick.x = joyUtil.LB - joyUtil.RB
        joyUtil.BTStick.y = joyUtil.LT - joyUtil.RT
        joyUtil.RightStick = MatrixMultiplication(joyUtil.faceList[properties.shipFace], joyUtil.RightStick)
        joyUtil.BTStick = MatrixMultiplication(joyUtil.faceListLeft[properties.shipFace], joyUtil.BTStick)

        if joyUtil.cd < 1 then
            if joyUtil.back or joyUtil.start then
                local index = properties.mode
                if joyUtil.start then
                    index = index < #modelist and index + 1 or 1
                elseif joyUtil.back then
                    index = index > 1 and index - 1 or #modelist
                end
                attUtil.setLastPos()
                properties.mode = index
                joyUtil.cd = 4
            elseif joyUtil.right or joyUtil.left then
                joyUtil.cd = 4
            end
        end
        joyUtil.cd = joyUtil.cd > 0 and joyUtil.cd - 1 or 0
    else
        joyUtil.defaultOutput()
    end
end

joyUtil.defaultOutput = function()
    joyUtil.LeftStick.x = 0
    joyUtil.LeftStick.y = 0
    joyUtil.RightStick.x = 0
    joyUtil.RightStick.y = 0
    joyUtil.LeftJoyClick = false
    joyUtil.LB = 0
    joyUtil.RB = 0
    joyUtil.LT = 0
    joyUtil.RT = 0
    joyUtil.back = false
    joyUtil.start = false
    joyUtil.up = false
    joyUtil.down = false
    joyUtil.right = false
end

---------PDcontrol---------
pdControl = {
    pitchSpeed = 0,
    rollSpeed = 0,
    yawSpeed = 0,
    xSpeed = 0,
    ySpeed = 0,
    zSpeed = 0,
    fixCd = 0,
    pointLoopIndex = 1,
    basicYSpeed = 10,
    helicopt_P_multiply = 1,
    helicopt_D_multiply = 1,
    rot_P_multiply = 1,
    rot_D_multiply = 1,
    move_P_multiply = 1,
    move_D_multiply = 100,
    airMass_multiply = 10
}

pdControl.moveWithOutRot = function(xVal, yVal, zVal, p, d)
    p = p * pdControl.move_P_multiply
    d = d * pdControl.move_D_multiply
    pdControl.xSpeed = xVal * p + -attUtil.velocity.x * d
    pdControl.zSpeed = zVal * p + -attUtil.velocity.z * d
    pdControl.ySpeed = yVal * p + pdControl.basicYSpeed + -attUtil.velocity.y * d

    ship.applyInvariantForce(pdControl.xSpeed * attUtil.mass,
        pdControl.ySpeed * attUtil.mass,
        pdControl.zSpeed * attUtil.mass)
end

pdControl.moveWithRot = function(xVal, yVal, zVal, p, d, sidemove_p)
    p = p * pdControl.move_P_multiply
    d = d * pdControl.move_D_multiply
    pdControl.xSpeed = -attUtil.velocity.x * d
    pdControl.zSpeed = -attUtil.velocity.z * d
    pdControl.ySpeed = yVal * p + pdControl.basicYSpeed + -attUtil.velocity.y * d

    ship.applyInvariantForce(pdControl.xSpeed * attUtil.mass,
        pdControl.ySpeed * attUtil.mass,
        pdControl.zSpeed * attUtil.mass)

    if sidemove_p then
        sidemove_p = sidemove_p * pdControl.move_P_multiply
        ship.applyRotDependentForce(xVal * p * attUtil.mass,
            0,
            zVal * sidemove_p * attUtil.mass)
    end
    ship.applyRotDependentForce(xVal * p * attUtil.mass,
        0,
        zVal * p * attUtil.mass)
end

pdControl.quadUp = function(yVal, p, d, hov)
    p = p * pdControl.move_P_multiply
    d = d * pdControl.move_D_multiply
    if hov then
        local omegaApplyRot = RotateVectorByQuat(attUtil.quat, { x = 0, y = attUtil.velocity.y, z = 0 })
        pdControl.ySpeed = (yVal + -math.deg(math.asin(properties.zeroPoint))) * p +
            pdControl.basicYSpeed * 2 + -omegaApplyRot.y * d
    else
        pdControl.ySpeed = (yVal + -math.deg(math.asin(properties.zeroPoint))) * p
    end

    ship.applyRotDependentForce(0, pdControl.ySpeed * attUtil.mass, 0)

    pdControl.xSpeed = copysign((attUtil.velocity.x ^ 2) * pdControl.airMass_multiply * properties.airMass,
        -attUtil.velocity.x)
    pdControl.zSpeed = copysign((attUtil.velocity.z ^ 2) * pdControl.airMass_multiply * properties.airMass,
        -attUtil.velocity.z)
    pdControl.ySpeed = copysign((attUtil.velocity.y ^ 2) * pdControl.airMass_multiply * properties.airMass,
        -attUtil.velocity.y)

    ship.applyInvariantForce(pdControl.xSpeed * attUtil.mass,
        pdControl.ySpeed * attUtil.mass + properties.gravity * pdControl.basicYSpeed * attUtil.mass,
        pdControl.zSpeed * attUtil.mass)
end

pdControl.rotInner = function(xRot, yRot, zRot, p, d)
    p                    = p * pdControl.rot_P_multiply
    d                    = d * pdControl.rot_D_multiply
    pdControl.pitchSpeed = (attUtil.omega.pitch + zRot) * p + -attUtil.omega.pitch * 7 * d
    pdControl.rollSpeed  = (attUtil.omega.roll + xRot) * p + -attUtil.omega.roll * 7 * d
    pdControl.yawSpeed   = (attUtil.omega.yaw + yRot) * p + -attUtil.omega.yaw * 7 * d
    ship.applyRotDependentTorque(
        pdControl.rollSpeed * attUtil.MomentOfInertiaTensor,
        pdControl.yawSpeed * attUtil.MomentOfInertiaTensor,
        pdControl.pitchSpeed * attUtil.MomentOfInertiaTensor)
end

pdControl.rotate2Euler = function(euler, p, d)
    local tgAg, roll, yaw, pitch = {}, 0, 0, 0
    local selfAg                 = attUtil.eulerAngle
    tgAg.roll                    = resetAngelRange(euler.roll - selfAg.roll)
    tgAg.yaw                     = resetAngelRange(euler.yaw - selfAg.yaw)
    tgAg.pitch                   = resetAngelRange(euler.pitch - selfAg.pitch)

    yaw                          = tgAg.yaw * (1 - attUtil.pX.y ^ 2) + -tgAg.roll * (attUtil.pX.y ^ 2)
    roll                         = tgAg.roll * (1 - attUtil.pX.y ^ 2) + tgAg.yaw * (attUtil.pX.y ^ 2)
    pitch                        = tgAg.pitch * (1 - attUtil.pZ.y ^ 2) + tgAg.yaw * (attUtil.pZ.y ^ 2)

    pdControl.rotInner(roll, yaw, pitch, p, d)
end

pdControl.rotate2Euler2 = function(euler, p, d)
    local x_c = math.cos(math.rad(euler.pitch))
    local tmpx = {
        x = -math.cos(math.rad(euler.yaw)) * x_c,
        y = -math.sin(math.rad(euler.pitch)),
        z = math.sin(math.rad(euler.yaw)) * x_c
    }
    euler.yaw = -euler.yaw
    local z_c = math.cos(math.rad(euler.roll))
    local tmpz = {
        x = math.sin(math.rad(euler.yaw)) * z_c,
        y = -math.sin(math.rad(euler.roll)),
        z = -math.cos(math.rad(euler.yaw)) * z_c
    }

    tmpx = RotateVectorByQuat(attUtil.conjQuat, tmpx)
    tmpz = RotateVectorByQuat(attUtil.conjQuat, tmpz)
    local xRot = math.deg(math.asin(tmpz.y))
    local yRot = math.deg(math.atan2(tmpx.z, -tmpx.x))
    local zRot = -math.deg(math.asin(tmpx.y))

    pdControl.rotInner(xRot, yRot, zRot, p, d)
end

pdControl.spaceShip = function()
    if properties.profile[properties.profileIndex].lock then
        if next(attUtil.tmpFlags.lastEuler) == nil then attUtil.setLastPos() end
        if next(attUtil.tmpFlags.lastPos) == nil then attUtil.setLastPos() end
        pdControl.gotoPosition(attUtil.tmpFlags.lastEuler, attUtil.tmpFlags.lastPos)
    else
        local forward, up, sideMove = math.deg(math.asin(joyUtil.BTStick.y)), math.deg(math.asin(joyUtil.LeftStick.y)),
            math.deg(math.asin(joyUtil.BTStick.x))
        local xRot, yRot, zRot = math.deg(math.asin(joyUtil.RightStick.x)), math.deg(math.asin(joyUtil.LeftStick.x)),
            math.deg(math.asin(joyUtil.RightStick.y))
        if joyUtil.LeftJoyClick then
            local p = properties.profile[properties.profileIndex].spaceShip_Burner
            forward, up, sideMove = forward * p, up * p, sideMove * p
            --p = p / 2
            --xRot, yRot, zRot = xRot * p, yRot * p, zRot * p
        end
        pdControl.moveWithRot(forward, up, sideMove,
            properties.profile[properties.profileIndex].spaceShip_Acc,
            properties.profile[properties.profileIndex].spaceShip_move_D,
            properties.profile[properties.profileIndex].spaceShip_SideMove)
        pdControl.rotInner(
            xRot, yRot, zRot,
            properties.profile[properties.profileIndex].spaceShip_P,
            properties.profile[properties.profileIndex].spaceShip_D)
    end
end

pdControl.quadFPV = function()
    if properties.profile[properties.profileIndex].lock then
        if joyUtil.LeftStick.y == 0 then
            pdControl.quadUp(
                0,
                properties.profile[properties.profileIndex].quad_Acc / pdControl.rot_D_multiply,
                3,
                true)
        else
            pdControl.quadUp(
                math.deg(math.asin(joyUtil.LeftStick.y)),
                properties.profile[properties.profileIndex].quad_Acc / pdControl.rot_D_multiply,
                3,
                false)
        end

        if joyUtil.RightStick.x == 0 and joyUtil.LeftStick.x == 0 and joyUtil.RightStick.y == 0 then
            local newVel = {}
            local distance = math.sqrt(attUtil.velocity.x ^ 2 + attUtil.velocity.z ^ 2 + attUtil.velocity.y ^ 2)
            newVel.x = attUtil.velocity.x / distance
            newVel.y = attUtil.velocity.y / distance
            newVel.z = attUtil.velocity.z / distance
            if newVel.x ~= newVel.x then newVel.x = 0 end
            if newVel.y ~= newVel.y then newVel.y = 0 end
            if newVel.z ~= newVel.z then newVel.z = 0 end
            newVel = RotateVectorByQuat(attUtil.conjQuat, newVel)
            local euler = {
                roll = -math.deg(math.asin(newVel.z)) * distance,
                yaw = attUtil.eulerAngle.yaw,
                pitch = math.deg(math.asin(newVel.x)) * distance
            }
            euler.roll = math.abs(euler.roll) > 70 and copysign(70, euler.roll) or euler.roll
            euler.pitch = math.abs(euler.pitch) > 70 and copysign(70, euler.pitch) or euler.pitch
            pdControl.rotate2Euler(euler, properties.profile[properties.profileIndex].quad_P,
                properties.profile[properties.profileIndex].quad_D)
        else
            pdControl.rotate2Euler({
                    roll = math.deg(math.asin(joyUtil.RightStick.x)) / 1.5,
                    yaw = attUtil.eulerAngle.yaw + joyUtil.LeftStick.x * 40 / pdControl.rot_D_multiply,
                    pitch = math.deg(math.asin(joyUtil.RightStick.y) / 1.5)
                },
                properties.profile[properties.profileIndex].quad_P,
                properties.profile[properties.profileIndex].quad_D)
        end
    else
        pdControl.quadUp(
            math.deg(math.asin(joyUtil.LeftStick.y)),
            properties.profile[properties.profileIndex].quad_Acc / pdControl.rot_D_multiply,
            3,
            false)
        pdControl.rotInner(
            math.deg(math.asin(joyUtil.RightStick.x)),
            math.deg(math.asin(joyUtil.LeftStick.x)),
            math.deg(math.asin(joyUtil.RightStick.y)),
            properties.profile[properties.profileIndex].quad_P,
            properties.profile[properties.profileIndex].quad_D)
    end
end

pdControl.helicopter = function()
    local acc
    local tgAg = {}
    if properties.profile[properties.profileIndex].lock then
        local tmpPos = {}
        tmpPos.y = attUtil.tmpFlags.lastPos.y - (attUtil.position.y + attUtil.velocity.y * 20)
        acc = tmpPos.y * 10
        acc = math.abs(acc) > 90 and copysign(90, acc) or acc
        tgAg.yaw = attUtil.tmpFlags.lastEuler.yaw
        tmpPos.x = attUtil.tmpFlags.lastPos.x - (attUtil.position.x + attUtil.velocity.x * 80)
        tmpPos.z = attUtil.tmpFlags.lastPos.z - (attUtil.position.z + attUtil.velocity.z * 80)
        tmpPos = RotateVectorByQuat(attUtil.conjQuat, tmpPos)
        tmpPos.tmp_c = math.sqrt(tmpPos.x ^ 2 + tmpPos.z ^ 2)
        tgAg.roll = math.deg(math.asin(tmpPos.z / tmpPos.tmp_c))
        tgAg.roll = tgAg.roll ~= tgAg.roll and 0 or tgAg.roll * tmpPos.tmp_c * 0.01
        tgAg.roll = math.abs(tgAg.roll) > 45 and copysign(45, tgAg.roll) or tgAg.roll
        tgAg.pitch = -math.deg(math.asin(tmpPos.x / tmpPos.tmp_c))
        tgAg.pitch = tgAg.pitch ~= tgAg.pitch and 0 or tgAg.pitch * tmpPos.tmp_c * 0.01
        tgAg.pitch = math.abs(tgAg.pitch) > 45 and copysign(45, tgAg.pitch) or tgAg.pitch
    else
        acc = math.deg(math.asin(joyUtil.LeftStick.y))
        tgAg.roll = math.deg(math.asin(joyUtil.RightStick.x)) *
            (properties.profile[properties.profileIndex].helicopt_MAX_ANGLE / 90)
        tgAg.yaw = attUtil.eulerAngle.yaw +
            joyUtil.LeftStick.x * 40 * properties.profile[properties.profileIndex].helicopt_YAW_P
        tgAg.pitch = math.deg(math.asin(joyUtil.RightStick.y)) *
            (properties.profile[properties.profileIndex].helicopt_MAX_ANGLE / 90)
    end

    pdControl.quadUp(
        acc,
        properties.profile[properties.profileIndex].helicopt_ACC / 4 / pdControl.rot_D_multiply,
        properties.profile[properties.profileIndex].helicopt_ACC_D,
        true)

    pdControl.rotate2Euler(
        tgAg,
        0.5 * properties.profile[properties.profileIndex].helicopt_ROT_P * pdControl.helicopt_P_multiply,
        properties.profile[properties.profileIndex].helicopt_ROT_D / pdControl.rot_D_multiply
    )
end

pdControl.airShip = function()
    local profile = properties.profile[properties.profileIndex]

    if properties.profile[properties.profileIndex].lock then
        pdControl.gotoPosition(attUtil.tmpFlags.lastEuler, attUtil.tmpFlags.lastPos)
    else
        local yaw = attUtil.eulerAngle.yaw + math.asin(joyUtil.LeftStick.x) * 9 * profile.airShip_ROT_P
        pdControl.rotate2Euler({roll = 0, yaw = yaw, pitch = 0}, 0.05, profile.airShip_ROT_D)
        pdControl.moveWithRot(
        math.asin(joyUtil.BTStick.y ) * 9 * profile.airShip_MOVE_P,
        math.asin(joyUtil.LeftStick.y ) * 9 * profile.airShip_MOVE_P,
        math.asin(joyUtil.BTStick.x ) * 9 * profile.airShip_MOVE_P,
        profile.airShip_MOVE_P,
        1
    )
    end
end

pdControl.gotoPosition = function(euler, pos)
    local xVal, yVal, zVal
    xVal = (pos.x - attUtil.position.x) * 3.6
    yVal = (pos.y - attUtil.position.y) * 3.6
    zVal = (pos.z - attUtil.position.z) * 3.6
    xVal = math.abs(xVal) > properties.MAX_MOVE_SPEED and copysign(properties.MAX_MOVE_SPEED, xVal) or xVal
    yVal = math.abs(yVal) > properties.MAX_MOVE_SPEED and copysign(properties.MAX_MOVE_SPEED, yVal) or yVal
    zVal = math.abs(zVal) > properties.MAX_MOVE_SPEED and copysign(properties.MAX_MOVE_SPEED, zVal) or zVal

    pdControl.moveWithOutRot(
        xVal,
        yVal,
        zVal,
        2,
        1.6
    )
    if euler then
        pdControl.rotate2Euler(euler, properties.profile[properties.profileIndex].spaceShip_P,
            properties.profile[properties.profileIndex].spaceShip_D)
    end
end

pdControl.HmsSpaceBasedGun = function()
    local targetAngle = scanner.getRCAngle(properties.rayCasterRange)
    targetAngle.roll = 0
    targetAngle.cosPitch = math.cos(math.rad(-attUtil.eulerAngle.pitch))
    targetAngle.y = math.sin(math.rad(-attUtil.eulerAngle.pitch))
    targetAngle.x = -math.cos(math.rad(attUtil.eulerAngle.yaw)) * targetAngle.cosPitch
    targetAngle.z = math.sin(math.rad(attUtil.eulerAngle.yaw)) * targetAngle.cosPitch
    local tg = rayCaster.run(attUtil.position, targetAngle, targetAngle.distance, true)
    if timeUtil.SpaceBasedGunCd > 20 then
        timeUtil.SpaceBasedGunCd = 0
        genParticleBomm(tg.x, tg.y, tg.z)
        rayCaster.runShoot(attUtil.position, targetAngle, targetAngle.distance, true)
    else
        timeUtil.SpaceBasedGunCd = timeUtil.SpaceBasedGunCd + 1
    end

    pdControl.gotoPosition(
        { roll = 0, yaw = targetAngle.yaw, pitch = targetAngle.pitch },
        properties.HOME
    )
end

pdControl.followMouse = function()
    if joyUtil.flag then
        if joyUtil.joy.hasUser() then
            attUtil.tmpFlags.hmsLastAtt = scanner.commander
        end
    end
    attUtil.tmpFlags.hmsLastAtt = scanner.commander
    pdControl.rotate2Euler2(attUtil.tmpFlags.hmsLastAtt, properties.profile[properties.profileIndex].spaceShip_P,
        properties.profile[properties.profileIndex].spaceShip_D)

    pdControl.moveWithRot(
        math.deg(math.asin(joyUtil.BTStick.y)),
        math.deg(math.asin(joyUtil.LeftStick.y)),
        math.deg(math.asin(joyUtil.BTStick.x)),
        properties.profile[properties.profileIndex].spaceShip_Acc,
        properties.profile[properties.profileIndex].spaceShip_move_D)
end

pdControl.follow = function(target)
    if target then
        local pos, qPos = {}, {}
        qPos.x = copysign(attUtil.size.x / 2, properties.followRange.x) + properties.followRange.x
        qPos.y = copysign(attUtil.size.y / 2, properties.followRange.y) + properties.followRange.y
        qPos.z = copysign(attUtil.size.z / 2, properties.followRange.z) + properties.followRange.z
        pos.x = target.x + qPos.x
        pos.y = target.y + qPos.y
        pos.z = target.z + qPos.z
        attUtil.tmpFlags.followLastAtt = pos
    end

    pdControl.gotoPosition(
        { roll = 0, yaw = 0, pitch = 0 }, attUtil.tmpFlags.followLastAtt)
end

pdControl.goHome = function()

end

pdControl.pointLoop = function()
    local tgAg, pos = {}, {}
    pos = properties.pointList[pdControl.pointLoopIndex]
    tgAg = { roll = 0, yaw = pos.yaw, pitch = 0 }
    if pos.flip then
        tgAg.pitch = 180
    end
    if math.abs(attUtil.position.x - pos.x) < 0.5 and
        math.abs(attUtil.position.y - pos.y) < 0.5 and
        math.abs(attUtil.position.z - pos.z) < 0.5 then
        if timeUtil.pointLoopWaitTime >= properties.pointLoopWaitTime then
            timeUtil.pointLoopWaitTime = 1
            if pdControl.pointLoopIndex >= #properties.pointList then
                pdControl.pointLoopIndex = 1
            else
                pdControl.pointLoopIndex = pdControl.pointLoopIndex + 1
            end
        else
            timeUtil.pointLoopWaitTime = timeUtil.pointLoopWaitTime + 1
        end
    end
    pdControl.gotoPosition(
        tgAg, pos)
end
---------screens---------

-- abstractScreen
-- 空屏幕，所有其他屏幕类的基类
local abstractScreen = {
    screenTitle = "blank"
}
abstractScreen.__index = abstractScreen

function abstractScreen:init() end

function abstractScreen:refresh() end

function abstractScreen:onTouch(x, y) end

function abstractScreen:onDisconnect()
    self.monitor.setTextColor(colors.white)
    self.monitor.setBackgroundColor(colors.black)
    self.monitor.clear()
    self.monitor.setCursorPos(1, 1)
    self.monitor.write("[DISCONNECTED]")
end

function abstractScreen:onRootFatal()
    self.monitor.setTextColor(colors.white)
    self.monitor.setBackgroundColor(colors.black)
    self.monitor.clear()
end

function abstractScreen:onSystemSleep()
    self.monitor.setTextColor(colors.white)
    self.monitor.setBackgroundColor(colors.black)
    self.monitor.clear()
    if self.monitor.setTextScale then
        self.monitor.setTextScale(0.5)
        local x, y = self.monitor.getSize()
        self.monitor.setCursorPos(x / 2 - 6, y / 2)
        self.monitor.write("click to restart")
    end
end

function abstractScreen:onBlank()
    self.monitor.setTextColor(colors.white)
    self.monitor.setBackgroundColor(colors.black)
    self.monitor.clear()
    self.monitor.setCursorPos(1, 1)
    if self.monitor.setTextScale then
        self.monitor.setTextScale(1)
    end
end

function abstractScreen:report() end

------------Window------------
local abstractWindow, abstractMonitor, flightPages = {}, {}, {}

function abstractWindow:init() end

function abstractWindow:new(parent, nX, nY, nWidth, nHeight, visible)
    self.window = window.create(parent, nX, nY, nWidth, nHeight, visible)
end

function abstractWindow:refreshButtons(cut, page) --没有参数时打印所有按钮，有参数时：cut前面的正常打印，cut后面的开始翻页
    if not self.buttons then
        for i = 1, #self.buttons, 1 do
            self.buttons[i].x = math.floor(self.buttons[i].x)
            self.buttons[i].y = math.floor(self.buttons[i].y)
        end
    end
    if not cut then
        cut = #self.buttons
    end
    if self.window.isVisible() then
        self:clear()
        for i = 1, cut, 1 do
            local bt = self.buttons[i]
            self.window.setCursorPos(bt.x, bt.y)
            self.window.blit(bt.text, bt.blitF, bt.blitB)
        end
    end

    if page then
        local start = (page - 1) * (self.height - 4) + 1 + cut
        for i = start, page * (self.height - 4) + cut, 1 do
            if i > #self.buttons then break end
            local bt = self.buttons[i]
            self.window.setCursorPos(bt.x, bt.y - (page - 1) * (self.height - 4))
            self.window.blit(bt.text, bt.blitF, bt.blitB)
        end
    end
end

function abstractWindow:clear()
    self.window.setBackgroundColor(getColorDec(properties.bg))
    self.window.clear()
    self.window.setCursorPos(1, 1)
end

function abstractWindow:switchWindow(index)
    local result = properties.winIndex[self.name][self.row][self.column] + index
    if result > 4 then
        result = 1
    elseif result == 0 then
        result = 4
    end
    properties.winIndex[self.name][self.row][self.column] = result
    return result
end

function abstractWindow:nextPage(x, y)
    if y == 1 then
        if x < self.width / 2 then
            return self:switchWindow(-1)
        elseif x > self.width / 2 then
            return self:switchWindow(1)
        end
    end
end

function abstractWindow:subPage_Back(x, y)
    if x == 1 and y == 1 then
        system.updatePersistentData()
        properties.winIndex[self.name][self.row][self.column] = self.indexFlag
    end
end

function abstractWindow:refreshTitle()
    self.window.setCursorPos(3, 1)
    self.window.blit(self.pageName, genStr(properties.title, #self.pageName), genStr(properties.bg, #self.pageName))
end

local page_attach_manager = {}
local modPage             = setmetatable({ pageId = 1, pageName = "modPage" }, { __index = abstractWindow })
local autoPage            = setmetatable({ pageId = 2, pageName = "autoPage" }, { __index = abstractWindow })
local attPage             = setmetatable({ pageId = 3, pageName = "attPage" }, { __index = abstractWindow })
local setPage             = setmetatable({ pageId = 4, pageName = "setPage" }, { __index = abstractWindow })
local set_spaceShip       = setmetatable({ pageId = 5, pageName = "set_spaceShip" }, { __index = abstractWindow })
local set_quadFPV         = setmetatable({ pageId = 6, pageName = "set_quadFPV" }, { __index = abstractWindow })
local set_helicopter      = setmetatable({ pageId = 7, pageName = "set_helicopter" }, { __index = abstractWindow })
local set_airShip         = setmetatable({ pageId = 8, pageName = "set_airShip" }, { __index = abstractWindow })
local set_user            = setmetatable({ pageId = 9, pageName = "user_Change" }, { __index = abstractWindow })
local set_home            = setmetatable({ pageId = 10, pageName = "home_set" }, { __index = abstractWindow })
local set_simulate        = setmetatable({ pageId = 11, pageName = "simulate" }, { __index = abstractWindow })
local set_att             = setmetatable({ pageId = 12, pageName = "set_att" }, { __index = abstractWindow })
local set_profile         = setmetatable({ pageId = 13, pageName = "profile" }, { __index = abstractWindow })
local set_colortheme      = setmetatable({ pageId = 14, pageName = "colortheme" }, { __index = abstractWindow })
local controllPage        = setmetatable({ pageId = 15, pageName = "controllPage" }, { __index = abstractWindow })

flightPages               = {
    modPage,        --1
    autoPage,       --2
    attPage,        --3
    setPage,        --4
    set_spaceShip,  --5
    set_quadFPV,    --6
    set_helicopter, --7
    set_airShip,    --8
    set_user,       --9
    set_home,       --10
    set_simulate,   --11
    set_att,        --12
    set_profile,    --13
    set_colortheme, --14
    controllPage    --15
}

--winIndex = 1
function modPage:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.buttons = {
        { text = "<    MOD    >",  x = self.width / 2 - 6, y = 1,               blitF = genStr(title, 13),               blitB = genStr(bg, 13) },
        { text = "[|]",            x = 3,                  y = self.height - 1, blitF = "eee",                           blitB = genStr(bg, 3) },
        { text = "[R]",            x = 6,                  y = self.height - 1, blitF = "222",                           blitB = genStr(bg, 3) },
        { text = "[x]",            x = self.width - 5,     y = self.height - 1, blitF = "888",                           blitB = genStr(bg, 3) },
        { text = modelist[1].name, x = 2,                  y = 3,               blitF = genStr(font, #modelist[1].name), blitB = genStr(bg, #modelist[1].name), modeId = 1, select = genStr(select, #modelist[1].name) },
        { text = modelist[2].name, x = 2,                  y = 4,               blitF = genStr(font, #modelist[2].name), blitB = genStr(bg, #modelist[2].name), modeId = 2, select = genStr(select, #modelist[2].name) },
        { text = modelist[3].name, x = 2,                  y = 5,               blitF = genStr(font, #modelist[3].name), blitB = genStr(bg, #modelist[3].name), modeId = 3, select = genStr(select, #modelist[3].name) },
        { text = modelist[4].name, x = 2,                  y = 6,               blitF = genStr(font, #modelist[4].name), blitB = genStr(bg, #modelist[4].name), modeId = 4, select = genStr(select, #modelist[4].name) },
        { text = modelist[5].name, x = 2,                  y = 7,               blitF = genStr(font, #modelist[5].name), blitB = genStr(bg, #modelist[5].name), modeId = 5, select = genStr(select, #modelist[5].name) },
    }
end

function modPage:refresh()
    self:refreshButtons()
    for k, v in pairs(self.buttons) do
        if v.text == modelist[properties.mode].name then
            self.window.setCursorPos(v.x, v.y)
            self.window.blit(v.text, v.blitB, v.select)
        end
    end
end

function modPage:onTouch(x, y)
    self:nextPage(x, y)
    for k, v in pairs(self.buttons) do
        if x >= v.x and x < v.x + #v.text and y == v.y then
            if v == self.buttons[2] or v == self.buttons[3] then
                system.updatePersistentData()
                if v == self.buttons[2] then
                    shutdown_flag = true
                    monitorUtil.onSystemSleep()
                else
                    os.reboot()
                end
            elseif v == self.buttons[4] then
                monitorUtil.disconnect(self.name)
            elseif v.modeId then
                properties.mode = v.modeId
            end
        end
    end
end

--winIndex = 2
function autoPage:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.buttons = {
        { text = "<  AUTOMOD  >",  x = self.width / 2 - 6, y = 1, blitF = genStr(title, 13),               blitB = genStr(bg, 13) },
        { text = modelist[6].name, x = 2,                  y = 3, blitF = genStr(font, #modelist[6].name), blitB = genStr(bg, #modelist[6].name), select = genStr(select, #modelist[6].name), modeId = 6 },
        { text = modelist[7].name, x = 2,                  y = 4, blitF = genStr(font, #modelist[7].name), blitB = genStr(bg, #modelist[7].name), select = genStr(select, #modelist[7].name), modeId = 7 },
        { text = modelist[8].name, x = 2,                  y = 5, blitF = genStr(font, #modelist[8].name), blitB = genStr(bg, #modelist[8].name), select = genStr(select, #modelist[8].name), modeId = 8 },
    }
end

function autoPage:refresh()
    self:refreshButtons()
    for k, v in pairs(self.buttons) do
        if v.text == modelist[properties.mode].name then
            self.window.setCursorPos(v.x, v.y)
            self.window.blit(v.text, v.blitB, v.select)
        end
    end
end

function autoPage:onTouch(x, y)
    self:nextPage(x, y)
    for k, v in pairs(self.buttons) do
        if x >= v.x and x < v.x + #v.text and y == v.y then
            if v.modeId then
                properties.mode = v.modeId
            end
        end
    end
end

--winIndex = 4
function setPage:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.buttons = {
        { text = "<    SET    >", x = self.width / 2 - 6, y = 1,       blitF = genStr(title, 13), blitB = genStr(bg, 13) },
        { text = "S_SpaceShip",   x = 2,                  pageId = 5,  y = 3,                     blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "S_QuadFPV  ",   x = 2,                  pageId = 6,  y = 4,                     blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "S_Helicopt ",   x = 2,                  pageId = 7,  y = 5,                     blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "S_aitShip  ",   x = 2,                  pageId = 8,  y = 6,                     blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "User_Change",   x = 2,                  pageId = 9,  y = 7,                     blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "Home_Set   ",   x = 2,                  pageId = 10, y = 8,                     blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "Simulate   ",   x = 2,                  pageId = 11, y = 9,                     blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "Set_Att    ",   x = 2,                  pageId = 12, y = 10,                    blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "Profile    ",   x = 2,                  pageId = 13, y = 11,                    blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "Colortheme ",   x = 2,                  pageId = 14, y = 12,                    blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false }
    }
    self.otherButtons = {
        { text = "      v      ", x = 2, y = self.height - 1, blitF = genStr(bg, 13), blitB = genStr(other, 13) },
        { text = "      ^      ", x = 2, y = 2,               blitF = genStr(bg, 13), blitB = genStr(other, 13) },
    }
    self.pageIndex = 1
end

function setPage:refresh()
    self:refreshButtons(1, self.pageIndex)
    if #self.buttons > self.height - 4 then
        if self.pageIndex == 1 or self.pageIndex * (self.height - 4) < #self.buttons - 1 then
            local bt = self.otherButtons[1]
            self.window.setCursorPos(bt.x, bt.y)
            self.window.blit(bt.text, bt.blitF, bt.blitB)
        end
        if self.pageIndex > 1 then
            local bt = self.otherButtons[2]
            self.window.setCursorPos(bt.x, bt.y)
            self.window.blit(bt.text, bt.blitF, bt.blitB)
        end
    end
    for k, v in pairs(self.buttons) do
        if v.selected then
            local yPos = v.y - (self.pageIndex - 1) * (self.height - 4)
            if yPos > 2 and yPos < self.height - 1 then
                self.window.setCursorPos(v.x, v.y - (self.pageIndex - 1) * (self.height - 4))
                self.window.blit(v.text, v.blitB, v.select)
            end
        end
    end
end

function setPage:onTouch(x, y)
    self:nextPage(x, y)
    if y == 2 then
        if self.pageIndex > 1 then
            self.pageIndex = self.pageIndex - 1
        end
    elseif y < self.height - 1 and y > 2 then
        for k, v in pairs(self.buttons) do
            if v.y > 1 then
                if x >= v.x and x < v.x + #v.text and y == v.y - (self.pageIndex - 1) * (self.height - 4) then
                    if not v.selected then
                        v.selected = true
                    else
                        self.windows[self.row][self.column][v.pageId].indexFlag = 4
                        properties.winIndex[self.name][self.row][self.column] = v.pageId
                    end
                else
                    v.selected = false
                end
            end
        end
    elseif y == self.otherButtons[1].y then
        if #self.buttons - 1 > self.pageIndex * (self.height - 4) then
            self.pageIndex = self.pageIndex + 1
        else
            self.pageIndex = 1
        end
    end
end

--winIndex = 3
function attPage:init()
end

function attPage:refresh()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    local info = page_attach_manager:get(self.name, self.pageName, self.row, self.column)
    local width, height, xPos, yPos
    if info ~= -1 then
        --self.window.setCursorPos(self.width / 2 - 3, self.height / 2 - 3)
        --self.window.write("group=" .. info.group)
        --self.window.setCursorPos(self.width / 2 - 6, self.height / 2 - 1)
        --self.window.write(("row=%d, max=%d" ):format(info.row, info.maxRow))
        --self.window.setCursorPos(self.width / 2 - 8, self.height / 2 + 1)
        --self.window.write(("column=%d, max=%d" ):format(info.column, info.maxColumn))
        width = info.maxColumn * self.width
        height = info.maxRow * self.height
        xPos = (info.column - 1) * self.width + 1
        yPos = (info.row - 1) * self.height
        if info.row == 1 then yPos = yPos + 1 end
    else
        width, height, xPos, yPos = self.width, self.height, 1, 1
    end
    self.window.setBackgroundColor(getColorDec(properties.bg))
    self.window.clear()
    self.window.setCursorPos(1, 1)
    if yPos == 1 then
        for i = 1, self.width, 1 do
            self.window.setCursorPos(i, 1)
            self.window.blit(".", font, bg)
        end

        local xMid = width / 2
        local xPoint = math.floor(math.cos(math.rad(attUtil.eulerAngle.yaw)) * xMid + 0.5)
        local zPoint = math.floor(math.sin(math.rad(attUtil.eulerAngle.yaw)) * xMid + 0.5)
        if attUtil.pX.x > 0 then
            self.window.setCursorPos(xMid + zPoint - xPos, 1)
            self.window.blit("W", select, bg)
        else
            self.window.setCursorPos(xMid - zPoint - xPos, 1)
            self.window.blit("E", select, bg)
        end

        if attUtil.pX.z > 0 then
            self.window.setCursorPos(xMid + xPoint - xPos, 1)
            self.window.blit("N", select, bg)
        else
            self.window.setCursorPos(xMid - xPoint - xPos, 1)
            self.window.blit("S", select, bg)
        end
    end

    local yMid = height / 2
    local lPointy = math.abs(attUtil.eulerAngle.pitch) > 90 and attUtil.pZ.y or -attUtil.pZ.y
    lPointy = math.floor(lPointy * yMid + 0.5)
    lPointy = math.abs(lPointy) > yMid - 1 and copysign(yMid - 1, lPointy) or lPointy
    local xPointy = math.abs(attUtil.eulerAngle.pitch) > 90 and attUtil.pX.y or -attUtil.pX.y
    xPointy = yMid + math.floor(xPointy * height + 0.5)
    local lline, rline = width * 0.33 - xPos + 2, width * 0.66 - xPos + 2
    for i = 1, height, 1 do
        local yy = i - yPos + 2
        if yPos > 1 then
            yy = yy - 1
        end
        if yy > 0 then
            self.window.setCursorPos(lline - 2, yy)
            if i == yMid + lPointy then
                self.window.blit("-", font, bg)
            end
            self.window.setCursorPos(lline, yy)
            if i == xPointy then
                self.window.blit(">-", font .. select, genStr(bg, 2))
            else
                self.window.setCursorPos(lline + 1, yy)
                self.window.blit("-", font, bg)
            end

            self.window.setCursorPos(rline + 3, yy)
            if i == yMid - lPointy then
                self.window.blit("-", font, bg)
            end
            self.window.setCursorPos(rline, yy)
            if i == xPointy then
                self.window.blit("-<", font .. select, genStr(bg, 2))
            else
                self.window.blit("-", font, bg)
            end
        end
    end
    if xPointy < 2 and yPos == 1 then
        self.window.setCursorPos(lline, 2)
        self.window.blit("^", font, bg)
        self.window.setCursorPos(rline + 1, 2)
        self.window.blit("^", font, bg)
    elseif xPointy > height - 1 then
        if info ~= -1 then
            if info.row ~= info.maxRow then goto continue end
        end
        self.window.setCursorPos(lline, self.height)
        self.window.blit("v", font, bg)
        self.window.setCursorPos(rline + 1, self.height)
        self.window.blit("v", font, bg)
    end
    ::continue::
    local mod = modelist[properties.mode].name
    if info ~= -1 then
        if info.maxColumn > 1 then
            local x, y = width / 2 - xPos, height / 2 - yPos
            if yPos > 1 then y = y - 1 end

            self.window.setCursorPos(x - #mod / 2 + 2, yPos + 1)
            self.window.blit(mod, genStr(title, #mod), genStr(bg, #mod))
            if mod == "spaceShip" and joyUtil.LeftJoyClick then
                self.window.setCursorPos(x - 3, y)
                self.window.blit("!BURNING!", "fffffffff", "eeeeeeeee")
            else
                self.window.setCursorPos(x - 3, y - 1)
                self.window.blit(("ROLL %6.1f"):format(attUtil.eulerAngle.roll), genStr(other, 11), genStr(bg, 11))
                self.window.setCursorPos(x - 3, y)
                self.window.blit(("YAW  %6.1f"):format(attUtil.eulerAngle.yaw), genStr(other, 11), genStr(bg, 11))
                self.window.setCursorPos(x - 3, y + 1)
                self.window.blit(("PITCH%6.1f"):format(attUtil.eulerAngle.pitch), genStr(other, 11), genStr(bg, 11))
            end
            self.window.setCursorPos(x - 2, y + 2)
            self.window.blit("tuning >", genStr(bg, 8), genStr(select, 8))
            self.window.setCursorPos(x - 2, y + 3)
            if properties.profile[properties.profileIndex].lock then
                self.window.blit("LOCK  ON", genStr(bg, 8), genStr(other, 8))
            else
                self.window.blit("LOCK OFF", genStr(other, 8), genStr(bg, 8))
            end

            self.window.setCursorPos(x - 3, y + 4)
            self.window.blit(("%6.1f km/h"):format(attUtil.speed * 3.6), genStr(select, 11), genStr(bg, 11))
            self.window.setCursorPos(x - 3, y + 5)
            self.window.blit(("H   %5.1f m"):format(attUtil.position.y), genStr(select, 11), genStr(bg, 11))

            if info.maxColumn > 2 then
                self.window.setCursorPos(x - self.width - joyUtil.LeftStick.x * (self.width / 2 - 2),
                    y + 2 - joyUtil.LeftStick.y * (height / 2 - 1))
                self.window.blit("*", font, select)
                self.window.setCursorPos(x + self.width + 3 - joyUtil.RightStick.x * (self.width / 2 - 2),
                    y + 2 - joyUtil.RightStick.y * (height / 2 - 1))
                self.window.blit("*", font, select)

                for i = 1, joyUtil.LT * height - 2, 1 do
                    self.window.setCursorPos(x - 5, height - yPos - i + 1)
                    self.window.blit("^", bg, font)
                end
                for i = 1, joyUtil.RT * height - 2, 1 do
                    self.window.setCursorPos(x + 9, height - yPos - i + 1)
                    self.window.blit("^", bg, font)
                end
            end
        end
    end
end

function attPage:onTouch(x, y)
    self:nextPage(x, y)
    local info = page_attach_manager:get(self.name, self.pageName, self.row, self.column)
    local width, height, xPos, yPos
    if info ~= -1 then
        width = info.maxColumn * self.width
        height = info.maxRow * self.height
        xPos = (info.column - 1) * self.width + 1
        yPos = (info.row - 1) * self.height
        if info.row == 1 then yPos = yPos + 1 end
    else
        width, height, xPos, yPos = self.width, self.height, 1, 1
    end
    local mod = modelist[properties.mode].name
    local bx, by = width / 2 - xPos - 2, height / 2 - yPos + 2
    if yPos > 1 then y = y - 1 end
    if y == by and x >= bx and x <= bx + 8 then
        local index
        if mod == "spaceShip" then
            index = 5
        elseif mod == "quadFPV" then
            index = 6
        elseif mod == "helicopter" then
            index = 7
        elseif mod == "airShip" then
            index = 8
        end
        if index then
            self.windows[self.row][self.column][index].indexFlag = 3
            properties.winIndex[self.name][self.row][self.column] = index
        end
    elseif y == by + 1 and x >= bx and x <= bx + 8 then
        attUtil.setLastPos()
        properties.profile[properties.profileIndex].lock = not properties.profile[properties.profileIndex].lock
    end
end

--winIndex = 5
function set_spaceShip:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.indexFlag = 4
    self.buttons = {
        { text = "<",             x = 1, y = 1, blitF = title,                           blitB = bg },
        { text = "P: --      ++", x = 2, y = 3, blitF = genStr(font, 3) .. "ffffffffff", blitB = genStr(bg, 3) .. "b5" .. genStr(bg, 6) .. "1e" },
        { text = "D: --      ++", x = 2, y = 4, blitF = genStr(font, 3) .. "ffffffffff", blitB = genStr(bg, 3) .. "b5" .. genStr(bg, 6) .. "1e" },
        { text = "Forward -   +", x = 2, y = 6, blitF = genStr(font, 8) .. "fffff",      blitB = genStr(bg, 8) .. "b" .. genStr(bg, 3) .. "e" },
        { text = "SideMove-   +", x = 2, y = 7, blitF = genStr(font, 8) .. "fffff",      blitB = genStr(bg, 8) .. "b" .. genStr(bg, 3) .. "e" },
        { text = "MOVE_D: -   +", x = 2, y = 8, blitF = genStr(font, 8) .. "fffff",      blitB = genStr(bg, 8) .. "b" .. genStr(bg, 3) .. "e" },
        { text = "Burner: -   +", x = 2, y = 9, blitF = genStr(font, 8) .. "fffff",      blitB = genStr(bg, 8) .. "b" .. genStr(bg, 3) .. "e" }
    }
end

function set_spaceShip:refresh()
    self:refreshButtons()
    self:refreshTitle()
    local profile = properties.profile[properties.profileIndex]
    self.window.setCursorPos(1, 2)
    self.window.blit(("profile:%s"):format(properties.profileIndex), genStr(properties.other, 16),
        genStr(properties.bg, 16))
    self.window.setTextColor(getColorDec(properties.font))
    self.window.setCursorPos(8, 3)
    self.window.write(string.format("%0.2f", profile.spaceShip_P))
    self.window.setCursorPos(8, 4)
    self.window.write(string.format("%0.2f", profile.spaceShip_D))
    self.window.setCursorPos(11, 6)
    self.window.write(string.format("%0.1f", profile.spaceShip_Acc))
    self.window.setCursorPos(11, 7)
    self.window.write(string.format("%0.1f", profile.spaceShip_SideMove))
    self.window.setCursorPos(11, 8)
    self.window.write(string.format("%0.1f", profile.spaceShip_move_D))
    self.window.setCursorPos(11, 9)
    self.window.write(string.format("%0.1f", profile.spaceShip_Burner))
end

function set_spaceShip:onTouch(x, y)
    self:subPage_Back(x, y)
    if y == 2 then
        self.windows[self.row][self.column][13].indexFlag = 5
        properties.winIndex[self.name][self.row][self.column] = 13
    end
    if x > 2 and y > 2 then
        local profile = properties.profile[properties.profileIndex]
        local result = 0
        if y == 3 or y == 4 then
            if x == 5 then result = -0.1 end
            if x == 6 then result = -0.01 end
            if x == 13 then result = 0.01 end
            if x == 14 then result = 0.1 end
            if y == 3 then
                profile.spaceShip_P = profile.spaceShip_P + result
            elseif y == 4 then
                profile.spaceShip_D = profile.spaceShip_D + result
            end
        elseif y > 5 then
            if x == 10 then result = -0.1 end
            if x == 14 then result = 0.1 end
            if y == 6 then
                profile.spaceShip_Acc = profile.spaceShip_Acc + result < 0 and 0 or profile.spaceShip_Acc + result
            elseif y == 7 then
                profile.spaceShip_SideMove = profile.spaceShip_SideMove + result < 0 and 0 or
                    profile.spaceShip_SideMove + result
            elseif y == 8 then
                profile.spaceShip_move_D = profile.spaceShip_move_D + result < 0 and 0 or
                    profile.spaceShip_move_D + result
            elseif y == 9 then
                profile.spaceShip_Burner = profile.spaceShip_Burner + result < 0 and 0 or
                    profile.spaceShip_Burner + result
            end
        end
    end
end

--winIndex = 6
function set_quadFPV:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.indexFlag = 4
    self.buttons = {
        { text = "<",             x = 1, y = 1, blitF = title,                           blitB = bg },
        { text = "P: --      ++", x = 2, y = 3, blitF = genStr(font, 3) .. "ffffffffff", blitB = genStr(bg, 3) .. "b5" .. genStr(bg, 6) .. "1e" },
        { text = "D: --      ++", x = 2, y = 4, blitF = genStr(font, 3) .. "ffffffffff", blitB = genStr(bg, 3) .. "b5" .. genStr(bg, 6) .. "1e" },
        { text = "ACC--      ++", x = 2, y = 5, blitF = genStr(font, 3) .. "ffffffffff", blitB = genStr(bg, 3) .. "b5" .. genStr(bg, 6) .. "1e" },
        { text = "rate         ", x = 2, y = 7, blitF = genStr(font, 13),                blitB = genStr(bg, 13),                                select = genStr(select, 13), selected = false, flag = false },
        { text = "AccRate      ", x = 2, y = 8, blitF = genStr(font, 13),                blitB = genStr(bg, 13),                                select = genStr(select, 13), selected = false, flag = false }
    }
end

function set_quadFPV:refresh()
    self:refreshButtons()
    self:refreshTitle()
    for k, v in pairs(self.buttons) do
        if v.selected then
            self.window.setCursorPos(v.x, v.y)
            self.window.blit(v.text, v.blitB, v.select)
        end
    end
    local profile = properties.profile[properties.profileIndex]
    self.window.setTextColor(getColorDec(properties.font))
    self.window.setCursorPos(1, 2)
    self.window.blit(("profile:%s"):format(properties.profileIndex), genStr(properties.other, 16),
        genStr(properties.bg, 16))
    self.window.setCursorPos(8, 3)
    self.window.write(string.format("%0.2f", profile.quad_P))
    self.window.setCursorPos(8, 4)
    self.window.write(string.format("%0.2f", profile.quad_D))
    self.window.setCursorPos(8, 5)
    self.window.write(string.format("%0.2f", profile.quad_Acc))
end

function set_quadFPV:onTouch(x, y)
    self:subPage_Back(x, y)
    if y == 2 then
        self.windows[self.row][self.column][13].indexFlag = 6
        properties.winIndex[self.name][self.row][self.column] = 13
    end
    if x > 2 and y > 2 then
        local profile = properties.profile[properties.profileIndex]
        local result = 0
        if y > 2 and y < 6 then
            if x == 5 then result = -0.1 end
            if x == 6 then result = -0.01 end
            if x == 13 then result = 0.01 end
            if x == 14 then result = 0.1 end
            if y == 3 then
                profile.quad_P = profile.quad_P + result < 0 and 0 or profile.quad_P + result
            elseif y == 4 then
                profile.quad_D = profile.quad_D + result < 0 and 0 or profile.quad_P + result
            elseif y == 5 then
                profile.quad_Acc = profile.quad_Acc + result < 0 and 0 or profile.quad_P + result
            end
        end
    end
    for k, v in pairs(self.buttons) do
        if v.selected ~= nil then
            if x >= v.x and x < v.x + #v.text and y == v.y then
                if not v.selected then
                    v.selected = true
                else
                    if v.text == "rate         " then
                        --?.indexFlag = 6
                        --properties.winIndex[self.name][self.row][self.column] = ?
                    elseif v.text == "AccRate      " then
                        --?.indexFlag = 6
                        --properties.winIndex[self.name][self.row][self.column] = ?
                    end
                end
            else
                v.selected = false
            end
        end
    end
end

--winIndex = 7
function set_helicopter:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.indexFlag = 4
    self.buttons = {
        { text = "<",             x = 1, y = 1, blitF = title,                         blitB = bg },
        { text = "Yaw_P--    ++", x = 2, y = 3, blitF = genStr(font, 5) .. "ffffffff", blitB = genStr(bg, 5) .. "b5" .. genStr(bg, 4) .. "1e" },
        { text = "Rot_P--    ++", x = 2, y = 4, blitF = genStr(font, 5) .. "ffffffff", blitB = genStr(bg, 5) .. "b5" .. genStr(bg, 4) .. "1e" },
        { text = "Rot_D--    ++", x = 2, y = 5, blitF = genStr(font, 5) .. "ffffffff", blitB = genStr(bg, 5) .. "b5" .. genStr(bg, 4) .. "1e" },
        { text = "ACC:-   +",     x = 2, y = 6, blitF = genStr(font, 4) .. "fffff",    blitB = genStr(bg, 4) .. "b" .. genStr(bg, 3) .. "e" },
        { text = "Acc_D--    ++", x = 2, y = 7, blitF = genStr(font, 5) .. "ffffffff", blitB = genStr(bg, 5) .. "b5" .. genStr(bg, 4) .. "1e" },
        { text = "MaxAngle:-  +", x = 2, y = 9, blitF = genStr(font, 9) .. "ffff",     blitB = genStr(bg, 9) .. "b" .. genStr(bg, 2) .. "e" }
    }
end

function set_helicopter:refresh()
    self:refreshButtons()
    self:refreshTitle()
    local profile = properties.profile[properties.profileIndex]
    self.window.setCursorPos(1, 2)
    self.window.blit(("profile:%s"):format(properties.profileIndex), genStr(properties.other, 16),
        genStr(properties.bg, 16))
    self.window.setTextColor(getColorDec(properties.font))
    self.window.setCursorPos(9, 3)
    self.window.write(string.format("%0.2f", profile.helicopt_YAW_P))
    self.window.setCursorPos(9, 4)
    self.window.write(string.format("%0.2f", profile.helicopt_ROT_P))
    self.window.setCursorPos(9, 5)
    self.window.write(string.format("%0.2f", profile.helicopt_ROT_D))
    self.window.setCursorPos(7, 6)
    self.window.write(string.format("%0.1f", profile.helicopt_ACC))
    self.window.setCursorPos(9, 7)
    self.window.write(string.format("%0.2f", profile.helicopt_ACC_D))
    self.window.setCursorPos(12, 9)
    self.window.write(string.format("%d", profile.helicopt_MAX_ANGLE))
end

function set_helicopter:onTouch(x, y)
    self:subPage_Back(x, y)
    if y == 2 then
        self.windows[self.row][self.column][13].indexFlag = 7
        properties.winIndex[self.name][self.row][self.column] = 13
    end
    if x > 2 and y > 2 then
        local profile = properties.profile[properties.profileIndex]
        local result = 0
        if (y > 2 and y < 6) or y == 7 then
            if x == 7 then result = -0.1 end
            if x == 8 then result = -0.01 end
            if x == 13 then result = 0.01 end
            if x == 14 then result = 0.1 end
            if y == 3 then
                profile.helicopt_YAW_P = profile.helicopt_YAW_P + result < 0 and 0 or profile.helicopt_YAW_P + result
            elseif y == 4 then
                profile.helicopt_ROT_P = profile.helicopt_ROT_P + result < 0 and 0 or profile.helicopt_ROT_P + result
            elseif y == 5 then
                profile.helicopt_ROT_D = profile.helicopt_ROT_D + result < 0 and 0 or profile.helicopt_ROT_D + result
            elseif y == 7 then
                profile.helicopt_ACC_D = profile.helicopt_ACC_D + result < 0 and 0 or profile.helicopt_ACC_D + result
            end
        elseif y == 6 then
            if x == 6 then result = -0.1 end
            if x == 10 then result = 0.1 end
            profile.helicopt_ACC = profile.helicopt_ACC + result < 0 and 0 or profile.helicopt_ACC + result
        elseif y == 9 then
            if x == 11 then result = -1 end
            if x == 14 then result = 1 end
            profile.helicopt_MAX_ANGLE = profile.helicopt_MAX_ANGLE + result < 0 and 0 or
                profile.helicopt_MAX_ANGLE + result
            profile.helicopt_MAX_ANGLE = profile.helicopt_MAX_ANGLE > 60 and 60 or profile.helicopt_MAX_ANGLE
        end
    end
end

--winIndex = 8
function set_airShip:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.indexFlag = 4
    self.buttons = {
        { text = "<",             x = 1, y = 1, blitF = title,                         blitB = bg },
        { text = "Rot_P--    ++", x = 2, y = 3, blitF = genStr(font, 5) .. "ffffffff", blitB = genStr(bg, 5) .. "b5" .. genStr(bg, 4) .. "1e" },
        { text = "Rot_D--    ++", x = 2, y = 4, blitF = genStr(font, 5) .. "ffffffff", blitB = genStr(bg, 5) .. "b5" .. genStr(bg, 4) .. "1e" },
        { text = "MOVE_P: -   +", x = 2, y = 6, blitF = genStr(font, 8) .. "fffff",    blitB = genStr(bg, 8) .. "b" .. genStr(bg, 3) .. "e" }
    }
end

function set_airShip:refresh()
    self:refreshButtons()
    self:refreshTitle()
    local profile = properties.profile[properties.profileIndex]
    self.window.setCursorPos(1, 2)
    self.window.blit(("profile:%s"):format(properties.profileIndex), genStr(properties.other, 16),
        genStr(properties.bg, 16))
    self.window.setTextColor(getColorDec(properties.font))
    self.window.setCursorPos(9, 3)
    self.window.write(string.format("%0.2f", profile.airShip_ROT_P))
    self.window.setCursorPos(9, 4)
    self.window.write(string.format("%0.2f", profile.airShip_ROT_D))
    self.window.setCursorPos(11, 6)
    self.window.write(string.format("%0.1f", profile.airShip_MOVE_P))
end

function set_airShip:onTouch(x, y)
    self:subPage_Back(x, y)
    if y == 2 then
        self.windows[self.row][self.column][13].indexFlag = 8
        properties.winIndex[self.name][self.row][self.column] = 13
    end
    if x > 2 and y > 2 then
        local profile = properties.profile[properties.profileIndex]
        local result = 0
        if y == 3 or y == 4 then
            if x == 7 then result = -0.1 end
            if x == 8 then result = -0.01 end
            if x == 13 then result = 0.01 end
            if x == 14 then result = 0.1 end
            if y == 3 then
                profile.airShip_ROT_P = profile.airShip_ROT_P + result < 0 and 0 or profile.airShip_ROT_P + result
            else
                profile.airShip_ROT_D = profile.airShip_ROT_D + result < 0 and 0 or profile.airShip_ROT_D + result
            end
        elseif y == 6 then
            if x == 10 then result = -0.1 end
            if x == 14 then result = 0.1 end
            profile.airShip_MOVE_P = profile.airShip_MOVE_P + result < 0 and 0 or profile.airShip_MOVE_P + result
        end
    end
end

--winIndex = 9
function set_user:init()
    local bg, other, font, title = properties.bg, properties.other, properties.font, properties.title
    self.indexFlag = 4
    self.buttons = {
        { text = "<",           x = 1, y = 1, blitF = title,             blitB = bg },
        { text = "selectUser:", x = 2, y = 2, blitF = genStr(other, 11), blitB = genStr(bg, 11) },
    }
end

function set_user:refresh()
    self:refreshButtons()
    self:refreshTitle()
    local bg, font, select = properties.bg, properties.font, properties.select
    for i = 1, 7, 1 do
        if properties.mode ~= 4 and properties.mode ~= 5 then scanner.scanPlayer() end
        if scanner.playerList[i] then
            local name = scanner.playerList[i].name
            self.window.setCursorPos(2, 2 + i)
            if name == properties.userName then
                self.window.blit(name, genStr(bg, #name), genStr(select, #name))
            else
                self.window.blit(name, genStr(font, #name), genStr(bg, #name))
            end
        end
    end
end

function set_user:onTouch(x, y)
    self:subPage_Back(x, y)
    if y > 2 and y < 10 then
        local user = scanner.playerList[y - 2]
        if user then
            properties.userName = user.name
        end
    end
end

--winIndex = 10
function set_home:init()
    local bg, other, font, title = properties.bg, properties.other, properties.font, properties.title
    self.indexFlag = 4
    self.buttons = {
        { text = "<", x = 1, y = 1, blitF = title, blitB = bg }
    }
end

function set_home:refresh()
    self:refreshButtons()
    self:refreshTitle()
end

function set_home:onTouch(x, y)
    self:subPage_Back(x, y)
end

--winIndex = 11
function set_simulate:init()
    local bg, other, font, title = properties.bg, properties.other, properties.font, properties.title
    self.indexFlag = 4
    self.buttons = {
        { text = "<",             x = 1, y = 1, blitF = title,                       blitB = bg },
        { text = "AirMass-    +", x = 1, y = 3, blitF = genStr(font, 7) .. "ffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 4) .. "e" },
        { text = "Gravity-    +", x = 1, y = 5, blitF = genStr(font, 7) .. "ffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 4) .. "e" },
        { text = "0_Point-    +", x = 1, y = 7, blitF = genStr(font, 7) .. "ffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 4) .. "e" },
    }
end

function set_simulate:refresh()
    self:refreshButtons()
    self:refreshTitle()
    local bg, other, font = properties.bg, properties.other, properties.font
    self.window.setTextColor(getColorDec(properties.font))
    self.window.setCursorPos(3, 1)
    self.window.blit(self.pageName, genStr(properties.title, #self.pageName), genStr(bg, #self.pageName))
    self.window.setCursorPos(9, 3)
    self.window.write(string.format("%0.1f", properties.airMass))
    self.window.setCursorPos(9, 5)
    self.window.write(string.format("%0.1f", properties.gravity))
    self.window.setCursorPos(9, 7)
    self.window.write(string.format("%0.1f", properties.zeroPoint))
end

function set_simulate:onTouch(x, y)
    self:subPage_Back(x, y)
    if x > 2 and y > 2 and y < 10 then
        local result = 0
        if x == 8 then result = -0.1 end
        if x == 13 then result = 0.1 end
        if y == 3 then
            properties.airMass = properties.airMass + result < 0 and 0 or properties.airMass + result
        elseif y == 5 then
            properties.gravity = properties.gravity + result > 0 and 0 or properties.gravity + result
        elseif y == 7 then
            properties.zeroPoint = properties.zeroPoint + result < 0 and 0 or properties.zeroPoint + result
        end
    end
end

--winIndex = 12
function set_att:init()
    local bg, other, font, title = properties.bg, properties.other, properties.font, properties.title
    self.indexFlag = 4
    self.buttons = {
        { text = "<", x = 1,                  y = 1,                   blitF = title, blitB = bg },
        { text = "w", x = self.width / 2 - 5, y = self.height / 2,     blitF = font,  blitB = bg },
        { text = "n", x = self.width / 2,     y = self.height / 2 - 3, blitF = font,  blitB = bg },
        { text = "e", x = self.width / 2 + 5, y = self.height / 2,     blitF = font,  blitB = bg },
        { text = "s", x = self.width / 2,     y = self.height / 2 + 3, blitF = font,  blitB = bg }
    }
end

function set_att:refresh()
    self:refreshButtons()
    self:refreshTitle()
    local index
    if properties.shipFace == "west" then
        index = 2
    elseif properties.shipFace == "north" then
        index = 3
    elseif properties.shipFace == "east" then
        index = 4
    elseif properties.shipFace == "south" then
        index = 5
    end

    self.window.setCursorPos(self.buttons[index].x, self.buttons[index].y)
    self.window.blit(self.buttons[index].text, properties.bg, properties.select)
end

function set_att:onTouch(x, y)
    self:subPage_Back(x, y)
    for k, v in pairs(self.buttons) do
        if x == v.x and y == v.y then
            if v.text == "w" then
                properties.shipFace = "west"
            elseif v.text == "n" then
                properties.shipFace = "north"
            elseif v.text == "e" then
                properties.shipFace = "east"
            elseif v.text == "s" then
                properties.shipFace = "south"
            end
        end
    end
end

--winIndex = 13
function set_profile:init()
    local bg, other, font, title = properties.bg, properties.other, properties.font, properties.title
    self.indexFlag = 4
    self.buttons = {
        { text = "<",        x = 1, y = 1, blitF = title,           blitB = bg },
        { text = "keyboard", x = 2, y = 3, blitF = genStr(font, 8), blitB = genStr(bg, 8) },
        { text = "joyStick", x = 2, y = 4, blitF = genStr(font, 8), blitB = genStr(bg, 8) }
    }
end

function set_profile:refresh()
    self:refreshButtons()
    self:refreshTitle()
    if properties.profileIndex == "keyboard" then
        self.window.setCursorPos(self.buttons[2].x, self.buttons[2].y)
        self.window.blit(self.buttons[2].text, genStr(properties.bg, 8), genStr(properties.select, 8))
    else
        self.window.setCursorPos(self.buttons[3].x, self.buttons[3].y)
        self.window.blit(self.buttons[3].text, genStr(properties.bg, 8), genStr(properties.select, 8))
    end
end

function set_profile:onTouch(x, y)
    self:subPage_Back(x, y)
    if x > 1 and x < 10 then
        if y == 3 then
            properties.profileIndex = "keyboard"
        elseif y == 4 then
            properties.profileIndex = "joyStick"
        end
    end
end

--winIndex = 14
function set_colortheme:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.indexFlag = 4
    self.buttons = {
        { text = "<",          x = 1, y = 1, blitF = title,            blitB = bg },
        { text = "font      ", x = 4, y = 3, blitF = genStr(font, 10), blitB = genStr(bg, 10), prt = genStr(font, 2) },
        { text = "background", x = 4, y = 4, blitF = genStr(font, 10), blitB = genStr(bg, 10), prt = genStr(bg, 2) },
        { text = "title     ", x = 4, y = 5, blitF = genStr(font, 10), blitB = genStr(bg, 10), prt = genStr(title, 2) },
        { text = "select    ", x = 4, y = 6, blitF = genStr(font, 10), blitB = genStr(bg, 10), prt = genStr(select, 2) },
        { text = "other     ", x = 4, y = 7, blitF = genStr(font, 10), blitB = genStr(bg, 10), prt = genStr(other, 2) },
    }
end

function set_colortheme:refresh()
    self:refreshButtons()
    self:refreshTitle()
    for i = 2, 6, 1 do
        self.window.setCursorPos(2, self.buttons[i].y)
        self.window.blit("  ", "00", self.buttons[i].prt)
    end
end

function set_colortheme:onTouch(x, y)
    self:subPage_Back(x, y)
    if x < 4 then
        if y == 3 then
            properties.font = getNextColor(properties.font, 1)
        elseif y == 4 then
            properties.bg = getNextColor(properties.bg, 1)
        elseif y == 5 then
            properties.title = getNextColor(properties.title, 1)
        elseif y == 6 then
            properties.select = getNextColor(properties.select, 1)
        elseif y == 7 then
            properties.other = getNextColor(properties.other, 1)
        end
    end
    self:init()
end

abstractMonitor = setmetatable({}, { __index = abstractScreen })

function abstractMonitor:getWindowCount()
    self.width, self.height = self.monitor.getSize()
    self.xCount = math.floor((self.width + 6) / 21.25 + 0.1)
    self.yCount = math.floor((self.height + 4) / 14.25 + 0.1)
end

function abstractMonitor:init()
    if self.monitor then
        if not self.name == "computer" then self.monitor.setTextScale(0.5) end
        self.monitor.setBackgroundColor(getColorDec(properties.bg))
        self.monitor.clear()
        self:getWindowCount()
        self.windows = {}
        self.winCount = 0
        local width, height = self.width / self.xCount, self.height / self.yCount
        width, height = math.floor(width), math.floor(height)
        local xP, yP = 1, 1
        for i = 1, self.yCount, 1 do
            table.insert(self.windows, {})
            for j = 1, self.xCount, 1 do
                table.insert(self.windows[i], {})
                self.winCount = self.winCount + 1
                for k = 1, #flightPages, 1 do
                    local tmpt = setmetatable(
                        {
                            name = self.name,
                            windows = self.windows,
                            winNum = self.winCount,
                            width = width,
                            height =
                                height,
                            row = i,
                            column = j
                        },
                        { __index = flightPages[k] }
                    )
                    xP = j > 1 and math.floor((j - 1) * width + 1.5) or 1
                    yP = i > 1 and math.floor((i - 1) * height + 1.5) or 1
                    tmpt:new(self.monitor, xP, yP, width, height, false)
                    tmpt:init()
                    table.insert(self.windows[i][j], tmpt)
                end
            end
        end

        if not properties.winIndex[self.name] then
            properties.winIndex[self.name] = {}
        end
        for i = 1, #self.windows, 1 do
            if not properties.winIndex[self.name][i] then
                properties.winIndex[self.name][i] = {}
            end
            for j = 1, #self.windows[i], 1 do
                if not properties.winIndex[self.name][i][j] then
                    properties.winIndex[self.name][i][j] = 1
                end
            end
        end
    end
end

function page_attach_manager:get(mName, pageName, row, column)
    if self[mName] then
        for k, v in pairs(self[mName][pageName]) do
            if (row >= v.rowStart and row <= v.rowEnd) and (column >= v.columnStart and column <= v.columnEnd) then
                return {
                    group = v.group,
                    row = row + 1 - v.rowStart,
                    maxRow = v.rowEnd + 1 - v.rowStart,
                    column = column + 1 - v.columnStart,
                    maxColumn = v.columnEnd + 1 - v.columnStart
                }
            end
        end
    end
    return -1
end

function page_attach_manager:test()
    for k, v in pairs(self["monitor_12"]) do
        for k2, v2 in pairs(v) do
            commands.execAsync(("say %s=%s"):format(k, v))
        end
    end
end

function abstractMonitor:refresh_page_attach()
    if not page_attach_manager[self.name] then
        page_attach_manager[self.name] = {}
    end
    local att = {}
    page_attach_manager[self.name]["attPage"] = att
    local wi = 1
    local group = 0
    while true do --总行数
        if wi > #self.windows then break end
        local minRowAdd = 0
        local wj = 1
        while true do --总列数
            if wj > #self.windows[1] then break end
            local rowStart, columnStart = wi, wj
            local rowEnd = rowStart + 2 > #self.windows and #self.windows or rowStart + 2
            local columnEnd = columnStart + 2 > #self.windows[1] and #self.windows[1] or columnStart + 2
            local rowCount, columnCount = 0, 0
            for i = rowStart, rowEnd, 1 do
                local j = columnStart
                while true do
                    if j > columnEnd then break end
                    if properties.winIndex[self.name][i][j] == 3 then --attPage = 3
                        if i == rowStart then columnCount = columnCount + 1 end
                    else
                        if i == rowStart and columnCount > 0 then
                            columnEnd = j - 1
                        elseif j < columnEnd + 1 then
                            goto continue
                        end
                    end
                    j = j + 1
                end
                rowCount = rowCount + 1
            end
            ::continue::
            if rowCount > 1 or columnCount > 1 then
                group = group + 1
                table.insert(att,
                    {
                        group = group,
                        rowStart = rowStart,
                        rowEnd = rowStart - 1 + rowCount,
                        columnStart = columnStart,
                        columnEnd = columnStart - 1 + columnCount
                    })
            end
            wj = columnCount == 0 and wj + 1 or wj + columnCount
            if wi == 1 then
                minRowAdd = rowCount
            else
                minRowAdd = math.min(minRowAdd, rowCount)
            end
        end
        wi = minRowAdd == 0 and wi + 1 or wi + minRowAdd
    end
end

function abstractMonitor:refresh()
    self:refresh_page_attach()
    for i = 1, #self.windows, 1 do
        for j = 1, #self.windows[i], 1 do
            for k = 1, #self.windows[i][j], 1 do
                if properties.winIndex[self.name][i][j] == k then
                    self.windows[i][j][k].window.setVisible(true)
                    self.windows[i][j][k]:refresh()
                else
                    self.windows[i][j][k].window.setVisible(false)
                end
            end
        end
    end
end

function abstractMonitor:onTouch(x, y)
    local clickX, clickY
    for i = #self.windows, 1, -1 do
        local xPos, yPos = self.windows[i][1][1].window.getPosition()
        if yPos <= y then
            clickY = math.floor(y % self.windows[i][1][1].height)
            clickY = clickY == 0 and math.floor(self.windows[i][1][1].height) or clickY
            for j = #self.windows[i], 1, -1 do
                xPos, yPos = self.windows[i][j][1].window.getPosition()
                if xPos <= x then
                    clickX = x % self.windows[i][j][1].width
                    clickX = clickX == 0 and math.floor(self.windows[i][1][1].width) or clickX
                    self.windows[i][j][properties.winIndex[self.name][i][j]]:onTouch(clickX, clickY)
                    return
                end
            end
        end
    end
end

-- flightGizmoScreen
-- 飞控系统屏幕

local flightGizmoScreen = setmetatable({ screenTitle = "gizmo", }, { __index = abstractMonitor })

function flightGizmoScreen:report()
    return ("%d x %d"):format(#self.windows, #self.windows[1])
end

-- screensManagerScreen
-- 用于管理所有其他的屏幕；主机专属屏幕
local screensManagerScreen = {
    screenTitle = "screens manager"
}
screensManagerScreen.__index = setmetatable(screensManagerScreen, abstractScreen)

function screensManagerScreen:init()
    self.rows = {}
end

function screensManagerScreen:refresh()
    local redirects = arrayTableDuplicate(joinArrayTables({ "computer" }, monitorUtil.getMonitorNames(),
        properties.enabledMonitors))
    table.sort(redirects, function(n1, n2)
        local s1 = monitorUtil.getMonitorSort(n1)
        local s2 = monitorUtil.getMonitorSort(n2)
        if s1 ~= s2 then
            return s1 < s2
        else
            return n1 < n2
        end
    end)
    self.monitor.setTextColor(colors.white)
    self.monitor.setBackgroundColor(colors.black)
    self.monitor.clear()
    self.monitor.setCursorPos(1, 1)
    self.monitor.write("Monitors:")
    local newrows = {}
    for i, name in ipairs(redirects) do
        self.monitor.setCursorPos(1, i + 1)
        self.monitor.write(("%2i."):format(i))
        local status
        local title
        local report
        if not monitorUtil.hasMonitor(name) then
            self.monitor.setBackgroundColor(colors.red)
            status = "MISSING"
        elseif not tableHasValue(properties.enabledMonitors, name) then
            self.monitor.setBackgroundColor(colors.lightGray)
            status = "OFFLINE"
        elseif not monitorUtil.screens[name] then
            self.monitor.setBackgroundColor(colors.red)
            status = "ONLINE"
            title = "???"
        else
            local text, color = monitorUtil.screens[name]:report()
            self.monitor.setBackgroundColor(color or colors.lime)
            status = "ONLINE"
            title = monitorUtil.screens[name].screenTitle
            report = text
        end
        table.insert(newrows, name)
        if name == "computer" then
            name = os.getComputerLabel() or name
        end
        self.monitor.write(name .. " [" .. status .. "]")
        if title then
            self.monitor.write("[" .. title .. "]")
        end
        if report then
            self.monitor.write("[" .. report .. "]")
        end
        self.monitor.setBackgroundColor(colors.black)
    end
    self.rows = newrows
end

function screensManagerScreen:onTouch(x, y)
    local name = self.rows[y - 1]
    if name then
        if tableHasValue(properties.enabledMonitors, name) then
            arrayTableRemoveElement(properties.enabledMonitors, name)
            monitorUtil.disconnect(name)
        else
            table.insert(properties.enabledMonitors, name)
        end
        system.updatePersistentData()
    end
end

-- screenPickerScreen
-- 用于打开其他的屏幕的屏幕
local screenPickerScreen = setmetatable({ screenTitle = "idle" }, { __index = abstractScreen })

function screenPickerScreen:init()
    self.rows = {}
    if self.name == "computer" then
        table.insert(self.rows, { name = "screens manager", class = screensManagerScreen })
    end
    table.insert(self.rows, { name = "flight gizmo", class = flightGizmoScreen })
    if #self.rows == 1 then
        monitorUtil.newScreen(self.name, self.rows[1].class)
        return
    end
end

function screenPickerScreen:refresh()
    self.monitor.setTextColor(colors.white)
    self.monitor.setBackgroundColor(colors.black)
    self.monitor.clear()
    self.monitor.setCursorPos(1, 1)
    self.monitor.write("Choose screen:")
    if #self.rows <= 0 then
        self.monitor.setCursorPos(1, 2)
        self.monitor.write("no screen available!")
    else
        for i, row in ipairs(self.rows) do
            self.monitor.setCursorPos(1, i + 1)
            self.monitor.write(("%2i."):format(i))
            if i % 2 == 0 then
                self.monitor.setBackgroundColor(colors.lightGray)
            else
                self.monitor.setBackgroundColor(colors.gray)
            end
            self.monitor.write(row.name)
            self.monitor.setBackgroundColor(colors.black)
        end
    end
end

function screenPickerScreen:onTouch(x, y)
    local row = self.rows[y - 1]
    if row then
        monitorUtil.newScreen(self.name, row.class)
    end
end

-- loadingScreen
-- 加载屏幕
local loadingScreen = {
    screenTitle = "loading"
}
loadingScreen.__index = setmetatable(loadingScreen, abstractScreen)

function loadingScreen:report()
    return "Loading: " .. ("%i"):format(math.floor(self.step * 100 / 16)) .. "%", colors.orange
end

function loadingScreen:init()
    self.step = 1
    self.index = 1
    self.postload = screenPickerScreen
    if self.monitor.setTextScale then -- 电脑终端也是显示器
        self.monitor.setTextScale(0.5)
    end
end

function loadingScreen:refresh()
    if self.step == 1 then
        local offset_x, offset_y = self.monitor.getSize()
        offset_x = math.floor((offset_x - 15) / 2)
        offset_y = math.floor((offset_y - 10) / 2)
        self.monitor.setBackgroundColor(colors.black)
        self.monitor.clear()
        self.monitor.setCursorBlink(false)
        self.monitor.setCursorPos(offset_x + 5, offset_y + 3)
        self.monitor.blit("WELCOME", "0000000", "fffffff")

        self.monitor.setCursorPos(offset_x + 9 - #properties.userName / 2, offset_y + 5)
        self.monitor.write(properties.userName)

        self.monitor.setCursorPos(offset_x + 9 - #self.name / 2 - 1, offset_y + 9)
        self.monitor.write("[" .. self.name .. "]")

        self.monitor.setCursorPos(offset_x + 1, offset_y + 7)
    end
    if self.index >= 14 then self.index = 1 end
    if self.index < 10 then
        self.monitor.blit("-", ("%d"):format(self.index), "f")
    else
        self.monitor.blit("-", ("%s"):format(string.char(self.index + 87)), "f")
    end
    self.step = self.step + 1
    self.index = self.index + 1
    if self.step >= 16 then
        monitorUtil.newScreen(self.name, self.postload)
    end
end

---------monitorUtil---------
monitorUtil = {
    screens = {}
}

monitorUtil.newScreen = function(name, class)
    if not class then
        class = loadingScreen
    end
    local screen = setmetatable({ name = name }, { __index = class })
    monitorUtil.screens[name] = screen
    local monitor
    if name == "computer" then
        monitor = term.current()
    else
        monitor = peripheral.wrap(name)
    end
    screen.monitor = monitor
    screen:init()
    return monitorUtil.screens[name] --init有可能会改变屏幕类
end

monitorUtil.disconnectComputer = function()
    local c = term.current()
    c.setTextColor(colors.white)
    c.setBackgroundColor(colors.black)
    c.clear()
    c.setCursorPos(1, 1)
    c.write("[DISCONNECTED]")
    c.setCursorPos(1, 2)
    c.write("Press any key to reconnect this screen...")
    c.setCursorPos(1, 3)
end

monitorUtil.disconnect = function(name)
    if monitorUtil.screens[name] ~= nil and (name == "computer" or peripheral.isPresent(name)) then
        monitorUtil.screens[name]:onDisconnect()
        monitorUtil.screens[name] = nil
        if name == "computer" then
            monitorUtil.disconnectComputer()
        end
    end
end

monitorUtil.hasMonitor = function(name)
    if name == "computer" then
        return term.current().isColor()
    elseif peripheral.isPresent(name) and peripheral.hasType(name, "monitor") then
        return true
    else
        return false
    end
end

monitorUtil.scanMonitors = function()
    for _, name in ipairs(properties.enabledMonitors) do
        if monitorUtil.screens[name] == nil then
            if name == "computer" or monitorUtil.hasMonitor(name) then
                monitorUtil.newScreen(name)
            end
        end
    end
    for _, name in ipairs(properties.enabledMonitors) do
        if not monitorUtil.hasMonitor(name) then
            monitorUtil.screens[name] = nil
        elseif not tableHasValue(properties.enabledMonitors, name) then
            monitorUtil.disconnect(name)
        end
    end
end

monitorUtil.refresh = function()
    monitorUtil.scanMonitors()
    for _, screen in pairs(monitorUtil.screens) do
        screen:refresh()
    end
end

monitorUtil.getMonitorNames = function()
    local monitors = peripheral.getNames()
    local result = {}
    table.insert(monitors, "term")
    for _, name in ipairs(monitors) do
        if monitorUtil.hasMonitor(name) then
            table.insert(result, name)
        end
    end
    return result
end

monitorUtil.blankAllScreens = function()
    for _, screen in pairs(monitorUtil.screens) do
        screen:onBlank()
    end
end

monitorUtil.onRootFatal = function()
    for _, screen in pairs(monitorUtil.screens) do
        screen:onRootFatal()
    end
end


monitorUtil.onSystemSleep = function()
    for _, screen in pairs(monitorUtil.screens) do
        screen:onSystemSleep()
    end
end

monitorUtil.monitorSortOrder = {
    computer = -8,
    bottom = -7,
    top = -6,
    left = -5,
    right = -4,
    front = -3,
    back = -2,
}

function monitorUtil.getMonitorSort(name)
    if monitorUtil.monitorSortOrder[name] then
        return monitorUtil.monitorSortOrder[name]
    end
    local id = string.match(name, 'monitor_(%d+)')
    if id then
        return tonumber(id) or -1
    end
    return -1
end

---------main---------

system.init()

if term.isColor() then
    shell.run("background", "shell")
end

function flightUpdate()
    if ship.isStatic() then
        --static
    elseif properties.mode == 1 then
        pdControl.spaceShip()
    elseif properties.mode == 2 then
        pdControl.quadFPV()
    elseif properties.mode == 3 then
        pdControl.helicopter()
    elseif properties.mode == 4 then
        pdControl.airShip()
    elseif properties.mode == 5 then
        pdControl.followMouse()
    elseif properties.mode == 6 then
        pdControl.follow(scanner.commander)
    elseif properties.mode == 7 then
        pdControl.goHome()
    elseif properties.mode == 8 then
        pdControl.pointLoop()
    end
end

local phys_Count = 1
local testRun = function(phys)
    if shutdown_flag then
        sleep(0.5)
    else
        attUtil.poseVel = phys.getPoseVel()
        attUtil.inertia = phys.getInertia()
        attUtil.getAttWithPhysTick()
        joyUtil.getJoyInput()

        if phys_Count == 3 then
            scanner.scan()
            phys_Count = 1
        else
            phys_Count = phys_Count + 1
        end

        flightUpdate()
        attUtil.setPreAtt()
    end
end

function listener()
    while true do
        local eventData = { os.pullEvent() }
        local event = eventData[1]

        if event == "physics_tick" then
            if physics_flag then
                physics_flag = false
            end
            testRun(eventData[2])
        end

        if event == "monitor_touch" and monitorUtil.screens[eventData[2]] then
            if shutdown_flag then
                local m = monitorUtil.screens[eventData[2]].monitor
                local x, y = m.getSize()
                if eventData[4] == y / 2 and eventData[3] >= x / 2 - 7 and eventData[3] <= x / 2 + 9 then
                    os.reboot()
                end
            end
            monitorUtil.screens[eventData[2]]:onTouch(eventData[3], eventData[4])
        elseif event == "mouse_click" and monitorUtil.screens["computer"] then
            monitorUtil.screens["computer"]:onTouch(eventData[3], eventData[4])
        elseif event == "key" and not tableHasValue(properties.enabledMonitors, "computer") then
            table.insert(properties.enabledMonitors, "computer")
            system.updatePersistentData()
        end
    end
end

function run()
    parallel.waitForAll(runFlight, listener)
end

function runFlight()
    sleep(0.1)
    if physics_flag then
        pdControl.basicYSpeed = 30
        pdControl.helicopt_P_multiply = 1.5
        pdControl.helicopt_D_multiply = 4
        pdControl.rot_P_multiply = 1.5
        pdControl.rot_D_multiply = 0.5
        pdControl.move_P_multiply = 2
        pdControl.move_D_multiply = 100
        pdControl.airMass_multiply = 20
    else
        return
    end

    while true do
        if shutdown_flag then
            sleep(0.5)
        else
            scanner.scan()
            attUtil.getAttWithCCTick()
            joyUtil.getJoyInput()
            flightUpdate()
            attUtil.setPreAtt()
            sleep(0.05)
        end
    end
end

function refreshDisplay()
    sleep(0.1)
    while true do
        if shutdown_flag then
            monitorUtil.onSystemSleep()
            sleep(0.5)
        else
            monitorUtil.refresh()
            sleep(0.1)
        end
    end
end

xpcall(function()
    monitorUtil.scanMonitors()
    if monitorUtil.screens["computer"] == nil then
        monitorUtil.disconnectComputer()
    end
    attUtil.init()
    parallel.waitForAll(run, refreshDisplay)
    error("Unexpected flight control exit")
end, function(err)
    monitorUtil.onRootFatal()
    local c = term.current()
    c.setTextColor(colors.white)
    c.setBackgroundColor(colors.black)
    c.clear()
    c.setCursorPos(1, 1)
    if c.setTextScale then
        c.setTextScale(1)
    end
    if err:find("Terminated") then
        c.setTextColor(colors.orange)
        print("Flight control terminated.")
    else
        c.setTextColor(colors.red)
        print("Flight control error:")
        print(err)
    end
    c.setTextColor(colors.white)
end)
