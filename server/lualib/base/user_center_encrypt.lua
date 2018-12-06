local md5 =	require	"md5"
local aes = require "aes"
local crypt = require "skynet.crypt"
local cjson = require "cjson"
local httpc = require "http.httpc"

local UCE = {}

local usercenter_url = "124.90.36.250:31200"
local usercenter_userinfo_url = "/v1/user/userinfo"
local usercenter_game_id = 456
local usercenter_app_id = "100047"
local usercenter_app_secret = "B805E08566288D0105F6F79297D1BF84"

local function custom_encrypt(content, custom_key, app_id, app_secret)
	local random = math.random(0, 15)
	local text = tostring(random)
	local len = string.len(text)

	if random < 10 then
		text = "0"..text
	end

	local text2 = string.sub(custom_key, 1, 6)
	local text3 = string.sub(custom_key, 7, 21)
	local text4 = string.sub(custom_key, 22, string.len(custom_key))
	local str = text2..text..text3..tostring(app_id)..text4
	app_secret = string.lower(app_secret)
	local key = string.sub(app_secret, tonumber(text) + 1, tonumber(text) + 16)

	return crypt.base64encode(aes.encrypt(content, key))..str
end

local function concat_params(params)
	local str = ""

	for n, v in pairs(params) do
		str = str.."&"..tostring(v.n).."="..tostring(v.v)
	end

	return str
end

local function make_sign(request, app_secret)
	local params = {}

	for n, v in pairs(request) do
		if n ~= "appId" then
			table.insert(params, {n = n, v = v})
		end
	end

	table.sort(params, function(a, b) return tostring(a.n) < tostring(b.n) end)

	local query_params = concat_params(params)
	local sign = md5.sumhexa(string.format("appid=%d%s&appsecret=%s", request.appId, query_params, app_secret))

	return sign
end

local function build_client_request_params(request, app_secret)
	request.sign = string.lower(make_sign(request, app_secret))

	local request_json = cjson.encode(request)
	local equest_base64 = crypt.base64encode(request_json)

	local custom_key = string.lower(md5.sumhexa(equest_base64))

	local data = {}
	data.data = custom_encrypt(equest_base64, custom_key, request.appId, app_secret)

	return cjson.encode(data)
end

function UCE.post_get_userinfo_msg(args, ip)
    local request = {}
	request.appId = usercenter_app_id
	request.gameId = usercenter_game_id
	request.deviceId = args.deviceId
	request.unionId = args.unionId
	request.siteId = args.siteId
	request.userIp = ip
	request.terminalSource = args.terminalSource
	request.version = args.version
	request.access_token = args.access_token

    local content = build_client_request_params(request, usercenter_app_secret)

	local header = {
		["content-type"] = "application/json"
	}

    local respheader = {}

	-- httpc.dns()	                -- set dns server
    httpc.timeout = 3 * 100	    -- set timeout 3 second

    local status, body = httpc.request("POST", usercenter_url, usercenter_userinfo_url, respheader, header, content)

    return status, body
end

return UCE