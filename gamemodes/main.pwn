/* Includes */
#include <a_samp>
#define SSCANF_NO_NICE_FEATURES
#define YSI_NO_HEAP_MALLOC

#include <sscanf2>
#include <streamer>

#include <a_mysql>

#include <YSI_Data\y_iterate>
#include <YSI_Coding\y_va>
#include <YSI_Coding\y_timers>
#include <YSI_Extra\y_inline_timers>

#include <easyDialog>
#include <eSelection>
#include <samp_bcrypt>
#include <izcmd>
#include <EVF2>
#include <progress2>
#include <PreviewModelDialog2>
#include <strlib>

//==========[ MODULAR ]==========
//==[ Server & Misc ]==
#include "Modular\Server\Define.pwn"
#include "Modular\Server\Variable.pwn"

//==[ Dynamic ]==
#include "Modular\Dynamic\Bisnis.pwn"
#include "Modular\Dynamic\Rental.pwn"
#include "Modular\Dynamic\House.pwn"

//==[ Player ]==
#include "Modular\Player\Inventory.pwn"
#include "Modular\Player\DropItem.pwn"

//==[ Vehicle ]==
#include "Modular\Vehicle\PrivateVehicle.pwn"

//==[ Faction]
#include "Modular\Faction\FactionVariable.pwn"

//==[ Commands ]==
#include "Modular\Cmd\PlayerCmd.pwn"
#include "Modular\Cmd\AdminCmd.pwn"

//==[ Server Function ]==
#include "Modular\Server\Streamer.pwn"
#include "Modular\Server\Textdraw.pwn"
#include "Modular\Server\Function.pwn"

/* Gamemode Start! */

main(){}

public OnGameModeInit()
{
	Database_Connect();

	SendRconCommand(va_return("hostname %s", SERVER_NAME));
	SendRconCommand(va_return("weburl %s", SERVER_URL));
	SetGameModeText(SERVER_REVISION);

	CreateGlobalTextDraw();
	DisableInteriorEnterExits();
	EnableStuntBonusForAll(0);
	ManualVehicleEngineAndLights();
	StreamerConfig();
	
	Iter_Init(House);
	Iter_Init(FurnitureHouse);
	Iter_Init(PlayerVehicle);

	/* Load from Database */
	mysql_tquery(sqlcon, "SELECT * FROM `business`", "Business_Load");
	mysql_tquery(sqlcon, "SELECT * FROM `dropped`", "Dropped_Load", "");
	mysql_tquery(sqlcon, "SELECT * FROM `rental`", "Rental_Load", "");
	mysql_tquery(sqlcon, "SELECT * FROM `houses`", "House_Load", "");
	return true;
}

public OnGameModeExit()
{
	return true;
}

public OnPlayerConnect(playerid)
{
	g_RaceCheck{playerid} ++;

	ResetVariable(playerid);

	CreatePlayerHUD(playerid);
	return true;
}

public OnPlayerRequestClass(playerid, classid)
{
    if (IsPlayerNPC(playerid))
	    return true;

	if (!PlayerData[playerid][pAccount] && !PlayerData[playerid][pKicked])
	{
	    PlayerData[playerid][pAccount] = true;
	    TogglePlayerSpectating(playerid, 1);

		SetPlayerColor(playerid, 0xFFFFFFFF);
		SetCameraData(playerid);
		CheckAccount(playerid);
	}
	return true;
}

public OnPlayerDisconnect(playerid, reason)
{
	g_RaceCheck{playerid} ++;
	UnloadPlayerVehicle(playerid);
	SaveData(playerid);
	return true;
}

public OnPlayerUpdate(playerid)
{
	if (PlayerData[playerid][pKicked])
		return false;

	return true;
}

public OnPlayerStateChange(playerid, newstate, oldstate)
{
	if(newstate == PLAYER_STATE_DRIVER)
	{
	    new vehicleid = GetPlayerVehicleID(playerid);
	    new pvid = Vehicle_Inside(playerid);
	    new time[3];
	    if(IsSpeedoVehicle(vehicleid))
	    {
	        forex(i, 4)
	        {
	            PlayerTextDrawShow(playerid, SPEEDOTD[playerid][i]);
			}
			PlayerTextDrawShow(playerid, KMHTD[playerid]);
			PlayerTextDrawShow(playerid, VEHNAMETD[playerid]);
			PlayerTextDrawShow(playerid, HEALTHTD[playerid]);
			FUELBAR[playerid] = CreatePlayerProgressBar(playerid, 520.000000, 433.000000, 110.000000, 7.000000, 9109759, 100.000000, BAR_DIRECTION_RIGHT);
		}
		if(pvid != -1 && VehicleData[pvid][vRental] != -1)
		{
		    GetElapsedTime(VehicleData[pvid][vRentTime], time[0], time[1], time[2]);
		    SendClientMessageEx(playerid, COLOR_SERVER, "RENTAL: {FFFFFF}Sisa rental {00FFFF}%s {FFFFFF}milikmu adalah {FFFF00}%02d jam %02d menit %02d detik", GetVehicleName(vehicleid), time[0], time[1], time[2]);
		}
	}
	if(oldstate == PLAYER_STATE_DRIVER)
	{
        forex(i, 4)
        {
            PlayerTextDrawHide(playerid, SPEEDOTD[playerid][i]);
		}
		PlayerTextDrawHide(playerid, KMHTD[playerid]);
		PlayerTextDrawHide(playerid, VEHNAMETD[playerid]);
		PlayerTextDrawHide(playerid, HEALTHTD[playerid]);
		DestroyPlayerProgressBar(playerid, FUELBAR[playerid]);
	}
	return true;
}

public OnModelSelectionResponse(playerid, extraid, index, modelid, response)
{
	if ((response) && (extraid == MODEL_SELECTION_FURNITURE))
	{
        new
			id = House_Inside(playerid),
			price;

		new
		    Float:x,
		    Float:y,
		    Float:z,
		    Float:angle;

        GetPlayerPos(playerid, x, y, z);
        GetPlayerFacingAngle(playerid, angle);

        x += 5.0 * floatsin(-angle, degrees);
        y += 5.0 * floatcos(-angle, degrees);

	    if (id != -1)
	    {
	        price = Furniture_ReturnPrice(PlayerData[playerid][pListitem]);

	        if (GetMoney(playerid) < price)
	            return SendErrorMessage(playerid, "You have insufficient funds for the purchase.");

			new furniture = Furniture_Add(House_Inside(playerid), GetFurnitureNameByModel(modelid), modelid, x, y, z, 0.0, 0.0, angle);

			if(furniture == INVALID_ITERATOR_SLOT)
				return SendErrorMessage(playerid, "The server cannot create more furniture's!");

			GiveMoney(playerid, -price);
			SendServerMessage(playerid, "You have purchased a \"%s\" for %s.", GetFurnitureNameByModel(modelid), FormatNumber(price));
			Streamer_Update(playerid, STREAMER_TYPE_OBJECT);
	    }
	}
	return true;
}

Dialog:DIALOG_REGISTER(playerid, response, listitem, inputtext[])
{
	if(!response)
		return KickEx(playerid);

	new str[256];
	format(str, sizeof(str), "{FFFFFF}UCP Account: {00FFFF}%s\n{FFFFFF}Attempts: {00FFFF}%d/5\n{FFFFFF}Create Password: {FF00FF}(Input Below)", GetName(playerid), PlayerData[playerid][pAttempt]);

	if(strlen(inputtext) < 7)
		return Dialog_Show(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Register to Xyronite", str, "Register", "Exit");

	if(strlen(inputtext) > 32)
		return Dialog_Show(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Register to Xyronite", str, "Register", "Exit");

	bcrypt_hash(playerid, "HashPlayerPassword", inputtext, BCRYPT_COST);

	return true;
}

Dialog:DIALOG_LOGIN(playerid, response, listitem, inputtext[])
{
	if(!response)
		return KickEx(playerid);
		
	if(strlen(inputtext) < 1)
	{
		new str[256];
		format(str, sizeof(str), "{FFFFFF}UCP Account: {00FFFF}%s\n{FFFFFF}Attempts: {00FFFF}%d/5\n{FFFFFF}Password: {FF00FF}(Input Below)", GetName(playerid), PlayerData[playerid][pAttempt]);
		Dialog_Show(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login to Xyronite", str, "Login", "Exit");
		return true;
	}
	new pwQuery[256], hash[BCRYPT_HASH_LENGTH];
	mysql_format(sqlcon, pwQuery, sizeof(pwQuery), "SELECT Password FROM accounts WHERE UCP = '%e' LIMIT 1", GetName(playerid));
	mysql_query(sqlcon, pwQuery);
	
	cache_get_value_name(0, "Password", hash, sizeof(hash));
	
	bcrypt_verify(playerid, "OnPlayerPasswordChecked", inputtext, hash);

	return true;
}

Dialog:DIALOG_CHARLIST(playerid, response, listitem, inputtext[])
{
	if(response)
	{
		if (PlayerChar[playerid][listitem][0] == EOS)
			return Dialog_Show(playerid, DIALOG_MAKECHAR, DIALOG_STYLE_INPUT, "Create Character", "Insert your new Character Name\n\nExample: Finn_Xanderz, Javier_Cooper etc.", "Create", "Exit");

		PlayerData[playerid][pChar] = listitem;
		SetPlayerName(playerid, PlayerChar[playerid][listitem]);

		new cQuery[256];
		mysql_format(sqlcon, cQuery, sizeof(cQuery), "SELECT * FROM `characters` WHERE `Name` = '%s' LIMIT 1;", PlayerChar[playerid][PlayerData[playerid][pChar]]);
		mysql_tquery(sqlcon, cQuery, "LoadCharacterData", "d", playerid);
		
	}
	return true;
}

Dialog:DIALOG_MAKECHAR(playerid, response, listitem, inputtext[])
{
	if(response)
	{
		if(strlen(inputtext) < 1 || strlen(inputtext) > 24)
			return Dialog_Show(playerid, DIALOG_MAKECHAR, DIALOG_STYLE_INPUT, "Create Character", "Insert your new Character Name\n\nExample: Finn_Xanderz, Javier_Cooper etc.", "Create", "Back");

		if(!IsRoleplayName(inputtext))
			return Dialog_Show(playerid, DIALOG_MAKECHAR, DIALOG_STYLE_INPUT, "Create Character", "Insert your new Character Name\n\nExample: Finn_Xanderz, Javier_Cooper etc.", "Create", "Back");

		new characterQuery[178];
		mysql_format(sqlcon, characterQuery, sizeof(characterQuery), "SELECT * FROM `characters` WHERE `Name` = '%s'", inputtext);
		mysql_tquery(sqlcon, characterQuery, "InsertPlayerName", "ds", playerid, inputtext);

		format(PlayerData[playerid][pUCP], 22, GetName(playerid));
	}
	return true;
}

Dialog:DIALOG_AGE(playerid, response, listitem, inputtext[])
{
	if(response)
	{
		if(strval(inputtext) >= 70)
			return Dialog_Show(playerid, DIALOG_AGE, DIALOG_STYLE_INPUT, "Character Age", "ERROR: Cannot more than 70 years old!", "Continue", "Cancel");

		if(strval(inputtext) < 13)
			return Dialog_Show(playerid, DIALOG_AGE, DIALOG_STYLE_INPUT, "Character Age", "ERROR: Cannot below 13 Years Old!", "Continue", "Cancel");

		PlayerData[playerid][pAge] = strval(inputtext);
		Dialog_Show(playerid, DIALOG_ORIGIN, DIALOG_STYLE_INPUT, "Character Origin", "Please input your Character Origin:", "Continue", "Quit");
	}
	else
	{
		Dialog_Show(playerid, DIALOG_AGE, DIALOG_STYLE_INPUT, "Character Age", "Please Insert your Character Age", "Continue", "Cancel");
	}
	return true;
}

Dialog:DIALOG_ORIGIN(playerid, response, listitem, inputtext[])
{
	if(!response)
		return Dialog_Show(playerid, DIALOG_ORIGIN, DIALOG_STYLE_INPUT, "Character Origin", "Please input your Character Origin:", "Continue", "Quit");

	if(strlen(inputtext) < 1)
		return Dialog_Show(playerid, DIALOG_ORIGIN, DIALOG_STYLE_INPUT, "Character Origin", "Please input your Character Origin:", "Continue", "Quit");

	format(PlayerData[playerid][pOrigin], 32, inputtext);
	Dialog_Show(playerid, DIALOG_GENDER, DIALOG_STYLE_LIST, "Character Gender", "Male\nFemale", "Continue", "Cancel");

	return true;
}

Dialog:DIALOG_GENDER(playerid, response, listitem, inputtext[])
{
	if(!response)
		return Dialog_Show(playerid, DIALOG_GENDER, DIALOG_STYLE_LIST, "Character Gender", "Male\nFemale", "Continue", "Cancel");

	if(listitem == 0)
	{
		PlayerData[playerid][pGender] = 1;
		PlayerData[playerid][pSkin] = 240;
		PlayerData[playerid][pHealth] = 100.0;
		SetupPlayerData(playerid);
	}
	if(listitem == 1)
	{
		PlayerData[playerid][pGender] = 2;
		PlayerData[playerid][pSkin] = 172;
		PlayerData[playerid][pHealth] = 100.0;
		SetupPlayerData(playerid);
		
	}
	return true;
}

Dialog:DIALOG_HELP(playerid, response, listitem, inputtext[])
{
	new string[1412];
	if(response)
	{
		if(listitem == 0)
		{
			strcat(string, "/phone | /salary | /insu | /weapon | /takejob | /quitjob | /renthelp | /call | /accept | /animlist\n");
			strcat(string, "/pay | /buy | /refuel | /inventory | /enter | /jobdelay | /report | /ask | /sms | /myproperty \n");
			strcat(string, "/health [opt:playerid/name] | /mask | /atm | /stats | /drag | /undrag | /frisk | /factions\n");
			strcat(string, "/tempdamage [opt:playerid/PartOfName] | /setfreq | /pr | /disablecp | /licenses [opt:playerid/PartOfName]\n");
			strcat(string, "/v(ehicle) | /seatbelt | /isafk | /clearchat | /fish | /sellfish | /myfish | /buybait | /toggle\n");
			strcat(string, "/tag | /cursor | /hidebuy | /tog(gle) | /warnings | /hbestyle | /weapon | /weapon | /usecigar | /usecrack | /useweed\n");
			Dialog_Show(playerid, DIALOG_HELP_RETURN, DIALOG_STYLE_MSGBOX, "General Commands", string, "Back", "");
		}
		if(listitem == 1)
		{
			strcat(string, "/me | /ame | /pr | /do | /l(ow) | /w(hisper) | /o | /c | /pm");
			Dialog_Show(playerid, DIALOG_HELP_RETURN, DIALOG_STYLE_MSGBOX, "Chat Commands", string, "Back", "");
		}
		if(listitem == 2)
		{
			Dialog_Show(playerid, DIALOG_HELP_JOB, DIALOG_STYLE_LIST, "Job Commands", "Trucker\nMechanic\nTaxi\nLumberjack\nFarmer\nMiner\nSidejob: Trashmaster", "Select", "Close");
		}
		if(listitem == 3)
		{
			strcat(string, "/faction [invite/kick/menu/accept/locker/setrank/quit]\n");
			strcat(string, "/r | /or | /d | /od\n");
			if(GetFactionType(playerid) == FACTION_POLICE)
			{
				strcat(string, "/mdc | /arrest | /detain | /cuff | /uncuff | /impound | /seizeweed | /m(egaphone)\n");
				strcat(string, "/take | /callsign | /spike | /tazer | /backup | /flare | /deploy | /undeploy | /undeployall\n");
			}
			else if(GetFactionType(playerid) == FACTION_MEDIC)
			{
				strcat(string, "/mdc | /treatment | /m(egaphone) | /stretcher");
			}
			else if(GetFactionType(playerid) == FACTION_NEWS)
			{
				strcat(string, "/live | /guest [invite/remove]");
			}
			else if(GetFactionType(playerid) == FACTION_GOV)
			{
				strcat(string, "/tax [set/withdraw/deposit]");
			}
			Dialog_Show(playerid, DIALOG_HELP_RETURN, DIALOG_STYLE_MSGBOX, "Faction Commands", string, "Back", "");
		}
		if(listitem == 4)
		{
			strcat(string, "/biz buy - untuk membeli Business\n");
			strcat(string, "/biz menu - untuk membuka menu Business (for owner)\n");
			strcat(string, "/biz lock - untuk toggle lock/unlock Business\n");
			strcat(string, "/biz reqstock - untuk meminta restock kepada Trucker\n");
			strcat(string, "/biz convertfuel - untuk merestock Fuel stock (24/7 only)\n");
			Dialog_Show(playerid, DIALOG_HELP_RETURN, DIALOG_STYLE_MSGBOX, "Business Commands", string, "Back", "");

		}
		if(listitem == 5)
		{
			strcat(string, "/house buy - untuk membeli house\n");
			strcat(string, "/house lock - untuk toggle lock/unlock House\n");
			strcat(string, "/house menu - untuk membuka House Menu\n");
			Dialog_Show(playerid, DIALOG_HELP_RETURN, DIALOG_STYLE_MSGBOX, "House Commands", string, "Back", "");
		}
		if(listitem == 6)
		{
			strcat(string, "/withdraw - untuk menarik uang dari Bank\n");
			strcat(string, "/deposit - untuk menyimpan uang ke Bank\n");
			strcat(string, "/paycheck - untuk mencairkan salary\n");
			strcat(string, "/balance - untuk melihat total uang di Bank\n");
			strcat(string, "/transfer - untuk men-transfer uang ke player lain\n");
			strcat(string, "/robbank - untuk merampok bank\n");
			strcat(string, "/setupvault - untuk memasang bom di brangkas bank\n");
			strcat(string, "\nNote: Command diatas hanya bisa dilakukan di Bank Point.");
			Dialog_Show(playerid, DIALOG_HELP_RETURN, DIALOG_STYLE_MSGBOX, "Bank Commands", string, "Back", "");
		}
		if(listitem == 7)
		{
			strcat(string, "/dealer buy - untuk membeli dealership\n");
			strcat(string, "/dealer buyvehicle - untuk membeli kendaraan\n");
			strcat(string, "/dealer menu - untuk membuka Dealership menu\n");
			Dialog_Show(playerid, DIALOG_HELP_RETURN, DIALOG_STYLE_MSGBOX, "Dealership Commands", string, "Back", "");
		}
		if(listitem == 8)
		{
			strcat(string, "/workshop buy - untuk membeli Workshop\n");
			strcat(string, "/workshop menu - untuk membuka Workshop menu\n");
			Dialog_Show(playerid, DIALOG_HELP_RETURN, DIALOG_STYLE_MSGBOX, "Workshop Commands", string, "Back", "");
		}
		if(listitem == 9)
		{
			strcat(string, "/farm buy - untuk membeli Farm\n");
			strcat(string, "/farm menu - untuk membuka Farm menu\n");
			Dialog_Show(playerid, DIALOG_HELP_RETURN, DIALOG_STYLE_MSGBOX, "Farm Commands", string, "Back", "");
		}
	}
	return true;
}

Dialog:DIALOG_STREAMER_CONFIG(playerid, response, listitem, inputtext[])
{
	if(response)
	{
		new config[] = {1000, 700, 500, 300};
		new const confignames[][24] = {"High", "Medium", "Low", "Potato"};

		Streamer_SetVisibleItems(STREAMER_TYPE_OBJECT, config[listitem], playerid);
		SendServerMessage(playerid, "You have adjusted maximum streamed object configuration to {FFFF00}%s", confignames[listitem]);
		Streamer_Update(playerid, STREAMER_TYPE_OBJECT);
	}
	return true;
}

//Biz
Dialog:DIALOG_BIZPRICE(playerid, response, listitem, inputtext[])
{
	if(response)
	{
		new str[256];
		PlayerData[playerid][pListitem] = listitem;
		format(str, sizeof(str), "{FFFFFF}Current Product Price: %s\n{FFFFFF}Silahkan masukan harga baru untuk product {00FFFF}%s", FormatNumber(BizData[PlayerData[playerid][pInBiz]][bizProduct][listitem]), ProductName[PlayerData[playerid][pInBiz]][listitem]);
		Dialog_Show(playerid, DIALOG_BIZPRICESET, DIALOG_STYLE_INPUT, "Set Product Price", str, "Set", "Close");
	}
	else cmd_biz(playerid, "menu");

	return true;
}

Dialog:DIALOG_BIZPROD(playerid, response, listitem, inputtext[])
{
	if(response)
	{
		new str[256];
		PlayerData[playerid][pListitem] = listitem;
		format(str, sizeof(str), "{FFFFFF}Current Product Name: %s\n{FFFFFF}Silahkan masukan nama baru untuk product {00FFFF}%s", ProductName[PlayerData[playerid][pInBiz]][listitem], ProductName[PlayerData[playerid][pInBiz]][listitem]);
		Dialog_Show(playerid, DIALOG_BIZPRODSET, DIALOG_STYLE_INPUT, "Set Product Name", str, "Set", "Close");
	}
	else cmd_biz(playerid, "menu");

	return true;
}

Dialog:DIALOG_BIZPRODSET(playerid, response, listitem, inputtext[])
{
	if(response)
	{
		if(strlen(inputtext) < 1 || strlen(inputtext) > 24)
			return SendErrorMessage(playerid, "Invalid Product name!");

		new id = PlayerData[playerid][pInBiz];
		new slot = PlayerData[playerid][pListitem];
		SendClientMessageEx(playerid, COLOR_SERVER, "BIZ: {FFFFFF}Kamu telah mengubah nama product dari {00FFFF}%s {FFFFFF}menjadi {00FFFF}%s", ProductName[id][slot], inputtext);
		format(ProductName[id][slot], 24, inputtext);
		cmd_biz(playerid, "menu");
		Business_Save(id);
	}
	return true;
}

Dialog:DIALOG_BIZPRICESET(playerid, response, listitem, inputtext[])
{
	if(response)
	{
		if(strval(inputtext) < 1)
			return SendErrorMessage(playerid, "Invalid Product price!");
			
		new id = PlayerData[playerid][pInBiz];
		new slot = PlayerData[playerid][pListitem];
		SendClientMessageEx(playerid, COLOR_SERVER, "BIZ: {FFFFFF}Kamu telah mengubah harga product dari {009000}%s {FFFFFF}menjadi {009000}%s", FormatNumber(BizData[id][bizProduct][slot]), FormatNumber(strval(inputtext)));
		BizData[id][bizProduct][slot] = strval(inputtext);
		cmd_biz(playerid, "menu");
		Business_Save(id);
	}
	return true;
}

Dialog:DIALOG_BIZMENU(playerid, response, listitem, inputtext[])
{
	if(response)
	{
		if(listitem == 0)
		{
			SetProductName(playerid);
		}
		if(listitem == 1)
		{
			SetProductPrice(playerid);
		}
		if(listitem == 2)
		{
			new str[256];
			format(str, sizeof(str), "{FFFFFF}Current Biz Name: %s\n{FFFFFF}Silahkan masukan nama Business mu yang baru:\n\n{FFFFFF}Note: Max 24 Huruf!", BizData[PlayerData[playerid][pInBiz]][bizName]);
			Dialog_Show(playerid, DIALOG_BIZNAME, DIALOG_STYLE_INPUT, "Business Name", str, "Set", "Close");
		}
	}
	return true;
}

Dialog:DIALOG_BIZBUY(playerid, response, listitem, inputtext[])
{
	if(response)
	{
		new bid = PlayerData[playerid][pInBiz], price, prodname[34];
		if(bid != -1)
		{
			price = BizData[bid][bizProduct][listitem];
			prodname = ProductName[bid][listitem];
			if(GetMoney(playerid) < price)
				return SendErrorMessage(playerid, "You don't have enough money!");
				
			if(BizData[bid][bizStock] < 1)
				return SendErrorMessage(playerid, "This business is out of stock.");
				
			switch(BizData[bid][bizType])
			{
				case 1:
				{
					if(listitem == 0)
					{
						if(GetEnergy(playerid) >= 100)
							return SendErrorMessage(playerid, "Your energy is already full!");

						PlayerData[playerid][pEnergy] += 20;
						SendNearbyMessage(playerid, 20.0, COLOR_PURPLE, "* %s has paid %s and purchased a %s.", ReturnName(playerid), FormatNumber(price), prodname);
						GiveMoney(playerid, -price);
						BizData[bid][bizStock]--;
					}
					if(listitem == 1)
					{
						if(GetEnergy(playerid) >= 100)
							return SendErrorMessage(playerid, "Your energy is already full!");

						PlayerData[playerid][pEnergy] += 40;
						SendNearbyMessage(playerid, 20.0, COLOR_PURPLE, "* %s has paid %s and purchased a %s.", ReturnName(playerid), FormatNumber(price), prodname);
						GiveMoney(playerid, -price);
						BizData[bid][bizStock]--;
					}
					if(listitem == 2)
					{
						if(GetEnergy(playerid) >= 100)
							return SendErrorMessage(playerid, "Your energy is already full!");

						PlayerData[playerid][pEnergy] += 15;
						SendNearbyMessage(playerid, 20.0, COLOR_PURPLE, "* %s has paid %s and purchased a %s.", ReturnName(playerid), FormatNumber(price), prodname);
						GiveMoney(playerid, -price);
						BizData[bid][bizStock]--;
					}
				}
				case 2:
				{
					if(listitem == 0)
					{
						Inventory_Add(playerid, "Snack", 2768, 1);
						SendNearbyMessage(playerid, 20.0, COLOR_PURPLE, "* %s has paid %s and purchased a %s.", ReturnName(playerid), FormatNumber(price), prodname);
						GiveMoney(playerid, -price);
						BizData[bid][bizStock]--;
					}
					if(listitem == 1)
					{
						Inventory_Add(playerid, "Water", 2958, 1);
						SendNearbyMessage(playerid, 20.0, COLOR_PURPLE, "* %s has paid %s and purchased a %s.", ReturnName(playerid), FormatNumber(price), prodname);
						GiveMoney(playerid, -price);
						BizData[bid][bizStock]--;
					}
					if(listitem == 2)
					{
						Inventory_Add(playerid, "Mask", 19036, 1);
						SendNearbyMessage(playerid, 20.0, COLOR_PURPLE, "* %s has paid %s and purchased a %s.", ReturnName(playerid), FormatNumber(price), prodname);
						GiveMoney(playerid, -price);
						BizData[bid][bizStock]--;
					}
					if(listitem == 3)
					{
						Inventory_Add(playerid, "Medkit", 1580, 1);
						SendNearbyMessage(playerid, 20.0, COLOR_PURPLE, "* %s has paid %s and purchased a %s.", ReturnName(playerid), FormatNumber(price), prodname);
						GiveMoney(playerid, -price);
						BizData[bid][bizStock]--;
					}
				}
				case 3:
				{
					new gstr[1012];
					if(PlayerData[playerid][pGender] == 1)
					{
						forex(i, sizeof(g_aMaleSkins))
						{
							format(gstr, sizeof(gstr), "%s%i\n", gstr, g_aMaleSkins[i]);
						}
						Dialog_Show(playerid, DIALOG_BUYSKINS, DIALOG_STYLE_PREVIEW_MODEL, "Purchase Clothes", gstr, "Select", "Close");
					}
					else
					{
						forex(i, sizeof(g_aFemaleSkins))
						{
							format(gstr, sizeof(gstr), "%s%i\n", gstr, g_aFemaleSkins[i]);
						}
						Dialog_Show(playerid, DIALOG_BUYSKINS, DIALOG_STYLE_PREVIEW_MODEL, "Purchase Clothes", gstr, "Select", "Close");
					}
				}
				case 4:
				{
					if(listitem == 0)
					{
						if(PlayerHasItem(playerid, "Cellphone"))
							return SendErrorMessage(playerid, "Kamu sudah memiliki Cellphone!");
							
						PlayerData[playerid][pPhoneNumber] = PlayerData[playerid][pID]+RandomEx(13158, 98942);
						Inventory_Add(playerid, "Cellphone", 18867, 1);
						SendNearbyMessage(playerid, 20.0, COLOR_PURPLE, "* %s has paid %s and purchased a %s.", ReturnName(playerid), FormatNumber(price), prodname);
						GiveMoney(playerid, -price);
						BizData[bid][bizStock]--;
					}
					if(listitem == 1)
					{
						if(PlayerHasItem(playerid, "GPS"))
							return SendErrorMessage(playerid, "Kamu sudah memiliki GPS!");

						Inventory_Add(playerid, "GPS", 18875, 1);
						SendNearbyMessage(playerid, 20.0, COLOR_PURPLE, "* %s has paid %s and purchased a %s.", ReturnName(playerid), FormatNumber(price), prodname);
						GiveMoney(playerid, -price);
						BizData[bid][bizStock]--;
					}
					if(listitem == 2)
					{
						if(PlayerHasItem(playerid, "Portable Radio"))
							return SendErrorMessage(playerid, "Kamu sudah memiliki Portable Radio!");

						Inventory_Add(playerid, "Portable Radio", 19942, 1);
						SendNearbyMessage(playerid, 20.0, COLOR_PURPLE, "* %s has paid %s and purchased a %s.", ReturnName(playerid), FormatNumber(price), prodname);
						GiveMoney(playerid, -price);
						BizData[bid][bizStock]--;
					}
					if(listitem == 3)
					{
						PlayerData[playerid][pCredit] += 50;
						SendNearbyMessage(playerid, 20.0, COLOR_PURPLE, "* %s has paid %s and purchased a %s.", ReturnName(playerid), FormatNumber(price), prodname);
						GiveMoney(playerid, -price);
						BizData[bid][bizStock]--;
					}
				}
			}
		}
	}
	return true;
}

Dialog:DIALOG_BUYSKINS(playerid, response, listitem, inputtext[])
{
	if(response)
	{
		GiveMoney(playerid, -PlayerData[playerid][pSkinPrice]);
		SendNearbyMessage(playerid, 20.0, COLOR_PURPLE, "* %s has paid %s and purchased a %s.", ReturnName(playerid), FormatNumber(PlayerData[playerid][pSkinPrice]), ProductName[PlayerData[playerid][pInBiz]][0]);
		BizData[PlayerData[playerid][pInBiz]][bizStock]--;
		if(PlayerData[playerid][pGender] == 1)
		{
			UpdatePlayerSkin(playerid, g_aMaleSkins[listitem]);
		}
		else
		{
			UpdatePlayerSkin(playerid, g_aFemaleSkins[listitem]);
		}
	}
	return true;
}

//Rental
Dialog:DIALOG_RENTAL(playerid, response, listitem, inputtext[])
{
	if(response)
	{
		new rentid = PlayerData[playerid][pRenting];
		if(GetMoney(playerid) < RentData[rentid][rentPrice][listitem])
			return SendErrorMessage(playerid, "Kamu tidak memiliki cukup uang!");
			
		new str[256];
		format(str, sizeof(str), "{FFFFFF}Berapa jam kamu ingin menggunakan kendaraan Rental ini ?\n{FFFFFF}Maksimal adalah {FFFF00}4 jam\n\n{FFFFFF}Harga per Jam: {009000}$%d", RentData[rentid][rentPrice][listitem]);
		Dialog_Show(playerid, DIALOG_RENTTIME, DIALOG_STYLE_INPUT, "{FFFFFF}Rental Time", str, "Rental", "Close");
		PlayerData[playerid][pListitem] = listitem;
	}
	return true;
}

Dialog:DIALOG_RENTTIME(playerid, response, listitem, inputtext[])
{
	if(response)
	{
		new id = PlayerData[playerid][pRenting];
		new slot = PlayerData[playerid][pListitem];
		new time = strval(inputtext);
		if(time < 1 || time > 4)
		{
			new str[256];
			format(str, sizeof(str), "{FFFFFF}Berapa jam kamu ingin menggunakan kendaraan Rental ini ?\n{FFFFFF}Maksimal adalah {FFFF00}4 jam\n\n{FFFFFF}Harga per Jam: {009000}$%d", RentData[id][rentPrice][listitem]);
			Dialog_Show(playerid, DIALOG_RENTTIME, DIALOG_STYLE_INPUT, "{FFFFFF}Rental Time", str, "Rental", "Close");
			return true;
		}
		GiveMoney(playerid, -RentData[id][rentPrice][slot] * time);
		SendClientMessageEx(playerid, COLOR_SERVER, "RENTAL: {FFFFFF}Kamu telah menyewa {00FFFF}%s {FFFFFF}untuk %d Jam seharga {009000}$%d", GetVehicleModelName(RentData[id][rentModel][slot]), time, RentData[id][rentPrice][slot] * time);
		VehicleRental_Create(PlayerData[playerid][pID], RentData[id][rentModel][slot], RentData[id][rentSpawn][0], RentData[id][rentSpawn][1], RentData[id][rentSpawn][2], RentData[id][rentSpawn][3], time*3600, PlayerData[playerid][pRenting]);
	}
	return true;
}

//Dialog Inventory
Dialog:DIALOG_DROPITEM(playerid, response, listitem, inputtext[])
{
	if(response)
	{
		new
			itemid = PlayerData[playerid][pListitem],
			string[32],
			str[356];

		strunpack(string, InventoryData[playerid][itemid][invItem]);

		if (response)
		{
			if (isnull(inputtext))
				return format(str, sizeof(str), "Drop Item", "Item: %s - Quantity: %d\n\nPlease specify how much of this item you wish to drop:", string, InventoryData[playerid][itemid][invQuantity]),
				Dialog_Show(playerid, DIALOG_DROPITEM, DIALOG_STYLE_INPUT, "Drop Item", str, "Drop", "Cancel");

			if (strval(inputtext) < 1 || strval(inputtext) > InventoryData[playerid][itemid][invQuantity])
				return format(str, sizeof(str), "ERROR: Insufficient amount specified.\n\nItem: %s - Quantity: %d\n\nPlease specify how much of this item you wish to drop:", string, InventoryData[playerid][itemid][invQuantity]),
				Dialog_Show(playerid, DIALOG_DROPITEM, DIALOG_STYLE_INPUT, "Drop Item", str, "Drop", "Cancel");

			DropPlayerItem(playerid, itemid, strval(inputtext));
		}
	}
	return true;
}

Dialog:DIALOG_GIVEITEM(playerid, response, listitem, inputtext[])
{
	if (response)
	{
		static
			userid = -1,
			itemid = -1,
			string[32];

		if (sscanf(inputtext, "u", userid))
			return Dialog_Show(playerid, DIALOG_GIVEITEM, DIALOG_STYLE_INPUT, "Give Item", "Please enter the name or the ID of the player:", "Submit", "Cancel");

		if (userid == INVALID_PLAYER_ID)
			return Dialog_Show(playerid, DIALOG_GIVEITEM, DIALOG_STYLE_INPUT, "Give Item", "ERROR: Invalid player specified.\n\nPlease enter the name or the ID of the player:", "Submit", "Cancel");

		if (!IsPlayerNearPlayer(playerid, userid, 6.0))
			return Dialog_Show(playerid, DIALOG_GIVEITEM, DIALOG_STYLE_INPUT, "Give Item", "ERROR: You are not near that player.\n\nPlease enter the name or the ID of the player:", "Submit", "Cancel");

		if (userid == playerid)
			return Dialog_Show(playerid, DIALOG_GIVEITEM, DIALOG_STYLE_INPUT, "Give Item", "ERROR: You can't give items to yourself.\n\nPlease enter the name or the ID of the player:", "Submit", "Cancel");

		itemid = PlayerData[playerid][pListitem];

		if (itemid == -1)
			return false;

		strunpack(string, InventoryData[playerid][itemid][invItem]);

		if (InventoryData[playerid][itemid][invQuantity] == 1)
		{
			new id = Inventory_Add(userid, string, InventoryData[playerid][itemid][invModel]);

			if (id == -1)
				return SendErrorMessage(playerid, "That player doesn't have anymore inventory slots.");

			SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "* %s takes out a \"%s\" and gives it to %s.", ReturnName(playerid), string, ReturnName(userid));
			SendServerMessage(userid, "%s has given you \"%s\" (added to inventory).", ReturnName(playerid), string);

			Inventory_Remove(playerid, string);
			//Log_Write("logs/give_log.txt", "[%s] %s (%s) has given a %s to %s (%s).", ReturnDate(), ReturnName(playerid), PlayerData[playerid][pIP], string, ReturnName(userid, 0), PlayerData[userid][pIP]);
		}
		else
		{
			new str[152];
			format(str, sizeof(str), "Item: %s (Amount: %d)\n\nPlease enter the amount of this item you wish to give %s:", string, InventoryData[playerid][itemid][invQuantity], ReturnName(userid));
			Dialog_Show(playerid, DIALOG_GIVEAMOUNT, DIALOG_STYLE_INPUT, "Give Item", str, "Give", "Cancel");
			PlayerData[playerid][pTarget] = userid;
		}
	}
	return true;
}

Dialog:DIALOG_GIVEAMOUNT(playerid, response, listitem, inputtext[])
{
	if (response && PlayerData[playerid][pTarget] != INVALID_PLAYER_ID)
	{
		new
			userid = PlayerData[playerid][pTarget],
			itemid = PlayerData[playerid][pListitem],
			string[32],
			str[352];

		strunpack(string, InventoryData[playerid][itemid][invItem]);

		if (isnull(inputtext))
			return format(str, sizeof(str), "Item: %s (Amount: %d)\n\nPlease enter the amount of this item you wish to give %s:", string, InventoryData[playerid][itemid][invQuantity], ReturnName(userid)),
			Dialog_Show(playerid, DIALOG_GIVEAMOUNT, DIALOG_STYLE_INPUT, "Give Item", str, "Give", "Cancel");

		if (strval(inputtext) < 1 || strval(inputtext) > InventoryData[playerid][itemid][invQuantity])
			return format(str, sizeof(str), "ERROR: You don't have that much.\n\nItem: %s (Amount: %d)\n\nPlease enter the amount of this item you wish to give %s:", string, InventoryData[playerid][itemid][invQuantity], ReturnName(userid)),
			Dialog_Show(playerid, DIALOG_GIVEAMOUNT, DIALOG_STYLE_INPUT, "Give Item", str, "Give", "Cancel");

		new id = Inventory_Add(userid, string, InventoryData[playerid][itemid][invModel], strval(inputtext));

		if (id == -1)
			return SendErrorMessage(playerid, "That player doesn't have anymore inventory slots.");

		SendNearbyMessage(playerid, 30.0, COLOR_PURPLE, "* %s takes out a \"%s\" and gives it to %s.", ReturnName(playerid), string, ReturnName(userid));
		SendServerMessage(userid, "%s has given you \"%s\" (added to inventory).", ReturnName(playerid), string);

		Inventory_Remove(playerid, string, strval(inputtext));
		//  Log_Write("logs/give_log.txt", "[%s] %s (%s) has given %d %s to %s (%s).", ReturnDate(), ReturnName(playerid), PlayerData[playerid][pIP], strval(inputtext), string, ReturnName(userid, 0), PlayerData[userid][pIP]);
	}
	return true;
}

Dialog:DIALOG_INVACTION(playerid, response, listitem, inputtext[])
{
	if(response)
	{
		new
			itemid = PlayerData[playerid][pListitem],
			string[64],
			str[256];

		strunpack(string, InventoryData[playerid][itemid][invItem]);

		switch (listitem)
		{
			case 0:
			{
				CallLocalFunction("OnPlayerUseItem", "dds", playerid, itemid, string);
			}
			case 1:
			{
				if(!strcmp(string, "Cellphone"))
					return SendErrorMessage(playerid, "You can't do that on this item!");

				if(!strcmp(string, "GPS"))
					return SendErrorMessage(playerid, "You can't do that on this item!");
					
				PlayerData[playerid][pListitem] = itemid;
				Dialog_Show(playerid, DIALOG_GIVEITEM, DIALOG_STYLE_INPUT, "Give Item", "Please enter the name or the ID of the player:", "Submit", "Cancel");
			}
			case 2:
			{
				if (IsPlayerInAnyVehicle(playerid))
					return SendErrorMessage(playerid, "You can't drop items right now.");

				if(!strcmp(string, "Cellphone"))
					return SendErrorMessage(playerid, "You can't do that on this item!");

				if(!strcmp(string, "GPS"))
					return SendErrorMessage(playerid, "You can't do that on this item!");

				else if (InventoryData[playerid][itemid][invQuantity] == 1)
					DropPlayerItem(playerid, itemid);

				else
					format(str, sizeof(str), "Item: %s - Quantity: %d\n\nPlease specify how much of this item you wish to drop:", string, InventoryData[playerid][itemid][invQuantity]),
					Dialog_Show(playerid, DIALOG_DROPITEM, DIALOG_STYLE_INPUT, "Drop Item", str, "Drop", "Cancel");
			}
		}
	}
	return true;
}

Dialog:DIALOG_INVENTORY(playerid, response, listitem, inputtext[])
{
	if(response)
	{
		new
			name[48];

		strunpack(name, InventoryData[playerid][listitem][invItem]);
		PlayerData[playerid][pListitem] = listitem;

		switch (PlayerData[playerid][pStorageSelect])
		{
			case 0:
			{
				format(name, sizeof(name), "%s (%d)", name, InventoryData[playerid][listitem][invQuantity]);
				Dialog_Show(playerid, DIALOG_INVACTION, DIALOG_STYLE_LIST, name, "Use Item\nGive Item\nDrop Item", "Select", "Cancel");
			}
		}
	}
	return true;
}

//House And Furniture Dialog
Dialog:DIALOG_FURNITURE_BUY(playerid, response, listitem, inputtext[])
{
	if(response)
	{
		new
			items[50] = {-1, ...},
			count;

		for (new i = 0; i < sizeof(g_aFurnitureData); i ++) if (g_aFurnitureData[i][e_FurnitureType] == listitem + 1) {
			items[count++] = g_aFurnitureData[i][e_FurnitureModel];
		}
		PlayerData[playerid][pListitem] = listitem;

		if (listitem == 3) {
			ShowModelSelectionMenu(playerid, "Furniture", MODEL_SELECTION_FURNITURE, items, count, -12.0, 0.0, 0.0);
		}
		else {
			ShowModelSelectionMenu(playerid, "Furniture", MODEL_SELECTION_FURNITURE, items, count);
		}
	}
	return true;
}

Dialog:DIALOG_FURNITURE_MENU(playerid, response, listitem, inputtext[])
{
	new id = PlayerData[playerid][pEditing];

	if(response)
	{
		if(listitem == 0)
		{
			Furniture_Delete(id);

			SendServerMessage(playerid, "You have successfully removed the furniture!");

			cmd_house(playerid, "menu");
		}
		if(listitem == 1)
		{
			if(House_Inside(playerid) != -1 && House_IsOwner(playerid, House_Inside(playerid)))
			{
				if(Iter_Contains(Furniture, id))
				{
					PlayerData[playerid][pEditType] = EDIT_FURNITURE;

					EditDynamicObject(playerid, FurnitureData[id][furnitureObject]);

					SendServerMessage(playerid, "You are not in editing mode of furniture index id: %d", id);
				}
			}
		}
		if(listitem == 2)
		{
			ShowEditTextDraw(playerid);

			SendServerMessage(playerid, "You are now in editing mode of furniture index id: %d", id);

		}
	}
	return true;
}

Dialog:DIALOG_FURNITURE_LIST(playerid, response, listitem, inputtext[])
{
	if(response)
	{
		if(House_Inside(playerid) != -1 && House_IsOwner(playerid, House_Inside(playerid)))
		{
			PlayerData[playerid][pEditing] = ListedFurniture[playerid][listitem];

			Dialog_Show(playerid, DIALOG_FURNITURE_MENU, DIALOG_STYLE_LIST, "Furniture Option(s)", "Remove furniture\nEdit position (click n drag)\nEdit position (click textdraw)", "Select", "Close");
		}
	}
	return true;
}

Dialog:DIALOG_FURNITURE(playerid, response, listitem, inputtext[])
{
	if(response)
	{
		if(listitem == 0)
		{
			new count = 0, string[MAX_FURNITURE * 32], houseid = House_Inside(playerid);
			format(string, sizeof(string), "Model Name\tModel ID\tDistance\n");
			foreach(new i : Furniture) if (FurnitureData[i][furnitureHouse] == houseid)
			{
				ListedFurniture[playerid][count++] = i;
				format(string, sizeof(string), "%s%s\t%d\t%.2f meters\n", string, FurnitureData[i][furnitureName], FurnitureData[i][furnitureModel], GetPlayerDistanceFromPoint(playerid, FurnitureData[i][furniturePos][0], FurnitureData[i][furniturePos][1], FurnitureData[i][furniturePos][2]));
			}
			if (count)
			{
				Dialog_Show(playerid, DIALOG_FURNITURE_LIST, DIALOG_STYLE_TABLIST_HEADERS, "Furniture List", string, "Select", "Cancel");
			}
			else SendErrorMessage(playerid, "There is no furniture on this house!"), cmd_house(playerid, "menu");
		}
		if(listitem == 1)
		{
			if(Furniture_GetCount(House_Inside(playerid)) >= 30)
				return SendErrorMessage(playerid, "You only can place 30 furniture per house!"), cmd_house(playerid, "menu");

			new str[312];

			str[0] = 0;

			for (new i = 0; i < sizeof(g_aFurnitureTypes); i ++) {
				format(str, sizeof(str), "%s%s - $%s\n", str, g_aFurnitureTypes[i], FormatNumber(Furniture_ReturnPrice(i)));
			}
			Dialog_Show(playerid, DIALOG_FURNITURE_BUY, DIALOG_STYLE_LIST, "Purchase Furniture", str, "Select", "Close");
		}
		if(listitem == 3)
		{
			if(Furniture_GetCount(House_Inside(playerid)) < 1)
				return SendErrorMessage(playerid, "There is no furniture on your house!"), cmd_house(playerid, "menu");

			foreach(new i : Furniture) if(FurnitureData[i][furnitureHouse] == House_Inside(playerid))
			{
				Furniture_Delete(i);
			}
			SendServerMessage(playerid, "You have removed all furniture on this house!");
			cmd_house(playerid, "menu");
		}
	}
	return true;
}

Dialog:DIALOG_HOUSE_MENU(playerid, response, listitem, inputtext[])
{
	if(response)
	{
		if(listitem == 0)
		{
			Dialog_Show(playerid, DIALOG_FURNITURE, DIALOG_STYLE_LIST, "House Furniture", "Furniture list\nPurchase furniture\nRemove all furniture", "Select", "Close");
		}
		if(listitem == 1)
		{
			House_OpenStorage(playerid, House_Inside(playerid));
		}
	}
	return true;
}

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
	if(newkeys & KEY_YES)
	{
	    if(GetPlayerState(playerid) != PLAYER_STATE_DRIVER)
	    {
			cmd_inventory(playerid, "");
		}
	}
	if((newkeys & KEY_SECONDARY_ATTACK ))
	{
		return cmd_enter(playerid, "");
	}
	return true;
}

public OnPlayerSpawn(playerid)
{
	if(!PlayerData[playerid][pSpawned])
	{
	    PlayerData[playerid][pSpawned] = true;
	    GivePlayerMoney(playerid, PlayerData[playerid][pMoney]);
	    SetPlayerHealth(playerid, PlayerData[playerid][pHealth]);
	    SetPlayerSkin(playerid, PlayerData[playerid][pSkin]);
	    SetPlayerVirtualWorld(playerid, PlayerData[playerid][pWorld]);
		SetPlayerInterior(playerid, PlayerData[playerid][pInterior]);
		PlayerTextDrawShow(playerid, ENERGYTD[playerid][0]);
		PlayerTextDrawShow(playerid, ENERGYTD[playerid][1]);
		ENERGYBAR[playerid] = CreatePlayerProgressBar(playerid, 539.000000, 158.000000, 69.500000, 9.000000, 9109759, 100.000000, BAR_DIRECTION_RIGHT);
	}
	return true;
}

public OnPlayerEditDynamicObject(playerid, STREAMER_TAG_OBJECT:objectid, response, Float:x, Float:y, Float:z, Float:rx, Float:ry, Float:rz)
{
	new id = PlayerData[playerid][pEditing];
	if(response == EDIT_RESPONSE_FINAL)
	{
		if(PlayerData[playerid][pEditing] != -1)
		{
			if(PlayerData[playerid][pEditType] == EDIT_FURNITURE)
			{
				FurnitureData[id][furniturePos][0] = x;
				FurnitureData[id][furniturePos][1] = y;
				FurnitureData[id][furniturePos][2] = z;

				FurnitureData[id][furnitureRot][0] = rx;
				FurnitureData[id][furnitureRot][1] = ry;
				FurnitureData[id][furnitureRot][2] = rz;

				Furniture_Save(id);
				Furniture_Refresh(id);

				SendServerMessage(playerid, "You have successfully editing furniture ID: %d", id);
			}
		}
		PlayerData[playerid][pEditing] = -1;
		PlayerData[playerid][pEditType] = EDIT_NONE;
	}
	if(response == EDIT_RESPONSE_CANCEL)
	{
		if(PlayerData[playerid][pEditType] == EDIT_FURNITURE)
			Furniture_Refresh(id);

		PlayerData[playerid][pEditType] = EDIT_NONE;

	}
	return true;
}


public OnPlayerText(playerid, text[])
{
	if(PlayerData[playerid][pCalling] != INVALID_PLAYER_ID)
	{
		new lstr[1024];
		format(lstr, sizeof(lstr), "(Phone) %s says: %s", ReturnName(playerid), text);
		ProxDetector(10, playerid, lstr, 0xE6E6E6E6, 0xC8C8C8C8, 0xAAAAAAAA, 0x8C8C8C8C, 0x6E6E6E6E);
		SetPlayerChatBubble(playerid, text, COLOR_WHITE, 10.0, 3000);

		SendClientMessageEx(PlayerData[playerid][pCalling], COLOR_YELLOW, "(Phone) Caller says: %s", text);
		return false;
	}
	else
	{
		new lstr[1024];
		format(lstr, sizeof(lstr), "%s says: %s", ReturnName(playerid), text);
		ProxDetector(10, playerid, lstr, 0xE6E6E6E6, 0xC8C8C8C8, 0xAAAAAAAA, 0x8C8C8C8C, 0x6E6E6E6E);
		SetPlayerChatBubble(playerid, text, COLOR_WHITE, 10.0, 3000);

		return false;
	}
}

public OnVehicleSpawn(vehicleid)
{
	forex(i, MAX_PLAYER_VEHICLE)if(VehicleData[i][vExists])
	{
		if(vehicleid == VehicleData[i][vVehicle] && IsValidVehicle(VehicleData[i][vVehicle]))
		{
		    if(VehicleData[i][vRental] == -1)
		    {
				if(VehicleData[i][vInsurance] > 0)
	    		{
					VehicleData[i][vInsurance] --;
					VehicleData[i][vInsuTime] = gettime() + (1 * 86400);
					foreach(new pid : Player) if (VehicleData[i][vOwner] == PlayerData[pid][pID])
	        		{
	            		SendServerMessage(pid, "Kendaraan {00FFFF}%s {FFFFFF}milikmu telah hancur, kamu bisa Claim setelah 24 jam dari Insurance.", GetVehicleName(vehicleid));
					}

					if(IsValidVehicle(VehicleData[i][vVehicle]))
						DestroyVehicle(VehicleData[i][vVehicle]);

					VehicleData[i][vVehicle] = INVALID_VEHICLE_ID;
				}
				else
				{
					foreach(new pid : Player) if (VehicleData[i][vOwner] == PlayerData[pid][pID])
	        		{
	            		SendServerMessage(pid, "Kendaraan {00FFFF}%s {FFFFFF}milikmu telah hancur dan tidak akan dan tidak memiliki Insurance lagi.", GetVehicleName(vehicleid));
					}
					
					new query[128];
					mysql_format(sqlcon, query, sizeof(query), "DELETE FROM vehicle WHERE vehID = '%d'", VehicleData[i][vID]);
					mysql_query(sqlcon, query, true);

                    VehicleData[i][vExists] = false;
                    
					if(IsValidVehicle(VehicleData[i][vVehicle]))
						DestroyVehicle(VehicleData[i][vVehicle]);
				}
			}
			else
			{
				foreach(new pid : Player) if (VehicleData[i][vOwner] == PlayerData[pid][pID])
        		{
        		    GiveMoney(pid, -250);
            		SendServerMessage(pid, "Kendaraan Rental milikmu (%s) telah hancur, kamu dikenai denda sebesar {009000}$250!", GetVehicleName(vehicleid));
				}

				new query[128];
				mysql_format(sqlcon, query, sizeof(query), "DELETE FROM vehicle WHERE vehID = '%d'", VehicleData[i][vID]);
				mysql_query(sqlcon, query, true);

                VehicleData[i][vExists] = false;

				if(IsValidVehicle(VehicleData[i][vVehicle]))
					DestroyVehicle(VehicleData[i][vVehicle]);
			}
		}
	}
	return true;
}

/*
	    case 1: str = "Fast Food";
	    case 2: str = "24/7";
	    case 3: str = "Clothes";
*/

/* » Server Timer */

ptask EnergyUpdate[30000](playerid)
{
	if(PlayerData[playerid][pEnergy] > 0)
	{
	    PlayerData[playerid][pEnergy]--;
	}
	return true;
}

task RentalUpdate[1000]()
{
	forex(i, MAX_PLAYER_VEHICLE) if(VehicleData[i][vExists] && VehicleData[i][vRental] != -1)
	{
	    if(VehicleData[i][vRentTime] > 0)
	    {
	        VehicleData[i][vRentTime]--;
	        if(VehicleData[i][vRentTime] <= 0)
	        {
	            foreach(new playerid : Player) if(VehicleData[i][vOwner] == PlayerData[playerid][pID])
	            {
	            	SendClientMessageEx(playerid, COLOR_SERVER, "RENTAL: {FFFFFF}Masa rental kendaraan %s telah habis, kendaraan otomatis dihilangkan.", GetVehicleModelName(VehicleData[i][vModel]));
				}
				Vehicle_Delete(i);
			}
		}
	}
	return true;
}

task VehicleUpdate[50000]()
{
	forex(i, MAX_VEHICLES) if (IsEngineVehicle(i) && GetEngineStatus(i))
	{
	    if (GetFuel(i) > 0)
	    {
	        VehCore[i][vehFuel]--;
			if (GetFuel(i) <= 0)
			{
			    VehCore[i][vehFuel] = 0;
	      		SwitchVehicleEngine(i, false);
	      		GameTextForPlayer(GetVehicleDriver(i), "Vehicle out of ~r~Fuel!", 3000, 5);
			}
		}
	}
	forex(i, MAX_PLAYER_VEHICLE) if(VehicleData[i][vExists])
	{
		if(VehicleData[i][vInsuTime] != 0 && VehicleData[i][vInsuTime] <= gettime())
		{
			VehicleData[i][vInsuTime] = 0;
		}
	}
	return true;
}
ptask PlayerUpdate[1000](playerid)
{
	if(PlayerData[playerid][pSpawned])
	{
		SetPlayerProgressBarValue(playerid, ENERGYBAR[playerid], PlayerData[playerid][pEnergy]);
		SetPlayerProgressBarColour(playerid, ENERGYBAR[playerid], ConvertHBEColor(PlayerData[playerid][pEnergy]));
		new vehicleid = GetPlayerVehicleID(playerid);
		if(GetPlayerState(playerid) == PLAYER_STATE_DRIVER)
		{
		    if(IsSpeedoVehicle(vehicleid))
		    {
		        new Float:vHP, vehname[64], speedtd[64], healthtd[64];
		        GetVehicleHealth(vehicleid, vHP);
		        format(healthtd, sizeof(healthtd), "%.1f", vHP);
		        PlayerTextDrawSetString(playerid, HEALTHTD[playerid], healthtd);

		        format(vehname, sizeof(vehname), "%s", GetVehicleName(vehicleid));
		        PlayerTextDrawSetString(playerid, VEHNAMETD[playerid], vehname);
		        
		        format(speedtd, sizeof(speedtd), "%iKM/H", GetVehicleSpeedKMH(vehicleid));
		        PlayerTextDrawSetString(playerid, KMHTD[playerid], speedtd);
		        
		        SetPlayerProgressBarValue(playerid, FUELBAR[playerid], VehCore[vehicleid][vehFuel]);
			}
		}
	}
	return true;
}
