#if defined _ultjb_logger_included
 #endinput
#endif
#define _ultjb_logger_included

public SharedPlugin:__pl_ultjb_logger = 
{
	name = "ultjb_logger",
	file = "UltJB_Logger.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

enum
{
	LOGTYPE_ANY = 0,
	LOGTYPE_NONE = 1,
	LOGTYPE_ATTACK,
	LOGTYPE_ITEM,
	LOGTYPE_USE,
	LOGTYPE_BREAK,
	LOGTYPE_LASTREQUEST
};

native UltJB_Logger_LogEvent(String:message[], iPrimaryLog, iSecondaryLog, iLogType, bool:bLogGlobal=true);