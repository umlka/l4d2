#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

#define PLUGIN_NAME				"Server Clean Up"
#define PLUGIN_AUTHOR			"Jamster"
#define PLUGIN_DESCRIPTION		"Cleans up logs and demo files automatically"
#define PLUGIN_VERSION			"1.2.2"
#define PLUGIN_URL				"https://forums.alliedmods.net/showthread.php?p=1023928"

#define CVAR_FLAGS				FCVAR_NOTIFY

enum {
	LOG = 0,
	SML,
	DEM,
	SPR,
	MAX
};

ConVar
	g_cEnable,
	g_cLogging,
	g_cLogType,
	g_cType[MAX],
	g_cTime[MAX],
	g_cDemoPath,
	g_cArchDemos,
	g_cSVLogsDir;

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	CreateConVar("sm_srvcln_version", PLUGIN_VERSION, "Server Clean Up version.", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_cEnable =		CreateConVar("sm_srvcln_enable",			"1",		"启用服务器自动清理 (1-自动,0-仅手动).", CVAR_FLAGS);
	g_cLogging =	CreateConVar("sm_srvcln_logging_mode",		"0",		"记录服务器清理删除的内容.", CVAR_FLAGS);
	g_cLogType =	CreateConVar("sm_srvcln_smlogs_type",		"2",		"要从SM日志文件夹中删除的日志类型(0-仅普通日志,1-普通日志和错误日志,2-所有日志).", CVAR_FLAGS);
	g_cType[LOG] =	CreateConVar("sm_srvcln_logs",				"1",		"清理常规服务器日志.", CVAR_FLAGS);
	g_cType[SML] =	CreateConVar("sm_srvcln_smlogs",			"1",		"清理SourceMod服务器日志.", CVAR_FLAGS);
	g_cType[DEM] =	CreateConVar("sm_srvcln_demos",				"0",		"清理自动录制的demo演示文件.", CVAR_FLAGS);
	g_cDemoPath =	CreateConVar("sm_srvcln_demos_path",		"./demos",	"demo演示文件的可选目录路径(如果要在其他位置手动保存它们).", CVAR_FLAGS);
	g_cArchDemos =	CreateConVar("sm_srvcln_demos_archives",	"0",		"删除demo演示文件时,自动检测服务器压缩文件(bz2,zip,rar和7z).", CVAR_FLAGS);
	g_cType[SPR] =	CreateConVar("sm_srvcln_sprays",			"1",		"清理上传的客户端喷漆文件.", CVAR_FLAGS);
	g_cTime[LOG] =	CreateConVar("sm_srvcln_logs_time",			"168",		"保留常规服务器日志的时间(以小时为单位)(默认为一周,最小值为12小时,设置为-1仅保留当前日期).", CVAR_FLAGS, true, -1.0);
	g_cTime[SPR] =	CreateConVar("sm_srvcln_sprays_time",		"168",		"保留上传的客户端喷漆文件的时间(以小时为单位)(默认为一周,最小值为12小时,设置为-1仅保留当前日期).", CVAR_FLAGS, true, -1.0);
	g_cTime[SML] =	CreateConVar("sm_srvcln_smlogs_time",		"168",		"保留SourceMod服务器日志的时间(以小时为单位)(默认为一周,最小值为12小时,设置为-1仅保留当前日期).", CVAR_FLAGS, true, -1.0);
	g_cTime[DEM] =	CreateConVar("sm_srvcln_demos_time",		"168",		"保留demo演示文件的时间(以小时为单位)(默认为一周,最小值为12小时,设置为-1仅保留当前日期).", CVAR_FLAGS, true, -1.0);
	g_cSVLogsDir =	FindConVar("sv_logsdir");

	RegAdminCmd("sm_srvcln_now", cmdCleanNow, ADMFLAG_ROOT, "手动运行服务器清理");
}

public void OnConfigsExecuted() {
	if (g_cEnable.BoolValue) {
		for (int i; i < MAX; i++) {
			if (g_cType[i].BoolValue)
				CleanServer(i);
		}
	}
}

Action cmdCleanNow(int client, int args) {
	ReplyToCommand(client, "启动服务器清理");

	for (int i; i < MAX; i++) {
		if (g_cType[i].BoolValue)
			CleanServer(i);
	}

	LogMessage("手动运行服务器清理");
	ReplyToCommand(client, "服务器清理已完成");
	return Plugin_Handled;
}

void CleanServer(int type) {	
	int Time32;
	int TimeType = g_cTime[type].IntValue;
	if (TimeType != -1)
		Time32 = GetTime() / 3600 - TimeType;
	else {
		char day[12];
		FormatTime(day, sizeof day, "%Y%j");
		Time32 = StringToInt(day);
	}
	
	char fileName[256];
	bool log = g_cLogging.BoolValue;
	char directory[PLATFORM_MAX_PATH];

	switch (type) {
		case LOG:
			g_cSVLogsDir.GetString(directory, sizeof directory);

		case SML:
			BuildPath(Path_SM, directory, sizeof directory, "logs");

		case DEM:
			g_cDemoPath.GetString(directory, sizeof directory);

		case SPR:
			FormatEx(directory, sizeof directory, "downloads");
	}

	FileType entryType;
	DirectoryListing dl;

	if (type == SPR) {
		if (DirExists(directory)) {
			dl = OpenDirectory(directory);
			while (dl.GetNext(fileName, sizeof fileName, entryType)) {
				if (entryType != FileType_File)
					continue;

				if (IsSpraysFile(fileName)) {
					CanDelete(Time32, TimeType, directory, fileName, type, log);
					continue;
				} 
			}

			delete dl;
		}

		FormatEx(directory, sizeof directory, "download/user_custom");
		if (DirExists(directory)) {
			DirectoryListing dlContents;
			static char buffer[PLATFORM_MAX_PATH];
			static char contents[PLATFORM_MAX_PATH];

			bool empty;
			dl = OpenDirectory(directory);
			while (dl.GetNext(buffer, sizeof buffer, entryType)) {
				if (entryType != FileType_Directory)
					continue;

				FormatEx(contents, sizeof contents, "%s/%s", directory, buffer);
				if (DirExists(contents)) {
					empty = true;
					dlContents = OpenDirectory(contents);
					while (dlContents.GetNext(fileName, sizeof fileName, entryType)) {
						if (entryType != FileType_File)
							continue;

						empty = false;

						if (IsSpraysFile(fileName)) {
							CanDelete(Time32, TimeType, contents, fileName, type, log);
							continue;
						}
					}

					delete dlContents;
					if (empty)
						CanDelete(Time32, TimeType, directory, buffer, type, log, true, true);
				}
				
			}

			delete dl;
		}
	}
	else {
		if (DirExists(directory)) {
			bool compresses = g_cArchDemos.BoolValue;
			dl = OpenDirectory(directory);
			while (dl.GetNext(fileName, sizeof fileName, entryType)) {
				if (entryType != FileType_File)
					continue;

				if (type == LOG) {
					if (IsLogFile(fileName)) {
						CanDelete(Time32, TimeType, directory, fileName, type, log);
						continue;
					}
				}
				else if (type == SML) {
					switch (g_cLogType.IntValue) {
						case 0: {
							if (StrContains(fileName, "l", false) == 0 && IsLogFile(fileName)) {
								CanDelete(Time32, TimeType, directory, fileName, type, log);
								continue;
							}
						}

						case 1: {
							if ((StrContains(fileName, "l", false) == 0 || StrContains(fileName, "errors_", false) == 0) && IsLogFile(fileName)) {
								CanDelete(Time32, TimeType, directory, fileName, type, log);
								continue;
							}
						}

						case 2: {
							if (IsLogFile(fileName)) {
								CanDelete(Time32, TimeType, directory, fileName, type, log);
								continue;
							}
						}
					}
				}
				else if (type == DEM) {
					if (StrContains(fileName, "auto-", false) == 0 && (IsDemoFile(fileName) || (compresses && IsCompressesFile(fileName)))) {
						CanDelete(Time32, TimeType, directory, fileName, type, log);
						continue;
					}
				}
			}
			
			delete dl;
		}
	}
}

void CanDelete(int Time32, int TimeType, const char[] directory, const char[] fileName, int type, bool log, bool force = false, bool folder = false) {
	int TimeStamp;
	static char buffer[PLATFORM_MAX_PATH];
	FormatEx(buffer, sizeof buffer, "%s/%s", directory, fileName);
	if (type == SPR) {
		// Sprays are done on last access due to players requesting them.
		TimeStamp = GetFileTime(buffer, FileTime_LastAccess);
		if (TimeStamp == -1)
			TimeStamp = GetFileTime(buffer, FileTime_LastChange);
	}
	else
		TimeStamp = GetFileTime(buffer, FileTime_LastChange);
	
	if (TimeType != -1)
		TimeStamp /= 3600;
	else {
		char day[12];
		FormatTime(day, sizeof day, "%Y%j", TimeStamp);
		TimeStamp = StringToInt(day);
	}
	
	if (TimeStamp == -1)
		LogError("\"%s\" 时间戳错误", buffer);
	
	if (force || Time32 > TimeStamp) {
		if (folder ? !RemoveDir(buffer) : !DeleteFile(buffer))
			LogError("无法删除 \"%s\", 可能是因为权限不足.", buffer);
		else if (log) {
			if (!folder)
				LogMessage("删除文件 \"%s\"", buffer);
			else
				LogMessage("删除文件夹 \"%s\"", buffer);
		}
	}
}

bool IsSpraysFile(const char[] fileName) {
	int length = strlen(fileName);
	return StrContains(fileName, ".dat", false) == length - 4 || StrContains(fileName, ".ztmp", false) == length - 5;
}

bool IsLogFile(const char[] fileName) {
	return StrContains(fileName, ".log", false) == strlen(fileName) - 4;
}

bool IsDemoFile(const char[] fileName) {
	return StrContains(fileName, ".dem", false) == strlen(fileName) - 4;
}

bool IsCompressesFile(const char[] fileName) {
	int length = strlen(fileName);
	return StrContains(fileName, ".zip", false) == length - 4 || StrContains(fileName, ".bz2", false) == length - 4 || StrContains(fileName, ".rar", false) == length - 4 || StrContains(fileName, ".7z", false) == length - 3;
}
