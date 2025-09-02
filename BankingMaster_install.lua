-- master_install.lua
local diskDrive = peripheral.find("disk") or peripheral.find("disk_drive")
local modem = peripheral.find("modem") or error("No wireless modem attached!", 0)

-- Ask for setup options
term.clear()
term.setCursorPos(1,1)
print("=== Master Computer Install ===")

-- Set wireless channel
write("Enter wireless channel for slave communication (default 50): ")
local channelInput = read()
local CHANNEL = tonumber(channelInput) or 50

-- Open modem channel
modem.open(CHANNEL)
print("Wireless modem opened on channel " .. CHANNEL)

-- Prepare accounts database
local accountsFile = "/disk/accounts.db"

if not fs.exists("/disk") then
    error("No disk found! Insert a disk to store account data.", 0)
end

if fs.exists(accountsFile) then
    print("Accounts database already exists.")
else
    -- Create default admin account
    print("Creating default admin account...")
    local file = fs.open(accountsFile, "w")
    local defaultAdmin = {
        admin = {
            password = "admin123",
            role = 99
        }
    }
    file.write(textutils.serializeJSON(defaultAdmin))
    file.close()
    print("Default admin created: username=admin password=admin123 role=99")
end

-- Create slave tracking file (optional)
local slavesFile = "/disk/slaves.db"
if not fs.exists(slavesFile) then
    local file = fs.open(slavesFile, "w")
    file.write(textutils.serializeJSON({}))
    file.close()
    print("Slave tracking database created.")
end

print("\nMaster install complete!")
print("You can now run bank.lua to start the system.")

-- Save configuration file
local configFile = "/disk/master_config.db"
local file = fs.open(configFile, "w")
file.write(textutils.serializeJSON({ channel = CHANNEL }))
file.close()
print("Configuration saved to master_config.db")
