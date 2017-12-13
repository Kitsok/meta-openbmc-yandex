local i2c = require 'i2c'
local bin = require 'struct'
local bit = require 'bit'

local stpack, stunpack = bin.pack, bin.unpack
local lshift, rshift, arshift, bor, band = bit.lshift, bit.rshift, bit.arshift, bit.bor, bit.band

local function BIT(n)
    return lshift(1, n)
end

local function s8(n)
    return stunpack('<b', stpack('<i', n))
end

local function s16(n)
    return stunpack('<h', stpack('<i', n))
end

local function u16(n)
    return stunpack('<H', stpack('<i', n))
end

local _M = {
    PMBUS_PAGE                      = 0x00,
    PMBUS_OPERATION                 = 0x01,
    PMBUS_ON_OFF_CONFIG             = 0x02,
    PMBUS_CLEAR_FAULTS              = 0x03,
    PMBUS_PHASE                     = 0x04,

    PMBUS_CAPABILITY                = 0x19,
    PMBUS_QUERY                     = 0x1A,

    PMBUS_VOUT_MODE                 = 0x20,
    PMBUS_VOUT_COMMAND              = 0x21,
    PMBUS_VOUT_TRIM                 = 0x22,
    PMBUS_VOUT_CAL_OFFSET           = 0x23,
    PMBUS_VOUT_MAX                  = 0x24,
    PMBUS_VOUT_MARGIN_HIGH          = 0x25,
    PMBUS_VOUT_MARGIN_LOW           = 0x26,
    PMBUS_VOUT_TRANSITION_RATE      = 0x27,
    PMBUS_VOUT_DROOP                = 0x28,
    PMBUS_VOUT_SCALE_LOOP           = 0x29,
    PMBUS_VOUT_SCALE_MONITOR        = 0x2A,

    PMBUS_COEFFICIENTS              = 0x30,
    PMBUS_POUT_MAX                  = 0x31,

    PMBUS_FAN_CONFIG_12             = 0x3A,
    PMBUS_FAN_COMMAND_1             = 0x3B,
    PMBUS_FAN_COMMAND_2             = 0x3C,
    PMBUS_FAN_CONFIG_34             = 0x3D,
    PMBUS_FAN_COMMAND_3             = 0x3E,
    PMBUS_FAN_COMMAND_4             = 0x3F,

    PMBUS_VOUT_OV_FAULT_LIMIT       = 0x40,
    PMBUS_VOUT_OV_FAULT_RESPONSE    = 0x41,
    PMBUS_VOUT_OV_WARN_LIMIT        = 0x42,
    PMBUS_VOUT_UV_WARN_LIMIT        = 0x43,
    PMBUS_VOUT_UV_FAULT_LIMIT       = 0x44,
    PMBUS_VOUT_UV_FAULT_RESPONSE    = 0x45,
    PMBUS_IOUT_OC_FAULT_LIMIT       = 0x46,
    PMBUS_IOUT_OC_FAULT_RESPONSE    = 0x47,
    PMBUS_IOUT_OC_LV_FAULT_LIMIT    = 0x48,
    PMBUS_IOUT_OC_LV_FAULT_RESPONSE = 0x49,
    PMBUS_IOUT_OC_WARN_LIMIT        = 0x4A,
    PMBUS_IOUT_UC_FAULT_LIMIT       = 0x4B,
    PMBUS_IOUT_UC_FAULT_RESPONSE    = 0x4C,

    PMBUS_OT_FAULT_LIMIT            = 0x4F,
    PMBUS_OT_FAULT_RESPONSE         = 0x50,
    PMBUS_OT_WARN_LIMIT             = 0x51,
    PMBUS_UT_WARN_LIMIT             = 0x52,
    PMBUS_UT_FAULT_LIMIT            = 0x53,
    PMBUS_UT_FAULT_RESPONSE         = 0x54,
    PMBUS_VIN_OV_FAULT_LIMIT        = 0x55,
    PMBUS_VIN_OV_FAULT_RESPONSE     = 0x56,
    PMBUS_VIN_OV_WARN_LIMIT         = 0x57,
    PMBUS_VIN_UV_WARN_LIMIT         = 0x58,
    PMBUS_VIN_UV_FAULT_LIMIT        = 0x59,

    PMBUS_IIN_OC_FAULT_LIMIT        = 0x5B,
    PMBUS_IIN_OC_WARN_LIMIT         = 0x5D,

    PMBUS_POUT_OP_FAULT_LIMIT       = 0x68,
    PMBUS_POUT_OP_WARN_LIMIT        = 0x6A,
    PMBUS_PIN_OP_WARN_LIMIT         = 0x6B,

    PMBUS_STATUS_BYTE               = 0x78,
    PMBUS_STATUS_WORD               = 0x79,
    PMBUS_STATUS_VOUT               = 0x7A,
    PMBUS_STATUS_IOUT               = 0x7B,
    PMBUS_STATUS_INPUT              = 0x7C,
    PMBUS_STATUS_TEMPERATURE        = 0x7D,
    PMBUS_STATUS_CML                = 0x7E,
    PMBUS_STATUS_OTHER              = 0x7F,
    PMBUS_STATUS_MFR_SPECIFIC       = 0x80,
    PMBUS_STATUS_FAN_12             = 0x81,
    PMBUS_STATUS_FAN_34             = 0x82,

    PMBUS_READ_VIN                  = 0x88,
    PMBUS_READ_IIN                  = 0x89,
    PMBUS_READ_VCAP                 = 0x8A,
    PMBUS_READ_VOUT                 = 0x8B,
    PMBUS_READ_IOUT                 = 0x8C,
    PMBUS_READ_TEMPERATURE_1        = 0x8D,
    PMBUS_READ_TEMPERATURE_2        = 0x8E,
    PMBUS_READ_TEMPERATURE_3        = 0x8F,
    PMBUS_READ_FAN_SPEED_1          = 0x90,
    PMBUS_READ_FAN_SPEED_2          = 0x91,
    PMBUS_READ_FAN_SPEED_3          = 0x92,
    PMBUS_READ_FAN_SPEED_4          = 0x93,
    PMBUS_READ_DUTY_CYCLE           = 0x94,
    PMBUS_READ_FREQUENCY            = 0x95,
    PMBUS_READ_POUT                 = 0x96,
    PMBUS_READ_PIN                  = 0x97,

    PMBUS_REVISION                  = 0x98,
    PMBUS_MFR_ID                    = 0x99,
    PMBUS_MFR_MODEL                 = 0x9A,
    PMBUS_MFR_REVISION              = 0x9B,
    PMBUS_MFR_LOCATION              = 0x9C,
    PMBUS_MFR_DATE                  = 0x9D,
    PMBUS_MFR_SERIAL                = 0x9E,

    PMBUS_VIRT_BASE = 0x100,
    PMBUS_VIRT_READ_TEMP_AVG = 0x101,
    PMBUS_VIRT_READ_TEMP_MIN = 0x102,
    PMBUS_VIRT_READ_TEMP_MAX = 0x103,
    PMBUS_VIRT_RESET_TEMP_HISTORY = 0x104,
    PMBUS_VIRT_READ_VIN_AVG = 0x105,
    PMBUS_VIRT_READ_VIN_MIN = 0x106,
    PMBUS_VIRT_READ_VIN_MAX = 0x107,
    PMBUS_VIRT_RESET_VIN_HISTORY = 0x108,
    PMBUS_VIRT_READ_IIN_AVG = 0x109,
    PMBUS_VIRT_READ_IIN_MIN = 0x10a,
    PMBUS_VIRT_READ_IIN_MAX = 0x10b,
    PMBUS_VIRT_RESET_IIN_HISTORY = 0x10c,
    PMBUS_VIRT_READ_PIN_AVG = 0x10d,
    PMBUS_VIRT_READ_PIN_MIN = 0x10e,
    PMBUS_VIRT_READ_PIN_MAX = 0x10f,
    PMBUS_VIRT_RESET_PIN_HISTORY = 0x110,
    PMBUS_VIRT_READ_POUT_AVG = 0x111,
    PMBUS_VIRT_READ_POUT_MIN = 0x112,
    PMBUS_VIRT_READ_POUT_MAX = 0x113,
    PMBUS_VIRT_RESET_POUT_HISTORY = 0x114,
    PMBUS_VIRT_READ_VOUT_AVG = 0x115,
    PMBUS_VIRT_READ_VOUT_MIN = 0x116,
    PMBUS_VIRT_READ_VOUT_MAX = 0x117,
    PMBUS_VIRT_RESET_VOUT_HISTORY = 0x118,
    PMBUS_VIRT_READ_IOUT_AVG = 0x119,
    PMBUS_VIRT_READ_IOUT_MIN = 0x11a,
    PMBUS_VIRT_READ_IOUT_MAX = 0x11b,
    PMBUS_VIRT_RESET_IOUT_HISTORY = 0x11c,
    PMBUS_VIRT_READ_TEMP2_AVG = 0x11d,
    PMBUS_VIRT_READ_TEMP2_MIN = 0x11e,
    PMBUS_VIRT_READ_TEMP2_MAX = 0x11f,
    PMBUS_VIRT_RESET_TEMP2_HISTORY = 0x120,
    PMBUS_VIRT_READ_VMON = 0x121,
    PMBUS_VIRT_VMON_UV_WARN_LIMIT = 0x122,
    PMBUS_VIRT_VMON_OV_WARN_LIMIT = 0x123,
    PMBUS_VIRT_VMON_UV_FAULT_LIMIT = 0x124,
    PMBUS_VIRT_VMON_OV_FAULT_LIMIT = 0x125,
    PMBUS_VIRT_STATUS_VMON = 0x126,

    -- Functionality bit mask
    PMBUS_HAVE_VIN   = BIT(0),
    PMBUS_HAVE_VCAP  = BIT(1),
    PMBUS_HAVE_VOUT  = BIT(2),
    PMBUS_HAVE_IIN   = BIT(3),
    PMBUS_HAVE_IOUT  = BIT(4),
    PMBUS_HAVE_PIN   = BIT(5),
    PMBUS_HAVE_POUT  = BIT(6),
    PMBUS_HAVE_FAN12 = BIT(7),
    PMBUS_HAVE_FAN34 = BIT(8),
    PMBUS_HAVE_TEMP  = BIT(9),
    PMBUS_HAVE_TEMP2 = BIT(10),
    PMBUS_HAVE_TEMP3 = BIT(11),
    PMBUS_HAVE_STATUS_VOUT  = BIT(12),
    PMBUS_HAVE_STATUS_IOUT  = BIT(13),
    PMBUS_HAVE_STATUS_INPUT = BIT(14),
    PMBUS_HAVE_STATUS_TEMP  = BIT(15),
    PMBUS_HAVE_STATUS_FAN12 = BIT(16),
    PMBUS_HAVE_STATUS_FAN34 = BIT(17),
    PMBUS_HAVE_VMON         = BIT(18),
    PMBUS_HAVE_STATUS_VMON  = BIT(19),

    PB_FAN_1_INSTALLED = BIT(7),
}

local data_format = { linear = 0, direct = 1, vid = 2 }

local vrm_version = { vr11 = 0, vr12 = 1 }

local classes = {
    PSC_VOLTAGE_IN  = 0,
    PSC_VOLTAGE_OUT = 1,
    PSC_CURRENT_IN  = 2,
    PSC_CURRENT_OUT = 3,
    PSC_POWER       = 4,
    PSC_TEMPERATURE = 5,
    PSC_FAN         = 6
}

local voltage_attributes = {
    {
        reg = _M.PMBUS_READ_VIN,
        func = _M.PMBUS_HAVE_VIN,
        class = classes.PSC_VOLTAGE_IN,
        label = 'vin',
        limit = {
            min = {
                reg = _M.PMBUS_VIN_UV_WARN_LIMIT
            },
            lcrit = {
                reg = _M.PMBUS_VIN_UV_FAULT_LIMIT
            },
            max = {
                reg = _M.PMBUS_VIN_OV_WARN_LIMIT
       	    },
            crit = {
                reg = _M.PMBUS_VIN_OV_FAULT_LIMIT
            },
            average = {
                reg = _M.PMBUS_VIRT_READ_VIN_AVG
            },
            lowest = {
                reg = _M.PMBUS_VIRT_READ_VIN_MIN
            },
            highest = {
                reg = _M.PMBUS_VIRT_READ_VIN_MAX
            },
            reset_history = {
                reg = _M.PMBUS_VIRT_RESET_VIN_HISTORY
            }
        }
    }, {
        reg = _M.PMBUS_VIRT_READ_VMON,
        func = _M.PMBUS_HAVE_VMON,
        class = classes.PSC_VOLTAGE_IN,
        label = 'vmon',
        limit = {
            min = {
                reg = _M.PMBUS_VIRT_VMON_UV_WARN_LIMIT
            },
            lcrit = {
                reg = _M.PMBUS_VIRT_VMON_UV_FAULT_LIMIT
            },
            max = {
                reg = _M.PMBUS_VIRT_VMON_OV_WARN_LIMIT
            },
            crit = {
                reg = _M.PMBUS_VIRT_VMON_OV_FAULT_LIMIT
            }
        }
    }, {
        reg = _M.PMBUS_READ_VCAP,
        func = _M.PMBUS_HAVE_VCAP,
        class = classes.PSC_VOLTAGE_IN,
        label = 'vcap',
    }, {
        reg = _M.PMBUS_READ_VOUT,
        func = _M.PMBUS_HAVE_VOUT,
        class = classes.PSC_VOLTAGE_OUT,
        label = 'vout',
        paged = true,
        limit = {
            min = {
                reg = _M.PMBUS_VOUT_UV_WARN_LIMIT
            },
            lcrit = {
                reg = _M.PMBUS_VOUT_UV_FAULT_LIMIT
            },
            max = {
                reg = _M.PMBUS_VOUT_OV_WARN_LIMIT
            },
            crit = {
                reg = _M.PMBUS_VOUT_OV_FAULT_LIMIT
            },
            average = {
                reg = _M.PMBUS_VIRT_READ_VOUT_AVG
            },
            lowest = {
                reg = _M.PMBUS_VIRT_READ_VOUT_MIN
            },
            highest = {
                reg = _M.PMBUS_VIRT_READ_VOUT_MAX
            },
            reset_history = {
                reg = _M.PMBUS_VIRT_RESET_VOUT_HISTORY
            }
        }
    }
}

local current_attributes = {
    {
        reg = _M.PMBUS_READ_IIN,
        func = _M.PMBUS_HAVE_IIN,
        class = classes.PSC_CURRENT_IN,
        label = 'iin'
    }, {
        reg = _M.PMBUS_READ_IOUT,
        func = _M.PMBUS_HAVE_IOUT,
        class = classes.PSC_CURRENT_OUT,
        label = 'iout',
        paged = true
    }
}

local power_attributes = {
    {
        reg = _M.PMBUS_READ_PIN,
        func = _M.PMBUS_HAVE_PIN,
        class = classes.PSC_POWER,
        label = 'pin'
    }, {
        reg = _M.PMBUS_READ_POUT,
        func = _M.PMBUS_HAVE_POUT,
        class = classes.PSC_POWER,
        label = 'pout',
        paged = true
    }
}

local temp_attributes = {
    {
        reg = _M.PMBUS_READ_TEMPERATURE_1,
        func = _M.PMBUS_HAVE_TEMP,
        class = classes.PSC_TEMPERATURE,
        paged = true
    }, {
        reg = _M.PMBUS_READ_TEMPERATURE_2,
        func = _M.PMBUS_HAVE_TEMP2,
        class = classes.PSC_TEMPERATURE,
        paged = true
    }, {
        reg = _M.PMBUS_READ_TEMPERATURE_3,
        func = _M.PMBUS_HAVE_TEMP3,
        class = classes.PSC_TEMPERATURE,
        paged = true
    }
}

local pmbus_fan_registers = {
    {
        reg = _M.PMBUS_READ_FAN_SPEED_1,
        func = _M.PMBUS_HAVE_FAN12,
        class = classes.PSC_FAN
    }, {
        reg = _M.PMBUS_READ_FAN_SPEED_2,
        func = _M.PMBUS_HAVE_FAN12,
        class = classes.PSC_FAN
    }, {
        reg = _M.PMBUS_READ_FAN_SPEED_3,
        func = _M.PMBUS_HAVE_FAN34,
        class = classes.PSC_FAN
    }, {
        reg = _M.PMBUS_READ_FAN_SPEED_4,
        func = _M.PMBUS_HAVE_FAN34,
        class = classes.PSC_FAN
    }
}

local pmbus_fan_config_registers = {
    _M.PMBUS_FAN_CONFIG_12,
    _M.PMBUS_FAN_CONFIG_12,
    _M.PMBUS_FAN_CONFIG_34,
    _M.PMBUS_FAN_CONFIG_34,
}

local mt = { __index = _M }

function _M.new(self, banknum, bus, addr, on_plug, on_unplug)
    local t = {
        present = false,
        number = banknum,
        bus = bus,
        addr  = addr,
        mfr_serial = nil,
        mfr_model = nil,
        mfr_id = nil,
        mfr_loc = nil,
        mfr_rev = nil,
        page  = -1,
        pages = 0, -- total number of pages
        format = {},
        vrm_version = nil,
        m = {}, -- mantissa for direct data format
        b = {}, -- offset
        R = {}, -- exponent
        func = {}, -- functionality, per page

        -- struct pmbus_data
        exponent = {}, -- linear mode: exponent for output voltages
        sensors = {}, -- pmbus_sensor *

        attrs = {},

        -- callbacks
        on_plug = on_plug,
        on_unplug = on_unplug
    }

    t.f = i2c:new(bus)
    if not t.f then return end

    local i
    for i=0,6 do
        t.format[i] = 0
    end

    local obj = setmetatable(t, mt)
    obj:do_probe()
    return obj
end

function _M.write_reg(self, reg, data)
    local nmsg, _, err = self.f:rdwr(self.addr, stpack('B<H', reg, data), 0)
    return nmsg, err
end

function _M.read_reg(self, reg)
    local nmsg, data, err = self.f:rdwr(self.addr, '', 2)
    return data, err
end

function _M.read_cmd(self, cmd, to_read)
    local nmsg, data, err = self.f:rdwr(self.addr, stpack('B', cmd), to_read)
    if err then return nil, err end
    return data, err
end

--
--
--

function _M.i2c_write_byte_data(self, command, value)
    local nmsg, _, err = self.f:rdwr(self.addr, stpack('BB', command, value), 0)
    return nmsg, err
end

function _M.i2c_write_byte(self, value)
    local nmsg, _, err = self.f:rdwr(self.addr, stpack('B', value), 0)
    return nmsg, err
end

function _M.i2c_read_byte_data(self, command)
    local nmsg, data, err = self.f:rdwr(self.addr, stpack('B', command), 1)
    if err ~= nil then return nil, err end
    return stunpack('B', data), err
end

function _M.i2c_read_word_data(self, command)
    local nmsg, data, err = self.f:rdwr(self.addr, stpack('B', command), 2)
    if err ~= nil then return nil, err end
    return stunpack('<H', data), err
end

function _M.set_page(self, page)
    if self.page == page then return end

    local nmsgw, err = self:i2c_write_byte_data(_M.PMBUS_PAGE, page)
    local newpage, err = self:i2c_read_byte_data(_M.PMBUS_PAGE)
    if newpage ~= page then
        return '-EIO'
    else
        self.page = page
    end
end

function _M.write_byte(self, page, value)
    if page >= 0 then
        local rv = self:set_page(page)
        if rv ~= nil then return nil, rv end
    end

    return self:i2c_write_byte(value)
end

function _M.read_byte_data(self, page, reg)
    if page >= 0 then
        local rv = self:set_page(page)
        if rv ~= nil then return nil, rv end
    end

    return self:i2c_read_byte_data(reg)
end

function _M.read_word_data(self, page, reg)
    if page >= 0 then
        local rv = self:set_page(page)
        if rv ~= nil then return nil, rv end
    end

    return self:i2c_read_word_data(reg)
end

function _M.read_string_data(self, reg, to_read)
    local nmsg, data, err = self.f:rdwr(self.addr, stpack('B', reg), to_read)
    if err then return nil, err end
    return stunpack('Bc0', data), err
end

function _M.clear_fault_page(self, page)
    return self:write_byte(page, _M.PMBUS_CLEAR_FAULTS)
end

function _M.clear_faults(self)
    local i
    for i=0, self.pages-1 do
       self:clear_fault_page(i)
    end
end

function _M.check_register(self, fn, page, reg)
    local rv, err = fn(self, page, reg)
    self:clear_fault_page(page)
    if err ~= nil then return false, err end
    return rv >= 0 and rv ~= 0xffff
end

function _M.check_byte_register(self, page, reg)
    return self:check_register(_M.read_byte_data, page, reg)
end

function _M.check_word_register(self, page, reg)
    return self:check_register(_M.read_word_data, page, reg)
end

function _M.identify(self)
    if self.pages == 0 then
        self.pages = 1
        if self:check_byte_register(0, _M.PMBUS_PAGE) then
            for i = 1, 31 do
                local err = self:set_page(i)
                if err == nil then break end
                self.pages = i
            end
            self:set_page(0)
        end
        -- print('PAGES', self.pages)
    end

    if self:check_byte_register(0, _M.PMBUS_VOUT_MODE) then
        local vout_mode = self:read_byte_data(0, _M.PMBUS_VOUT_MODE)
        if vout_mode >= 0 and vout_mode ~= 0xff then
            vout_mode = rshift(vout_mode, 5)
            if vout_mode == 0 then
                -- nop
            elseif vout_mode == 1 then
                self.format[classes.PSC_VOLTAGE_OUT] = data_format.vid
                self.vrm_version = vrm_version.vr11
            elseif vout_mode == 2 then
                self.format[classes.PSC_VOLTAGE_OUT] = data_format.direct
            else
                print('-ENODEV')
            end
        end
    end

    self.mfr_id     = self:read_string_data(_M.PMBUS_MFR_ID, 32)
    self.mfr_refv   = self:read_string_data(_M.PMBUS_MFR_REVISION, 32)
    self.mfr_loc    = self:read_string_data(_M.PMBUS_MFR_LOCATION, 32)
    self.mfr_model  = self:read_string_data(_M.PMBUS_MFR_MODEL, 32)
    self.mfr_serial = self:read_string_data(_M.PMBUS_MFR_SERIAL, 32)

    self:pmbus_find_sensor_groups()
end

function _M.pmbus_find_sensor_groups(self)
    local func = {}, i
    for i = 0, 31 do
        func[i] = 0
    end
    if self:check_word_register(0, _M.PMBUS_READ_VIN) then
        func[0] = bor(func[0], _M.PMBUS_HAVE_VIN)
    end
    if self:check_word_register(0, _M.PMBUS_READ_VCAP) then
        func[0] = bor(func[0], _M.PMBUS_HAVE_VCAP)
    end
    if self:check_word_register(0, _M.PMBUS_READ_IIN) then
        func[0] = bor(func[0], _M.PMBUS_HAVE_IIN)
    end
    if self:check_word_register(0, _M.PMBUS_READ_PIN) then
        func[0] = bor(func[0], _M.PMBUS_HAVE_PIN)
    end
    if func[0] ~= 0 and self:check_word_register(0, _M.PMBUS_STATUS_INPUT) then
        func[0] = bor(func[0], _M.PMBUS_HAVE_STATUS_INPUT)
    end
    if self:check_byte_register(0, _M.PMBUS_FAN_CONFIG_12) and
       self:check_word_register(0, _M.PMBUS_READ_FAN_SPEED_1) then
        func[0] = bor(func[0], _M.PMBUS_HAVE_FAN12)
        if self:check_byte_register(0, _M.PMBUS_STATUS_FAN_12) then
            func[0] = bor(func[0], _M.PMBUS_HAVE_STATUS_FAN12)
        end
    end
    if self:check_byte_register(0, _M.PMBUS_FAN_CONFIG_34) and
       self:check_word_register(0, _M.PMBUS_READ_FAN_SPEED_3) then
        func[0] = bor(func[0], _M.PMBUS_HAVE_FAN34)
        if self:check_byte_register(0, _M.PMBUS_STATUS_FAN_34) then
            func[0] = bor(func[0], _M.PMBUS_HAVE_STATUS_FAN34)
        end
    end
    if self:check_word_register(0, _M.PMBUS_READ_TEMPERATURE_1) then
        func[0] = bor(func[0], _M.PMBUS_HAVE_TEMP)
    end
    if self:check_word_register(0, _M.PMBUS_READ_TEMPERATURE_2) then
        func[0] = bor(func[0], _M.PMBUS_HAVE_TEMP2)
    end
    if self:check_word_register(0, _M.PMBUS_READ_TEMPERATURE_3) then
        func[0] = bor(func[0], _M.PMBUS_HAVE_TEMP3)
    end
    if band(func[0], 0xe00) > 0 and
       self:check_byte_register(0, _M.PMBUS_STATUS_TEMPERATURE) then
        func[0] = bor(func[0], _M.PMBUS_HAVE_STATUS_TEMP)
    end

    -- Sensors detect on all pages
    local page
    for page=0, self.pages-1 do
        if self:check_word_register(page, _M.PMBUS_READ_VOUT) then
            func[page] = bor(func[page], _M.PMBUS_HAVE_VOUT)
            if self:check_byte_register(page, _M.PMBUS_STATUS_VOUT) then
                func[page] = bor(func[page], _M.PMBUS_HAVE_STATUS_VOUT)
            end
        end
        if self:check_word_register(page, _M.PMBUS_READ_IOUT) then
            func[page] = bor(func[page], _M.PMBUS_HAVE_IOUT)
            if self:check_byte_register(page, _M.PMBUS_STATUS_IOUT) then
                func[page] = bor(func[page], _M.PMBUS_HAVE_STATUS_IOUT)
            end
        end
        if self:check_word_register(page, _M.PMBUS_READ_POUT) then
            func[page] = bor(func[page], _M.PMBUS_HAVE_POUT)
        end
    end
    for page=0, self.pages-1 do
        self.exponent[page] = 0
        --print('FUNC['..tostring(page)..']', func[page])
    end

    self.func = func
end

function _M.pmbus_identify_common(self)
    local vout_mode = -1
    if self:check_byte_register(self.page, _M.PMBUS_VOUT_MODE) then
        vout_mode = self:read_byte_data(self.page, _M.PMBUS_VOUT_MODE)
    end

    if vout_mode >=0 and vout_mode ~= 0xff then
        mode = rshift(vout_mode, 5)
        if mode == 0 then -- linear mode
            if self.format[classes.PSC_VOLTAGE_OUT] ~= data_format.linear then
                print('-ENODEV -- linear-mode')
                return
            end
            self.exponent[self.page] = arshift(s8(lshift(vout_mode, 3)), 3)
        elseif mode == 1 then -- VID mode
            if self.format[classes.PSC_VOLTAGE_OUT] ~= data_format.vid then
                print('-ENODEV -- VID mode')
                return
            end
        elseif mode == 2 then -- direct mode
            if self.format[classes.PSC_VOLTAGE_OUT] ~= data_format.direct then
                print('-ENODEV -- direct mode')
                return
            end
        else
            print('-ENODEV')
        end
    end

    self:clear_fault_page(self.page)
end

function _M.add_limit_attrs(self, name, index, page, attrs)
    local n, l
    for n, l in pairs(attrs) do
        if self:check_word_register(page, l.reg) then
            -- local v = self:read_word_data(page, l.reg)
            -- print('ADD '..name..tostring(index)..'_'..n..' = '..tostring(v))
        end
    end
end

function _M.add_sensor_attrs_one(self, name, index, page, attr)
    if attr.limit ~= nil then
        self:add_limit_attrs(attr.label, index, page, attr.limit)
    end
    table.insert(self.attrs, {
        reg = attr.reg,
        page = page,
        label = name..tostring(index),
        func = attr.func,
        class = attr.class,
        paged = attr.paged
    })
end

function _M.read_attributes(self)
    local i, attr
    -- TODO: record values' timestamps
    local ret_attrs = {}
    for i, attr in ipairs(self.attrs) do
        local v, err = self:read_word_data(attr.page, attr.reg)
        if err ~= nil then
            self:unplugged()
            return {}
        end
        attr.value = self:pmbus_reg2data(v, attr)
        ret_attrs[attr.label] = attr.value
    end
    return ret_attrs
end

--
-- Convert linear sensor values to milli- or micro-units
-- depending on sensor type
--
function _M.pmbus_reg2data_linear(self, data, sensor)
    local exponent
    local mantissa
    local val

    if data == nil then
        return nil
    end

    if sensor.class == classes.PSC_VOLTAGE_OUT then -- LINEAR16
        exponent = s16(self.exponent[self.page])
        mantissa = u16(data)
    else -- LINEAR11
        exponent = s16(arshift(s16(data), 11))
        mantissa = arshift(s16(lshift(band(data, 0x7ff), 5)), 5)
    end


    val = mantissa

    -- scale result to milli-units for all sensors but fans
    if sensor.class ~= classes.PSC_FAN then
        val = val * 1000
    end

    -- Dont do it as the result will not fit into S32
--  -- scale result to micro-units for power sensors
--  if sensor.class == classes.PSC_POWER then
--      val = val * 1000
--  end

    if exponent >= 0 then
        val = lshift(val, exponent)
    else
        val = arshift(val, -exponent)
    end

    return val
end

--
-- Convert direct sensor values to milli- or micro-units
-- depending on sensor type
--
function _M.pmbus_reg2data_direct(self, data, sensor)
    local val = data
    local m, b, R

    m = self.m[sensor.class]
    b = self.b[sensor.class]
    R = self.R[sensor.class]

    if m == 0 then
        return 0
    end

    -- X = 1/m * (Y * 10^-R - b)
    R = -R
    -- scale result to milli-units for everything but fans
    if sensor.class ~= classes.PSC_FAN then
        R = R + 3
        b = b * 1000
    end

    -- scale result to micro-units for power sensros
    if sensor.class == PSC_POWER then
        R = R + 3
        b = b * 1000
    end

    while R > 0 do
        val = val * 10
        R = R - 1
    end

    while R < 0 do
        val = val / 10 -- DIV_ROUND_CLOSEST
        R = R + 1
    end

    return (val - b) / m
end

--
-- Convert VID sensor values to milli- or micro-units
-- depending on sensor type
--
function _M.pmbus_reg2data_vid(self, data, sensor)
    local val = data
    local rv = 0
    if self.vrm_version == vrm_version.vr11 then
        if val >= 0x02 and val <= 0xb2 then
            rv = (160000 - (val - 2) * 625) / 100 -- DIV_ROUND_CLOSEST
        end
    elseif self.vrm_version == vrm_version.vr12 then
        if val >= 0x01 then
            rv = 250 + (val - 1) * 5
        end
    end
    return rv
end

function _M.pmbus_reg2data(self, data, sensor)
    local val
    local format = self.format[sensor.class]

    if format == data_format.direct then
        val = self:pmbus_reg2data_direct(data, sensor)
    elseif format == data_format.vid then
        val = self:pmbus_reg2data_vid(data, sensor)
    else -- format == data_format.linear
        val = self:pmbus_reg2data_linear(data, sensor)
    end
    return val
end

function _M.add_fan_attributes(self)
    local page
    local index = 1
    for page=0, self.pages-1 do
        local f, attr
        for f, attr in ipairs(pmbus_fan_registers) do
            if band(self.func[page], attr.func) == 0 then break end

            if not self:check_word_register(page, attr.reg) then break end

            -- Skip fan if not installed.
            -- Each fan configuration regsiter covers multiple fans,
            -- so we have to do some magic

            local regval = self:read_byte_data(page, pmbus_fan_config_registers[f])
            local fan_installed = rshift(_M.PB_FAN_1_INSTALLED, band(f, 1) * 4)
            if (regval == 0xff) or
               (band(regval, fan_installed) == 0) then goto continue end

            table.insert(self.attrs, {
                reg = attr.reg,
                page = page,
                label = 'fan'..tostring(index),
                func = attr.func,
                class = attr.class,
                paged = attr.paged
            })

            index = index + 1
            ::continue::
        end
    end
end

function _M.pmbus_add_sensor_attrs(self, name, attrs)
    local i, attr
    local index = 1
    for i, attr in ipairs(attrs) do
        local page, pages
        pages = attrs.paged and self.pages-1 or 0
        for page=0, pages do
            if band(self.func[page], attr.func) ~= 0 then
                self:add_sensor_attrs_one(name, index, page, attr)
                index = index + 1
            end
        end
    end
end

function _M.pmbus_find_attributes(self)
    local ret
    -- Voltage sensors
    ret = self:pmbus_add_sensor_attrs('in', voltage_attributes)

    -- Current sensors
    ret = self:pmbus_add_sensor_attrs('curr', current_attributes)

    -- Power sensors
    ret = self:pmbus_add_sensor_attrs('power', power_attributes)

    -- Temperature sensors
    ret = self:pmbus_add_sensor_attrs('temp', temp_attributes)

    -- Fans
    return self:add_fan_attributes()
end

function _M.pmbus_init_common(self)
    self:set_page(0)
    local ret, err = self:i2c_read_byte_data(_M.PMBUS_STATUS_BYTE)
    if ret == nil or ret == 0xff then
        ret, err  = self:i2c_read_word_data(_M.PMBUS_STATUS_WORD)
        if ret == nil or ret == 0xffff or err ~= nil then
            print('PMBus status register not found: '..tostring(err))
            return err
        end
        --print('WORD')
    --else
        --print('BYTE')
    end

    self:clear_faults()

    self:identify()

    local page
    for page=0, 31 do
        self:pmbus_identify_common(page)
    end
end

function _M.do_probe(self)
    local err = self:pmbus_init_common()
    if err ~= nil then return err end
    self:pmbus_find_attributes()
    self.present = true
    if self.on_plug then
        self:on_plug()
    end
end

function _M.ping(self)
    local newpage, err = self:i2c_read_byte_data(_M.PMBUS_PAGE)
    if err ~= nil then
        return false
    end

    self:do_probe()
    return true
end

function _M.unplugged(self)
    if self.on_unplug then
        self:on_unplug()
    end
    self.present = false
    self.mfr_serial = nil
    self.mfr_model = nil
    self.mfr_id = nil
    self.mfr_loc = nil
    self.mfr_rev = nil
    self.page  = -1
    self.pages = 0
    self.format = {}
    self.vrm_version = nil
    self.m = {}
    self.b = {}
    self.R = {}
    self.func = {}
    self.exponent = {}
    self.sensors = {}
    self.attrs = {}
end

return _M
