/* Plugin Template generated by Pawn Studio */

#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <l4d2lib>
#include <sdktools>
#include <l4d2util_stocks>

/*
* Version 1.0
* - End Saferoom Door closes shut to prevent SI from Sneaking in there.
* - While Tank is up the End Saferoom Door can't be closed unless 50% of the Team is Dead/Incapped.
* > In 1v1 and 2v2 you're forced to kill the Tank.
* 
* Version 1.1
* - Implement a new method to hook onto End Saferoom Doors.
* - Now works in Custom Campaigns and L4D1 Maps.
* - Cleaned up Code.
///////////////////
******************/

#define SAFEDOOR_CLASS "prop_door_rotating_checkpoint"
#define SAFEDOOR_MODEL_01 "models/props_doors/checkpoint_door_01.mdl"
#define SAFEDOOR_MODEL_01_2 "models/props_doors/checkpoint_door_-01.mdl"
#define SAFEDOOR_MODEL_02 "models/props_doors/checkpoint_door_02.mdl"
#define SAFEDOOR_MODEL_02_2 "models/props_doors/checkpoint_door_-02.mdl"

//Checking & Saving Entities
int Door;
int TotalDoors;
int ent_safedoor;

//Has survivor made it to the saferoom? / How many made it to the saferoom?
int checkpointreached[MAXPLAYERS+1];
int checkpointtotal;

//CVars + Tracking
ConVar g_hSafeEndClose;
ConVar g_hSafeEndTankBlock;
ConVar g_hSurvivorLimit;

int IsIncapped[MAXPLAYERS+1];

bool bHasHooked;

//No Finals Please
Handle hFinalMapsTrie;
bool bCheckFinal;


public Plugin myinfo = 
{
    name = "Saferoom Door Manager",
    author = "Sir",
    description = "Manages Saferoom Doors",
    version = "1.1",
    url = "https://github.com/SirPlease/SirCoding"
}

public void OnPluginStart()
{
    //CVars
    g_hSafeEndClose = CreateConVar("safe_end_lock", "1", "Close end Saferoom Door on round start?");
    g_hSafeEndTankBlock = CreateConVar("safe_end_tank", "1", "Stop Survivors from closing saferoom during Tank when 50% or more is Alive");
    
    //Finals
    hFinalMapsTrie = FinalMaps();
    
    //Tracking
    g_hSurvivorLimit = FindConVar("survivor_limit");
    
    //Start!
    bHasHooked = false;
	HookEvent("door_open", Door_Open);
}

public void L4D2_OnRealRoundStart()
{
    //Reset Clientside Tracking and Total.
    for(int i = 1; i <= MAXPLAYERS; i++)
    {
        checkpointreached[i] = 0;
        IsIncapped[i] = 0;
    }
    checkpointtotal = 0;
    
    //Empty Storage
	ent_safedoor = -1;
    Door = 0;
    TotalDoors = 0;
    bCheckFinal = false;
    
    //Map Check
    char sCurMap[64];
    GetCurrentMap(sCurMap, sizeof(sCurMap));
    GetTrieValue(hFinalMapsTrie, sCurMap, bCheckFinal);
	
	CreateTimer(1.0, DelayDoor);
}

public Action DelayDoor(Handle timer)
{
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, SAFEDOOR_CLASS)) != -1)
	if (entity > 0)
	{
		//Check both Model and Targetname
		char sModel[128];
		char sName[128];
		GetEntPropString(entity, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
		GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));
		
		int spawn_flags;
		spawn_flags = GetEntProp(entity, Prop_Data, "m_spawnflags");
			
		if ((StrEqual(sModel, SAFEDOOR_MODEL_01) && (spawn_flags == 8192 || spawn_flags == 0)) 
		|| (StrEqual(sModel, SAFEDOOR_MODEL_01_2) && (spawn_flags == 8192 || spawn_flags == 0))) ent_safedoor = entity;
		
		if (StrEqual(sModel, SAFEDOOR_MODEL_02)
		|| StrEqual(sModel, SAFEDOOR_MODEL_02_2))
		{
			//Store Doors for Recheck - Used for maps that don't trigger on the targetname check
			TotalDoors++;
			
			//Is targetname equal to these? - Triggers for most maps.
			if(StrEqual(sName, "checkpoint_entrance")
			|| StrEqual(sName, "door_checkpoint"))
			{
				Door = entity;
				FoundYou();
			}
			// Found an End Saferoom door Model that's not assigned the correct targetname.
			else CreateTimer (1.0, NoDoors, entity);
		}
	}
}

public Action NoDoors(Handle timer, any entity)
{
    //There should only be one End Saferoom Model, check for it.
    if(TotalDoors == 1 && Door == 0)
    {
        Door = entity;
        FoundYou();
    }
}

void FoundYou()
{
    //If map is a finale, return.
    if(bCheckFinal) return;
    
    //Close door if requested
    if (GetConVarBool(g_hSafeEndClose)) AcceptEntityInput(Door, "Close");
    
    //Hook/UnHook
    if(GetConVarBool(g_hSafeEndTankBlock)) Hook();
    else UnHook();
}

public Action Door_Open(Event event, const char[] name, bool dontBroadcast)
{
	if (ent_safedoor > 0)
	{
		if (event.GetBool("checkpoint"))
		{
			int client = GetClientOfUserId(event.GetInt("userid"));
			if (!client || !IsClientInGame(client)) return;
			int ent_brokendoor = CreateEntityByName("prop_physics");
			char model[255];
			GetEntPropString(ent_safedoor, Prop_Data, "m_ModelName", model, sizeof(model));
			
			float pos[3], ang[3];
			GetEntPropVector(ent_safedoor, Prop_Send, "m_vecOrigin", pos);
			GetEntPropVector(ent_safedoor, Prop_Send, "m_angRotation", ang);
			AcceptEntityInput(ent_safedoor, "Kill");
			DispatchKeyValue(ent_brokendoor, "model", model);
			DispatchKeyValue(ent_brokendoor, "spawnflags", "4");
			DispatchSpawn(ent_brokendoor);
			
			float EyeAngles[3], Push[3], ang_fix[3];
			
			ang_fix[0] = (ang[0] - 5.0);
			ang_fix[1] = (ang[1] + 5.0);
			ang_fix[2] = (ang[2]);
			
			GetClientEyeAngles(client, EyeAngles);
			Push[0] = (100.0 * Cosine(DegToRad(EyeAngles[1])));
			Push[1] = (100.0 * Sine(DegToRad(EyeAngles[1])));
			Push[2] = (15.0 * Sine(DegToRad(EyeAngles[0])));
			
			TeleportEntity(ent_brokendoor, pos, ang_fix, Push);
			CreateTimer(10.0, FadeBrokenDoor, ent_brokendoor);
		}
	}
}

public Action FadeBrokenDoor(Handle timer, any ent_brokendoor)
{
	if (IsValidEntity(ent_brokendoor))
	{
		SetEntityRenderFx(ent_brokendoor, RENDERFX_FADE_FAST); //RENDERFX_FADE_SLOW 3.5
		CreateTimer(1.5, KillBrokenDoorEntity, ent_brokendoor);
	}
}

public Action KillBrokenDoorEntity(Handle timer, any ent_brokendoor)
{
	if (IsValidEntity(ent_brokendoor)) AcceptEntityInput(ent_brokendoor, "Kill");
}

public Action Player_Entered_Checkpoint(Event event, const char[] name, bool dontBroadcast)
{
    int entered = GetClientOfUserId(event.GetInt("userid"));
    int door = event.GetInt("door");
    
    if (IsValidInGame(entered))
    {
        //Is Actual End Saferoom?
        //Check if there are multiple "End Saferoom" Doors.
        if (door == Door)
        {
            //Survivor Entered
            if (GetClientTeam(entered) == 2) 
            {
                checkpointreached[entered] = 1;
                checkpointtotal++;
                
                //Check if we can Close.
                CanWeClose();
            }	
        }
    }
}

public Action Player_Left_Checkpoint(Event event, const char[] name, bool dontBroadcast)
{
    int left = GetClientOfUserId(event.GetInt("userid"));
    
    if (IsValidInGame(left) && checkpointreached[left] == 1)
    {
        //Survivor Left
        checkpointreached[left] = 0;
        checkpointtotal--;
        
        //Check if we can Close.
        if (checkpointtotal > 0) CanWeClose();
    }
}

public Action OnRevive(Event event, const char[] name, bool dontBroadcast)
{
    int revive = GetClientOfUserId(event.GetInt("subject"));
    if (!IsValidInGame(revive) || GetClientTeam(revive ) != 2) return;
    
    //Incapped, do a check.
    IsIncapped[revive] = 0;
    
    if (checkpointtotal > 0) CanWeClose();
}

public Action OnDeath(Event event, const char[] name, bool dontBroadcast)
{
    int death = GetClientOfUserId(event.GetInt("userid"));
    char victim[64];
    event.GetString("victimname", victim, sizeof(victim));
    
    if (!IsValidInGame(death)) return;
    
    //Survivor Died.
    if(GetClientTeam(death) != 2 && checkpointreached[death] == 1)
    {
        checkpointreached[death] = 0;
        checkpointtotal--;
        
        if (checkpointtotal > 0) CanWeClose();
    }
    else if (StrEqual(victim, "tank", false)) CanWeClose();
}

public Action OnIncap(Event event, const char[] name, bool dontBroadcast)
{
    int incap = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidInGame(incap) || GetClientTeam(incap) != 2) return;
    
    //Incapped, do a check.
    IsIncapped[incap] = 1;
    
    if (checkpointtotal > 0) CanWeClose();
}

void CanWeClose()
{
    if(!CheckClose()) DispatchKeyValue(Door, "spawnflags", "32768");
    else DispatchKeyValue(Door, "spawnflags", "8192");
}

bool CheckClose()
{
    if(TankUp())
    {
        //Block 1v1 and 2v2 Tank Rushes
        if (GetConVarInt(g_hSurvivorLimit) <= 2) return false;
        
        // More than 50%? Block. (2 of 3) && (3+ of 4)
        if ((((float(checkpointtotal) + float(FindSurvivors())) / float(GetConVarInt(g_hSurvivorLimit))) * 100) > 50)
        {
            return false;
        }
    }
    return true;
}

bool TankUp()
{
    for (int t = 1; t <= MaxClients; t++)
    {
        if (!IsClientInGame(t) 
            || GetClientTeam(t) != 3 
        || !IsPlayerAlive(t) 
        || GetEntProp(t, Prop_Send, "m_zombieClass") != 8)
        continue;
        
        return true; // Found tank, return
    }
    return false;
}

int FindSurvivors()
{
    int Outsiders = 0;
    
    for (int outsider = 1; outsider <= MaxClients; outsider++)
    {
        if (IsValidInGame(outsider) 
            && GetClientTeam(outsider) == 2
        && !checkpointreached[outsider]  
        && IsPlayerAlive(outsider) 
        && !IsIncapped[outsider]) 
        
        Outsiders++;
    }
    return Outsiders;
}

void Hook()
{
    //Hooked Events Already.
    if (bHasHooked) return;
    bHasHooked = true;
    
    //Saferoom Leaving and Entering
    HookEvent("player_entered_checkpoint", Player_Entered_Checkpoint);
    HookEvent("player_left_checkpoint", Player_Left_Checkpoint);
    
    //Incap or Death - Check Door.
    HookEvent("revive_success", OnRevive); 
    HookEvent("player_death", OnDeath);
    HookEvent("player_incapacitated", OnIncap);
}

void UnHook()
{
    //No Events to Unhook
    if(!bHasHooked) return;
    bHasHooked = false;
    
    //Saferoom Leaving and Entering
    UnhookEvent("player_entered_checkpoint", Player_Entered_Checkpoint);
    UnhookEvent("player_left_checkpoint", Player_Left_Checkpoint);
    
    //Incap or Death - Check Door.
    UnhookEvent("revive_success", OnRevive); 
    UnhookEvent("player_death", OnDeath);
    UnhookEvent("player_incapacitated", OnIncap);
}

Handle FinalMaps()
{
    Handle trie = CreateTrie();
    
    SetTrieValue(trie, "c1m4_atrium", true);
    SetTrieValue(trie, "c2m5_concert", true);
    SetTrieValue(trie, "c3m4_plantation", true);
    SetTrieValue(trie, "c4m5_milltown_escape", true);
    SetTrieValue(trie, "c5m5_bridge", true);
    SetTrieValue(trie, "c6m3_port", true);
    SetTrieValue(trie, "c7m3_port", true);
    SetTrieValue(trie, "c8m5_rooftop", true);
    SetTrieValue(trie, "c9m2_lots", true);
    SetTrieValue(trie, "c10m5_houseboat", true);
    SetTrieValue(trie, "c11m5_runway", true);
    SetTrieValue(trie, "c12m5_cornfield", true);
    SetTrieValue(trie, "c13m4_cutthroatcreek", true);
    
    return trie;    
}
