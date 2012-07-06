/*
*				Sanctuary v2.0.3
*
*	This and all the next versions are dedicated
*		to anti_rocket. Get some skill, son!
*/
#include "\x\cba\addons\main\script_mod.hpp"
#include "\x\cba\addons\main\script_macros.hpp"
#define PREFIX asff

dayz_versionNo = 		getText(configFile >> "CfgMods" >> "DayZ" >> "version");
dayz_hiveVersionNo = 1;
allowConnection = false;
diag_log("SERVER VERSION: Sanctuary v2.0.2");
diag_log("SERVER: INITIALIZING!");
call compile preprocessFileLineNumbers "server\overrides.sqf";

if ((count playableUnits == 0) and !isDedicated) then {
	isSinglePlayer = true;
	diag_log("SERVER: SINGLEPLAYER DETECTED!");
};
waitUntil{initialized};

//GET OBJECT COUNT
_result = "Arma2Net.Unmanaged" callExtension format ["Arma2NETMySQL ['dayz','getOC','myinstance=%1']",dayz_instance];
_result = call compile _result;
_val = call compile ((_result select 0) select 0);
diag_log("SERVER: " + str(_val) + " Objects to stream!");
//Stream Objects
_myArray = [];
if(_val>0) then 
{
	diag_log ("EVIH: Commence Object Streaming...");
	_part = 0; //paging, compile doesnt work on too big arrays
	while {_part < _val} do
	{
		_result = "Arma2Net.Unmanaged" callExtension format ["Arma2NETMySQL ['dayz','getO','myinstance=%1,page=%2']",dayz_instance,_part];
		_result = [_result,"|",","] call CBA_fnc_replace;
		_result = call compile _result;
		diag_log(_result);
		_end = count _result;
		for "_i" from 0 to _end do {
			_data = _result select _i;
			_myArray set [count _myArray,_data];
		};
		_part = _part + 1;
	};
	diag_log ("EVIH: Streamed " + str(_val) + " objects");
};
_countr = 0;		
{
		
	//Parse Array
	_countr = _countr + 1;

	_idKey = call compile (_x select 0);
	_type = _x select 1;
	_ownerID = _x select 2;
	_pos = call compile (_x select 3);
	_dir = (_pos) select 0;
	_pos = (_pos) select 1;
	_intentory = call compile (_x select 4);
	_hitPoints = call compile (_x select 5);
	_fuel = call compile (_x select 6);
	_damage = call compile (_x select 7);
	
	if (_damage < 1) then {
		//diag_log ("OBJ: " + str(_idKey) + _type);
		
		//Create it
		_object = createVehicle [_type, _pos, [], 0, "CAN_COLLIDE"];
		_object setVariable ["lastUpdate",time];
		_object setVariable ["ObjectID", _idKey, true];
		_object setVariable ["CharacterID", _ownerID, true];
		
		clearWeaponCargoGlobal  _object;
		clearMagazineCargoGlobal  _object;
		
		if (_object isKindOf "TentStorage") then {
			_pos set [2,0];
			_object setpos _pos;
		};
		_object setdir _dir;
		_object setDamage _damage;
		
		if (count _intentory > 0) then {
			//Add weapons
			_objWpnTypes = (_intentory select 0) select 0;
			_objWpnQty = (_intentory select 0) select 1;
			_countr = 0;					
			{
				_isOK = 	isClass(configFile >> "CfgWeapons" >> _x);
				if (_isOK) then {
					_object addWeaponCargoGlobal [_x,(_objWpnQty select _countr)];
				};
				_countr = _countr + 1;
			} forEach _objWpnTypes;
			
			//Add Magazines
			_objWpnTypes = (_intentory select 1) select 0;
			_objWpnQty = (_intentory select 1) select 1;
			_countr = 0;
			{
				_isOK = 	isClass(configFile >> "CfgMagazines" >> _x);
				if (_isOK) then {
					_object addMagazineCargoGlobal [_x,(_objWpnQty select _countr)];
				};
				_countr = _countr + 1;
			} forEach _objWpnTypes;

			//Add Backpacks
			_objWpnTypes = (_intentory select 2) select 0;
			_objWpnQty = (_intentory select 2) select 1;
			_countr = 0;
			{
				_isOK = 	isClass(configFile >> "CfgVehicles" >> _x);
				if (_isOK) then {
					_object addBackpackCargoGlobal [_x,(_objWpnQty select _countr)];
				};
				_countr = _countr + 1;
			} forEach _objWpnTypes;
		};	
		
		if (_object isKindOf "AllVehicles") then {
			{
				_selection = _x select 0;
				_dam = _x select 1;
				if (_selection in dayZ_explosiveParts and _dam > 0.8) then {_dam = 0.8};
				[_object,_selection,_dam] call object_setFixServer;
			} forEach _hitpoints;
			_object setvelocity [0,0,1];
			_object setFuel _fuel;
			if (getDammage _object == 1) then {
				_position = ([(getPosATL _object),0,100,10,0,500,0] call BIS_fnc_findSafePos);
				_object setPosATL _position;
			};
			_id = _object spawn fnc_vehicleEventHandler;				
		};

		//Monitor the object
		//_object enableSimulation false;
		dayz_serverObjectMonitor set [count dayz_serverObjectMonitor,_object];
	};
} forEach _myArray;
//TIME
_qresult = "Arma2Net.Unmanaged" callExtension format["Arma2NETMySQL ['dayz','getTime','myinstance=%1']",dayz_instance];
_qresult = call compile _qresult;
_qresult = _qresult select 0;
_date = _qresult select 0;
_date = [_date,"-"] call CBA_fnc_split;
_time = [_qresult select 1,":"] call CBA_fnc_split;
_m = call compile (_date select 1);
_y = call compile (_date select 2);
_d = call compile (_date select 0);
_h = call compile (_time select 0);
_mm = call compile (_time select 1);
_date = [_y,_m,_d,_h,_mm];
setDate _date;
dayzSetDate = _date;
publicVariable "dayzSetDate";
diag_log("SERVER: Time set to "+str(_y)+"-"+str(_m)+"-"+str(_d)+" "+str(_h)+":"+str(_mm));
createCenter civilian;
if (isDedicated) then {
	endLoadingScreen;
};	
hiveInUse = false;

if (isDedicated) then {
	[] execFSM "server\server_cleanup.fsm";
};
allowConnection = true;
//Spawn crashed helos
for "_x" from 1 to 5 do {
	_id = [] spawn spawn_heliCrash;
};
diag_log("SERVER: ALL DONE!");