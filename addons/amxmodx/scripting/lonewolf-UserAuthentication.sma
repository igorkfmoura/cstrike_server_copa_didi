#include <amxmodx>
#include <engine>
#include <fakemeta>

#define PLUGIN  "UserAuthentication"
#define VERSION "0.1"
#define AUTHOR  "lonewolf"

static const CHAT_PREFIX[] = "^4[UserAuthentication]^1";

static const info_name[] = "name";

static const prefix_unauth[] = "[???] ";

static const nick[]   = "lonewolf";
static const prefix[] = "TESTE ' ";
static const auth[]   = "STEAM_0:0:8354200";

static nick_formated[33][32];


public plugin_init()
{
  register_plugin(PLUGIN, VERSION, AUTHOR);

  register_forward(FM_ClientUserInfoChanged, "event_ClientUserInfoChanged");
}


public client_disconnected(id)
{
  nick_formated[id][0] = '^0';
}


public client_authorized(id)
{
  static user_auth[32];
  static name_old[32];
  static name_new[32];

  nick_formated[id][0] = '^0';
  get_user_authid(id, user_auth, charsmax(user_auth));

  server_print("AUTH: %s - %s", user_auth, auth);
  if (!equali(user_auth, auth))
  {
    return;
  }

  get_user_info(id, info_name, name_old, charsmax(name_old));
  formatex(nick_formated[id], 31, "%s%s", prefix, nick);

  server_print("AUTH: name_old: %s, name_new: %s", name_old, nick_formated[id]);
  if (!equal(name_old, nick_formated[id]))
  {
    server_print("AUTH: setting name: %s", nick_formated[id]);
    set_user_info(id, info_name, nick_formated[id]);
  }

  // set_user_info(id, info_name, "mnbmnbmnb");

}

public event_ClientUserInfoChanged(id, buffer) 
{ 
  if (!is_user_connected(id))
  {
    return FMRES_HANDLED;
  }

  server_print("ClientUserInfoChanged: buffer: %c", buffer);

  static name_old[32];
  static name_new[32];

  entity_get_string(id, EV_SZ_netname, name_old, charsmax(name_old));
  get_user_info(id, info_name, name_new, charsmax(name_new)) 
    
  server_print("ClientUserInfoChanged: name_old: %s, name_new: %s", name_old, name_new);
  
  if (nick_formated[id][0])
  { 
    if (!equal(name_new, nick_formated[id])) 
    { 
      server_print("ClientUserInfoChanged: setting name: %s", nick_formated[id]);
      set_user_info(id, info_name, nick_formated[id]);
      return FMRES_SUPERCEDE;
    }

    return FMRES_IGNORED;
  }

  format(name_new, charsmax(name_new), "%s%s", prefix_unauth, name_new);

  if (!equal(name_new, name_old))
  {
    server_print("ClientUserInfoChanged: setting name: %s", name_new);
    set_user_info(id, info_name, name_new);
    return FMRES_SUPERCEDE;
  }


  return FMRES_IGNORED;
} 
