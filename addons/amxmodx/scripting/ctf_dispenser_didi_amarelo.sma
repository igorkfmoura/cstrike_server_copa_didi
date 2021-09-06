/*         
~~~~~~~~~~~~~~~~~~~~~~~
Build Dispenser
Edit por Zetsukt & OciXCrom [ Base Original tuty ]

lonewolf implementou:
- trocas de cor ao mudar de time
- aviso de quem destruiu dispenser de aliado
- auto-unstuck otimizado
- entre outros

~~~~~~~~~~~~~~~~~~~~~~~
*/



#include < amxmodx >
#include < amxmisc >

#include < fakemeta >
#include < hamsandwich >
#include < cstrike >
#include < engine >
#include < fun >

#include < xs >

#pragma semicolon 1

#define PLUGIN  "ep1c-CTF-Dispenser"
#define VERSION "#1.0.6.5"
#define AUTHOR  "tuty + lonewolf"


#if AMXX_VERSION_NUM < 183
#define MAX_PLAYERS        32
#endif

#define BREAK_COMPUTER        6

#if !defined client_disconnected
	#define client_disconnected client_disconnect
#endif

enum
{
	STATUS_BUILDING,
	STATUS_ACTIVE
};

enum _: iColorAndCoords
{
	x_r = 0,
	y_g,
	z_b
};

new const gDamageSounds[ ][ ] =
{
	"debris/metal1.wav",
	"debris/metal2.wav",
	"debris/metal3.wav"
};

/*new const szBuildingMessages[ ][ ] =
{
	"Construindo um dispenser..."
};*/

new const PREFIX_CHAT[ ] = "^4[COPA DO DIDI]^1";
new const PREFIX_MENU[ ] = "\y[ \rDispenser\y ]\w";

new const gDispenserClassname[ ] = "NiceDispenser:D";

new const gDispenserActive[ ] = "buttons/button9.wav";
new const gMetalGibsMdl[ ] = "models/computergibs.mdl";

new const gDispenserMdl[] = "models/dispenser_hd.mdl";

//new const gHealingSprite[ ] = "sprites/laserbeam.spr";

static const gTeamColors[CsTeams][3] = 
{
  {  0,  0,   0},
  {255, 25,   0},
  {  0, 25, 255},
  {  0,  0,   0},
};

const gDispenserAdminFlag = ADMIN_RCON;
const Float:gDispenserCheckFreq = 0.5;
const gDispenserCheckDistance = 1500;

new gDispenserSyncObj;

new gHealingBeam;
new gMetalGibs;
new gMaxPlayers;
// new gHudSync;

new gCvarEnabled;
new gDispenserCost;
new gCvarDispenserHealth;
new gCvarBuildTime;
new gCvarReplenishRadius;
new gCvarSpinDispenser;
new gCvarMaxHealth;
new gCvarMaxArmor;
new gCvarGlow;


new CsTeams:gPlayerTeam[ MAX_PLAYERS + 1 ];

new Float:gDispenserOrigin[ MAX_PLAYERS + 1 ][ iColorAndCoords ];
// new gBeamcolor[ MAX_PLAYERS + 1 ][ iColorAndCoords ];

new Float:gDispenserHealthOff[ MAX_PLAYERS + 1 ];
new bool:bDispenserBuild[ MAX_PLAYERS + 1 ];
new gUserDispenser[ MAX_PLAYERS + 1 ];

public plugin_init( )
{
	register_plugin( PLUGIN, VERSION, AUTHOR );

	register_event( "TextMsg", "EVENT_TextMsg", "a", "2&#Game_C", "2&#Game_w", "2&#Game_will_restart_in" );
	register_logevent( "LOG_RoundEnd", 2, "1=Round_End" );

	static szDispenserClassname[ ] = "info_target";

	RegisterHam( Ham_Spawn, "player", "PlayerSpawn", 1 );
	RegisterHam( Ham_TakeDamage, szDispenserClassname, "bacon_TakeDamage", 1 );
	RegisterHam( Ham_TraceAttack, szDispenserClassname, "bacon_TraceAttack" );

	register_think( gDispenserClassname, "DispenserThink" );
	register_clcmd( "drop", "CommandDispenserBuild" );
	register_clcmd( "say", "CommandSay" );
	register_clcmd( "say_team", "CommandSay" );

	gCvarEnabled = register_cvar( "dispenser_enabled", "1" );
	gDispenserCost = register_cvar( "dispenser_cost", "1500" );
	gCvarDispenserHealth = register_cvar( "dispenser_health", "900" );
	gCvarBuildTime = register_cvar( "dispenser_buildtime", "1" );
	gCvarReplenishRadius = register_cvar( "dispenser_radius", "300" );
	gCvarSpinDispenser = register_cvar( "dispenser_spin", "1" );
	gCvarMaxHealth = register_cvar( "dispenser_playermax_health", "100" );
	gCvarMaxArmor = register_cvar( "dispenser_playermax_armor", "100" );
	gCvarGlow = register_cvar( "dispenser_glow", "1" );

	gMaxPlayers = get_maxplayers( );

	// gHudSync = CreateHudSyncObj( );
	gDispenserSyncObj = CreateHudSyncObj( );
}

public client_connect( id )
{
	bDispenserBuild[ id ] = false;
	gUserDispenser[ id ] = 0;
	gPlayerTeam[ id ] = CS_TEAM_UNASSIGNED;
	
	set_task( gDispenserCheckFreq, "ShowDispenserOwner", id, .flags = "b" );
}

public client_disconnected( id )
{
	if( bDispenserBuild[ id ] )
	{
		DestroyDispenser( id );
	}
}

public plugin_precache( )
{
//	gHealingBeam = precache_model( gHealingSprite );
	gMetalGibs = precache_model( gMetalGibsMdl );

	precache_model( gDispenserMdl );
	precache_sound( gDispenserActive );

	new i;
	for( i = 0; i < sizeof gDamageSounds; i++ )
	{
		precache_sound( gDamageSounds[ i ] );
	}
}

public ShowDispenserOwner( id )
{
	new iEnt, iBody;
	get_user_aiming( id, iEnt, iBody, gDispenserCheckDistance );

	if( pev_valid( iEnt ) )
	{
		new szClassname[ 32 ];
		pev( iEnt, pev_classname, szClassname, charsmax( szClassname ) );

		if( equal( szClassname, gDispenserClassname ) )
		{
			new szName[ 32 ], iOwner = pev( iEnt, pev_iuser2 );
			get_user_name( iOwner, szName, charsmax( szName ) );

			set_hudmessage( 255, 255, 255, -1.0, 0.65, 1, .holdtime = gDispenserCheckFreq );
			ShowSyncHudMsg( id, gDispenserSyncObj, "• Dispenser •^n^nDono: %s", szName );
		}
	}
}

public CommandDispenserBuild( id )
{
	if( !is_user_alive( id )
	|| get_user_weapon( id ) != CSW_KNIFE
	|| get_pcvar_num( gCvarEnabled ) != 1 )
	{
		return PLUGIN_CONTINUE;
	}

	if( bDispenserBuild[ id ] == true && is_valid_ent( gUserDispenser[ id ] ) )
	{
		client_print_color(id, print_team_default, "%s Você já tem um ^3Dispenser^1 construido!", PREFIX_CHAT );

		return PLUGIN_HANDLED;
	}

	bDispenserBuild[ id ] = false;
	gUserDispenser[ id ] = 0;

	if( !( pev( id, pev_flags ) & FL_ONGROUND ) )
	{
		client_print_color(id, print_team_default, "%s Você precisa estar no chão para construir um ^3Dispenser^1!", PREFIX_CHAT );

		return PLUGIN_HANDLED;
	}

	new iMoney = cs_get_user_money( id );
	new iCost = get_pcvar_num( gDispenserCost );

	if( iMoney < iCost )
	{
		client_print_color(id, print_team_default, "%s Você precisa de ^4$%d^1 para construir um ^3Dispenser^1!", PREFIX_CHAT, iCost );
		
		return PLUGIN_HANDLED;
	}

	new iEntity = create_entity( "info_target" );

	if( !pev_valid( iEntity ) )
	{
		return PLUGIN_HANDLED;
	}

	gPlayerTeam[ id ] = cs_get_user_team(id);
	
	new Float:flPlayerOrigin[ 3 ];
	pev( id, pev_origin, flPlayerOrigin );

	new Float:flHealth = float( get_pcvar_num( gCvarDispenserHealth ) );
		
	set_pev( iEntity, pev_classname, gDispenserClassname );
	engfunc( EngFunc_SetModel, iEntity, gDispenserMdl );
	set_pev( iEntity, pev_skin, gPlayerTeam[ id ] );
	engfunc( EngFunc_SetSize, iEntity, Float:{ -12.0, -10.0, -12.0 }, Float:{ 12.0, 10.0, 12.0 } );
	set_pev( iEntity, pev_origin, flPlayerOrigin );
	set_pev( iEntity, pev_solid, SOLID_NOT );
	set_pev( iEntity, pev_movetype, MOVETYPE_PUSHSTEP );
	set_pev( iEntity, pev_health, flHealth );
	set_pev( iEntity, pev_takedamage, DAMAGE_YES );
	set_pev( iEntity, pev_iuser2, id );
	set_pev( iEntity, pev_iuser3, STATUS_BUILDING );
	set_pev( iEntity, pev_nextthink, get_gametime( ) + 0.1 );

	gDispenserOrigin[ id ][ x_r ] = flPlayerOrigin[ 0 ];
	gDispenserOrigin[ id ][ y_g ] = flPlayerOrigin[ 1 ];
	gDispenserOrigin[ id ][ z_b ] = flPlayerOrigin[ 2 ];

	gDispenserHealthOff[ id ] = flHealth;
	bDispenserBuild[ id ] = true;
	gUserDispenser[ id ] = iEntity;
	
	set_rendering( iEntity, kRenderFxDistort, 255, 255, 255, kRenderTransAdd, 70 );
	
	new Float:flBuildTime = get_pcvar_float( gCvarBuildTime );
	
	if ( flBuildTime > 0.0 )
	{
		set_task( flBuildTime, "BuildDispenserSolid", iEntity );
	}
	else
	{
		BuildDispenserSolid( iEntity );
	}
	
	cs_set_user_money( id, iMoney - iCost, 1 );

	client_print_color(id, id, "%s Você comprou um ^3Dispenser^1 por ^4$%d^1!", PREFIX_CHAT , iCost );

	return PLUGIN_HANDLED;
}

public MenuDestroy( id )
{
	if( !is_user_connected( id ) )
	{
		return PLUGIN_CONTINUE;
	}

	if ( !(get_user_flags( id ) & gDispenserAdminFlag) )
	{
		client_print_color( id, print_team_red, "%s Menu Destroy disponível apenas para ^3Administradores^1.", PREFIX_CHAT );
		return PLUGIN_CONTINUE;
	}

	new iMenu = menu_create( fmt( "%s \r~\w Destruir Dispenser^n\d(say /destroymenu)\w", PREFIX_MENU ), "MenuDestroyHandler" );

	new iDispenserCount = 0;

	for ( new iOwner = 1; iOwner <= MaxClients; ++iOwner )
	{
		if ( !bDispenserBuild[ iOwner ] || !is_user_connected( iOwner ) )
		{
			continue;
		}

		new iHealth = pev( gUserDispenser[ iOwner ], pev_health );

		new CsTeams:iTeam = cs_get_user_team( iOwner );
		new szTeams[ CsTeams ][] = { "", "\rTR\w", "\wCT\w", "" };

		new szOwner[ 32 ];
		get_user_name( iOwner, szOwner, charsmax( szOwner ) );

		new szItem[ 96 ];
		formatex( szItem, charsmax( szItem ), "\r» \w|%s| \r~\w |\y%s\w| \r~ \w|\yHP: \r%d\w|", szTeams[ iTeam ], szOwner, iHealth );

		new szInfo[6];
		num_to_str( iOwner, szInfo, charsmax( szInfo ) );

		menu_additem( iMenu, szItem, szInfo, gDispenserAdminFlag );

		++iDispenserCount;
	}

	if ( !iDispenserCount )
	{
		menu_addtext2( iMenu, "\d(Não há dispensers no mapa!)" );
	}

	menu_setprop( iMenu, MPROP_BACKNAME, "Página Anterior" );
	menu_setprop( iMenu, MPROP_NEXTNAME, "Proxima Página" );
	menu_setprop( iMenu, MPROP_EXITNAME, "Fechar" );

	menu_display(id, iMenu);

	return PLUGIN_HANDLED;
}

public MenuDestroyHandler( id, iMenu, iSlot )
{
	if( iSlot == MENU_EXIT )
	{
		menu_destroy( iMenu );

		return PLUGIN_HANDLED;
	}

	new szId[6];
	menu_item_getinfo( iMenu, iSlot, _, szId, charsmax( szId ) );

	new iOwner = str_to_num( szId );

	if( bDispenserBuild[ iOwner ] )
	{
		new szAdmin[ 32 ];
		new szName[ 32 ];
		get_user_name( iOwner, szName, charsmax( szName ) );
		get_user_name( id, szAdmin, charsmax( szAdmin ) );

		client_print_color( id, iOwner, "%s Você destruiu o ^4Dispenser^1 de ^3%s^1!", PREFIX_CHAT, szName );
		client_print_color( iOwner, id, "%s Administrador ^3%s^1 destruiu seu ^4Dispenser^1 via menu!", PREFIX_CHAT, szAdmin );

		client_cmd( iOwner, "speak ^"vox/bizwarn computer destroyed^"" );
		DestroyDispenser( iOwner );

	}

	set_task( 0.5, "MenuDestroyDelayed", 1631 + iOwner );
	menu_destroy( iMenu );

	return PLUGIN_HANDLED;
}

public MenuDestroyDelayed( iOwner )
{
	iOwner -= 1631;
	MenuDestroy( iOwner );
}

public CommandSay( id )
{
	new szSay[ 64 ], szCommand[ 32 ], szArg[ 32 ];
	read_args( szSay, charsmax( szSay ) );
	remove_quotes( szSay );

	parse( szSay, szCommand, charsmax( szCommand ), szArg, charsmax( szArg ) );

	if( !equal( szCommand, "/destroy" ) )
	{
		if ( equal( szCommand, "/destroymenu" ) )
		{
			MenuDestroy( id );
			return PLUGIN_HANDLED;
		}

		return PLUGIN_CONTINUE;
	}

	if( szArg[0] && get_user_flags( id ) & gDispenserAdminFlag )
	{
		new iPlayer = cmd_target( id, szArg, CMDTARGET_ALLOW_SELF );

		if( !iPlayer )
		{
			client_print_color(id, print_team_default, "%s Player não encontrado!", PREFIX_CHAT );
			return PLUGIN_HANDLED;
		}

		new szName[ 32 ];
		get_user_name( iPlayer, szName, charsmax( szName) );

		if( !bDispenserBuild[ iPlayer ] )
		{
			client_print_color(id, iPlayer, "%s Jogador ^3%s ^1não tem um ^4dispenser^1!", PREFIX_CHAT, szName );
			return PLUGIN_HANDLED;
		}

		DestroyDispenser( iPlayer );
		client_print_color(id, iPlayer, "%s Você destruiu o ^4Dispenser de ^3%s", PREFIX_CHAT, szName );
	}
	else
	{
		if( !bDispenserBuild[ id ] )
		{
			client_print_color(id, print_team_default, "%s Você^1 não tem um ^4dispenser^1!", PREFIX_CHAT );
			return PLUGIN_HANDLED;
		}

		if ( is_valid_ent( gUserDispenser[ id ] ) )
		{
			client_print_color(id, print_team_default, "%s Você^1 destruiu seu próprio ^4Dispenser^1.", PREFIX_CHAT );
		}
		DestroyDispenser( id );
	}

	return PLUGIN_HANDLED;
}

DestroyDispenser( id )
{
	if ( is_valid_ent( gUserDispenser[ id ] ) )
	{
		set_pev( gUserDispenser[ id ], pev_flags, pev( gUserDispenser[ id ], pev_flags ) | FL_KILLME );
	}
	bDispenserBuild[ id ] = false;
	gUserDispenser[ id ] = 0;
}

public bacon_TakeDamage( ent, idinflictor, idattacker, Float:damage, damagebits )
{
	new szClassname[ 32 ];
	pev( ent, pev_classname, szClassname, charsmax( szClassname ) );

	if( equal( szClassname, gDispenserClassname ) )
	{
		new iOwner = pev( ent, pev_iuser2 );
		new iHealth = pev( ent, pev_health );

		if( iHealth <= 0 )
		{
			new szName[ 32 ];
			get_user_name( idattacker, szName, charsmax( szName ) );

			new Float:flOrigin[ 3 ];
			pev( ent, pev_origin, flOrigin );

			UTIL_BreakModel( flOrigin, gMetalGibs, BREAK_COMPUTER );
			set_pev( ent, pev_flags, pev( ent, pev_flags ) | FL_KILLME );

			if( idattacker == iOwner )
			{
				client_print_color(iOwner, print_team_default, "%s Você destruiu seu próprio ^3Dispenser^1!", PREFIX_CHAT );
			}
			else
			{
				if (cs_get_user_team( iOwner ) != cs_get_user_team( idattacker ) )
				{
					client_print( iOwner, print_center, "%s destruiu seu Dispenser!", szName ); // centro da tela
					client_print_color(iOwner, idattacker, "%s Jogador ^3%s^1 destruiu seu Dispenser!", PREFIX_CHAT, szName); // no chat com cor
				}
				else
				{
					new szOwner[ 32 ];
					get_user_name( iOwner, szOwner, charsmax( szOwner ) );
					client_print_color(0, idattacker, "%s Jogador ^3%s^1 destruiu o Dispenser do aliado ^3%s^1!", PREFIX_CHAT, szName, szOwner); // vingança
				}
			}

			client_cmd( iOwner, "speak ^"vox/bizwarn computer destroyed^"" );
			bDispenserBuild[ iOwner ] = false;
		}


		gDispenserHealthOff[ iOwner ] = float( iHealth );
		emit_sound( ent, CHAN_STATIC, gDamageSounds[ random_num( 0, charsmax( gDamageSounds ) ) ], VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
	}
}

public bacon_TraceAttack( iVictim, iAttacker, Float:flDamage, Float:flDirection[ 3 ], iTr, iDamageBits )
{
	new szClassname[ 32 ];
	pev( iVictim, pev_classname, szClassname, charsmax( szClassname ) );

	if( equal( szClassname, gDispenserClassname ) )
	{
		new Float:flEndOrigin[ 3 ];
		get_tr2( iTr, TR_vecEndPos, flEndOrigin );

		UTIL_Sparks( flEndOrigin );
	}
}

public DispenserThink( iEnt )
{
	if( !pev_valid( iEnt )  )
	{
		return PLUGIN_CONTINUE;
	}
	
	new iOwner = pev( iEnt, pev_iuser2 );
	if ( !is_user_connected( iOwner ) )
	{
		return PLUGIN_CONTINUE;
	}
	
	set_pev( iEnt, pev_nextthink, get_gametime( ) + 0.1 );
	
	if( get_pcvar_num( gCvarSpinDispenser ) == 1 )
	{
		new Float:flAngles[ 3 ];
		pev( iEnt, pev_angles, flAngles );

		flAngles[ 1 ] += 1.0;

		set_pev( iEnt, pev_angles, flAngles );
	}

	new CsTeams:iTeam = cs_get_user_team( iOwner );
	if ( iTeam != gPlayerTeam[ iOwner ] )
	{
		if (get_pcvar_num(gCvarGlow))
		{
			set_rendering( iEnt, kRenderFxGlowShell, gTeamColors[ iTeam ][ 0 ], gTeamColors[ iTeam ][ 1 ], gTeamColors[ iTeam ][ 2 ], kRenderNormal, 3 );
		}

		if ( iTeam == CS_TEAM_T || iTeam == CS_TEAM_CT  )
		{
			gPlayerTeam[ iOwner ] = iTeam;
			set_pev( iEnt, pev_skin, gPlayerTeam[ iOwner ] );
		}
		else
		{
			return PLUGIN_CONTINUE;
		}
	}
		
	new iStatus = entity_get_int( iEnt, EV_INT_iuser3 );
	if ( iStatus != STATUS_ACTIVE )
	{
		return PLUGIN_CONTINUE;
	}
	
	new iMaxHealth = get_pcvar_num( gCvarMaxHealth );
	new iMaxArmor = get_pcvar_num( gCvarMaxArmor );
	new Float:flReplenishRadius = get_pcvar_float( gCvarReplenishRadius );
	new Float:flDispenserOrigin[ 3 ];
	
	flDispenserOrigin = gDispenserOrigin[ iOwner ];
	
	for( new iPlayer = 1; iPlayer <= gMaxPlayers; ++iPlayer )
	{

		if( !is_user_alive( iPlayer ) || ( cs_get_user_team( iPlayer ) != iTeam ) )
		{
			continue;
		}
		
		new Float:flOrigin[ 3 ];
		entity_get_vector( iPlayer, EV_VEC_origin, flOrigin );

		new Float:flDistance = get_distance_f( flDispenserOrigin, flOrigin );
		
		if( flDistance > flReplenishRadius || !UTIL_IsVisible( iPlayer, iEnt ))
		{
			continue;
		}
		
		UTIL_GiveWeaponAmmo( iPlayer );

		new iHealth = get_user_health( iPlayer );
		new iArmor  = get_user_armor( iPlayer );
		
		if( iHealth < iMaxHealth )
		{
			set_user_health( iPlayer, iHealth + 1 );
		}

		if( iArmor < iMaxArmor )
		{
			set_user_armor( iPlayer, iArmor + 1 );
		}
		// UTIL_BeamEnts( gDispenserOrigin[ iOwner ], flOrigin, gBeamcolor[ iOwner ][ x_r ], gBeamcolor[ iOwner ][ y_g ], gBeamcolor[ iOwner ][ z_b ] );
	}
	
	// set_hudmessage( gBeamcolor[ iOwner ][ x_r ], gBeamcolor[ iOwner ][ y_g ], gBeamcolor[ iOwner ][ z_b ], 0.0, 0.21, 1, 6.0, 0.2 );
	// ShowSyncHudMsg( iOwner, gHudSync, ">>>[ Dispenser ]<<<^n^nHealth Status: [%d]", floatround( gDispenserHealthOff[ iOwner ] ) );
	
	return PLUGIN_CONTINUE;
}

public PlayerSpawn( iPlayer )
{
	CheckStuck( iPlayer );
}


// Automatic Unstucking by Ramono, revised by lonewolf
// https://forums.alliedmods.net/showthread.php?p=441576?p=441576
new const Float:flSize[][3] = {
	{0.0, 0.0, 1.0}, {0.0, 0.0, -1.0}, {0.0, 1.0, 0.0}, {0.0, -1.0, 0.0}, {1.0, 0.0, 0.0}, {-1.0, 0.0, 0.0}, {-1.0, 1.0, 1.0}, {1.0, 1.0, 1.0}, {1.0, -1.0, 1.0}, {1.0, 1.0, -1.0}, {-1.0, -1.0, 1.0}, {1.0, -1.0, -1.0}, {-1.0, 1.0, -1.0}, {-1.0, -1.0, -1.0},
	{0.0, 0.0, 2.0}, {0.0, 0.0, -2.0}, {0.0, 2.0, 0.0}, {0.0, -2.0, 0.0}, {2.0, 0.0, 0.0}, {-2.0, 0.0, 0.0}, {-2.0, 2.0, 2.0}, {2.0, 2.0, 2.0}, {2.0, -2.0, 2.0}, {2.0, 2.0, -2.0}, {-2.0, -2.0, 2.0}, {2.0, -2.0, -2.0}, {-2.0, 2.0, -2.0}, {-2.0, -2.0, -2.0},
	{0.0, 0.0, 3.0}, {0.0, 0.0, -3.0}, {0.0, 3.0, 0.0}, {0.0, -3.0, 0.0}, {3.0, 0.0, 0.0}, {-3.0, 0.0, 0.0}, {-3.0, 3.0, 3.0}, {3.0, 3.0, 3.0}, {3.0, -3.0, 3.0}, {3.0, 3.0, -3.0}, {-3.0, -3.0, 3.0}, {3.0, -3.0, -3.0}, {-3.0, 3.0, -3.0}, {-3.0, -3.0, -3.0},
	{0.0, 0.0, 4.0}, {0.0, 0.0, -4.0}, {0.0, 4.0, 0.0}, {0.0, -4.0, 0.0}, {4.0, 0.0, 0.0}, {-4.0, 0.0, 0.0}, {-4.0, 4.0, 4.0}, {4.0, 4.0, 4.0}, {4.0, -4.0, 4.0}, {4.0, 4.0, -4.0}, {-4.0, -4.0, 4.0}, {4.0, -4.0, -4.0}, {-4.0, 4.0, -4.0}, {-4.0, -4.0, -4.0},
	{0.0, 0.0, 5.0}, {0.0, 0.0, -5.0}, {0.0, 5.0, 0.0}, {0.0, -5.0, 0.0}, {5.0, 0.0, 0.0}, {-5.0, 0.0, 0.0}, {-5.0, 5.0, 5.0}, {5.0, 5.0, 5.0}, {5.0, -5.0, 5.0}, {5.0, 5.0, -5.0}, {-5.0, -5.0, 5.0}, {5.0, -5.0, -5.0}, {-5.0, 5.0, -5.0}, {-5.0, -5.0, -5.0}
};

public CheckStuck( iPlayer ) 
{
	static Float:flOrigin[3];
	static Float:flMins[3]; 
	static Float:flVec[3];
	static iHull;
	static i;
	
	if ( !is_user_alive(iPlayer) || 
	     get_user_noclip( iPlayer ) ||
	     ( entity_get_int( iPlayer, EV_INT_solid) & SOLID_NOT ) ) 
	{
		return;
	}
	
	entity_get_vector( iPlayer, EV_VEC_origin, flOrigin);
	iHull = ( get_entity_flags( iPlayer ) & FL_DUCKING ) ? HULL_HEAD : HULL_HUMAN;
	
	if ( IsHullVacant( flOrigin, iHull, iPlayer ) ) 
	{
		return;
	}
	
	entity_get_vector( iPlayer, EV_VEC_mins, flMins );
	
	new s = sizeof ( flSize );
	for ( i = 0; i < s; ++i ) 
	{
		flVec[0] = flOrigin[0] - flMins[0] * flSize[i][0];
		flVec[1] = flOrigin[1] - flMins[1] * flSize[i][1];
		flVec[2] = flOrigin[2] - flMins[2] * flSize[i][2];
		
		if ( IsHullVacant( flVec, iHull, iPlayer ) ) 
		{
			static Float:vecZeros[3] = { 0.0, 0.0, 0.0 };
			
			entity_set_origin( iPlayer, flVec );
			entity_set_vector( iPlayer, EV_VEC_velocity, vecZeros );
			
			client_cmd( iPlayer,"spk fvox/blip.wav" );
			return;
		}
	}
}

stock bool:IsHullVacant( const Float:flOrigin[3], iHull, iPlayer ) 
{
	static tr;
	// engfunc( EngFunc_TraceHull, flOrigin, flOrigin, 0, iHull, iPlayer, tr );
	trace_hull( flOrigin, iHull, iPlayer, IGNORE_MONSTERS );
	
	return ( !traceresult( tr, TR_StartSolid) || !traceresult( tr, TR_AllSolid ) );
}


public BuildDispenserSolid( iEntity )
{
	if( !pev_valid( iEntity ))
	{
		return PLUGIN_CONTINUE;
	}
	
	if (get_pcvar_num(gCvarGlow))
	{
		new iOwner = pev( iEntity, pev_iuser2 );
		new CsTeams:iTeam = cs_get_user_team( iOwner );
		set_rendering( iEntity, kRenderFxGlowShell, gTeamColors[ iTeam ][ 0 ], gTeamColors[ iTeam ][ 1 ], gTeamColors[ iTeam ][ 2 ], kRenderNormal, 3 );
	}
	else
	{
		set_rendering( iEntity );
	}
	
	set_pev( iEntity, pev_solid, SOLID_BBOX );
	set_pev( iEntity, pev_iuser3, STATUS_ACTIVE );
	
	engfunc( EngFunc_DropToFloor, iEntity );
	
	emit_sound( iEntity, CHAN_STATIC, gDispenserActive, VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
	
	set_task( 0.1, "CheckAllStucked", iEntity );

	return PLUGIN_CONTINUE;
}


public CheckAllStucked( iEntity )
{
	if( !pev_valid( iEntity ))
	{
		return PLUGIN_CONTINUE;
	}

	new Float:flDispenserOrigin[ 3 ];
	entity_get_vector( iEntity, EV_VEC_origin, flDispenserOrigin);
	
	new iOwner = entity_get_int( iEntity, EV_INT_iuser2);
	gDispenserOrigin[ iOwner ] = flDispenserOrigin;
	
	for ( new iPlayer = 1; iPlayer <= gMaxPlayers; ++iPlayer )
	{
		if ( !is_user_alive( iPlayer ) )
		{
			continue;
		}
		
		new Float:flOrigin[ 3 ];
		entity_get_vector( iPlayer, EV_VEC_origin, flOrigin );
		
		new Float:flDistance = get_distance_f( flDispenserOrigin, flOrigin );
		
		if ( flDistance <= 48.0 )
		{
			CheckStuck( iPlayer );
		}
	}
	
	return PLUGIN_CONTINUE;
}


public EVENT_TextMsg( )
{
	UTIL_DestroyDispensers( );
}

public LOG_RoundEnd( )
{
	UTIL_DestroyDispensers( );
}


/*
	~~~~~~~~~~~~~~~~~~~~~~~
		Stocks
	~~~~~~~~~~~~~~~~~~~~~~~
*/


stock UTIL_DestroyDispensers( )
{
	new iEnt = FM_NULLENT;

	while( ( iEnt = find_ent_by_class( iEnt, gDispenserClassname ) ) )
	{
		new iOwner = pev( iEnt, pev_iuser2 );

		bDispenserBuild[ iOwner ] = false;
		set_pev( iEnt, pev_flags, pev( iEnt, pev_flags ) | FL_KILLME );
	}
}

stock UTIL_BreakModel( Float:flOrigin[ 3 ], model, flags )
{
	engfunc( EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, flOrigin, 0 );
	write_byte( TE_BREAKMODEL );
	engfunc( EngFunc_WriteCoord, flOrigin[ 0 ] );
	engfunc( EngFunc_WriteCoord, flOrigin[ 1 ] );
	engfunc( EngFunc_WriteCoord, flOrigin[ 2 ] );
	write_coord( 16 );
	write_coord( 16 );
	write_coord( 16 );
	write_coord( random_num( -20, 20 ) );
	write_coord( random_num( -20, 20 ) );
	write_coord( 10 );
	write_byte( 10 );
	write_short( model );
	write_byte( 10 );
	write_byte( 9 );
	write_byte( flags );
	message_end( );
}

stock UTIL_BeamEnts( Float:flStart[ 3 ], Float:flEnd[ 3 ], r, g, b )
{
	engfunc( EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, flStart );
	write_byte( TE_BEAMPOINTS );
	engfunc( EngFunc_WriteCoord, flStart[ 0 ] );
	engfunc( EngFunc_WriteCoord, flStart[ 1 ] );
	engfunc( EngFunc_WriteCoord, flStart[ 2 ] );
	engfunc( EngFunc_WriteCoord, flEnd[ 0 ] );
	engfunc( EngFunc_WriteCoord, flEnd[ 1 ] );
	engfunc( EngFunc_WriteCoord, flEnd[ 2 ] );
	write_short( gHealingBeam );
	write_byte( 5 );
	write_byte( 2 );
	write_byte( 1 );
	write_byte( 80 );
	write_byte( 1 );
	write_byte( r );
	write_byte( g );
	write_byte( b );
	write_byte( 130 );
	write_byte( 0 );
	message_end( );
}

stock UTIL_GiveWeaponAmmo( index )
{
	new szCopyAmmoData[ 40 ];

	switch( get_user_weapon( index ) )
	{
		case CSW_P228: copy( szCopyAmmoData, charsmax( szCopyAmmoData ), "ammo_357sig" );
		case CSW_SCOUT, CSW_G3SG1, CSW_AK47: copy( szCopyAmmoData, charsmax( szCopyAmmoData ), "ammo_762nato" );
		case CSW_XM1014, CSW_M3: copy( szCopyAmmoData, charsmax( szCopyAmmoData ), "ammo_buckshot" );
		case CSW_MAC10, CSW_UMP45, CSW_USP: copy( szCopyAmmoData, charsmax( szCopyAmmoData ), "ammo_45acp" );
		case CSW_SG550, CSW_GALIL, CSW_FAMAS, CSW_M4A1, CSW_SG552, CSW_AUG: copy( szCopyAmmoData, charsmax( szCopyAmmoData ), "ammo_556nato" );
		case CSW_ELITE, CSW_GLOCK18, CSW_MP5NAVY, CSW_TMP: copy( szCopyAmmoData, charsmax( szCopyAmmoData ), "ammo_9mm" );
		case CSW_AWP: copy( szCopyAmmoData, charsmax( szCopyAmmoData ), "ammo_338magnum" );
		case CSW_M249: copy( szCopyAmmoData, charsmax( szCopyAmmoData ), "ammo_556natobox" );
		case CSW_FIVESEVEN, CSW_P90: copy( szCopyAmmoData, charsmax( szCopyAmmoData ), "ammo_57mm" );
		case CSW_DEAGLE: copy( szCopyAmmoData, charsmax( szCopyAmmoData ), "ammo_50ae" );
	}

	give_item( index, szCopyAmmoData );
}

stock UTIL_Sparks( Float:flOrigin[ 3 ] )
{
	engfunc( EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, flOrigin, 0 );
	write_byte( TE_SPARKS );
	engfunc( EngFunc_WriteCoord, flOrigin[ 0 ] );
	engfunc( EngFunc_WriteCoord, flOrigin[ 1 ] );
	engfunc( EngFunc_WriteCoord, flOrigin[ 2 ] );
	message_end( );
}

stock bool:UTIL_IsVisible( index, entity, ignoremonsters = 0 )
{
	new Float:flStart[ 3 ], Float:flDest[ 3 ];
	pev( index, pev_origin, flStart );
	pev( index, pev_view_ofs, flDest );

	xs_vec_add( flStart, flDest, flStart );

	pev( entity, pev_origin, flDest );
	engfunc( EngFunc_TraceLine, flStart, flDest, ignoremonsters, index, 0 );

	new Float:flFraction;
	get_tr2( 0, TR_flFraction, flFraction );

	if( flFraction == 1.0 || get_tr2( 0, TR_pHit) == entity )
	{
		return true;
	}

	return false;
}

/*
	~~~~~~~~~~~~~~~~~~~~~~~
		  End of Code
	~~~~~~~~~~~~~~~~~~~~~~~
*/
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ ansicpg1252\\ deff0\\ deflang1046{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ f0\\ fs16 \n\\ par }
*/
