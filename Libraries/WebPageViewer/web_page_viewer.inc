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
 * @param web_page_url		Web page to open.
 * @param window_width		The width of the popup window.
 * @param window_height		The height of the popup window.
 * @noreturn
 */
native WebPageViewer_OpenPage(client, const String:web_page_url[], window_width=786, window_height=518, bool:query_disabled_html_cvar=true);



#if !defined REQUIRE_PLUGIN
public __pl_web_page_viewer_SetNTVOptional()
{
	MarkNativeAsOptional("WebPageViewer_OpenPage");
}
#endif