#!/usr/bin/lua

local pmbus = require 'pmbus'
local bit = require 'bit'
local bin = require 'struct'
local ffi = require "ffi"
local uloop = require 'uloop'
local cjson = require 'cjson'
local ipmi = require 'ipmi'

ffi.cdef "unsigned int sleep(unsigned int seconds);"

local cjson_encode = cjson.encode
local rshift, bor, band = bit.rshift, bit.bor, bit.band
local stpack, stunpack = bin.pack, bin.unpack

local function sleep(n)
    ffi.C.sleep(n)
end

uloop.init()

local db_resty = nixio.socket('unix', 'stream')
if not db_resty:connect('/run/openresty/socket') then return -1 end
getmetatable(db_resty).getfd = function(self) return tonumber(tostring(self):sub(13)) end
getmetatable(db_resty).request = function(self, banknum, name, value, method)
    -- TODO: keep values in array and post it independetly in coroutine
    local body = cjson_encode({ data = value })
    if name ~= '' then name = '/'..name end
    if banknum ~= nil then
        banknum = 'pmbus/' .. tostring(banknum) .. '/'
    else
        banknum = ''
    end
    body = (method or 'POST')..' /api/storage/'..banknum..name.." HTTP/1.1\r\nUser-Agent: collector/1.0\r\nAccept: */*\r\nHost: localhost\r\nContent-type: application/json\r\nConnection: keep-alive\r\nContent-Length: "..#body.."\r\n\r\n"..body.."\r\n\r\n"
    local cnt, errno, errmsg = db_resty:write(body)
    if errno ~= nil then
        -- print('RECONNECT', errno, errmsg)
        db_resty:close()
        db_resty = nixio.socket('unix', 'stream')
        db_resty:connect('/run/openresty/socket')
        uloop.fd_add(db_resty, resty_event, uloop.ULOOP_READ + 0x40)
        if db_resty:write(body) == nil then print('WRITE failed') end
    end
end
local db_que = {}

function resty_event(ufd, events)
    local d, errno, errmsg = ufd:read(4096)
    if d == '' or d == nil then
        -- print('RECONNECT', events)
        db_resty:close()
        db_resty = nixio.socket('unix', 'stream')
        db_resty:connect('/run/openresty/socket')
        uloop.fd_add(db_resty, resty_event, uloop.ULOOP_READ + 0x40)
--    else
--        print('RESTY: ', tostring(d), #db_que, events)
    end
end

local r = uloop.fd_add(db_resty, resty_event, uloop.ULOOP_READ + 0x40)

local banks = {}

local function update_banks_list()
    local i, b
    local banks_online = {}
    for i, b in ipairs(banks) do
        if b.present then
            table.insert(banks_online, i)
        end
    end
    db_resty:request('', '', cjson_encode(banks_online))
end

local function on_plug(bank)
    local k, v
    local attrs = {'mfr_id', 'mfr_rev', 'mfr_loc', 'mfr_model', 'mfr_serial'}
    for k, v in ipairs(attrs) do
        db_resty:request(bank.number, v, bank[v])
    end
    for k, v in pairs(bank.attrs) do
        table.insert(attrs, v.label)
    end
    db_resty:request(bank.number, '', cjson_encode(attrs))
    update_banks_list()
end

local function on_unplug(bank)
    local k, v
    local attrs = {'mfr_id', 'mfr_rev', 'mfr_loc', 'mfr_model', 'mfr_serial'}
    for k, v in ipairs(attrs) do
        db_resty:request(bank.number, v, nil, 'DELETE')
    end
    db_resty:request(bank.number, '', nil, 'DELETE')
    update_banks_list()
end

local i, b
for i=9, 15 do
    b = pmbus:new(#banks+1, i, 0x10, on_plug, on_unplug)
    table.insert(banks, b)
end

local timer
timer = uloop.timer(function()
    timer:set(1000)

    local i, k, v, b
    for i, b in ipairs(banks) do
        if not b.present and not b:ping() then
            goto continue
        end
        local attrs = b:read_attributes()
        local req_attrs = {}
        local banknum = 'pmbus/'..b.number..'/'
        for k, v in pairs(attrs) do
            req_attrs[banknum..k] = { value = v, duration = 30 }
        end
        db_resty:request(nil, '', req_attrs)

        ::continue::
    end

end, 1000)

uloop.run()
