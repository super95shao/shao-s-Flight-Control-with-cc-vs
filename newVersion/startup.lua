local engine_controller = peripheral.find("EngineController")
local flight_control, hologram_manager, hologram_prop, controllers, system, properties, monitorUtil, shipNet_p2p_send, scanner, radar
local shutdown_flag, engineOff = false, false
local public_protocol = "shipNet_broadcast"
local protocol, request_protocol = "CBCNetWork", "CBCcenter"
local shipName, computerId = engine_controller.getName(), os.getComputerID()
local shipNet_list = {}
local beat_ct, call_ct, captcha, calling
local childShips, callList, linkedCannons = {}, {}, {}
local dimension = "overworld"
peripheral.find("modem", rednet.open)

local modelist = {
    { name = "SpaceShip",  flag = false },
    { name = "QuadFPV",    flag = false },
    { name = "Helicopter", flag = false },
    { name = "AirShip",    flag = false },
    { name = "Hms_Fly",    flag = false },
    { name = "Follow",     flag = false },
    { name = "GoHome",     flag = false },
    { name = "PointLoop ", flag = false },
    { name = "ShipCamera", flag = false },
    { name = "ShipFollow", flag = false },
    { name = "Anchorage",  flag = false },
    { name = "SpaceFpv",   flag = false },
    { name = "Fixed-wing", flag = false },
}

local entryList = {
    "top",
    "bottom",
    "left",
    "right",
    "front",
    "back"
}

local language = {
    "chinese",
    "english"
}

----------------------------------------------------

local formatN = function(val, n)
    n = math.pow(10, n or 1)
    val = tonumber(val)
    return math.floor(val * n) / n
end

local genStr = function(s, count)
    local result = ""
    for i = 1, count, 1 do
        result = result .. s
    end
    return result
end

local getColorDec = function(paint)
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

local getNextColor = function(color, index)
    local num = string.byte(string.sub(color, 1, 1))
    num = num + index
    if num < 48 then num = 102 end
    if num == 58 then num = 97 end
    if num == 103 then num = 48 end
    if num == 96 then num = 57 end
    return string.char(num)
end

local tableHasValue = function(targetTable, targetValue)
    for index, value in ipairs(targetTable) do
        if index ~= 'metatable' and value == targetValue then
            return true
        end
    end
    return false
end

local joinArrayTables = function(...)
    local entries = {}
    for i = 1, select('#', ...) do
        local t = select(i, ...)
        for _, v in ipairs(t) do
            table.insert(entries, v)
        end
    end
    return entries
end

local arrayTableDuplicate = function(targetTable)
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

local arrayTableRemoveElement = function(targetTable, value)
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

local split = function(input, delimiter)
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

local stringToCharArray = function(str)
    local charArray = {}
    for i = 1, #str do
        charArray[i] = string.sub(str, i, i)
    end
    return charArray
end

table.copy = function (t)
    local tmp = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            local tmpv = table.copy(v)
            tmp[k] = tmpv
        else
            tmp[k] = v
        end
    end
    return tmp
end

local pi2 = math.pi * 2
local resetAngelRange = function(angle)
    if (math.abs(angle) > math.pi) then
        angle = math.abs(angle) >= pi2 and angle % pi2 or angle
        return -copysign(pi2 - math.abs(angle), angle)
    else
        return angle
    end
end

local vector = {}
local newVec = function (x, y, z)
    if type(x) == "table" then
        return setmetatable({ x = x.x, y = x.y, z = x.z}, { __index = vector })
    elseif x and y and z then
        return setmetatable({ x = x, y = y, z = z}, { __index = vector})
    else
        return setmetatable({ x = 0, y = 0, z = 0}, { __index = vector})
    end
end

function vector:zero()
    self.x = 0
    self.y = 0
    self.z = 0
    return self
end

function vector:copy()
    return newVec(self.x, self.y, self.z)
end

function vector:len()
    return math.sqrt(self.x ^ 2 + self.y ^ 2 + self.z ^ 2)
end

function vector:norm()
    local l = self:len()
    if l == 0 then
        self:zero()
    else
        self.x = self.x / l
        self.y = self.y / l
        self.z = self.z / l
    end
    return self
end

function vector:nega()
    self.x = -self.x
    self.y = -self.y
    self.z = -self.z
    return self
end

function vector:add(v)
    self.x = self.x + v.x
    self.y = self.y + v.y
    self.z = self.z + v.z
    return self
end

function vector:sub(v)
    self.x = self.x - v.x
    self.y = self.y - v.y
    self.z = self.z - v.z
    return self
end

function vector:scale(num)
    self.x = self.x * num
    self.y = self.y * num
    self.z = self.z * num
    return self
end

function vector:unpack()
    return self.x, self.y, self.z
end

local unpackVec = function(v)
    return v.x, v.y, v.z
end

local vector2d = {}
function vector2d:len()
    return math.sqrt(self.x ^ 2 + self.y ^ 2)
end

function vector2d:norm()
    local l = self:len()
    if l == 0 then
        self:zero()
    else
        self.x = self.x / l
        self.y = self.y / l
    end
    return self
end

function vector2d:scale(num)
    self.x = self.x * num
    self.y = self.y * num
    return self
end

function vector2d:scaleVec(v)
    self.x = self.x * v.x
    self.y = self.y * v.y
    return self
end

function vector2d:add(v)
    self.x = self.x + v.x
    self.y = self.y + v.y
    return self
end

function vector2d:sub(v)
    self.x = self.x - v.x
    self.y = self.y - v.y
    return self
end

function vector2d:zero()
    self.x = 0
    self.y = 0
    return self
end


local new2dVec = function (x, y)
    if type(x) == "table" then
        return setmetatable({x = x.x, y = x.y}, { __index = vector2d })
    elseif x and y then
        return setmetatable({x = x, y = y}, {__index = vector2d})
    else
        return setmetatable({x = 0, y = 0}, {__index = vector2d})
    end
end

function vector2d:copy()
    return new2dVec(self.x, self.y)
end

local matrixMultiplication = function(m, v)
    return new2dVec(m[1][1] * v.x + m[1][2] * v.y, m[2][1] * v.x + m[2][2] * v.y)
end

local matrixMultiplication_3d = function (m, v)
    return newVec(
        m[1][1] * v.x + m[1][2] * v.y + m[1][3] * v.z,
        m[2][1] * v.x + m[2][2] * v.y + m[2][3] * v.z,
        m[3][1] * v.x + m[3][2] * v.y + m[3][3] * v.z
    )
end

local blockOffset = newVec(0.5, 0.5, 0.5)
----------------------------------------------------
system = {
    files = {
        propFileName = "dat",
        holograms = "holograms",
    },
    file = nil
}

function system:init()
    properties = system.datFromFile(self.files.propFileName)
    hologram_prop = system.datFromFile(self.files.holograms)
    system:updatePersistentData()
end

system.datFromFile = function (fileName)
    local file = io.open(fileName, "r")
    local result
    if file then
        local tmpFile = textutils.unserialise(file:read("a"))
        
        if fileName == "dat" then
            result = system.resetProp()
            for k, v in pairs(result) do
                if tmpFile[k] then
                    result[k] = tmpFile[k]
                end
            end
        elseif fileName == "holograms" then
            result = {}
            for k, v in pairs(tmpFile) do
                result[k] = v
            end
        end

        file:close()
    else
        if fileName == "dat" then
            result = system.resetProp()
        elseif fileName == "holograms" then
            result = {}
        end
    end
    
    return result
end

system.resetProp = function()
    local firstMonitor = peripheral.find("monitor")
    local enabledMonitors = { "computer" }
    if firstMonitor then
        table.insert(enabledMonitors, peripheral.getName(firstMonitor))
    end
    return {
        userName = "fashaodesu",
        holo_eye_pos = newVec(-3, 0, 0),
        mode = 1,
        HOME = { x = 0, y = 120, z = 0 },
        homeList = {
            { x = 0, y = 120, z = 0 }
        },
        enabledMonitors = enabledMonitors,
        winIndex = {},
        profileIndex = "keyboard",
        coupled = true,
        drawHoloBorder = true,
        radarMode = 1,
        radarFov = 90,
        radarRange = 2048,
        radar_lock_mode = true,
        language = language[1],
        password = "123456",
        whiteList = {},
        shipNet_whiteList = {},
        spaceShipThrottle = 3,
        profile = {
            keyboard = {
                spaceShip_P = 1.2,
                spaceShip_D = 2.4,
                spaceShip_forward = 1.5,
                spaceShip_sideMove = 1.5,
                spaceShip_vertMove = 1.5,
                spaceShip_burner = 3.0,
                spaceShip_move_D = 1,
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
                helicopt_ROT_P = 0.3,
                helicopt_ROT_D = 0.5,
                helicopt_MAX_ANGLE = 50,
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
                spaceShip_P = 3,
                spaceShip_D = 6,
                spaceShip_forward = 2,
                spaceShip_sideMove = 2,
                spaceShip_vertMove = 2,
                spaceShip_burner = 3.0,
                spaceShip_move_D = 1.6,
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
                helicopt_ROT_P = 0.3,
                helicopt_ROT_D = 0.5,
                helicopt_MAX_ANGLE = 50,
                helicopt_ACC = 0.5,
                helicopt_ACC_D = 0.75,
                airShip_ROT_P = 1,
                airShip_ROT_D = 0.5,
                airShip_MOVE_P = 1,
                camera_rot_speed = 1,
                camera_move_speed = 0.5,
                shipFollow_move_speed = 0.5,
            }
        },
        lock = false,
        zeroPoint = 0,
        gravity = -2,
        airMass = 1, --空气密度 (风阻)
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

function system:updatePersistentData()
    system.write(self.files.propFileName, properties)
    system.write(self.files.holograms, hologram_prop)
end

system.write = function(file, obj)
    system.file = io.open(file, "w")
    system.file:write(textutils.serialise(obj))
    system.file:close()
end

local quat = {}
function quat.new()
    return { w = 1, x = 0, y = 0, z = 0}
end

function quat.vecRot(q, v)
    local x = q.x * 2
    local y = q.y * 2
    local z = q.z * 2
    local xx = q.x * x
    local yy = q.y * y
    local zz = q.z * z
    local xy = q.x * y
    local xz = q.x * z
    local yz = q.y * z
    local wx = q.w * x
    local wy = q.w * y
    local wz = q.w * z
    local res = {}
    res.x = (1.0 - (yy + zz)) * v.x + (xy - wz) * v.y + (xz + wy) * v.z
    res.y = (xy + wz) * v.x + (1.0 - (xx + zz)) * v.y + (yz - wx) * v.z
    res.z = (xz - wy) * v.x + (yz + wx) * v.y + (1.0 - (xx + yy)) * v.z
    return newVec(res.x, res.y, res.z)
end

function quat.multiply(q1, q2)
    local newQuat = {}
    newQuat.w = -q1.x * q2.x - q1.y * q2.y - q1.z * q2.z + q1.w * q2.w
    newQuat.x = q1.x * q2.w + q1.y * q2.z - q1.z * q2.y + q1.w * q2.x
    newQuat.y = -q1.x * q2.z + q1.y * q2.w + q1.z * q2.x + q1.w * q2.y
    newQuat.z = q1.x * q2.y - q1.y * q2.x + q1.z * q2.w + q1.w * q2.z
    return newQuat
end

function quat.nega(q)
    return {
        w = q.w,
        x = -q.x,
        y = -q.y,
        z = -q.z,
    }
end

local newQuat = function(w, x, y, z)
    if type(w) == "table" then
        return setmetatable({ w = w.w, x = w.x, y = w.y, z = w.z}, { __index = quat })
    else
        return setmetatable({ w = w, x = x, y = y, z = z }, { __index = quat })
    end
end

local DEFAULT_PARENT_SHIP = {
    id = -1,
    name = "",
    pos = newVec(),
    rot = quat.new(),
    preQuat = quat.new(),
    velocity = newVec(),
    anchorage = { offset = newVec(), entry = "top" },
    size = engine_controller.getSize(),
    beat = beat_ct
}

local parentShip = DEFAULT_PARENT_SHIP

local sin2cos = function(s)
    return math.sqrt( 1 - s ^ 2)
end

local applyInvariantForce = function (x, y, z)
    flight_control.all_force = flight_control.all_force + x + y + z
    engine_controller.applyInvariantForce(x, y, z)
end

local applyRotDependentForce = function (x, y, z)
    flight_control.all_force = flight_control.all_force + x + y + z
    engine_controller.applyRotDependentForce(x, y, z)
end

local applyRotDependentTorque = function (x, y, z)
    flight_control.all_force = flight_control.all_force + x + y + z
    engine_controller.applyRotDependentTorque(x, y, z)
end

local absController = { hasUser = false }

function absController:refresh()
    self.hasUser = false
    if self.joy then
        if not pcall(self.joy.hasUser) then
            return
        end
        if self.joy.hasUser() then
            self.joy.setFullPrecision(true)
            self.hasUser = true
            self.LeftStick.x = -self.joy.getAxis(1)
            self.LeftStick.y = -self.joy.getAxis(2)
            self.RightStick.x = -self.joy.getAxis(3)
            self.RightStick.y = -self.joy.getAxis(4)
            self.A = self.joy.getButton(1)
            self.B = self.joy.getButton(2)
            self.X = self.joy.getButton(3)
            self.Y = self.joy.getButton(4)
            self.LB = self.joy.getButton(5)
            self.RB = self.joy.getButton(6)
            self.LT = self.joy.getAxis(5)
            self.RT = self.joy.getAxis(6)
            self.back = self.joy.getButton(7)
            self.start = self.joy.getButton(8)
            self.up = self.joy.getButton(12)
            self.down = self.joy.getButton(14)
            self.left = self.joy.getButton(15)
            self.right = self.joy.getButton(13)
            self.LeftJoyClick = self.joy.getButton(10)
            self.RightJoyClick = self.joy.getButton(11)
        end

        self.LB = self.LB and 1 or 0
        self.RB = self.RB and 1 or 0
        self.BTStick.x = self.LB - self.RB
        self.BTStick.y = self.LT - self.RT

    else
        self.joy.setFullPrecision(false)
        self:defaultOutput()
    end
end

local rotController = function(v, left)
    local ecFace = engine_controller.getFaceRaw()
    local matrix2d = {
        {-ecFace.x, ecFace.z},
        {-ecFace.z, -ecFace.x}
    }
    local matrix2dLeft = {
        {-ecFace.x, -ecFace.z},
        {ecFace.z, -ecFace.x}
    }
    if left then
        return matrixMultiplication(matrix2dLeft, v)
    else
        return matrixMultiplication(matrix2d, v)
    end
end

function absController:rot()
    self.BTStickRot = rotController(self.BTStick, true)
    self.RightStickRot = rotController(self.RightStick)
end

function absController:defaultOutput()
    self.LeftStick = new2dVec()
    self.RightStick = new2dVec()
    self.RightStickRot = new2dVec()
    self.BTStick = new2dVec()
    self.BTStickRot = new2dVec()
    self.LeftJoyClick = false
    self.RightJoyClick = false
    self.LB = 0
    self.RB = 0
    self.LT = 0
    self.RT = 0
    self.back = false
    self.start = false
    self.up = false
    self.down = false
    self.left = false
    self.right = false
    self.A = false
    self.B = false
    self.X = false
    self.Y = false
end

local defController = setmetatable({}, {__index = absController}):defaultOutput()

controllers = {
    controllers = {},
    activated = {}
}
function controllers:getAll()
    local allControllers = {peripheral.find("tweaked_controller")}
    for k, v in pairs(allControllers) do
        self.controllers[k] = setmetatable({ joy = v }, { __index = absController })
        self.controllers[k]:defaultOutput()
    end
end

function controllers:run()
    while true do
        local flag = true
        if self.controllers then
            for k, v in pairs(self.controllers) do
                v:refresh()
                if v.hasUser then
                    v:rot()
                    self.activated = v
                    flag = false
                    break
                end
            end
        end
        
        if flag then
            self.activated = defController
        end
        sleep(0.05)
    end
end

flight_control = {
    mass = 0,
    omega = newVec(),
    hold = false,
    pos = newVec(),
    pX = newVec(),
    pY = newVec(),
    pZ = newVec(),
    rot = quat.new(),
    rot_face = quat.new(),
    lastPos = newVec(),
    lastRot = quat.new(),
    lastForce = newVec(),
    q_yaw = quat.new(),
    lastYaw = 0,
    yaw = 0,
    roll = 0,
    pitch = 0,
    all_force = 0,
    y_point = newVec(0, 1, 0),
    rotMatrix_90 = {
        {0, -1}, {1, 0}
    },
    faceMatrix = {{0, 1},{-1, 0}},
    tmpp = 1 / (math.pi / 2)
}

local getWorldOffsetOfPcPos = function(v)
    local wPos = flight_control.pos:copy()
    local yardPos = newVec(engine_controller.getShipCenter())
    local selfPos = newVec(coordinate.getAbsoluteCoordinates())
    local offset = quat.vecRot(flight_control.rot, yardPos:sub(selfPos):sub(blockOffset):sub(v))
    return wPos:sub(offset)
end

local send_to_childShips = function()
    if #childShips > 0 then
        for k, v in pairs(childShips) do
            local anchorageWorldPos = getWorldOffsetOfPcPos(properties.anchorage_offset)
            local msg = {
                id = computerId,
                name = shipName,
                pos = newVec(flight_control.pos),
                rot = newQuat(flight_control.rot_face),
                preRot = newQuat(flight_control.preRot),
                velocity = newVec(flight_control.velocity),
                size = newVec(flight_control.size),
                anchorage = { pos = anchorageWorldPos, entry = entryList[properties.anchorage_entry] },
                code = v.code
            }
            rednet.send(v.id, msg, public_protocol)
        end
    end
end

function flight_control:pd_rot_control(vec, p, d)
    applyRotDependentTorque(vec:scale(p):sub(self.omega:scale(d)):scale(self.momentOfInertiaTensor[1][1]):unpack())
end

function flight_control:pd_mov_control(vec, p, d)
    applyRotDependentForce(vec:scale(p):sub(self.velocityRot:scale(d)):scale(self.mass):unpack())
end

function flight_control:pd_wolrd_space_control(vec, p, d)
    applyInvariantForce(vec:scale(p):sub(self.velocity:scale(d)):scale(self.mass):unpack())
end

function flight_control:run(phy)
    if engineOff then return end
    self.all_force = 0
    local poseVel = phy.getShipPoseVel()
    local inertia = phy.getInertia()
    for k, v in pairs(poseVel) do
        self[k] = v
    end
    for k, v in pairs(inertia) do
        self[k] = v
    end

    local rowPoint = engine_controller.getFaceRaw()
    self.pX = quat.vecRot(self.rot, rowPoint)
    self.pY = quat.vecRot(self.rot, self.y_point)
    local m = self.rotMatrix_90
    self.pZ = {
        x = m[1][1] * rowPoint.x + m[1][2] * rowPoint.z,
        y = rowPoint.y,
        z = m[2][1] * rowPoint.x + m[2][2] * rowPoint.z,
    }
    self.pZ = quat.vecRot(self.rot, self.pZ)

    self.faceMatrix = {
        {rowPoint.x, rowPoint.z},
        {-rowPoint.z, rowPoint.x}
    }

    self.faceMatrix3d = {
        {rowPoint.x, 0, rowPoint.z},
        {0, 1, 0},
        {-rowPoint.z, 0, rowPoint.x},
    }

    self.yaw = math.deg(math.atan2(self.pX.z, self.pX.x))
    self.pitch = math.deg(math.asin(self.pX.y))
    self.roll = math.deg(math.asin(self.pZ.y))
    self.pitch = self.pY.y > 0 and self.pitch or copysign(180 - math.abs(self.pitch), self.pitch)
    --self.roll = self.pY.y > 0 and self.roll or copysign(180 - math.abs(self.roll), self.roll)

    local yaw_rot = -math.atan2(rowPoint.z, rowPoint.x) / 2
    self.q_yaw = {
        w = math.cos(yaw_rot),
        x = 0,
        y = math.sin(yaw_rot),
        z = 0,
    }

    self.rot_face = quat.multiply(self.rot, self.q_yaw)

    local rot_nega = quat.nega(self.rot)
    self.pos = newVec(poseVel.pos)
    self.velocity = newVec(poseVel.velocity)
    self.velocityRot = quat.vecRot(rot_nega, self.velocity)
    self.omega_raw = self.omega
    self.omega = quat.vecRot(rot_nega, self.omega)
    self.size = engine_controller.getSize()

    self.speed = self.velocity:len()

    if modelist[properties.mode].name == "SpaceShip" then
        self:spaceShip()
    elseif modelist[properties.mode].name == "QuadFPV" then
        self:fpv()
    elseif modelist[properties.mode].name == "Helicopter" then
        self:helicopter()
    elseif modelist[properties.mode].name == "ShipCamera" then
        if parentShip.id ~= -1 then
            self:ShipCamera()
        else
            self:spaceShip()
        end
    elseif modelist[properties.mode].name == "ShipFollow" then
        if parentShip.id ~= -1 then
            self:ShipFollow()
        else
            self:spaceShip()
        end
    end
    
    send_to_childShips()
end

local press_ct_1 = 0
function flight_control:spaceShip()
    dimension = coordinate.getSelfDimensionType()
    local movFor, rotFor = newVec(), newVec()
    local ct = controllers.activated
    local profile = properties.profile[properties.profileIndex]
    
    if properties.lock then
        self:gotoPos(self.lastPos)
        self:gotoRot(self.lastRot)
    else
        if ct then
            if flight_control.hold and press_ct_1 < 1 and (
                math.abs(ct.BTStick.y) > 0.2 or
                math.abs(ct.LeftStick.x) > 0.2 or
                math.abs(ct.RightStick.x) > 0.2 or
                math.abs(ct.RightStick.y) > 0.2) then
                flight_control.hold = false
            end

            if ct.start and press_ct_1 < 1 then
                flight_control.hold = not flight_control.hold
                flight_control:setLastPos()
                press_ct_1 = 30
            end
        end

        if flight_control.hold then
            local rot = self:genRotByEuler(0, self.lastYaw, 0)
            local mov = newVec(self.lastForce.x / 2, self.lastForce.y, self.lastForce.z / 2)
            self:pd_mov_control(mov, 1, profile.spaceShip_move_D)
            self:gotoRot_PD(rot, 1, 18)
        else
            if ct then
                local throttle_level = properties.spaceShipThrottle * 0.33 + 0.01
                local PD_FROM_PROFILE = rotController(new2dVec(profile.spaceShip_forward, profile.spaceShip_sideMove))
                movFor.x = math.deg(math.asin(ct.BTStickRot.y)) * math.abs(PD_FROM_PROFILE.x) * throttle_level
                movFor.y = math.deg(math.asin(ct.LeftStick.y)) * profile.spaceShip_vertMove * throttle_level
                movFor.z = math.deg(math.asin(ct.BTStickRot.x)) * math.abs(PD_FROM_PROFILE.y) * throttle_level
                movFor:scale(0.5)
                if ct.LeftJoyClick then
                    movFor:scale(profile.spaceShip_burner)
                end
                if ct.RightJoyClick and press_ct_1 < 1 then
                    properties.coupled = not properties.coupled
                    press_ct_1 = 30
                end
                if (ct.up or ct.down) and press_ct_1 < 1 then
                    if ct.up then
                         properties.spaceShipThrottle = properties.spaceShipThrottle + 1
                         properties.spaceShipThrottle = properties.spaceShipThrottle > 9 and 9 or properties.spaceShipThrottle
                    else
                        properties.spaceShipThrottle = properties.spaceShipThrottle - 1
                        properties.spaceShipThrottle = properties.spaceShipThrottle < 1 and 1 or properties.spaceShipThrottle
                    end
                    press_ct_1 = 10
                end
        
                rotFor.x = math.asin(ct.RightStickRot.x)
                rotFor.y = math.asin(ct.LeftStick.x)
                rotFor.z = math.asin(ct.RightStickRot.y)
                rotFor:scale(5)
            end
    
            if properties.coupled then
                if dimension ~= "solar_system" then
                    movFor:add(quat.vecRot(quat.nega(self.rot), newVec(0, 10, 0)))
                end
                self:pd_mov_control(movFor:copy(), 1, profile.spaceShip_move_D)
            else
                self:pd_mov_control(movFor:copy(), 1, 0.2)
            end

            self.lastForce = movFor
            self:pd_rot_control(rotFor, profile.spaceShip_P, profile.spaceShip_D)
        end
        if press_ct_1 > 0 then
            press_ct_1 = press_ct_1 - 1
        end
    end
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

local getFpvThrottle = function(mid, t_exp, x)
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

function flight_control:fpv()
    local ct = controllers.activated
    local profile = properties.profile[properties.profileIndex]

    local velocity_tick = self.velocity:copy():scale(0.01666666666666666666666666666667)
    local damping = newVec(velocity_tick.x ^ 2, velocity_tick.y ^ 2, velocity_tick.z ^ 2)
    damping.x = copysign(damping.x, -velocity_tick.x)
    damping.y = copysign(damping.y, -velocity_tick.y)
    damping.z = copysign(damping.z, -velocity_tick.z)
    damping:scale(30):scale(properties.airMass):scale(self.mass)

    local movFor = newVec()
    if ct then
        local rotFor = newVec(
                math.deg(math.asin(ct.RightStickRot.x)),
                math.deg(math.asin(ct.LeftStick.x)),
                -math.deg(math.asin(ct.RightStickRot.y))
            )
        if properties.lock then
            local yf = math.deg(math.asin(ct.LeftStick.y)) + 10
            movFor.y = yf / self.pY.y
            movFor.y = movFor.y == math.huge and yf or movFor.y
            movFor.y = movFor.y - self.velocity.y

            local len2 = math.sqrt(rotFor.x ^ 2 + rotFor.z ^ 2)
            if len2 > 60 then
                rotFor.x = rotFor.x / len2 * 60
                rotFor.z = rotFor.z / len2 * 60
            end
    
            rotFor.x = (rotFor.x - self.roll)
            rotFor.z = -(rotFor.z - self.pitch)

            applyRotDependentTorque(rotFor:scale(3):sub(self.omega:scale(30)):scale(self.momentOfInertiaTensor[1][1]):unpack())
        else
            local throttle
            if properties.zeroPoint == -1 then
                throttle = math.asin((ct.LeftStick.y + 1) / 2) * self.tmpp
            else
                throttle = math.asin(ct.LeftStick.y) * self.tmpp
            end
            throttle = getFpvThrottle(profile.throttle_mid, profile.throttle_expo, throttle) * 2 * profile.max_throttle
            movFor.y = math.deg(throttle)
            
            rotFor:scale(self.tmpp)
            rotFor.x = getRate(profile.roll_rc_rate, profile.roll_s_rate, profile.roll_expo, ct.RightStickRot.x)
            rotFor.y = getRate(profile.yaw_rc_rate, profile.yaw_s_rate, profile.yaw_expo, ct.LeftStick.x)
            rotFor.z = getRate(profile.pitch_rc_rate, profile.pitch_s_rate, profile.pitch_expo, ct.RightStickRot.y)
        
            damping.y = damping.y + (1 + properties.gravity) * 10 * self.mass --重力附加
            applyRotDependentTorque(rotFor:scale(0.5239):sub(self.omega:scale(30)):scale(self.momentOfInertiaTensor[1][1]):unpack())
        end
    else
        local pp = math.abs(self.pY.y)
        pp = pp > 0.3 and pp or 0.3
        movFor.y = 10 / pp
        movFor.y = movFor.y == math.huge and 10 or movFor.y
        movFor.y = movFor.y - self.velocityRot.y
        
        local newVel = self.velocityRot:copy()
        local len = newVel:len()
        newVel = newVel:norm():nega()
        local rotFor = newVec(len * math.asin(newVel.z), 0, len * math.asin(newVel.x))
        rotFor:scale(9)
        rotFor.x = math.abs(rotFor.x) > 89 and copysign(89, rotFor.x) or rotFor.x
        rotFor.z = math.abs(rotFor.z) > 89 and copysign(89, rotFor.z) or rotFor.z

        rotFor.x = (rotFor.x - self.roll)
        rotFor.z = -(rotFor.z - self.pitch)
        local len2 = math.sqrt(rotFor.x ^ 2 + rotFor.z ^ 2)
        if len2 > 60 then
            rotFor.x = rotFor.x / len2 * 60
            rotFor.z = rotFor.z / len2 * 60
        end

        applyRotDependentTorque(rotFor:scale(2):sub(self.omega:scale(30)):scale(self.momentOfInertiaTensor[1][1]):unpack())
    end

    damping = quat.vecRot(quat.nega(self.rot), damping)
    applyRotDependentForce(movFor:scale(self.mass):add(damping):unpack())
end

function flight_control:helicopter()
    local ct = controllers.activated
    local profile = properties.profile[properties.profileIndex]

    local movFor = newVec()
    local rot
    --local localPoint = quat.vecRot(self.rot, newVec(1, 0, 0))
    local localYaw = math.atan2(self.pX.z, self.pX.x)
    if ct then
        local max_ag = math.rad(profile.helicopt_MAX_ANGLE) * 2 / math.pi
        rot = self:genRotByEuler(
            -math.asin(ct.RightStickRot.y * max_ag),
            resetAngelRange(localYaw - math.asin(ct.LeftStick.x) / 2),
            math.asin(ct.RightStickRot.x * max_ag)
        )
        movFor.y = math.deg(math.asin(ct.LeftStick.y)) / 4 * profile.helicopt_ACC + -flight_control.velocityRot.y * profile.helicopt_ACC_D
    else
        rot = self:genRotByEuler(0, localYaw, 0)
    end
    self:gotoRot_PD(rot, profile.helicopt_ROT_P, profile.helicopt_ROT_D * 10)
    movFor.y = movFor.y + 10
    self:pd_mov_control(movFor, 1, 0.05)
end

local cameraQuat = quat.new()
local xOffset = 0
function flight_control:ShipCamera()
    local ct = controllers.activated
    local profile = properties.profile[properties.profileIndex]

    local pos = newVec(parentShip.pos):add(newVec(parentShip.velocity):scale(0.05))
    local maxSize = math.max(parentShip.size.x, parentShip.size.z)
    maxSize = math.max(maxSize, parentShip.size.y)
    local range = newVec(maxSize + xOffset, 0, 0)

    if ct then
        xOffset = xOffset + math.asin(ct.BTStick.y) * profile.camera_move_speed
        xOffset = xOffset < 3 and 3 or xOffset
        xOffset = xOffset > 128 and 128 or xOffset
        range = newVec(maxSize + xOffset, 0, 0)

        local myRot = newVec(
            math.asin(ct.RightStick.x) * profile.camera_rot_speed * 2,
            math.asin(ct.LeftStick.x) * profile.camera_rot_speed,
            math.asin(ct.LeftStick.y) * profile.camera_rot_speed
        )

        myRot:scale(0.05)
        local x_rot = myRot.x / 2
        local qx = {
            w = math.cos(x_rot),
            x = math.sin(x_rot),
            y = 0,
            z = 0
        }
        local y_rot = -myRot.y / 2
        local qy = {
            w = math.cos(y_rot),
            x = 0,
            y = math.sin(y_rot),
            z = 0
        }
        local z_rot = myRot.z / 2
        local qz = {
            w = math.cos(z_rot),
            x = 0,
            y = 0,
            z = math.sin(z_rot)
        }

        local q_rot = quat.multiply(quat.multiply(qx, qy), qz)
        cameraQuat = quat.multiply(cameraQuat, q_rot)
    end
    range = quat.vecRot(cameraQuat, range)
    pos = pos:add(range)
    self:gotoRot_PD(cameraQuat, 2, 24)
    self:gotoPos_PD(pos, 6, 18)
end

function flight_control:ShipFollow()
    local pos = newVec(parentShip.pos):add(newVec(parentShip.velocity):scale(0.05))
    local offset = newVec(properties.shipFollow_offset)
    offset.x = offset.x + parentShip.size.x + flight_control.size.x

    local parentQ = quat.multiply(parentShip.rot, quat.nega(self.q_yaw))
    offset = quat.vecRot(parentQ, offset)
    pos = pos:add(offset)
    self:gotoRot_PD(parentQ, 2, 24)
    self:gotoPos_PD(pos, 12, 12)
end

function flight_control:gotoPos(pos)
    self:gotoPos_PD(pos, 1, 6)
end

function flight_control:gotoPos_PD(pos, p, d)
    local tg = self.pos:copy():sub(pos)
    tg = tg:len() > 299 and tg:norm():scale(299) or tg
    self:pd_wolrd_space_control(tg:nega():scale(10):add(newVec(0, 10, 0)), p, d)
end

function flight_control:gotoRot(rot)
    self:gotoRot_PD(rot, 1, 18)
end

function flight_control:gotoRot_PD(rot, p, d)
    local selfRot = newQuat(self.rot.w, self.rot.x, self.rot.y, self.rot.z)
    local xp, zp = quat.vecRot(selfRot, newVec(1, 0, 0)), quat.vecRot(selfRot, newVec(0, 0, 1))
    xp = quat.vecRot(quat.nega(rot), xp)
    zp = quat.vecRot(quat.nega(rot), zp)
    local xRot = math.deg(math.asin(zp.y))
    local yRot = math.deg(math.atan(xp.z, xp.x))
    local zRot = -math.deg(math.asin(xp.y))
    self:pd_rot_control(newVec(xRot, yRot, zRot), p, d)
end

function flight_control:genRotByEuler(pitch, yaw, roll)
    local cosp = math.abs(math.cos(pitch))
    local cosr = math.abs(math.cos(roll))
    local xp = newVec(-math.cos(yaw) * cosp, math.sin(pitch), math.sin(yaw) * cosp)
    local zp = newVec(-math.sin(yaw) * cosr, math.sin(roll), -math.cos(yaw) * cosr)
    --commands.execAsync(("say %.2f %.2f %.2f"):format(xp.x, xp.y, xp.z))
    --commands.execAsync(("say %.2f %.2f %.2f"):format(zp.x, zp.y, zp.z))
    --xp = matrixMultiplication_3d(self.faceMatrix3d, xp)
    --zp = matrixMultiplication_3d(self.faceMatrix3d, zp)
    local halfR = math.asin(zp.y) / 2
    local xRot = newQuat(math.cos(halfR), math.sin(halfR), 0, 0)
    local halfY = math.atan2(xp.z, xp.x) / 2
    local yRot = newQuat(math.cos(halfY), 0, math.sin(halfY), 0)
    local halfP = -math.asin(xp.y) / 2
    local zRot = newQuat(math.cos(halfP), 0, 0, math.sin(halfP))
    return quat.multiply(quat.multiply(yRot, xRot), zRot)
end

function flight_control:setLastPos()
    self.lastPos = self.pos
    self.lastRot = self.rot
    self.lastYaw = math.atan2(self.pX.z, self.pX.x)
end
--------------------------------------------------

scanner = {
    vsShips = {},
    monsters = {},
    players = {},
    commander = {},
    preMonster = {},
    preplayers = {},
}

function scanner:getPlayer(range)
    self.players = coordinate.getPlayers(range)

    for k, v in pairs(self.preplayers) do
        v.flag = false
    end

    if self.players ~= nil then
        for k, v in pairs(self.players) do
            if scanner.preplayers[k] then
                v.velocity = {
                    x = v.x - scanner.preplayers[v.uuid].x,
                    y = v.y - scanner.preplayers[v.uuid].y,
                    z = v.z - scanner.preplayers[v.uuid].z
                }
            else
                v.velocity = newVec()
            end
            v.flag = true
            scanner.preplayers[v.uuid] = v
        end
    end

    for k, v in pairs(self.preplayers) do
        if not v.flag then
            self.preplayers[k] = nil
        end
    end

    return self.players
end

function scanner:getMonster(scope)
    self.monsters = coordinate.getMonster(scope)

    for k, v in pairs(self.preMonster) do
        v.flag = false
    end

    if scanner.monsters ~= nil then
        for k, v in pairs(scanner.monsters) do
            if scanner.preMonster[k] then
                v.velocity = {
                    x = v.x - scanner.preMonster[v.uuid].x,
                    y = v.y - scanner.preMonster[v.uuid].y,
                    z = v.z - scanner.preMonster[v.uuid].z
                }
            else
                v.velocity = newVec()
            end
            v.flag = true
            scanner.preMonster[v.uuid] = v
        end
    end

    for k, v in pairs(self.preMonster) do
        if not v.flag then
            self.preMonster[k] = nil
        end
    end

    return self.monsters
end

function scanner:getCommander()
    self:getPlayer()
    for k, v in pairs(self.players) do
        if v.name == properties.userName then
            self.commander = v
            return self.commander
        end
    end
end

function scanner:get_commander_eye_pos()
    if self.commander then
        if self.commander.isPassenger then
            local eyePos = newVec(self.commander):add(quat.vecRot(flight_control.rot, newVec(0, self.commander.eyeHeight, 0)))
            self.commander.x = eyePos.x
            self.commander.y = eyePos.y
            self.commander.z = eyePos.z
        else
            self.commander.y = self.commander.y + self.commander.eyeHeight
        end
    end
end

function scanner:getShips(range)
    if not coordinate then
        return
    end
    local ships
    if dimension == "overworld" then
        ships = coordinate.getShips(range)
    else
        ships = coordinate.getShipsAll(range)
    end

    for k, v in pairs(scanner.vsShips) do
        v.flag = false
    end

    for k, v in pairs(ships) do
        if scanner.vsShips[v.id] then
            v.velocity = {
                x = v.x - scanner.vsShips[v.id].x,
                y = v.y - scanner.vsShips[v.id].y,
                z = v.z - scanner.vsShips[v.id].z
            }
        else
            v.velocity = {
                x = 0,
                y = 0,
                z = 0
            }
        end
        v.flag = true
        v.name = v.slug
        scanner.vsShips[v.id] = v
    end

    for k, v in pairs(scanner.vsShips) do
        if not v.flag then
            scanner.vsShips[k] = nil
        end
    end
    return scanner.vsShips
end

local max_fov_holo = {fov = 0}
radar = { targets = {}, final_targets = {}, other_targets = {} }
function radar:run()
    local press_ct = 0
    while true do
        if max_fov_holo.name then
            local fire = false
            local ct = controllers.activated
            
            if ct then
                if (ct.left or ct.right or ct.Y) and press_ct < 1 then
                    if ct.left then
                        properties.radarMode = properties.radarMode - 1
                        properties.radarMode = properties.radarMode < 1 and 4 or properties.radarMode
                    elseif ct.right then
                        properties.radarMode = properties.radarMode + 1
                        properties.radarMode = properties.radarMode > 4 and 1 or properties.radarMode
                    elseif ct.Y then
                        properties.radar_lock_mode = not properties.radar_lock_mode
                    end
                    press_ct = 10
                    system:updatePersistentData()
                elseif ct.A then
                    fire = true
                elseif ct.back and press_ct < 1 then
                    for k, v in pairs(hologram_manager.holograms) do
                        v.screen.SetClearColor(0xFF1111FF)
                        v.screen.Clear()
                        v.screen.Flush(true)
                        v.screen.SetClearColor(0x00000000)
                    end
                    press_ct = 10
                end
            end

            if press_ct > 0 then
                press_ct = press_ct - 1
            end

            local isShip = false
            local targets = {}
            if properties.radarMode == 1 then --nil
                targets = nil
            elseif properties.radarMode == 2 then --vs_ship
                isShip = true
                targets = scanner:getShips(properties.radarRange)
            elseif properties.radarMode == 3 then --monster
                targets = scanner:getMonster(properties.radarRange)
            elseif properties.radarMode == 4 then --player
                targets = scanner:getPlayer(properties.radarRange)
            end

            self.targets = {}
            if targets then
                local tan = math.tan(max_fov_holo.fov)
                local count = 0
                for k, v in pairs(targets) do
                    local flag = true
                    if isShip then
                        for __, slug in pairs(properties.whiteList) do
                            if v.slug == slug then
                                flag = false
                            end
                        end
                    end

                    if flag then
                        local pos = max_fov_holo:offset_from_self(newVec(v)):sub(max_fov_holo.eye_offset)
                        local max_d = pos.x * tan
                        if pos.x > 4 and math.abs(pos.z) < max_d and math.abs(pos.y) < max_d then
                            count = count + 1
                            v.id = v.id and v.id or v.uuid
                            v.center_dis = math.sqrt(pos.y ^ 2 + pos.z ^ 2) / pos.x
                            table.insert(self.targets, v)
                        end
                    end
                end

                table.sort(self.targets, function(a, b) return a.center_dis < b.center_dis end)
            else
                self.targets = nil
            end

            self.final_targets = {}
            local target_count = 0
            if properties.radar_lock_mode then
                target_count = 1
            else
                target_count = #linkedCannons
            end

            if self.targets and target_count > 0 then
                target_count = target_count < #self.targets and target_count or #self.targets
                for i = 1, target_count, 1 do
                    self.targets[i].y = self.targets[i].y
                    self.final_targets[i] = self.targets[i]
                end
            else
                self.final_targets = nil
            end

            if self.targets then
                self.other_targets = {}
                local startIndex = self.final_targets and #self.final_targets + 1 or 1
                for i = startIndex, #self.targets, 1 do
                    table.insert(self.other_targets, self.targets[i])
                end
            else
                self.other_targets = nil
            end

            if self.final_targets then
                local len = #self.final_targets
                for i = 1, #linkedCannons, 1 do
                    local index = i % len == 0 and len or i % len
                    local tg = self.final_targets[index]
                    if tg then
                        rednet.send(linkedCannons[i].id, {
                            tgPos = newVec(tg.x, tg.y, tg.z),
                            velocity = tg.velocity,
                            mode = 3,
                            fire = fire,
                            rot = flight_control.rot,
                            raw_face = engine_controller.getFaceRaw(),
                            pos = flight_control.pos,
                            omega = flight_control.omega_raw,
                            center_velocity = flight_control.velocity,
                        }, protocol)
                    end
                end
            end

            sleep(0.05)
        else
            sleep(0.1)
        end
        
    end
end

--------------------------------------------------
local jizhi_7x7_fonts = {
_4f60 = {
    0,1,0,1,0,0,0,0,1,0,1,1,1,1,1,1,1,0,1,0,1,0,1,0,0,1,0,0,0,1,0,1,1,1,0,0,1,1,0,1,0,1,0,1,0,1,1,0,0,},
_597d = {
    0,0,1,0,1,1,1,0,0,1,0,0,0,1,1,1,1,1,0,1,0,0,1,0,1,1,1,1,0,1,1,0,0,1,0,0,0,1,1,0,1,0,1,1,0,0,1,1,0,},
_9ad8 = {
    0,0,0,1,0,0,0,1,1,1,1,1,1,1,0,0,1,0,1,0,0,0,0,1,1,1,0,0,1,1,1,1,1,1,1,1,0,1,0,1,0,1,1,0,1,1,1,0,1,},
_5ea6 = {
    0,0,0,0,1,0,0,0,1,1,1,1,1,1,0,1,0,1,0,1,0,0,1,1,1,1,1,1,0,1,0,1,0,1,0,0,1,0,0,1,0,0,1,0,1,1,0,1,1,},
_901f = {
    1,0,0,0,1,0,0,0,1,1,1,1,1,1,0,0,1,0,1,0,1,1,1,1,1,1,1,1,0,1,0,1,1,1,0,0,1,1,0,1,0,1,1,0,1,1,1,1,1,},
_7c73 = {
    0,1,0,1,0,1,0,0,0,1,1,1,0,0,1,1,1,1,1,1,1,0,0,0,1,0,0,0,0,0,1,1,1,0,0,1,1,0,1,0,1,1,0,0,0,1,0,0,0,},
_2f = {
    0,0,0,0,0,1,0,0,0,0,0,1,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,1,0,0,0,0,0,},
_65e0 = {
    0,1,1,1,1,1,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,1,1,1,1,1,1,1,0,0,0,1,1,0,0,0,0,1,0,1,0,1,1,1,0,0,1,1,1,}, --无
_96f7 = {
   0,0,1,1,1,0,0,1,1,1,1,1,1,1,1,0,1,0,1,0,1,0,0,0,0,0,0,0,0,1,1,1,1,1,0,0,1,0,1,0,1,0,0,1,1,1,1,1,0,}, --雷
_8fbe = {
 1,0,0,0,1,0,0,1,0,0,0,1,0,0,0,0,1,1,1,1,1,1,0,0,0,1,0,0,1,0,0,1,0,1,0,1,0,1,0,0,0,1,1,1,1,1,1,1,1,}, --达
_74e6 = {
    1,1,1,1,1,1,1,0,1,0,0,0,0,0,0,1,1,1,1,1,0,0,1,0,0,0,1,0,0,1,0,1,0,1,0,0,1,0,0,0,1,0,0,1,1,1,0,1,1,}, --瓦
_5c14 = {
    0,1,0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,1,0,0,1,0,0,0,1,0,0,0,0,1,0,1,0,1,0,1,0,0,1,0,0,1,0,0,1,1,0,0,0,}, --尔
_57fa = {
    0,0,1,0,1,0,0,0,1,1,1,1,1,0,0,0,1,0,1,0,0,1,1,1,1,1,1,1,0,1,0,0,0,1,0,1,0,0,1,0,0,1,0,0,1,1,1,0,0,}, --基
_91cc = {
    0,1,1,1,1,1,0,0,1,0,1,0,1,0,0,1,1,1,1,1,0,0,1,0,1,0,1,0,0,1,1,1,1,1,0,0,0,0,1,0,0,0,1,1,1,1,1,1,1,}, --里
_602a = {
    0,1,1,1,1,1,0,1,1,0,1,0,1,0,1,1,0,0,1,0,0,0,1,1,1,0,1,1,0,1,0,1,1,1,0,0,1,0,0,1,0,0,0,1,1,1,1,1,1,}, --怪
_7269 = {
    1,1,0,1,0,0,0,1,1,0,1,1,1,1,1,1,1,0,1,1,1,0,1,0,0,1,1,1,1,1,0,1,0,1,1,0,1,1,0,1,0,1,0,1,0,1,0,1,1,}, --物
_73a9 = {
    0,0,0,1,1,1,0,1,1,0,0,0,0,0,0,1,1,1,1,1,1,1,1,0,1,0,1,0,0,1,0,1,0,1,0,1,1,0,1,0,1,0,0,0,1,0,0,1,1,}, --玩
_5bb6 = {
    0,0,0,1,0,0,0,1,1,1,1,1,1,1,1,0,1,1,1,0,1,0,0,1,1,0,0,0,1,1,0,1,1,0,1,0,0,1,0,1,1,0,1,1,0,1,1,0,1,}, --家
}

local my_5x5_letter = {
["_cross"] ={ 1, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1,},
["_cross_box"] = { 1, 1, 0, 1, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0, 1, 1,},
["_"] = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1,},
["-"] = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,},
["/"] = { 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0,},
["<"] = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0,},
[">"] = { 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0,},
["a"] = { 0, 1, 1, 1, 0, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1,},
["b"] = { 1, 1, 1, 1, 0, 1, 0, 0, 0, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 1, 1, 1, 1, 1, 0,},
["c"] = { 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1,},
["d"] = { 1, 1, 1, 1, 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 0,},
["e"] = { 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1,},
["f"] = { 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0,},
["g"] = { 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 0, 0, 0, 1, 0, 1, 1, 1, 1,},
["h"] = { 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1,},
["i"] = { 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 1, 1,},
["j"] = { 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0,},
["k"] = { 1, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 1,},
["l"] = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1,},
["m"] = { 1, 0, 0, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1,},
["n"] = { 1, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 0, 1, 0, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 1,},
["o"] = { 0, 1, 1, 1, 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0,},
["p"] = { 1, 1, 1, 1, 0, 1, 0, 0, 0, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0,},
["q"] = { 0, 1, 1, 1, 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0, 1, 1, 0, 1,},
["r"] = { 1, 1, 1, 1, 0, 1, 0, 0, 0, 1, 1, 1, 1, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 1,},
["s"] = { 0, 1, 1, 1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0,},
["t"] = { 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0,},
["u"] = { 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0},
["v"] = { 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0,},
["w"] = { 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0,},
["x"] = { 1, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1,},
["y"] = { 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0,},
["z"] = { 1, 1, 1, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 1, 1,},
["0"] = { 0, 0, 1, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 1, 1, 0,},
["1"] = { 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0,},
["2"] = { 0, 0, 1, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 1,},
["3"] = { 0, 3, 3, 3, 0, 0, 0, 0, 0, 3, 0, 0, 3, 3, 3, 0, 0, 0, 0, 3, 0, 3, 3, 3, 0,},
["4"] = { 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1,},
["5"] = { 0, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, },
["6"] = { 0, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1, 1, 1, 1, 0, 1, 0, 0, 1, 0, 1, 1, 1, 1, },
["7"] = { 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, },
["8"] = { 0, 1, 1, 1, 1, 0, 1, 0, 0, 1, 0, 1, 1, 1, 1, 0, 1, 0, 0, 1, 0, 1, 1, 1, 1, },
["9"] = { 0, 1, 1, 1, 1, 0, 1, 0, 0, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, },
}

local my_4x5_number = {
{0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0,},
{0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0,},
{0, 1, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 1, 1, 1,},
{1, 1, 1, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1,},
{1, 0, 0, 1, 1, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1,},
{1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1,},
{1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1,},
{1, 1, 1, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0,},
{1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1,},
{1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1,}
}

local filterString = function(str)
    return string.gsub(str, "[^%w/%-_]", "")
end

local BakeBitMap = function(buf, color)
    local b = {}
    local i = 0
    for _, v in ipairs(buf) do
        if v > 0 then
            b[i] = color
        else
            b[i] = 0x00000000
        end
        i = i + 1
    end
    return b
end

for k, v in pairs(jizhi_7x7_fonts) do
    jizhi_7x7_fonts[k] = BakeBitMap(v, 0xFFFFFFFF)
end

local my_5x5_letter_white = {}
local my_5x5_letter_red = {}
for k, v in pairs(my_5x5_letter) do
    my_5x5_letter[k] = BakeBitMap(v, 0x33FFFFFF)
    my_5x5_letter_white[k] = BakeBitMap(v, 0xFFFFFFFF)
    my_5x5_letter_red[k] = BakeBitMap(v, 0xFF1111FF)
end

local my_4x5_number_white = {}
for k, v in pairs(my_4x5_number) do
    my_4x5_number[k] = BakeBitMap(v, 0x33FFFFFF)
    my_4x5_number_white[k] = BakeBitMap(v, 0xFFFFFFFF)
end

local absAttLine = {
    raw = {},
    list = {},
    move = {}
}

function absAttLine:transform(m, flag)
    self.list = {}
    for k, v in pairs(self.move) do
        self.list[k] = matrixMultiplication(m, v)
    end

    if flag then
        self:vertMir()
        for k, v in pairs(self.mir) do
            self.mir[k] = matrixMultiplication(m, v)
        end
    end
end

function absAttLine:mov(vec)
    for k, v in pairs(self.raw) do
        self.move[k] = new2dVec(v.x + vec.x, v.y + vec.y)
    end
end

function absAttLine:vertMir()
    self.mir = {}
    for k, v in pairs(self.move) do
        table.insert(self.mir, new2dVec(-v.x, v.y))
    end
end

local newAbsAttLine = function (t)
    return setmetatable({ raw = t, list = {}, move = {} }, { __index = absAttLine})
end

local abs2dVecGroup = { raw = {}, list = {} }
function abs2dVecGroup:transform(m)
    for k, v in pairs(self.list) do
       self.list[k] = matrixMultiplication(m ,v)
    end
end
local new2dVecGroup = function (t)
    return setmetatable({ raw = t, list = t }, { __index = abs2dVecGroup})
end
local new_lock_box = function ()
    return new2dVecGroup(
        {
            new2dVec(-0.2, -0.2),
            new2dVec(0.2, -0.2),
            new2dVec(0.2, 0.2),
            new2dVec(-0.2, 0.2),
            new2dVec(-0.2, -0.2)
        }
    )
end
local new_other_lock_box = function ()
    return new2dVecGroup(
        {
            new2dVec(-0.01, 0),
            new2dVec(0, -0.01),
            new2dVec(0.01, 0),
        }
    )
end
local cross_box = new2dVecGroup(
    {
        new2dVec(-0.01, -0.00866),
        new2dVec(0.01, -0.00866),
        new2dVec(0, 0.00866),
        new2dVec(-0.01, -0.00866),
    }
)
--------------------------------------------------
local absHoloGram = {}

function absHoloGram:initData()
    self.width = 384
    self.height = 256
    self.rotation = newVec()
    self.translation = newVec(0, 1, 0)
    self.scale = 2
    self.bg = {
        r = 0,
        g = 0,
        b = 0,
        a = 0
    }
    self.eye_offset = newVec(2, 0.12, 0)
    self.attBorder = new2dVec(0.1, 0.1)
    self.msg_bar_offset = 0.9
    self.cannon_bar_offset = 0.6
    self.target_bar_offset = 0.85
    self.attSize = 1
    self.lint_interval = 5
    self.drawHoloBorder = true
    self.drawInputLine = true
    self.rgb_lock_box = true
    self.other_targets = true
end

function absHoloGram:init()
    self:initData()
    self:checkProp()
    self.midPoint = new2dVec(self.width / 2, self.height / 2)
    self.heightPos = new2dVec(0.8, 0):scaleVec(self.midPoint):add(self.midPoint)
    self.hightFontPos = new2dVec(0.8, 0.05):scaleVec(self.midPoint):add(self.midPoint)
    self.speedPos = new2dVec(-0.9, self.msg_bar_offset):scaleVec(self.midPoint):add(self.midPoint)
    self.speedFontPos = new2dVec(-0.75, self.msg_bar_offset-0.01):scaleVec(self.midPoint):add(self.midPoint)
    self.energyPos = new2dVec(0.85, self.msg_bar_offset):scaleVec(self.midPoint):add(self.midPoint)
    self.energyFontPos = new2dVec(0.85, self.msg_bar_offset+0.05):scaleVec(self.midPoint):add(self.midPoint)
    self.massPos = new2dVec(0.85, self.msg_bar_offset-0.1):scaleVec(self.midPoint):add(self.midPoint)
    self.radarPos_left = new2dVec(-0.2, self.msg_bar_offset):scaleVec(self.midPoint):add(self.midPoint)
    self.radarPos_right = new2dVec(0.2, self.msg_bar_offset):scaleVec(self.midPoint):add(self.midPoint)
    self.radarModePos = new2dVec(0, self.msg_bar_offset):scaleVec(self.midPoint):add(self.midPoint)
    self.eye_offset = newVec(self.eye_offset)
    self.eye_offset.x = -math.abs(self.eye_offset.x)
    self.eye_len = self.eye_offset:len()
    self.eye_pitch_offset = math.tan(math.asin(self.eye_offset.y / self.eye_len)) * self.eye_offset.x / 2 * self.midPoint.y / self.scale

    self.cannonCountPos = new2dVec(-0.9, self.cannon_bar_offset):scaleVec(self.midPoint):add(self.midPoint)
    self.targetPos = new2dVec(0, self.target_bar_offset):scaleVec(self.midPoint):add(self.midPoint)
    local per_pix_for_pers = 1 / self.midPoint.y
    local hp_h = copysign(math.abs(self.target_bar_offset) + 6 * per_pix_for_pers, self.target_bar_offset)
    self.hp_pos_start = new2dVec(-0.3, hp_h):scaleVec(self.midPoint):add(self.midPoint)
    self.hp_pos_end = new2dVec(0.3, hp_h):scaleVec(self.midPoint):add(self.midPoint)
    self.hp_bar_len = 0.6
    self.hp_text_start = new2dVec(-0.3 - 12 * per_pix_for_pers, hp_h):scaleVec(self.midPoint):add(self.midPoint)
    self.hp_text_end = new2dVec(0.3 + 12 * per_pix_for_pers, hp_h):scaleVec(self.midPoint):add(self.midPoint)
    
    self.ThrottlePos = new2dVec(0.4, self.msg_bar_offset):scaleVec(self.midPoint):add(self.midPoint)
    self.ThrottleFontPos = new2dVec(0.4 + 20 * per_pix_for_pers, self.msg_bar_offset + 2 * per_pix_for_pers):scaleVec(self.midPoint):add(self.midPoint)
    self.holdingPos = new2dVec(-0.4, self.msg_bar_offset):scaleVec(self.midPoint):add(self.midPoint)

    self.borders = { full = new2dVec(0, 0), attBorder = self.attBorder }
    for k, v in pairs(self.borders) do
        self.borders[k] = new2dVec(v.x * self.width, v.y * self.height)
    end

    local bgColor = tonumber(string.format("%x%x%x%x", self.bg.r, self.bg.g, self.bg.b, self.bg.a), 16)
    self.screen.SetClearColor(bgColor)
    self.screen.Resize(self.width, self.height)
    local sc = (16 / self.width) * self.scale
    self.screen.SetScale(sc, sc)
    local translat_t = { x = -self.translation.z, y = self.translation.y, z = self.translation.x}
    self.screen.SetTranslation(unpackVec(translat_t))
    self.screen.SetRotation(unpackVec(self.rotation))

    self.fov = math.acos(math.abs(self.eye_offset.x) / math.sqrt(self.eye_offset.x ^ 2 + (self.scale * 0.5) ^ 2))
    if self.fov > max_fov_holo.fov then
        max_fov_holo = self
    end
    self.locked_list = {}
    self.other_list = {}

    self.attLines = {
        line_center = newAbsAttLine({
            new2dVec(0.1, 0),
            new2dVec(0.3, 0),
        }),
        line_l_top = newAbsAttLine({
                new2dVec(0.1, 0),
                new2dVec(0.15, 0),
                new2dVec(0.15, 0.015),
            }),
        line_l_bottom = newAbsAttLine({
                new2dVec(0.1, 0),
                new2dVec(0.15, 0),
                new2dVec(0.15, -0.015),
            }),
        }

    for k, v in pairs(self.attLines) do
        for _, v2 in pairs(v.raw) do
            v2:scale(self.attSize)
        end
    end

    self.boxDisOffset = 0.035 * self.width

    self.attNumberXPos = -(self.attLines.line_l_top.raw[2].x + 0.0625 * 12 * (16 / self.width))
    self:refresh()
end

function absHoloGram:checkProp()
    if hologram_prop[self.name] then
        for k, v in pairs(hologram_prop[self.name]) do
            if k ~= "screen" and self[k] then
                self[k] = v
            end
        end

        for k, v in pairs(self) do
            if k ~= "screen" then
                if not hologram_prop[self.name][k] then
                    if type(v) == "table" then
                        hologram_prop[self.name][k] = table.copy(v)
                    else
                        hologram_prop[self.name][k] = v
                    end
                end
            end
        end
    else
        hologram_prop[self.name] = {
            width = self.width,
            height = self.height,
            rotation = newVec(self.rotation),
            translation = newVec(self.translation),
            scale = self.scale,
            bg = table.copy(self.bg),
            eye_offset = self.eye_offset,
            lint_interval = self.lint_interval,
            drawHoloBorder = self.drawHoloBorder,
            drawInputLine = self.drawInputLine,
            rgb_lock_box = self.rgb_lock_box,
            other_targets = self.other_targets,
            attBorder = self.attBorder,
            attSize = self.attSize,
            msg_bar_offset = self.msg_bar_offset,
            cannon_bar_offset = self.cannon_bar_offset,
            target_bar_offset = self.target_bar_offset,
        }
    end
end

function absHoloGram:refresh()
    self:getSelfPos()

    self.screen.Clear()
    self:radarPage()
    self:attPage()
    self:drawCannon()

    if self.drawHoloBorder then
        self:drawBorder()
    end
    --self.screen.DrawLine(0, self.midPoint.y, self.width, self.midPoint.y, 0x33FFFFFF)
    --self.screen.DrawLine(self.midPoint.x, 0, self.midPoint.x, self.height, 0x33FFFFFF)
    --self:draw_number(new2dVec(1,1), math.floor(flight_control.pitch * 100))
    self.screen.Flush()
end

local genParticle = function(x, y, z)
    commands.execAsync(string.format("particle electric_spark %0.6f %0.6f %0.6f 0 0 0 0 0 force", x, y, z))
end

local holoOffset = newVec(0, 1, 0)
function absHoloGram:getSelfPos()
    local offset = newVec(engine_controller.getShipCenter()):sub(newVec(self.screen.GetBlockPos())):sub(blockOffset):sub(vector.copy(self.translation):add(holoOffset))
    self.worldPos = flight_control.pos:copy():sub(quat.vecRot(flight_control.rot, offset))
    --genParticle(self.worldPos:unpack())
end

function absHoloGram:offset_from_self(v)
    return matrixMultiplication_3d(flight_control.faceMatrix3d, quat.vecRot(quat.nega(flight_control.rot), v:copy():sub(self.worldPos)))
end

function absHoloGram:attPage()
    local eho = newVec(self.eye_offset.x, 0, self.eye_offset.z) --eye_holoCenter_offset
    eho.y = quat.vecRot(flight_control.rot, newVec(0, self.eye_offset.y / 4, 0)).y

    local len2dy = math.sqrt(flight_control.pY.y ^ 2 + flight_control.pZ.y ^ 2)
    local yy = -flight_control.pZ.y / len2dy
    local sinR, cosR = yy, sin2cos(yy)
    if flight_control.pY.y > 0 then
        cosR = -cosR
    end
    local m = {{cosR, -sinR}, {sinR, cosR}}

    local eye_err = math.asin(eho.y / math.sqrt(eho.x ^ 2 + eho.z ^ 2 + eho.y ^ 2))
    local tmpCross_y = eho.x * math.tan(eye_err)
    local tmpCross = new2dVec(0, -tmpCross_y * 2 / self.scale)
    self.crossPos = matrixMultiplication(m, tmpCross):scale(self.midPoint.x):add(self.midPoint)

    local o_ag = math.asin(flight_control.pX.y) - eye_err
    local eye_offset = (eho.x * math.tan(o_ag)) * 2 / self.scale
    if math.abs(eye_offset) < 0.5 - self.attBorder.y then
        self.attLines.line_center:mov(newVec(0, eye_offset, 0))
        self.attLines.line_center:transform(m, true)
        self:drawVec2dgroup(self.midPoint, self.attLines.line_center.list, 0xFFFFFFFF, self.borders.attBorder)
        self:drawVec2dgroup(self.midPoint, self.attLines.line_center.mir, 0xFFFFFFFF, self.borders.attBorder)
    end

    for i = math.rad(self.lint_interval), math.rad(90), math.rad(self.lint_interval) do --想想怎么优化
        local tmp_offset_y = (eho.x * math.tan(i + o_ag)) * 2 / self.scale
        if math.abs(tmp_offset_y) < 0.5 - self.attBorder.y then
            local offset = setmetatable({}, {__index = self.attLines.line_l_top})
            offset:mov(newVec(0, tmp_offset_y, 0))
            offset:transform(m, true)
            self:drawVec2dgroup(self.midPoint, offset.list, 0x33FFFFFF, self.borders.attBorder)
            self:drawVec2dgroup(self.midPoint, offset.mir, 0x33FFFFFF, self.borders.attBorder)

            local numberPos = new2dVec(self.attNumberXPos, 0):add(new2dVec(0, tmp_offset_y))
            numberPos= matrixMultiplication(m, numberPos):scale(self.midPoint.x):add(self.midPoint)
            self:draw_number(numberPos, -math.deg(i))
        end

        local tmp_offset_y_2 = (eho.x * math.tan(o_ag - i)) * 2 / self.scale
        if math.abs(tmp_offset_y_2) < 0.5 - self.attBorder.y and math.abs(i) < 1.55 then
            local offset_nega = setmetatable({}, {__index = self.attLines.line_l_bottom})
            offset_nega:mov(newVec(0, tmp_offset_y_2, 0))
            offset_nega:transform(m, true)
            self:drawVec2dgroup(self.midPoint, offset_nega.list, 0x33FFFFFF, self.borders.attBorder)
            self:drawVec2dgroup(self.midPoint, offset_nega.mir, 0x33FFFFFF, self.borders.attBorder)

            local numberPos = new2dVec(self.attNumberXPos, 0):add(new2dVec(0, tmp_offset_y_2))
            numberPos= matrixMultiplication(m, numberPos):scale(self.midPoint.x):add(self.midPoint)
            self:draw_number(numberPos, math.deg(i))
        end
    end

    self:draw_msg_bar()

end

function absHoloGram:drawCannon()
    local pos = self.cannonCountPos
    for i = 1, #linkedCannons, 1 do
        local yp = pos.y + (i - 1) * 6
        self:draw_5x5_letter(new2dVec(pos.x, yp - 2), linkedCannons[i].name, false, "white")
        self:draw_number(new2dVec(pos.x + 50, yp), linkedCannons[i].bullets_count, true)
        if linkedCannons[i].cross_point then
            self:drawCannonCross(linkedCannons[i].cross_point, cross_box)
        end
    end
end

function absHoloGram:radarPage()
    self:draw_5x5_letter(self.radarPos_left, "<")
    self:draw_5x5_letter(self.radarPos_right, ">")
    if properties.radarMode == 1 then --nil
        if properties.language == language[1] then
            self:draw_7x7_fonts(self.radarModePos, "_65e0")
        else
            self:draw_5x5_letter(self.radarModePos, "null", "white")
        end
    elseif properties.radarMode == 2 then --vs_ship
        if properties.language == language[1] then
            self:draw_7x7_fonts(self.radarModePos, "_74e6,_5c14,_57fa,_91cc")
        else
            self:draw_5x5_letter(self.radarModePos, "vs_ship", "white")
        end
    elseif properties.radarMode == 3 then --monster
        if properties.language == language[1] then
            self:draw_7x7_fonts(self.radarModePos, "_602a,_7269")
        else
            self:draw_5x5_letter(self.radarModePos, "monster", "white")
        end
    elseif properties.radarMode == 4 then --player
        if properties.language == language[1] then
            self:draw_7x7_fonts(self.radarModePos, "_73a9,_5bb6")
        else
            self:draw_5x5_letter(self.radarModePos, "player", "white")
        end
    end
    
    for k, v in pairs(self.locked_list) do
        v.flag = false
    end

    if radar.final_targets then
        for k, v in pairs(radar.final_targets) do
            if self.locked_list[v.id] then
                self.locked_list[v.id].flag = true
                self.locked_list[v.id].pos = newVec(v.x, v.y, v.z)
            else
                self.locked_list[v.id] = { name = v.name, anime_count = 12, flag = true, pos = newVec(v.x, v.y, v.z), box = new_lock_box()}
                if v.health then
                    self.locked_list[v.id].health = v.health
                    self.locked_list[v.id].maxHealth = v.maxHealth
                end
            end
        end
    end

    for k, v in pairs(self.locked_list) do
        if not v.flag then
            self.locked_list[k] = nil
        end
    end

    local fflag = true
    for k, v in pairs(self.locked_list) do
        self:drawLockBox(v.pos, v.box, v.anime_count)
        self.locked_list[k].anime_count = v.anime_count > 0 and self.locked_list[k].anime_count - 1 or 0

        if fflag then
            fflag  = false
            self:draw_5x5_letter(self.targetPos, filterString(self.locked_list[k].name), "white")
            if self.locked_list[k].health then
                local x_offset = (self.locked_list[k].health / self.locked_list[k].maxHealth) * self.hp_bar_len * self.midPoint.x
                self.screen.DrawLine(self.hp_pos_start.x, self.hp_pos_start.y, self.hp_pos_start.x + x_offset, self.hp_pos_end.y, 0x11FF11FF, 1)
                self.screen.DrawLine(self.hp_pos_start.x + x_offset, self.hp_pos_start.y, self.hp_pos_end.x, self.hp_pos_end.y, 0x1111FFFF, 1)
                self:draw_number(self.hp_text_start, self.locked_list[k].health)
                self:draw_number(self.hp_text_end, self.locked_list[k].maxHealth)
            end
        end
    end

    -----其它目标-----
    if self.other_targets then
        for k, v in pairs(self.other_list) do
            v.flag = false
        end
    
        if radar.other_targets then
            for k, v in pairs(radar.other_targets) do
                if self.other_list[v.id] then
                    self.other_list[v.id].flag = true
                    self.other_list[v.id].pos = newVec(v.x, v.y, v.z)
                else
                    self.other_list[v.id] = { name = v.name, flag = true, pos = newVec(v.x, v.y, v.z), box = new_other_lock_box()}
                end
            end
        end
    
        for k, v in pairs(self.other_list) do
            if not v.flag then
                self.other_list[k] = nil
            else
                self:drawOtherBox(v.pos, v.box)
            end
        end
    end
end

local rot_box_matrix = {
    {math.cos(math.rad(18)), math.sin(math.rad(18))},
    {-math.sin(math.rad(18)), math.cos(math.rad(18))}
}
local scale_lower = {
    { 0.82, 0 }, { 0, 0.82 }
}

function absHoloGram:getLockPos(v)
    local e2e = self.eye_offset:copy()
    --e2e.y = e2e.y * self.scale
    local pos = self:offset_from_self(v):sub(e2e)
    local len = pos:len()
    local sin_y = pos.y / len
    local sin_x = (-pos.z / len)
    local xx = self.eye_offset.x * math.tan(math.asin(sin_x / sin2cos(sin_y)))
    local yy = self.eye_offset.x * math.tan(math.asin(sin_y / sin2cos(sin_x)))
    local point = new2dVec(xx / self.scale, yy / self.scale):scale(self.width):add(self.midPoint)
    point.y = point.y + self.eye_pitch_offset
    return point, len
end

function absHoloGram:drawLockBox(v, box, anime_index)
    local point, len = self:getLockPos(v)
    box:transform(rot_box_matrix, false)
    if anime_index > 0 then
        box:transform(scale_lower, false)
        if self.rgb_lock_box then
            local g_b = anime_index * 20
            local color = tonumber(string.format("%x%x%x%x", (12 - anime_index) * 20, g_b, 51, 255), 16)
            self:drawVec2dgroup(point, box.list, color, self.borders.full)
        else
            self:drawVec2dgroup(point, box.list, 0xFF3333FF, self.borders.full)
        end
    else
        self:drawVec2dgroup(point, box.list, 0xFF3333FF, self.borders.full)
        self:draw_number(new2dVec(point.x + self.boxDisOffset, point.y), math.floor(len))
    end
end

function absHoloGram:drawOtherBox(v, box)
    local point, len = self:getLockPos(v)
    self:drawVec2dgroup(point, box.list, 0x3333FFFF, self.borders.full)
end

function absHoloGram:drawCannonCross(v, box)
    local point = self:getLockPos(v)
    self:drawVec2dgroup(point, box.list, 0x33FF33FF, self.borders.full)
end

function absHoloGram:drawVec2dgroup(point, list, color, border)
    for i, v in ipairs(list) do
        local next = list[i + 1]
        if next then
            local p1 = new2dVec(v.x, v.y):scale(self.midPoint.x):add(point)
            local p2 = new2dVec(next.x, next.y):scale(self.midPoint.x):add(point)
            if self:checkVecArea(p1, border) and self:checkVecArea(p2, border) then
                self.screen.DrawLine(p1.x, p1.y, p2.x, p2.y, color, 1)
            end
        end
    end
end

function absHoloGram:checkVecArea(v2d, border)
    return v2d.x > border.x and v2d.x < self.width - border.x
        and v2d.y > border.y and v2d.y < self.height - border.y
end

function absHoloGram:drawBorder()
    self.screen.DrawLine(0, 0, 30, 0, 0xFFFFFFFF, 1)
    self.screen.DrawLine(0, 0, 0, 30, 0xFFFFFFFF, 1)

    self.screen.DrawLine(self.width - 30, 0, self.width, 0, 0xFFFFFFFF, 1)
    self.screen.DrawLine(self.width - 1, 0, self.width - 1, 30, 0xFFFFFFFF, 1)

    self.screen.DrawLine(self.width - 1, self.height - 30, self.width - 1, self.height, 0xFFFFFFFF, 1)
    self.screen.DrawLine(self.width - 1, self.height - 1, self.width - 30, self.height - 1, 0xFFFFFFFF, 1)
    self.screen.DrawLine(0, self.height - 30, 0, self.height - 1, 0xFFFFFFFF, 1)
    self.screen.DrawLine(0, self.height - 1, 30, self.height - 1, 0xFFFFFFFF, 1)
end

local coupled_ct = 20
function absHoloGram:draw_msg_bar()
    local ct = controllers.activated
    if self.drawInputLine and ct then
        local joy = new2dVec(-ct.LeftStick.x,ct.RightStick.y)
        local joy2len = joy:len()
        joy2len = joy2len > 1 and 1 or joy2len
        joy:norm():scale(joy2len)
        local right_joy_pos = new2dVec(self.crossPos):add(joy:scale(self.midPoint.x):scale(0.3))
        self.screen.DrawLine(self.crossPos.x, self.crossPos.y, right_joy_pos.x, right_joy_pos.y, 0xFFFFFF33, 1)
    end

    self:draw_number(self.heightPos, flight_control.pos.y)
    if properties.language == language[1] then
        self:draw_7x7_fonts(self.hightFontPos, "_9ad8,_5ea6,_space,_7c73")
    else
        self:draw_5x5_letter(self.hightFontPos, "height", "white")
    end
    self:draw_number(self.speedPos, flight_control.speed * 3.6)
    self:draw_5x5_letter(self.speedFontPos, "km/h")

    self:draw_5x5_letter(self.energyFontPos, "need rpm")
    self:draw_number(self.energyPos, flight_control.mass / 20000)
    if properties.mode == 1 then
        self:draw_5x5_letter(self.ThrottlePos, "throttle")
        self:draw_number(self.ThrottleFontPos, properties.spaceShipThrottle, true)
        if flight_control.hold then
            self:draw_5x5_letter(self.holdingPos, "holding")
        end
    end
    if properties.coupled then
        self:draw_5x5_letter(self.massPos, "coupled", "white") --Decoupled
    elseif coupled_ct > 10 then
        self:draw_5x5_letter(self.massPos, "decoupled", "red")
    end
    coupled_ct = coupled_ct > 1 and coupled_ct - 1 or 20
    --self:draw_number(self.massPos, math.abs(flight_control.all_force / 1000))
    --self:draw_number(self.massPos, math.deg(math.asin(flight_control.pX.y) * 100))

    --self.screen.Blit(self.crossPos.x, self.crossPos.y, 1, 1, {0xFFFFFFFF}, 1)
    if properties.radar_lock_mode then
        self:draw_5x5_letter(new2dVec(self.crossPos.x + 2, self.crossPos.y - 2), "_cross")
    else
        self:draw_5x5_letter(new2dVec(self.crossPos.x + 2, self.crossPos.y - 2), "_cross_box")
    end
end

function absHoloGram:draw_number(pos, n, white)
    if type(n) ~= "number" then
        return
    end
    n = math.floor(n + 0.5)
    local str = tostring(math.abs(n))
    local x = pos.x - 2 * #str
    local y = pos.y - 2
    if white then
        if n < 0 then
            self.screen.DrawLine(x, y + 2, x + 4, y + 2, 0xFFFFFFFF, 1)
            x = x + 5
        end
    
        for i = 1, #str, 1 do
            self.screen.Blit(x, y, 4, 5, my_4x5_number_white[tonumber(str:sub(i, i)) + 1], 1)
            x = x + 5
        end
    else
        if n < 0 then
            self.screen.DrawLine(x, y + 2, x + 4, y + 2, 0x33FFFFFF, 1)
            x = x + 5
        end
    
        for i = 1, #str, 1 do
            self.screen.Blit(x, y, 4, 5, my_4x5_number[tonumber(str:sub(i, i)) + 1], 1)
            x = x + 5
        end
    end
end

function absHoloGram:draw_7x7_fonts(pos, uni_arr)
    local arrs = split(uni_arr, ",")
    local x, y = pos.x - #arrs / 2 * 8, pos.y
    for i, v in ipairs(arrs) do
        if v ~= "_space" then
            self.screen.Blit(x, y, 7, 7, jizhi_7x7_fonts[v], 1)
        end
        x = x + 8
    end
end

function absHoloGram:draw_5x5_letter(pos, str, color, left)
    local arrs
    if str == "_cross" or str == "_cross_box" then
        arrs = {str}
    else
        str = string.lower(str)
        arrs = stringToCharArray(str)
    end
    local x, y = 0, pos.y
    if left then
        x = pos.x
    else
        x = pos.x - #arrs / 2 * 6
    end
    for i, v in ipairs(arrs) do
        if v ~= " " then
            if color == "white" then
                self.screen.Blit(x, y, 5, 5, my_5x5_letter_white[v], 1)
            elseif color == "red" then
                self.screen.Blit(x, y, 5, 5, my_5x5_letter_red[v], 1)
            else
                self.screen.Blit(x, y, 5, 5, my_5x5_letter[v], 1)
            end
        end
        x = x + 6
    end
end

hologram_manager = {
    holograms = {}
}

function hologram_manager:getAllHoloGram()
    local holograms = { peripheral.find("hologram") }
    for k, v in pairs(holograms) do
        local tmp = setmetatable({ name = v.GetName(), screen = v }, {__index = absHoloGram})
        self.holograms[k] = tmp
    end
    hologram_manager:initAll()
end

function hologram_manager:initAll()
    for k, v in pairs(hologram_prop) do
        v.flag = false
    end

    for k, v in pairs(self.holograms) do
        v:init()
        if hologram_prop[v.name] then
            hologram_prop[v.name].flag = true
        end
    end

    for k, v in pairs(hologram_prop) do
        if not v.flag then
            hologram_prop[k] = nil
        end
    end

end

function hologram_manager:refresh()
    for k, v in pairs(self.holograms) do
        v:refresh()
    end
end

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
    if x <= 2 and y == 1 then
        system:updatePersistentData()
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
local setPage              = setmetatable({ pageId = 4, pageName = "setPage" }, { __index = abstractWindow })
local set_spaceShip        = setmetatable({ pageId = 5, pageName = "set_spaceShip" }, { __index = abstractWindow })
local set_quadFPV          = setmetatable({ pageId = 6, pageName = "set_quadFPV" }, { __index = abstractWindow })
local set_helicopter       = setmetatable({ pageId = 7, pageName = "set_helicopter" }, { __index = abstractWindow })
local set_airShip          = setmetatable({ pageId = 8, pageName = "set_airShip" }, { __index = abstractWindow })
local set_user             = setmetatable({ pageId = 9,  pageName = "user_Change" }, { __index = abstractWindow })
local set_home             = setmetatable({ pageId = 10, pageName = "home_set" }, { __index = abstractWindow })
local set_simulate         = setmetatable({ pageId = 11, pageName = "simulate" }, { __index = abstractWindow })
local set_att              = setmetatable({ pageId = 12, pageName = "set_att" }, { __index = abstractWindow })
local set_profile          = setmetatable({ pageId = 13, pageName = "profile" }, { __index = abstractWindow })
local set_colortheme       = setmetatable({ pageId = 14, pageName = "colortheme" }, { __index = abstractWindow })
local shipNet_set_Page     = setmetatable({ pageId = 15, pageName = "shipNet_set" }, { __index = abstractWindow })
local shipNet_connect_Page = setmetatable({ pageId = 16, pageName = "shipNet_call" }, { __index = abstractWindow })
local set_camera           = setmetatable({ pageId = 17, pageName = "set_camera" }, { __index = abstractWindow })
local set_shipFollow       = setmetatable({ pageId = 18, pageName = "set_shipFollow" }, { __index = abstractWindow })
local set_anchorage        = setmetatable({ pageId = 19, pageName = "set_anchorage" }, { __index = abstractWindow })
local mass_fix             = setmetatable({ pageId = 20, pageName = "mass_fix" }, { __index = abstractWindow })
local rate_Roll            = setmetatable({ pageId = 21, pageName = "rate_Roll" }, { __index = abstractWindow })
local rate_Yaw             = setmetatable({ pageId = 22, pageName = "rate_Yaw" }, { __index = abstractWindow })
local rate_Pitch           = setmetatable({ pageId = 23, pageName = "rate_Pitch" }, { __index = abstractWindow })
local set_fixedWing        = setmetatable({ pageId = 24, pageName = "set_fixedWing" }, { __index = abstractWindow })
local set_followRange      = setmetatable({ pageId = 25, pageName = "set_followRange" }, { __index = abstractWindow })
local recordings           = setmetatable({ pageId = 26, pageName = "recordings" }, { __index = abstractWindow })

flightPages                = {
    modPage,              --1
    shipNetPage,          --2
    attPage,              --3
    setPage,              --4
    set_spaceShip,        --5
    set_quadFPV,          --6
    set_helicopter,       --7
    set_airShip,          --8
    set_user,             --9
    set_home,             --10
    set_simulate,         --11
    set_att,              --12
    set_profile,          --13
    set_colortheme,       --14
    shipNet_set_Page,     --15
    shipNet_connect_Page, --16
    set_camera,           --17
    set_shipFollow,       --18
    set_anchorage,        --19
    mass_fix,             --20
    rate_Roll,            --21
    rate_Yaw,             --22
    rate_Pitch,           --23
    set_fixedWing,        --24
    set_followRange,      --25
    recordings            --26
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
            system:updatePersistentData()
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
        flight_control:setLastPos()
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
        local xPoint = math.floor(math.cos(math.rad(flight_control.yaw)) * xMid + 0.5)
        local zPoint = math.floor(math.sin(math.rad(flight_control.yaw)) * xMid + 0.5)
        if flight_control.pX.x > 0 then
            self.window.setCursorPos(xMid + zPoint - xPos, 1)
            self.window.blit("W", select, bg)
        else
            self.window.setCursorPos(xMid - zPoint - xPos, 1)
            self.window.blit("E", select, bg)
        end

        if flight_control.pX.z > 0 then
            self.window.setCursorPos(xMid + xPoint - xPos, 1)
            self.window.blit("N", select, bg)
        else
            self.window.setCursorPos(xMid - xPoint - xPos, 1)
            self.window.blit("S", select, bg)
        end
    end

    local yMid = height / 2
    local lPointy = math.abs(flight_control.pitch) > 90 and flight_control.pZ.y or -flight_control.pZ.y
    lPointy = math.floor(lPointy * yMid + 0.5)
    lPointy = math.abs(lPointy) > yMid - 1 and copysign(yMid - 1, lPointy) or lPointy
    local xPointy = math.abs(flight_control.pitch) > 90 and -flight_control.pX.y or flight_control.pX.y
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

    local joyUtil = controllers.activated
    --commands.execAsync(("say %s"):format(joyUtil))
    local mod = modelist[properties.mode].name
    if info ~= -1 then
        if info.maxColumn > 1 then
            local x, y = width / 2 - xPos, height / 2 - yPos
            if yPos > 1 then y = y - 1 end

            self.window.setCursorPos(x - #mod / 2 + 2, yPos + 1)
            self.window.blit(mod, genStr(title, #mod), genStr(bg, #mod))
            if mod == "SpaceShip" then
                if joyUtil and joyUtil.LeftJoyClick then
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
                self.window.blit(("ROLL %6.1f"):format(flight_control.roll), genStr(other, 11), genStr(bg, 11))
                self.window.setCursorPos(x - 3, y)
                self.window.blit(("YAW  %6.1f"):format(flight_control.yaw), genStr(other, 11), genStr(bg, 11))
                self.window.setCursorPos(x - 3, y + 1)
                self.window.blit(("PITCH%6.1f"):format(flight_control.pitch), genStr(other, 11), genStr(bg, 11))
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
            self.window.blit(("%6.1f km/h"):format(flight_control.speed * 3.6), genStr(select, 11), genStr(bg, 11))
            self.window.setCursorPos(x - 3, y + 5)
            if flight_control.pos.y < 99999 then
                self.window.blit(("H %7.1f m"):format(flight_control.pos.y), genStr(select, 11), genStr(bg, 11))
            else
                self.window.blit(("H  %5.1f km"):format(flight_control.pos.y / 1000), genStr(select, 11), genStr(bg, 11))
            end

            if joyUtil and info.maxColumn > 2 then
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
            if mod == "SpaceShip" or mod == "QuadFPV" then
                self:drawSpeed(mod, bg, font, title, select, other)
            end
        end
    else
        if mod == "SpaceShip" or mod == "QuadFPV" then
            self:drawSpeed(mod, bg, font, title, select, other)
        end
    end
end

function attPage:drawSpeed(mod, bg, font, title, select, other)
    if mod == "SpaceShip" then
        self.window.setCursorPos(math.floor(self.width / 2) + 1, math.floor(self.height / 2))
        if properties.coupled then
            self.window.blit("C", bg, select)
        else
            self.window.blit("C", font, bg)
        end
    end
    self.window.setCursorPos(math.floor(self.width / 2), math.floor(self.height / 2) + 2)
    local flaaag = flight_control.speed < 999
    local speeeed = flaaag and flight_control.speed or flight_control.speed / 1000

    local str = string.format("%3d", speeeed)
    self.window.blit(str, genStr(font, 3), genStr(bg, 3))
    self.window.setCursorPos(math.floor(self.width / 2), math.floor(self.height / 2) + 3)
    self.window.blit(flaaag and "m/s" or " km", genStr(other, 3), genStr(bg, 3))
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
                if mod == "SpaceShip" then
                    index = 6
                elseif mod == "QuadFPV" then
                    index = 7
                elseif mod == "Helicopter" then
                    index = 8
                elseif mod == "AirShip" then
                    index = 9
                end
                if index then
                    self.windows[self.row][self.column][index].indexFlag = 2
                    properties.winIndex[self.name][self.row][self.column] = index
                end
            elseif y == by + 3 and x >= bx - 2 and x <= bx + 10 then
                flight_control:setLastPos()
                properties.lock = not properties.lock
            elseif y == by - 1 and x >= bx - 2 and x <= bx + 9 then
                properties.coupled = not properties.coupled
            end
        else
            if mod == "SpaceShip" then
                if y == math.floor(self.height / 2) and x == math.floor(self.width / 2) + 1 then
                    properties.coupled = not properties.coupled
                end
            end
        end
    else
        if mod == "SpaceShip" then
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
                    properties.winIndex[self.name][self.row][self.column] = 15
                elseif x >= self.width - 7 then
                    properties.winIndex[self.name][self.row][self.column] = 16
                end
            end
        end

        if (self.pageIndex == 1 and (y > 2)) or (self.pageIndex > 1 and y > 1 and y < self.height - 2) then
            local index = #shipNet_list > listLen and listLen * (self.pageIndex - 1) + 2 - yPos or
                2 - yPos --融合窗口中每页从第几个开始打印
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
    self.indexFlag = 2
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
                        properties.winIndex[self.name][self.row][self.column] = 17
                    elseif v.text == "set_follow" then
                        properties.winIndex[self.name][self.row][self.column] = 18
                    elseif v.text == "set_anchorage" then
                        properties.winIndex[self.name][self.row][self.column] = 19
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
    self.indexFlag = 2
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

local accept_connect = function(ship, code)
    shipNet_p2p_send(ship.id, "agree", code)
    local flag = false
    for k, v in pairs(childShips) do
        if v.name == ship.name then
            childShips[k] = ship
            childShips[k].beat = beat_ct
            flag = true
            break
        end
    end

    if not flag then
        local newChild = ship
        newChild.beat = beat_ct
        table.insert(childShips, newChild)
    end

    table.remove(callList, 1)
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
                table.insert(properties.shipNet_whiteList, callList[1].name)
                accept_connect(callList[1], callList[1].code)
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
                for k, v in pairs(properties.shipNet_whiteList) do
                    if v == childShips[i2].name then
                        table.remove(properties.shipNet_whiteList, k)
                        break
                    end
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
    self.indexFlag = 15
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
    self.indexFlag = 15
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
    self.indexFlag = 15
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
    self.indexFlag = 15
    self.buttons = {
        { text = "<",             x = 1, y = 1, blitF = title,                       blitB = bg },
        { text = "xOffset-     +", x = 2, y = 3, blitF = genStr(font, 7) .. "fffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 5) .. "e" },
        { text = "yOffset-     +", x = 2, y = 5, blitF = genStr(font, 7) .. "fffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 5) .. "e" },
        { text = "zOffset-     +", x = 2, y = 7, blitF = genStr(font, 7) .. "fffffff", blitB = genStr(bg, 7) .. "b" .. genStr(bg, 5) .. "e" },
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
        elseif x == 15 then
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

--winIndex = 5
function setPage:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.buttons = {
        { text = "<    SET    >", x = self.width / 2 - 5, y = 1,       blitF = genStr(title, 13), blitB = genStr(bg, 13) },
        { text = "S_SpaceShip",   x = 2,                  pageId = 5,  y = 3,                     blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "S_QuadFPV  ",   x = 2,                  pageId = 6,  y = 4,                     blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "S_FixedWing",   x = 2,                  pageId = 24, y = 5,                     blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "S_Helicopt ",   x = 2,                  pageId = 7,  y = 6,                     blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "S_airShip  ",   x = 2,                  pageId = 8,  y = 7,                     blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "User_Change",   x = 2,                  pageId = 9, y = 8,                     blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "Home_Set   ",   x = 2,                  pageId = 10, y = 9,                     blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "FollowRange",   x = 2,                  pageId = 25, y = 10,                    blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "Simulate   ",   x = 2,                  pageId = 11, y = 11,                    blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "Set_Att    ",   x = 2,                  pageId = 12, y = 12,                    blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "Profile    ",   x = 2,                  pageId = 13, y = 13,                    blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "Colortheme ",   x = 2,                  pageId = 14, y = 14,                    blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false },
        { text = "MassFix",       x = 2,                  pageId = 20, y = 15,                    blitF = genStr(font, 7),  blitB = genStr(bg, 7),  select = genStr(select, 7),  selected = false, flag = false },
        { text = "Recordings ",   x = 2,                  pageId = 26, y = 16,                    blitF = genStr(font, 11), blitB = genStr(bg, 11), select = genStr(select, 11), selected = false, flag = false }
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

--winIndex = 5
function set_spaceShip:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.indexFlag = 4
    self.buttons = {
        { text = "<",             x = 1, y = 1, blitF = title,                           blitB = bg },
        { text = "P: --      ++", x = 2, y = 3, blitF = genStr(font, 3) .. "ffffffffff", blitB = genStr(bg, 3) .. "b5" .. genStr(bg, 6) .. "1e" },
        { text = "D: --      ++", x = 2, y = 4, blitF = genStr(font, 3) .. "ffffffffff", blitB = genStr(bg, 3) .. "b5" .. genStr(bg, 6) .. "1e" },
        { text = "Forward -   +", x = 2, y = 5, blitF = genStr(font, 8) .. "fffff",      blitB = genStr(bg, 8) .. "b" .. genStr(bg, 3) .. "e" },
        { text = "vertMove-   +", x = 2, y = 6, blitF = genStr(font, 8) .. "fffff",      blitB = genStr(bg, 8) .. "b" .. genStr(bg, 3) .. "e" },
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
    self.window.setCursorPos(11, 5)
    self.window.write(string.format("%0.1f", profile.spaceShip_forward))
    self.window.setCursorPos(11, 6)
    self.window.write(string.format("%0.1f", profile.spaceShip_vertMove))
    self.window.setCursorPos(11, 7)
    self.window.write(string.format("%0.1f", profile.spaceShip_sideMove))
    self.window.setCursorPos(11, 8)
    self.window.write(string.format("%0.1f", profile.spaceShip_move_D))
    self.window.setCursorPos(11, 9)
    self.window.write(string.format("%0.1f", profile.spaceShip_burner))
end

function set_spaceShip:onTouch(x, y)
    self:subPage_Back(x, y)
    if y == 2 then
        self.windows[self.row][self.column][14].indexFlag = 5
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
                profile.spaceShip_P = profile.spaceShip_P < 0 and 0 or profile.spaceShip_P
            elseif y == 4 then
                profile.spaceShip_D = profile.spaceShip_D + result
            end
        elseif y > 4 then
            if x == 10 then result = -0.1 end
            if x == 14 then result = 0.1 end
            if y == 5 then
                profile.spaceShip_forward = profile.spaceShip_forward + result < 0 and 0 or profile.spaceShip_forward + result
            elseif y == 6 then
                profile.spaceShip_vertMove = profile.spaceShip_vertMove + result < 0 and 0 or profile.spaceShip_vertMove + result
            elseif y == 7 then
                profile.spaceShip_sideMove = profile.spaceShip_sideMove + result < 0 and 0 or profile.spaceShip_sideMove + result
            elseif y == 8 then
                profile.spaceShip_move_D = profile.spaceShip_move_D + result < 0 and 0 or profile.spaceShip_move_D + result
            elseif y == 9 then
                profile.spaceShip_burner = profile.spaceShip_burner + result < 0 and 0 or profile.spaceShip_burner + result
            end
        end
    end
end

--winIndex = 7
function set_quadFPV:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.indexFlag = 4
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
        self.windows[self.row][self.column][14].indexFlag = 6
        properties.winIndex[self.name][self.row][self.column] = 13
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
                        self.windows[self.row][self.column][21].indexFlag = 6
                        properties.winIndex[self.name][self.row][self.column] = 21
                    elseif v.text == "Rate_Yaw  >" then
                        self.windows[self.row][self.column][22].indexFlag = 6
                        properties.winIndex[self.name][self.row][self.column] = 22
                    elseif v.text == "Rate_Pitch>" then
                        self.windows[self.row][self.column][23].indexFlag = 6
                        properties.winIndex[self.name][self.row][self.column] = 23
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
    self.indexFlag = 4
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
    self.indexFlag = 4
    self.buttons = {
        { text = "<",             x = 1, y = 1, blitF = title,                         blitB = bg },
        { text = "Rot_P--    ++", x = 2, y = 3, blitF = genStr(font, 5) .. "ffffffff", blitB = genStr(bg, 5) .. "b5" .. genStr(bg, 4) .. "1e" },
        { text = "Rot_D--    ++", x = 2, y = 4, blitF = genStr(font, 5) .. "ffffffff", blitB = genStr(bg, 5) .. "b5" .. genStr(bg, 4) .. "1e" },
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
    self.window.write(string.format("%0.2f", profile.helicopt_ROT_P))
    self.window.setCursorPos(9, 4)
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
        self.windows[self.row][self.column][14].indexFlag = 7
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
                profile.helicopt_ROT_P = profile.helicopt_ROT_P + result < 0 and 0 or profile.helicopt_ROT_P + result
            elseif y == 4 then
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
            profile.helicopt_MAX_ANGLE = profile.helicopt_MAX_ANGLE > 90 and 90 or profile.helicopt_MAX_ANGLE
        end
    end
end

--winIndex = 9
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
        self.windows[self.row][self.column][14].indexFlag = 8
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

--winIndex = 10
function set_user:init()
    local bg, other, font, title = properties.bg, properties.other, properties.font, properties.title
    self.indexFlag = 4
    self.buttons = {
        { text = "<",           x = 1, y = 1, blitF = title,             blitB = bg },
        { text = "selectUser:", x = 2, y = 2, blitF = genStr(other, 11), blitB = genStr(bg, 11) },
    }
end

function set_user:refresh()
    scanner:getPlayer(properties.radarRange)
    self:refreshButtons()
    self:refreshTitle()
    local bg, font, select = properties.bg, properties.font, properties.select
    local index = 1
    for k, v in pairs(scanner.players) do
        if index == 7 then break end
        self.window.setCursorPos(2, 2 + index)
        if v.name == properties.userName then
            self.window.blit(v.name, genStr(bg, #v.name), genStr(select, #v.name))
        else
            self.window.blit(v.name, genStr(font, #v.name), genStr(bg, #v.name))
        end
        index = index + 1
    end
end

function set_user:onTouch(x, y)
    self:subPage_Back(x, y)
    if y > 2 and y < 10 then
        local user = scanner.players[y - 2]
        if user then
            properties.userName = user.name
        end
    end
end

--winIndex = 11
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

--winIndex = 26
function recordings:init()
    local bg, other, font, title = properties.bg, properties.other, properties.font, properties.title
    self.indexFlag = 4
    self.buttons = {
        { text = "<",             x = 1, y = 1, blitF = title,                       blitB = bg },
        { text = "REC", x = 2, y = 10, blitF = "eee", blitB = "fff" },
        { text = "[|]", x = 6, y = 10, blitF = "ddd", blitB = "fff" },
        { text = "[>]", x = 12, y = 10, blitF = "000", blitB = "fff" }
    }
end

function recordings:refresh()
    self:refreshButtons()
    self:refreshTitle()
end

function recordings:onTouch(x, y)
    self:subPage_Back(x, y)
end

--winIndex = 12
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
    self.indexFlag = 4
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

--winIndex = 15
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

--winIndex=21
function mass_fix:init()
    local bg, font, title, select, other = properties.bg, properties.font, properties.title, properties.select,
        properties.other
    self.indexFlag = 4
    self.buttons = {
        { text = "<",          x = 1, y = 1, blitF = title,            blitB = bg },
        { text = "font      ", x = 4, y = 3, blitF = genStr(font, 10), blitB = genStr(bg, 10), prt = genStr(font, 2) },
    }
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
        system:updatePersistentData()
    end
end

local absHologramSetPage = setmetatable({ screenTitle = "hologram setting" }, {__index=abstractScreen})
local hologramManagerScreen = setmetatable({ screenTitle = "hologram manager" }, {__index=abstractScreen})

function absHologramSetPage:init()
    
end

function absHologramSetPage:refresh()
    self.monitor.setTextColor(colors.white)
    self.monitor.setBackgroundColor(colors.black)
    self.monitor.clear()
    self.monitor.setCursorPos(1, 1)
    self.monitor.blit("< back ", "fffffff", "0000000")
    local prop = hologram_prop[self.holo]
    self.monitor.setCursorPos(2, 3)
    self.monitor.blit(("scale --%5.1f++"):format(prop.scale), "00000ffffffffff", "ffffffb5000001e")
    self.monitor.setCursorPos(2, 5)
    self.monitor.blit(("width  + %5d -"):format(prop.width), "00000fffffffffff", "fffffffb0000000e")
    self.monitor.setCursorPos(2, 6)
    self.monitor.blit(("height - %5d -"):format(prop.height), "000000ffffffffff", "fffffffb0000000e")
    self.monitor.setCursorPos(2, 12)
    self.monitor.blit(("radar  - %5d -"):format(properties.radarRange), "000000ffffffffff", "fffffffb0000000e")
    self.monitor.setCursorPos(2, 8)
    if prop.drawHoloBorder then
        self.monitor.blit("draw border", "fffffffffff", "00000000000")
    else
        self.monitor.blit("draw border", "00000000000", "fffffffffff")
    end
    self.monitor.setCursorPos(2, 9)
    if prop.drawInputLine then
        self.monitor.blit("Input Line", "ffffffffff", "0000000000")
    else
        self.monitor.blit("Input Line", "0000000000", "ffffffffff")
    end
    self.monitor.setCursorPos(2, 10)
    if prop.rgb_lock_box then
        self.monitor.blit("RGB_Lock_Box", "ffffffffffff", "000000000000")
    else
        self.monitor.blit("RGB_Lock_Box", "000000000000", "ffffffffffff")
    end
    self.monitor.setCursorPos(2, 11)
    if prop.other_targets then
        self.monitor.blit("Other_Target", "ffffffffffff", "000000000000")
    else
        self.monitor.blit("Other_Target", "000000000000", "ffffffffffff")
    end
    self.monitor.setCursorPos(28, 3)
    self.monitor.blit(("translation_x --%5.1f++"):format(prop.translation.x), genStr("0", 14).."fffffffff", genStr("f", 14).."b5000001e")
    self.monitor.setCursorPos(28, 4)
    self.monitor.blit(("translation_y --%5.1f++"):format(prop.translation.y), genStr("0", 14).."fffffffff", genStr("f", 14).."b5000001e")
    self.monitor.setCursorPos(28, 5)
    self.monitor.blit(("translation_z --%5.1f++"):format(prop.translation.z), genStr("0", 14).."fffffffff", genStr("f", 14).."b5000001e")
    self.monitor.setCursorPos(2, 14)
    self.monitor.blit(("background_r -- %3d ++"):format(prop.bg.r), genStr("f", 22), genStr("e", 12).."fb5000001e")
    self.monitor.setCursorPos(2, 15)
    self.monitor.blit(("background_g -- %3d ++"):format(prop.bg.g), genStr("f", 22), genStr("5", 12).."fb5000001e")
    self.monitor.setCursorPos(2, 16)
    self.monitor.blit(("background_b -- %3d ++"):format(prop.bg.b), genStr("f", 22), genStr("b", 12).."fb5000001e")
    self.monitor.setCursorPos(2, 17)
    self.monitor.blit(("background_a -- %3d ++"):format(prop.bg.a), genStr("f", 22), genStr("0", 12).."fb5000001e")
    self.monitor.setCursorPos(28, 9)
    self.monitor.blit(("eye_offset_x --%5.1f++"):format(prop.eye_offset.x), genStr("0", 13).."fffffffff", genStr("f", 13).."b5000001e")
    self.monitor.setCursorPos(28, 10)
    self.monitor.blit(("eye_offset_y --%5.2f++"):format(prop.eye_offset.y), genStr("0", 13).."fffffffff", genStr("f", 13).."b5000001e")
    self.monitor.setCursorPos(28, 12)
    self.monitor.blit(("att_border   --%5.2f++"):format(prop.attBorder.y), genStr("0", 13).."fffffffff", genStr("f", 13).."b5000001e")
    self.monitor.setCursorPos(28, 13)
    self.monitor.blit(("att_size     --%5.2f++"):format(prop.attSize), genStr("0", 13).."fffffffff", genStr("f", 13).."b5000001e")
    self.monitor.setCursorPos(28, 7)
    self.monitor.blit(("PitchInterval - %3d +"):format(prop.lint_interval), genStr("0", 13).."ffffffff", genStr("f", 14).."b00000e")
    self.monitor.setCursorPos(28, 15)
    self.monitor.blit(("m_bar_offset --%5.2f++"):format(prop.msg_bar_offset), genStr("0", 13).."fffffffff", genStr("f", 13).."b5000001e")
    self.monitor.setCursorPos(28, 16)
    self.monitor.blit(("g_bar_offset --%5.2f++"):format(prop.cannon_bar_offset), genStr("0", 13).."fffffffff", genStr("f", 13).."b5000001e")
    self.monitor.setCursorPos(28, 17)
    self.monitor.blit(("t_bar_offset --%5.2f++"):format(prop.target_bar_offset), genStr("0", 13).."fffffffff", genStr("f", 13).."b5000001e")
end

function absHologramSetPage:checkInputRange(t, min, max)
    return t < min and min or t > max and max or t
end

function absHologramSetPage:onTouch(x, y)
    if x < 8 and y == 1 then
        monitorUtil.newScreen(self.name, nil)
    else
        local prop = hologram_prop[self.holo]
        if x < 28 then
            if y == 3 then
                local result = x == 8 and -1 or x == 9 and -0.1 or x == 15 and 0.1 or x == 16 and 1 or 0
                prop.scale = self:checkInputRange(prop.scale + result, 0.1, 99)
            elseif y == 5 then
                local result = x == 9 and -64 or x == 17 and 64 or 0
                prop.width = self:checkInputRange(prop.width + result, 64, 1024)
                if prop.width < prop.height  then prop.height = prop.width end
            elseif y == 6 then
                local result = x == 9 and -64 or x == 17 and 64 or 0
                prop.height = self:checkInputRange(prop.height + result, 64, prop.width)
            elseif y == 8 then
                if x < 13 then
                    prop.drawHoloBorder = not prop.drawHoloBorder
                end
            elseif y == 9 then
                if x < 13 then
                    prop.drawInputLine = not prop.drawInputLine
                end
            elseif y == 10 then
                if x < 13 then
                    prop.rgb_lock_box = not prop.rgb_lock_box
                end
            elseif y == 11 then
                if x < 13 then
                    prop.other_targets = not prop.other_targets
                end
            elseif y == 12 then
                local result = x == 9 and -64 or x == 17 and 64 or 0
                properties.radarRange = result + properties.radarRange
                properties.radarRange = properties.radarRange > 2496 and 2496 or properties.radarRange < 64 and 64 or properties.radarRange
            end
        else
            if y == 3 then
                local result = x == 42 and -1 or x == 43 and -0.1 or x == 49 and 0.1 or x == 50 and 1 or 0
                prop.translation.x = result + prop.translation.x
                prop.translation.x = math.abs(prop.translation.x) > 99 and copysign(99, prop.translation.x) or prop.translation.x
            elseif y == 4 then
                local result = x == 42 and -1 or x == 43 and -0.1 or x == 49 and 0.1 or x == 50 and 1 or 0
                prop.translation.y = result + prop.translation.y
                prop.translation.y = math.abs(prop.translation.y) > 99 and copysign(99, prop.translation.y) or prop.translation.y
            elseif y == 5 then
                local result = x == 42 and -1 or x == 43 and -0.1 or x == 49 and 0.1 or x == 50 and 1 or 0
                prop.translation.z = result + prop.translation.z
                prop.translation.z = math.abs(prop.translation.z) > 99 and copysign(99, prop.translation.z) or prop.translation.z
            elseif y == 7 then
                local result = x == 42 and -1 or x == 48 and 1 or 0
                prop.lint_interval = self:checkInputRange(prop.lint_interval + result, 1, 30)
            elseif y == 9 then
                local result = x == 41 and -1 or x == 42 and -0.1 or x == 48 and 0.1 or x == 49 and 1 or 0
                prop.eye_offset.x = self:checkInputRange(prop.eye_offset.x + result, 0, 30)
            elseif y == 10 then
                local result = x == 41 and -0.1 or x == 42 and -0.01 or x == 48 and 0.01 or x == 49 and 0.1 or 0
                prop.eye_offset.y = result + prop.eye_offset.y
                prop.eye_offset.y = math.abs(prop.eye_offset.y) > 99 and copysign(99, prop.eye_offset.y) or prop.eye_offset.y
            elseif y == 12 then
                local result = x == 41 and -0.1 or x == 42 and -0.01 or x == 48 and 0.01 or x == 49 and 0.1 or 0
                prop.attBorder.y = result + prop.attBorder.y
                prop.attBorder.y = math.abs(prop.attBorder.y) > 0.5 and copysign(0.5, prop.attBorder.y) or prop.attBorder.y
                prop.attBorder.y = prop.attBorder.y < 0 and 0 or prop.attBorder.y
                prop.attBorder.x = prop.attBorder.y
            elseif y == 13 then
                local result = x == 41 and -0.1 or x == 42 and -0.01 or x == 48 and 0.01 or x == 49 and 0.1 or 0
                prop.attSize = result + prop.attSize
                prop.attSize = prop.attSize < 0.1 and 0.1 or prop.attSize > 3 and 3 or prop.attSize
            elseif y == 15 then
                local result = x == 41 and -0.1 or x == 42 and -0.01 or x == 48 and 0.01 or x == 49 and 0.1 or 0
                prop.msg_bar_offset = result + prop.msg_bar_offset
                prop.msg_bar_offset = prop.msg_bar_offset < -0.95 and -0.95 or prop.msg_bar_offset > 0.95 and 0.95 or prop.msg_bar_offset
            elseif y == 16 then
                local result = x == 41 and -0.1 or x == 42 and -0.01 or x == 48 and 0.01 or x == 49 and 0.1 or 0
                prop.cannon_bar_offset = result + prop.cannon_bar_offset
                prop.cannon_bar_offset = prop.cannon_bar_offset < -0.95 and -0.95 or prop.cannon_bar_offset > 0.95 and 0.95 or prop.cannon_bar_offset
            elseif y == 17 then
                local result = x == 41 and -0.1 or x == 42 and -0.01 or x == 48 and 0.01 or x == 49 and 0.1 or 0
                prop.target_bar_offset = result + prop.target_bar_offset
                prop.target_bar_offset = prop.target_bar_offset < -0.99 and -0.99 or prop.target_bar_offset > 0.99 and 0.99 or prop.target_bar_offset
            end
        end
        system:updatePersistentData()
        hologram_manager:initAll()
    end
end

function hologramManagerScreen:init()
    self.holograms = {}
    for k, v in pairs(hologram_manager.holograms) do
        table.insert(self.holograms, setmetatable({ holo = v.name }, {__index = absHologramSetPage}))
    end
end

function hologramManagerScreen:refresh()
    self.monitor.setTextColor(colors.white)
    self.monitor.setBackgroundColor(colors.black)
    self.monitor.clear()
    self.monitor.setCursorPos(1, 1)
    self.monitor.write(" <")
    local cursorIndex = 2
    for k, v in pairs(self.holograms) do
        self.monitor.setBackgroundColor(colors.blue)
        self.monitor.setCursorPos(2, cursorIndex)
        self.monitor.write(string.format("[ %s ]", v.holo))
        cursorIndex = cursorIndex + 1
    end
end

function hologramManagerScreen:onTouch(x, y)
    if y > #self.holograms + 1 then
        return
    end
    if y < 2 then
        monitorUtil.newScreen(self.name, nil)
    end
    monitorUtil.newScreen(self.name, self.holograms[y - 1])
end

-- screenPickerScreen
-- 用于打开其他的屏幕的屏幕
local screenPickerScreen = setmetatable({ screenTitle = "idle" }, { __index = abstractScreen })

function screenPickerScreen:init()
    self.rows = {}
    if self.name == "computer" then
        table.insert(self.rows, { name = "screens manager", class = screensManagerScreen })
        table.insert(self.rows, { name = "hologram manager", class = hologramManagerScreen })
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
    self.monitor.setCursorPos(34, 1)
    self.monitor.write(string.format("Computer_Id: %4d", computerId))
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
                    if page == 2 or page == 3 or page == 16 then
                        screen.windows[i][j][page]:refresh()
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
                pos = engine_controller.getPosition(),
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
                    local result = { id = id, name = msg.name, code = msg.code, ct = 10 }
                    local flag = false
                    for k, v in pairs(properties.shipNet_whiteList) do
                        if msg.name == v then
                            accept_connect(result, msg.code)
                            flag = true
                            break
                        end
                    end
                    
                    if not flag then
                        table.insert(callList, result)
                    end
                    monitorUtil.refreshAll()
                elseif msg.request_connect == "back" and msg.name and msg.code == captcha then --回听请求是否被接受
                    if msg.result == "agree" then
                        parentShip.id = id
                        parentShip.name = msg.name
                        parentShip.beat = beat_ct
                        parentShip.code = captcha
                        parentShip.pos = msg.pos
                        parentShip.size = msg.size
                        parentShip.rot = DEFAULT_PARENT_SHIP.rot
                        parentShip.preQuat = DEFAULT_PARENT_SHIP.rot
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
    sleep(0.1)
    parallel.waitForAll(shipNet_beat, shipNet_getMessage)
end

shipNet_p2p_send = function(id, type, code) --发送p2p
    if type == "call" then            --请求父级连接
        if call_ct <= 0 and id ~= parentShip.id then
            rednet.send(id, { name = shipName, code = captcha, request_connect = "call" }, public_protocol)
            calling = id
            call_ct = 10
        end
    elseif type == "agree" or type == "refuse" then --回复子级连接
        local result = { name = shipName, code = code, request_connect = "back", result = type }
        if type == "agree" then
            result.pos = flight_control.pos
            result.size = flight_control.size
            result.rot = flight_control.rot
        end
        rednet.send(id, result, public_protocol)
    elseif type == "beat" then --向父级发送心跳包
        rednet.send(id, "beat", public_protocol)
    end
end

-- {name = properties.cannonName, pw = properties.password}
local cannon_rednet = function()
    while true do
        local id, msg
        repeat
            id, msg = rednet.receive(request_protocol)
        until type(msg) == "table"
        if msg.pw == properties.password then
            local flag = false
            for k, v in pairs(linkedCannons) do
                if v.id == id then
                    v.beat = 3
                    v.bullets_count = msg.bullets_count
                    if msg.cross_point then
                        v.cross_point = newVec(msg.cross_point)
                    else
                        v.cross_point = nil
                    end
                    flag = true
                    break
                end
            end

            if not flag then
                table.insert(linkedCannons, {
                    id = id,
                    name = filterString(msg.name),
                    beat = 3,
                    mode = 2,
                    bullets_count = msg.bullets_count,
                    group = nil
                })

                if not table.contains(properties.whiteList, msg.slug) then
                    table.insert(properties.whiteList, msg.slug)
                end
                
                if not table.contains(properties.whiteList, msg.yawSlug) then
                    table.insert(properties.whiteList, msg.yawSlug)
                end

                if msg.pitchSlug and not table.contains(properties.whiteList, msg.pitchSlug) then
                    table.insert(properties.whiteList, msg.pitchSlug)
                end
                system:updatePersistentData()
            end
        end
    end
end
    
local beats = function()
    while true do
        local index = 1
        while true do
            if index > #linkedCannons then
                break
            end
            linkedCannons[index].beat = linkedCannons[index].beat - 1
            if linkedCannons[index].beat < 0 then
                table.remove(linkedCannons, index)
                index = index - 1
            end
            index = index + 1
        end
        sleep(1)
    end
end

local run_fire_control = function ()
    parallel.waitForAll(cannon_rednet, beats)
end
----------------------------------------------------

local run_event = function ()
    while true do
        local eventData = {os.pullEvent()}
        local event = eventData[1]
        if event == "phys_tick" then
            flight_control:run(eventData[2])
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
            system:updatePersistentData()
        elseif event == "mouse_click" and monitorUtil.screens["computer"] then
            monitorUtil.screens["computer"]:onTouch(eventData[3], eventData[4])
            for k, screen in pairs(monitorUtil.screens) do
                screen:refresh()
            end
            system:updatePersistentData()
        elseif event == "key" and not tableHasValue(properties.enabledMonitors, "computer") then
            table.insert(properties.enabledMonitors, "computer")
            system:updatePersistentData()
        end
    end
end

local refreshDisplay = function()
    sleep(0.1)
    while true do
        if shutdown_flag then
            monitorUtil.onSystemSleep()
            sleep(0.5)
        else
            monitorUtil.refresh()
            sleep(0.05)
        end
    end
end

local run_hologram = function ()
    sleep(0.1)
    local need_init = true
    while true do
        if ship and ship.isStatic() then
            sleep(0.5)
            need_init = true
        else
            if need_init then
                hologram_manager:getAllHoloGram()
                need_init = false
            end
            engine_controller.setIdle(false)
            hologram_manager:refresh()
            sleep(0.05)
        end
    end
end

local run_radar = function()
    sleep(1)
    radar:run()
end

local run_Controllers = function ()
    controllers:getAll()
    controllers:run()
end

local run = function ()
    parallel.waitForAll(run_event, run_radar, run_fire_control, run_Controllers, run_hologram, shipNet_run)
end

system:init()
xpcall(function()
    monitorUtil.scanMonitors()
    if monitorUtil.screens["computer"] == nil then
        monitorUtil.disconnectComputer()
    end
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
