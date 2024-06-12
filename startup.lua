---------inner---------
local modelist = {
    spaceShip = { y = 3, name = "spaceShip ", flag = false },
    quadFPV   = { y = 4, name = "quadFPV   ", flag = false },
    helicopt  = { y = 5, name = "helicopter", flag = false },
    hms_fly   = { y = 6, name = "hms_fly   ", flag = false },
    follow    = { y = 7, name = "follow    ", flag = false },
    pointLoop = { y = 8, name = "pointLoop ", flag = false }
}

local toMonitor = peripheral.find("monitor")

local system, properties, attUtil, monitorUtil, joyUtil, pdControl, rayCaster, scanner, timeUtil

---------system---------
system = {
    fileName = "dat",
    file = nil
}

system.init = function()
    ship.setScale(1)
    system.file = io.open(system.fileName, "r")
    if system.file then
        properties = textutils.unserialise(system.file:read("a"))
        if properties.omega_D > 1.52 then properties.omega_D = 1.52 end
        system.file:close()
    else
        properties = system.reset()
        system.update(system.fileName, properties)
    end

    for key, value in pairs(modelist) do
        if value.name == properties.mode then
            value.flag = true
        end
    end
end

system.reset = function()
    return {
        userName = "fashaodesu",
        mode = modelist.quadFPV.name,
        HOME = { x = 0, y = 120, z = 0 },
        homeList = {
            { x = 0, y = 120, z = 0 }
        },
        omega_P = 1,            --角速度比例, 决定转向快慢
        omega_D = 1.52,         --角速度阻尼, 低了停的慢、太高了会抖动。标准是松杆时快速停下角速度、且停下时不会抖动
        space_Acc = 2,          --星舰模式油门速度
        quad_Acc = 1,           --四轴FPV模式油门强度
        move_D = 1.6,           --移动阻尼, 低了停的慢、太高了会抖动。标准是松杆时快速停下、且停下时不会抖动
        ZeroPoint = 0,
        MAX_MOVE_SPEED = 99,    --自动驾驶 (点循环、跟随模式) 最大跟随速度
        pointLoopWaitTime = 60, --点循环模式-到达目标点后等待时间 (tick)
        rayCasterRange = 128,
        quadAutoHover = false,
        spaceShipLock = false,
        quadGravity = -1,
        airMass = 1,                            --空气密度 (风阻)
        followRange = { x = -1, y = 0, z = 0 }, --跟随距离
        pointList = {                           --点循环模式，按照顺序逐个前往
            { x = -4499, y = 74, z = -896, yaw = 0, flip = false }
        }
    }
end

system.update = function(file, obj)
    system.file = io.open(file, "w")
    system.file:write(textutils.serialise(obj))
    system.file:close()
end

-----------function------------
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

local FPoint, LPoint
function quat2Euler(quat)
    FPoint = RotateVectorByQuat(quat, { x = 1, y = 0, z = 0 })
    LPoint = RotateVectorByQuat(quat, { x = 0, y = 0, z = -1 })
    --ag.pitch = math.deg(math.atan2(FPoint.y, copysign(math.sqrt(FPoint.x ^ 2 + FPoint.z ^ 2), TopPoint.y)))
    --ag.yaw = -math.deg(math.atan2(LPoint.x, -LPoint.z))
    --[[     if math.abs(FPoint.y) < 0.1 then
        ag.yaw = math.deg(math.atan2(-FPoint.z, FPoint.x))
    else
        ag.yaw = math.deg(math.atan2(TopPoint.z, -TopPoint.x))
        if FPoint.y < 0 then
            ag.yaw = resetAngelRange(ag.yaw - 180)
        end
    end ]]
    return {
        roll = math.deg(math.asin(LPoint.y)),
        pitch = math.deg(math.asin(FPoint.y)),
        yaw = math.deg(math.atan2(-FPoint.z, FPoint.x))
    }
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
                result.yaw = -math.deg(math.atan2(result.raw_euler_x, result.raw_euler_z))
                result.pitch = math.deg(math.asin(result.raw_euler_y))
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
    targetAngle.yaw = -math.deg(math.atan2(pos.z / targetAngle._c, pos.x / targetAngle._c))
    targetAngle.pitch = -math.deg(math.asin(pos.y / targetAngle.distance))
    targetAngle.roll = 0
    return targetAngle
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
    initPoint = {},
    velocity = {},
    speed = {},
    lastPos = {},
    lastEuler = {}
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
    attUtil.eulerAngle = getEulerByMatrix(attUtil.matrix)

    --attUtil.eulerAngle = quat2Euler(attUtil.quat)
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

    attUtil.velocity.x = ship.getVelocity().x / 20
    attUtil.velocity.y = ship.getVelocity().y / 20
    attUtil.velocity.z = ship.getVelocity().z / 20
    attUtil.speed = math.sqrt(ship.getVelocity().x ^ 2 + ship.getVelocity().y ^ 2 + ship.getVelocity().z ^ 2)
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
    joy = peripheral.find("tweaked_controller"),
    switchCd = 0,
    l_fb = 0,
    l_lr = 0,
    r_fb = 0,
    r_lr = 0,
    LB = false,
    RB = false,
    LT = 0,
    RT = 0,
    back = false,
    start = false
}

joyUtil.getJoyInput = function()
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
        joyUtil.LB = false
        joyUtil.RB = false
        joyUtil.LT = 0
        joyUtil.RT = 0
        joyUtil.back = false
        joyUtil.start = false
    end

    if joyUtil.switchCd > 0 then
        joyUtil.switchCd = joyUtil.switchCd - 1
    end

    if joyUtil.switchCd == 0 then
        if joyUtil.back then
            properties.quadAutoHover = not properties.quadAutoHover
        end
        joyUtil.switchCd = 4
    end
    joyUtil.LB = joyUtil.LB and 1 or 0
    joyUtil.RB = joyUtil.RB and 1 or 0
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
    pdControl.ySpeed = yVal * p + pdControl.basicYSpeed * 2 + -attUtil.velocity.y * d

    ship.applyInvariantForce(pdControl.xSpeed * attUtil.mass,
        pdControl.ySpeed * attUtil.mass + properties.quadGravity * 30 * attUtil.mass,
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
    pdControl.pitchSpeed = (attUtil.omega.pitch + zRot) * p + -attUtil.omega.pitch * 7 * d
    pdControl.rollSpeed  = (attUtil.omega.roll + xRot) * p + -attUtil.omega.roll * 7 * d
    pdControl.yawSpeed   = (attUtil.omega.yaw + yRot) * p + -attUtil.omega.yaw * 7 * d
    ship.applyRotDependentTorque(
        pdControl.rollSpeed * attUtil.MomentOfInertiaTensor,
        pdControl.yawSpeed * attUtil.MomentOfInertiaTensor,
        pdControl.pitchSpeed * attUtil.MomentOfInertiaTensor)
end

pdControl.rotate2Euler = function(euler)
    local tgAg, roll, yaw, pitch = {}, 0, 0, 0
    local selfAg = attUtil.eulerAngle
    tgAg.roll = resetAngelRange(euler.roll - selfAg.roll)
    tgAg.yaw = resetAngelRange(euler.yaw - selfAg.yaw)
    tgAg.pitch = resetAngelRange(euler.pitch - selfAg.pitch)
    if math.abs(selfAg.pitch) >= 90 then
        tgAg.yaw = -tgAg.yaw
    end

    yaw   = tgAg.yaw * (1 - attUtil.pX.y ^ 2) + -tgAg.roll * (attUtil.pX.y ^ 2)
    roll  = tgAg.roll * (1 - attUtil.pX.y ^ 2) + tgAg.yaw * (attUtil.pX.y ^ 2)
    pitch = tgAg.pitch * (1 - attUtil.pZ.y ^ 2) + tgAg.yaw * (attUtil.pZ.y ^ 2)
    roll  = roll * 1.1
    yaw   = yaw * 1.1
    pitch = pitch * 1.1

    pdControl.rotInner(roll, yaw, pitch, properties.omega_P, properties.omega_D)
end

pdControl.rotate2Euler2 = function(euler)
    local tmpx = {
        x = -math.cos(math.rad(euler.yaw)),
        y = -math.sin(math.rad(euler.pitch)),
        z = math.sin(math.rad(euler
            .yaw))
    }
    local tmpz = {
        x = math.sin(math.rad(euler.yaw)),
        y = math.sin(math.rad(euler.roll)),
        z = -math.cos(math.rad(euler
            .yaw))
    }
    local newXpoint = RotateVectorByQuat(attUtil.conjQuat, tmpx)
    local newZpoint = RotateVectorByQuat(attUtil.conjQuat, tmpz)
    local roll = math.deg(math.asin(newZpoint.y))
    local yaw = math.deg(math.atan2(newXpoint.z, -newXpoint.x))
    local pitch = -math.deg(math.asin(newXpoint.y))
    --commands.execAsync(("say roll=%0.2f  yaw=%0.2f  pitch=%0.2f"):format(roll, yaw, pitch))
    pdControl.rotInner(roll, yaw, pitch, properties.omega_P, properties.omega_D)
end

pdControl.spaceShip = function()
    if properties.spaceShipLock then
        if next(attUtil.lastEuler) == nil then attUtil.lastEuler = attUtil.eulerAngle end
        if next(attUtil.lastPos) == nil then attUtil.lastPos = attUtil.position end
        pdControl.gotoPosition(attUtil.lastEuler, attUtil.lastPos)
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
            pdControl.rotate2Euler(euler)
        else
            pdControl.rotate2Euler({
                roll = math.deg(math.asin(joyUtil.r_lr)) / 1.5,
                yaw = attUtil.eulerAngle.yaw + joyUtil.l_lr * 45,
                pitch = math.deg(math.asin(joyUtil.r_fb) / 1.5)
            })
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

    pdControl.rotate2Euler({
        roll = math.deg(math.asin(joyUtil.r_lr)) / 2,
        yaw = attUtil.eulerAngle.yaw + joyUtil.l_lr * 20 * properties.omega_P,
        pitch = math.deg(math.asin(joyUtil.r_fb) / 2)
    })
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
        pdControl.rotate2Euler(euler)
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

local lastAtt = { roll = 0, yaw = 0, pitch = 0 }
pdControl.followMouse = function()
    if joyUtil.joy.hasUser() then
        lastAtt = scanner.getRCAngle(16)
    end
    pdControl.rotate2Euler(lastAtt)

    pdControl.moveWithRot(
        math.deg(math.asin(joyUtil.LT - joyUtil.RT)),
        math.deg(math.asin(joyUtil.l_fb)),
        math.deg(math.asin(joyUtil.LB - joyUtil.RB)),
        properties.space_Acc,
        properties.move_D)
end

pdControl.follow = function(target)
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
---------monitorUtil---------
monitorUtil = {
    monitor = nil,
    mainPage = {
        modeSelect   = { x = 1, name = " MOD ", flag = true },
        attIndicator = { x = 6, name = " ATT ", flag = false },
        settings     = { x = 11, name = " SET ", flag = false }
    },
    settingPage = {
        PD_Tuning   = { y = 3, name = "PD_Tuning  ", selected = false, flag = false },
        User_Change = { y = 4, name = "User_Change", selected = false, flag = false },
        HOME_SET    = { y = 5, name = "Home_Set   ", selected = false, flag = false },
        Simulate    = { y = 6, name = "Simulate   ", selected = false, flag = false },
        miniSize    = { y = 7, name = "*miniSize* ", selected = false, flag = false }
    },
    attPage = {
        compass = { name = "compass", flag = true },
        level = { name = "level", flag = false }
    },
    playerList = {}
}

monitorUtil.init = function()
    monitorUtil.monitor = peripheral.find("monitor")
    monitorUtil.monitor.setTextScale(0.5)
    term.redirect(monitorUtil.monitor)
    monitorUtil.monitor.setBackgroundColor(colors.black)

    monitorUtil.monitor.clear()
    monitorUtil.monitor.setCursorPos(5, 3)
    monitorUtil.monitor.blit("WELCOME", "0000000", "fffffff")

    monitorUtil.monitor.setCursorPos(9 - #properties.userName / 2, 5)
    monitorUtil.monitor.write(properties.userName)

    monitorUtil.monitor.setCursorPos(1, 7)
    local index = 1
    for i = 1, 15, 1 do
        if index >= 14 then index = 1 end
        if index < 10 then
            monitorUtil.monitor.blit("-", ("%d"):format(index), "f")
        else
            monitorUtil.monitor.blit("-", ("%s"):format(string.char(index + 87)), "f")
        end
        index = index + 1
        sleep(0.05)
    end

    monitorUtil.monitor.setBackgroundColor(colors.lightBlue)
    sleep(0.1)
end

monitorUtil.refresh = function()
    monitorUtil.monitor.clear()

    for key, value in pairs(monitorUtil.mainPage) do
        monitorUtil.monitor.setCursorPos(value.x, 1)
        if value.flag then
            monitorUtil.monitor.blit(value.name, "fffff", "44444")
        else
            monitorUtil.monitor.blit(value.name, "00000", "22222")
        end
    end

    if monitorUtil.mainPage.modeSelect.flag then --modePage
        for key, mode in pairs(modelist) do
            monitorUtil.monitor.setCursorPos(2, mode.y)
            if mode.flag then
                monitorUtil.monitor.blit(mode.name, "ffffffffff", "4444444444")
            else
                monitorUtil.monitor.blit(mode.name, "0000000000", "3333333333")
            end
        end

        if properties.mode == modelist.spaceShip.name then
            monitorUtil.monitor.setCursorPos(12, modelist.spaceShip.y)
            if properties.spaceShipLock then
                monitorUtil.monitor.blit(" L", "ff", "33")
            else
                monitorUtil.monitor.blit(" N", "88", "33")
            end
        end

        if properties.mode == modelist.quadFPV.name then
            monitorUtil.monitor.setCursorPos(12, modelist.quadFPV.y)
            if properties.quadAutoHover then
                monitorUtil.monitor.blit(" A", "ff", "33")
            else
                monitorUtil.monitor.blit(" N", "88", "33")
            end
        end
    elseif monitorUtil.mainPage.attIndicator.flag then --attPage
        if monitorUtil.attPage.compass.flag then       --罗盘
            monitorUtil.monitor.setCursorPos(1, 2)
            for i = 1, 15, 1 do
                monitorUtil.monitor.setCursorPos(i, 2)
                monitorUtil.monitor.blit(".", "0", "3")
            end

            local xPoint = math.floor(math.cos(math.rad(attUtil.eulerAngle.yaw)) * 8 + 0.5)
            local zPoint = math.floor(math.sin(math.rad(attUtil.eulerAngle.yaw)) * 8 + 0.5)
            if attUtil.pX.x > 0 then
                monitorUtil.monitor.setCursorPos(8 + zPoint, 2)
                monitorUtil.monitor.blit("W", "0", "3")
            else
                monitorUtil.monitor.setCursorPos(8 - zPoint, 2)
                monitorUtil.monitor.blit("E", "0", "3")
            end

            if attUtil.pX.z > 0 then
                monitorUtil.monitor.setCursorPos(8 + xPoint, 2)
                monitorUtil.monitor.blit("N", "e", "3")
            else
                monitorUtil.monitor.setCursorPos(8 - xPoint, 2)
                monitorUtil.monitor.blit("S", "b", "3")
            end
        elseif monitorUtil.attPage.level.flag then --水平仪
            for i = 1, 128, 1 do
                local yPoint = math.abs(attUtil.eulerAngle.roll) > 90 and -attUtil.pZ.y or attUtil.pZ.y
                monitorUtil.monitor.setCursorPos(8 - math.cos(math.asin(attUtil.pX.y)) * (8 - i),
                    6 - (attUtil.pX.y * 6) - yPoint * (8 - i))
                monitorUtil.monitor.blit(" ", "0", "0")
            end
        end
    elseif monitorUtil.mainPage.settings.flag then --settingPage
        if monitorUtil.settingPage.PD_Tuning.flag then
            properties.spaceShipLock = false
            monitorUtil.monitor.setCursorPos(1, 2)
            monitorUtil.monitor.blit("<<", "24", "33")

            monitorUtil.monitor.setCursorPos(2, 3)
            monitorUtil.monitor.blit("P: --      ++", "1ffffffffffff", "333b53333331e")
            monitorUtil.monitor.setCursorPos(8, 3)
            print(string.format("%0.2f", properties.omega_P))

            monitorUtil.monitor.setCursorPos(2, 4)
            monitorUtil.monitor.blit("D: --      ++", "9ffffffffffff", "333b53333331e")
            monitorUtil.monitor.setCursorPos(8, 4)
            print(string.format("%0.2f", properties.omega_D))

            monitorUtil.monitor.setCursorPos(2, 6)
            monitorUtil.monitor.blit("spaceAcc-   +", "fffffffffffff", "33333333b333e")
            monitorUtil.monitor.setCursorPos(11, 6)
            print(string.format("%0.1f", properties.space_Acc))

            monitorUtil.monitor.setCursorPos(2, 7)
            monitorUtil.monitor.blit("quad_Acc-   +", "fffffffffffff", "33333333b333e")
            monitorUtil.monitor.setCursorPos(11, 7)
            print(string.format("%0.1f", properties.quad_Acc))

            monitorUtil.monitor.setCursorPos(2, 8)
            monitorUtil.monitor.blit("MOVE_D: -   +", "fffffffffffff", "33333333b333e")
            monitorUtil.monitor.setCursorPos(11, 8)
            print(string.format("%0.1f", properties.move_D))
        elseif monitorUtil.settingPage.User_Change.flag then
            monitorUtil.monitor.setCursorPos(1, 2)
            monitorUtil.monitor.blit("<<", "24", "33")

            monitorUtil.monitor.setCursorPos(2, 3)
            monitorUtil.monitor.blit("selectUser:", "fffffffffff", "33333333333")

            for i = 1, 5, 1 do
                if monitorUtil.playerList[i] then
                    local name = monitorUtil.playerList[i].name
                    monitorUtil.monitor.setCursorPos(2, 3 + i)
                    if name == properties.userName then
                        for j = 1, 10, 1 do
                            local tmpChar = name:sub(j, j)
                            if #tmpChar ~= 0 then
                                monitorUtil.monitor.blit(tmpChar, "f", "4")
                            end
                        end
                    else
                        for j = 1, 10, 1 do
                            local tmpChar = name:sub(j, j)
                            if #tmpChar ~= 0 then
                                monitorUtil.monitor.blit(tmpChar, "0", "3")
                            end
                        end
                    end
                end
            end
        elseif monitorUtil.settingPage.HOME_SET.flag then
            monitorUtil.monitor.setCursorPos(1, 2)
            monitorUtil.monitor.blit("<<", "24", "33")
        elseif monitorUtil.settingPage.Simulate.flag then
            monitorUtil.monitor.setCursorPos(1, 2)
            monitorUtil.monitor.blit("<<", "24", "33")

            monitorUtil.monitor.setCursorPos(2, 4)
            monitorUtil.monitor.blit("AirMass-    +", "fffffffffffff", "3333333b3333e")
            monitorUtil.monitor.setCursorPos(10, 4)
            print(string.format("%0.1f", properties.airMass))

            monitorUtil.monitor.setCursorPos(2, 6)
            monitorUtil.monitor.blit("Gravity-    +", "fffffffffffff", "3333333b3333e")
            monitorUtil.monitor.setCursorPos(10, 6)
            print(string.format("%0.1f", properties.quadGravity))

            monitorUtil.monitor.setCursorPos(2, 8)
            monitorUtil.monitor.blit("0_Point-    +", "fffffffffffff", "3333333b3333e")
            monitorUtil.monitor.setCursorPos(10, 8)
            print(string.format("%0.1f", properties.ZeroPoint))
        else
            for key, value in pairs(monitorUtil.settingPage) do
                monitorUtil.monitor.setCursorPos(2, value.y)
                if value.selected then
                    monitorUtil.monitor.blit(value.name, "fffffffffff", "44444444444")
                else
                    monitorUtil.monitor.blit(value.name, "00000000000", "33333333333")
                end
            end
        end
    end

    --reboot and shutdown
    monitorUtil.monitor.setCursorPos(1, 10)
    monitorUtil.monitor.blit("[|]", "eee", "333")
    monitorUtil.monitor.setCursorPos(13, 10)
    monitorUtil.monitor.blit("[R]", "444", "333")
end

monitorUtil.listener = function()
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")

        if y < 2 then
            for key, value in pairs(monitorUtil.mainPage) do
                if x >= value.x and x <= value.x + 4 then
                    value.flag = true
                else
                    value.flag = false
                end
            end
        end

        if monitorUtil.mainPage.modeSelect.flag then
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
                    attUtil.lastPos = attUtil.position
                    attUtil.lastEuler = attUtil.eulerAngle
                    properties.spaceShipLock = not properties.spaceShipLock
                elseif y == modelist.quadFPV.y then
                    properties.quadAutoHover = not properties.quadAutoHover
                end
            end
        elseif monitorUtil.mainPage.settings.flag then
            if monitorUtil.settingPage.PD_Tuning.flag then
                properties.mode = modelist.spaceShip.name
                for k, v in pairs(modelist) do
                    if v.name == modelist.spaceShip.name then v.flag = true
                    else v.flag = false
                    end
                end
                if y == 2 and x < 3 then
                    monitorUtil.settingPage.PD_Tuning.flag = false
                    system.update(system.fileName, properties)
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
            elseif monitorUtil.settingPage.User_Change.flag then
                if y == 2 and x < 3 then
                    monitorUtil.settingPage.User_Change.flag = false
                    system.update(system.fileName, properties)
                end

                if y >= 4 and y <= 8 then
                    local user = monitorUtil.playerList[y - 3]
                    if user then
                        properties.userName = user.name
                    end
                end
            elseif monitorUtil.settingPage.HOME_SET.flag then
                if y == 2 and x < 3 then
                    monitorUtil.settingPage.HOME_SET.flag = false
                    system.update(system.fileName, properties)
                end
            elseif monitorUtil.settingPage.Simulate.flag then
                if y == 2 and x < 3 then
                    monitorUtil.settingPage.Simulate.flag = false
                    system.update(system.fileName, properties)
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
            elseif monitorUtil.settingPage.miniSize.flag then
                --ship.setScale(0.1)
            else
                for key, value in pairs(monitorUtil.settingPage) do
                    if y == value.y then
                        if value.selected then
                            value.flag = true
                            if value == monitorUtil.settingPage.User_Change then
                                if scanner.entities ~= nil then
                                    monitorUtil.playerList = {}
                                    for k, v in pairs(scanner.entities) do
                                        if v.isPlayer then
                                            v.distance = math.sqrt((attUtil.position.x - v.x) ^ 2 +
                                                (attUtil.position.y - v.y) ^ 2 + (attUtil.position.z - v.z) ^ 2)
                                            table.insert(monitorUtil.playerList, 1, v)
                                        end
                                    end
                                    table.sort(monitorUtil.playerList, function(a, b) return a.distance < b.distance end)
                                end
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

        if y == 10 and (x >= 13 or x < 4) then
            monitorUtil.monitor.setBackgroundColor(colors.black)
            monitorUtil.monitor.clear()
            system.update(system.fileName, properties)
            if x >= 13 then
                os.reboot()
            elseif x < 4 then
                os.shutdown()
            end
        end
    end
end

---------main---------
system.init()

function run()
    attUtil.init()
    while true do
        attUtil.getAtt()
        joyUtil.getJoyInput()
        scanner.entities = scanner.scanEntity()
        scanner.commander = scanner.getCommander()
        if toMonitor then
            monitorUtil.refresh()
        end

        if ship.isStatic() then
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
        attUtil.setPreAtt()
        sleep(0.05)
    end
end

if toMonitor then
    monitorUtil.init()
    parallel.waitForAll(run, monitorUtil.listener)
else
    run()
end
