-- SPDX-License-Identifier: MIT
--[[
--	lcoyote
--	Copyright (c) 2025 Yao Zi.
--]]

local ldbus		= require "ldbus";
local dbus, dmessage	= ldbus.bus, ldbus.message;

local messageDecodeValue;

local function
decodeBasic(iter)
	local res = iter:get_basic();
	iter:next();
	return res;
end

local decoders = {
	['y'] = decodeBasic, ['b'] = decodeBasic, ['n'] = decodeBasic,
	['q'] = decodeBasic, ['i'] = decodeBasic, ['u'] = decodeBasic,
	['x'] = decodeBasic, ['t'] = decodeBasic, ['d'] = decodeBasic,
	['o'] = decodeBasic, ['s'] = decodeBasic, ['g'] = decodeBasic,
	['h'] = decodeBasic,
	['a'] = function(iter)
		local arrIter = iter:recurse();

		local type = arrIter:get_arg_type();
		local arr = {};
		while type do
			local v1, v2 = messageDecodeValue(arrIter);

			-- convert ARRAY of DICT_ENTRY into a K-V table
			if v2 then
				arr[v1] = v2;
			else
				table.insert(arr, v1);
			end

			type = arrIter:get_arg_type();
		end

		iter:next();
		return arr;
	end,
	['e'] = function(iter)
		local subIter = iter:recurse();

		local k = subIter:get_basic();
		subIter:next();
		local v = messageDecodeValue(subIter);
		iter:next();
		return k, v;
	end,
	['v'] = function(iter)
		local subIter = iter:recurse();
		local v = messageDecodeValue(subIter);
		iter:next();
		return v;
	end,
};

messageDecodeValue = function(iter)
	local t = iter:get_arg_type();
	local f = decoders[t];

	if not f then
		error(("Unknown D-Bus type '%s'"):format(t));
	end

	return f(iter);
end

local function
decodeMessage(msg)
	local iter = msg:iter_init();

	return messageDecodeValue(iter);
end

local function
splitPath(path)
	local pArr = {};
	for segment in path:gmatch("[^/]+") do
		table.insert(pArr, segment);
	end
	return pArr;
end

local dbusSession;

local function
init()
	dbusSession = dbus.get("system");
	if not dbus.start_service_by_name(dbusSession, "org.bluez") then
		return false, "bluez daemon isn't ready";
	end

	return true;
end

local function
getObjects()
	local interface <const> = "org.freedesktop.DBus.ObjectManager";
	local query = dmessage.new_method_call("org.bluez", "/", interface,
					       "GetManagedObjects");

--	FIXME: ldbus doesn't claim the reference to the message in iterators,
--	workaround this or we may get a segfault.
--	local res = decodeMessage(dbusSession:send_with_reply_and_block(query));
	local reply = dbusSession:send_with_reply_and_block(query);
	local res = decodeMessage(reply);

	return res;
end

local function
getDevices()
	local devices = {};

	for k, v in pairs(getObjects()) do
		local path = splitPath(k);

		if path[#path]:match("^dev_[_0-9A-F]+$") then
			devices[k] = v;
		end
	end

	return devices;

end

local charMeta = {};
charMeta.__index = charMeta;

-- TODO: Support options
charMeta.readValue = function(self)
	local interface <const> = "org.bluez.GattCharacteristic1";
	local query = dmessage.new_method_call("org.bluez", self.objpath,
					       interface, "ReadValue");

	local iter = query:iter_init_append();
	local subiter = iter:open_container("a", "{sv}");
	iter:close_container(subiter);

	local reply = assert(dbusSession:send_with_reply_and_block(query));
	local res = decodeMessage(reply);

	return res;
end

-- FIXME: We could have different services with the same charUUID, it isn't
-- the case for DGLab Coyote though.
local function
getCharacteristic(devpath, charUUID)
	local services = {};

	for k, v in pairs(getObjects()) do
		if not k:find(devpath) then
			goto continue;
		end

		local path = splitPath(k);
		if not path[#path]:match("^char[0-9a-f]+$") then
			goto continue;
		end

		if v["org.bluez.GattCharacteristic1"].UUID == charUUID then
			local char = { objpath = k };
			return setmetatable(char, charMeta);
		end
	::continue::
	end

	return nil;
end

return {
	init			= init,
	getDevices		= getDevices,
	getCharacteristic	= getCharacteristic,
       };
