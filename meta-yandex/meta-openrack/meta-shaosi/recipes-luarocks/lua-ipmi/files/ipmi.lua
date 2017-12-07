local bin = require 'struct'
local bit = require 'bit'
local nixio = require 'nixio'
local ffi = require 'ffi'

local fopen = nixio.open
local hash = nixio.crypto.hash
local stpack, stunpack = bin.pack, bin.unpack
local bor, band, bxor, lshift, rshift = bit.bor, bit.band, bit.bxor, bit.lshift, bit.rshift
local byte, sub, match = string.byte, string.sub, string.match
local pow, max = math.pow, math.max

local IOC = {
  SIZEBITS = 14,
  DIRBITS = 2,
  NONE = 0,
  WRITE = 1,
  READ = 2,
}

IOC.READWRITE = IOC.READ + IOC.WRITE

IOC.NRBITS = 8
IOC.TYPEBITS = 8

IOC.NRSHIFT = 0
IOC.TYPESHIFT = IOC.NRSHIFT + IOC.NRBITS
IOC.SIZESHIFT = IOC.TYPESHIFT + IOC.TYPEBITS
IOC.DIRSHIFT  = IOC.SIZESHIFT + IOC.SIZEBITS

local function _IOC(dir, ch, nr, size)
    return bor(lshift(dir, IOC.DIRSHIFT),
                   lshift(byte(ch), IOC.TYPESHIFT),
                   lshift(nr, IOC.NRSHIFT),
                   lshift(size, IOC.SIZESHIFT))
end

local _IO    = function(ch, nr)		return _IOC(IOC.NONE, ch, nr, 0) end
local _IOR   = function(ch, nr, tp)	return _IOC(IOC.READ, ch, nr, tp) end
local _IOW   = function(ch, nr, tp)	return _IOC(IOC.WRITE, ch, nr, tp) end
local _IOWR  = function(ch, nr, tp)	return _IOC(IOC.READWRITE, ch, nr, tp) end

local sizeof_ipmi_msg = 8
local sizeof_ipmi_recv = 16 + sizeof_ipmi_msg
local sizeof_ipmi_req = 12 + sizeof_ipmi_msg
local sizeof_ipmi_cmdspec = 4
local sizeof_ipmi_system_interface_addr = 8
local IPMICTL_RECEIVE_MSG_TRUNC		= _IOWR('i', 11, sizeof_ipmi_recv)
local IPMICTL_RECEIVE_MSG		= _IOWR('i', 12, sizeof_ipmi_recv)
local IPMICTL_SEND_COMMAND		= _IOR('i', 13, sizeof_ipmi_req)
local IPMICTL_REGISTER_FOR_CMD		= _IOR('i', 14, sizeof_ipmi_cmdspec)
local IPMICTL_UNREGISTER_FOR_CMD	= _IOR('i', 15, sizeof_ipmi_cmdspec)
local IPMICTL_SET_GETS_EVENTS_CMD	= _IOR('i', 16, 4)
local IPMICTL_SET_MY_ADDRESS_CMD	= _IOR('i', 17, 4)
local IPMICTL_GET_MY_ADDRESS_CMD	= _IOR('i', 18, 4)
local IPMICTL_SET_MY_LUN_CMD		= _IOR('i', 19, 4)
local IPMICTL_GET_MY_LUN_CMD		= _IOR('i', 20, 4)

local IPMI_BMC_CHANNEL			= 0xf
local IPMI_SYSTEM_INTERFACE_ADDR_TYPE	= 0x0c
local IPMI_IPMB_ADDR_TYPE		= 0x01
local IPMI_IPMB_BROADCAST_ADDR_TYPE	= 0x41
local IPMI_RESPONSE_RECV_TYPE		= 1
local IPMI_ASYNC_EVENT_RECV_TYPE	= 2
local IPMI_CMD_RECV_TYPE		= 3

ffi.cdef[[
   int fileno(void *fp);
   int ioctl(int d, unsigned int request, ...);

   struct ipmi_msg {
      uint8_t netfn;
      uint8_t cmd;
      uint16_t data_len;
      uint8_t *data;
   };

   typedef struct {
      struct ipmi_msg;
      uint8_t d[?];
   } ipmi_msg;

   struct ipmi_req {
      uint8_t *addr;
      uint32_t addr_len;
      long msgid;
      struct ipmi_msg msg;
   };

   typedef struct {
      struct ipmi_req;
      uint8_t a[32];
      uint8_t d[?];
   } ipmi_req;

   struct ipmi_recv {
      int recv_type;
      uint8_t *addr;
      uint32_t addr_len;
      long msgid;
      struct ipmi_msg msg;
   };

   typedef struct {
      struct ipmi_recv;
      uint8_t a[32];
      uint8_t d[?];
   } ipmi_recv;

   struct ipmi_cmdspec {
      uint8_t netfn;
      uint8_t cmd;
   };

   struct ipmi_system_interface_addr {
      int32_t addr_type;
      int16_t channel;
      uint8_t lun;
   };

   struct ipmi_ipmb_addr {
      int32_t addr_type;
      int16_t channel;
      uint8_t slave_addr;
      uint8_t lun;
   };

   typedef long time_t;

   typedef struct timeval {
      time_t tv_sec;
      time_t tv_usec;
   } timeval;

   int gettimeofday(struct timeval* t, void* tzp);
]]

local C = ffi.C

local _ioctl = function(fd, ...) return C.ioctl(fd:getfd(), ...) end

local gettimeofday_struct = ffi.new("timeval")

local function gettimeofday()
   C.gettimeofday(gettimeofday_struct, nil)
   return tonumber(gettimeofday_struct.tv_sec), tonumber(gettimeofday_struct.tv_usec)
end

function _checksum(data)
    local i
    local csum = 0
    for i = 1, #data do
        csum = csum + byte(data, i)
    end
    csum = bxor(csum, 0xff) + 1
    return band(csum, 0xff)
end

--
-- Lan interface
--
local _L = {
    PAYLOADS = {
        IPMI = 0x00,
        SOL = 0x01,
        RMCPPLUSOPENREQ = 0x10,
        RMCPPLUSOPENRESPONSE = 0x11,
        RAKP1 = 0x12,
        RAKP2 = 0x13,
        RAKP3 = 0x14,
        RAKP4 = 0x15
    },

    RMCP_CODES = {
        [1] = 'Insufficient resources to create new session \
               (wait for existing sessions to timeout)',
        [2] = 'Invalid Session ID',
        [3] = 'Invalid payload type',
        [4] = 'Invalid authentication algorithm',
    }
}

local L_mt = { __index = _L }

L_mt.__ipairs = function(self)
    local idx = self._cmdidx
    local interval = self._interval
    local max_interval = self._max_interval
    return function()
        i = i + 1
        if i <= max_interval and (i % idx) == 0 then
            local c = self._cmds[i]
            local cidx = c._idx
            c._idx = (c._idx + 1) % #c
            return i, c[cidx]
        end
    end
end

function _L.new(self, sock, user, passwd, cmds, sdrs, authtype)
    local t = {
        _sock = sock,
        _user = user,
        _passwd = passwd,
        _kg = passwd,
        _cmds = {},
        _sdrs = sdrs or {},
        sdr_ttl = {},
        sdr_names = {},
        _sdr_cmds = {},
        _sdr_cached = false,
        _reqauth = authtype or 2,
        _interval = 1,
        _max_interval = 0,
        _intervals = {},
        _round = 0,
        _retry = 0,
    }

    local i, c
    for i, c in pairs(cmds or {}) do
        if type(i) == 'number' then
            t._cmds[i] = {}
            local tc = t._cmds[i]
            local ci, cv
            for ci, cv in ipairs(c) do
                tc[ci] = cv
            end
            table.insert(t._intervals, i)
            t._max_interval = max(i, t._max_interval)
            tc._idx = 0
        else
            t._cmds[i] = c
        end
    end
    t._sdr_read_cb = t._cmds['sdr_read']
    t._ready_cb = t._cmds['ready']
    table.sort(t._intervals)
    local obj = setmetatable(t, L_mt)
    obj:_initsession()
    return obj
end

function _L.close(self)
    self._sock:close()
end

function _L._initsession(self)
    self._cycles = 0
    self._logged = false
    self._localsid = stunpack('>I', 'MAYC')-1
    self._privlevel = 4 -- admin access
    self._confalgo = 0
    self._aeskey = false
    self._integrityalgo = 0
    self._k1 = false
    self._k2 = false
    self._rmcptag = 1
    self._sessionid = string.rep('\x00', 4)
    self._authtype = 0
    self._lastpayload = false
    self._seqlun = 0
    self._sequencenumber = 0
    self._ipmiversion = 0x15
    self._ipmi15only = true
    self._ver = 0
    self._Lfg = -1
    self._prod = -1
    self._builtin_dr = false
    self._rqaddr = 0x81 -- per IPMI talbe 5-4, software ids in the ipmi spec may
                        -- be 0x81 through 0x8d. We'll stick with 0x81 for now,
                        -- do not forsee a reason to adjust
    self._cmdidx = 0
    self._send = _L._presence_ping
    self._recv = false
    self._oldpayload = false
end

function _L._ipmi15authcode(self, payload, checkremotecode)
    if self._authcode == 0 then
        return ''
    end

    local password = self._passwd
    local padneeded = 16 - #password
    if padneeded < 0 then
        print('Password too long for ipmi 1.5')
        return nil
    end
    password = password .. string.rep('\x00', padneeded)
    local seqbytes
    if checkremotecode then
        --
    else
        seqbytes = stpack('<I', self._sequencenumber)
    end
    local md5 = hash('md5')
    md5:update(password)
    md5:update(self._sessionid)
    md5:update(payload)
    md5:update(seqbytes)
    md5:update(password)
    local hex, bin = md5:final()
    return bin
end

function _L._make_ipmi_payload(self, netfn, command, ...)
--    local seqinc = 7 -- IPMI spec forbids gaps bigger than 7 in seq number

    local reqbody
    local header = stpack('BB', 0x20, lshift(netfn, 2))
    local argc = select('#', ...)
    if argc > 0 and type(select(1, ...)) == 'string' then
        reqbody = stpack('BBBc0', self._rqaddr, self._seqlun, command, ...)
    else
        reqbody = stpack('BBB'..string.rep('B', argc), self._rqaddr, self._seqlun, command, ...)
    end

    return stpack('c0Bc0B', header, _checksum(header), reqbody, _checksum(reqbody))
end

function _L._send_payload(self, netfn, command, ...)
    local ipmipayload = self:_make_ipmi_payload(netfn, command, ...)
    local payload_type = _L.PAYLOADS.IPMI
    if self._integrityalgo ~= 0 then
        payload_type = bor(payload_type, 0x40)
    end
    if self._confalgo ~= 0 then
        payload_type = bor(payload_type, 0x80)
    end

    return self:_pack_payload(ipmipayload, payload_type)
end

function _L._pack_payload(self, payload, payload_type)
    if not payload then
        payload = self._lastpayload
    end
    if not payload_type then
        payload_type = self._last_payload_type
    end
    local message = stpack('BBBB', 0x6, 0, 0xff, 0x07) -- constant RMCP header for IPMI
    local baretype = band(payload_type, 0x3f)
    self._lastpayload = payload
    self._last_payload_type = payload_type
    message = message .. stpack('B', self._authtype)
    if self._ipmiversion == 0x20 then
       --
    end

    message = message .. stpack('<I', self._sequencenumber)
    if self._ipmiversion == 0x15 then
        message = message..self._sessionid
        if self._authtype == 2 then -- MD5
            message = message .. stpack('c0', self:_ipmi15authcode(payload))
        elseif self._authtype == 4 then -- PASSWORD
            message = message .. self._passwd .. string.rep('\x00', 16 - #self._passwd)
        end
        message = stpack('c0Bc0', message, #payload, payload)
        local tl = 34 + #message
        if tl == 56 or tl == 84 or tl == 112 or tl == 128 or tl == 156 then
            message = message .. '\x00' -- legacy pad as mandated by ipmi spec
        end
    elseif self._ipmiversion == 0x20 then
        --
        print('IPMI v2.0')
    end

    if self._sequencenumber ~= 0 then
        self._sequencenumber = self._sequencenumber + 1
    end

    return self._sock:send(message)
end

function _L.send(self)
    if self._send and not self._stopped then
        -- if self._DEBUG then print(self.n, prettyinfo(self, self._send), 'stopped', self._stopped, 'logged', self._logged, 'tout', self._timedout) end
        return self:_send()
    else
        return 0
    end
end

function _L.recv(self)
    local data = self._sock:recv(1024)
    if data == nil or #data == 0 then return false end

    local payload
    local is_asf = false
    if byte(data, 1) == 0x06 and byte(data, 3) == 0xff and byte(data, 4) == 0x06 then
        payload = sub(data, 6)
        is_asf = true
    elseif not (byte(data, 1) == 0x06 and byte(data, 3) == 0xff and byte(data, 4) == 0x07) then
        -- not valid IPMI
        print('Not valid IPMI')
        return false
    end

    if self._DEBUG then print(self.ip, '<<<<<', nixio.bin.hexlify(data), prettyinfo(self, self._send), prettyinfo(self, self._recv), self._interval) end

    if not is_asf and (byte(data, 5) == 0x00 or byte(data, 5) == 0x02 or byte(data, 5) == 0x04) then
        -- IPMI v1.5
        local seqnumber = stunpack('<I', sub(data, 6, 9))
        if byte(data, 5) ~= self._authtype then
            -- logout
            -- BMC responded with mismatch authtype
            print('BMC responded with mismatch authtype')
            return false
        end

        if self._sessionid ~= sub(data, 10, 13) and self._sessionid ~= '\x00\x00\x00\x00' then
            self:_initsession()
            return true
        end

        local authcode
        if byte(data, 5) == 0x02 or byte(data, 5) == 0x04 then
            authcode = sub(data, 14, 29)
            local sz = byte(data, 30)+30
            payload = sub(data, 31, sz)
        else
            local sz = byte(data, 14)+14
            payload = sub(data, 15, sz)
        end
        -- TODO: check _ipmi15authcode
    end

    self._seqlun = self._seqlun + 4
    self._seqlun = band(self._seqlun, 0xff)

    -- unordr

    if not self._recv then return false end

    -- unset receive function
    local fn = self._recv
    self._recv = false
    return fn(self, payload)
end

function _L.logout(self)
    self._recv = false
    self._send = false
    if not self._logged then return 0 end
    self._logged = false
    self._stopped = true
    self._sdr_cached = false
    return self:_send_payload(0x6, 0x3c, self._sessionid)
end

function _L._got_logout(self, response)
    self._recv = false
    self._send = false
    self._logged = false
    self._stopped = true
    return true
end

function _L._presence_ping(self)
    self._send = _L._get_channel_auth_cap
    self._recv = _L._presence_pong
    local message = { 0x6, 0, 0xff, 0x06,
        0, 0, 0x11, 0xbe, 0x80, 0, 0, 0 }
    
    if self._sequencenumber ~= 0 then
        self._sequencenumber = self._sequencenumber + 1
    end

    return self._sock:send(stpack(string.rep('B', #message), unpack(message)))
end

function _L._presence_pong(self, response)
    return true
end

function _L._get_channel_auth_cap(self)
    self._recv = _L._got_channel_auth_cap
    if self._ipmi15only then
        return self:_send_payload(0x6, 0x38, 0x0e, self._privlevel)
    else
        return self:_send_payload(0x6, 0x38, 0x8e, self._privlevel)
    end
end

function _L._got_channel_auth_cap(self, response)
    self._recv = false

    if byte(response, 7) == 0xcc then
        self._ipmi15only = true
        self._send = _L._get_channel_auth_cap
        return true
    end

    -- TODO: check IPMI error for (netfn, command)

    self._currentchannel = byte(response, 8)
    if #response < 11 then
        print('Too short reponse')
        return false
    end

    if band(byte(response, 9), 0x80) == 0x80 and band(byte(response, 11), 0x02) == 0x02 then
        -- ipmi 2.0 support
        self._ipmiversion = 0x20
    end

    if self._ipmiversion == 0x15 then
        if band(byte(response, 9), 0x04) == 0 then
            print('MD5 is required but not enabled/available on target BMC')
            return false
        end
        self._send = _L._get_session_challenge
    elseif self._ipmiversion == 0x20 then
        self._send = _L._open_rmcpplus_request
    else
        return false
    end

    return true
end

function _L._get_session_challenge(self)
    local padneeded = 16 - #self._user

    if padneeded < 0 then
        print('Username too long for IPMI')
        return false
    end

    self._recv = _L._got_session_challenge
    return self:_send_payload(0x6, 0x39, stpack('B', self._reqauth)..self._user..string.rep('\x00', padneeded))
end

function _L._got_session_challenge(self, response)
    self._sessionid = sub(response, 8, 11)
    self._authtype = self._reqauth
    self._challenge = sub(response, 12, #response-1)

    self._recv = false
    self._send = _L._activate_session

    return true
end

function _L._activate_session(self)
    self._recv = _L._activated_session
    -- TODO(jbjohnso): this always requests admin level (1.5)
    return self:_send_payload(0x6, 0x3a, stpack('BB', self._authtype, 0x04)..self._challenge..'\x01\x00\x00\x00')
end

function _L._activated_session(self, data)
    self._logontries = 5
    if byte(data, 7) ~= 0 then
        -- print('Session activate: '..tostring(byte(data, 7)))
        -- disconnect
        return false
    end

    self._sessionid = sub(data, 9, 12)
    self._sequencenumber = stunpack('<I', sub(data, 13, 16))
    self._recv = false
    self._send = _L._req_priv_level

    return true
end

function _L._req_priv_level(self)
    self._recv = _L._got_priv_level
    return self:_send_payload(0x6, 0x3b, self._privlevel)
end

function _L._got_priv_level(self, response)
    if (byte(response, 7) == '\x80' or byte(response, 7) == '\x81') and self._privlevel == 4 then
        print('degrade privlevel')
        self._logged = true
--        self:_logout()
        self:_initsession()
        self._privlevel = 3
        return true
    end

    self._logged = true
    if next(self._sdrs) ~= nil then
        self._send = self._get_product_id
    else
        self._send = self._process_next_cmd
    end

    return true
end

function _L._get_product_id(self)
    self._recv = _L._got_product_id
    return self:_send_payload(0x6, 0x1)
end

function _L._got_product_id(self, response)
    if #response < 18 then return false end

    self._ver = stunpack('>H', sub(response, 10, 11))
    self._mfg = stunpack('<I', sub(response, 14, 16) .. '\x00')
    self._prod = stunpack('<H', sub(response, 17, 18))
    self._builtin_sdr = band(byte(response, 9), 0x80) == 0x80 and band(byte(response, 13), 0x03) == 0x01

    if self._builtin_sdr then
        --            Func  Rec   Cnt   Rsvd
        self._sdr = { 0x04, 0x21, 0x00, 0x00 }
    else
        self._sdr = { 0x0a, 0x23, 0x00, 0x00 }
    end

    if not self._sdr_cached and next(self._sdrs) ~= nil then
        self._send = _L._get_sdr_info
    else
        self._logged = true
        self._send = _L._process_next_cmd
        -- self._stopped = true
        if self._ready_cb then self:_ready_cb() end
        if self._DEBUG then print(self.ip or self.n, 'READY!') end
    end

    return true
end

function _L._get_sdr_info(self)
    self._recv = _L._got_sdr_info
    return self:_send_payload(self._sdr[1], 0x20)
end

function _L._got_sdr_info(self, repo)
    if #repo < 10 then
        if self._DEBUG then print('_L._got_sdr_info fail') end
        return false
    end
    self._sdr[3] = stunpack('<H', sub(repo, 9, 10))
--    self._send = _L._get_sdr_reserve
    self._sdr_recid = 0
    self._sdr_idx = 0
    self._sdr_type = 0
    self._send = _L._get_sdr_header

    return true
end

function _L._get_sdr_reserve(self)
    self._recv = _L._got_sdr_reserve
    return self:_send_payload(self._sdr[1], 0x22)
end

function _L._got_sdr_reserve(self, response)
    if #response < 9 then return false end

    if byte(response, 7) ~= 0 then
--        self._logged = true
--        self._send = false
        if self._DEBUG then print('_L._got_sdr_reserve fail') end
        return false
    end
    -- self._sdr[4] = stunpack('<H', sub(response, 8, 9))
    self._sdr_recid = 0
    self._sdr_idx = 0
    self._sdr_type = 0
    self._send = _L._get_sdr_header

    return true
end

function _L._get_sdr_header(self)
    self._recv = _L._got_sdr_header
    local payload = stpack('<H<HBB', self._sdr[4], self._sdr_recid, 0, 5)
    return self:_send_payload(self._sdr[1], self._sdr[2], payload)
end

function _L._got_sdr_header(self, header)
    if byte(header, 7) ~= 0 or #header < 14 then
        -- self._logged = true
        if self._DEBUG then print('c_L._got_sdr_header fail') end
        return false
    end

    self._sdr_nextid = stunpack('<H', sub(header, 8, 9))
    self._sdr_type = byte(header, 13)
    if self._sdr_type ~= 0x01 and self._sdr_type ~= 0x02 then -- SDR_RECORD_TYPE_FULL_SENSOR || SDR_RECORD_TYPE_COMPACT_SENSOR
        _L._next_sdr_or_ready(self)
        return true
    end

    self._sdr_len = byte(header, 14)
    self._send = _L._get_sdr_record

    return true
end

function _L._get_sdr_record(self)
    self._recv = _L._got_sdr_record
    local payload = stpack('<H<HBB', self._sdr[4], self._sdr_recid, 5, self._sdr_len)
    return self:_send_payload(self._sdr[1], self._sdr[2], payload)
end

function _L._got_sdr_record(self, record)
    if #record < 30 then -- FIXME: check for minimal length of COMPACT_SENSOR record
        if #record ~= 7 then
            _L._next_sdr_or_ready(self)
            if self._DEBUG then print('_L._next_sdr_or_ready', self._sdr_type, byte(record, 8+8), nixio.bin.hexlify(record)) end
            return true
        end

        -- Retry on timeout
        local rc = byte(record, 7)
        if rc == 0xc3 or rc == 0xff then
            if self._retry < 4 then
               self._retry = self._retry + 1
            else
               -- print(self.n, rc, 'timeouted')
               self._stopped = true
               self._retry = 0
            end
            return false
        end

        _L._next_sdr_or_ready(self)
        return true
    end

    local name, size

    if self._sdr_type == 2 and #record >= 37 then
         size = band(byte(record, 36), 0x1f)
         name = sub(record, 37, 36+size):upper()
    else if self._sdr_type ~= 2 and #record >= 53 then
              size = band(byte(record, 52), 0x1f)
              name = sub(record, 53, 52+size):upper()
	 else
	      return false
         end
    end

    if self._sdr_type ~= 0x01 and self._sdr_type ~= 0x02 and self._sdr_type ~= 0x04 and self._sdr_type ~= 0x08 and self._sdr_type ~= 0x0d then
        _L._next_sdr_or_ready(self)
        return true
    end

    local interval, ttl, found
    if #self._sdrs > 0 then
        local i, p
        for i, p in ipairs(self._sdrs) do
            local m = p[1] -- match pattern
            found = match(name, '^'..m..'$') ~= nil
            if found then
                local s = p[4] -- optional replace pattern
                if s ~= nil then name = string.gsub(name, m, s) end
                interval = p[2]
                ttl = p[3]
                break
            end
        end
    else
        interval = 1
        ttl = 0.0
        found = true
    end

    -- No match, do not add
    if not found then
        _L._next_sdr_or_ready(self)
        return true
    end

    -- reserve a space for interval commands
    if self._cmds[interval] == nil then
        self._cmds[interval] = { _idx = 0 }
        table.insert(self._intervals, interval)
        table.sort(self._intervals)
    end

    if self._sdr_type == 2 then
        table.insert(self._cmds[interval], {
            -- callback
            _L._cmd_got_sensor_reading,
            -- netfn, cmd
            0x4, 0x2d,
            -- number
            byte(record, 12),
            -- name
            name,
            -- unit
            3, -- not an analog sensor
        })

        self.sdr_ttl[name] = ttl
        table.insert(self.sdr_names, name)

        _L._next_sdr_or_ready(self)
        return true
    end

    local tos32 = function(val, bits)
        if band(val, lshift(1, bits-1)) ~= 0 then
            return bor(-band(val, lshift(1, bits-1)), val)
        else
            return val
        end
    end

    local mtol = stunpack('>H', sub(record, 29, 30))
    local bacc = stunpack('>I', sub(record, 31, 34))

    table.insert(self._cmds[interval], {
        -- callback
        _L._cmd_got_sensor_reading,
        -- netfn, cmd
        0x4, 0x2d,
        -- number
        byte(record, 12),
        -- name
        name,
        -- unit
        rshift(byte(record, 25), 6),
        -- linear
        band(byte(record, 28), 0x7f),
        -- __TO_M
        tos32(bor(rshift(band(mtol, 0xff00), 8),
                 (lshift(band(mtol, 0xc0), 2))), 10),
        -- __TO_B
        tos32(bor(rshift(band(bacc, 0xff000000), 24),
                 (rshift(band(bacc, 0xc00000), 14))), 10),
        -- __TO_R_EXP
        tos32(rshift(band(bacc, 0xf0), 4), 4),
        -- __TO_B_EXP
        tos32(band(bacc, 0xf), 4)
    })
    self.sdr_ttl[name] = ttl
    table.insert(self.sdr_names, name)

    _L._next_sdr_or_ready(self)
    return true
end

function _L._next_sdr_or_ready(self)
    local ready = false
    if not self._sdr_cached then
        self._sdr_idx = self._sdr_idx + 1
        self._sdr_recid = self._sdr_nextid
        ready = self._sdr_idx == self._sdr[3]
    else
        ready = true
    end
    if ready then
        self._sdr_idx = 0
        self._sdr_cached = true
        self._logged = true
        self._send = _L._process_next_cmd
        -- self._stopped = true
        if self._ready_cb then self:_ready_cb() end
        if self._DEBUG then print(self.n, 'READY!') end
    else
        self._send = _L._get_sdr_header
    end
end

function _L._cmd_got_sensor_reading(self, resp)
    if #resp < 9 then
        if #resp ~= 7 then return true end

	-- Retry on timeout
        local rc = byte(resp, 7)
        if rc == 0xc3 or rc == 0xff then
            if self._retry < 4 then
               self._retry = self._retry + 1
            else
               -- print(self.n, rc, 'timeouted')
               self._stopped = true
               self._retry = 0
            end
            return false
        end
        return true
    end

    if not (byte(resp, 7) == 0 and band(byte(resp, 9), 0x20) ~= 0x20 and band(byte(resp, 9), 0x40) == 0x40) then
--        if self._sdr_read_cb ~= nil then
--            self:_sdr_read_cb(self._cmds[self._cmdidx+1][5], 'na')
--        end
        -- print(self.n, '_L._cmd_got_sensor_reading fail')
        return true
    end

    local c = self._cmds[self._intervals[self._interval]]
    local name,t,l,m,b,k2,k1 = unpack(c[c._idx + 1], 5)
    local val = byte(resp, 8)
    if t == 1 then
        if band(val, 0x80) == 0x80 then val = val + 1 end
    end
    if t > 0 then
        -- make int8_t from uint8_t
        val = stunpack('b', stpack('B', val))
    end

    local result
    if t > 2 then
        -- Ooops! This isn't an analog sensor
        result = val
    else
        result = ((m * val) + (b * pow(10, k1))) * pow(10, k2)
    end

    if self._sdr_read_cb ~= nil then
        self:_sdr_read_cb(name, result)
    end

    return true
end

function _L._process_next_cmd(self)
    if next(self._cmds) == nil then
        self._stopped = true
        return 0
    end
    self._recv = _L._got_next_cmd
    local c = self._cmds[self._intervals[self._interval]]
    local cmd = c[c._idx + 1]
    if type(cmd[4]) == 'table' then
        return self:_send_payload(cmd[2], cmd[3], unpack(cmd[4] or {}))
    elseif cmd[4] then
        return self:_send_payload(cmd[2], cmd[3], cmd[4])
    else
        return self:_send_payload(cmd[2], cmd[3])
    end
end

function _L.next_interval(self, iv)
    local i, v
    local ci = self._intervals[iv] or -1
    for i, v in ipairs(self._intervals) do
        if self._DEBUG then print('ci', ci, 'i', i, 'v', v, 'cur', self._interval, 'round', self._round, '%', self._round % v, 'max interval', self._max_interval) end
        -- on zero-round run all, then exclude zero-round commands
        if (v > ci) and (self._round == 0 or (v ~= 0 and self._round % v == 0)) then
            if self._DEBUG then print('NEW INTERVAL', i,'v',v,'round', self._round) end
            return true, i
        end
    end
    return false, -1
end

function _L._got_next_cmd(self, response)
    local c = self._cmds[self._intervals[self._interval]]
    if c[c._idx + 1][1](self, response) == false then
        if self._DEBUG then print(self.n, 'FAIL', prettyinfo(self, self._recv), prettyinfo(self, self._send)) end
        return false
    end

    c._idx = (c._idx + 1) % #c
    if c._idx == 0 then
        -- if true then print(self.n, 'idx', self._interval, 'interval', self._intervals[self._interval], '#intervals', #self._intervals) end
        -- get next interval for the same round
        local ok, ni = _L.next_interval(self, self._interval)
        if not ok then
            local cr = self._round
            repeat
               self._round = self._round + 1
               if self._round > self._max_interval then self._round = 1 end
               ok, ni = _L.next_interval(self, ni)
            until ok or self._round == cr
            -- restore old round value
            if self._round == cr or cr == 0 then
                self._round = 1
            else
                self._round = cr + 1
            end
            self._interval = ni
            self._stopped = true
            if self._DEBUG ~= nil then print(self.n, 'ROUND', self._round, 'stopped', self._stopped, 'logged', self._logged, 'tout', self._timedout, 'interval', self._interval) end
        else
            self._interval = ni
        end
    end

    return true
end

function _L.process_commands(self)
    -- check current round & interval
    if self._round > 0 and self._round % self._intervals[self._interval] ~= 0 then
         -- print('NEXT ROUND', self._round, 'interval', self._interval, 'max', self._max_interval, 'v', self._intervals[self._interval], 'id', self.ip or self.n)
         self._round = self._round + 1
         if self._round > self._max_interval then self._round = 1 end
         return 0
    end

    if self._send then
         if self._DEBUG then print('PROCESS', prettyinfo(self, self._send), 'logged', self._logged, 'stopped', self._stopped, 'tout', self._timedout, 'round', self._round, 'id', self.ip or self.n) end
         -- handle timeouts, first run starts counting
         if self._timedout == nil then
             self._timedout = 0
         -- ...for the next three iterations
         elseif self._timedout < 3 and self._logged then
             self._timedout = self._timedout + 1
         -- ...and fire re-send on 4th
         else
             self._timedout = nil
             return self:_send()
         end
    else
         if self.ip ~= nil then print(self.n, self.ip, 'PROCESS send NULL', 'logged', self._logged, 'stopped', self._stopped, 'tout', self._timedout) end
    end
    if not self._logged or not self._stopped then return 0 end

    local tm = self._tm or 0
    self._tm = gettimeofday()
    self._tm_delta = self._tm - tm
    self._stopped = false
    self._timedout = nil
    self._send = self._process_next_cmd
    return self:send()
end

function _L.command(self, cb, netfn, cmd, ...)
    self._recv = cb
    return self:_send_payload(netfn, cmd, ...)
end

--
-- OpenIPMI interface
--
local _O = {
    send = _L.send,
    process_commands = _L.process_commands,
    command = _L.command,
}

local O_mt = { __index = _O }

O_mt.__ipairs = L_mt.__ipairs

function _O.new(self, devnum, cmds, sdrs)
    local t = {
        n = devnum,
        f = fopen('/dev/ipmi'..tonumber(devnum)),
        req = ffi.new('ipmi_req', 256),
        rsp = ffi.new('ipmi_recv', 256),
        bmc_addr = ffi.new('struct ipmi_system_interface_addr[1]'),
        ipmb_addr = ffi.new('struct ipmi_ipmb_addr[1]'),
        sdr_ttl = { },
        sdr_names = { },
        _cmds = { },
        _sdrs = sdrs or { },
        _cmdidx = 0,
        _sdr_cmds = { },
        _sdr_cached = false,
        _stopped = true,
        _logged = false,
        _send = _L._get_product_id,
        _recv = false,
        _interval = 1,
        _intervals = {},
        _max_interval = 0,
        _round = 0,
        _retry = 0,
    }
    if not t.f then return end

    local i, c
    for i, c in pairs(cmds or {}) do
        if type(i) == 'number' then
            t._cmds[i] = {}
            local tc = t._cmds[i]
            local ci, cv
            for ci, cv in ipairs(c) do
                tc[ci] = cv
           end
            table.insert(t._intervals, i)
            t._max_interval = max(i, t._max_interval)
            tc._idx = 0
        else
            t._cmds[i] = c
        end
    end

    t._sdr_read_cb = t._cmds['sdr_read']
    t._ready_cb = t._cmds['ready']

    table.sort(t._intervals)
    getmetatable(t.f).getfd = function(self) return tonumber(tostring(self):sub(12)) end

    local i = ffi.new('int[1]', 0)
    if _ioctl(t.f, IPMICTL_SET_GETS_EVENTS_CMD, i) < 0 then
        return
    end

    t.bmc_addr[0].addr_type = IPMI_SYSTEM_INTERFACE_ADDR_TYPE
    t.bmc_addr[0].channel = IPMI_BMC_CHANNEL
    t.ipmb_addr[0].addr_type = IPMI_IPMB_ADDR_TYPE

    t.req.addr = t.req.a
    t.req.msg.data = t.req.d
    t.req.msgid = 1

    t.rsp.addr = t.req.a
    t.rsp.msg.data = t.req.d

    return setmetatable(t, O_mt)
end

function _O.close(self)
    self.f:close()
end

function prettyinfo(self, fp)
    return self._fpn[fp]
end

function _O._send_payload(self, netfn, command, ...)
    local reqbody
    local argc = select('#', ...)
    if argc > 0 and type(select(1, ...)) == 'string' then
        reqbody = stpack('c0', ...)
    else
        reqbody = stpack(string.rep('B', argc), ...)
    end

    ffi.copy(self.req.addr, self.bmc_addr, 32)
    self.req.addr_len = sizeof_ipmi_system_interface_addr

    self.req.msgid = self.req.msgid + 1

    ffi.copy(self.req.msg.data, reqbody)
    self.req.msg.data_len = #reqbody
    self.req.msg.netfn = netfn
    self.req.msg.cmd = command

    if self._DEBUG then print(self.n, '>>>>>', netfn, command, nixio.bin.hexlify(reqbody), prettyinfo(self, self._send), prettyinfo(self, self._recv), self._interval) end
    local ret = _ioctl(self.f, IPMICTL_SEND_COMMAND, self.req)
    return ret
end

function _O.recv(self)
    self.rsp.addr_len = 32
    self.rsp.msg.data_len = 256

    if _ioctl(self.f, IPMICTL_RECEIVE_MSG_TRUNC, self.rsp) < 0 then return false end

    if not self._recv then return false end

    local payload = ffi.string(self.rsp.msg.data, self.rsp.msg.data_len)

    -- unset receive function
    local fn = self._recv
    self._recv = false

    if self._DEBUG then print(self.n, '<<<<<', nixio.bin.hexlify(payload), prettyinfo(self, self._send), prettyinfo(self, fn), self._interval) end
    return fn(self, string.rep('\x00', 6)..payload)
end

_O._process_next_cmd = _L._process_next_cmd

_L._fpn = {}
_O._fpn = {}
local k, v
for k, v in pairs(_L) do
    if type(v) == 'function' then
        _L._fpn[v] = k
        _O._fpn[v] = k
    end
end

for k, v in pairs(_O) do
    if type(v) == 'function' then
        _O._fpn[v] = k
    end
end

return { lan = _L, open = _O }
