require("myFunction")

---------inner---------
local modelist = {
    spaceShip = 1,
    quadFPV = 2,
    hms_fly = 3,
    follow = 4,
    pointLoop = 5,
    hms_weapon = 6,
    test = "test"
}

local tags = {
    spaceShipFollowMouse = false,
    quadAutoHover = false
}

local toMonitor = peripheral.find("monitor")

local system, property, attUtil, monitorUtil, joyUtil, pdControl, rayCaster, scanner, timeUtil

---------system---------
system = {
    fileName = "dat",
    file = nil
}

system.init = function()
    system.file = io.open(system.fileName, "r")
    if system.file then
        property = textutils.unserialise(system.file:read("a"))
        system.file:close()
    else
        property = system.reset()
        system.update(system.fileName, property)
    end
end

system.reset = function()
    return {
        userName = "fashaodesu",
        mode = modelist.spaceShip,
        HOME = { x = 0, y = 120, z = 0 },
        omega_P = 2,                            --角速度比例, 决定转向快慢
        omega_D = 1.66,                         --角速度阻尼, 低了停的慢、太高了会抖动。标准是松杆时快速停下角速度、且停下时不会抖动
        space_move_P = 2,                       --星舰模式油门速度
        quad_move_P = 1,                        --四轴FPV模式油门强度
        move_D = 1.6,                           --移动阻尼, 低了停的慢、太高了会抖动。标准是松杆时快速停下、且停下时不会抖动
        MAX_MOVE_SPEED = 30,                    --自动驾驶 (点循环、跟随模式) 最大跟随速度
        pointLoopWaitTime = 60,                 --点循环模式-到达目标点后等待时间 (tick)
        rayCasterRange = 128,
        airMass = 1,                            --空气密度 (风阻)
        followRange = { x = -1, y = 0, z = 0 }, --跟随距离
        pointList = {                           --点循环模式，按照顺序逐个前往
            { x = -4499, y = 74, z = -896, yaw = 0,  flip = false }
        }
    }
end

system.update = function(file, obj)
    system.file = io.open(file, "w")
    system.file:write(textutils.serialise(obj))
    system.file:close()
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
            if v.name == property.userName then
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
    eulerOmega = {},
    initPoint = {},
    velocity = {}
}

attUtil.getAtt = function()
    attUtil.mass = ship.getMass()
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
            tags.quadAutoHover = not tags.quadAutoHover
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
    lastPos = ship.getWorldspacePosition(),
    lastEuler = getEulerByMatrix(ship.getRotationMatrix()),
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
    if xVal == 0 and yVal == 0 and zVal == 0 and pdControl.fixCd >= 40 then
        pdControl.gotoPosition(pdControl.lastEuler, pdControl.lastPos)
    else
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

        pdControl.lastPos = attUtil.position
        pdControl.lastEuler = attUtil.eulerAngle
        if xVal == 0 and yVal == 0 and zVal == 0 then
            pdControl.fixCd = pdControl.fixCd + 1
        else
            pdControl.fixCd = 0
        end
    end
end

pdControl.quadUp = function(yVal, p, d, hov)
    p = p * 2
    d = d * 200
    if hov then
        local omegaApplyRot = RotateVectorByQuat(attUtil.quat, { x = 0, y = attUtil.velocity.y, z = 0 })
        pdControl.ySpeed = yVal * p + pdControl.basicYSpeed + -omegaApplyRot.y * d
    else
        pdControl.ySpeed = yVal * p
    end

    ship.applyRotDependentForce(0, pdControl.ySpeed * attUtil.mass, 0)

    pdControl.xSpeed = copysign((attUtil.velocity.x ^ 2) * 10 * property.airMass, -attUtil.velocity.x)
    pdControl.zSpeed = copysign((attUtil.velocity.z ^ 2) * 10 * property.airMass, -attUtil.velocity.z)
    pdControl.ySpeed = copysign((attUtil.velocity.y ^ 2) * 10 * property.airMass, -attUtil.velocity.y)

    ship.applyInvariantForce(pdControl.xSpeed * attUtil.mass,
        pdControl.ySpeed * attUtil.mass,
        pdControl.zSpeed * attUtil.mass)
end

pdControl.rotInner = function(xRot, yRot, zRot, p, d)
    d = d * 10
    pdControl.pitchSpeed = zRot * p + -attUtil.omega.pitch * d
    pdControl.rollSpeed = xRot * p + -attUtil.omega.roll * d
    pdControl.yawSpeed = yRot * p + -attUtil.omega.yaw * d
    ship.applyRotDependentTorque(
        pdControl.rollSpeed * attUtil.mass,
        pdControl.yawSpeed * attUtil.mass,
        pdControl.pitchSpeed * attUtil.mass)
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

    pdControl.rotInner(roll, yaw, pitch, property.omega_P, property.omega_D)
end

pdControl.rotate2Euler2 = function(euler)
    local tmpx = {x = -math.cos(math.rad(euler.yaw)), y = -math.sin(math.rad(euler.pitch)), z = math.sin(math.rad(euler.yaw))}
    local tmpz = {x = math.sin(math.rad(euler.yaw)), y = math.sin(math.rad(euler.roll)), z = -math.cos(math.rad(euler.yaw))}
    local newXpoint = RotateVectorByQuat(attUtil.conjQuat, tmpx)
    local newZpoint = RotateVectorByQuat(attUtil.conjQuat, tmpz)
    local roll = math.deg(math.asin(newZpoint.y))
    local yaw = math.deg(math.atan2(newXpoint.z, -newXpoint.x))
    local pitch = -math.deg(math.asin(newXpoint.y))
    --commands.execAsync(("say roll=%0.2f  yaw=%0.2f  pitch=%0.2f"):format(roll, yaw, pitch))
    pdControl.rotInner(roll, yaw, pitch, property.omega_P, property.omega_D)
end

pdControl.spaceShip = function()
    pdControl.moveWithRot(
        math.deg(math.asin(joyUtil.LT - joyUtil.RT)),
        math.deg(math.asin(joyUtil.l_fb)),
        math.deg(math.asin(joyUtil.LB - joyUtil.RB)),
        property.space_move_P,
        property.move_D)
    pdControl.rotInner(
        math.deg(math.asin(joyUtil.r_lr)),
        math.deg(math.asin(joyUtil.l_lr)),
        math.deg(math.asin(joyUtil.r_fb)),
        property.omega_P,
        property.omega_D)
end


pdControl.quadFPV = function()
    if tags.quadAutoHover then
        if joyUtil.l_fb == 0 then
            tags.quadFpv_Auto_Y = true
            pdControl.quadUp(
                0,
                property.quad_move_P,
                property.move_D,
                true)
        else
            pdControl.quadUp(
                math.deg(math.asin(joyUtil.l_fb)),
                property.quad_move_P,
                property.move_D,
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
            local euler = {roll = -math.deg(math.asin(newVel.z)) * distance, yaw = attUtil.eulerAngle.yaw, pitch = math.deg(math.asin(newVel.x)) * distance}
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
        pdControl.lastPos = attUtil.position
        pdControl.lastEuler = attUtil.eulerAngle
    else
        pdControl.quadUp(
            math.deg(math.asin(joyUtil.l_fb)),
            property.quad_move_P,
            property.move_D,
            false)
        pdControl.rotInner(
            math.deg(math.asin(joyUtil.r_lr)),
            math.deg(math.asin(joyUtil.l_lr)),
            math.deg(math.asin(joyUtil.r_fb)),
            property.omega_P,
            property.omega_D)
    end
end

pdControl.gotoPosition = function(euler, pos)
    local xVal, yVal, zVal
    xVal = (pos.x - attUtil.position.x) * 3.6
    yVal = (pos.y - attUtil.position.y) * 3.6
    zVal = (pos.z - attUtil.position.z) * 3.6
    xVal = math.abs(xVal) > property.MAX_MOVE_SPEED and copysign(property.MAX_MOVE_SPEED, xVal) or xVal
    yVal = math.abs(yVal) > property.MAX_MOVE_SPEED and copysign(property.MAX_MOVE_SPEED, yVal) or yVal
    zVal = math.abs(zVal) > property.MAX_MOVE_SPEED and copysign(property.MAX_MOVE_SPEED, zVal) or zVal

    pdControl.moveWithOutRot(
        xVal,
        yVal,
        zVal,
        property.space_move_P,
        property.move_D
    )
    pdControl.rotate2Euler(euler)
end

pdControl.HmsSpaceBasedGun = function()
    local targetAngle = scanner.getRCAngle(property.rayCasterRange)
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
        property.HOME
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
        property.space_move_P,
        property.move_D)
end

pdControl.follow = function(target)
    local pos, qPos = {}, {}
    qPos.x = copysign(attUtil.size.x / 2, property.followRange.x) + property.followRange.x
    qPos.y = copysign(attUtil.size.y / 2, property.followRange.y) + property.followRange.y
    qPos.z = copysign(attUtil.size.z / 2, property.followRange.z) + property.followRange.z
    pos.x = target.x + qPos.x
    pos.y = target.y + qPos.y
    pos.z = target.z + qPos.z

    pdControl.gotoPosition(
        { roll = 0, yaw = 0, pitch = 0 }, pos)
end

pdControl.pointLoop = function()
    local tgAg, pos = {}, {}
    pos = property.pointList[timeUtil.pointLoopIndex]
    tgAg = { roll = 0, yaw = pos.yaw, pitch = 0 }
    if pos.flip then
        tgAg.pitch = 180
    end
    if math.abs(attUtil.position.x - pos.x) < 0.5 and
        math.abs(attUtil.position.y - pos.y) < 0.5 and
        math.abs(attUtil.position.z - pos.z) < 0.5 then
        if timeUtil.pointLoopWaitTime >= property.pointLoopWaitTime then
            timeUtil.pointLoopWaitTime = 1
            if timeUtil.pointLoopIndex >= #property.pointList then
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
    x = 1,
    y = 1,
    modeIndex = { {}, {}, {}, {}, {}, {} },
    mainPageIndex = { {}, {}, {} },
    mainPage = 1,
    mainPageList = {
        modeSelect = 1,
        attIndicator = 2,
        settings = 3
    }
}

monitorUtil.init = function()
    monitorUtil.monitor = peripheral.find("monitor")
    monitorUtil.monitor.setTextScale(0.5)
    term.redirect(monitorUtil.monitor)
    monitorUtil.monitor.setBackgroundColor(colors.black)

    monitorUtil.monitor.clear()
    monitorUtil.monitor.setCursorPos(5, 3)
    monitorUtil.monitor.blit("WELCOME", "0000000", "fffffff")

    monitorUtil.monitor.setCursorPos(9 - #property.userName / 2, 5)
    monitorUtil.monitor.write(property.userName)

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

    for i = 1, 3, 1 do
        if monitorUtil.mainPage == i then
            monitorUtil.mainPageIndex[i][1] = "fffff"
            monitorUtil.mainPageIndex[i][2] = "44444"
        else
            monitorUtil.mainPageIndex[i][1] = "00000"
            monitorUtil.mainPageIndex[i][2] = "22222"
        end
    end
    monitorUtil.monitor.setCursorPos(1, 1)
    monitorUtil.monitor.blit(" MOD ", monitorUtil.mainPageIndex[1][1], monitorUtil.mainPageIndex[1][2])
    monitorUtil.monitor.setCursorPos(6, 1)
    monitorUtil.monitor.blit(" ATT ", monitorUtil.mainPageIndex[2][1], monitorUtil.mainPageIndex[2][2])
    monitorUtil.monitor.setCursorPos(11, 1)
    monitorUtil.monitor.blit(" SET ", monitorUtil.mainPageIndex[3][1], monitorUtil.mainPageIndex[3][2])

    if monitorUtil.mainPage == monitorUtil.mainPageList.modeSelect then
        for i = 1, 6, 1 do
            if property.mode == i then
                monitorUtil.modeIndex[i][1] = "ffffffffff"
                monitorUtil.modeIndex[i][2] = "4444444444"
            else
                monitorUtil.modeIndex[i][1] = "0000000000"
                monitorUtil.modeIndex[i][2] = "3333333333"
            end
        end

        monitorUtil.monitor.setCursorPos(2, 3)
        monitorUtil.monitor.blit("space_ship", monitorUtil.modeIndex[1][1], monitorUtil.modeIndex[1][2])
        monitorUtil.monitor.setCursorPos(2, 4)
        monitorUtil.monitor.blit("quad_fpv  ", monitorUtil.modeIndex[2][1], monitorUtil.modeIndex[2][2])
        monitorUtil.monitor.setCursorPos(2, 5)
        monitorUtil.monitor.blit("hms_fly   ", monitorUtil.modeIndex[3][1], monitorUtil.modeIndex[3][2])
        monitorUtil.monitor.setCursorPos(2, 6)
        monitorUtil.monitor.blit("follow    ", monitorUtil.modeIndex[4][1], monitorUtil.modeIndex[4][2])
        monitorUtil.monitor.setCursorPos(2, 7)
        monitorUtil.monitor.blit("point_loop", monitorUtil.modeIndex[5][1], monitorUtil.modeIndex[5][2])

        if property.mode == modelist.quadFPV then
            monitorUtil.monitor.setCursorPos(12, 4)
            if tags.quadAutoHover then
                monitorUtil.monitor.blit(" A", "ff", "33")
            else
                monitorUtil.monitor.blit(" N", "88", "33")
            end
        end
    elseif monitorUtil.mainPage == monitorUtil.mainPageList.attIndicator then
        for i = 8, 1, -1 do
            monitorUtil.monitor.setCursorPos(8 + math.floor(attUtil.pX.z * i + 0.5),6 + math.floor(-attUtil.pX.x * (i / 2) + 0.5))
            monitorUtil.monitor.blit(" ", "3", "e")
            monitorUtil.monitor.setCursorPos(8 + math.floor(-attUtil.pZ.z * i + 0.5),6 + math.floor(attUtil.pZ.x * (i / 2) + 0.5))
            monitorUtil.monitor.blit(" ", "3", "b")
            monitorUtil.monitor.setCursorPos(8 + math.floor(-attUtil.pY.z * i + 0.5),6 + math.floor(attUtil.pY.x * (i / 2) + 0.5))
            monitorUtil.monitor.blit(" ", "3", "5")
        end
    end

    monitorUtil.monitor.setCursorPos(1, 10)
    monitorUtil.monitor.blit("[|]", "eee", "333")
    monitorUtil.monitor.setCursorPos(13, 10)
    monitorUtil.monitor.blit("[R]", "444", "333")
end

monitorUtil.listener = function()
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")

        if y < 2 then
            if x <= 5 then
                monitorUtil.mainPage = monitorUtil.mainPageList.modeSelect
            elseif x <= 10 then
                monitorUtil.mainPage = monitorUtil.mainPageList.attIndicator
            else
                monitorUtil.mainPage = monitorUtil.mainPageList.settings
            end
        end

        if monitorUtil.mainPage == monitorUtil.mainPageList.modeSelect then
            if x < 11 then
                if y == 3 then
                    property.mode = modelist.spaceShip
                elseif y == 4 then
                    property.mode = modelist.quadFPV
                elseif y == 5 then
                    property.mode = modelist.hms_fly
                elseif y == 6 then
                    property.mode = modelist.follow
                elseif y == 7 then
                    property.mode = modelist.pointLoop
                end
            else
                if y == 4 then
                    tags.quadAutoHover = not tags.quadAutoHover
                end
            end
        end

        if y == 10 then
            monitorUtil.monitor.setBackgroundColor(colors.black)
            monitorUtil.monitor.clear()
            if x >= 13 then
                os.reboot()
            elseif x < 4 then
                os.shutdown()
            end
        end
        monitorUtil.x, monitorUtil.y = x, y
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

        if property.mode == modelist.spaceShip then
            pdControl.spaceShip()
        elseif property.mode == modelist.quadFPV then
            pdControl.quadFPV()
        elseif property.mode == modelist.hms_fly then
            pdControl.followMouse()
        elseif property.mode == modelist.hms_weapon then
            pdControl.HmsSpaceBasedGun()
        elseif property.mode == modelist.follow then
            pdControl.follow(scanner.commander)
        elseif property.mode == modelist.pointLoop then
            pdControl.pointLoop()
        elseif property.mode == modelist.auto then
            pdControl.gotoPosition(
                { roll = 0, yaw = 120, pitch = 80 },
                property.HOME
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
