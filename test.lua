local bluetooth		= require "lcoyote.bluetooth";

bluetooth.init();

local devpath = next(bluetooth.getDevices());

local readBat = bluetooth.getCharacteristic(devpath, "00001500-0000-1000-8000-00805f9b34fb");
local writeData1 = bluetooth.getCharacteristic(devpath, "0000150a-0000-1000-8000-00805f9b34fb");

print(readBat:readValue()[1]);
--			     no serial  absolute strength
while true do
writeData1:writeValue({0xb0, (0 << 4) | 0x3 << 2,
		       -- A: length = 10, B: length = 0
		       20, 0,
		       10, 10, 10, 10,	-- A: wave freq
		       25, 50, 75, 100,		-- A: wave strength
		       0, 0, 0, 0,		-- B: wave freq
		       0, 0, 0, 101})		-- B: wave strength
end
