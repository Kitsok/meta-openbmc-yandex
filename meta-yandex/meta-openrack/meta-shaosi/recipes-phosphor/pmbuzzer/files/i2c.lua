local ffi = require 'ffi'
local nixio = require 'nixio'
local fopen = nixio.open

ffi.cdef[[
   int fileno(void *fp);
   int ioctl(int d, unsigned int request, ...);
]]

local C = ffi.C
local insert = table.insert

local _ioctl = function(f, ...) return C.ioctl(f:getfd(), ...) end

local I2C_M_RD  = 0x0001
local I2C_RDWR  = 0x0707
local I2C_SMBUS = 0x0720
local I2C_RDWR_IOCTL_MAX_MSGS = 42

ffi.cdef[[
struct i2c_msg
{
	uint16_t addr;
	uint16_t flags;
	uint16_t len;
	uint8_t *buf;
};

struct i2c_rdwr_ioctl_data
{
	struct i2c_msg *msgs;
	uint32_t nmsgs;
};
]]

local _M = {}

local mt = { __index = _M }

function _M.new(self, bus)
    local t = {
	bus = bus,
	msgs = { },
	f = fopen('/dev/i2c-'..tonumber(bus))
    }

    if not t.f then return end

    getmetatable(t.f).getfd = function(self) return tonumber(tostring(self):sub(12)) end

    return setmetatable(t, mt)
end

function _M.read(self, addr, cnt)
    local rd_msg = ffi.new('uint8_t[?]', cnt)
    insert(self.msgs, { addr, I2C_M_RD, cnt, rd_msg })
end

function _M.write(self, addr, data)
    local wr_msg = ffi.new('uint8_t[?]', #data)
    ffi.copy(wr_msg, data)
    insert(self.msgs, { addr, 0, #data, wr_msg })
end

function _M.flush(self)
    local nmsg = #self.msgs
    local msgs = ffi.new('struct i2c_msg[?]', nmsg, self.msgs)

    local ioctl_data = ffi.new('struct i2c_rdwr_ioctl_data[1]', {
        { msgs, nmsg }
    })

    if _ioctl(self.f, I2C_RDWR, ioctl_data) ~= nmsg then
        self.msgs = { }
        return nil, nil, 'ioctl failed'
    end

    data = { }
    for i, v in ipairs(self.msgs) do
        if v[2] == I2C_M_RD then
           insert(data, ffi.string(ioctl_data[0].msgs[i-1].buf, v[3]))
        end
    end
    self.msgs = { }

    return nmsg, data
end

function _M.rdwr(self, addr, to_write, to_read)
    if #to_write > 0 then self:write(addr, to_write) end
    if to_read > 0 then self:read(addr, to_read) end

    local nmsg, data, err = self:flush()
    if err == nil then
        return nmsg, data[1]
    end
    return nil, nil, err
end

return _M
