/*  SM Be a Santa Claus
 *
 *  Copyright (C) 2017 Francisco 'Franc1sco' García
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "1.1"

#define	DAMAGE_NO				0
#define	DAMAGE_YES				2

new gSmoke1;
new gHaloS;
new gGlow1;
new gLaser1;

new bool:g_Santa[MAXPLAYERS+1] = {false, ...};
new g_Regalos[MAXPLAYERS+1] = 0;

new Handle:cvar_vida = INVALID_HANDLE;
new Handle:cvar_ataque = INVALID_HANDLE;
new Handle:cvar_damage = INVALID_HANDLE;
new Handle:cvar_implode = INVALID_HANDLE;
new Handle:cvar_weapons = INVALID_HANDLE;
new Handle:cvar_explosion = INVALID_HANDLE;
new Handle:cvar_speed = INVALID_HANDLE;

new Handle:g_CVarAdmFlag;
new g_AdmFlag;

public Plugin:myinfo =
{
	name = "SM Be a Santa Claus",
	author = "Franc1sco Steam: franug",
	description = "for Christmas",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/franug"
};

public OnPluginStart()
{
	CreateConVar("sm_santaclaus_version", PLUGIN_VERSION, "version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	RegConsoleCmd("sm_santa", besanta);
	
	HookEvent("player_spawn", PlayerSpawn);
	HookEvent("weapon_fire", EventWeaponFire);

	cvar_vida = CreateConVar("sm_santaclaus_health", "500", "Health of Santa Claus");

	cvar_ataque = CreateConVar("sm_santaclaus_attack", "8.0", "Interval for drop gifts");

	cvar_damage = CreateConVar("sm_santaclaus_damage", "300", "Magnitude of explosive gifts");

	cvar_implode = CreateConVar("sm_santaclaus_implode", "1", "Enable implode effect. 0 = disable");

	cvar_weapons = CreateConVar("sm_santaclaus_weapons", "0", "Enable or disable that Santa Claus can use weapons. 1 = enable");

	cvar_explosion = CreateConVar("sm_santaclaus_explosiontime", "10.0", "time in secons to explode gifts if nobody touches it");

	cvar_speed = CreateConVar("sm_santaclaus_speed", "1.0", "Speed of Santa Claus. 1.0 = normal speed");

	g_CVarAdmFlag = CreateConVar("sm_santaclaus_adminflag", "z", "Admin flag required to use command. 0 = No flag needed. Can use a b c ....");

	HookConVarChange(g_CVarAdmFlag, CVarChange);
}

public CVarChange(Handle:convar, const String:oldValue[], const String:newValue[]) {

	g_AdmFlag = ReadFlagString(newValue);
}

public OnMapStart()
{
	AddFileToDownloadsTable("sound/santa/santa.mp3");
	PrecacheSound("santa/santa.mp3");

	PrecacheSound("weapons/physcannon/energy_disintegrate4.wav");

	gHaloS = PrecacheModel("materials/sprites/halo01.vmt");
	gGlow1 = PrecacheModel("sprites/blueglow2.vmt", true);
	gSmoke1 = PrecacheModel("materials/effects/fire_cloud1.vmt");
	gLaser1 = PrecacheModel("materials/sprites/laser.vmt");

	PrecacheModel("models/items/cs_gift.mdl");
	
	AddFileToDownloadsTable("materials/models/player/slow/santa_claus/slow_santa.vmt");
	AddFileToDownloadsTable("materials/models/player/slow/santa_claus/slow_santa.vtf");
	AddFileToDownloadsTable("materials/models/player/slow/santa_claus/slow_santa_bump.vtf");
	AddFileToDownloadsTable("materials/models/player/slow/santa_claus/slow_santa_cloth.vmt");
	AddFileToDownloadsTable("materials/models/player/slow/santa_claus/slow_santa_cloth.vtf");
	AddFileToDownloadsTable("materials/models/player/slow/santa_claus/slow_santa_detail.vtf");
	AddFileToDownloadsTable("models/player/slow/santa_claus/slow_fix.dx80.vtx");
	AddFileToDownloadsTable("models/player/slow/santa_claus/slow_fix.dx90.vtx");
	AddFileToDownloadsTable("models/player/slow/santa_claus/slow_fix.mdl");
	AddFileToDownloadsTable("models/player/slow/santa_claus/slow_fix.phy");
	AddFileToDownloadsTable("models/player/slow/santa_claus/slow_fix.sw.vtx");
	AddFileToDownloadsTable("models/player/slow/santa_claus/slow_fix.vvd");
	PrecacheModel("models/player/slow/santa_claus/slow_fix.mdl");
}


public Action:PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	g_Santa[client] = false;
	g_Regalos[client] = 0;
}

public Action:besanta(client, args)
{
	if ((g_AdmFlag > 0) && !CheckCommandAccess(client, "sm_santa", g_AdmFlag, true)) 
        {
			PrintToChat(client, "\x04[SM_SANTACLAUS] \x01You do not have access");
			return Plugin_Handled;
	}

	if(args < 1) // Not enough parameters
	{
		ReplyToCommand(client, "[SM] Use: sm_santa <#userid|name>");
		return Plugin_Handled;
	}


	decl String:strTarget[32]; GetCmdArg(1, strTarget, sizeof(strTarget)); 

	// Process the targets 
	decl String:strTargetName[MAX_TARGET_LENGTH]; 
	decl TargetList[MAXPLAYERS], TargetCount; 
	decl bool:TargetTranslate; 

	if ((TargetCount = ProcessTargetString(strTarget, client, TargetList, MAXPLAYERS, COMMAND_FILTER_CONNECTED, 
					strTargetName, sizeof(strTargetName), TargetTranslate)) <= 0) 
	{ 
		PrintToChat(client, "\x04[SM_SANTACLAUS] \x01client not found");
		return Plugin_Handled; 
	} 

	// Apply to all targets 
	for (new i = 0; i < TargetCount; i++) 
	{ 
		new iClient = TargetList[i]; 
		if (IsClientInGame(iClient) && IsPlayerAlive(iClient)) 
		{
			Santa(iClient);
			PrintToChat(client, "\x04[SM_SANTACLAUS] \x01Player %N has been converted in Santa Claus",iClient);
		} 
	}

	return Plugin_Handled;
}

Santa(client)
{
	g_Santa[client] = true;
	SetEntityHealth(client, GetConVarInt(cvar_vida));
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", GetConVarFloat(cvar_speed));
	//EmitSoundToAll("franug/santa.mp3");
	SetEntityModel(client, "models/player/slow/santa_claus/slow_fix.mdl");
	g_Regalos[client] += 1;						
						
		
	if(!GetConVarBool(cvar_weapons))
	{				
		new wepIdx;
						
		// strip all weapons
		for (new s = 0; s < 4; s++)
		{
			if ((wepIdx = GetPlayerWeaponSlot(client, s)) != -1)
			{
				RemovePlayerItem(client, wepIdx);
				RemoveEdict(wepIdx);
			}
		}
		GivePlayerItem(client, "weapon_knife");
	}
						
	if (GetClientTeam(client) == 3)
		SetEntityRenderColor(client, 0, 255, 0, 255);
						
	//PrintToChatAll("\x04[SM_Franug-JailPlugins] \x05Ha venido SANTA CLAUS!");					
}

public DrawIonBeam(Float:startPosition[3])
{
	decl Float:position[3];
	position[0] = startPosition[0];
	position[1] = startPosition[1];
	position[2] = startPosition[2] + 1500.0;	

	TE_SetupBeamPoints(startPosition, position, gLaser1, 0, 0, 0, 0.15, 25.0, 25.0, 0, 1.0, {0, 150, 255, 255}, 3 );
	TE_SendToAll();
	position[2] -= 1490.0;
	TE_SetupSmoke(startPosition, gSmoke1, 10.0, 2);
	TE_SendToAll();
	TE_SetupGlowSprite(startPosition, gGlow1, 1.0, 1.0, 255);
	TE_SendToAll();
}

stock env_shake(Float:Origin[3], Float:Amplitude, Float:Radius, Float:Duration, Float:Frequency)
{
	decl Ent;

	//Initialize:
	Ent = CreateEntityByName("env_shake");
		
	//Spawn:
	if(DispatchSpawn(Ent))
	{
		//Properties:
		DispatchKeyValueFloat(Ent, "amplitude", Amplitude);
		DispatchKeyValueFloat(Ent, "radius", Radius);
		DispatchKeyValueFloat(Ent, "duration", Duration);
		DispatchKeyValueFloat(Ent, "frequency", Frequency);

		SetVariantString("spawnflags 8");
		AcceptEntityInput(Ent,"AddOutput");

		//Input:
		AcceptEntityInput(Ent, "StartShake", 0);
		
		//Send:
		TeleportEntity(Ent, Origin, NULL_VECTOR, NULL_VECTOR);

		//Delete:
		RemoveEntity(Ent, 30.0);
	}
}


stock RemoveEntity(entity, Float:time = 0.0)
{
	if (time == 0.0)
	{
		if(IsValidEntity(entity))
		{
			new String:edictname[32];
			GetEdictClassname(entity, edictname, 32);

			if (StrEqual(edictname, "player"))
				KickClient(entity); // HaHa =D
			else
				AcceptEntityInput(entity, "kill");
		}
	}
	else
	{
		CreateTimer(time, RemoveEntityTimer, entity, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:RemoveEntityTimer(Handle:Timer, any:entity)
{
	if(IsValidEntity(entity))
		AcceptEntityInput(entity, "kill"); // RemoveEdict(entity);
	
	return (Plugin_Stop);
}

stock MineAttack(client)
{
	decl Float:cleyepos[3], Float:cleyeangle[3];
	
	GetClientEyePosition(client, cleyepos);
	GetClientEyeAngles(client, cleyeangle);

	new entity;
	entity = CreateEntityByName("hegrenade_projectile");

	
	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);
	DispatchSpawn(entity);
	
	setm_takedamage(entity, DAMAGE_YES);
	
	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);
	SetEntityModel(entity, "models/items/cs_gift.mdl");
	TeleportEntity(entity, cleyepos, cleyeangle, cleyeangle);

	SetEntProp(entity, Prop_Data, "m_iHealth", 1);
	
	CreateTimer(GetConVarFloat(cvar_explosion), StartMine, entity, TIMER_FLAG_NO_MAPCHANGE);
	
	SDKHook(entity, SDKHook_StartTouch, MineTouchHook);				
	SDKHook(entity, SDKHook_OnTakeDamage, MineDamageHook);
}

public Action:StartMine(Handle:Timer, any:entity)
{
	MineActive(entity);
}

public Action:MineTouchHook(entity, other)
{
	decl Float:entityposition[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entityposition);	
	
	new laserent = CreateEntityByName("point_tesla");
	DispatchKeyValue(laserent, "m_flRadius", "100.0");
	DispatchKeyValue(laserent, "m_SoundName", "DoSpark");
	DispatchKeyValue(laserent, "beamcount_min", "42");
	DispatchKeyValue(laserent, "beamcount_max", "62");
	DispatchKeyValue(laserent, "texture", "sprites/physbeam.vmt");
	DispatchKeyValue(laserent, "m_Color", "255 255 255");
	DispatchKeyValue(laserent, "thick_min", "10.0");
	DispatchKeyValue(laserent, "thick_max", "11.0");
	DispatchKeyValue(laserent, "lifetime_min", "0.3");
	DispatchKeyValue(laserent, "lifetime_max", "0.3");
	DispatchKeyValue(laserent, "interval_min", "0.1");
	DispatchKeyValue(laserent, "interval_max", "0.2");
	DispatchSpawn(laserent);
	
	TeleportEntity(laserent, entityposition, NULL_VECTOR, NULL_VECTOR);
	
	AcceptEntityInput(laserent, "TurnOn");  
	AcceptEntityInput(laserent, "DoSpark");    
		
	if(other != 0)
	{
		if(other == GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))
			return (Plugin_Continue);
		else if(!IsEntityCollidable(other, true, true, true))
			return (Plugin_Continue);
			
		MineActive(entity);
	}

	return (Plugin_Continue);
}

public Action:MineDamageHook(entity, &attacker, &inflictor, &Float:damage, &damagetype)
{
	MineActive(entity);
	
	return (Plugin_Handled);
}

stock MineActive(entity)
{
	SDKUnhook(entity, SDKHook_StartTouch, MineTouchHook);
	SDKUnhook(entity, SDKHook_OnTakeDamage, MineDamageHook);

	if(IsValidEntity(entity) && IsValidEdict(entity))
	{ 
		setm_takedamage(entity, DAMAGE_NO);
		decl Float:entityposition[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entityposition);
		new client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");

		AcceptEntityInput(entity, "Kill");
		
		DrawIonBeam(entityposition);
		TE_SetupBeamRingPoint(entityposition, 0.0, 500.0, gGlow1, gHaloS, 0, 0, 0.5, 10.0, 2.0, {255, 255, 255, 255}, 0, 0);
		TE_SendToAll();
		TE_SetupBeamRingPoint(entityposition, 0.0, 500.0, gGlow1, gHaloS, 0, 0, 0.7, 10.0, 2.0, {255, 255, 255, 255}, 0, 0);
		TE_SendToAll();
		TE_SetupBeamRingPoint(entityposition, 0.0, 500.0, gGlow1, gHaloS, 0, 0, 0.9, 10.0, 2.0, {255, 255, 255, 255}, 0, 0);
		TE_SendToAll();
		TE_SetupBeamRingPoint(entityposition, 0.0, 500.0, gGlow1, gHaloS, 0, 0, 1.4, 10.0, 2.0, {255, 255, 255, 255}, 0, 0);
		TE_SendToAll();

		// Light
		new ent = CreateEntityByName("light_dynamic");

		DispatchKeyValue(ent, "_light", "120 120 255 255");
		DispatchKeyValue(ent, "brightness", "5");
		DispatchKeyValueFloat(ent, "spotlight_radius", 500.0);
		DispatchKeyValueFloat(ent, "distance", 500.0);
		DispatchKeyValue(ent, "style", "6");
		
		// SetEntityMoveType(ent, MOVETYPE_NOCLIP); 
		DispatchSpawn(ent);
		AcceptEntityInput(ent, "TurnOn");
		
		TeleportEntity(ent, entityposition, NULL_VECTOR, NULL_VECTOR);
		
		RemoveEntity(ent, 1.0);
		
		entityposition[2] += 15.0;
		makeexplosion(IsClientConnectedIngame(client) ? client : 0, -1, entityposition, "", GetConVarInt(cvar_damage));
		
		env_shake(entityposition, 120.0, 1000.0, 3.0, 250.0);
		
		EmitSoundToAll("weapons/physcannon/energy_disintegrate4.wav", 0, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, entityposition);
		

		if(!GetConVarBool(cvar_implode))
			return;

		// Knockback
		new Float:vReturn[3], Float:vClientPosition[3], Float:dist;
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i))
			{	
				GetClientEyePosition(i, vClientPosition);

				dist = GetVectorDistance(vClientPosition, entityposition, false);
				if (dist < 1000.0)
				{
					MakeVectorFromPoints(entityposition, vClientPosition, vReturn);
					NormalizeVector(vReturn, vReturn);
					ScaleVector(vReturn, -5000.0);

					TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, vReturn);
				}
			}
		}
	}
}

public Action:DarRegalos(Handle:timer, any:client)
{
 if (IsClientInGame(client) && g_Santa[client])
 {
   	g_Regalos[client] += 1;
 }
}


public EventWeaponFire(Handle:event,const String:name[],bool:dontBroadcast) 
{       
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	static String:sWeapon[32];
	GetEventString(event, "weapon", sWeapon, sizeof(sWeapon));
	if (!IsFakeClient(client) && StrEqual(sWeapon, "knife") && g_Regalos[client] > 0)
	{
				
				MineAttack(client);	
				g_Regalos[client] -= 1;
				
				if (g_Santa[client])
				{
					new Float:pos[3];
					GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
					EmitSoundToAll("santa/santa.mp3", SOUND_FROM_WORLD, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, pos);                
					CreateTimer(GetConVarFloat(cvar_ataque), DarRegalos, client);
				}
						
	}
}

stock bool:makeexplosion(attacker = 0, inflictor = -1, const Float:attackposition[3], const String:weaponname[] = "", magnitude = 800, radiusoverride = 0, Float:damageforce = 0.0, flags = 0){
	
	new explosion = CreateEntityByName("env_explosion");


	
	if(explosion != -1)
	{
		DispatchKeyValueVector(explosion, "Origin", attackposition);
		
		decl String:intbuffer[64];
		IntToString(magnitude, intbuffer, 64);
		DispatchKeyValue(explosion,"iMagnitude", intbuffer);
		if(radiusoverride > 0)
		{
			IntToString(radiusoverride, intbuffer, 64);
			DispatchKeyValue(explosion,"iRadiusOverride", intbuffer);
		}
		
		if(damageforce > 0.0)
			DispatchKeyValueFloat(explosion,"DamageForce", damageforce);

		if(flags != 0)
		{
			IntToString(flags, intbuffer, 64);
			DispatchKeyValue(explosion,"spawnflags", intbuffer);
		}

		if(!StrEqual(weaponname, "", false))
			DispatchKeyValue(explosion,"classname", weaponname);

		DispatchSpawn(explosion);
		if(IsClientConnectedIngame(attacker))
                {
			SetEntPropEnt(explosion, Prop_Send, "m_hOwnerEntity", attacker);
		        new clientTeam = GetEntProp(attacker, Prop_Send, "m_iTeamNum");
                        SetEntProp(explosion, Prop_Send, "m_iTeamNum", clientTeam);
                }

		if(inflictor != -1)
			SetEntPropEnt(explosion, Prop_Data, "m_hInflictor", inflictor);

			
		AcceptEntityInput(explosion, "Explode");
		AcceptEntityInput(explosion, "Kill");
		
		return (true);
	}
	else
		return (false);
}

stock setm_takedamage(entity, type)
{
	SetEntProp(entity, Prop_Data, "m_takedamage", type);
}

stock bool:IsEntityCollidable(entity, bool:includeplayer = true, bool:includehostage = true, bool:includeprojectile = true)
{
	decl String:classname[64];
	GetEdictClassname(entity, classname, 64);
	
	if((StrEqual(classname, "player", false) && includeplayer) || (StrEqual(classname, "hostage_entity", false) && includehostage)
		|| StrContains(classname, "physics", false) != -1 || StrContains(classname, "prop", false) != -1
		|| StrContains(classname, "door", false)  != -1 || StrContains(classname, "weapon", false)  != -1
		|| StrContains(classname, "break", false)  != -1 || ((StrContains(classname, "projectile", false)  != -1) && includeprojectile)
		|| StrContains(classname, "brush", false)  != -1 || StrContains(classname, "button", false)  != -1
		|| StrContains(classname, "physbox", false)  != -1 || StrContains(classname, "plat", false)  != -1
		|| StrEqual(classname, "func_conveyor", false) || StrEqual(classname, "func_fish_pool", false)
		|| StrEqual(classname, "func_guntarget", false) || StrEqual(classname, "func_lod", false)
		|| StrEqual(classname, "func_monitor", false) || StrEqual(classname, "func_movelinear", false)
		|| StrEqual(classname, "func_reflective_glass", false) || StrEqual(classname, "func_rotating", false)
		|| StrEqual(classname, "func_tanktrain", false) || StrEqual(classname, "func_trackautochange", false)
		|| StrEqual(classname, "func_trackchange", false) || StrEqual(classname, "func_tracktrain", false)
		|| StrEqual(classname, "func_train", false) || StrEqual(classname, "func_traincontrols", false)
		|| StrEqual(classname, "func_vehicleclip", false) || StrEqual(classname, "func_traincontrols", false)
		|| StrEqual(classname, "func_water", false) || StrEqual(classname, "func_water_analog", false))
	{
		return (true);
	}
	
	return (false);
}

stock bool:IsClientConnectedIngame(client)
{
	if(client > 0 && client <= MaxClients)
		if(IsClientInGame(client))
			return (true);

	return (false);
}

public Action:OnWeaponCanUse(client, weapon)
{
	if (g_Santa[client] && !GetConVarBool(cvar_weapons))
	{
		// block switching to weapon other than knife
		decl String:sClassname[32];
		GetEdictClassname(weapon, sClassname, sizeof(sClassname));
		if (!StrEqual(sClassname, "weapon_knife"))
			return Plugin_Handled;
	}
	return Plugin_Continue;
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
}
