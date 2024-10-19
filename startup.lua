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

peripheral.find("modem", rednet.open)
---------inner---------
local modelist = {
    { name = "spaceShip",  flag = false },
    { name = "quadFPV",    flag = false },
    { name = "helicopter", flag = false },
    { name = "airShip",    flag = false },
    { name = "hms_fly",    flag = false },
    { name = "follow",     flag = false },
    { name = "goHome",     flag = false },
    { name = "pointLoop ", flag = false },
    { name = "ShipCamera", flag = false },
    { name = "ShipFollow", flag = false },
    { name = "Anchorage",  flag = false },
    { name = "spaceFpv",   flag = false },
    { name = "Fixed-wing", flag = false },
}

local system, properties, attUtil, monitorUtil, joyUtil, pdControl, rayCaster, scanner, timeUtil, shipNet_p2p_send
local physics_flag, shutdown_flag, engineOff = true, false, false
local allForce, InvariantForce, RotDependentForce, RotDependentTorque = 0, 0, 0, 0
local public_protocol = "shipNet_broadcast"
local shipName, computerId = ship.getName(), os.getComputerID()
local childShips, callList = {}, {}
local shipNet_list = {} --shipNet_list={id=%d, name=%s, beat=%d, pos={x,y,z}, size={x,y,z}}
local beat_ct, call_ct, captcha, calling
local DEFAULT_PARENT_SHIP = {
    id = -1,
    name = "",
    pos = { x = 0, y = 0, z = 0 },
    quat = { w = 0, x = 0, y = 0, z = 0 },
    preQuat = { w = 0, x = 0, y = 0, z = 0 },
    velocity = { x = 0, y = 0, z = 0 },
    anchorage = { offset = { x = 0, y = 0, z = 0 }, entry = "top" },
    size = ship.getSize(),
    beat = beat_ct
}
local parentShip = DEFAULT_PARENT_SHIP
local entryList = {
    "top",
    "bottom",
    "left",
    "right",
    "front",
    "back"
}
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

        if not type(properties.mode) == "number" then properties.mode = 1 end
        if properties.mode > 5 and properties.mode ~= 12 then
            properties.mode = 1
        end

        if properties.profile.keyboard.spaceShip_D > 2.52 then properties.profile.keyboard.spaceShip_D = 2.52 end
        if properties.profile.joyStick.spaceShip_D > 2.52 then properties.profile.joyStick.spaceShip_D = 2.52 end

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
        profileIndex = "keyboard",
        raderRange = 1,
        coupled = true,
        profile = {
            keyboard = {
                spaceShip_P = 0.1,       --角速度比例, 决定转向快慢
                spaceShip_D = 0.52,       --角速度阻尼, 低了停的慢、太高了会抖动。标准是松杆时快速停下角速度、且停下时不会抖动
                spaceShip_Acc = 0.4,      --星舰模式油门速度
                spaceShip_SideMove = 0.2, --星舰模式横移速度
                spaceShip_Burner = 3.0,   --星舰模式加力燃烧倍率
                spaceShip_move_D = 0.5,   --移动阻尼, 低了停的慢、太高了会抖动。标准是松杆时快速停下、且停下时不会抖动
                roll_rc_rate = 1.1,
                roll_s_rate = 0.7,
                roll_expo = 0.3,
                yaw_rc_rate = 1.1,
                yaw_s_rate = 0.7,
                yaw_expo = 0.3,
                pitch_rc_rate = 1.1,
                pitch_s_rate = 0.7,
                pitch_expo = 0.3,
                max_throttle = 1.5,
                throttle_mid = 0.15,
                throttle_expo = 1.0,
                helicopt_YAW_P = 0.75,
                helicopt_ROT_P = 0.75,
                helicopt_ROT_D = 0.75,
                helicopt_MAX_ANGLE = 30,
                helicopt_ACC = 0.5,
                helicopt_ACC_D = 0.75,
                airShip_ROT_P = 1,
                airShip_ROT_D = 0.5,
                airShip_MOVE_P = 1,
                camera_rot_speed = 0.2,
                camera_move_speed = 0.2,
                shipFollow_move_speed = 0.2,
            },
            joyStick = {
                spaceShip_P = 1,        --角速度比例, 决定转向快慢
                spaceShip_D = 2.32,     --角速度阻尼, 低了停的慢、太高了会抖动。标准是松杆时快速停下角速度、且停下时不会抖动
                spaceShip_Acc = 2,      --星舰模式油门速度
                spaceShip_SideMove = 2, --星舰模式横移速度
                spaceShip_Burner = 3.0, --星舰模式加力燃烧倍率
                spaceShip_move_D = 1.6, --移动阻尼, 低了停的慢、太高了会抖动。标准是松杆时快速停下、且停下时不会抖动
                roll_rc_rate = 1.1,
                roll_s_rate = 0.7,
                roll_expo = 0.3,
                yaw_rc_rate = 1.1,
                yaw_s_rate = 0.7,
                yaw_expo = 0.3,
                pitch_rc_rate = 1.1,
                pitch_s_rate = 0.7,
                pitch_expo = 0.3,
                max_throttle = 1.5,
                throttle_mid = 0.15,
                throttle_expo = 1.0,
                helicopt_YAW_P = 0.75,
                helicopt_ROT_P = 0.75,
                helicopt_ROT_D = 0.75,
                helicopt_MAX_ANGLE = 30,
                helicopt_ACC = 0.5,
                helicopt_ACC_D = 0.75,
                airShip_ROT_P = 1,
                airShip_ROT_D = 0.5,
                airShip_MOVE_P = 1,
                camera_rot_speed = 1,
                camera_move_speed = 0.2,
                shipFollow_move_speed = 0.2,
            }
        },
        lock = false,
        zeroPoint = 0,
        gravity = -2,
        airMass = 1, --空气密度 (风阻)
        wing = {
            wings        = { pos = { x = ship.getSize().x / 8, y = 0, z = ship.getSize().z / 4 }, size = 1 },
            tail_wings   = { pos = { x = ship.getSize().x / 2, y = 0, z = 0 }, size = 0.25 },
            verticalTail = { pos = { x = ship.getSize().x / 2, y = ship.getSize().y / 8, z = 0 }, size = 0.25 },
        },
        rayCasterRange = 128,
        shipFace = "west",
        bg = "f",
        font = "8",
        title = "3",
        select = "3",
        other = "7",
        MAX_MOVE_SPEED = 99,                    --自动驾驶最大跟随速度
        pointLoopWaitTime = 60,                 --点循环模式-到达目标点后等待时间 (tick)
        followRange = { x = -1, y = 0, z = 0 }, --跟随距离
        shipFollow_offset = { x = -3, y = 0, z = 0 },
        pointList = {                           --点循环模式，按照顺序逐个前往
        },
        anchorage_offset = {
            x = -5,
            y = 0,
            z = 0
        },
        anchorage_entry = 1
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

local copysign = function(num1, num2)
    num1 = math.abs(num1)
    num1 = num2 > 0 and num1 or -num1
    return num1
end

local contrarysign = function(num1, num2)
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

function resetAngelRangeRad(angle)
    return math.rad(resetAngelRange(math.deg(angle)))
end

local genCaptcha = function(len)
    local length = len and len or 5
    local result = ""
    for i = 1, length, 1 do
        local num = math.random(0, 2)
        if num == 0 then
            result = result .. string.char(math.random(65, 90))
        elseif num == 1 then
            result = result .. string.char(math.random(97, 122))
        else
            result = result .. string.char(math.random(48, 57))
        end
    end
    return result
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

local genStr = function(s, count)
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

local quatMultiply = function(q1, q2)
    local newQuat = {}
    newQuat.w = -q1.x * q2.x - q1.y * q2.y - q1.z * q2.z + q1.w * q2.w
    newQuat.x = q1.x * q2.w + q1.y * q2.z - q1.z * q2.y + q1.w * q2.x
    newQuat.y = -q1.x * q2.z + q1.y * q2.w + q1.z * q2.x + q1.w * q2.y
    newQuat.z = q1.x * q2.y - q1.y * q2.x + q1.z * q2.w + q1.w * q2.z
    return newQuat
end

local RotateVectorByQuat = function(quat, v)
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

local quat2Euler = function(quat)
    local FPoint = RotateVectorByQuat(quat, { x = 1, y = 0, z = 0 })
    local LPoint = RotateVectorByQuat(quat, { x = 0, y = 0, z = -1 })
    local TopPoint = RotateVectorByQuat(quat, { x = 0, y = 1, z = 0 })
    local ag = {}
    ag.pitch = math.deg(math.asin(FPoint.y))
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

local quaternionInv = function(q)
    local a = 1.0 / (q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w);
    return { w = a * q.w, x = a * -q.x, y = a * -q.y, z = a * -q.z }
end

local getEulerByMatrix = function(matrix)
    return {
        yaw = math.deg(math.atan2(matrix[1][3], matrix[3][3])),
        pitch = math.deg(math.atan2(matrix[2][1], matrix[2][2])),
        roll = math.deg(math.atan2(-matrix[2][3], matrix[2][2]))
    }
end

local getEulerByMatrixLeft = function(matrix)
    return {
        yaw = math.deg(math.atan2(matrix[3][3], matrix[1][3])),
        pitch = math.deg(math.atan2(matrix[2][1], matrix[2][2])),
        roll = math.deg(math.atan2(matrix[2][3], matrix[2][2]))
    }
end

local euler2Quat = function(roll, yaw, pitch)
    local cy = math.cos(-pitch)
    local sy = math.sin(-pitch)
    local cp = math.cos(-yaw)
    local sp = math.sin(-yaw)
    local cr = math.cos(-roll)
    local sr = math.sin(-roll)
    local q = {
        w = cy * cp * cr + sy * sp * sr,
        x = cy * cp * sr - sy * sp * cr,
        y = sy * cp * sr + cy * sp * cr,
        z = sy * cp * cr - cy * sp * sr
    }
    return q
end

local quatLookAt = function(v)
    local CosY = v.z / math.sqrt(v.x * v.x + v.z * v.z)
    local CosYDiv2 = math.sqrt((1 - CosY) / 2)
    if (v.x < 0) then CosYDiv2 = -CosYDiv2 end
    local SinYDiv2 = math.sqrt((CosY + 1) / 2)

    local CosX = math.sqrt((v.x * v.x + v.z * v.z) / (v.x * v.x + v.y * v.y + v.z * v.z))
    local CosXDiv2 = math.sqrt((CosX + 1) / 2)
    if (v.z > 0) then CosXDiv2 = -CosXDiv2 end
    local SinXDiv2 = math.sqrt((1 - CosX) / 2)

    return {
        w = CosXDiv2 * CosYDiv2,
        x = SinXDiv2 * CosYDiv2,
        y = CosXDiv2 * SinYDiv2,
        z = SinXDiv2 * SinYDiv2
    }
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

local getRate = function(rc, s, exp, x)
    if s >= 1 then
        s = 0.99
    end
    local flag = x < 0 and true or false
    x = math.abs(x)
    local p = 1 / (1 - (x * s))
    local q = (math.pow(x, 4) * exp) + x * (1 - exp)
    local r = 200 * q * rc
    local t = r * p
    return flag and -t or t
end

local getThrottle = function(mid, t_exp, x)
    x = x > 1 and 1 or x
    local flag = x < 0 and true or false
    x = math.abs(x)
    local result = 0
    if x < mid then
        x = 1 - (x / mid)
        result = (math.pow(x, 2) * t_exp) + x * (1 - t_exp)
        result = mid - result * mid
    else
        x = (x - mid) / (1 - mid)
        result = (math.pow(x, 2) * t_exp) + x * (1 - t_exp)
        result = mid + result * (1 - mid)
    end
    return flag and -result or result
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

function genWakeFlow()
    local xSpeed = math.abs(RotateVectorByQuat(attUtil.quat, attUtil.velocity).x * 20 * 3.6)
    --commands.execAsync(("say xSpeed = %0.2f km/h"):format(xSpeed))
    local p1 = { x = 0, y = 0, z = attUtil.size.z / 2 * ship.getScale().x }
    local p2 = { x = p1.x, y = p1.y, z = -p1.z }
    local pm = { x = -attUtil.size.x / 2, y = 0, z = 0 }
    p1 = RotateVectorByQuat(ship.getQuaternion(), p1)
    p2 = RotateVectorByQuat(ship.getQuaternion(), p2)
    pm = RotateVectorByQuat(ship.getQuaternion(), pm)
    for k, v in pairs(p1) do
        p1[k] = p1[k] + attUtil.position[k]
        p2[k] = p2[k] + attUtil.position[k]
        pm[k] = pm[k] + attUtil.position[k]
    end
    commands.execAsync(string.format("particle glow_squid_ink %0.6f %0.6f %0.6f 0 0 0 0 0 force", pm.x, pm.y, pm.z))
    if xSpeed > 50 then
        commands.execAsync(string.format("particle cloud %0.6f %0.6f %0.6f 0 0 0 0 0 force", p1.x, p1.y, p1.z))
        commands.execAsync(string.format("particle cloud %0.6f %0.6f %0.6f 0 0 0 0 0 force", p2.x, p2.y, p2.z))
    end
end

local getWorldOffsetOfPcPos = function(v)
    local wPos = ship.getWorldspacePosition()
    local yardPos = ship.getShipyardPosition()
    local selfPos = coordinate.getAbsoluteCoordinates()
    local offset = {
        x = yardPos.x - selfPos.x - 0.5 - v.x,
        y = yardPos.y - selfPos.y - 0.5 - v.y,
        z = yardPos.z - selfPos.z - 0.5 - v.z
    }
    offset = RotateVectorByQuat(ship.getQuaternion(), offset)
    return {
        x = wPos.x - offset.x,
        y = wPos.y - offset.y,
        z = wPos.z - offset.z
    }
end

local applyInvariantForce = function(x, y, z)
    InvariantForce = math.abs(x) + math.abs(y) + math.abs(z)
    --commands.execAsync(("say iForce = %d"):format(InvariantForce))
    ship.applyInvariantForce(x, y, z)
end

local applyRotDependentForce = function(x, y, z)
    RotDependentForce = math.abs(x) + math.abs(y) + math.abs(z)
    --commands.execAsync(("say rotForce = %d"):format(RotDependentForce))
    ship.applyRotDependentForce(x, y, z)
end

local applyRotDependentTorque = function(x, y, z)
    RotDependentTorque = math.abs(x) + math.abs(y) + math.abs(z)
    --commands.execAsync(("say rotTorque = %d"):format(RotDependentTorque))
    ship.applyRotDependentTorque(x, y, z)
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
    return coordinate.getShipsAll(256)
end

scanner.scanEntity = function()
    return coordinate.getEntitiesAll(-1)
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
    tmpFlags = {},
    wingWeight = 0
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
    local tmpYawrad = math.rad(attUtil.eulerAngle.yaw)
    attUtil.yawMatrix = { { -math.sin(tmpYawrad), -math.cos(tmpYawrad) },
        { -math.cos(tmpYawrad), math.sin(tmpYawrad) } }
    attUtil.pX = RotateVectorByQuat(attUtil.quat, { x = 1, y = 0, z = 0 })
    attUtil.pY = RotateVectorByQuat(attUtil.quat, { x = 0, y = 1, z = 0 })
    attUtil.pZ = RotateVectorByQuat(attUtil.quat, { x = 0, y = 0, z = -1 })
    --attUtil.getOmega(attUtil.pX, attUtil.pY, attUtil.pZ)
    attUtil.omega = RotateVectorByQuat(attUtil.conjQuat, ship.getOmega())
    attUtil.velocity.x = ship.getVelocity().x / 20
    attUtil.velocity.y = ship.getVelocity().y / 20
    attUtil.velocity.z = ship.getVelocity().z / 20
    attUtil.speed = math.sqrt(ship.getVelocity().x ^ 2 + ship.getVelocity().y ^ 2 + ship.getVelocity().z ^ 2)
    --commands.execAsync(("say w=%0.6f, x=%0.6f, y=%0.6f, z=%0.6f"):format(attUtil.quat.w, attUtil.quat.x, attUtil.quat.y, attUtil.quat.z))

    attUtil.wingWeight = 1 / (properties.wing.wings.size * 2 + properties.wing.tail_wings.size)
end

attUtil.getAttWithPhysTick = function()
    attUtil.mass = attUtil.inertia.mass
    attUtil.MomentOfInertiaTensor = attUtil.inertia.momentOfInertiaTensor[1][1] * math.pow(ship.getScale().x, -2)

    attUtil.size = ship.getSize()
    attUtil.position = attUtil.poseVel.pos
    attUtil.quat = quatMultiply(attUtil.quatList[properties.shipFace], attUtil.poseVel.rot)
    attUtil.conjQuat = getConjQuat(attUtil.poseVel.rot)
    attUtil.matrix = ship.getRotationMatrix()
    attUtil.eulerAngle = quat2Euler(attUtil.quat)
    local tmpYawrad = math.rad(attUtil.eulerAngle.yaw)
    attUtil.yawMatrix = { { -math.sin(tmpYawrad), -math.cos(tmpYawrad) },
        { -math.cos(tmpYawrad), math.sin(tmpYawrad) } }
    attUtil.pX = RotateVectorByQuat(attUtil.quat, { x = 1, y = 0, z = 0 })
    attUtil.pY = RotateVectorByQuat(attUtil.quat, { x = 0, y = 1, z = 0 })
    attUtil.pZ = RotateVectorByQuat(attUtil.quat, { x = 0, y = 0, z = -1 })
    attUtil.omega = RotateVectorByQuat(attUtil.conjQuat, attUtil.poseVel.omega)
    attUtil.velocity.x = attUtil.poseVel.velocity.x / 60
    attUtil.velocity.y = attUtil.poseVel.velocity.y / 60
    attUtil.velocity.z = attUtil.poseVel.velocity.z / 60
    attUtil.speed = math.sqrt(ship.getVelocity().x ^ 2 + ship.getVelocity().y ^ 2 + ship.getVelocity().z ^ 2)
    attUtil.wingWeight = 1 / ((properties.wing.wings.size + properties.wing.tail_wings.size) * 2)
    --commands.execAsync(("say w=%df, x=%df"):format(attUtil.quat.w * 1000, attUtil.quat.x * 1000))
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
        lastPos = ship.getWorldspacePosition(),
        lastEuler = quat2Euler(attUtil.quat),
        hmsLastAtt = quat2Euler(attUtil.quat),
        followLastAtt = ship.getWorldspacePosition(),
        quat = quatMultiply(attUtil.quatList[properties.shipFace], ship.getQuaternion())
    }
end

attUtil.setLastPos = function()
    attUtil.tmpFlags.lastPos = attUtil.position
    attUtil.tmpFlags.lastEuler = attUtil.eulerAngle
    attUtil.tmpFlags.quat = attUtil.quat
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
            joyUtil.RightJoyClick = joyUtil.joy.getButton(11)
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
                monitorUtil.refreshAll()
            elseif joyUtil.right or joyUtil.left then
            elseif joyUtil.RightJoyClick then
                properties.coupled = not properties.coupled
            end

            if physics_flag then
                joyUtil.cd = 4
            else
                joyUtil.cd = 16
            end
        end
        joyUtil.cd = joyUtil.cd > 0 and joyUtil.cd - 1 or 0
    else
        joyUtil.defaultOutput()
    end
end

joyUtil.defaultOutput = function()
    joyUtil.LeftStick.y = 0 + properties.zeroPoint
    joyUtil.LeftStick.x = 0
    joyUtil.RightStick.x = 0
    joyUtil.RightStick.y = 0
    joyUtil.LeftJoyClick = false
    joyUtil.RightJoyClick = false
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
    quadFpv_P = 0.3456,
    quadFpv_D = 7.25,
    helicopt_P_multiply = 1,
    helicopt_D_multiply = 1,
    rot_P_multiply = 1,
    rot_D_multiply = 1,
    move_P_multiply = 1,
    move_D_multiply = 100,
    airMass_multiply = 30,
    tmpp = 1 / (math.pi / 2)
}

pdControl.moveWithOutRot = function(xVal, yVal, zVal, p, d)
    p = p * pdControl.move_P_multiply
    d = d * pdControl.move_D_multiply
    pdControl.xSpeed = xVal * p + -attUtil.velocity.x * d
    pdControl.zSpeed = zVal * p + -attUtil.velocity.z * d
    pdControl.ySpeed = yVal * p + pdControl.basicYSpeed + -attUtil.velocity.y * d
    applyInvariantForce(pdControl.xSpeed * attUtil.mass,
        pdControl.ySpeed * attUtil.mass,
        pdControl.zSpeed * attUtil.mass)
end

pdControl.moveWithRot = function(xVal, yVal, zVal, p, d, sidemove_p)
    if properties.mode == 1 and not properties.coupled then
        d = 0.15 * pdControl.move_D_multiply
    else
        d = d * pdControl.move_D_multiply
    end
    p = p * pdControl.move_P_multiply
    pdControl.xSpeed = -attUtil.velocity.x * d
    pdControl.zSpeed = -attUtil.velocity.z * d
    if properties.mode == 1 and not properties.coupled then
        pdControl.ySpeed = -attUtil.velocity.y * d
    else
        pdControl.ySpeed = pdControl.basicYSpeed + -attUtil.velocity.y * d
    end

    applyInvariantForce(pdControl.xSpeed * attUtil.mass,
        pdControl.ySpeed * attUtil.mass,
        pdControl.zSpeed * attUtil.mass)

    if sidemove_p then
        sidemove_p = sidemove_p * pdControl.move_P_multiply
        
        if properties.shipFace == "north" or properties.shipFace == "south" then
            xVal, yVal, zVal = xVal * sidemove_p, yVal * p, zVal * p
        else
            xVal, yVal, zVal = xVal * p, yVal * p, zVal * sidemove_p
        end
        applyRotDependentForce(xVal * attUtil.mass,
            yVal * attUtil.mass,
            zVal * attUtil.mass)
    else
        applyRotDependentForce(xVal * p * attUtil.mass,
            yVal * p * attUtil.mass,
            zVal * p * attUtil.mass)
    end
end

pdControl.quadUp = function(yVal, p, d, hov)
    p = p * pdControl.move_P_multiply
    d = d * pdControl.move_D_multiply
    if hov then
        local omegaApplyRot = RotateVectorByQuat(attUtil.quat, { x = 0, y = attUtil.velocity.y, z = 0 })
        pdControl.ySpeed = yVal * p +
            pdControl.basicYSpeed + -omegaApplyRot.y * d
    else
        pdControl.ySpeed = yVal * p
    end

    applyRotDependentForce(0, pdControl.ySpeed * attUtil.mass, 0)

    pdControl.xSpeed = copysign((attUtil.velocity.x ^ 2) * pdControl.airMass_multiply * properties.airMass,
        -attUtil.velocity.x)
    pdControl.zSpeed = copysign((attUtil.velocity.z ^ 2) * pdControl.airMass_multiply * properties.airMass,
        -attUtil.velocity.z)
    pdControl.ySpeed = copysign((attUtil.velocity.y ^ 2) * pdControl.airMass_multiply * properties.airMass,
        -attUtil.velocity.y)

    if properties.mode ~= 3 then
        applyInvariantForce(pdControl.xSpeed * attUtil.mass,
            pdControl.ySpeed * attUtil.mass + properties.gravity * pdControl.basicYSpeed * attUtil.mass,
            pdControl.zSpeed * attUtil.mass)
    else
        applyInvariantForce(pdControl.xSpeed * attUtil.mass,
            pdControl.ySpeed * attUtil.mass,
            pdControl.zSpeed * attUtil.mass)
    end
end

pdControl.rotInner = function(xRot, yRot, zRot, p, d)
    p                    = p * pdControl.rot_P_multiply
    d                    = d * pdControl.rot_D_multiply
    xRot                 = resetAngelRange(xRot)
    yRot                 = resetAngelRange(yRot)
    zRot                 = resetAngelRange(zRot)
    pdControl.pitchSpeed = resetAngelRange(attUtil.omega.z + zRot) * p + -attUtil.omega.z * 7 * d
    pdControl.rollSpeed  = resetAngelRange(attUtil.omega.x + xRot) * p + -attUtil.omega.x * 7 * d
    pdControl.yawSpeed   = resetAngelRange(attUtil.omega.y + yRot) * p + -attUtil.omega.y * 7 * d
    applyRotDependentTorque(
        pdControl.rollSpeed * attUtil.MomentOfInertiaTensor * (ship.getScale().x ^ 2),
        pdControl.yawSpeed * attUtil.MomentOfInertiaTensor * (ship.getScale().x ^ 2),
        pdControl.pitchSpeed * attUtil.MomentOfInertiaTensor * (ship.getScale().x ^ 2))
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
    local force = {
        x = resetAngelRange(euler.roll - attUtil.eulerAngle.roll),
        y = resetAngelRange(euler.yaw - attUtil.eulerAngle.yaw),
        z = resetAngelRange(euler.pitch - attUtil.eulerAngle.pitch),
    }

    force = RotateVectorByQuat(attUtil.conjQuat, force)

    pdControl.rotInner(force.x, force.y, force.z, p, 9)
end

pdControl.rotate2quat = function(q, p, d)
    q = getConjQuat(q)
    local tgQ = quatMultiply(q, attUtil.quat)
    local xPoint, zPoint
    xPoint = RotateVectorByQuat(tgQ, { x = -1, y = 0, z = 0 })
    zPoint = RotateVectorByQuat(tgQ, { x = 0, y = 0, z = -1 })
    local xRot = math.deg(-math.asin(zPoint.y))
    local yRot = math.deg(-math.asin(xPoint.z))
    local zRot = math.deg(math.asin(xPoint.y))
    pdControl.rotInner(xRot, yRot, zRot, p, d)
end

pdControl.spaceShip = function()
    if properties.lock then
        if next(attUtil.tmpFlags.quat) == nil then attUtil.setLastPos() end
        if next(attUtil.tmpFlags.lastPos) == nil then attUtil.setLastPos() end
        pdControl.rotate2quat(attUtil.tmpFlags.quat, 0.9, 2.8)
        pdControl.gotoPosition(nil, attUtil.tmpFlags.lastPos, properties.MAX_MOVE_SPEED)
    else
        local forward, up, sideMove = math.deg(math.asin(joyUtil.BTStick.y)), math.deg(math.asin(joyUtil.LeftStick.y)),
            math.deg(math.asin(joyUtil.BTStick.x))
        local xRot, yRot, zRot = math.deg(math.asin(joyUtil.RightStick.x)), math.deg(math.asin(joyUtil.LeftStick.x)),
            math.deg(math.asin(joyUtil.RightStick.y))
        if joyUtil.LeftJoyClick then
            local p = properties.profile[properties.profileIndex].spaceShip_Burner
            forward, up, sideMove = forward * p, up * p, sideMove * p
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

pdControl.quatRot = function(xRot, yRot, zRot)
    pdControl.xSpeed = (attUtil.omega.x + xRot) * pdControl.quadFpv_P + -attUtil.omega.x * pdControl.quadFpv_D
    pdControl.ySpeed = (attUtil.omega.y + yRot) * pdControl.quadFpv_P + -attUtil.omega.y * pdControl.quadFpv_D
    pdControl.zSpeed = (attUtil.omega.z + zRot) * pdControl.quadFpv_P + -attUtil.omega.z * pdControl.quadFpv_D
    applyRotDependentTorque(
        pdControl.xSpeed * attUtil.MomentOfInertiaTensor * (ship.getScale().x ^ 2),
        pdControl.ySpeed * attUtil.MomentOfInertiaTensor * (ship.getScale().y ^ 2),
        pdControl.zSpeed * attUtil.MomentOfInertiaTensor * (ship.getScale().z ^ 2))
end

pdControl.quadFPV = function()
    local prf = properties.profile[properties.profileIndex]
    if properties.lock then
        if joyUtil.LeftStick.y == 0 then
            pdControl.quadUp(
                0,
                properties.profile[properties.profileIndex].max_throttle / pdControl.rot_D_multiply,
                3,
                true)
        else
            pdControl.quadUp(
                math.deg(math.asin(joyUtil.LeftStick.y)),
                properties.profile[properties.profileIndex].max_throttle / pdControl.rot_D_multiply,
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
            pdControl.rotate2Euler2(euler, 1, 2.6)
        else
            pdControl.rotate2Euler2({
                    roll = math.deg(math.asin(joyUtil.RightStick.x)) / 3,
                    yaw = attUtil.eulerAngle.yaw + joyUtil.LeftStick.x * 20 / pdControl.rot_D_multiply,
                    pitch = math.deg(math.asin(joyUtil.RightStick.y) / 3)
                },
                1,
                2)
        end
    else
        local throttle
        if properties.zeroPoint == -1 then
            throttle = math.asin((joyUtil.LeftStick.y + 1) / 2) * pdControl.tmpp
        else
            throttle = math.asin(joyUtil.LeftStick.y) * pdControl.tmpp
        end
        throttle = getThrottle(prf.throttle_mid, prf.throttle_expo, throttle) * 2 * prf.max_throttle
        --commands.execAsync(("say %d"):format(throttle * 50))
        pdControl.quadUp(
            math.deg(throttle),
            properties.profile[properties.profileIndex].max_throttle / pdControl.rot_D_multiply,
            3,
            false)
        local xRot = math.asin(joyUtil.RightStick.x) * pdControl.tmpp
        local yRot = math.asin(joyUtil.LeftStick.x) * pdControl.tmpp
        local zRot = math.asin(joyUtil.RightStick.y) * pdControl.tmpp
        xRot = getRate(prf.roll_rc_rate, prf.roll_s_rate, prf.roll_expo, xRot)
        yRot = getRate(prf.yaw_rc_rate, prf.yaw_s_rate, prf.yaw_expo, yRot)
        zRot = getRate(prf.pitch_rc_rate, prf.pitch_s_rate, prf.pitch_expo, zRot)
        pdControl.quatRot(xRot, yRot, zRot)
    end
end

pdControl.quadSpaceUp = function(xVal, yVal, zVal, p)
    p = p * pdControl.move_P_multiply
    local xSpeed = xVal * p
    local ySpeed = yVal * p
    local zSpeed = zVal * p

    applyRotDependentForce(xSpeed * attUtil.mass, ySpeed * attUtil.mass, zSpeed * attUtil.mass)

    xSpeed = copysign((attUtil.velocity.x ^ 2) * pdControl.airMass_multiply * properties.airMass,
        -attUtil.velocity.x)
    zSpeed = copysign((attUtil.velocity.z ^ 2) * pdControl.airMass_multiply * properties.airMass,
        -attUtil.velocity.z)
    ySpeed = copysign((attUtil.velocity.y ^ 2) * pdControl.airMass_multiply * properties.airMass,
        -attUtil.velocity.y)

    if properties.mode ~= 3 then
        applyInvariantForce(xSpeed * attUtil.mass,
            ySpeed * attUtil.mass + properties.gravity * pdControl.basicYSpeed * attUtil.mass,
            zSpeed * attUtil.mass)
    else
        applyInvariantForce(xSpeed * attUtil.mass,
            ySpeed * attUtil.mass,
            zSpeed * attUtil.mass)
    end
end

pdControl.spaceFpv = function()
    local prf = properties.profile[properties.profileIndex]
    local throttle = math.asin(joyUtil.LeftStick.y) * pdControl.tmpp
    throttle = getThrottle(prf.throttle_mid, prf.throttle_expo, throttle) * 2 * prf.max_throttle
    pdControl.quadSpaceUp(
        math.deg(math.asin(joyUtil.BTStick.y)),
        math.deg(throttle),
        math.deg(math.asin(joyUtil.BTStick.x)),
        properties.profile[properties.profileIndex].max_throttle / pdControl.rot_D_multiply)
    local xRot = math.asin(joyUtil.RightStick.x) * pdControl.tmpp
    local yRot = math.asin(joyUtil.LeftStick.x) * pdControl.tmpp
    local zRot = math.asin(joyUtil.RightStick.y) * pdControl.tmpp
    xRot = getRate(prf.roll_rc_rate, prf.roll_s_rate, prf.roll_expo, xRot)
    yRot = getRate(prf.yaw_rc_rate, prf.yaw_s_rate, prf.yaw_expo, yRot)
    zRot = getRate(prf.pitch_rc_rate, prf.pitch_s_rate, prf.pitch_expo, zRot)
    pdControl.quatRot(xRot, yRot, zRot)
end

pdControl.fixedWing = function()
    local s = RotateVectorByQuat(getConjQuat(attUtil.quat), attUtil.velocity)
    --计算三轴压强
    --local powX = s.x ^ 2
    local powX = 0
    local xDrag = copysign(powX, -s.x) * 0.01
    local yDrag = copysign((s.y * 2) ^ 2, -s.y)
    yDrag = yDrag + yDrag * powX
    yDrag = math.abs(yDrag) > 128 and copysign(128, yDrag) or yDrag
    local zDrag = copysign((s.z * 2) ^ 2, -s.z)
    zDrag = zDrag + zDrag * powX
    zDrag = math.abs(zDrag) > 128 and copysign(128, zDrag) or zDrag

    local p1 = properties.wing.wings.pos
    local p1w = attUtil.wingWeight * properties.wing.wings.size

    local p3 = properties.wing.tail_wings.pos
    local p3w = attUtil.wingWeight * properties.wing.tail_wings.size

    local xRotDrag = copysign(attUtil.omega.x ^ 2 * p1.z, attUtil.omega.x) --roll
    xRotDrag = xRotDrag + xRotDrag * powX
    local yRotDrag = copysign(attUtil.omega.y ^ 2 * properties.wing.verticalTail.pos.x, attUtil.omega.y) --yaw
    yRotDrag = yRotDrag + yRotDrag * powX
    local zRotD_All = attUtil.omega.z ^ 2
    local zRotDrag_1 = copysign(zRotD_All * p1.x, -attUtil.omega.z) --pitch
    zRotDrag_1 = zRotDrag_1 + zRotDrag_1 * powX
    local zRotDrag_2 = copysign(zRotD_All * p3.x, -attUtil.omega.z) --pitch
    zRotDrag_2 = zRotDrag_2 + zRotDrag_2 * powX

    xRotDrag = math.abs(xRotDrag) > 128 and copysign(128, xRotDrag) or xRotDrag
    yRotDrag = math.abs(yRotDrag) > 128 and copysign(128, yRotDrag) or yRotDrag
    zRotDrag_1 = math.abs(zRotDrag_1) > 128 and copysign(128, zRotDrag_1) or zRotDrag_1
    zRotDrag_2 = math.abs(zRotDrag_2) > 128 and copysign(128, zRotDrag_2) or zRotDrag_2

    ship.applyRotDependentForceToPos(0, (yDrag + xRotDrag + zRotDrag_1 / 2) * properties.wing.wings.size * attUtil.mass, 0, p1.x, p1.y, p1.z)
    ship.applyRotDependentForceToPos(0, (yDrag - xRotDrag + zRotDrag_1 / 2) * properties.wing.wings.size * attUtil.mass, 0, p1.x, p1.y, -p1.z)

    ship.applyRotDependentForceToPos(0, (yDrag + zRotDrag_2) * properties.wing.tail_wings.size * 2 * attUtil.mass,
        (zDrag + yRotDrag) * properties.wing.tail_wings.size * attUtil.mass, p3.x, p3.y, p3.z)

    xDrag = xDrag * (attUtil.size.z * attUtil.size.y)
end

pdControl.helicopter = function()
    local acc
    local tgAg = {}
    if properties.lock then
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

    if properties.lock then
        pdControl.gotoPosition(attUtil.tmpFlags.lastEuler, attUtil.tmpFlags.lastPos, properties.MAX_MOVE_SPEED)
    else
        local yaw = attUtil.eulerAngle.yaw + math.asin(joyUtil.LeftStick.x) * 9 * profile.airShip_ROT_P
        pdControl.rotate2Euler2({ roll = 0, yaw = yaw, pitch = 0 }, 0.05, profile.airShip_ROT_D)
        pdControl.moveWithRot(
            math.asin(joyUtil.BTStick.y) * 9 * profile.airShip_MOVE_P,
            math.asin(joyUtil.LeftStick.y) * 9 * profile.airShip_MOVE_P,
            math.asin(joyUtil.BTStick.x) * 9 * profile.airShip_MOVE_P,
            profile.airShip_MOVE_P,
            1
        )
    end
end

pdControl.gotoPosition = function(euler, pos, maxSpeed)
    pdControl.gotoPositionWithPD(euler, attUtil.position, pos, maxSpeed, 8, 3.6, 6)
end

pdControl.gotoPositionWithPD = function(euler, pos1, pos2, maxSpeed, p, p2, d)
    local xVal, yVal, zVal
    xVal = (pos2.x - pos1.x) * p2
    yVal = (pos2.y - pos1.y) * p2
    zVal = (pos2.z - pos1.z) * p2
    if properties.mode ~= 9 then
        xVal = math.abs(xVal) > maxSpeed and copysign(maxSpeed, xVal) or xVal
        yVal = math.abs(yVal) > maxSpeed and copysign(maxSpeed, yVal) or yVal
        zVal = math.abs(zVal) > maxSpeed and copysign(maxSpeed, zVal) or zVal
    end
    pdControl.moveWithOutRot(
        xVal,
        yVal,
        zVal,
        p,
        d
    )

    if euler then
        euler.roll  = resetAngelRange(euler.roll)
        euler.yaw   = resetAngelRange(euler.yaw)
        euler.pitch = resetAngelRange(euler.pitch)
        pdControl.rotate2Euler2(euler, 0.5, 2.8)
    end
end

pdControl.HmsSpaceBasedGun = function()
    local block =
        rayCaster.run(
            scanner.commander,
            {
                x = scanner.commander.raw_euler_x,
                y = scanner.commander.raw_euler_y,
                z = scanner.commander.raw_euler_z
            },
            properties.rayCasterRange,
            false
        )
    local pos = {}
    pos.x = attUtil.position.x - block.x
    pos.y = -(attUtil.position.y - block.y)
    pos.z = attUtil.position.z - block.z

    local tmpPos = RotateVectorByQuat(quatMultiply(attUtil.conjQuat, attUtil.quatList[properties.shipFace]), pos)

    local add = math.sqrt(tmpPos.x ^ 2 + tmpPos.y ^ 2 + tmpPos.z ^ 2)

            local yRot = math.deg(math.atan2(tmpPos.z, -tmpPos.x))
            local zRot = -math.deg(math.asin(tmpPos.y / add))

    pdControl.rotInner(-attUtil.eulerAngle.roll, yRot, zRot, 1, 2.32)

    pdControl.gotoPosition(
        { roll = 0, yaw = targetAngle.yaw, pitch = targetAngle.pitch },
        properties.HOME, properties.MAX_MOVE_SPEED
    )
end

pdControl.followMouse = function()
    local xRot, yRot, zRot = 0, 0, 0
    if joyUtil.flag then
        if joyUtil.joy.hasUser() then
            local startPoint = scanner.commander
            startPoint.y = startPoint.y
            local block = rayCaster.run(
                startPoint,
                {
                    x = scanner.commander.raw_euler_x,
                    y = scanner.commander.raw_euler_y,
                    z = scanner.commander.raw_euler_z
                },
                8,
                false
            )
            --genParticle(block.x, block.y, block.z)
            local pos = {}
            pos.x = startPoint.x - block.x
            pos.y = startPoint.y - block.y
            pos.z = startPoint.z - block.z
            
            pos = RotateVectorByQuat(quatMultiply(attUtil.conjQuat, attUtil.quatList["west"]), pos)
            xRot = math.deg(math.asin(joyUtil.RightStick.x))
            yRot = resetAngelRange(math.deg(math.atan2(-pos.z, pos.x)) + 180)

            local add = math.sqrt(pos.x ^ 2 + pos.y ^ 2 + pos.z ^ 2)
            zRot = -math.deg(math.asin(pos.y / add))
            
            --xRot = resetAngelRange(math.deg(math.atan2(-vec.z, vec.x)) + 180)
            --yRot = 0
            --zRot = -math.deg(math.asin(vec.y))
        end
    end
    
    local p              = properties.profile[properties.profileIndex].spaceShip_P * pdControl.rot_P_multiply
    local d              = properties.profile[properties.profileIndex].spaceShip_D * pdControl.rot_D_multiply
    local d2 = 18 * pdControl.rot_D_multiply
    pdControl.pitchSpeed = resetAngelRange(attUtil.omega.z + zRot) * (p * 8) + -attUtil.omega.z * 7 * d2
    pdControl.rollSpeed  = resetAngelRange(attUtil.omega.x + xRot) * p + -attUtil.omega.x * 7 * d
    pdControl.yawSpeed   = resetAngelRange(attUtil.omega.y + yRot) * (p * 8) + -attUtil.omega.y * 7 * d2
    applyRotDependentTorque(
    pdControl.rollSpeed * attUtil.MomentOfInertiaTensor * (ship.getScale().x ^ 2),
    pdControl.yawSpeed * attUtil.MomentOfInertiaTensor * (ship.getScale().x ^ 2),
    pdControl.pitchSpeed * attUtil.MomentOfInertiaTensor * (ship.getScale().x ^ 2))

    --pdControl.rotInner(xRot, yRot, zRot, p, d)
    local forward, up, sideMove = math.deg(math.asin(joyUtil.BTStick.y)), math.deg(math.asin(joyUtil.LeftStick.y)),
            math.deg(math.asin(joyUtil.BTStick.x))
    if joyUtil.LeftJoyClick then
        local p = properties.profile[properties.profileIndex].spaceShip_Burner
        forward, up, sideMove = forward * p, up * p, sideMove * p
    end
    pdControl.moveWithRot( forward, up, sideMove,
        properties.profile[properties.profileIndex].spaceShip_Acc,
        properties.profile[properties.profileIndex].spaceShip_move_D)
end

pdControl.follow = function(target)
    if target then
        local pos, qPos = {}, {}
        local sz = RotateVectorByQuat(getConjQuat(attUtil.quat), attUtil.size)
        sz.x = sz.x * ship.getScale().x
        sz.y = sz.y * ship.getScale().y
        sz.z = sz.z * ship.getScale().z
        qPos.x = copysign(sz.x / 2, properties.followRange.x) + properties.followRange.x
        qPos.y = copysign(sz.y / 2, properties.followRange.y) + properties.followRange.y
        qPos.z = copysign(sz.z / 2, properties.followRange.z) + properties.followRange.z
        pos.x = target.x + qPos.x
        pos.y = target.y + qPos.y
        pos.z = target.z + qPos.z
        attUtil.tmpFlags.followLastAtt = pos
    end

    pdControl.gotoPosition(nil, attUtil.tmpFlags.followLastAtt, properties.MAX_MOVE_SPEED)

    local vec = {
        x = target.x - attUtil.position.x,
        y = target.y + 1.75 - attUtil.position.y,
        z = target.z - attUtil.position.z
    }
    local euler = {
        roll = 0,
        yaw = math.atan2(vec.x, vec.z),
        pitch = math.asin(vec.y / math.sqrt(vec.x ^ 2 + vec.y ^ 2 + vec.z ^ 2))
    }
    local ag = euler2Quat(
        0,
        math.atan2(vec.x, vec.z),
        math.asin(vec.y / math.sqrt(vec.x ^ 2 + vec.y ^ 2 + vec.z ^ 2))
    )
    pdControl.rotate2Euler({roll = math.deg(euler.roll), yaw = math.deg(euler.yaw), pitch = math.deg(euler.pitch)}, 2, 2.8)
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
        tgAg, pos, properties.MAX_MOVE_SPEED)
end

local cameraQuat = { w = 1, x = 0, y = 0, z = 0 }
local xOffset = 0
pdControl.ShipCamera = function()
    if parentShip.id ~= -1 then
        xOffset = xOffset + math.asin(joyUtil.BTStick.y) * properties.profile[properties.profileIndex].camera_move_speed
        xOffset = xOffset < 3 and 3 or xOffset
        xOffset = xOffset > 64 and 64 or xOffset
        local maxSize = math.max(parentShip.size.x, parentShip.size.z)
        maxSize = math.max(maxSize, parentShip.size.y)
        local range = { x = -maxSize - xOffset, y = 0, z = 0 }
        local pos = {}

        pos.x = parentShip.pos.x + parentShip.velocity.x
        pos.y = parentShip.pos.y + parentShip.velocity.y
        pos.z = parentShip.pos.z + parentShip.velocity.z
        local speedMult = xOffset * 2
        speedMult = speedMult < 8 and 8 or speedMult
        local myRot = euler2Quat(
            math.asin(joyUtil.LeftStick.x) / 16 * properties.profile[properties.profileIndex].camera_rot_speed,
            math.asin(joyUtil.RightStick.x) / speedMult * properties.profile[properties.profileIndex].camera_rot_speed,
            math.asin(joyUtil.LeftStick.y) / speedMult * properties.profile[properties.profileIndex].camera_rot_speed
        )

        cameraQuat = quatMultiply(cameraQuat, myRot)
        range = RotateVectorByQuat(cameraQuat, range)
        pos.x = pos.x + range.x
        pos.y = pos.y + range.y
        pos.z = pos.z + range.z
        pdControl.rotate2quat(cameraQuat, 0.9, 2.8)
        pdControl.gotoPosition(nil, pos, properties.MAX_MOVE_SPEED)
    end
end

pdControl.ShipFollow = function()
    if parentShip.id == -1 then return end
    local pos = {
        x = parentShip.pos.x + parentShip.velocity.x,
        y = parentShip.pos.y + parentShip.velocity.y,
        z = parentShip.pos.z + parentShip.velocity.z
    }

    local offsets = {
        x = properties.shipFollow_offset.x + parentShip.size.x,
        y = properties.shipFollow_offset.y,
        z = properties.shipFollow_offset.z
    }
    local newPos = RotateVectorByQuat(parentShip.quat, offsets)

    pos.x = pos.x + newPos.x
    pos.y = pos.y + newPos.y
    pos.z = pos.z + newPos.z

    --local xRot, yRot, zRot = math.deg(math.asin(joyUtil.RightStick.x)), math.deg(math.asin(joyUtil.LeftStick.x)),
    --    math.deg(math.asin(joyUtil.RightStick.y))
    --pdControl.rotInner(
    --    xRot, yRot, zRot,
    --    properties.profile[properties.profileIndex].spaceShip_P,
    --    properties.profile[properties.profileIndex].spaceShip_D)
    pdControl.rotate2quat(parentShip.quat, 0.9, 2.8)
    pdControl.gotoPosition(nil, pos, properties.MAX_MOVE_SPEED)
end

pdControl.anchorage_getTgList = function()
    local list = {}
    -- 1=到达母舰外围 2=到达机库入口 3=机库坐标
    for i = 1, 2, 1 do
        list[i] = {
            x = parentShip.anchorage.pos.x,
            y = parentShip.anchorage.pos.y,
            z = parentShip.anchorage.pos.z
        }
    end

    local size = parentShip.size --获取最大尺寸边框
    local maxBorder = math.abs(size.x) > math.abs(size.y) and size.x or size.y
    maxBorder = math.abs(maxBorder) > math.abs(size.z) and maxBorder or size.z

    local p2 = { x = 0, y = 0, z = 0 }
    if parentShip.anchorage.entry == "top" then
        p2.y = size.y * 0.75
    elseif parentShip.anchorage.entry == "bottom" then
        p2.y = -size.y * 0.75
    elseif parentShip.anchorage.entry == "left" then
        p2.z = size.z * 0.75
    elseif parentShip.anchorage.entry == "right" then
        p2.z = -size.z * 0.75
    elseif parentShip.anchorage.entry == "back" then
        p2.x = size.x * 0.75
    elseif parentShip.anchorage.entry == "front" then
        p2.x = -size.x * 0.75
    end
    p2 = RotateVectorByQuat(parentShip.quat, p2)

    for k, v in pairs(list[2]) do
        list[2][k] = list[2][k] + p2[k]
    end
    local d = math.sqrt(p2.x ^ 2 + p2.y ^ 2 + p2.z ^ 2)
    return list, d
end

pdControl.anchorage = function()
    if parentShip.id == -1 then
        properties.mode = 1
        return
    end

    local sub = {
        x = parentShip.anchorage.pos.x - attUtil.position.x,
        y = parentShip.anchorage.pos.y - attUtil.position.y,
        z = parentShip.anchorage.pos.z - attUtil.position.z
    }

    local distance = math.sqrt(sub.x ^ 2 + sub.y ^ 2 + sub.z ^ 2)
    local targetPos, d = pdControl.anchorage_getTgList()
    local pcPos = getWorldOffsetOfPcPos({ x = 0, y = 0, z = 0 })
    if distance > d + 2 then
        local tmpDis = math.sqrt((targetPos[2].x - attUtil.position.x) ^ 2 +
            (targetPos[2].y - attUtil.position.y) ^ 2 +
            (targetPos[2].z - attUtil.position.z) ^ 2)
        local tgAg = {
            yaw = math.deg(math.atan2(sub.z, -sub.x)),
            roll = 0,
            pitch = -math.deg(math.asin((targetPos[2].y - attUtil.position.y) / tmpDis))
        }
        if tmpDis < 10 then
            tgAg.pitch = 0
        end
        tgAg.pitch = math.abs(tgAg.pitch) > 80 and copysign(80, tgAg.pitch) or tgAg.pitch
        if math.abs(resetAngelRange(tgAg.yaw - attUtil.eulerAngle.yaw)) > 9 or
            math.abs(resetAngelRange(tgAg.pitch - attUtil.eulerAngle.pitch)) > 6 then
            pdControl.rotate2Euler2(tgAg, 0.6, 2.8)
            pdControl.gotoPosition(nil, attUtil.position, 33)
        else
            local maxSpeed = distance / 5
            maxSpeed = maxSpeed > 33 and 33 or maxSpeed
            maxSpeed = maxSpeed < 3 and 3 or maxSpeed
            pdControl.gotoPositionWithPD(tgAg, pcPos, targetPos[2], maxSpeed, 3, 3.6, 2)
        end
    else
        pdControl.rotate2quat(parentShip.quat, 0.36, 2.8)
        pdControl.gotoPositionWithPD(nil, pcPos, targetPos[1], 9, 3, 3.6, 6)
    end
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

function abstractWindow:refreshButtons(cut, page, rowCut) --没有参数时打印所有按钮，有参数时：cut前面的正常打印，cut后面的开始翻页
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
        local start = (page - 1) * (self.height - rowCut) + 1 + cut
        for i = start, page * (self.height - rowCut) + cut, 1 do
            if i > #self.buttons then break end
            local bt = self.buttons[i]
            self.window.setCursorPos(bt.x, bt.y - (page - 1) * (self.height - rowCut))
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
    if result > 5 then
        result = 1
    elseif result == 0 then
        result = 5
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
    if x <= 2 and y == 1 then
        system.updatePersistentData()
        properties.winIndex[self.name][self.row][self.column] = self.indexFlag
    end
end

function abstractWindow:refreshTitle()
    self.window.setCursorPos(3, 1)
    self.window.blit(self.pageName, genStr(properties.title, #self.pageName), genStr(properties.bg, #self.pageName))
end

local page_attach_manager  = {}
local modPage              = setmetatable({ pageId = 1, pageName = "modPage" }, { __index = abstractWindow })
local shipNetPage          = setmetatable({ pageId = 2, pageName = "shipNetPage" }, { __index = abstractWindow })
local attPage              = setmetatable({ pageId = 3, pageName = "attPage" }, { __index = abstractWindow })
local raderPage            = setmetatable({ pageId = 4, pageName = "raderPage" }, { __index = abstractWindow })
local setPage              = setmetatable({ pageId = 5, pageName = "setPage" }, { __index = abstractWindow })
local set_spaceShip        = setmetatable({ pageId = 6, pageName = "set_spaceShip" }, { __index = abstractWindow })
local set_quadFPV          = setmetatable({ pageId = 7, pageName = "set_quadFPV" }, { __index = abstractWindow })
local set_helicopter       = setmetatable({ pageId = 8, pageName = "set_helicopter" }, { __index = abstractWindow })
local set_airShip          = setmetatable({ pageId = 9, pageName = "set_airShip" }, { __index = abstractWindow })
local set_user             = setmetatable({ pageId = 10, pageName = "user_Change" }, { __index = abstractWindow })
local set_home             = setmetatable({ pageId = 11, pageName = "home_set" }, { __index = abstractWindow })
local set_simulate         = setmetatable({ pageId = 12, pageName = "simulate" }, { __index = abstractWindow })
local set_att              = setmetatable({ pageId = 13, pageName = "set_att" }, { __index = abstractWindow })
local set_profile          = setmetatable({ pageId = 14, pageName = "profile" }, { __index = abstractWindow })
local set_colortheme       = setmetatable({ pageId = 15, pageName = "colortheme" }, { __index = abstractWindow })
local shipNet_set_Page     = setmetatable({ pageId = 16, pageName = "shipNet_set" }, { __index = abstractWindow })
local shipNet_connect_Page = setmetatable({ pageId = 17, pageName = "shipNet_call" }, { __index = abstractWindow })
local set_camera           = setmetatable({ pageId = 18, pageName = "set_camera" }, { __index = abstractWindow })
local set_shipFollow       = setmetatable({ pageId = 19, pageName = "set_shipFollow" }, { __index = abstractWindow })
local set_anchorage        = setmetatable({ pageId = 20, pageName = "set_anchorage" }, { __index = abstractWindow })
local mass_fix             = setmetatable({ pageId = 21, pageName = "mass_fix" }, { __index = abstractWindow })
local rate_Roll            = setmetatable({ pageId = 22, pageName = "rate_Roll" }, { __index = abstractWindow })
local rate_Yaw             = setmetatable({ pageId = 23, pageName = "rate_Yaw" }, { __index = abstractWindow })
local rate_Pitch           = setmetatable({ pageId = 24, pageName = "rate_Pitch" }, { __index = abstractWindow })
local set_fixedWing        = setmetatable({ pageId = 25, pageName = "set_fixedWing" }, { __index = abstractWindow })
local set_followRange      = setmetatable({ pageId = 26, pageName = "set_followRange" }, { __index = abstractWindow })

flightPages                = {
    modPage,              --1
    attPage,              --2
    shipNetPage,          --3
    raderPage,            --4
    setPage,              --5
    set_spaceShip,        --6
    set_quadFPV,          --7
    set_helicopter,       --8
    set_airShip,          --9
    set_user,             --10
    set_home,             --11
    set_simulate,         --12
    set_att,              --13
    set_profile,          --14
    set_colortheme,       --15
    shipNet_set_Page,     --16
    shipNet_connect_Page, --17
    set_camera,           --18
    set_shipFollow,       --19
    set_anchorage,        --20
    mass_fix,             --21
    rate_Roll,            --22
    rate_Yaw,             --23
    rate_Pitch,           --24
    set_fixedWing,        --25
    set_followRange       --26
}

--winIndex = 1
function modPage:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.buttons = {
        { text = "<    MOD    >",   x = self.width / 2 - 5, y = 1,               blitF = genStr(title, 13),                blitB = genStr(bg, 13) },
        { text = "[|]",             x = 3,                  y = self.height - 1, blitF = "eee",                            blitB = genStr(bg, 3) },
        { text = "[R]",             x = 6,                  y = self.height - 1, blitF = "222",                            blitB = genStr(bg, 3) },
        { text = "[x]",             x = self.width - 5,     y = self.height - 1, blitF = "888",                            blitB = genStr(bg, 3) },
        { text = modelist[1].name,  x = 2,                  y = 3,               blitF = genStr(font, #modelist[1].name),  blitB = genStr(bg, #modelist[1].name),  modeId = 1,  select = genStr(select, #modelist[1].name) },
        { text = modelist[2].name,  x = 2,                  y = 4,               blitF = genStr(font, #modelist[2].name),  blitB = genStr(bg, #modelist[2].name),  modeId = 2,  select = genStr(select, #modelist[2].name) },
        { text = modelist[3].name,  x = 2,                  y = 5,               blitF = genStr(font, #modelist[3].name),  blitB = genStr(bg, #modelist[3].name),  modeId = 3,  select = genStr(select, #modelist[3].name) },
        { text = modelist[4].name,  x = 2,                  y = 6,               blitF = genStr(font, #modelist[4].name),  blitB = genStr(bg, #modelist[4].name),  modeId = 4,  select = genStr(select, #modelist[4].name) },
        { text = modelist[5].name,  x = 2,                  y = 7,               blitF = genStr(font, #modelist[5].name),  blitB = genStr(bg, #modelist[5].name),  modeId = 5,  select = genStr(select, #modelist[5].name) },
        { text = modelist[6].name,  x = 2,                  y = 8,               blitF = genStr(font, #modelist[6].name),  blitB = genStr(bg, #modelist[6].name),  modeId = 6,  select = genStr(select, #modelist[6].name) },
        { text = modelist[7].name,  x = 2,                  y = 9,               blitF = genStr(font, #modelist[7].name),  blitB = genStr(bg, #modelist[7].name),  modeId = 7,  select = genStr(select, #modelist[7].name) },
        { text = modelist[8].name,  x = 2,                  y = 10,              blitF = genStr(font, #modelist[8].name),  blitB = genStr(bg, #modelist[8].name),  modeId = 8,  select = genStr(select, #modelist[8].name) },
        { text = modelist[9].name,  x = 2,                  y = 11,              blitF = genStr(font, #modelist[9].name),  blitB = genStr(bg, #modelist[9].name),  modeId = 9,  select = genStr(select, #modelist[9].name) },
        { text = modelist[10].name, x = 2,                  y = 12,              blitF = genStr(font, #modelist[10].name), blitB = genStr(bg, #modelist[10].name), modeId = 10, select = genStr(select, #modelist[10].name) },
        { text = modelist[11].name, x = 2,                  y = 13,              blitF = genStr(font, #modelist[11].name), blitB = genStr(bg, #modelist[11].name), modeId = 11, select = genStr(select, #modelist[11].name) },
        { text = modelist[12].name, x = 2,                  y = 14,              blitF = genStr(font, #modelist[12].name), blitB = genStr(bg, #modelist[12].name), modeId = 12, select = genStr(select, #modelist[12].name) },
        { text = modelist[13].name, x = 2,                  y = 15,              blitF = genStr(font, #modelist[13].name), blitB = genStr(bg, #modelist[13].name), modeId = 13, select = genStr(select, #modelist[13].name) },
    }
    self.otherButtons = {
        { text = "      v      ", x = 2, y = self.height - 2, blitF = genStr(bg, 13), blitB = genStr(other, 13) },
        { text = "      ^      ", x = 2, y = 2,               blitF = genStr(bg, 13), blitB = genStr(other, 13) },
    }
    self.pageIndex = 1
    self.cutRow = 5 --不需要分页的区域总行高
end

function modPage:refresh()
    self:refreshButtons(4, self.pageIndex, self.cutRow)
    for k, v in pairs(self.buttons) do
        if v.text == modelist[properties.mode].name then
            local yPos = v.y - (self.pageIndex - 1) * (self.height - self.cutRow)
            if yPos > 2 and yPos < self.height - 1 then
                self.window.setCursorPos(v.x, v.y - (self.pageIndex - 1) * (self.height - self.cutRow))
                self.window.blit(v.text, v.blitB, v.select)
                if properties.lock and v.modeId < 5 then
                    self.window.blit(" L", " " .. properties.other,
                        genStr(properties.bg, 2))
                end
            end
        end
    end
    if #self.buttons > self.height - self.cutRow then
        if self.pageIndex == 1 or self.pageIndex * (self.height - self.cutRow) < #self.buttons - 4 then
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
    if not physics_flag then
        self.window.setCursorPos(1, 2)
        self.window.blit("*", properties.select, properties.bg)
    end
    if self.row == 1 and self.pageIndex == 1 then
        self.window.setCursorPos(self.width / 2 - 5, 2)
        if engineOff then
            self.window.blit("engine_OFF", genStr(properties.other, 10), genStr(properties.bg, 10))
        else
            self.window.blit("engine_ON ", genStr(properties.other, 10), genStr(properties.bg, 10))
        end
    end
end

function modPage:onTouch(x, y)
    self:nextPage(x, y)
    if y == 2 then
        if self.row == 1 and self.pageIndex == 1 then
            if y == 2 and x >= self.width / 2 - 5 and x <= self.width / 2 + 5 then
                engineOff = not engineOff
            end
        elseif self.pageIndex > 1 then
            self.pageIndex = self.pageIndex - 1
        end
    elseif y == self.height - 1 then
        if x >= self.buttons[2].x and x < self.buttons[3].x + 3 then
            system.updatePersistentData()
            if x > 5 then
                os.reboot()
            else
                shutdown_flag = true
                monitorUtil.onSystemSleep()
            end
        elseif x > self.buttons[4].x then
            monitorUtil.disconnect(self.name)
        end
    elseif y < self.height - 2 and y > 2 then
        for k, v in pairs(self.buttons) do
            if v.y > 1 then
                if x >= v.x and x < v.x + #v.text + 2 and y == v.y - (self.pageIndex - 1) * (self.height - self.cutRow) then
                    if v.modeId then
                        if properties.mode == v.modeId then
                            if v.modeId < 5 then
                                attUtil.setLastPos()
                                properties.lock = not properties.lock
                            end
                        else
                            if v.modeId < 9 or v.modeId >= 12 then
                                properties.mode = v.modeId
                            elseif parentShip.id ~= -1 then
                                properties.mode = v.modeId
                            end
                        end
                    end
                end
            end
        end
    elseif y == self.otherButtons[1].y then
        if #self.buttons - 1 > self.pageIndex * (self.height - self.cutRow) then
            self.pageIndex = self.pageIndex + 1
        else
            self.pageIndex = 1
        end
    end
end

--winIndex = 2
function attPage:init()
end

function attPage:refresh()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
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
                self.window.blit("-<", select .. font, genStr(bg, 2))
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
            if mod == "spaceShip" then
                if joyUtil.LeftJoyClick then
                    self.window.setCursorPos(x - 3, y)
                    self.window.blit("!BURNING!", "fffffffff", "eeeeeeeee")
                else
                    self.window.setCursorPos(x - 2, y - 1)
                    if properties.coupled then
                        self.window.blit("Coupled", genStr(bg, 7), genStr(select, 7))
                    else
                        self.window.blit("Coupled", genStr(font, 7), genStr(bg, 7))
                    end
                end
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
            if properties.lock then
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
        else
            if mod == "spaceShip" or mod == "quadFPV" then
                if mod == "spaceShip" then
                    self.window.setCursorPos(math.floor(self.width / 2) + 1, math.floor(self.height / 2))
                    if properties.coupled then
                        self.window.blit("C", bg, select)
                    else
                        self.window.blit("C", font, bg)
                    end
                end
                self.window.setCursorPos(math.floor(self.width / 2), math.floor(self.height / 2) + 2)
                local str = string.format("%3d", attUtil.speed)
                self.window.blit(str, genStr(font, 3), genStr(bg, 3))
                self.window.setCursorPos(math.floor(self.width / 2), math.floor(self.height / 2) + 3)
                self.window.blit("m/s", genStr(other, 3), genStr(bg, 3))
            end
        end
    else
        if mod == "spaceShip" or mod == "quadFPV" then
            if mod == "spaceShip" then
                self.window.setCursorPos(math.floor(self.width / 2) + 1, math.floor(self.height / 2))
                if properties.coupled then
                    self.window.blit("C", bg, select)
                else
                    self.window.blit("C", font, bg)
                end
            end
            self.window.setCursorPos(math.floor(self.width / 2), math.floor(self.height / 2) + 2)
            local str = string.format("%3d", attUtil.speed)
            self.window.blit(str, genStr(font, 3), genStr(bg, 3))
            self.window.setCursorPos(math.floor(self.width / 2), math.floor(self.height / 2) + 3)
            self.window.blit("m/s", genStr(other, 3), genStr(bg, 3))
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
    if info ~= -1 then
        if info.maxColumn > 1 then
            local bx, by = width / 2 - xPos, height / 2 - yPos
            if yPos > 1 then y = y - 1 end
            if y == by + 2 and x >= bx - 2 and x <= bx + 10 then
                local index
                if mod == "spaceShip" then
                    index = 6
                elseif mod == "quadFPV" then
                    index = 7
                elseif mod == "helicopter" then
                    index = 8
                elseif mod == "airShip" then
                    index = 9
                end
                if index then
                    self.windows[self.row][self.column][index].indexFlag = 2
                    properties.winIndex[self.name][self.row][self.column] = index
                end
            elseif y == by + 3 and x >= bx - 2 and x <= bx + 10 then
                attUtil.setLastPos()
                properties.lock = not properties.lock
            elseif y == by - 1 and x >= bx - 2 and x <= bx + 9 then
                properties.coupled = not properties.coupled
            end
        else
            if mod == "spaceShip" then
                if y == math.floor(self.height / 2) and x == math.floor(self.width / 2) + 1 then
                    properties.coupled = not properties.coupled
                end
            end
        end
    else
        if mod == "spaceShip" then
            if y == math.floor(self.height / 2) and x == math.floor(self.width / 2) + 1 then
                properties.coupled = not properties.coupled
            end
        end
    end
end

--winIndex = 3
function shipNetPage:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.buttons = {
        { text = "<  SHIPNET  >", x = self.width / 2 - 5, y = 1,               blitF = genStr(title, 13), blitB = genStr(bg, 13) },
        { text = "set",           x = 2,                  y = self.height - 1, blitF = genStr(bg, 3),     blitB = genStr(select, 3) },
        { text = "connect",       x = self.width - 7,     y = self.height - 1, blitF = genStr(bg, 7),     blitB = genStr(select, 7) },
    }
    self.otherButtons = {
        { text = "      v      ", x = 2, y = self.height - 2, blitF = genStr(bg, 13), blitB = genStr(other, 13) },
        { text = "      ^      ", x = 2, y = 2,               blitF = genStr(bg, 13), blitB = genStr(other, 13) },
    }
    self.callBlink = 10
    self.callInBlink = 10
    self.pageIndex = 1
end

function shipNetPage:refresh()
    self.window.setBackgroundColor(getColorDec(properties.bg))
    self.window.clear()
    self.window.setCursorPos(1, 1)
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    local info = page_attach_manager:get(self.name, self.pageName, self.row, self.column)
    local width, height, xPos, yPos
    if info ~= -1 then --页面拼接
        width = info.maxColumn * self.width
        height = info.maxRow * self.height
        xPos = (info.column - 1) * self.width + 1
        yPos = (info.row - 1) * self.height
        if info.row == 1 then yPos = yPos + 1 end
    else
        width, height, xPos, yPos = self.width, self.height, 1, 1
    end

    local sp, ep = 1, #self.buttons
    if info ~= -1 then --页面拼接时把下面两个分项按钮移到底部
        if info.maxRow > 1 and yPos > 1 then
            sp = 2
        elseif info.maxRow > 1 and yPos == 1 then
            sp, ep = 1, 1
        end
    end

    if #callList > 0 then --收到连接请求
        if self.callInBlink % 2 == 0 then
            self.buttons[3].blitF = genStr(select, 7)
            self.buttons[3].blitB = genStr(bg, 7)
        else
            self.buttons[3].blitF = genStr(bg, 7)
            self.buttons[3].blitB = genStr(select, 7)
        end
        self.callInBlink = self.callInBlink - 0.5 > 0 and self.callInBlink - 0.5 or 10
    else
        self.buttons[3].blitF = genStr(bg, 7)
        self.buttons[3].blitB = genStr(select, 7)
    end

    for i = sp, ep, 1 do
        local x, y = self.buttons[i].x, self.buttons[i].y
        if i > 1 then y = height - yPos end
        if yPos > 1 then y = y - 1 end
        self.window.setCursorPos(x, y)
        self.window.blit(self.buttons[i].text, self.buttons[i].blitF, self.buttons[i].blitB)
    end


    if #shipNet_list > height - 5 then --如果超过一页, 显示翻页键
        local x, y = (self.width - #self.otherButtons[1].text) / 2 + 1, height - yPos - 1
        if yPos > 1 then y = y - 1 end
        self.window.setCursorPos(x, y)
        self.window.blit(self.otherButtons[1].text, self.otherButtons[1].blitF, self.otherButtons[1].blitB)
        if self.pageIndex > 1 then
            self.window.setCursorPos(x, 2)
            self.window.blit(self.otherButtons[2].text, self.otherButtons[2].blitF, self.otherButtons[2].blitB)
        end
    end

    ---------连接中的船区分颜色---------
    local listLen = height - 5
    local index = #shipNet_list > height - 5 and listLen * (self.pageIndex - 1) + 2 - yPos or 2 - yPos --融合窗口中每页从第几个开始打印)
    local count = 1
    for i = index, index + listLen - 1, 1 do
        if not shipNet_list[i] then break end
        local s, id = shipNet_list[i].name, shipNet_list[i].id
        if #s > self.width - 2 then
            s = string.sub(s, 1, self.width - 2)
        end
        local x, y = 2, 2 + count
        count = count + 1
        if y > 2 then
            self.window.setCursorPos(x, y)
            local flagF, flagBg = font, bg

            if id == calling then --如果正在呼叫对方
                if self.callBlink % 2 == 0 then
                    flagF, flagBg = "f", select
                else
                    flagF, flagBg = select, bg
                end
                self.callBlink = self.callBlink - 0.25 > 0 and self.callBlink - 0.25 or 10
            elseif id == parentShip.id then --如果是父级飞船
                flagF, flagBg = bg, "d"
            else
                for k, v in pairs(childShips) do --如果是子级飞船
                    if table.contains(v, id) then
                        flagF, flagBg = bg, "b"
                        break
                    end
                end
            end

            self.window.blit(s, genStr(flagF, #s), genStr(flagBg, #s))
        end
    end
end

function shipNetPage:onTouch(x, y)
    local info = page_attach_manager:get(self.name, self.pageName, self.row, self.column)
    local width, height, xPos, yPos, maxRow
    if info ~= -1 then
        width = info.maxColumn * self.width
        height = info.maxRow * self.height
        xPos = (info.column - 1) * self.width + 1
        yPos = (info.row - 1) * self.height
        maxRow = info.maxRow
        if info.row == 1 then
            yPos = yPos + 1
            self:nextPage(x, y)
        end
    else
        width, height, xPos, yPos, maxRow = self.width, self.height, 1, 1, 1
        self:nextPage(x, y)
    end

    if x >= 2 and x <= self.width - 1 then
        local listLen = height - 5
        if #shipNet_list > listLen then --翻页键
            local maxPage = math.ceil(#shipNet_list / listLen)
            if y == 2 then
                self.pageIndex = self.pageIndex - 1
                self.pageIndex = self.pageIndex < 1 and maxPage or self.pageIndex
            elseif y == self.height - 2 then
                self.pageIndex = self.pageIndex + 1
                self.pageIndex = self.pageIndex > maxPage and 1 or self.pageIndex
            end
        end

        if self.row == maxRow or info == -1 then
            if y == self.height - 1 then
                if x >= 2 and x <= 2 + 3 then
                    properties.winIndex[self.name][self.row][self.column] = 16
                elseif x >= self.width - 7 then
                    properties.winIndex[self.name][self.row][self.column] = 17
                end
            end
        end

        if (self.pageIndex == 1 and (y > 2)) or (self.pageIndex > 1 and y > 1 and y < self.height - 2) then
            local index = #shipNet_list > listLen and listLen * (self.pageIndex - 1) + 2 - yPos or
                2 -
                yPos --融合窗口中每页从第几个开始打印
            index = y - 3 + index
            if shipNet_list[index] then
                shipNet_p2p_send(shipNet_list[index].id, "call")
            end
        end
    end
end

--winIndex = 16
function shipNet_set_Page:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.indexFlag = 3
    self.buttons = {
        { text = "<",             x = 1, y = 1, blitF = title,            blitB = bg },
        { text = "set_camera",    x = 2, y = 3, blitF = genStr(font, 10), blitB = genStr(bg, 10), select = genStr(select, 10), flag = false },
        { text = "set_follow",    x = 2, y = 4, blitF = genStr(font, 10), blitB = genStr(bg, 10), select = genStr(select, 10), flag = false },
        { text = "set_anchorage", x = 2, y = 5, blitF = genStr(font, 13), blitB = genStr(bg, 13), select = genStr(select, 13), flag = false },
    }
end

function shipNet_set_Page:refresh()
    self:refreshButtons()
    self:refreshTitle()
    for k, v in pairs(self.buttons) do
        if v.flag then
            self.window.setCursorPos(v.x, v.y)
            self.window.blit(v.text, v.blitB, v.select)
        end
    end
end

function shipNet_set_Page:onTouch(x, y)
    self:subPage_Back(x, y)
    if x > 2 and y > 1 and y <= #self.buttons + 1 then
        for k, v in pairs(self.buttons) do
            if y == v.y and x >= v.x and x <= v.x + #v.text then
                if v.flag then
                    if v.text == "set_camera" then
                        properties.winIndex[self.name][self.row][self.column] = 18
                    elseif v.text == "set_follow" then
                        properties.winIndex[self.name][self.row][self.column] = 19
                    elseif v.text == "set_anchorage" then
                        properties.winIndex[self.name][self.row][self.column] = 20
                    end
                else
                    v.flag = true
                end
            else
                v.flag = false
            end
        end
    end
end

--winIndex = 17
function shipNet_connect_Page:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.indexFlag = 3
    self.buttons = {
        { text = "<", x = 1, y = 1, blitF = title, blitB = bg },
    }
    self.otherButtons = {
        { text = "      v      ", x = 2, y = self.height - 2, blitF = genStr(bg, 13), blitB = genStr(other, 13) },
        { text = "      ^      ", x = 2, y = 2,               blitF = genStr(bg, 13), blitB = genStr(other, 13) },
    }
    self.maxList = self.height - 3
    self.pageIndex = 1
end

function shipNet_connect_Page:refresh()
    self:refreshButtons()
    self:refreshTitle()
    local list = {}
    if parentShip.id ~= -1 then
        table.insert(list, parentShip)
    end

    for k, v in pairs(childShips) do
        table.insert(list, v)
    end

    if #list > self.maxList then
        self.window.setCursorPos(2, self.height - 1)
        self.window.blit(self.otherButtons[2].text, self.otherButtons[2].blitF, self.otherButtons[2].blitB)
        if self.pageIndex == 1 then
            self.window.setCursorPos(2, 2)
            self.window.blit(self.otherButtons[1].text, self.otherButtons[1].blitF, self.otherButtons[1].blitB)
        end
    end

    for i = 1, self.maxList, 1 do
        local index = (self.pageIndex - 1) * self.maxList + i
        if not list[index] then
            break
        end
        local str = list[index].name
        if #str > self.width - 3 then
            str = string.sub(str, 1, self.width - 4)
        end
        str = str .. " x"
        self.window.setCursorPos(2, 2 + i)
        if list[index].id == parentShip.id and i == 1 then
            self.window.blit(str, genStr(properties.bg, #str - 1) .. properties.font,
                genStr("d", #str - 2) .. genStr(properties.bg, 2))
        else
            self.window.blit(str, genStr(properties.bg, #str - 1) .. properties.font,
                genStr("b", #str - 2) .. genStr(properties.bg, 2))
        end
    end

    if #callList > 0 then --收到请求弹窗
        local str = callList[1].name
        local halfWidth = self.width / 2
        local halfHeight = self.height / 2
        if #str < self.width then
            str = genStr(" ", halfWidth - math.floor(#str / 2 + 0.5)) ..
                str .. genStr(" ", halfWidth + math.floor(#str / 2 + 0.5))
        end
        self.window.setCursorPos(1, halfHeight - 1)
        self.window.blit(str, genStr(properties.bg, #str), genStr(properties.other, #str))
        local str2 = "connect? " .. callList[1].ct
        if #str2 < self.width then
            str2 = genStr(" ", halfWidth - math.floor(#str2 / 2 + 0.5)) ..
                str2 .. genStr(" ", halfWidth + math.floor(#str2 / 2 + 0.5))
        end
        self.window.setCursorPos(1, halfHeight)
        self.window.blit(str2, genStr(properties.bg, #str2), genStr(properties.other, #str2))
        self.window.setCursorPos(halfWidth - 4, halfHeight + 2)
        self.window.blit("yes", genStr(properties.bg, 3), genStr(properties.select, 3))
        self.window.setCursorPos(halfWidth + 4, halfHeight + 2)
        self.window.blit("no", genStr(properties.bg, 2), genStr(properties.select, 2))
    end
end

function shipNet_connect_Page:onTouch(x, y)
    self:subPage_Back(x, y)
    if parentShip.id ~= -1 then
        self.window.setCursorPos(2, 3)
    end

    if #callList > 0 then --收到请求弹窗
        local halfWidth = self.width / 2
        local halfHeight = self.height / 2
        if y == halfHeight + 2 then
            if x >= halfWidth - 4 and x < halfWidth - 1 then
                shipNet_p2p_send(callList[1].id, "agree")
                local newChild = callList[1]
                newChild.beat = beat_ct
                table.insert(childShips, newChild)
                table.remove(callList, 1)
            elseif x >= halfWidth + 4 and x <= halfWidth + 6 then
                shipNet_p2p_send(callList[1].id, "refuse")
                table.remove(callList, 1)
            end
        end
    else
        local list = {}
        if parentShip.id ~= -1 then
            table.insert(list, parentShip)
        end

        for k, v in pairs(childShips) do
            table.insert(list, v)
        end
        if #list > self.maxList then
            local maxPage = math.ceil(#list / self.maxList)
            if self.pageIndex < maxPage then
                if y == self.height - 1 and x > 1 then
                    self.pageIndex = self.pageIndex + 1 > maxPage and 1 or self.pageIndex + 1
                end
            end
            if self.pageIndex > 1 then
                if y == 2 and x > 1 then
                    self.pageIndex = self.pageIndex - 1 > 1 and maxPage or self.pageIndex - 1
                end
            end
        end

        for i = 1, self.maxList, 1 do
            local index = (self.pageIndex - 1) * self.maxList + i
            if not list[index] then
                break
            end
            local str = list[index].name
            if #str > self.width - 3 then
                str = string.sub(str, 1, self.width - 4)
            end
            str = str .. " x"
            if y == 2 + i and x >= #str - 1 and x <= #str + 1 then
                local i2 = i
                if parentShip.id ~= -1 then
                    if i == 1 then
                        parentShip.id = -1
                        break
                    end
                    i2 = i2 - 1
                end
                table.remove(childShips, i2)
                break
            end
        end
    end
end

--winIndex = 18
function set_camera:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.indexFlag = 16
    self.buttons = {
        { text = "<",              x = 1, y = 1, blitF = title,                      blitB = bg },
        { text = "rotSpeed -   +", x = 2, y = 3, blitF = genStr(font, 9) .. "fffff", blitB = genStr(bg, 9) .. "b" .. genStr(bg, 3) .. "e" },
        { text = "moveSpeed-   +", x = 2, y = 5, blitF = genStr(font, 9) .. "fffff", blitB = genStr(bg, 9) .. "b" .. genStr(bg, 3) .. "e" },
    }
end

function set_camera:refresh()
    self:refreshButtons()
    self:refreshTitle()
    local profile = properties.profile[properties.profileIndex]
    self.window.setCursorPos(12, self.buttons[2].y)
    self.window.blit(string.format("%0.1f", profile.camera_rot_speed), genStr(properties.font, 3),
        genStr(properties.bg, 3))
    self.window.setCursorPos(12, self.buttons[3].y)
    self.window.blit(string.format("%0.1f", profile.camera_move_speed), genStr(properties.font, 3),
        genStr(properties.bg, 3))
end

function set_camera:onTouch(x, y)
    self:subPage_Back(x, y)
    local profile = properties.profile[properties.profileIndex]
    if y == self.buttons[2].y then
        if x == 11 then
            profile.camera_rot_speed = profile.camera_rot_speed - 0.1 < 0 and 0.1 or profile.camera_rot_speed - 0.1
        elseif x == 15 then
            profile.camera_rot_speed = profile.camera_rot_speed + 0.1 > 1 and 1 or profile.camera_rot_speed + 0.1
        end
    elseif y == self.buttons[3].y then
        if x == 11 then
            profile.camera_move_speed = profile.camera_move_speed - 0.1 < 0 and 0.1 or profile.camera_move_speed - 0.1
        elseif x == 15 then
            profile.camera_move_speed = profile.camera_move_speed + 0.1 > 1 and 1 or profile.camera_move_speed + 0.1
        end
    end
end

function set_shipFollow:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.indexFlag = 16
    self.buttons = {
        { text = "<",             x = 1, y = 1, blitF = title,                       blitB = bg },
        { text = "xOffset-    +", x = 2, y = 3, blitF = genStr(font, 7) .. "ffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 4) .. "e" },
        { text = "yOffset-    +", x = 2, y = 5, blitF = genStr(font, 7) .. "ffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 4) .. "e" },
        { text = "zOffset-    +", x = 2, y = 7, blitF = genStr(font, 7) .. "ffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 4) .. "e" },
    }
end

--winIndex = 26
function set_followRange:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.indexFlag = 16
    self.buttons = {
        { text = "<",             x = 1, y = 1, blitF = title,                       blitB = bg },
        { text = "xOffset-    +", x = 2, y = 3, blitF = genStr(font, 7) .. "ffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 4) .. "e" },
        { text = "yOffset-    +", x = 2, y = 5, blitF = genStr(font, 7) .. "ffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 4) .. "e" },
        { text = "zOffset-    +", x = 2, y = 7, blitF = genStr(font, 7) .. "ffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 4) .. "e" },
    }
end
function set_followRange:refresh()
    self:refreshButtons()
    self:refreshTitle()
    local sp = split(
        string.format("%d, %d, %d", properties.followRange.x, properties.followRange.y,
            properties.followRange.z), ", ")
    local sX, sY, sZ = sp[1], sp[2], sp[3]
    self.window.setCursorPos(11, self.buttons[2].y)
    self.window.blit(string.format("%d", sX), genStr(properties.font, #sX), genStr(properties.bg, #sX))
    self.window.setCursorPos(11, self.buttons[3].y)
    self.window.blit(string.format("%d", sY), genStr(properties.font, #sY), genStr(properties.bg, #sY))
    self.window.setCursorPos(11, self.buttons[4].y)
    self.window.blit(string.format("%d", sZ), genStr(properties.font, #sZ), genStr(properties.bg, #sZ))
end

function set_followRange:onTouch(x, y)
    self:subPage_Back(x, y)
    if y >= self.buttons[2].y and y <= self.buttons[4].y then
        local result = 0
        if x == 9 then
            result = -1
        elseif x == 14 then
            result = 1
        end
        if y == self.buttons[2].y then
            properties.followRange.x = properties.followRange.x + result
        elseif y == self.buttons[3].y then
            properties.followRange.y = properties.followRange.y + result
        elseif y == self.buttons[4].y then
            properties.followRange.z = properties.followRange.z + result
        end
    end
end

--winIndex = 19
function set_shipFollow:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.indexFlag = 16
    self.buttons = {
        { text = "<",             x = 1, y = 1, blitF = title,                       blitB = bg },
        { text = "xOffset-    +", x = 2, y = 3, blitF = genStr(font, 7) .. "ffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 4) .. "e" },
        { text = "yOffset-    +", x = 2, y = 5, blitF = genStr(font, 7) .. "ffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 4) .. "e" },
        { text = "zOffset-    +", x = 2, y = 7, blitF = genStr(font, 7) .. "ffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 4) .. "e" },
    }
end

function set_shipFollow:refresh()
    self:refreshButtons()
    self:refreshTitle()
    local sp = split(
        string.format("%d, %d, %d", properties.shipFollow_offset.x, properties.shipFollow_offset.y,
            properties.shipFollow_offset.z), ", ")
    local sX, sY, sZ = sp[1], sp[2], sp[3]
    self.window.setCursorPos(11, self.buttons[2].y)
    self.window.blit(string.format("%d", sX), genStr(properties.font, #sX), genStr(properties.bg, #sX))
    self.window.setCursorPos(11, self.buttons[3].y)
    self.window.blit(string.format("%d", sY), genStr(properties.font, #sY), genStr(properties.bg, #sY))
    self.window.setCursorPos(11, self.buttons[4].y)
    self.window.blit(string.format("%d", sZ), genStr(properties.font, #sZ), genStr(properties.bg, #sZ))
end

function set_shipFollow:onTouch(x, y)
    self:subPage_Back(x, y)
    if y >= self.buttons[2].y and y <= self.buttons[4].y then
        local result = 0
        if x == 9 then
            result = -1
        elseif x == 14 then
            result = 1
        end
        if y == self.buttons[2].y then
            properties.shipFollow_offset.x = properties.shipFollow_offset.x + result
        elseif y == self.buttons[3].y then
            properties.shipFollow_offset.y = properties.shipFollow_offset.y + result
        elseif y == self.buttons[4].y then
            properties.shipFollow_offset.z = properties.shipFollow_offset.z + result
        end
    end
end

--winIndex = 20
function set_anchorage:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.indexFlag = 16
    self.buttons = {
        { text = "<",             x = 1, y = 1, blitF = title,                       blitB = bg },
        { text = "xOffset-    +", x = 2, y = 3, blitF = genStr(font, 7) .. "ffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 4) .. "e" },
        { text = "yOffset-    +", x = 2, y = 4, blitF = genStr(font, 7) .. "ffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 4) .. "e" },
        { text = "zOffset-    +", x = 2, y = 5, blitF = genStr(font, 7) .. "ffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 4) .. "e" },
        { text = "entry:",        x = 2, y = 7, blitF = genStr(font, 6),             blitB = genStr(bg, 6) },
        { text = "<         >",   x = 3, y = 8, blitF = genStr(font, 11),            blitB = genStr(bg, 11) },
    }
end

function set_anchorage:refresh()
    self:refreshButtons()
    self:refreshTitle()
    local tmpX = string.format("%d", properties.anchorage_offset.x)
    self.window.setCursorPos(11, self.buttons[2].y)
    self.window.blit(tmpX, genStr(properties.font, #tmpX), genStr(properties.bg, #tmpX))
    local tmpY = string.format("%d", properties.anchorage_offset.y)
    self.window.setCursorPos(11, self.buttons[3].y)
    self.window.blit(tmpY, genStr(properties.font, #tmpY), genStr(properties.bg, #tmpY))
    local tmpZ = string.format("%d", properties.anchorage_offset.z)
    self.window.setCursorPos(11, self.buttons[4].y)
    self.window.blit(tmpZ, genStr(properties.font, #tmpZ), genStr(properties.bg, #tmpZ))

    local ent = entryList[properties.anchorage_entry]
    self.window.setCursorPos(6, self.buttons[6].y)
    self.window.blit(ent, genStr(properties.font, #ent), genStr(properties.bg, #ent))
end

function set_anchorage:onTouch(x, y)
    self:subPage_Back(x, y)
    if y >= self.buttons[2].y and y <= self.buttons[4].y then
        local result = 0
        if x == 9 then
            result = -1
        elseif x == 14 then
            result = 1
        end
        if y == self.buttons[2].y then
            properties.anchorage_offset.x = properties.anchorage_offset.x + result
        elseif y == self.buttons[3].y then
            properties.anchorage_offset.y = properties.anchorage_offset.y + result
        elseif y == self.buttons[4].y then
            properties.anchorage_offset.z = properties.anchorage_offset.z + result
        end
    elseif y == self.buttons[6].y then
        local result = 0
        if x == 3 then
            result = -1
        elseif x == 13 then
            result = 1
        end
        properties.anchorage_entry = properties.anchorage_entry + result
        properties.anchorage_entry = properties.anchorage_entry > #entryList and 1 or properties.anchorage_entry
        properties.anchorage_entry = properties.anchorage_entry < 1 and #entryList or properties.anchorage_entry
    end
end

--winIndex = 4
function raderPage:init()
end

function raderPage:refresh()
    self.window.setBackgroundColor(colors.black)
    self.window.clear()
    self.window.setCursorPos(1, 1)
    local info = page_attach_manager:get(self.name, self.pageName, self.row, self.column)
    local width, height, xPos, yPos
    if info ~= -1 then
        width = info.maxColumn * self.width
        height = info.maxRow * self.height
        xPos = (info.column - 1) * self.width + 1
        yPos = (info.row - 1) * self.height
    else
        width, height, xPos, yPos = self.width, self.height, 1, 1
    end

    local pixelDistance = 1 * (2 ^ properties.raderRange) / 2

    for i = 1, width, 1 do
        local xi = (i + 1) - xPos
        if xi <= self.width and xi > 0 then
            self.window.setCursorPos(xi, height / 2 - yPos)
            self.window.blit("-", "8", "f")
        end
    end

    for i = 1, height, 1 do
        local yi = (i + 1) - yPos
        if yi <= self.height and yi > 0 then
            self.window.setCursorPos(width / 2 + 2 - xPos, yi)
            self.window.blit("|", "8", "f")
        end
    end

    local range = string.format("pix=%4d block", pixelDistance)
    self.window.setCursorPos((width + 4 - 14) / 2 - xPos, height + 1 - yPos)
    if info ~= -1 then
        if self.row == info.maxRow then
            self.window.setCursorPos((width + 4 - 14) / 2 - xPos, height - yPos)
        end
    end
    self.window.blit(range, genStr(properties.bg, 14), genStr(properties.other, #range))

    for i = 1, #shipNet_list, 1 do
        local ship = shipNet_list[i]
        local x, z = (ship.pos.x - attUtil.position.x) / pixelDistance, (ship.pos.z - attUtil.position.z) / pixelDistance
        local tx, tz = math.abs(x), math.abs(z)
        if (tx > 0 and tx <= width + 1) and (tz > 0 and tz <= height - 1) then
            local point = MatrixMultiplication(attUtil.yawMatrix, { x = x, y = z })
            point.y = point.y / 1.5
            point = { x = width / 2 + 2 + point.x - xPos, y = height / 2 - point.y - yPos }
            local bounds = {
                x = point.x - (ship.size.x / 2) / pixelDistance,
                y = point.y -
                    (ship.size.z / 2) / pixelDistance
            }
            bounds.xStart = point.x - bounds.x
            bounds.xEnd = point.x + bounds.x
            bounds.yStart = point.y - bounds.y
            bounds.yEnd = point.y + bounds.y
            if point.x <= self.width + 1 and point.y <= self.height + 1 then
                self.window.setCursorPos(point.x, point.y)
                if ship.id == parentShip.id then
                    self.window.blit(" ", " ", "5")
                else
                    local bgg = "8"
                    for k, v in pairs(childShips) do
                        if v.id == ship.id then
                            bgg = "b"
                            break
                        end
                    end

                    self.window.blit(" ", " ", bgg)
                end
            end
        end
    end
end

function raderPage:onTouch(x, y)
    self:nextPage(x, y)
    local info = page_attach_manager:get(self.name, self.pageName, self.row, self.column)
    local width, height, xPos, yPos
    if info ~= -1 then
        width = info.maxColumn * self.width
        height = info.maxRow * self.height
        xPos = (info.column - 1) * self.width + 1
        yPos = (info.row - 1) * self.height
    else
        width, height, xPos, yPos = self.width, self.height, 1, 1
    end

    local tx, ty = (width + 4 - 14) / 2 - xPos, height + 1 - yPos
    if info ~= -1 then
        if self.row == info.maxRow then
            tx, ty = (width + 4 - 14) / 2 - xPos, height - yPos
        end
    end

    if y == ty then
        if x >= tx and x < tx + 7 then
            properties.raderRange = properties.raderRange - 1 < 1 and 1 or properties.raderRange - 1
        elseif x > tx + 7 and x < tx + 14 then
            properties.raderRange = properties.raderRange + 1 > 14 and 14 or properties.raderRange + 1
        end
    end
end

--winIndex = 5
function setPage:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.buttons = {
        { text = "<    SET    >", x = self.width / 2 - 5, y = 1,       blitF = genStr(title, 13), blitB = genStr(bg, 13) },
        { text = "S_SpaceShip",   x = 2,                  pageId = 6,  y = 3,                     blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "S_QuadFPV  ",   x = 2,                  pageId = 7,  y = 4,                     blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "S_FixedWing",   x = 2,                  pageId = 25, y = 5,                     blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "S_Helicopt ",   x = 2,                  pageId = 8,  y = 6,                     blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "S_airShip  ",   x = 2,                  pageId = 9,  y = 7,                     blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "User_Change",   x = 2,                  pageId = 10, y = 8,                     blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "Home_Set   ",   x = 2,                  pageId = 11, y = 9,                     blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "FollowRange",   x = 2,                  pageId = 26, y = 10,                    blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "Simulate   ",   x = 2,                  pageId = 12, y = 11,                    blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "Set_Att    ",   x = 2,                  pageId = 13, y = 12,                    blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "Profile    ",   x = 2,                  pageId = 14, y = 13,                    blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "Colortheme ",   x = 2,                  pageId = 15, y = 14,                    blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "MassFix",       x = 2,                  pageId = 21, y = 15,                    blitF = genStr(font, 7),  blitB = genStr(bg, 7),  select = genStr(select, 7),  selected = false, flag = false }
    }
    self.otherButtons = {
        { text = "      v      ", x = 2, y = self.height - 1, blitF = genStr(bg, 13), blitB = genStr(other, 13) },
        { text = "      ^      ", x = 2, y = 2,               blitF = genStr(bg, 13), blitB = genStr(other, 13) },
    }
    self.pageIndex = 1
    self.cutRow = 4
end

function setPage:refresh()
    self:refreshButtons(1, self.pageIndex, self.cutRow)
    if #self.buttons > self.height - self.cutRow then
        if self.pageIndex == 1 or self.pageIndex * (self.height - self.cutRow) < #self.buttons - 1 then
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
            local yPos = v.y - (self.pageIndex - 1) * (self.height - self.cutRow)
            if yPos > 2 and yPos < self.height - 1 then
                self.window.setCursorPos(v.x, v.y - (self.pageIndex - 1) * (self.height - self.cutRow))
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
                        self.windows[self.row][self.column][v.pageId].indexFlag = 5
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

--winIndex = 6
function set_spaceShip:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.indexFlag = 5
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
        self.windows[self.row][self.column][14].indexFlag = 6
        properties.winIndex[self.name][self.row][self.column] = 14
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

--winIndex = 7
function set_quadFPV:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.indexFlag = 5
    self.buttons = {
        { text = "<",             x = 1, y = 1, blitF = title,                       blitB = bg },
        { text = "Rate_Roll >",   x = 2, y = 3, blitF = genStr(font, 11),            blitB = genStr(bg, 11),                              select = genStr(select, 11), selected = false, flag = false },
        { text = "Rate_Yaw  >",   x = 2, y = 4, blitF = genStr(font, 11),            blitB = genStr(bg, 11),                              select = genStr(select, 11), selected = false, flag = false },
        { text = "Rate_Pitch>",   x = 2, y = 5, blitF = genStr(font, 11),            blitB = genStr(bg, 11),                              select = genStr(select, 11), selected = false, flag = false },

        { text = "Throttle:",     x = 2, y = 6, blitF = genStr(other, 9),            blitB = genStr(bg, 9) },
        { text = "max_val-    +", x = 2, y = 7, blitF = genStr(font, 7) .. "ffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 4) .. "e" },
        { text = "mid    -    +", x = 2, y = 8, blitF = genStr(font, 7) .. "ffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 4) .. "e" },
        { text = "expo   -    +", x = 2, y = 9, blitF = genStr(font, 7) .. "ffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 4) .. "e" },
    }
end

function set_quadFPV:refresh()
    self:refreshButtons()
    self:refreshTitle()
    local profile = properties.profile[properties.profileIndex]
    self.window.setCursorPos(1, 2)
    self.window.blit(("profile:%s"):format(properties.profileIndex), genStr(properties.other, 16),
        genStr(properties.bg, 16))

    for k, v in pairs(self.buttons) do
        if v.selected then
            self.window.setCursorPos(v.x, v.y)
            self.window.blit(v.text, v.blitB, v.select)
        end
    end

    self.window.setTextColor(getColorDec(properties.font))
    self.window.setCursorPos(10, 7)
    self.window.write(string.format("%0.2f", profile.max_throttle))
    self.window.setCursorPos(10, 8)
    self.window.write(string.format("%0.2f", profile.throttle_mid))
    self.window.setCursorPos(10, 9)
    self.window.write(string.format("%0.2f", profile.throttle_expo))
end

function set_quadFPV:onTouch(x, y)
    self:subPage_Back(x, y)
    if y == 2 then
        self.windows[self.row][self.column][14].indexFlag = 7
        properties.winIndex[self.name][self.row][self.column] = 14
    end
    if x > 2 and y > 2 then
        local profile = properties.profile[properties.profileIndex]
        local result = 0
        if y > 6 and y < 10 then
            if x == 9 then result = -0.01 end
            if x == 14 then result = 0.01 end
            if y == 7 then
                profile.max_throttle = profile.max_throttle + result
                profile.max_throttle = profile.max_throttle < 0 and 0 or
                    (profile.max_throttle > 9 and 9 or profile.max_throttle)
            elseif y == 8 then
                profile.throttle_mid = profile.throttle_mid + result
                profile.throttle_mid = profile.throttle_mid < 0 and 0 or
                    (profile.throttle_mid > 1 and 1 or profile.throttle_mid)
            elseif y == 9 then
                profile.throttle_expo = profile.throttle_expo + result
                profile.throttle_expo = profile.throttle_expo < 0 and 0 or
                    (profile.throttle_expo > 1 and 1 or profile.throttle_expo)
            end
        end
    end
    for k, v in pairs(self.buttons) do
        if v.selected ~= nil then
            if x >= v.x and x < v.x + #v.text and y == v.y then
                if not v.selected then
                    v.selected = true
                else
                    if v.text == "Rate_Roll >" then
                        self.windows[self.row][self.column][22].indexFlag = 7
                        properties.winIndex[self.name][self.row][self.column] = 22
                    elseif v.text == "Rate_Yaw  >" then
                        self.windows[self.row][self.column][23].indexFlag = 7
                        properties.winIndex[self.name][self.row][self.column] = 23
                    elseif v.text == "Rate_Pitch>" then
                        self.windows[self.row][self.column][24].indexFlag = 7
                        properties.winIndex[self.name][self.row][self.column] = 24
                    end
                end
            else
                v.selected = false
            end
        end
    end
end

--winIndex = 25
function set_fixedWing:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.indexFlag = 5
    self.buttons = {
        { text = "< wingOffset",   x = 1, y = 2, blitF = genStr(title, 12),             blitB = genStr(bg, 12) },
        { text = "Wing:-   +",     x = 1, y = 3, blitF = genStr(font, 5) .. "fffff",    blitB = genStr(bg, 5) .. "b" .. "fff" .. "e" },
        { text = "wSize:--    ++", x = 1, y = 4, blitF = genStr(font, 6) .. "ffffffff", blitB = genStr(bg, 6) .. "b5" .. "ffff" .. "1e" },
        { text = "Tail:-   +",     x = 1, y = 5, blitF = genStr(font, 5) .. "fffff",    blitB = genStr(bg, 5) .. "b" .. "fff" .. "e" },
        { text = "tSize:--    ++", x = 1, y = 6, blitF = genStr(font, 6) .. "ffffffff", blitB = genStr(bg, 6) .. "b5" .. "ffff" .. "1e" },
        { text = "vertTail:-   +", x = 1, y = 7, blitF = genStr(font, 9) .. "fffff",    blitB = genStr(bg, 9) .. "b" .. "fff" .. "e" },
        { text = "vSize:--    ++", x = 1, y = 8, blitF = genStr(font, 6) .. "ffffffff", blitB = genStr(bg, 6) .. "b5" .. "ffff" .. "1e" },
    }
end

function set_fixedWing:refresh()
    self:refreshButtons()
    self:refreshTitle()
    self.window.setCursorPos(7, 3)
    self.window.write(math.floor(properties.wing.wings.pos.x + 0.5))
    self.window.setCursorPos(9, 4)
    self.window.write(string.format("%0.2f", properties.wing.wings.size))
    self.window.setCursorPos(7, 5)
    self.window.write(math.floor(properties.wing.tail_wings.pos.x + 0.5))
    self.window.setCursorPos(9, 6)
    self.window.write(string.format("%0.2f", properties.wing.tail_wings.size))
    self.window.setCursorPos(11, 7)
    self.window.write(math.floor(properties.wing.verticalTail.pos.x + 0.5))
    self.window.setCursorPos(9, 8)
    self.window.write(string.format("%0.2f", properties.wing.verticalTail.size))
end

function set_fixedWing:onTouch(x, y)
    self:subPage_Back(x, y)
    if y == 3 or y == 5 or y == 7 then
        local result = 0
        if y < 7 then
            if x == 6 then
                result = -1
            elseif x == 10 then
                result = 1
            end
        else
            if x == 10 then
                result = -1
            elseif x == 14 then
                result = 1
            end
        end

        if y == 3 then
            properties.wing.wings.pos.x = properties.wing.wings.pos.x + result
        elseif y == 5 then
            properties.wing.tail_wings.pos.x = properties.wing.tail_wings.pos.x + result
        elseif y == 7 then
            properties.wing.verticalTail.pos.x = properties.wing.verticalTail.pos.x + result
        end
    elseif y == 4 or y == 6 or y == 8 then
        local result = 0
        if x == 7 then
            result = -0.1
        elseif x == 8 then
            result = -0.01
        elseif x == 13 then
            result = 0.01
        elseif x == 14 then
            result = 0.1
        end
        if y == 4 then
            properties.wing.wings.size = properties.wing.wings.size + result
            properties.wing.wings.size = properties.wing.wings.size < 0.01 and 0.01 or properties.wing.wings.size
        elseif y == 6 then
            properties.wing.tail_wings.size = properties.wing.tail_wings.size + result
            properties.wing.tail_wings.size = properties.wing.tail_wings.size < 0.01 and 0.01 or
                properties.wing.tail_wings.size
        elseif y == 8 then
            properties.wing.verticalTail.size = properties.wing.verticalTail.size + result
            properties.wing.verticalTail.size = properties.wing.verticalTail.size < 0.01 and 0.01 or
                properties.wing.verticalTail.size
        end
    end
end

--winIndex = 22
function rate_Roll:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.indexFlag = 7
    self.buttons = {
        { text = "<",               x = 1, y = 1, blitF = title,                       blitB = bg },
        { text = "rc_Rate-    +",   x = 2, y = 3, blitF = genStr(font, 7) .. "ffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 4) .. "e" },
        { text = "s_Rate -    +",   x = 2, y = 5, blitF = genStr(font, 7) .. "ffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 4) .. "e" },
        { text = "expo   -    +",   x = 2, y = 7, blitF = genStr(font, 7) .. "ffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 4) .. "e" },
        { text = "maxDeg:     d/s", x = 1, y = 9, blitF = genStr(font, 15),            blitB = genStr(bg, 15) },
    }
end

function rate_Roll:refresh()
    self:refreshButtons()
    self:refreshTitle()

    local profile = properties.profile[properties.profileIndex]
    self.window.setTextColor(getColorDec(properties.font))
    self.window.setCursorPos(10, 3)
    self.window.write(string.format("%0.2f", profile.roll_rc_rate))
    self.window.setCursorPos(10, 5)
    self.window.write(string.format("%0.2f", profile.roll_s_rate))
    self.window.setCursorPos(10, 7)
    self.window.write(string.format("%0.2f", profile.roll_expo))
    self.window.setCursorPos(8, 9)
    self.window.write(string.format("%d", getRate(profile.roll_rc_rate, profile.roll_s_rate, profile.roll_expo, 1.0)))
end

function rate_Roll:onTouch(x, y)
    self:subPage_Back(x, y)
    if x > 2 and y > 2 then
        local profile = properties.profile[properties.profileIndex]
        local result = 0
        if (y > 2 and y < 6) or (y > 6 and y < 10) then
            if x == 9 then result = -0.01 end
            if x == 14 then result = 0.01 end
            if y == 3 then
                profile.roll_rc_rate = profile.roll_rc_rate + result
                profile.roll_rc_rate = profile.roll_rc_rate < 0 and 0 or
                    (profile.roll_rc_rate > 2.55 and 2.55 or profile.roll_rc_rate)
            elseif y == 5 then
                profile.roll_s_rate = profile.roll_s_rate + result
                profile.roll_s_rate = profile.roll_s_rate < 0 and 0 or
                    (profile.roll_s_rate > 1 and 1 or profile.roll_s_rate)
            elseif y == 7 then
                profile.roll_expo = profile.roll_expo + result
                profile.roll_expo = profile.roll_expo < 0 and 0 or (profile.roll_expo > 1 and 1 or profile.roll_expo)
            end
        end
    end
end

--winIndex = 23
function rate_Yaw:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.indexFlag = 7
    self.buttons = {
        { text = "<",               x = 1, y = 1, blitF = title,                       blitB = bg },
        { text = "rc_Rate-    +",   x = 2, y = 3, blitF = genStr(font, 7) .. "ffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 4) .. "e" },
        { text = "s_Rate -    +",   x = 2, y = 5, blitF = genStr(font, 7) .. "ffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 4) .. "e" },
        { text = "expo   -    +",   x = 2, y = 7, blitF = genStr(font, 7) .. "ffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 4) .. "e" },
        { text = "maxDeg:     d/s", x = 1, y = 9, blitF = genStr(font, 15),            blitB = genStr(bg, 15) },
    }
end

function rate_Yaw:refresh()
    self:refreshButtons()
    self:refreshTitle()

    local profile = properties.profile[properties.profileIndex]
    self.window.setTextColor(getColorDec(properties.font))
    self.window.setCursorPos(10, 3)
    self.window.write(string.format("%0.2f", profile.yaw_rc_rate))
    self.window.setCursorPos(10, 5)
    self.window.write(string.format("%0.2f", profile.yaw_s_rate))
    self.window.setCursorPos(10, 7)
    self.window.write(string.format("%0.2f", profile.yaw_expo))
    self.window.setCursorPos(8, 9)
    self.window.write(string.format("%d", getRate(profile.yaw_rc_rate, profile.yaw_s_rate, profile.yaw_expo, 1.0)))
end

function rate_Yaw:onTouch(x, y)
    self:subPage_Back(x, y)
    if x > 2 and y > 2 then
        local profile = properties.profile[properties.profileIndex]
        local result = 0
        if (y > 2 and y < 6) or (y > 6 and y < 10) then
            if x == 9 then result = -0.01 end
            if x == 14 then result = 0.01 end
            if y == 3 then
                profile.yaw_rc_rate = profile.yaw_rc_rate + result
                profile.yaw_rc_rate = profile.yaw_rc_rate < 0 and 0 or
                    (profile.yaw_rc_rate > 2.55 and 2.55 or profile.yaw_rc_rate)
            elseif y == 5 then
                profile.yaw_s_rate = profile.yaw_s_rate + result
                profile.yaw_s_rate = profile.yaw_s_rate < 0 and 0 or
                    (profile.yaw_s_rate > 1 and 1 or profile.yaw_s_rate)
            elseif y == 7 then
                profile.yaw_expo = profile.yaw_expo + result
                profile.yaw_expo = profile.yaw_expo < 0 and 0 or (profile.yaw_expo > 1 and 1 or profile.yaw_expo)
            end
        end
    end
end

--winIndex = 24
function rate_Pitch:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.indexFlag = 7
    self.buttons = {
        { text = "<",               x = 1, y = 1, blitF = title,                       blitB = bg },
        { text = "rc_Rate-    +",   x = 2, y = 3, blitF = genStr(font, 7) .. "ffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 4) .. "e" },
        { text = "s_Rate -    +",   x = 2, y = 5, blitF = genStr(font, 7) .. "ffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 4) .. "e" },
        { text = "expo   -    +",   x = 2, y = 7, blitF = genStr(font, 7) .. "ffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 4) .. "e" },
        { text = "maxDeg:     d/s", x = 1, y = 9, blitF = genStr(font, 15),            blitB = genStr(bg, 15) },
    }
end

function rate_Pitch:refresh()
    self:refreshButtons()
    self:refreshTitle()

    local profile = properties.profile[properties.profileIndex]
    self.window.setTextColor(getColorDec(properties.font))
    self.window.setCursorPos(10, 3)
    self.window.write(string.format("%0.2f", profile.pitch_rc_rate))
    self.window.setCursorPos(10, 5)
    self.window.write(string.format("%0.2f", profile.pitch_s_rate))
    self.window.setCursorPos(10, 7)
    self.window.write(string.format("%0.2f", profile.pitch_expo))
    self.window.setCursorPos(8, 9)
    self.window.write(string.format("%d", getRate(profile.pitch_rc_rate, profile.pitch_s_rate, profile.pitch_expo, 1.0)))
end

function rate_Pitch:onTouch(x, y)
    self:subPage_Back(x, y)
    if x > 2 and y > 2 then
        local profile = properties.profile[properties.profileIndex]
        local result = 0
        if (y > 2 and y < 6) or (y > 6 and y < 10) then
            if x == 9 then result = -0.01 end
            if x == 14 then result = 0.01 end
            if y == 3 then
                profile.pitch_rc_rate = profile.pitch_rc_rate + result
                profile.pitch_rc_rate = profile.pitch_rc_rate < 0 and 0 or
                    (profile.pitch_rc_rate > 2.55 and 2.55 or profile.pitch_rc_rate)
            elseif y == 5 then
                profile.pitch_s_rate = profile.pitch_s_rate + result
                profile.pitch_s_rate = profile.pitch_s_rate < 0 and 0 or
                    (profile.pitch_s_rate > 1 and 1 or profile.pitch_s_rate)
            elseif y == 7 then
                profile.pitch_expo = profile.pitch_expo + result
                profile.pitch_expo = profile.pitch_expo < 0 and 0 or (profile.pitch_expo > 1 and 1 or profile.pitch_expo)
            end
        end
    end
end

--winIndex = 8
function set_helicopter:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.indexFlag = 5
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
        self.windows[self.row][self.column][14].indexFlag = 8
        properties.winIndex[self.name][self.row][self.column] = 14
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

--winIndex = 9
function set_airShip:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.indexFlag = 5
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
        self.windows[self.row][self.column][14].indexFlag = 9
        properties.winIndex[self.name][self.row][self.column] = 14
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

--winIndex = 10
function set_user:init()
    local bg, other, font, title = properties.bg, properties.other, properties.font, properties.title
    self.indexFlag = 5
    self.buttons = {
        { text = "<",           x = 1, y = 1, blitF = title,             blitB = bg },
        { text = "selectUser:", x = 2, y = 2, blitF = genStr(other, 11), blitB = genStr(bg, 11) },
    }
end

function set_user:refresh()
    if properties.mode ~= 5 and properties.mode ~= 6 then
        scanner.scan()
    end
    scanner.scanPlayer()
    self:refreshButtons()
    self:refreshTitle()
    local bg, font, select = properties.bg, properties.font, properties.select
    for i = 1, 7, 1 do
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

--winIndex = 11
function set_home:init()
    local bg, other, font, title = properties.bg, properties.other, properties.font, properties.title
    self.indexFlag = 5
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

--winIndex = 12
function set_simulate:init()
    local bg, other, font, title = properties.bg, properties.other, properties.font, properties.title
    self.indexFlag = 5
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
    self.window.write(string.format("%d", properties.zeroPoint))
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
            properties.zeroPoint = properties.zeroPoint == 0 and -1 or 0
        end
    end
end

--winIndex = 13
function set_att:init()
    local bg, other, font, title = properties.bg, properties.other, properties.font, properties.title
    self.indexFlag = 5
    self.buttons = {
        { text = "<", x = 1,                              y = 1,                               blitF = title, blitB = bg },
        { text = "w", x = math.floor(self.width / 2) - 5, y = math.floor(self.height / 2),     blitF = font,  blitB = bg },
        { text = "n", x = math.floor(self.width / 2),     y = math.floor(self.height / 2) - 3, blitF = font,  blitB = bg },
        { text = "e", x = math.floor(self.width / 2) + 5, y = math.floor(self.height / 2),     blitF = font,  blitB = bg },
        { text = "s", x = math.floor(self.width / 2),     y = math.floor(self.height / 2) + 3, blitF = font,  blitB = bg }
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

--winIndex = 14
function set_profile:init()
    local bg, other, font, title = properties.bg, properties.other, properties.font, properties.title
    self.indexFlag = 5
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

--winIndex = 15
function set_colortheme:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.indexFlag = 5
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

--winIndex=21
function mass_fix:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.indexFlag = 5
    self.buttons = {
        { text = "<",          x = 1, y = 1, blitF = title,            blitB = bg },
        { text = "font      ", x = 4, y = 3, blitF = genStr(font, 10), blitB = genStr(bg, 10), prt = genStr(font, 2) },
    }
    self.indexFlag = 5
end

function mass_fix:refresh()
    self:refreshButtons()
    self:refreshTitle()
end

function mass_fix:onTouch(x, y)
    self:subPage_Back(x, y)
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
                v.row = row + 1 - v.rowStart
                v.maxRow = v.rowEnd + 1 - v.rowStart
                v.column = column + 1 - v.columnStart
                v.maxColumn = v.columnEnd + 1 - v.columnStart
                return v
            end
        end
    end
    return -1
end

function abstractMonitor:page_attach_util(name)
    local pageId
    if name == "attPage" then
        pageId = 2
    elseif name == "shipNetPage" then
        pageId = 3
    elseif name == "raderPage" then
        pageId = 4
    end
    local result = {}
    page_attach_manager[self.name][name] = result
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
                    if properties.winIndex[self.name][i][j] == pageId then
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
                table.insert(result, {
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

function abstractMonitor:refresh_page_attach()
    if not page_attach_manager[self.name] then
        page_attach_manager[self.name] = {}
    end
    self:page_attach_util("attPage")
    self:page_attach_util("shipNetPage")
    self:page_attach_util("raderPage")
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
        for k, screen in pairs(monitorUtil.screens) do
            screen:refresh()
        end
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
    for n, screen in pairs(monitorUtil.screens) do
        if screen.windows then
            for i = 1, #screen.windows, 1 do
                for j = 1, #screen.windows[i], 1 do
                    local page = properties.winIndex[n][i][j]
                    if page == 2 or page == 4 or page == 3 or page == 17 then
                        screen.windows[i][j][page]:refresh()
                        --commands.execAsync(("say %s"):format(screen.windows[i][j][page].pageName))
                    end
                end
            end
        else
            screen:refresh()
        end
    end
end

monitorUtil.refreshAll = function()
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

---------broadcast---------
beat_ct, call_ct, captcha, calling = 5, 0, genCaptcha(), -1
local shipNet_beat = function() --广播
    while true do
        if not shutdown_flag then
            ---------发送广播---------
            local broadcast_msg = {
                name = shipName,
                id = computerId,
                request_connect = "broadcast",
                pos = ship.getWorldspacePosition(),
                size = ship.getSize()
            }
            rednet.broadcast(broadcast_msg, public_protocol)

            ---------公频广播心跳包---------
            local index = 1
            while true do
                if index > #shipNet_list then break end
                shipNet_list[index].beat = shipNet_list[index].beat - 1
                if shipNet_list[index].beat < 1 then
                    if shipNet_list[index].id == parentShip.id then
                        parentShip.id = -1
                    end
                    table.remove(shipNet_list, index)
                    index = index - 1
                end

                index = index + 1
            end

            ---------父级飞船心跳包---------
            if parentShip.id ~= -1 then
                parentShip.beat = parentShip.beat - 1
                if parentShip.beat <= 0 then
                    parentShip.id = -1
                end
            end

            ---------子级飞船心跳包---------
            local i2 = 1
            while true do
                if i2 > #childShips then break end
                childShips[i2].beat = childShips[i2].beat - 1
                if childShips[i2].beat <= 0 then
                    table.remove(childShips, i2)
                    i2 = i2 - 1
                end
                i2 = i2 + 1
            end

            if parentShip.id ~= -1 then --给父级发送心跳包
                shipNet_p2p_send(parentShip.id, "beat")
            end

            for k, v in pairs(childShips) do --给子级发送心跳包
                shipNet_p2p_send(v.id, "beat")
            end

            ---------呼叫计时器---------
            if call_ct > 0 then --已在呼叫中
                call_ct = call_ct - 1
            else                --未在呼叫或呼叫超时
                call_ct = 0
                calling = -1
            end

            ---------呼叫请求计时器---------
            if #callList > 0 then --未处理的呼叫请求
                for k, v in pairs(callList) do
                    v.ct = v.ct - 1
                end
                if callList[1].ct <= 0 then --未处理请求超时
                    table.remove(callList, 1)
                end
            end
        end
        sleep(1)
    end
end

local shipNet_getMessage = function() --从广播中筛选
    while true do
        if not shutdown_flag then
            local id, msg = rednet.receive(public_protocol)     --船舶信息广播

            if id == parentShip.id and msg.code == captcha then --父级飞船发来的消息
                if msg.pos then
                    parentShip = msg
                    parentShip.beat = beat_ct
                end
            end

            if msg == "beat" then
                for k, v in pairs(childShips) do
                    if id == v.id then
                        v.beat = beat_ct
                    end
                end
            end

            if type(msg) == "table" then
                if msg.request_connect == "broadcast" then --收到公频广播
                    local flag = false
                    for i = 1, #shipNet_list, 1 do
                        if table.contains(shipNet_list[i], msg.name) then
                            msg.beat = beat_ct
                            shipNet_list[i] = msg
                            flag = true
                            break
                        end
                    end
                    if not flag then
                        msg.beat = beat_ct
                        table.insert(shipNet_list, msg)
                    end
                elseif msg.request_connect == "call" and msg.name and msg.code then --收到连接请求
                    table.insert(callList, { id = id, name = msg.name, code = msg.code, ct = 10 })
                    monitorUtil.refreshAll()
                elseif msg.request_connect == "back" and msg.name and msg.code == captcha then --回听请求是否被接受
                    if msg.result == "agree" then
                        parentShip.id = id
                        parentShip.name = msg.name
                        parentShip.beat = beat_ct
                        parentShip.code = captcha
                        parentShip.pos = DEFAULT_PARENT_SHIP.pos
                        parentShip.quat = DEFAULT_PARENT_SHIP.quat
                        parentShip.preQuat = DEFAULT_PARENT_SHIP.quat
                        parentShip.velocity = DEFAULT_PARENT_SHIP.velocity
                        parentShip.anchorage = DEFAULT_PARENT_SHIP.anchorage
                    else
                        parentShip.id = -1
                    end
                    call_ct = 0
                    calling = -1
                    monitorUtil.refreshAll()
                end
            end
        else
            sleep(0.5)
        end
    end
end

local shipNet_run = function() --启动船舶网络
    parallel.waitForAll(shipNet_beat, shipNet_getMessage)
end

shipNet_p2p_send = function(id, type) --发送p2p
    if type == "call" then            --请求父级连接
        if call_ct <= 0 and id ~= parentShip.id then
            rednet.send(id, { name = shipName, code = captcha, request_connect = "call" }, public_protocol)
            calling = id
            call_ct = 10
        end
    elseif type == "agree" or type == "refuse" then --回复子级连接
        rednet.send(id, { name = shipName, code = callList[1].code, request_connect = "back", result = type },
            public_protocol)
    elseif type == "beat" then --向父级发送心跳包
        rednet.send(id, "beat", public_protocol)
    end
end

local send_to_childShips = function()
    if #childShips > 0 then
        for k, v in pairs(childShips) do
            local anchorageWorldPos = getWorldOffsetOfPcPos(properties.anchorage_offset)
            local msg = {
                id = computerId,
                name = shipName,
                pos = attUtil.position,
                quat = attUtil.quat,
                preQuat = attUtil.preQuat,
                velocity = attUtil.velocity,
                size = attUtil.size,
                anchorage = { pos = anchorageWorldPos, entry = entryList[properties.anchorage_entry] },
                code = v.code
            }
            rednet.send(v.id, msg, public_protocol)
        end
    end
end

local engineSound = function ()
    --local speaker
    --while true do
    --    if commands then
    --        --InvariantForce
    --        local val = math.abs(((RotDependentForce + InvariantForce + RotDependentTorque) * 0.1 ) / attUtil.mass) * 0.1
    --        local vo = val < 0 and 0 or val > 3 and 3 or val
    --        local pic = val < 0.5 and 0.5 or val > 1 and 1 or val
    --        local sPos = {
    --            x = attUtil.position.x + attUtil.velocity.x * 8,
    --            y = attUtil.position.y + attUtil.velocity.y * 8,
    --            z = attUtil.position.z + attUtil.velocity.z * 8
    --        }
    --        commands.execAsync(string.format("playsound createdieselgenerators:diesel_engine_sound block @e[type=minecraft:player] %d %d %d %0.2f %0.4f 0.5", sPos.x, sPos.y, sPos.z, vo, pic))
    --        --commands.execAsync(string.format("say %0.2f", vo))
--
    --        if val < 0.5 then
    --            sleep(0.25)
    --        else
    --            sleep(0.05)
    --        end
    --    else
    --        --speaker = peripheral.find("speaker")
    --        sleep(0.5)
    --    end
    --end
end

---------main---------

system.init()

if term.isColor() then
    shell.run("background", "shell")
end

local flightUpdate = function()
    send_to_childShips()
    if ship.isStatic() or engineOff then
        --static
    else
        if properties.mode == 1 then
            pdControl.spaceShip()
        elseif properties.mode == 2 then
            pdControl.quadFPV()
        elseif properties.mode == 3 then
            pdControl.helicopter()
        elseif properties.mode == 4 then
            pdControl.airShip()
        elseif properties.mode == 5 then
            scanner.scan()
            pdControl.followMouse()
        elseif properties.mode == 6 then
            scanner.scan()
            pdControl.follow(scanner.commander)
        elseif properties.mode == 7 then
            pdControl.goHome()
        elseif properties.mode == 8 then
            pdControl.pointLoop()
        elseif properties.mode == 9 then
            pdControl.ShipCamera()
        elseif properties.mode == 10 then
            pdControl.ShipFollow()
        elseif properties.mode == 11 then
            pdControl.anchorage()
        elseif properties.mode == 12 then
            pdControl.spaceFpv()
        elseif properties.mode == 13 then
            pdControl.fixedWing()
        end
        --commands.execAsync(("say %0.2f"):format(attUtil.velocity.x))
        --genWakeFlow()
        allForce = InvariantForce + RotDependentForce + RotDependentTorque
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
            --scanner.scan()
            phys_Count = 1
        else
            phys_Count = phys_Count + 1
        end

        flightUpdate()
        attUtil.setPreAtt()
        allForce = InvariantForce + RotDependentForce + RotDependentTorque
    end
end

local listener = function()
    while true do
        local eventData = { os.pullEvent() }
        local event = eventData[1]

        if event == "phys_tick" then
            if physics_flag then
                physics_flag = false
            end
            --commands.execAsync(("say phy"))
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
            for k, screen in pairs(monitorUtil.screens) do
                screen:refresh()
            end
        elseif event == "mouse_click" and monitorUtil.screens["computer"] then
            monitorUtil.screens["computer"]:onTouch(eventData[3], eventData[4])
            for k, screen in pairs(monitorUtil.screens) do
                screen:refresh()
            end
        elseif event == "key" and not tableHasValue(properties.enabledMonitors, "computer") then
            table.insert(properties.enabledMonitors, "computer")
            system.updatePersistentData()
        end
    end
end

local all_listener = function()
    parallel.waitForAll(listener, shipNet_run)
end

local isPhysMode = function()
    if physics_flag then
        pdControl.basicYSpeed = 30
        pdControl.helicopt_P_multiply = 1.5
        pdControl.helicopt_D_multiply = 4
        pdControl.rot_P_multiply = 1.5
        pdControl.rot_D_multiply = 0.5
        pdControl.move_P_multiply = 2
        pdControl.move_D_multiply = 100
        pdControl.airMass_multiply = 10
        pdControl.quadFpv_P = 0.3456
        pdControl.quadFpv_D = 7.25
        return false
    else
        pdControl.basicYSpeed = 10
        pdControl.helicopt_P_multiply = 1
        pdControl.helicopt_D_multiply = 1
        pdControl.rot_P_multiply = 1
        pdControl.rot_D_multiply = 1
        pdControl.move_P_multiply = 1
        pdControl.move_D_multiply = 100
        pdControl.airMass_multiply = 30
        pdControl.quadFpv_P = 0.2625
        pdControl.quadFpv_D = 16
        return true
    end
end

local runFlight = function()
    sleep(0.1)

    while true do
        if shutdown_flag then
            sleep(0.5)
        else
            if isPhysMode() then return end
            attUtil.getAttWithCCTick()
            joyUtil.getJoyInput()
            flightUpdate()
            attUtil.setPreAtt()
            sleep(0.05)
        end
    end
end

function run()
    parallel.waitForAll(runFlight, all_listener)
end

local refreshDisplay = function()
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

local env = function ()
    parallel.waitForAll(refreshDisplay, engineSound)
end

xpcall(function()
    monitorUtil.scanMonitors()
    if monitorUtil.screens["computer"] == nil then
        monitorUtil.disconnectComputer()
    end
    attUtil.init()
    parallel.waitForAll(run, env)
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
