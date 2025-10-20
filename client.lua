-- Config
local Config = {}
Config.UsingLVC = true -- Set to true if using LVC (uses control 85/Q), false for non-LVC (uses control 86/E)

-- Define animations for different vehicle models
local vehicleAnimations = {
    ["jbpd-23tahoeppv"] = {
        animDict = "arges_sweep",
        animName = "arges_sweep",
        loopAnim = true,
        finishedAnimDict = "arges_front",
        finishedAnimName = "arges_front"
    },
    ["some_other_car"] = {
        animDict = "other_dict",
        animName = "other_anim",
        loopAnim = false,
        finishedAnimDict = "other_finished_dict",
        finishedAnimName = "other_finished_anim"
    }
}

-- Determine which control to use based on LVC setting
local CONTROL_KEY = Config.UsingLVC and 85 or 86 -- If LVC: 85 = Q key, If not LVC: 86 = E key

local activeVehicles = {}  -- Keyed by network ID
local animLoops = {}       -- Keyed by network ID

-- Helper function to play an animation
local function PlayAnim(vehicle, animDict, animName, blend, loop, stayInAnim, startPos, flags)
    startPos = startPos or 0.0
    flags = flags or 0
    return PlayEntityAnim(vehicle, animName, animDict, blend, loop, stayInAnim, false, startPos, flags)
end

-- Loads the animation dictionary if needed and then plays the animation
local function LoadAndPlayAnim(vehicle, animDict, animName, blend, loop, stayInAnim, startPos, flags)
    if not HasAnimDictLoaded(animDict) then
        RequestAnimDict(animDict)
        local timeout = 0
        while not HasAnimDictLoaded(animDict) and timeout < 1000 do
            Citizen.Wait(10)
            timeout = timeout + 10
        end
        if timeout >= 1000 then
            print("^1[ERROR] Failed to load animation dictionary: " .. animDict .. "^0")
            return false
        end
    end
    return PlayAnim(vehicle, animDict, animName, blend, loop, stayInAnim, startPos, flags)
end

-- Gets animation data for a vehicle model
local function GetVehicleAnimData(vehicle)
    local vehModel = GetEntityModel(vehicle)
    for model, animData in pairs(vehicleAnimations) do
        if vehModel == GetHashKey(model) then
            return animData
        end
    end
    return nil
end

-- Starts the animation loop for a vehicle
local function StartAnimLoop(vehicle, animData)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    
    local vehNet = VehToNet(vehicle)
    if animLoops[vehNet] then return end -- Already running
    
    animLoops[vehNet] = true
    
    Citizen.CreateThread(function()
        while animLoops[vehNet] and DoesEntityExist(vehicle) do
            if not IsEntityPlayingAnim(vehicle, animData.animDict, animData.animName, 3) then
                LoadAndPlayAnim(vehicle, animData.animDict, animData.animName, 8.0, animData.loopAnim, false, 0.0, 0)
            end
            Citizen.Wait(500)
        end
        -- Cleanup when loop ends
        animLoops[vehNet] = nil
    end)
end

-- Stops the animation loop for a vehicle and plays the finished animation
local function StopAnimLoop(vehicle, animData)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    
    local vehNet = VehToNet(vehicle)
    animLoops[vehNet] = false
    StopEntityAnim(vehicle, animData.animName, animData.animDict, 8.0)

    -- Play the finished animation if defined
    if animData.finishedAnimDict and animData.finishedAnimName then
        LoadAndPlayAnim(vehicle, animData.finishedAnimDict, animData.finishedAnimName, 8.0, false, false, 0.0, 0)
    end
end

-- Key press detection thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        -- Disable control to check if it's being pressed
        DisableControlAction(0, CONTROL_KEY, true)
        
        if IsDisabledControlJustReleased(0, CONTROL_KEY) then
            local ped = PlayerPedId()
            
            if IsPedInAnyVehicle(ped, false) then
                local vehicle = GetVehiclePedIsIn(ped, false)
                local animData = GetVehicleAnimData(vehicle)
                
                if animData then
                    local vehNet = VehToNet(vehicle)
                    
                    -- Toggle the animation state
                    if activeVehicles[vehNet] then
                        activeVehicles[vehNet] = nil
                        TriggerServerEvent("syncRoofLoop", vehNet, false)
                    else
                        activeVehicles[vehNet] = true
                        TriggerServerEvent("syncRoofLoop", vehNet, true)
                    end
                end
            end
        end
    end
end)

-- Listen for sync events from the server
RegisterNetEvent("syncRoofLoop")
AddEventHandler("syncRoofLoop", function(vehNet, state)
    local vehicle = NetToVeh(vehNet)
    
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then 
        return 
    end
    
    local animData = GetVehicleAnimData(vehicle)
    
    if animData then
        if state then
            StartAnimLoop(vehicle, animData)
        else
            StopAnimLoop(vehicle, animData)
        end
    end
end)

-- Cleanup when player exits vehicle
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        
        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped, false) then
            -- Player is not in a vehicle, cleanup any active states for vehicles they were in
            local coords = GetEntityCoords(ped)
            for vehNet, _ in pairs(activeVehicles) do
                local vehicle = NetToVeh(vehNet)
                if vehicle and DoesEntityExist(vehicle) then
                    local vehCoords = GetEntityCoords(vehicle)
                    -- If vehicle is far away and player left it, clean up
                    if #(coords - vehCoords) > 100.0 then
                        activeVehicles[vehNet] = nil
                    end
                else
                    -- Vehicle no longer exists, cleanup
                    activeVehicles[vehNet] = nil
                    animLoops[vehNet] = nil
                end
            end
        end
    end
end)

-- Made with assistance from AI, refined for FiveM use