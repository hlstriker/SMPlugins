#if defined _unsafe_knives_included
 #endinput
#endif
#define _unsafe_knives_included


public SharedPlugin:__pl_unsafe_knives = 
{
	name = "unsafe_knives",
	file = "Unsafe_Knives.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


functag public Callback_OnKnifeMenuBack(client);
functag public Callback_OnKnifeMenuSelect(client);


native Knives_OpenKnifeMenu(client, Callback_OnKnifeMenuSelect:menu_select_callback=INVALID_FUNCTION, Callback_OnKnifeMenuBack:menu_back_callback=INVALID_FUNCTION);
native bool:Knives_GetUsedKnifeClassname(client, String:classname[], maxlength);


#if !defined REQUIRE_PLUGIN
public __pl_unsafe_knives_SetNTVOptional()
{
	MarkNativeAsOptional("Knives_OpenKnifeMenu");
	MarkNativeAsOptional("Knives_GetUsedKnifeClassname");
}
#endif