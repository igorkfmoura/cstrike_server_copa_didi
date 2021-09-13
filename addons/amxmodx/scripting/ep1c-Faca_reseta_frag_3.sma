#include <amxmodx>
#include <cstrike>
#include <fun>

#define PLUGIN  "ep1c: Faca reseta frag"
#define VERSION "1.2"
#define AUTHOR  "Wilian M."

new cvar_enabled;
new enabled;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	register_event("DeathMsg", "xDeathMsg", "a")
	cvar_enabled = create_cvar("amx_knife_rr", "1")
	bind_pcvar_num(cvar_enabled, enabled)

}

public xDeathMsg()
{
	if (!enabled)
		return

	new xKiller = read_data(1)
	new xVictim = read_data(2)

	if(xKiller == xVictim)
		return

	new xWpn[32]
	read_data(4, xWpn, charsmax(xWpn))
    
	if(equal(xWpn, "knife") && is_user_alive(xKiller))
    {
		static xNameVic[32], xNameKiller[32]
		get_user_name(xKiller, xNameKiller, charsmax(xNameKiller))
		get_user_name(xVictim, xNameVic, charsmax(xNameVic))

		client_print_color(0, xVictim, "^4>> ^3%s ^1teve seu ^4FRAG ^1resetado pois morreu na faca por: ^4%s^1!", xNameVic, xNameKiller)

		set_task(1.0, "xResetScore", xVictim+22417)
    }
}

public xResetScore(xVictim)
{
	xVictim -= 22417

	if(!is_user_connected(xVictim))
	{
		remove_task(xVictim+22417)
		return
	}

	cs_set_user_deaths(xVictim, 0)
	set_user_frags(xVictim, 0)
	cs_set_user_deaths(xVictim, 0)
	set_user_frags(xVictim, 0)
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1046\\ f0\\ fs16 \n\\ par }
*/
