#if defined _tokens_update_included
 #endinput
#endif
#define _tokens_update_included


public SharedPlugin:__pl_tokens_update = 
{
	name = "tokens_update",
	file = "TokensUpdate.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


native bool:TokensUpdate_IsAwaitingRestart();


#if !defined REQUIRE_PLUGIN
public __pl_tokens_update_SetNTVOptional()
{
	MarkNativeAsOptional("TokensUpdate_IsAwaitingRestart");
}
#endif