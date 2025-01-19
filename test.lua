local bluetooth		= require "lcoyote.bluetooth";

bluetooth.init();

for path, dev in pairs(bluetooth.getDevices()) do
	print(("%s: %s"):format(path, dev["org.bluez.Device1"].Name));
end
