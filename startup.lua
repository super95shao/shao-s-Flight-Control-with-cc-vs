if not ship then
    if term.isColor() then term.setTextColor(colors.red) end
    print("ShipAPI unavailable. Either this computer is not on a ship, or CC-VS is not installed.")
    return
end
if not ship.setStatic then
    if term.isColor() then term.setTextColor(colors.red) end
    print("ExtendedShipAPI unavailable. Requires either disable \"command_only\" in CC-VS config, or a command computer.")
    return
end

---------inner---------
local modelist = {
    spaceShip = { y = 3, name = "spaceShip ", flag = false },
    quadFPV   = { y = 4, name = "quadFPV   ", flag = false },
    helicopt  = { y = 5, name = "helicopter", flag = false },
    hms_fly   = { y = 6, name = "hms_fly   ", flag = false },
    follow    = { y = 7, name = "follow    ", flag = false },
    pointLoop = { y = 8, name = "pointLoop ", flag = false }
}

local system, properties, attUtil, monitorUtil, joyUtil, pdControl, rayCaster, scanner, timeUtil

---------system---------
system = {
    fileName = "dat",
    file = nil
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
        if properties.omega_D > 1.52 then properties.omega_D = 1.52 end
        system.file:close()
    else
        properties = system.reset()
        system.updatePersistentData()
    end

    for key, value in pairs(modelist) do
        if value.name == properties.mode then
            value.flag = true
        end
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
        mode = modelist.quadFPV.name,
        HOME = { x = 0, y = 120, z = 0 },
        homeList = {
            { x = 0, y = 120, z = 0 }
        },
        enabledMonitors = enabledMonitors,
        omega_P = 1,    --角速度比例, 决定转向快慢
        omega_D = 1.52, --角速度阻尼, 低了停的慢、太高了会抖动。标准是松杆时快速停下角速度、且停下时不会抖动
        space_Acc = 2,  --星舰模式油门速度
        quad_Acc = 1,   --四轴FPV模式油门强度
        move_D = 1.6,   --移动阻尼, 低了停的慢、太高了会抖动。标准是松杆时快速停下、且停下时不会抖动
        helicopt_YAW_P = 0.5,
        helicopt_ROT_D = 0.75,
        helicopt_MAX_ANGLE = 45,
        helicopt_ACC = 0.5,
        helicopt_ACC_D = 0.5,
        ZeroPoint = 0,
        MAX_MOVE_SPEED = 99,    --自动驾驶 (点循环、跟随模式) 最大跟随速度
        pointLoopWaitTime = 60, --点循环模式-到达目标点后等待时间 (tick)
        rayCasterRange = 128,
        quadAutoHover = false,
        helicoptAutoHover = false,
        spaceShipLock = false,
        quadGravity = -1,
        airMass = 1,                            --空气密度 (风阻)
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
        for i, v in ipairs(t) do
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
    if math.abs(ag.pitch) > 90 then
        ag.yaw = -ag.yaw
        ag.roll = -ag.roll
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
    ag.yaw = math.deg(math.atan2(matrix[3][3], matrix[1][3]))
    ag.pitch = math.deg(math.atan2(matrix[2][1], matrix[2][2]))
    ag.roll = math.deg(math.atan2(matrix[2][3], matrix[2][2]))
    return ag
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
    --result.x = math.deg(math.asin(result.x))
    --result.y = math.deg(math.asin(result.y))
    --result.z = math.deg(math.asin(result.z))
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
                result.y = result.y + 1.6
                result.roll = 0
                result.yaw = math.deg(math.atan2(result.raw_euler_z, -result.raw_euler_x))
                result.pitch = -math.deg(math.asin(result.raw_euler_y))
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
    pointLoopIndex = 1,
    pointLoopWaitTime = 1
}
---------attUtil---------
attUtil = {
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
    eulerOmega = {},
    initPoint = {},
    velocity = {},
    speed = {},
    tmpFlags = {
        spaceShipLastPos = ship.getWorldspacePosition(),
        spaceShipLastEuler = {roll = 0, yaw = 0, pitch = 0},
        hmsLastAtt = {roll = 0, yaw = 0, pitch = 0},
        helicoptLastPos = ship.getWorldspacePosition(),
        helicoptLastEuler = {roll = 0, yaw = 0, pitch = 0},
    }
}

attUtil.getAtt = function()
    attUtil.mass = ship.getMass()
    attUtil.MomentOfInertiaTensor = ship.getMomentOfInertiaTensor()[1][1]

    attUtil.mass = attUtil.mass * ship.getScale().x ^ 3
    attUtil.MomentOfInertiaTensor = attUtil.MomentOfInertiaTensor * ship.getScale().x ^ 3

    attUtil.size = ship.getSize()
    attUtil.position = ship.getWorldspacePosition()
    attUtil.quat = ship.getQuaternion()
    attUtil.conjQuat = {}
    attUtil.conjQuat.w = attUtil.quat.w
    attUtil.conjQuat.x = -attUtil.quat.x
    attUtil.conjQuat.y = -attUtil.quat.y
    attUtil.conjQuat.z = -attUtil.quat.z
    attUtil.matrix = ship.getRotationMatrix()
    --attUtil.eulerAngle = getEulerByMatrix(attUtil.matrix)
    attUtil.eulerAngle = quat2Euler(attUtil.quat)
    attUtil.pX = RotateVectorByQuat(attUtil.quat, { x = 1, y = 0, z = 0 })
    attUtil.pY = RotateVectorByQuat(attUtil.quat, { x = 0, y = 1, z = 0 })
    attUtil.pZ = RotateVectorByQuat(attUtil.quat, { x = 0, y = 0, z = -1 })

    local XPoint = { x = attUtil.pX.x, y = attUtil.pX.y, z = attUtil.pX.z }
    local ZPoint = { x = attUtil.pZ.x, y = attUtil.pZ.y, z = attUtil.pZ.z }
    attUtil.preQuat.x = -attUtil.preQuat.x
    attUtil.preQuat.y = -attUtil.preQuat.y
    attUtil.preQuat.z = -attUtil.preQuat.z
    XPoint = RotateVectorByQuat(attUtil.preQuat, XPoint)
    ZPoint = RotateVectorByQuat(attUtil.preQuat, ZPoint)
    attUtil.omega.roll = math.deg(math.asin(ZPoint.y))
    attUtil.omega.pitch = math.deg(math.asin(XPoint.y))
    attUtil.omega.yaw = math.deg(math.atan2(-XPoint.z, XPoint.x))


    attUtil.eulerOmega.roll = attUtil.eulerAngle.roll - attUtil.preEuler.roll
    attUtil.eulerOmega.yaw = attUtil.eulerAngle.yaw - attUtil.preEuler.yaw
    attUtil.eulerOmega.pitch = attUtil.eulerAngle.pitch - attUtil.preEuler.pitch

    attUtil.velocity.x = ship.getVelocity().x / 20
    attUtil.velocity.y = ship.getVelocity().y / 20
    attUtil.velocity.z = ship.getVelocity().z / 20
    --commands.execAsync(("say roll=%0.2f  yaw=%0.2f  pitch=%0.2f"):format(attUtil.eulerAngle.roll, attUtil.eulerAngle.yaw, attUtil.eulerAngle.pitch))
    --commands.execAsync(("say w = %0.2f x=%0.2f  y=%0.2f  z=%0.2f"):format(attUtil.quat.w, attUtil.quat.x, attUtil.quat.y, attUtil.quat.z))
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
    attUtil.quat = ship.getQuaternion()
    attUtil.preQuat = attUtil.quat
    attUtil.eulerAngle = quat2Euler(attUtil.quat)
    attUtil.preEuler = { roll = 0, yaw = 0, pitch = 0 }
end

---------joyUtil---------
joyUtil = {
    joy = nil,
    joyMissing = true,
    l_fb = 0,
    l_lr = 0,
    r_fb = 0,
    r_lr = 0,
    LB = 0,
    RB = 0,
    LT = 0,
    RT = 0,
    back = 0,
    start = 0,
    flag = false
}

joyUtil.getJoyInput = function()
    if not joyUtil.joy or not peripheral.hasType(joyUtil.joy, "tweaked_controller") then
        joyUtil.joy = peripheral.find("tweaked_controller")
    end
    if joyUtil.joy then
        joyUtil.joyMissing = false
        joyUtil.flag = pcall(joyUtil.joy.hasUser)
        if not joyUtil.flag then
            return
        end
        if joyUtil.joy.hasUser() then
            joyUtil.l_lr = -joyUtil.joy.getAxis(1)
            joyUtil.l_fb = -joyUtil.joy.getAxis(2)
            joyUtil.r_lr = -joyUtil.joy.getAxis(3)
            joyUtil.r_fb = -joyUtil.joy.getAxis(4)
            joyUtil.LB = joyUtil.joy.getButton(5)
            joyUtil.RB = joyUtil.joy.getButton(6)
            joyUtil.LT = joyUtil.joy.getAxis(5)
            joyUtil.RT = joyUtil.joy.getAxis(6)
            joyUtil.back = joyUtil.joy.getButton(7)
            joyUtil.start = joyUtil.joy.getButton(8)
        else
            joyUtil.l_lr = 0
            joyUtil.l_fb = 0
            joyUtil.r_lr = 0
            joyUtil.r_fb = 0
            joyUtil.LB = 0
            joyUtil.RB = 0
            joyUtil.LT = 0
            joyUtil.RT = 0
            joyUtil.back = 0
            joyUtil.start = 0
        end

        joyUtil.LB = joyUtil.LB and 1 or 0
        joyUtil.RB = joyUtil.RB and 1 or 0
    else
        joyUtil.joyMissing = false
        --[[properties.mode = modelist.spaceShip.name
        for k, v in pairs(modelist) do
            if v == modelist.spaceShip then
                v.flag = true
            else
                v.flag = false
            end
        end]]
    end
end

---------PDcontrol---------
pdControl = {
    pitchSpeed = 0,
    rollSpeed = 0,
    yawSpeed = 0,
    xSpeed = 0,
    ySpeed = 0,
    zSpeed = 0,
    basicYSpeed = 30,
    fixCd = 0
}

pdControl.moveWithOutRot = function(xVal, yVal, zVal, p, d)
    p = p * 2
    d = d * 200
    pdControl.xSpeed = xVal * p + -attUtil.velocity.x * d
    pdControl.zSpeed = zVal * p + -attUtil.velocity.z * d
    pdControl.ySpeed = yVal * p + pdControl.basicYSpeed + -attUtil.velocity.y * d

    ship.applyInvariantForce(pdControl.xSpeed * attUtil.mass,
        pdControl.ySpeed * attUtil.mass,
        pdControl.zSpeed * attUtil.mass)
end

pdControl.moveWithRot = function(xVal, yVal, zVal, p, d)
    p = p * 2
    d = d * 200
    pdControl.xSpeed = -attUtil.velocity.x * d
    pdControl.zSpeed = -attUtil.velocity.z * d
    pdControl.ySpeed = yVal * p + pdControl.basicYSpeed + -attUtil.velocity.y * d

    ship.applyInvariantForce(pdControl.xSpeed * attUtil.mass,
        pdControl.ySpeed * attUtil.mass,
        pdControl.zSpeed * attUtil.mass)

    ship.applyRotDependentForce(xVal * p * attUtil.mass,
        0,
        zVal * p * attUtil.mass)
end

pdControl.quadUp = function(yVal, p, d, hov)
    p = p * 2
    d = d * 200
    if hov then
        local omegaApplyRot = RotateVectorByQuat(attUtil.quat, { x = 0, y = attUtil.velocity.y, z = 0 })
        pdControl.ySpeed = (yVal + -math.deg(math.asin(properties.ZeroPoint))) * p + pdControl.basicYSpeed * 2 +
            -omegaApplyRot.y * d
    else
        pdControl.ySpeed = (yVal + -math.deg(math.asin(properties.ZeroPoint))) * p
    end

    ship.applyRotDependentForce(0, pdControl.ySpeed * attUtil.mass, 0)

    pdControl.xSpeed = copysign((attUtil.velocity.x ^ 2) * 10 * properties.airMass, -attUtil.velocity.x)
    pdControl.zSpeed = copysign((attUtil.velocity.z ^ 2) * 10 * properties.airMass, -attUtil.velocity.z)
    pdControl.ySpeed = copysign((attUtil.velocity.y ^ 2) * 10 * properties.airMass, -attUtil.velocity.y)

    ship.applyInvariantForce(pdControl.xSpeed * attUtil.mass,
        pdControl.ySpeed * attUtil.mass + properties.quadGravity * 30 * attUtil.mass,
        pdControl.zSpeed * attUtil.mass)
end

pdControl.rotInner = function(xRot, yRot, zRot, p, d)
    --commands.execAsync(("say omegaRoll=%0.8f"):format(attUtil.omega.roll))
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
    local selfAg = attUtil.eulerAngle
    euler.pitch = math.abs(euler.pitch) > 45 and copysign(45, euler.pitch) or euler.pitch
    tgAg.roll  = resetAngelRange(euler.roll - selfAg.roll)
    tgAg.yaw   = resetAngelRange(euler.yaw - selfAg.yaw)
    tgAg.pitch = resetAngelRange(euler.pitch - selfAg.pitch)

    yaw        = tgAg.yaw * (1 - attUtil.pX.y ^ 2) + -tgAg.roll * (attUtil.pX.y ^ 2)
    roll       = tgAg.roll * (1 - attUtil.pX.y ^ 2) + tgAg.yaw * (attUtil.pX.y ^ 2)
    pitch      = tgAg.pitch * (1 - attUtil.pZ.y ^ 2) + tgAg.yaw * (attUtil.pZ.y ^ 2)
    roll       = roll
    yaw        = yaw
    pitch      = pitch

    pdControl.rotInner(roll, yaw, pitch, p, d)
end

pdControl.rotate2Euler2 = function(euler)
    local tmpx = {
        x = -math.cos(math.rad(euler.yaw)),
        y = -math.sin(math.rad(euler.pitch)),
        z = math.sin(math.rad(euler.yaw))
    }
    local tmpz = {
        x = math.sin(math.rad(euler.yaw)),
        y = math.sin(math.rad(euler.roll)),
        z = -math.cos(math.rad(euler.yaw))
    }

    local newXpoint = RotateVectorByQuat(attUtil.conjQuat, tmpx)
    local newZpoint = RotateVectorByQuat(attUtil.conjQuat, tmpz)
    local roll = math.deg(math.asin(newZpoint.y))
    local yaw = math.deg(math.atan2(newXpoint.z, -newXpoint.x))
    local pitch = -math.deg(math.asin(newXpoint.y))

    commands.execAsync(("say roll=%0.2f  yaw=%0.2f  pitch=%0.2f"):format(roll, yaw, pitch))
    --pdControl.rotInner(roll, yaw, pitch, properties.omega_P, properties.omega_D)
end

pdControl.spaceShip = function()
    if properties.spaceShipLock then
        if next(attUtil.tmpFlags.spaceShipLastEuler) == nil then attUtil.tmpFlags.spaceShipLastEuler = attUtil.eulerAngle end
        if next(attUtil.tmpFlags.spaceShipLastPos) == nil then attUtil.tmpFlags.spaceShipLastPos = attUtil.position end
        pdControl.gotoPosition(attUtil.tmpFlags.spaceShipLastEuler, attUtil.tmpFlags.spaceShipLastPos)
    else
        pdControl.moveWithRot(
            math.deg(math.asin(joyUtil.LT - joyUtil.RT)),
            math.deg(math.asin(joyUtil.l_fb)),
            math.deg(math.asin(joyUtil.LB - joyUtil.RB)),
            properties.space_Acc,
            properties.move_D)
    end

    pdControl.rotInner(
        math.deg(math.asin(joyUtil.r_lr)),
        math.deg(math.asin(joyUtil.l_lr)),
        math.deg(math.asin(joyUtil.r_fb)),
        properties.omega_P,
        properties.omega_D)
end

pdControl.quadFPV = function()
    if properties.quadAutoHover then
        if joyUtil.l_fb == 0 then
            pdControl.quadUp(
                0,
                properties.quad_Acc,
                properties.move_D,
                true)
        else
            pdControl.quadUp(
                math.deg(math.asin(joyUtil.l_fb)),
                properties.quad_Acc,
                properties.move_D,
                false)
        end

        if joyUtil.r_lr == 0 and joyUtil.l_lr == 0 and joyUtil.r_fb == 0 then
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
                pitch = math
                    .deg(math.asin(newVel.x)) * distance
            }
            euler.roll = math.abs(euler.roll) > 70 and copysign(70, euler.roll) or euler.roll
            euler.pitch = math.abs(euler.pitch) > 70 and copysign(70, euler.pitch) or euler.pitch
            pdControl.rotate2Euler(euler, properties.omega_P, properties.omega_D)
        else
            pdControl.rotate2Euler({
                    roll = math.deg(math.asin(joyUtil.r_lr)) / 1.5,
                    yaw = attUtil.eulerAngle.yaw + joyUtil.l_lr * 40,
                    pitch = math.deg(math.asin(joyUtil.r_fb) / 1.5)
                },
                properties.omega_P,
                properties.omega_D)
        end
    else
        pdControl.quadUp(
            math.deg(math.asin(joyUtil.l_fb)),
            properties.quad_Acc,
            properties.move_D,
            false)
        pdControl.rotInner(
            math.deg(math.asin(joyUtil.r_lr)),
            math.deg(math.asin(joyUtil.l_lr)),
            math.deg(math.asin(joyUtil.r_fb)),
            properties.omega_P,
            properties.omega_D)
    end
end

pdControl.helicopter = function()
    local acc
    local tgAg = {}
    if properties.helicoptAutoHover then
        local tmpPos = {}
        tmpPos.y = attUtil.tmpFlags.helicoptLastPos.y - (attUtil.position.y + attUtil.velocity.y * 20)
        acc = tmpPos.y * 10
        acc = math.abs(acc) > 90 and copysign(90, acc) or acc
        tgAg.yaw = attUtil.tmpFlags.helicoptLastEuler.yaw
        tmpPos.x = attUtil.tmpFlags.helicoptLastPos.x - (attUtil.position.x + attUtil.velocity.x * 80)
        tmpPos.z = attUtil.tmpFlags.helicoptLastPos.z - (attUtil.position.z + attUtil.velocity.z * 80)
        tmpPos = RotateVectorByQuat(attUtil.conjQuat, tmpPos)
        tmpPos.tmp_c = math.sqrt(tmpPos.x ^ 2 + tmpPos.z ^ 2)
        tgAg.roll = math.deg(math.asin(tmpPos.z / tmpPos.tmp_c))
        tgAg.roll = tgAg.roll ~= tgAg.roll and 0 or tgAg.roll * tmpPos.tmp_c * 0.01
        tgAg.roll = math.abs(tgAg.roll) > 45 and copysign(45, tgAg.roll) or tgAg.roll
        tgAg.pitch = -math.deg(math.asin(tmpPos.x / tmpPos.tmp_c))
        tgAg.pitch = tgAg.pitch ~= tgAg.pitch and 0 or tgAg.pitch * tmpPos.tmp_c * 0.01
        tgAg.pitch = math.abs(tgAg.pitch) > 45 and copysign(45, tgAg.pitch) or tgAg.pitch
    else
        acc = math.deg(math.asin(joyUtil.l_fb))
        tgAg.roll = math.deg(math.asin(joyUtil.r_lr)) * (properties.helicopt_MAX_ANGLE / 90)
        tgAg.yaw = attUtil.eulerAngle.yaw + joyUtil.l_lr * 40 * properties.helicopt_YAW_P
        tgAg.pitch = math.deg(math.asin(joyUtil.r_fb)) * (properties.helicopt_MAX_ANGLE / 90)
    end

    pdControl.quadUp(
        acc,
        properties.helicopt_ACC,
        properties.helicopt_ACC_D,
        true)

    pdControl.rotate2Euler(tgAg, properties.helicopt_ROT_D, properties.helicopt_ROT_D)
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
        properties.space_Acc,
        properties.move_D
    )
    if euler then
        pdControl.rotate2Euler(euler, properties.omega_P, properties.omega_D)
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
    pdControl.rotate2Euler(attUtil.tmpFlags.hmsLastAtt, properties.omega_P, properties.omega_D)

    pdControl.moveWithRot(
        math.deg(math.asin(joyUtil.LT - joyUtil.RT)),
        math.deg(math.asin(joyUtil.l_fb)),
        math.deg(math.asin(joyUtil.LB - joyUtil.RB)),
        properties.space_Acc,
        properties.move_D)
end

pdControl.follow = function(target)
    if not target then
        -- TODO:插入悬停飞控
        -- pdControl.staticHover()
        return
    end
    local pos, qPos = {}, {}
    qPos.x = copysign(attUtil.size.x / 2, properties.followRange.x) + properties.followRange.x
    qPos.y = copysign(attUtil.size.y / 2, properties.followRange.y) + properties.followRange.y
    qPos.z = copysign(attUtil.size.z / 2, properties.followRange.z) + properties.followRange.z
    pos.x = target.x + qPos.x
    pos.y = target.y + qPos.y
    pos.z = target.z + qPos.z

    pdControl.gotoPosition(
        { roll = 0, yaw = 0, pitch = 0 }, pos)
end

pdControl.pointLoop = function()
    local tgAg, pos = {}, {}
    pos = properties.pointList[timeUtil.pointLoopIndex]
    tgAg = { roll = 0, yaw = pos.yaw, pitch = 0 }
    if pos.flip then
        tgAg.pitch = 180
    end
    if math.abs(attUtil.position.x - pos.x) < 0.5 and
        math.abs(attUtil.position.y - pos.y) < 0.5 and
        math.abs(attUtil.position.z - pos.z) < 0.5 then
        if timeUtil.pointLoopWaitTime >= properties.pointLoopWaitTime then
            timeUtil.pointLoopWaitTime = 1
            if timeUtil.pointLoopIndex >= #properties.pointList then
                timeUtil.pointLoopIndex = 1
            else
                timeUtil.pointLoopIndex = timeUtil.pointLoopIndex + 1
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
    self.monitor.setBackgroundColor(colors.blue)
    self.monitor.clear()
    self.monitor.setCursorPos(1, 1)
    if self.monitor.setTextScale then
        self.monitor.setTextScale(1)
        self.monitor.write(":(")
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

-- flightGizmoScreen
-- 飞控系统屏幕
local flightGizmoScreen = {
    screenTitle = "gizmo"
}
flightGizmoScreen.__index = setmetatable(flightGizmoScreen, abstractScreen)

function flightGizmoScreen:init()
    if self.monitor.setTextScale then
        self.monitor.setTextScale(0.5)
    end
    self.monitor.setBackgroundColor(colors.lightBlue)
    self.mainPage = {
        modeSelect   = { x = 1, name = " MOD ", flag = true },
        attIndicator = { x = 6, name = " ATT ", flag = false },
        settings     = { x = 11, name = " SET ", flag = false }
    }
    self.settingPage = {
        PD_Tuning   = { y = 3, name = "PD_Tuning  ", selected = false, flag = false },
        helicopter  = { y = 4, name = "Helicopter ", selected = false, flag = false },
        User_Change = { y = 5, name = "User_Change", selected = false, flag = false },
        HOME_SET    = { y = 6, name = "Home_Set   ", selected = false, flag = false },
        Simulate    = { y = 7, name = "Simulate   ", selected = false, flag = false },
    }
    self.attPage = {
        compass = { name = "compass", flag = true },
        level = { name = "level", flag = false }
    }
end

function flightGizmoScreen:report()
    if self.mainPage.modeSelect.flag then
        return "Tab: MOD"
    elseif self.mainPage.attIndicator.flag then
        return "Tab: ATT"
    elseif self.mainPage.settings.flag then
        return "Tab: SET"
    else
        return "Tab: ?"
    end
end

function flightGizmoScreen:refresh()
    if coordinate and not scanner.commander then
        for k, v in pairs(self.mainPage) do
            if v == self.mainPage.settings then
                scanner.scanPlayer()
                v.flag = true
            else
                v.flag = false
            end
        end
        for k, v in pairs(self.settingPage) do
            if v == self.settingPage.User_Change then
                v.flag = true
            else
                v.flag = false
            end
        end
    end
    self.monitor.clear()

    for key, value in pairs(self.mainPage) do
        self.monitor.setCursorPos(value.x, 1)
        if value.flag then
            self.monitor.blit(value.name, "fffff", "44444")
        else
            self.monitor.blit(value.name, "00000", "22222")
        end
    end

    if self.mainPage.modeSelect.flag then --modePage
        if ship.isStatic() then
            self.monitor.setCursorPos(4, 2)
            self.monitor.blit("[STATIC!]", "eeeeeeeee", "111111111")
        end
        for key, mode in pairs(modelist) do
            self.monitor.setCursorPos(2, mode.y)
            if mode.flag then
                self.monitor.blit(mode.name, "ffffffffff", "4444444444")
            else
                self.monitor.blit(mode.name, "0000000000", "3333333333")
            end
        end

        if properties.mode == modelist.spaceShip.name then
            self.monitor.setCursorPos(12, modelist.spaceShip.y)
            if properties.spaceShipLock then
                self.monitor.blit(" L", "ff", "33")
            else
                self.monitor.blit(" N", "88", "33")
            end
        end

        if properties.mode == modelist.helicopt.name then
            self.monitor.setCursorPos(12, modelist.helicopt.y)
            if properties.helicoptAutoHover then
                self.monitor.blit(" L", "ff", "33")
            else
                self.monitor.blit(" N", "88", "33")
            end
        end

        if properties.mode == modelist.quadFPV.name then
            self.monitor.setCursorPos(12, modelist.quadFPV.y)
            if properties.quadAutoHover then
                self.monitor.blit(" A", "ff", "33")
            else
                self.monitor.blit(" N", "88", "33")
            end
        end
    elseif self.mainPage.attIndicator.flag then --attPage
        if self.attPage.compass.flag then       --罗盘
            self.monitor.setCursorPos(1, 2)
            for i = 1, 15, 1 do
                self.monitor.setCursorPos(i, 2)
                self.monitor.blit(".", "0", "3")
            end

            local xPoint = math.floor(math.cos(math.rad(attUtil.eulerAngle.yaw)) * 8 + 0.5)
            local zPoint = math.floor(math.sin(math.rad(attUtil.eulerAngle.yaw)) * 8 + 0.5)
            if attUtil.pX.x > 0 then
                self.monitor.setCursorPos(8 + zPoint, 2)
                self.monitor.blit("W", "0", "3")
            else
                self.monitor.setCursorPos(8 - zPoint, 2)
                self.monitor.blit("E", "0", "3")
            end

            if attUtil.pX.z > 0 then
                self.monitor.setCursorPos(8 + xPoint, 2)
                self.monitor.blit("N", "e", "3")
            else
                self.monitor.setCursorPos(8 - xPoint, 2)
                self.monitor.blit("S", "b", "3")
            end
        elseif self.attPage.level.flag then --水平仪
            for i = 1, 128, 1 do
                local yPoint = math.abs(attUtil.eulerAngle.roll) > 90 and -attUtil.pZ.y or attUtil.pZ.y
                self.monitor.setCursorPos(8 - math.cos(math.asin(attUtil.pX.y)) * (8 - i),
                    6 - (attUtil.pX.y * 6) - yPoint * (8 - i))
                self.monitor.blit(" ", "0", "0")
            end
        end
    elseif self.mainPage.settings.flag then --settingPage
        if self.settingPage.PD_Tuning.flag then
            properties.spaceShipLock = false
            self.monitor.setCursorPos(1, 2)
            self.monitor.blit("<<", "24", "33")

            self.monitor.setCursorPos(2, 3)
            self.monitor.blit("P: --      ++", "1ffffffffffff", "333b53333331e")
            self.monitor.setCursorPos(8, 3)
            self.monitor.write(string.format("%0.2f", properties.omega_P))

            self.monitor.setCursorPos(2, 4)
            self.monitor.blit("D: --      ++", "9ffffffffffff", "333b53333331e")
            self.monitor.setCursorPos(8, 4)
            self.monitor.write(string.format("%0.2f", properties.omega_D))

            self.monitor.setCursorPos(2, 6)
            self.monitor.blit("spaceAcc-   +", "fffffffffffff", "33333333b333e")
            self.monitor.setCursorPos(11, 6)
            self.monitor.write(string.format("%0.1f", properties.space_Acc))

            self.monitor.setCursorPos(2, 7)
            self.monitor.blit("quad_Acc-   +", "fffffffffffff", "33333333b333e")
            self.monitor.setCursorPos(11, 7)
            self.monitor.write(string.format("%0.1f", properties.quad_Acc))

            self.monitor.setCursorPos(2, 8)
            self.monitor.blit("MOVE_D: -   +", "fffffffffffff", "33333333b333e")
            self.monitor.setCursorPos(11, 8)
            self.monitor.write(string.format("%0.1f", properties.move_D))
        elseif self.settingPage.helicopter.flag then
            self.monitor.setCursorPos(1, 2)
            self.monitor.blit("<<", "24", "33")

            self.monitor.setCursorPos(2, 3)
            self.monitor.blit("Yaw_P--    ++", "fffffffffffff", "33333b533331e")
            self.monitor.setCursorPos(9, 3)
            self.monitor.write(string.format("%0.2f", properties.helicopt_YAW_P))

            self.monitor.setCursorPos(2, 4)
            self.monitor.blit("Rot_D--    ++", "fffffffffffff", "33333b533331e")
            self.monitor.setCursorPos(9, 4)
            self.monitor.write(string.format("%0.2f", properties.helicopt_ROT_D))

            self.monitor.setCursorPos(2, 5)
            self.monitor.blit("ACC:-   +", "fffffffff", "3333b333e")
            self.monitor.setCursorPos(7, 5)
            self.monitor.write(string.format("%0.1f", properties.helicopt_ACC))

            self.monitor.setCursorPos(2, 6)
            self.monitor.blit("Acc_D--    ++", "fffffffffffff", "33333b533331e")
            self.monitor.setCursorPos(9, 6)
            self.monitor.write(string.format("%0.2f", properties.helicopt_ACC_D))

            self.monitor.setCursorPos(2, 7)
            self.monitor.blit("MaxAngle:-  +", "fffffffffffff", "333333333b33e")
            self.monitor.setCursorPos(12, 7)
            self.monitor.write(string.format("%d", properties.helicopt_MAX_ANGLE))
        elseif self.settingPage.User_Change.flag then
            self.monitor.setCursorPos(1, 2)
            self.monitor.blit("<<", "24", "33")

            self.monitor.setCursorPos(2, 3)
            self.monitor.blit("selectUser:", "fffffffffff", "33333333333")

            for i = 1, 5, 1 do
                if scanner.playerList[i] then
                    local name = scanner.playerList[i].name
                    self.monitor.setCursorPos(2, 3 + i)
                    if name == properties.userName then
                        for j = 1, 10, 1 do
                            local tmpChar = name:sub(j, j)
                            if #tmpChar ~= 0 then
                                self.monitor.blit(tmpChar, "f", "4")
                            end
                        end
                    else
                        for j = 1, 10, 1 do
                            local tmpChar = name:sub(j, j)
                            if #tmpChar ~= 0 then
                                self.monitor.blit(tmpChar, "0", "3")
                            end
                        end
                    end
                end
            end
        elseif self.settingPage.HOME_SET.flag then
            self.monitor.setCursorPos(1, 2)
            self.monitor.blit("<<", "24", "33")
        elseif self.settingPage.Simulate.flag then
            self.monitor.setCursorPos(1, 2)
            self.monitor.blit("<<", "24", "33")

            self.monitor.setCursorPos(2, 4)
            self.monitor.blit("AirMass-    +", "fffffffffffff", "3333333b3333e")
            self.monitor.setCursorPos(10, 4)
            self.monitor.write(string.format("%0.1f", properties.airMass))

            self.monitor.setCursorPos(2, 6)
            self.monitor.blit("Gravity-    +", "fffffffffffff", "3333333b3333e")
            self.monitor.setCursorPos(10, 6)
            self.monitor.write(string.format("%0.1f", properties.quadGravity))

            self.monitor.setCursorPos(2, 8)
            self.monitor.blit("0_Point-    +", "fffffffffffff", "3333333b3333e")
            self.monitor.setCursorPos(10, 8)
            self.monitor.write(string.format("%0.1f", properties.ZeroPoint))
        else
            for key, value in pairs(self.settingPage) do
                self.monitor.setCursorPos(2, value.y)
                if value.selected then
                    self.monitor.blit(value.name, "fffffffffff", "44444444444")
                else
                    self.monitor.blit(value.name, "00000000000", "33333333333")
                end
            end
        end
    end

    --reboot and shutdown
    self.monitor.setCursorPos(1, 10)
    self.monitor.blit("[|]", "eee", "333")
    self.monitor.blit("[R]", "444", "333")
    self.monitor.setCursorPos(13, 10)
    self.monitor.blit("[X]", "fff", "333")
end

function flightGizmoScreen:onTouch(x, y)
    if y < 2 then
        for key, value in pairs(self.mainPage) do
            if x >= value.x and x <= value.x + 4 then
                value.flag = true
            else
                value.flag = false
            end
        end
    end

    if self.mainPage.modeSelect.flag then
        if x < 12 then
            if y >= 3 and y <= 8 then
                for key, value in pairs(modelist) do
                    if value.y == y then
                        value.flag = true
                        properties.mode = value.name
                    else
                        value.flag = false
                    end
                end
            end
        else
            if y == modelist.spaceShip.y then
                attUtil.tmpFlags.spaceShipLastPos = attUtil.position
                attUtil.tmpFlags.spaceShipLastEuler = attUtil.eulerAngle
                properties.spaceShipLock = not properties.spaceShipLock
            elseif y == modelist.helicopt.y then
                attUtil.tmpFlags.helicoptLastPos = attUtil.position
                attUtil.tmpFlags.helicoptLastEuler = attUtil.eulerAngle
                properties.helicoptAutoHover = not properties.helicoptAutoHover
            elseif y == modelist.quadFPV.y then
                properties.quadAutoHover = not properties.quadAutoHover
            end
        end
    elseif self.mainPage.settings.flag then
        if self.settingPage.PD_Tuning.flag then
            if y == 2 and x < 3 then
                self.settingPage.PD_Tuning.flag = false
                system.updatePersistentData()
            end

            if y == 3 then
                if x == 5 then
                    properties.omega_P = properties.omega_P - 0.1
                elseif x == 6 then
                    properties.omega_P = properties.omega_P - 0.01
                elseif x == 13 then
                    properties.omega_P = properties.omega_P + 0.01
                elseif x == 14 then
                    properties.omega_P = properties.omega_P + 0.1
                end
            elseif y == 4 then
                if x == 5 then
                    properties.omega_D = properties.omega_D - 0.1
                elseif x == 6 then
                    properties.omega_D = properties.omega_D - 0.01
                elseif x == 13 then
                    properties.omega_D = properties.omega_D + 0.01
                elseif x == 14 then
                    properties.omega_D = properties.omega_D + 0.1
                end

                if properties.omega_D >= 1.52 then properties.omega_D = 1.52 end
            elseif y == 6 then
                if x == 10 then
                    properties.space_Acc = properties.space_Acc - 0.1
                elseif x == 14 then
                    properties.space_Acc = properties.space_Acc + 0.1
                end
            elseif y == 7 then
                if x == 10 then
                    properties.quad_Acc = properties.quad_Acc - 0.1
                elseif x == 14 then
                    properties.quad_Acc = properties.quad_Acc + 0.1
                end
            elseif y == 8 then
                if x == 10 then
                    properties.move_D = properties.move_D - 0.1
                elseif x == 14 then
                    if properties.move_D < 1.6 then
                        properties.move_D = properties.move_D + 0.1
                    end
                end
            end
        elseif self.settingPage.helicopter.flag then
            if y == 2 and x < 3 then
                self.settingPage.helicopter.flag = false
                system.updatePersistentData()
            end

            if y == 3 then
                if x == 7 then
                    properties.helicopt_YAW_P = properties.helicopt_YAW_P - 0.1
                elseif x == 8 then
                    properties.helicopt_YAW_P = properties.helicopt_YAW_P - 0.01
                elseif x == 13 then
                    properties.helicopt_YAW_P = properties.helicopt_YAW_P + 0.01
                elseif x == 14 then
                    properties.helicopt_YAW_P = properties.helicopt_YAW_P + 0.1
                end
            elseif y == 4 then
                if x == 7 then
                    properties.helicopt_ROT_D = properties.helicopt_ROT_D - 0.1
                elseif x == 8 then
                    properties.helicopt_ROT_D = properties.helicopt_ROT_D - 0.01
                elseif x == 13 then
                    properties.helicopt_ROT_D = properties.helicopt_ROT_D + 0.01
                elseif x == 14 then
                    properties.helicopt_ROT_D = properties.helicopt_ROT_D + 0.1
                end
            elseif y == 5 then
                if x == 6 then
                    properties.helicopt_ACC = properties.helicopt_ACC - 0.1
                elseif x == 10 then
                    properties.helicopt_ACC = properties.helicopt_ACC + 0.1
                end
            elseif y == 6 then
                if x == 7 then
                    properties.helicopt_ACC_D = properties.helicopt_ACC_D - 0.1
                elseif x == 8 then
                    properties.helicopt_ACC_D = properties.helicopt_ACC_D - 0.01
                elseif x == 13 then
                    properties.helicopt_ACC_D = properties.helicopt_ACC_D + 0.01
                elseif x == 14 then
                    properties.helicopt_ACC_D = properties.helicopt_ACC_D + 0.1
                end
            elseif y == 7 then
                if x == 11 then
                    properties.helicopt_MAX_ANGLE = properties.helicopt_MAX_ANGLE - 1
                elseif x == 14 then
                    if properties.helicopt_MAX_ANGLE < 60 then
                        properties.helicopt_MAX_ANGLE = properties.helicopt_MAX_ANGLE + 1
                    end
                end
            end
        elseif self.settingPage.User_Change.flag then
            if y == 2 and x < 3 then
                self.settingPage.User_Change.flag = false
                system.updatePersistentData()
            end

            if y >= 4 and y <= 8 then
                local user = scanner.playerList[y - 3]
                if user then
                    properties.userName = user.name
                end
            end
        elseif self.settingPage.HOME_SET.flag then
            if y == 2 and x < 3 then
                self.settingPage.HOME_SET.flag = false
                system.updatePersistentData()
            end
        elseif self.settingPage.Simulate.flag then
            if y == 2 and x < 3 then
                self.settingPage.Simulate.flag = false
                system.updatePersistentData()
            end

            if y == 4 then
                if x == 9 then
                    properties.airMass = properties.airMass - 0.1
                elseif x == 14 then
                    properties.airMass = properties.airMass + 0.1
                end
            elseif y == 6 then
                if x == 9 then
                    properties.quadGravity = properties.quadGravity - 0.1
                elseif x == 14 then
                    properties.quadGravity = properties.quadGravity + 0.1
                end
            elseif y == 8 then
                if x == 9 then
                    if properties.ZeroPoint > -1 then
                        properties.ZeroPoint = properties.ZeroPoint - 0.1
                    end
                elseif x == 14 then
                    if properties.ZeroPoint < 0 then
                        properties.ZeroPoint = properties.ZeroPoint + 0.1
                    end
                end
            end
        else
            for key, value in pairs(self.settingPage) do
                if y == value.y then
                    if value.selected then
                        value.flag = true
                        if value == self.settingPage.User_Change then
                            scanner.scanPlayer()
                        end
                    else
                        value.selected = true
                    end
                else
                    value.selected = false
                    value.flag = false
                end
            end
        end
    end

    if y == 10 then
        if x <= 3 then
            system.updatePersistentData()
            monitorUtil.blankAllScreens()
            os.shutdown()
        elseif x <= 6 then
            system.updatePersistentData()
            monitorUtil.blankAllScreens()
            os.reboot()
        elseif x >= 13 then
            monitorUtil.disconnect(self.name)
        end
    end
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
    self.monitor.setBackgroundColor(colors.lightBlue)
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
        self.monitor.setBackgroundColor(colors.lightBlue)
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
local screenPickerScreen = {
    screenTitle = "idle"
}
screenPickerScreen.__index = setmetatable(screenPickerScreen, abstractScreen)

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
    self.monitor.setBackgroundColor(colors.lightBlue)
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
            self.monitor.setBackgroundColor(colors.lightBlue)
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
    local screen = {}
    monitorUtil.screens[name] = screen
    if not class then
        class = loadingScreen
    end
    setmetatable(screen, class)
    screen.__index = class
    screen.name = name
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
    elseif peripheral.isPresent(name) and peripheral.hasType(name, "monitor") and peripheral.call(name, "isColor") then
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
    elseif properties.mode == modelist.spaceShip.name then
        pdControl.spaceShip()
    elseif properties.mode == modelist.quadFPV.name then
        pdControl.quadFPV()
    elseif properties.mode == modelist.helicopt.name then
        pdControl.helicopter()
    elseif properties.mode == modelist.hms_fly.name then
        pdControl.followMouse()
    elseif properties.mode == modelist.follow.name then
        pdControl.follow(scanner.commander)
    elseif properties.mode == modelist.pointLoop.name then
        pdControl.pointLoop()
    elseif properties.mode == modelist.auto.name then
        pdControl.gotoPosition(
            { roll = 0, yaw = 120, pitch = 80 },
            properties.HOME
        )
    end
end

function listener()
    while true do
        local eventData = { os.pullEvent() }
        local event = eventData[1]

        if event == "monitor_touch" and monitorUtil.screens[eventData[2]] then
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
    while true do
        attUtil.getAtt()
        joyUtil.getJoyInput()
        scanner.scan()
        monitorUtil.refresh()
        flightUpdate()
        attUtil.setPreAtt()
        sleep(0.05)
    end
end

xpcall(function()
    monitorUtil.scanMonitors()
    if monitorUtil.screens["computer"] == nil then
        monitorUtil.disconnectComputer()
    end
    attUtil.init()
    parallel.waitForAll(run, listener)
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
