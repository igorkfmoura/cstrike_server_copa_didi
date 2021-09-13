#include <amxmodx>
#include <cstrike>
#include <fun>
#include <hamsandwich>

#define PLUGIN "ep1c: Reset Score"
#define VERSION "1.2"
#define AUTHOR "S H E R M A N"

new const PREFIX[] = "^4[COPA DO DIDI]^1";

enum _:xMaxCvars
{
	CVAR_SHOW_MSG_ALL,
	CVAR_SOUND,
	CVAR_RESET_NEGATIVE,
	CVAR_AD_RESET_TIME
}

new xCvars[xMaxCvars]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	xRegisterSay("resetscore", "xResetScore")
	xRegisterSay("rr", "xResetScore")
	xRegisterSay("rs", "xResetScore")
	xRegisterSay("frag", "xResetScore")

	xCvars[CVAR_SHOW_MSG_ALL] = create_cvar("csr_reset_show_msg_all", "1", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0)
	xCvars[CVAR_SOUND] = create_cvar("csr_reset_sound", "1", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0)
	xCvars[CVAR_RESET_NEGATIVE] = create_cvar("csr_reset_negative", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0)
	xCvars[CVAR_AD_RESET_TIME] = create_cvar("csr_ad_reset_time", "3")

	RegisterHam(Ham_Killed, "player", "xPlayerKilled", true)
}

public plugin_cfg()
{
	static xTimeAds; xTimeAds = get_pcvar_num(xCvars[CVAR_AD_RESET_TIME])

	if(xTimeAds)
	{
		xTimeAds *= 60
		set_task(float(xTimeAds), "xAdResetScore", _, _, _, "b")
	}
}

public xPlayerKilled(victim, id, shouldgib)
{
	if(!is_user_connected(id))
		return HAM_IGNORED

	if(get_user_frags(victim) < get_user_deaths(victim) && get_pcvar_num(xCvars[CVAR_RESET_NEGATIVE]))
		xResetScore(victim)
	
	return HAM_IGNORED
}

public xAdResetScore()
{
	if(get_pcvar_num(xCvars[CVAR_RESET_NEGATIVE]))
	{
		client_print_color(0, print_team_red, "^4[Dica]^1 Digite ^4/rr^1 ou ^4.rs^1 para resetar seu ^4FRAG^1!");
		client_print_color(0, print_team_red, "^4[Dica]^1 Obs: Jogadores ^3negativos^1 terão os ^4FRAG^1 resetado automaticamente.")
	}
	else
	{
		client_print_color(0, print_team_red, "^4[Dica]^1 Digite ^4/rr^1 ou ^4.rs^1 para resetar seu ^4FRAG^1")
	}
}

public xResetScore(id)
{
	if(!is_user_connected(id))
		return PLUGIN_HANDLED

	static xName[32]; get_user_name(id, xName, charsmax(xName))

	if(get_pcvar_num(xCvars[CVAR_SHOW_MSG_ALL]))
		client_print_color(0, id, "%s ^3%s^1 zerou o score.", PREFIX, xName)
	else
		client_print_color(id, id, "%s ^3Você^1 zerou seu score.", PREFIX)

	if(get_pcvar_num(xCvars[CVAR_SOUND]))
		client_cmd(id, "spk plats/elevbell1.wav")
	
	cs_set_user_deaths(id, 0)
	set_user_frags(id, 0)
	cs_set_user_deaths(id, 0)
	set_user_frags(id, 0)

	return PLUGIN_HANDLED
}

stock xRegisterSay(szsay[], szfunction[])
{
	new sztemp[64]
	formatex(sztemp, 63 , "say /%s", szsay)
	register_clcmd(sztemp, szfunction)
	
	formatex(sztemp, 63 , "say .%s", szsay)
	register_clcmd(sztemp, szfunction)
	
	formatex(sztemp, 63 , "say_team /%s", szsay)
	register_clcmd(sztemp, szfunction )
	
	formatex(sztemp, 63 , "say_team .%s", szsay)
	register_clcmd(sztemp, szfunction)
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1046\\ f0\\ fs16 \n\\ par }
*/
