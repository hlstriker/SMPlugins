new const String:PLUGIN_NAME[] = "Strafe Stats";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "Hymns For Disco",
	description = "Gives strafing stats",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define TICKS 20

new Float:g_fGain[MAXPLAYERS + 1][TICKS];

public OnClientConnected(iClint)
{
	for (new i = 0; i < TICKS; i++)
	g_fGain[iClient][i] = 0;
}
