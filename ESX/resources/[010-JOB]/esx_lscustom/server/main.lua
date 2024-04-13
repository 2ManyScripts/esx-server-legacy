local Vehicles
local Customs = {}

RegisterNetEvent('esx_lscustom:startModing', function(props, netId)
	local src = tostring(source)
	if Customs[src] then
		Customs[src][tostring(props.plate)] = {props = props, netId = netId}
	else
		Customs[src] = {}
		Customs[src][tostring(props.plate)] = {props = props, netId = netId}
	end
end)

RegisterNetEvent('esx_lscustom:stopModing', function(plate)
	local src = tostring(source)
	if Customs[src] then
		Customs[src][tostring(plate)] = nil
	end
end)

AddEventHandler('esx:playerDropped', function(src)
    src = tostring(src)
	local playersCount = #GetPlayers()
    if Customs[src] then
        for k, v in pairs(Customs[src]) do
            local entity = NetworkGetEntityFromNetworkId(v.netId)
            if DoesEntityExist(entity) then
                if playersCount > 0 then
                    TriggerClientEvent('esx_lscustom:restoreMods', -1, v.netId, v.props)
                else
                    DeleteEntity(entity)
                end
            end
        end
        Customs[src] = nil
    end
end)

RegisterNetEvent('esx_lscustom:buyMod', function(price)
	local source = source
	local xPlayer = ESX.GetPlayerFromId(source)
	price = tonumber(price)

  if not xPlayer then return print('^3[WARNING]^0 The player could\'nt be found.') end

	if Config.IsMechanicJobOnly then
		local societyAccount

		TriggerEvent('esx_addonaccount:getSharedAccount', 'society_mechanic', function(account)
			societyAccount = account
		end)

		if price < societyAccount.money then
			TriggerClientEvent('esx_lscustom:installMod', source)
			TriggerClientEvent('esx:showNotification', source, TranslateCap('purchased'))
			societyAccount.removeMoney(price)
		else
			TriggerClientEvent('esx_lscustom:cancelInstallMod', source)
			TriggerClientEvent('esx:showNotification', source, TranslateCap('not_enough_money'))
		end
	else
		if price < xPlayer.getMoney() then
			TriggerClientEvent('esx_lscustom:installMod', source)
			TriggerClientEvent('esx:showNotification', source, TranslateCap('purchased'))
			xPlayer.removeMoney(price, "LSC Purchase")
		else
			TriggerClientEvent('esx_lscustom:cancelInstallMod', source)
			TriggerClientEvent('esx:showNotification', source, TranslateCap('not_enough_money'))
		end
	end
end)

RegisterNetEvent('esx_lscustom:refreshOwnedVehicle', function(vehicleProps, netId)
	local src = tostring(source)
	local xPlayer = ESX.GetPlayerFromId(source)

  if not vehicleProps then return print('^3[WARNING]^0 The vehicle Props could\'nt be found.') end
  if not vehicleProps.plate then return print('^3[WARNING]^0 The vehicle plate could\'nt be found.') end
  if not vehicleProps.model then return print('^3[WARNING]^0 The vehicle model could\'nt be found.') end

  if not xPlayer then return print('^3[WARNING]^0 The player could\'nt be found.') end

	MySQL.single('SELECT vehicle FROM owned_vehicles WHERE plate = ?', {vehicleProps.plate},
	function(result)
		if result then
			local vehicle = json.decode(result.vehicle)
			if vehicleProps.model == vehicle.model then
				MySQL.update('UPDATE owned_vehicles SET vehicle = ? WHERE plate = ?', {json.encode(vehicleProps), vehicleProps.plate})
				if Customs[src] then
					if Customs[src][tostring(vehicleProps.plate)]  then
						Customs[src][tostring(vehicleProps.plate)].props = vehicleProps
					else
						Customs[src][tostring(vehicleProps.plate)] = {props = vehicleProps, netId = netId}
					end
				else
					Customs[src] = {}
					Customs[src][tostring(vehicleProps.plate)] = {props = vehicleProps, netId = netId}
				end
        local veh = NetworkGetEntityFromNetworkId(netId)
				local Veh_State = Entity(veh).state.VehicleProperties
				if Veh_State then
					Entity(veh).state:set("VehicleProperties", vehicleProps, true)
        end
			else
				print(('[^3WARNING^7] Player ^5%s^7 Attempted To upgrade with mismatching vehicle model'):format(xPlayer.source))
			end
		end
	end)
end)

ESX.RegisterServerCallback('esx_lscustom:getVehiclesPrices', function(source, cb)
	if not Vehicles then
		Vehicles = MySQL.query.await('SELECT model, price FROM vehicles')
	end
	cb(Vehicles)
end)
