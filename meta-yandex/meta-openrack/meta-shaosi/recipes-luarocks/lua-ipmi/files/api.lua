local _M = {}

function _M.get(self)
    return 'get:'..tostring(self.match.path)
end

return _M
