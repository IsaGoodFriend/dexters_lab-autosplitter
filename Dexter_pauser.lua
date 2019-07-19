-- based off code from Trysdyn Black, 2016 https://github.com/trysdyn/bizhawk-speedrun-lua
-- Made by IsaGoodFriend and Blazephlozard

local function init_livesplit()
    pipe_handle = io.open("//./pipe/LiveSplit", 'a')

    if not pipe_handle then
        error("\nFailed to open LiveSplit named pipe!\n" ..
              "Please make sure LiveSplit is running and is at least 1.7, " ..
              "then load this script again")
    end

    pipe_handle:write("reset\r\n")
	pipe_handle:write("alwayspausegametime\r\n")
    pipe_handle:flush()

    return pipe_handle
end

local function frames_to_time(gt)
	hours = math.floor(gt / 216000)
	gt = gt % 216000
	minutes = math.floor(gt / 3600)
	gt = gt % 3600
	--includes milliseconds naturally
	seconds = gt / 60
	timerstring = hours .. ":" .. minutes .. ":" .. seconds
	return timerstring
end

local function send_time()
	bigframetimer = memory.read_u32_le(0x032590)
	--Timer is set to zero while exiting to menu, but we don't want that to get sent!
	if (bigframetimer > 0) then 
		timer = frames_to_time(bigframetimer)
		--console.log(timer)
		pipe_handle:write("setgametime " .. timer .. "\r\n")
		pipe_handle:flush()
	end
end

-- Set up our TCP socket to LiveSplit and send a reset to be sure
pipe_handle = init_livesplit()
memory.usememorydomain("Combined WRAM")

paused = true
mainmenucheck = false 
split = 0
frametimer = memory.readbyte(0x032590)

-- Values to look for when splitting.  Deedee and machine are direct counts, and don't check for specifics
-- Tool splits check individual tools.
----	0x01: Drill
----	0x08: Wrench
----	0x10: Screwdriver
----	0x20: Pliers
----	0x40: Soldering Iron
----	0x80: Hammer
-- 0xFFFF are dummy values to prevent index overflow
deedeeSplits = 	{0000, 0016, 0020, 0028, 0028, 0038, 0054, 0069, 0079, 0092, 0104, 0108, 0112, 0124, 0xFFFF}
machineSplits = {0000, 0005, 0006, 0009, 0009, 0011, 0012, 0016, 0021, 0023, 0028, 0030, 0041, 0043, 0xFFFF}
toolSplits = 	{0x08, 0x08, 0x18, 0x18, 0x38, 0xB8, 0xB8, 0xF8, 0xF8, 0xF8, 0xF9, 0xF9, 0xF9, 0xF9, 0xFFFF}

-- 030D0C On Screen Cursor
-- Level design? 027E20
-- 00E22A08 082ae200
-- ???? 0326A4
-- Level Pointer 0x9C4

while true do
	newframetimer = memory.readbyte(0x032590)
	pausevar = memory.readbyte(0x047C3E)
	demovar = memory.readbyte(0x032584)
	
	--Only send the game time every 256 frames, to reduce chance of lag
	if (newframetimer ~= frametimer and newframetimer == 0) then
		send_time()
	end
	
	--If game is at initial value, then restart splits
	if (deedeeCount == 0 and machineCount == 0 and pausevar == 1) then
		split = 0
	end
	
	if (pausevar == 0x9F and not mainmenucheck) then
		
		mainmenucheck = true
		
		tools = memory.readbyte(0x0325B8) + memory.readbyte(0x0325B9)
		deedeeCount = memory.readbyte(0x032610);
		
		machineFlags1 = memory.read_u32_le(0x0325A4)
		machineFlags2 = memory.read_u32_le(0x0325A8)
		
		machineCount = 0
		for i = 1,32 do
			temp = machineFlags1 % 2
			if temp >= 0 then
				machineCount = machineCount + 1
			end
			machineFlags1 = machineFlags1 / 2
			
			temp = machineFlags2 % 2
			if temp >= 1 then
				machineCount = machineCount + 1
			end
			machineFlags2 = machineFlags2 / 2
		end
		
		--console.log(machineCount)
		if (deedeeCount >= deedeeSplits[split + 1] and tools >= toolSplits[split + 1] and machineCount >= machineSplits[split + 1]) then
			send_time()
			split = split + 1
			pipe_handle:write("split\r\n")
			pipe_handle:flush()
		end
	elseif (pausevar ~= 0x9F and mainmenucheck) then
		mainmenucheck = false
	end
	
	if (paused and newframetimer ~= frametimer and demovar ~= 0) then
		--console.log("unpausing")
		paused = false
		pipe_handle:write("unpausegametime\r\n")
        pipe_handle:flush()
		send_time()
	elseif (not paused and newframetimer == frametimer) then 
		--console.log("pausing")
		paused = true
		--using alwayspausegametime so that game time doesn't start early when starting a run
		pipe_handle:write("alwayspausegametime\r\n")
        pipe_handle:flush()
		send_time()
	end
	
	frametimer = newframetimer
    emu.frameadvance()
end