#define PLUGIN_VERSION 		"1.1"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Console Spam Patches
*	Author	:	SilverShot
*	Descrp	:	Prevents certain errors/warnings from being displayed in the server console.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=316612
*	Plugins	:	http://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.1 (29-Jun-2019)
	- Renamed gamedata vars "SpamPatch_Add" to "SpamPatch_Sig" for easier editing and duplication.
	- If updating from 1.0 either rename these strings or download the new gamedata.

1.0 (01-Jun-2019)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo =
{
	name = "[L4D & L4D2] Console Spam Patches",
	author = "SilverShot",
	description = "防止某些错误/警告显示在服务器控制台中.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=316612"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead && test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	//CreateConVar("l4d_console_spam_version", PLUGIN_VERSION, "Console Spam Patches version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	Handle hGameConfg = LoadGameConfigFile("l4d_console_spam");

	if( hGameConfg )
	{
		Address patchAddr;
		char sTemp[32];
		int loop = 1;

		while( loop )
		{
			Format(sTemp, sizeof sTemp, "SpamPatch_Sig%d", loop);
			patchAddr = GameConfGetAddress(hGameConfg, sTemp);

			if( patchAddr )
			{
				StoreToAddress(patchAddr, 0x00, NumberType_Int8);
				loop++;
			} else {
				PrintToServer("[Console Spam] patched %d entries.", loop - 1);
				loop = 0;
			}
		}
	}

	delete hGameConfg;
}