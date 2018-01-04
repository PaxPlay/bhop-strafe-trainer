#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <clientprefs>

#pragma newdecls required

#define TRAINER_TICK_INTERVAL 10

EngineVersion g_Game;

float gF_LastAngle[MAXPLAYERS + 1][3];
int gI_ClientTickCount[MAXPLAYERS + 1];
float gF_ClientPercentages[MAXPLAYERS + 1][TRAINER_TICK_INTERVAL];

Handle gH_StrafeTrainerCookie;
bool gB_StrafeTrainer[MAXPLAYERS + 1] = {false, ...};

public Plugin myinfo = 
{
	name = "BHOP Strafe Trainer",
	author = "PaxPlay",
	description = "Bhop Strafe Trainer",
	version = "0.1",
	url = "https://github.com/PaxPlay/bhop-strafe-trainer"
};

public void OnPluginStart()
{	
	g_Game = GetEngineVersion();
	if(g_Game != Engine_CSGO && g_Game != Engine_CSS)
	{
		SetFailState("This plugin is for CSGO/CSS only.");	
	}
	
	RegConsoleCmd("sm_strafetrainer", Command_StrafeTrainer, "Toggles the Strafe trainer.");
	
	gH_StrafeTrainerCookie = RegClientCookie("strafetrainer_enabled", "strafetrainer_enabled", CookieAccess_Protected);
	
	// Late loading
	for(int i = 1; i <= MaxClients; i++)
	{
		if(AreClientCookiesCached(i))
		{
			OnClientCookiesCached(i);
		}
	}
}

public void OnClientDisconnect(int client)
{
	gB_StrafeTrainer[client] = false;
}

public void OnClientCookiesCached(int client)
{
	gB_StrafeTrainer[client] = GetClientCookieBool(client, gH_StrafeTrainerCookie);
}

public Action Command_StrafeTrainer(int client, int args)
{
	if (client != 0)
	{
		gB_StrafeTrainer[client] = !gB_StrafeTrainer[client];
		SetClientCookieBool(client, gH_StrafeTrainerCookie, gB_StrafeTrainer[client]);
		ReplyToCommand(client, "[SM] Strafe Trainer %s!", gB_StrafeTrainer[client] ? "enabled" : "disabled");
	}
	else
	{
		ReplyToCommand(client, "[SM] Invalid client!");
	}
	
	return Plugin_Handled;
}

float NormalizeAngle(float angle)
{
	float newAngle = angle;
	while (newAngle <= -180.0) newAngle += 360.0;
	while (newAngle > 180.0) newAngle -= 360.0;
	return newAngle;
}

float GetClientVelocity(int client)
{
	float vVel[3];
	
	vVel[0] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]");
	vVel[1] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]");
	
	
	return GetVectorLength(vVel);
}

float PerfStrafeAngle(float speed)
{
	return RadToDeg(ArcTangent(30 / speed));
}

void VisualisationString(char[] buffer, int maxlength, float percentage)
{
	
	if (0.5 <= percentage <= 1.5)
	{
		int Spaces = RoundFloat((percentage - 0.5) / 0.05);
		for (int i = 0; i <= Spaces + 1; i++)
		{
			FormatEx(buffer, maxlength, "%s ", buffer);
		}
		
		FormatEx(buffer, maxlength, "%s|", buffer);
		
		for (int i = 0; i <= (21 - Spaces); i++)
		{
			FormatEx(buffer, maxlength, "%s ", buffer);
		}
	}
	else
		Format(buffer, maxlength, "%s", percentage < 1.0 ? "|                   " : "                    |");
}

void GetPercentageColor(float percentage, int &r, int &g, int &b)
{
	float offset = FloatAbs(1 - percentage);
	
	if (offset < 0.05)
	{
		r = 0;
		g = 255;
		b = 0;
	}
	else if (0.05 <= offset < 0.1)
	{
		r = 128;
		g = 255;
		b = 0;
	}
	else if (0.1 <= offset < 0.25)
	{
		r = 255;
		g = 255;
		b = 0;
	}
	else if (0.25 <= offset < 0.5)
	{
		r = 255;
		g = 128;
		b = 0;
	}
	else
	{
		r = 255;
		g = 0;
		b = 0;
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!gB_StrafeTrainer[client])
		return Plugin_Continue; // dont run when disabled
	if ((GetEntityFlags(client) & FL_ONGROUND) || (GetEntityMoveType(client) == MOVETYPE_NOCLIP) || (GetEntityMoveType(client) == MOVETYPE_LADDER))
		return Plugin_Continue; // dont run when disabled
	
	// calculate differences
	float AngDiff[3];
	AngDiff[0] = NormalizeAngle(gF_LastAngle[client][0] - angles[0]); //not really used
	AngDiff[1] = NormalizeAngle(gF_LastAngle[client][1] - angles[1]);
	AngDiff[2] = NormalizeAngle(gF_LastAngle[client][2] - angles[2]); //not really used
	
	// get the perfect angle
	float PerfAngle = PerfStrafeAngle(GetClientVelocity(client));
	
	// calculate the current percentage
	float Percentage = FloatAbs(AngDiff[1]) / PerfAngle;
	
	
	if (gI_ClientTickCount[client] >= TRAINER_TICK_INTERVAL) // only every 10th tick, not really usable otherwise
	{
		float AveragePercentage = 0.0;
		
		for (int i = 0; i < TRAINER_TICK_INTERVAL; i++) // calculate average from the last ticks
		{
			AveragePercentage += gF_ClientPercentages[client][i];
			gF_ClientPercentages[client][i] = 0.0;
		}
		AveragePercentage /= TRAINER_TICK_INTERVAL;
		
		char sVisualisation[32]; // get the visualisation string
		VisualisationString(sVisualisation, sizeof(sVisualisation), AveragePercentage);
		
		// format the message
		char sMessage[256];
		Format(sMessage, sizeof(sMessage), "%d\%", RoundFloat(AveragePercentage * 100));
		
		Format(sMessage, sizeof(sMessage), "%s\n══════^══════", sMessage);
		Format(sMessage, sizeof(sMessage), "%s\n %s ", sMessage, sVisualisation);
		Format(sMessage, sizeof(sMessage), "%s\n══════^══════", sMessage);
		
		
		// get the text color
		int r, g, b;
		GetPercentageColor(AveragePercentage, r, g, b);
		
		// print the text
		Handle hText = CreateHudSynchronizer();
		if(hText != INVALID_HANDLE)
		{
			SetHudTextParams(-1.0, 0.2, 0.1, r, g, b, 255, 0, 0.0, 0.0, 0.1);
			ShowSyncHudText(client, hText, sMessage);
			CloseHandle(hText);
		}
		
		gI_ClientTickCount[client] = 0;
	}
	else
	{
		// save the percentage to an array to calculate the average later
		gF_ClientPercentages[client][gI_ClientTickCount[client]] = Percentage;
		gI_ClientTickCount[client]++;
	}
	
	// save the angles to a variable used in the next tick
	gF_LastAngle[client] = angles;
	
	return Plugin_Continue;
}

stock bool GetClientCookieBool(int client, Handle cookie)
{
	char sValue[8];
	GetClientCookie(client, gH_StrafeTrainerCookie, sValue, sizeof(sValue));
	
	return (sValue[0] != '\0' && StringToInt(sValue));
}

stock void SetClientCookieBool(int client, Handle cookie, bool value)
{
	char sValue[8];
	IntToString(value, sValue, sizeof(sValue));
	
	SetClientCookie(client, cookie, sValue);
}