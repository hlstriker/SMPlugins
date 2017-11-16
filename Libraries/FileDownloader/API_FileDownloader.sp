/*
* 	Things to note:
* 	- The http requests don't support redirects or services such as Cloudflare.
* 	- If you are having problems with a request you may need to lower the MAX_BYTES_PER_PACKET value.
*/

#include <sourcemod>
#include <socket>

#undef REQUIRE_PLUGIN
#include "../../Plugins/TokensUpdate/tokens_update"
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma dynamic 18000000

new const String:PLUGIN_NAME[] = "API: File Downloader";
new const String:PLUGIN_VERSION[] = "1.7";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to download files.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define MAX_URL_LENGTH		512

// On Linux setting this value any higher than 13299 would cause data loss?
// On Windows any value seemed fine.
// I thought maybe the SocketSendBuffer option wasn't working so increased the default net.ipv4.tcp_wmem value, still no good.
#define MAX_BYTES_PER_PACKET	13298

/*
#define PACK_LOCATION_PARSED_HEADER		0
#define PACK_LOCATION_FILE_HANDLE		8
#define PACK_LOCATION_PACK_STRINGS		16
#define PACK_LOCATION_SUCCESS_FORWARD	24
#define PACK_LOCATION_FAILED_FORWARD	32
*/

#define PACK_LOCATION_PARSED_HEADER		0
#define PACK_LOCATION_FILE_HANDLE		1
#define PACK_LOCATION_PACK_STRINGS		2
#define PACK_LOCATION_SUCCESS_FORWARD	3
#define PACK_LOCATION_FAILED_FORWARD	4
#define PACK_LOCATION_PASSED_DATA		5
#define PACK_LOCATION_BYTES_SENT		6

new const String:KEY_REQUEST[]		= "req";
new const String:KEY_REQUEST_LEN[]	= "reqlen";
new const String:KEY_SAVE_PATH[]	= "save";

new const String:POST_BOUNDARY[]	= "--SwooblesFormBoundaryr55pgTcYXsURugXEa";

enum DownloadEndCode
{
	DL_END_SUCCESS,
	DL_END_FILE_NOT_FOUND,
	DL_END_SOCKET_ERROR,
	DL_END_WRITE_ERROR
};

new g_iNumFilesDownloading;

new bool:g_bLibLoaded_TokensUpdate;


public OnPluginStart()
{
	CreateConVar("api_file_downloader_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public OnAllPluginsLoaded()
{
	g_bLibLoaded_TokensUpdate = LibraryExists("tokens_update");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "tokens_update"))
		g_bLibLoaded_TokensUpdate = true;
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "tokens_update"))
		g_bLibLoaded_TokensUpdate = false;
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("file_downloader");
	CreateNative("FileDownloader_DownloadFile", _FileDownloader_DownloadFile);
	CreateNative("FileDownloader_GetNumFilesDownloading", _FileDownloader_GetNumFilesDownloading);
	
	return APLRes_Success;
}

public _FileDownloader_GetNumFilesDownloading(Handle:hPlugin, iNumParams)
{
	return g_iNumFilesDownloading;
}

public _FileDownloader_DownloadFile(Handle:hPlugin, iNumParams)
{
	if(iNumParams < 4 || iNumParams > 7)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	if(g_bLibLoaded_TokensUpdate)
	{
		#if defined _tokens_update_included
		if(TokensUpdate_IsAwaitingRestart())
		{
			LogMessage("Could not start download since TokensUpdate is awaiting a restart.");
			return false;
		}
		#endif
	}
	
	decl iLengthURL;
	if(GetNativeStringLength(1, iLengthURL) != SP_ERROR_NONE)
		return false;
	
	decl iLengthSavePath;
	if(GetNativeStringLength(2, iLengthSavePath) != SP_ERROR_NONE)
		return false;
	
	g_iNumFilesDownloading++;
	
	iLengthURL++;
	iLengthSavePath++;
	decl String:szURL[iLengthURL], String:szSavePath[iLengthSavePath];
	GetNativeString(1, szURL, iLengthURL);
	GetNativeString(2, szSavePath, iLengthSavePath);
	
	CreateDirectoryStructure(szSavePath);
	
	// Get the file handle.
	new Handle:hFile = OpenFile(szSavePath, "wb");
	
	// Create the data pack.
	new Handle:hSuccessForward;
	new Function:callback = GetNativeCell(3);
	if(callback != INVALID_FUNCTION)
	{
		hSuccessForward = CreateForward(ET_Ignore, Param_String, Param_Any);
		AddToForward(hSuccessForward, hPlugin, callback);
	}
	
	new Handle:hFailedForward;
	callback = GetNativeCell(4);
	if(callback != INVALID_FUNCTION)
	{
		hFailedForward = CreateForward(ET_Ignore, Param_String, Param_Any);
		AddToForward(hFailedForward, hPlugin, callback);
	}
	
	new Handle:hPackStrings = CreateTrie();
	SetTrieArray(hPackStrings, KEY_REQUEST, {0}, 0);
	SetTrieValue(hPackStrings, KEY_REQUEST_LEN, 1);
	SetTrieString(hPackStrings, KEY_SAVE_PATH, szSavePath);
	
	new Handle:hPack = CreateDataPack();
	WritePackCell(hPack, 0);
	WritePackCell(hPack, _:hFile);
	WritePackCell(hPack, _:hPackStrings);
	WritePackCell(hPack, _:hSuccessForward);
	WritePackCell(hPack, _:hFailedForward);
	
	if(iNumParams >= 5)
		WritePackCell(hPack, GetNativeCell(5));
	else
		WritePackCell(hPack, 0);
	
	WritePackCell(hPack, 0);
	
	// Check the file handle.
	if(hFile == INVALID_HANDLE)
	{
		LogError("Error writing to file: %s", szSavePath);
		DownloadEnded(DL_END_WRITE_ERROR, _, hPack);
		return false;
	}
	
	decl String:szHostName[64], String:szLocation[256], String:szFileName[256];
	ParseURL(szURL, szHostName, sizeof(szHostName), szLocation, sizeof(szLocation), szFileName, sizeof(szFileName));
	
	new bool:bSetRequest;
	if(iNumParams >= 7)
	{
		new iPostFileDataLen = GetNativeCell(7);
		if(iPostFileDataLen > 0)
		{
			decl iPostFileData[iPostFileDataLen];
			GetNativeArray(6, iPostFileData, iPostFileDataLen);
			
			new iRequestLen = iPostFileDataLen + (MAX_URL_LENGTH * 2) + (sizeof(POST_BOUNDARY) * 3);
			decl String:szRequest[iRequestLen];
			
			new iPayLoadStartSize = 148 + sizeof(POST_BOUNDARY);
			decl String:szPayloadStart[iPayLoadStartSize];
			new iPayloadStartLen = FormatEx(szPayloadStart, iPayLoadStartSize, "\
				--%s\r\n\
				Content-Disposition: form-data; name=\"file\"; filename=\"file_from_dl_api\"\r\n\
				Content-Type: application/octet-stream\r\n\
				\r\n", POST_BOUNDARY);
			
			new iPayloadEndSize = 16 + sizeof(POST_BOUNDARY);
			decl String:szPayloadEnd[iPayloadEndSize];
			new iPayloadEndLen = FormatEx(szPayloadEnd, iPayloadEndSize, "\
				\r\n\
				--%s--\r\n", POST_BOUNDARY);
			
			new iLen = FormatEx(szRequest, iRequestLen, "\
				POST %s/%s HTTP/1.1\r\n\
				Host: %s\r\n\
				Connection: close\r\n\
				Pragma: no-cache\r\n\
				Cache-Control: no-cache\r\n\
				Accept: text/html\r\n\
				User-Agent: SwooblesDownloaderAPI\r\n\
				Content-Type: multipart/form-data; boundary=%s\r\n\
				Content-Length: %i\r\n\
				\r\n",
				szLocation, szFileName, szHostName, POST_BOUNDARY, iPayloadStartLen + iPostFileDataLen + iPayloadEndLen);
			
			iLen += FormatEx(szRequest[iLen], iRequestLen-iLen, szPayloadStart);
			
			for(new i=0; i<iPostFileDataLen; i++)
			{
				szRequest[iLen] = iPostFileData[i];
				iLen++;
			}
			
			iLen += FormatEx(szRequest[iLen], iRequestLen-iLen, szPayloadEnd);
			
			SetTrieArray(hPackStrings, KEY_REQUEST, szRequest, iLen);
			SetTrieValue(hPackStrings, KEY_REQUEST_LEN, iLen);
			bSetRequest = true;
		}
	}
	
	if(!bSetRequest)
	{
		decl String:szRequest[MAX_URL_LENGTH];
		new iLen = FormatEx(szRequest, sizeof(szRequest), "GET %s/%s HTTP/1.1\r\nHost: %s\r\nConnection: close\r\nPragma: no-cache\r\nCache-Control: no-cache\r\n\r\n", szLocation, szFileName, szHostName);
		SetTrieArray(hPackStrings, KEY_REQUEST, szRequest, iLen);
		SetTrieValue(hPackStrings, KEY_REQUEST_LEN, MAX_URL_LENGTH);
	}
	
	new Handle:hSocket = SocketCreate(SOCKET_TCP, OnSocketError);
	SocketSetArg(hSocket, hPack);
	SocketConnect(hSocket, OnSocketConnected, OnSocketReceive, OnSocketDisconnected, szHostName, 80);
	
	return true;
}

CreateDirectoryStructure(const String:szSavePath[])
{
	new iStrLen;
	decl String:szExplode[24][128], String:szTempPath[PLATFORM_MAX_PATH];
	
	strcopy(szTempPath, sizeof(szTempPath), szSavePath);
	ReplaceString(szTempPath, sizeof(szTempPath), "\\", "/");
	
	new iNumStrings = ExplodeString(szTempPath, "/", szExplode, sizeof(szExplode), sizeof(szExplode[]));
	for(new i=0; i<(iNumStrings - 1); i++)
	{
		if(!strlen(szExplode[i]))
			continue;
		
		if(!iStrLen)
			iStrLen += strcopy(szTempPath[iStrLen], sizeof(szTempPath), szExplode[i]);
		else
			iStrLen += FormatEx(szTempPath[iStrLen], sizeof(szTempPath), "/%s", szExplode[i]);
		
		if(!iStrLen)
			continue;
		
		if(DirExists(szTempPath))
			continue;
		
		CreateDirectory(szTempPath, FPERM_U_READ | FPERM_U_WRITE | FPERM_U_EXEC | FPERM_G_READ | FPERM_G_EXEC | FPERM_O_READ | FPERM_O_EXEC);
	}
}

public OnSocketConnected(Handle:hSocket, any:hPack)
{
	TrySendBytes(hSocket, hPack);
}

public OnSendQueueEmpty(Handle:hSocket, any:hPack)
{
	TrySendBytes(hSocket, hPack);
}

TrySendBytes(Handle:hSocket, any:hPack)
{
	SetPackGhettoPosition(hPack, PACK_LOCATION_PACK_STRINGS);
	new Handle:hPackStrings = Handle:ReadPackCell(hPack);
	
	SetPackGhettoPosition(hPack, PACK_LOCATION_BYTES_SENT);
	new iBytesSent = ReadPackCell(hPack);
	
	decl iRequestLen;
	GetTrieValue(hPackStrings, KEY_REQUEST_LEN, iRequestLen);
	
	if(iBytesSent >= iRequestLen)
		return;
	
	decl String:szRequest[iRequestLen];
	GetTrieArray(hPackStrings, KEY_REQUEST, szRequest, iRequestLen);
	
	new iBytesToSend = MAX_BYTES_PER_PACKET;
	if((iRequestLen - iBytesSent) < iBytesToSend)
		iBytesToSend = (iRequestLen - iBytesSent);
	
	SocketSend(hSocket, szRequest[iBytesSent], iBytesToSend);
	SocketSetSendqueueEmptyCallback(hSocket, OnSendQueueEmpty);
	
	SetPackGhettoPosition(hPack, PACK_LOCATION_BYTES_SENT);
	WritePackCell(hPack, iBytesSent + iBytesToSend);
}

SetPackGhettoPosition(Handle:hPack, iPosition)
{
	// When SM 1.7 released it broke the increments of 8 in the pack cells.
	// Use this for a quick and extremely dirty fix.
	// TODO: Fix it properly.
	
	ResetPack(hPack, false);
	for(new i=0; i<iPosition; i++)
		ReadPackCell(hPack);
}

public OnSocketReceive(Handle:hSocket, String:szData[], const iSize, any:hPack)
{
	// Check if the HTTP header has already been parsed.
	SetPackGhettoPosition(hPack, PACK_LOCATION_PARSED_HEADER);
	new bool:bParsedHeader = bool:ReadPackCell(hPack);
	
	new iIndex;
	if(!bParsedHeader)
	{
		iIndex = StrContains(szData, "\r\n\r\n");
		if(iIndex == -1)
		{
			iIndex = 0;
		}
		else
		{
			// Check HTTP status code
			decl String:szStatusCode[4];
			strcopy(szStatusCode, sizeof(szStatusCode), szData[9]);
			szStatusCode[3] = '\x0';
			
			if(!StrEqual(szStatusCode, "200"))
			{
				DownloadEnded(DL_END_FILE_NOT_FOUND, hSocket, hPack);
				return;
			}
			
			iIndex += 4;
		}
		
		SetPackGhettoPosition(hPack, PACK_LOCATION_PARSED_HEADER);
		WritePackCell(hPack, 1);
	}
	
	// Write data to file.
	SetPackGhettoPosition(hPack, PACK_LOCATION_FILE_HANDLE);
	new Handle:hFile = Handle:ReadPackCell(hPack);
	
	while(iIndex < iSize)
		WriteFileCell(hFile, szData[iIndex++], 1);
}

public OnSocketDisconnected(Handle:hSocket, any:hPack)
{
	DownloadEnded(DL_END_SUCCESS, hSocket, hPack);
}

public OnSocketError(Handle:hSocket, const iErrorType, const iErrorNum, any:hPack)
{
	DownloadEnded(DL_END_SOCKET_ERROR, hSocket, hPack);	
	LogError("Socket error: %i (Error code %i)", iErrorType, iErrorNum);
}

DownloadEnded(DownloadEndCode:code, Handle:hSocket=INVALID_HANDLE, Handle:hPack)
{
	// Get the save path.
	decl String:szSavePath[PLATFORM_MAX_PATH];
	SetPackGhettoPosition(hPack, PACK_LOCATION_PACK_STRINGS);
	new Handle:hPackStrings = ReadPackCell(hPack);
	
	if(hPackStrings != INVALID_HANDLE)
		GetTrieString(hPackStrings, KEY_SAVE_PATH, szSavePath, sizeof(szSavePath));
	else
		szSavePath[0] = '\x0';
	
	SetPackGhettoPosition(hPack, PACK_LOCATION_PASSED_DATA);
	new any:data = ReadPackCell(hPack);
	
	switch(code)
	{
		case DL_END_SUCCESS:
		{
			SetPackGhettoPosition(hPack, PACK_LOCATION_SUCCESS_FORWARD);
			new Handle:hHandle = ReadPackCell(hPack);
			if(hHandle != INVALID_HANDLE)
			{
				Call_StartForward(hHandle);
				Call_PushString(szSavePath);
				Call_PushCell(data);
				if(Call_Finish() != SP_ERROR_NONE)
					LogError("Error calling success forward for [%s].", szSavePath);
			}
			
			CloseSocketHandles(hSocket, hPack);
			DeleteFileIfNeeded(szSavePath);
		}
		case DL_END_FILE_NOT_FOUND, DL_END_SOCKET_ERROR, DL_END_WRITE_ERROR:
		{
			SetPackGhettoPosition(hPack, PACK_LOCATION_FAILED_FORWARD);
			new Handle:hHandle = ReadPackCell(hPack);
			if(hHandle != INVALID_HANDLE)
			{
				Call_StartForward(hHandle);
				Call_PushString(szSavePath);
				Call_PushCell(data);
				if(Call_Finish() != SP_ERROR_NONE)
					LogError("Error calling failed forward for [%s].", szSavePath);
			}
			
			CloseSocketHandles(hSocket, hPack);
			DeleteFileIfNeeded(szSavePath, true);
		}
	}
	
	g_iNumFilesDownloading--;
}

CloseSocketHandles(Handle:hSocket, Handle:hPack)
{
	// Close the handles.
	SetPackGhettoPosition(hPack, PACK_LOCATION_FILE_HANDLE);
	new Handle:hHandle = ReadPackCell(hPack);
	if(hHandle != INVALID_HANDLE)
		CloseHandle(hHandle);
	
	SetPackGhettoPosition(hPack, PACK_LOCATION_SUCCESS_FORWARD);
	hHandle = ReadPackCell(hPack);
	if(hHandle != INVALID_HANDLE)
		CloseHandle(hHandle);
	
	SetPackGhettoPosition(hPack, PACK_LOCATION_FAILED_FORWARD);
	hHandle = ReadPackCell(hPack);
	if(hHandle != INVALID_HANDLE)
		CloseHandle(hHandle);
	
	SetPackGhettoPosition(hPack, PACK_LOCATION_PACK_STRINGS);
	hHandle = ReadPackCell(hPack);
	if(hHandle != INVALID_HANDLE)
		CloseHandle(hHandle);
	
	if(hPack != INVALID_HANDLE)
		CloseHandle(hPack);
	
	if(hSocket != INVALID_HANDLE)
		CloseHandle(hSocket);
}

DeleteFileIfNeeded(const String:szSavePath[], bool:bForceDelete=false)
{
	// Delete the file if needed.
	new iFileSize = FileSize(szSavePath, false);
	if((bForceDelete && iFileSize != -1) || iFileSize == 0)
		DeleteFile(szSavePath);
}

/*
* Taken directly from GoD-Tony's updater plugin.
* https://forums.alliedmods.net/showthread.php?t=169095
*/
ParseURL(const String:url[], String:host[], maxHost, String:location[], maxLoc, String:filename[], maxName)
{
	// Strip url prefix.
	new idx = StrContains(url, "://");
	idx = (idx != -1) ? idx + 3 : 0;
	
	decl String:dirs[16][64];
	new total = ExplodeString(url[idx], "/", dirs, sizeof(dirs), sizeof(dirs[]));
	
	// host
	Format(host, maxHost, "%s", dirs[0]);
	
	// location
	location[0] = '\0';
	for (new i = 1; i < total - 1; i++)
	{
		Format(location, maxLoc, "%s/%s", location, dirs[i]);
	}
	
	// filename
	Format(filename, maxName, "%s", dirs[total-1]);
}