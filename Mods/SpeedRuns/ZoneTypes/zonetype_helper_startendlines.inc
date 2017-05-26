#if defined _zonetype_helper_startendlines_included
 #endinput
#endif
#define _zonetype_helper_startendlines_included


public SharedPlugin:__pl_zonetype_helper_startendlines = 
{
	name = "zonetype_helper_startendlines",
	file = "ZoneTypeHelper_StartEndLines.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


enum LineType
{
	LINE_TYPE_START = 0,
	LINE_TYPE_END
};

enum StyleType
{
	STYLE_TYPE_NOT_ENABLED = -1,
	STYLE_TYPE_LINE,
	STYLE_TYPE_LINE_BETWEEN_POINTS,
	STYLE_TYPE_X,
	STYLE_TYPE_X_BETWEEN_POINTS
};

enum FaceType
{
	FACE_TYPE_AUTOMATIC = 0,
	FACE_TYPE_FORWARD,
	FACE_TYPE_BACK,
	FACE_TYPE_LEFT,
	FACE_TYPE_RIGHT,
	FACE_TYPE_TOP,
	FACE_TYPE_BOTTOM
};


#define DATA_STRING_LINE_DATA	5


functag public Callback_OnLineMenuBack(client, zone_id);


native bool:StartEndLines_DisplayLineMenu(client, zone_id, LineType:line_type, Callback_OnLineMenuBack:on_menu_back_callback);

native StartEndLines_SetStyle(zone_id, LineType:line_type, StyleType:style_new);
native StartEndLines_SetFaceType(zone_id, LineType:line_type, FaceType:face_type_new);
native StartEndLines_SetLinePercent(zone_id, LineType:line_type, percent);
