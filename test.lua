local bluetooth		= require "lcoyote.bluetooth";

bluetooth.init();

local devpath = next(bluetooth.getDevices());

local readBat = bluetooth.getCharacteristic(devpath, "00001500-0000-1000-8000-00805f9b34fb");

print(readBat:readValue()[1]);
