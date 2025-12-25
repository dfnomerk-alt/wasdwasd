local Version = "17.2.0"
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/download/1.6.62/main.lua"))()
local http = game:GetService("HttpService")

-- // 1. CORE CONFIGURATION // --
local Config = {
    TargetName = "",
    Price = 100,
    MaxWeight = 2.0, 
    TargetAmount = 3,
    Delay = 6.0,      
    LoopDelay = 10.0, 
    IsRunning = false,
    AutoLoop = false,
    MaxBoothItems = 50,
    BlacklistedUUIDs = {},
    WebhookURL = "",
    DiscordID = "",
    PanicOnAdmin = true,
    AntiAFK = true, 
    StartTime = os.time()
}

local Stats = { Sold = 0, Gems = 0, CurrentlyListed = 0, CurrentTokens = 0, Status = "Idle" }

-- // 2. NOTIF & UTILITY // --
local function Notify(pTitle, pContent)
    WindUI:Notify({ Title = pTitle, Content = pContent, Icon = "solar:bell-bing-bold", Duration = 5 })
end

local function GetSessionTime()
    local diff = os.difftime(os.time(), Config.StartTime)
    local hours = math.floor(diff / 3600)
    local mins = math.floor((diff % 3600) / 60)
    return string.format("%dh %dm", hours, mins)
end

-- // 3. UI WINDOW SETUP (macOS STYLE REVISION) // --
local Window = WindUI:CreateWindow({
    Title = "MISTHIOS RHYTHM",
    SubTitle = "v17.2 | macOS EDITION",
    Author = "by Misthios",
    Folder = "MisthiosScan",
    Icon = "solar:shield-check-bold",
    Transparent = true, 
    Acrylic = true,     -- Efek kaca macOS
    TransparencyValue = 0.1,
    AccentColor = Color3.fromHex("#8E8E93"), -- Warna neutral macOS
    Topbar = { 
        Height = 44, 
        ButtonsType = "Mac" -- Tombol Close/Min/Max ala Mac
    },
    OpenButton = { Title = "RHYTHM", Icon = "solar:ghost-bold" }
})

-- // 4. TABS (CUSTOM COLORS PER ICON) // --
local MonitorTab = Window:Tab({ 
    Title = "Dashboard", 
    Icon = "solar:chart-bold", 
    IconColor = Color3.fromHex("#AF52DE") -- Purple
})
local MainTab = Window:Tab({ 
    Title = "Scanner", 
    Icon = "solar:scanner-bold", 
    IconColor = Color3.fromHex("#007AFF") -- Blue
})
local EliteTab = Window:Tab({ 
    Title = "AFK Perks", 
    Icon = "solar:ghost-bold", 
    IconColor = Color3.fromHex("#FF3B30") -- Red
})
local SettingTab = Window:Tab({ 
    Title = "Settings", 
    Icon = "solar:settings-bold", 
    IconColor = Color3.fromHex("#8E8E93") -- Gray
})

-- // 5. DASHBOARD ENGINE // --
local DashSec = MonitorTab:Section({ Title = "System Monitor" })
local StatusBtn = DashSec:Button({ Title = "Status: Idle", Desc = "Current system activity" })
local TokenBtn = DashSec:Button({ Title = "Wallet: Initializing...", Desc = "Real-time Token balance" })
local BoothBtn = DashSec:Button({ Title = "Booth: 0/50 Items", Desc = "Occupied slots" })
local SessionBtn = DashSec:Button({ Title = "Session Profit: 0 Tokens", Desc = "Earned since start" })
local TimeBtn = DashSec:Button({ Title = "Uptime: 0h 0m", Desc = "Time elapsed" })

task.spawn(function()
    local RS = game:GetService("ReplicatedStorage")
    local DataService = require(RS.Modules.DataService)
    local lp = game.Players.LocalPlayer

    local function forceSync()
        local data = nil
        repeat
            local success, res = pcall(function() return DataService:GetData() end)
            if success and res then data = res end
            if not data then task.wait(1) end
        until data or not task.wait(2)
        
        if data and data.TradeData then
            Stats.CurrentTokens = data.TradeData.Tokens
            TokenBtn:SetTitle("Wallet: " .. string.format("%.0f", Stats.CurrentTokens) .. " Tokens")
        end
    end

    DataService:GetPathSignal("TradeData/Tokens"):Connect(forceSync)
    forceSync()

    while task.wait(1) do
        TimeBtn:SetTitle("Uptime: " .. GetSessionTime())
        StatusBtn:SetTitle("Status: " .. Stats.Status)
        
        local bGui = lp.PlayerGui:FindFirstChild("TradeBooth") or lp.PlayerGui:FindFirstChild("Booth")
        if bGui then
            local listFrame = bGui:FindFirstChild("List", true) or bGui:FindFirstChild("ScrollingFrame", true)
            if listFrame then
                local count = 0
                for _, child in pairs(listFrame:GetChildren()) do
                    if (child:IsA("Frame") or child:IsA("ImageButton")) and child.Name ~= "Add" and not child:IsA("UIComponent") then
                        if child:FindFirstChild("Item", true) or child:FindFirstChild("Price", true) then count = count + 1 end
                    end
                end
                Stats.CurrentlyListed = count
                BoothBtn:SetTitle("Booth: " .. count .. "/50 Items")
            end
        end
    end
end)

-- // 6. SCANNER LOGIC // --
function StartRhythmScan()
    Stats.Status = "Scanning"
    Notify("System", "Auto Rhythm Started")
    task.spawn(function()
        local RS = game:GetService("ReplicatedStorage")
        while Config.AutoLoop do
            if Stats.CurrentlyListed >= Config.MaxBoothItems then
                Stats.Status = "Booth Full (Waiting)"
                repeat task.wait(5) until Stats.CurrentlyListed < Config.MaxBoothItems or not Config.AutoLoop
                if not Config.AutoLoop then break end
            end

            Config.IsRunning = true
            Stats.Status = "Listing Items"
            local bp = game.Players.LocalPlayer:FindFirstChild("Backpack")
            if bp and Config.TargetName ~= "" then
                local putInCycle = 0
                for _, item in pairs(bp:GetChildren()) do
                    if putInCycle >= Config.TargetAmount or (Stats.CurrentlyListed + putInCycle) >= Config.MaxBoothItems then break end
                    if string.find(item.Name:lower(), Config.TargetName:lower()) then
                        local weight = tonumber(string.match(item.Name, "%d+%.?%d*")) or 0
                        local uuid = item:GetAttribute("PET_UUID")
                        if uuid and weight <= Config.MaxWeight and not Config.BlacklistedUUIDs[uuid] then
                            local ok = RS.GameEvents.TradeEvents.Booths.CreateListing:InvokeServer("Pet", tostring(uuid), Config.Price)
                            if ok then
                                Config.BlacklistedUUIDs[uuid] = true
                                putInCycle = putInCycle + 1
                                Notify("Listed", item.Name .. " for " .. Config.Price)
                            end
                            task.wait(Config.Delay)
                        end
                    end
                end
            end
            Stats.Status = "Standby (Delay)"
            task.wait(Config.LoopDelay)
            Config.IsRunning = false
        end
        Stats.Status = "Idle"
    end)
end

-- // 7. UI TABS SETUP // --
local TargetSec = MainTab:Section({ Title = "Settings" })
TargetSec:Input({ Title = "Pet Name", Callback = function(v) Config.TargetName = v end })
TargetSec:Input({ Title = "Price", Callback = function(v) Config.Price = tonumber(v) or 100 end })
TargetSec:Input({ Title = "Max Weight", Value = "2.0", Callback = function(v) Config.MaxWeight = tonumber(v) or 2.0 end })
TargetSec:Input({ Title = "Pets Per Cycle", Value = "3", Callback = function(v) Config.TargetAmount = tonumber(v) or 3 end })

MainTab:Section({ Title = "Control" }):Toggle({ 
    Title = "Auto Rhythm", 
    Value = false, 
    Callback = function(s) Config.AutoLoop = s if s then StartRhythmScan() end end 
})

local EliteSec = EliteTab:Section({ Title = "Smart Protection" })
EliteSec:Toggle({ Title = "Anti-Idle Jump", Value = true, Callback = function(v) Config.AntiAFK = v end })

task.spawn(function()
    while task.wait(10) do
        if Config.AntiAFK then
            local lp = game.Players.LocalPlayer
            if lp.Character and lp.Character:FindFirstChild("Humanoid") then
                lp.Character.Humanoid.Jump = true
            end
            game:GetService("VirtualUser"):CaptureController()
            game:GetService("VirtualUser"):ClickButton2(Vector2.new())
        end
    end
end)

EliteSec:Toggle({ Title = "Panic on Admin", Value = true, Callback = function(v) Config.PanicOnAdmin = v end })

local SetSec = SettingTab:Section({ Title = "Connection" })
SetSec:Input({ Title = "Webhook URL", Callback = function(v) Config.WebhookURL = v end })

-- // 8. GLOBAL EVENTS // --
game:GetService("ReplicatedStorage").GameEvents.TradeEvents.Booths.AddToHistory.OnClientEvent:Connect(function(data)
    if data and data.seller and data.seller.userId == game.Players.LocalPlayer.UserId then
        Stats.Sold = Stats.Sold + 1
        Stats.Gems = Stats.Gems + (data.price or 0)
        SessionBtn:SetTitle("Session Profit: " .. Stats.Gems .. " Tokens")
        Notify("SALE SUCCESS", "Sold for " .. data.price)
    end
end)

game.Players.PlayerAdded:Connect(function(player)
    if Config.PanicOnAdmin and (player:GetRankInGroup(game.CreatorId) > 1 or player.UserId == game.CreatorId) then
        game:GetService("ReplicatedStorage").GameEvents.TradeEvents.Booths.RemoveBooth:FireServer()
        task.wait(1)
        game:GetService("TeleportService"):Teleport(game.PlaceId)
    end
end)
