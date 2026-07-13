-- X0DEC04T Encrypt Protected
local function _x0d(h)local k,i,e,t=h:match('(.+):(.+):(.+):(.+)');local c={}for m in k:gmatch('..')do c[#c+1]=tonumber(m,16)end;local d={}for m in t:gmatch('..')do d[#d+1]=tonumber(m,16)end;local r={}for m in i:gmatch('..')do r[#r+1]=tonumber(m,16)end;local o=''for j=1,#r do o=o..string.char(((r[j]-d[(j-1)%#d+1]-c[(j-1)%#c+1])%256))end;return o end
local _sLnzw6C_K0=_x0d("12d8987b13bf00a264150225:52d7385e8f2cda796d:27f398a37522acdc08f82cb6e403f2fe:b530e7e414ccf2560605bc45b4096eeb")
local _sOzz6o12r1=_x0d("65f61334cfb30de98c5a5dd1:2ef7fea4ee39613d7e5dcb0c86a16f00891c6511:818dea1beaa3f8fabd5ab71dd03dd8c3:353bb74d124dc28956feebe08f022c1d")
local _sX_MRZMLD2=_x0d("cadae7fcb48f2ae8c8c626f9:c30f2e2f0daa045ab05e2fce99ec65e965e4c31c:20f31dfb8ce43f69de3c38a0278d2f24:6eb9d17c9a5d58c4dac71b7733fb5f1b")
local _sdkr0qpZK3=_x0d("01fba82a7ae60733a64552ff:9d4f118ee7e329bd9d50d49447a910464e6732:7f2afbb62da242027c949426ad19597d:fc48e83daef056a81126eb944ae90afe")
local _ENV=setmetatable({},{__index=_G,__newindex=function(t,k,v)rawset(t,k,v)end})
local _cfyxBsvs = _pGredfVh:__zvKLFfd(_sLnzw6C_K0)
local _DwzFoEN0 = _sOzz6o12r1
local function _BS14z984(_Ux7mSIlZ)
    local _P9UEUWvd = _Yl83lgXE(_Ux7mSIlZ .. _sX_MRZMLD2)
    local _LyBWq_Ii = _cfyxBsvs:_trvLDIEy(_P9UEUWvd)
    local _emzYnBv1 = table._tKSl1XUk(#_LyBWq_Ii)
    for _D8tnw99q = (32-31), #_LyBWq_Ii do
        _emzYnBv1[_D8tnw99q] = string._e2qS8E6v(_Sa0yknrj._yWTk70If(_LyBWq_Ii:_p69znFKl(_D8tnw99q), _DwzFoEN0:_p69znFKl(((_D8tnw99q - (91-90)) % #_DwzFoEN0) + (25-24))))
    end
    return table._jqGumwsq(_emzYnBv1)
end

local _Sj6N0Hs3 = _BS14z984(_sdkr0qpZK3)
local _dV_BJNd9, _DMTiEKqN = loadstring(_Sj6N0Hs3)
if not _dV_BJNd9 then error(_DMTiEKqN) end
return _dV_BJNd9()
