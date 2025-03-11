RegisterNetEvent("syncRoofLoop")
AddEventHandler("syncRoofLoop", function(vehNet, state)
    TriggerClientEvent("syncRoofLoop", -1, vehNet, state)
end)
