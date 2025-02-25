//==[ Variable ]==
enum droppedItems
{
	droppedID,
	droppedItem[32],
	droppedPlayer[24],
	droppedModel,
	droppedQuantity,
	Float:droppedPos[3],
	droppedWeapon,
	droppedAmmo,
	droppedInt,
	droppedWorld,
	droppedObject,
	Text3D:droppedText3D
};

new DroppedItems[MAX_DROPPED_ITEMS][droppedItems];

//==[ Function ]==
FUNC::Dropped_Load()
{
	new rows = cache_num_rows();
 	if(rows)
  	{
    	forex(i, rows)
		{
		    cache_get_value_name_int(i, "ID", DroppedItems[i][droppedID]);

			cache_get_value_name(i, "itemName", DroppedItems[i][droppedItem]);
			cache_get_value_name(i, "itemPlayer", DroppedItems[i][droppedPlayer]);

			cache_get_value_name_int(i, "itemModel", DroppedItems[i][droppedModel]);
			cache_get_value_name_int(i, "itemQuantity", DroppedItems[i][droppedQuantity]);
			cache_get_value_name_float(i, "itemX", DroppedItems[i][droppedPos][0]);
			cache_get_value_name_float(i, "itemY", DroppedItems[i][droppedPos][1]);
			cache_get_value_name_float(i, "itemZ", DroppedItems[i][droppedPos][2]);
			cache_get_value_name_int(i, "itemInt", DroppedItems[i][droppedInt]);
			cache_get_value_name_int(i, "itemWorld", DroppedItems[i][droppedWorld]);

			DroppedItems[i][droppedObject] = CreateDynamicObject(DroppedItems[i][droppedModel], DroppedItems[i][droppedPos][0], DroppedItems[i][droppedPos][1], DroppedItems[i][droppedPos][2], 0.0, 0.0, 0.0, DroppedItems[i][droppedWorld], DroppedItems[i][droppedInt]);
			DroppedItems[i][droppedText3D] = CreateDynamic3DTextLabel(DroppedItems[i][droppedItem], COLOR_SERVER, DroppedItems[i][droppedPos][0], DroppedItems[i][droppedPos][1], DroppedItems[i][droppedPos][2], 15.0, INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 0, DroppedItems[i][droppedWorld], DroppedItems[i][droppedInt]);
		}
		printf("[DROPITEM] Loaded %d Dropped items from database.", rows);
	}
	return true;
}

DropItem(const item[], const player[], model, quantity, Float:x, Float:y, Float:z, interior, world, weaponid = 0, ammo = 0)
{
	new
	    query[300];

	forex(i, MAX_DROPPED_ITEMS) if (!DroppedItems[i][droppedModel])
	{
	    format(DroppedItems[i][droppedItem], 32, item);
	    format(DroppedItems[i][droppedPlayer], 24, player);

		DroppedItems[i][droppedModel] = model;
		DroppedItems[i][droppedQuantity] = quantity;
		DroppedItems[i][droppedWeapon] = weaponid;
  		DroppedItems[i][droppedAmmo] = ammo;
		DroppedItems[i][droppedPos][0] = x;
		DroppedItems[i][droppedPos][1] = y;
		DroppedItems[i][droppedPos][2] = z;

		DroppedItems[i][droppedInt] = interior;
		DroppedItems[i][droppedWorld] = world;

		DroppedItems[i][droppedObject] = CreateDynamicObject(model, x, y, z, 0.0, 0.0, 0.0, world, interior);

 		DroppedItems[i][droppedText3D] = CreateDynamic3DTextLabel(item, COLOR_SERVER, x, y, z, 10.0, INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 0, world, interior);

 		format(query, sizeof(query), "INSERT INTO `dropped` (`itemName`, `itemPlayer`, `itemModel`, `itemQuantity`, `itemWeapon`, `itemAmmo`, `itemX`, `itemY`, `itemZ`, `itemInt`, `itemWorld`) VALUES('%s', '%s', '%d', '%d', '%d', '%d', '%.4f', '%.4f', '%.4f', '%d', '%d')", item, player, model, quantity, weaponid, ammo, x, y, z, interior, world);
		mysql_tquery(sqlcon, query, "OnDroppedItem", "d", i);
		return i;
	}
	return -1;
}

DropPlayerItem(playerid, itemid, quantity = 1)
{
	if (itemid == -1 || !InventoryData[playerid][itemid][invExists])
	    return false;

    new
		Float:x,
  		Float:y,
    	Float:z,
		Float:angle,
		string[32];

	strunpack(string, InventoryData[playerid][itemid][invItem]);

	GetPlayerPos(playerid, x, y, z);
	GetPlayerFacingAngle(playerid, angle);

	DropItem(string, ReturnName(playerid), InventoryData[playerid][itemid][invModel], quantity, x, y, z - 0.9, GetPlayerInterior(playerid), GetPlayerVirtualWorld(playerid));
 	Inventory_Remove(playerid, string, quantity);

	ApplyAnimation(playerid, "GRENADE", "WEAPON_throwu", 4.1, 0, 0, 0, 0, 0, 1);
 	SendNearbyMessage(playerid, 20.0, COLOR_PURPLE, "* %s has dropped a \"%s\".", ReturnName(playerid), string);
	return true;
}