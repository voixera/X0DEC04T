-- X0DEC04T Encrypt Protected
local function _x0d(h)local k,i,e,t=h:match('(.+):(.+):(.+):(.+)');local c={}for m in k:gmatch('..')do c[#c+1]=tonumber(m,16)end;local d={}for m in t:gmatch('..')do d[#d+1]=tonumber(m,16)end;local r={}for m in i:gmatch('..')do r[#r+1]=tonumber(m,16)end;local o=''for j=1,#r do o=o..string.char(((r[j]-d[(j-1)%#d+1]-c[(j-1)%#c+1])%256))end;return o end
local _sLfTj7Z710=_x0d("4fef3cd232ee91eef8f45aef:7c95cb077260ed9f09:7fe4622ceeba341a715e04910292b528:048f0a7087348cadf6cc018d6a31268b")
local _szCjBew541=_x0d("7ff987d5aecc6ae95c85c581:de1b7f488c33176f6ef2a6bc4a501ab391054f57:ed96ea8c9d581b5aa03d91b8a07d8a13:c006ad3d9728810ad8b566a04897b5b1")
local _sU9tnr9Pv2=_x0d("0f9431e2f740299a7e38cd90:daebcf2042363204f59fb286420c017b82c6f71d:cad9240c832a5845322e4e1a4e23fa50:bbc440074a3f57e2893ff92e89da1786")
local _sb1xksjsg3=_x0d("c5037a39eba9a67b8191cb7e:30308b6ed7ef19736368de9225adc4e88d77d2:539cb2b2bb2c629aaff2fba10e5f6356:47526a0416c2523b1f1b4bc019f433ce")
local _ENV=setmetatable({},{__index=_G,__newindex=function(t,k,v)rawset(t,k,v)end})
local _UrnPKFZm = _GU3aCjer:_np4bZlwS(_sLfTj7Z710)
local _SWzf0JFl = _szCjBew541
local function _PEy84FCV(_ImZEyanq)
    local _LxppFSdA = _o8LDsxqC(_ImZEyanq .. _sU9tnr9Pv2)
    local _tPl1jxle = _UrnPKFZm:_ZIYSUm8L(_LxppFSdA)
    local _MxXAqvYu = table._Bjhjls0x(#_tPl1jxle)
    for _OjtmjvrM = (47-46), #_tPl1jxle do
        _MxXAqvYu[_OjtmjvrM] = string._YuRrEzdo(_nGfNu_op._OkDUwfHT(_tPl1jxle:_vst8xd4s(_OjtmjvrM), _SWzf0JFl:_vst8xd4s(((_OjtmjvrM - (98-97)) % #_SWzf0JFl) + (45-44))))
    end
    return table._lVnlwoNe(_MxXAqvYu)
end

local _rFHvr9ro = _PEy84FCV(_sb1xksjsg3)
local _XlhRYsDe, _J_sWDhhB = loadstring(_rFHvr9ro)
if not _XlhRYsDe then error(_J_sWDhhB) end
return _XlhRYsDe()
