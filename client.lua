-- Config: Define animations for different vehicle models
local vehicleAnimations = {
    ["23tahoeppv"] = {
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

local activeVehicles = {}  -- Keyed by network ID
local animLoops = {}       -- Keyed by network ID

-- Helper function to play an animation
function PlayAnim(vehicle, animDict, animName, blend, loop, stayInAnim, startPos, flags)
    startPos = startPos or 0.0
    flags = flags or 0
    return PlayEntityAnim(vehicle, animName, animDict, blend, loop, stayInAnim, false, startPos, flags)
end

-- Loads the animation dictionary if needed and then plays the animation
function LoadAndPlayAnim(vehicle, animDict, animName, blend, loop, stayInAnim, startPos, flags)
    if not HasAnimDictLoaded(animDict) then
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do
            Citizen.Wait(0)
        end
    end
    return PlayAnim(vehicle, animDict, animName, blend, loop, stayInAnim, startPos, flags)
end

-- Starts the animation loop for a vehicle
function startanimloop(vehicle, animData)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    local vehNet = VehToNet(vehicle)
    animLoops[vehNet] = true
    Citizen.CreateThread(function()
        while animLoops[vehNet] do
            if not IsEntityPlayingAnim(vehicle, animData.animDict, animData.animName, 3) then
                LoadAndPlayAnim(vehicle, animData.animDict, animData.animName, 8.0, animData.loopAnim, false, 0.0, 0)
            end
            Citizen.Wait(500)
        end
    end)
end

-- Stops the animation loop for a vehicle and plays the finished animation
function stopanimloop(vehicle, animData)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    local vehNet = VehToNet(vehicle)
    animLoops[vehNet] = false
    StopEntityAnim(vehicle, animData.animName, animData.animDict, 8.0)

    -- Play the finished animation if defined
    if animData.finishedAnimDict and animData.finishedAnimName then
        LoadAndPlayAnim(vehicle, animData.finishedAnimDict, animData.finishedAnimName, 8.0, false, false, 0.0, 0)
    end
end

-- Sync function to check nearby vehicles and broadcast their animation state
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- Check every 1 second

        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local vehicles = GetGamePool("CVehicle")

        for _, vehicle in ipairs(vehicles) do
            if #(GetEntityCoords(vehicle) - coords) < 50.0 then -- Check within 50m radius
                local vehModel = GetEntityModel(vehicle)
                for model, animData in pairs(vehicleAnimations) do
                    if vehModel == GetHashKey(model) then
                        local vehNet = VehToNet(vehicle)
                        local isSirenOn = IsVehicleSirenOn(vehicle)

                        if isSirenOn and not activeVehicles[vehNet] then
                            activeVehicles[vehNet] = true
                            TriggerServerEvent("syncRoofLoop", vehNet, true)
                        elseif not isSirenOn and activeVehicles[vehNet] then
                            activeVehicles[vehNet] = nil
                            TriggerServerEvent("syncRoofLoop", vehNet, false)
                        end
                        break
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
    if vehicle and DoesEntityExist(vehicle) then
        local vehModel = GetEntityModel(vehicle)
        for model, animData in pairs(vehicleAnimations) do
            if vehModel == GetHashKey(model) then
                if state then
                    startanimloop(vehicle, animData)
                else
                    stopanimloop(vehicle, animData)
                end
                break
            end
        end
    end
end)

-- Dont ask how much of this was made with ChatGPT. The answer is enough where it works tho.