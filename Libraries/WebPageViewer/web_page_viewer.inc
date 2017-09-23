#if defined _web_page_viewer_included
 #endinput
#endif
#define _web_page_viewer_included


public SharedPlugin:__pl_web_page_viewer = 
{
	name = "web_page_viewer",
	file = "API_WebPageViewer.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



/**
 * Opens a web page in a popup window.
 *
 * @param client			Client index.
 * @param url_format		Web page URL format.
 * @param any				Variable number of format parameters.
 * @return					True on success, false otherwise.
 */
native bool:WebPageViewer_OpenPage(client, const String:url_format[], any:...);



#if !defined REQUIRE_PLUGIN
public __pl_web_page_viewer_SetNTVOptional()
{
	MarkNativeAsOptional("WebPageViewer_OpenPage");
}
#endif