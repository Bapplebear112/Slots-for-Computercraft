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
if not fs.exists("/disk") then
    error("No disk found! Insert a disk to store account data.", 0)
end

local accountsFile = "/disk/accounts.db"
if not fs.exists(accountsFile) then
    print("Creating default admin account...")
    local file = fs.open(accountsFile, "w")
    local defaultAdmin = {
        admin = { password = "admin123", role = 99 }
    }
    file.write(textutils.serializeJSON(defaultAdmin))
    file.close()
    print("Default admin created: username=admin password=admin123 role=99")
else
    print("Accounts database already exists.")
end

-- Create slave tracking file
local slavesFile = "/disk/slaves.db"
if not fs.exists(slavesFile) then
    local file = fs.open(slavesFile, "w")
    file.write(textutils.serializeJSON({}))
    file.close()
    print("Slave tracking database created.")
end

-- Save configuration file
local configFile = "/disk/master_config.db"
local file = fs.open(configFile, "w")
file.write(textutils.serializeJSON({ channel = CHANNEL }))
file.close()
print("Configuration saved to master_config.db")

-- Automatically create bank.lua
local bankCode = [[
-- bank.lua
local modem = peripheral.find("modem") or error("No wireless modem attached!",0)
local accountsFile = "/disk/accounts.db"
local slaves = {}

-- Load accounts
local function loadAccounts()
    local file = fs.open(accountsFile,"r")
    local data = file.readAll()
    file.close()
    return textutils.unserializeJSON(data) or {}
end

-- Save accounts
local function saveAccounts(accounts)
    local file = fs.open(accountsFile,"w")
    file.write(textutils.serializeJSON(accounts))
    file.close()
end

-- Login function
local function login(accounts)
    term.clear()
    term.setCursorPos(1,1)
    print("=== Bank Login ===")
    write("Username: ")
    local user = read()
    write("Password: ")
    local pass = read("*")
    if accounts[user] and accounts[user].password == pass then
        print("Login successful! Welcome, " .. user)
        sleep(1)
        return user, accounts[user].role
    else
        print("Invalid login!")
        sleep(2)
        return nil
    end
end

-- Admin menu
local function adminMenu(accounts)
    while true do
        term.clear()
        print("=== Admin Menu ===")
        print("1. Create account")
        print("2. Delete account")
        print("3. List accounts")
        print("4. View slaves")
        print("5. Logout")
        write("Choose option: ")
        local choice = read()
        if choice == "1" then
            write("Enter new username: ")
            local uname = read()
            if accounts[uname] then
                print("User exists!")
            else
                write("Enter password: ")
                local pwd = read("*")
                write("Enter role number: ")
                local role = tonumber(read())
                accounts[uname] = { password=pwd, role=role }
                saveAccounts(accounts)
                print("Account created!")
            end
            sleep(2)
        elseif choice == "2" then
            write("Enter username to delete: ")
            local uname = read()
            if uname == "admin" then
                print("Cannot delete admin!")
            elseif accounts[uname] then
                accounts[uname] = nil
                saveAccounts(accounts)
                print("Account deleted!")
            else
                print("User not found!")
            end
            sleep(2)
        elseif choice == "3" then
            print("Accounts:")
            for k,v in pairs(accounts) do
                print(" - " .. k .. " (role " .. v.role .. ")")
            end
            sleep(4)
        elseif choice == "4" then
            print("Connected slaves:")
            for id, s in pairs(slaves) do
                local age = math.floor(os.clock() - s.lastSeen)
                print("ID:"..id.." | Area:"..s.area.." | Role:"..s.role.." | Function:"..s.functionType.type.." | Last seen "..age.."s ago")
            end
            sleep(4)
        elseif choice == "5" then
            break
        else
            print("Invalid choice!")
            sleep(2)
        end
    end
end

-- Modem event loop
modem.open(50)
parallel.waitForAny(function()
    local accounts = loadAccounts()
    if not accounts["admin"] then
        accounts["admin"] = { password="admin123", role=99 }
        saveAccounts(accounts)
    end
    while true do
        local user, role = login(accounts)
        if user then
            if role == 99 then
                adminMenu(accounts)
            else
                print("User login complete. (user menu TBD)")
                sleep(2)
            end
        end
    end
end,
function()
    while true do
        local _, side, channel, replyChannel, msg = os.pullEvent("modem_message")
        if msg then
            if msg.type=="register" then
                slaves[msg.id] = { area=msg.area, role=msg.role, lastSeen=os.clock(), functionType=msg.functionType }
                print("Registered slave "..msg.id.." ("..msg.area..")")
            elseif msg.type=="alive" then
                if slaves[msg.id] then
                    slaves[msg.id].lastSeen = os.clock()
                else
                    slaves[msg.id] = { area=msg.area, role=msg.role, lastSeen=os.clock(), functionType=msg.functionType }
                end
            end
        end
    end
end)
]]

-- Write bank.lua to disk
local file = fs.open("/disk/bank.lua","w")
file.write(bankCode)
file.close()
print("bank.lua created on disk. You can now run it to start the master server.")
