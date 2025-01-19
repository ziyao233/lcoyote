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
	local msg = dbusSession:send_with_reply_and_block(query);
	local res = decodeMessage(msg);

	return res;
end

local function
getDevices()
	local objs = getObjects();
	local devices = {};

	for k, v in pairs(objs) do
		local path = splitPath(k);

		if path[#path]:match("^dev_[_0-9A-F]+$") then
			devices[k] = v;
		end
	end

	return devices;

end

return {
	init		= init,
	getDevices	= getDevices,
       };
