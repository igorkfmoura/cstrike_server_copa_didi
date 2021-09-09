#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <json>

#define PLUGIN  "UserAuthentication"
#define VERSION "0.2"
#define AUTHOR  "lonewolf"

static const CHAT_PREFIX[] = "^4[UserAuthentication]^1";

static const info_name[] = "name";

static const prefix_unauth[] = "[???] ";

static const nick[]   = "lonewolf";
static const prefix[] = "TESTE ' ";
static const auth[]   = "STEAM_0:0:8354200";

new JSON_FILE[32] = "auth.json";
new JSON_PATH[128];
new CONFIG_PATH[96];

enum _:Clans
{
  AST,
  BRA,
  EP1C,
  FNG,
  KNG,
  RCT,
  OKX,
  EFNG,
  STAFF
};

new clan_names[Clans][32];
new clan_prefixes[Clans][32];
new clan_nicks[Clans][30][32];
new clan_auths[Clans][30][32];

static nick_formated[33][32];

new JSON:root;

public plugin_init()
{
  register_plugin(PLUGIN, VERSION, AUTHOR);

  auth_load();
  register_concmd("auth_reload", "auth_reload", ADMIN_CVAR);

  register_forward(FM_ClientUserInfoChanged, "event_ClientUserInfoChanged");
}

public auth_reload()
{
  for (new i = 0; i < STAFF; ++i)
  {
    clan_names[i][0] = '^0';
    clan_prefixes[i][0] = '^0';
    for (new j = 0; j < 30; ++j)
    {
      clan_nicks[i][j][0] = '^0';
      clan_auths[i][j][0] = '^0';
    }
  }

  auth_load();
}

public auth_load()
{
  get_configsdir(CONFIG_PATH, charsmax(CONFIG_PATH));

  formatex(JSON_PATH, charsmax(JSON_PATH), "%s/%s", CONFIG_PATH, JSON_FILE);

  server_print("[%s] Parsing '%s'...", PLUGIN, JSON_PATH);
  root = json_parse(JSON_PATH, .is_file=true, .with_comments=true);

  // new buffer[1024];
  // json_serial_to_string(root, buffer, charsmax(buffer));

  new JSON:clans = json_object_get_value(root, "clans");
  new JSON:tmp;
  new JSON:members;
  new JSON:member;
  
  new len = json_array_get_count(clans); // todo: check size < Clans
  
  for (new i = 0; i < len; ++i)
  {
    tmp = json_array_get_value(clans, i);
    if (tmp != Invalid_JSON)
    {
      json_object_get_string(tmp, "name", clan_names[i], 31);
      json_object_get_string(tmp, "prefix", clan_prefixes[i], 31);

      members = json_object_get_value(tmp, "members");
      new len2 = json_array_get_count(members);
      for (new j = 0; j < len2; ++j)
      {
        member = json_array_get_value(members, j);
        if (member != Invalid_JSON)
        {
          json_object_get_string(member, "nick", clan_nicks[i][j], 31);
          json_object_get_string(member, "auth", clan_auths[i][j], 31);
        }

        // server_print("%s%s - %s", clan_prefixes[i], clan_nicks[i][j], clan_auths[i][j]);
      }  
    }
  }

  json_free(member); 
  json_free(members); 
  json_free(tmp); 
  json_free(clans);

  server_print("[%s] '%s' OK", PLUGIN, JSON_PATH);
}


public client_disconnected(id)
{
  nick_formated[id][0] = '^0';
}


public client_authorized(id)
{
  static user_auth[32];
  static user_name[32];
  static user_ip[32];
  // static log[196];

  nick_formated[id][0] = '^0';
  get_user_authid(id, user_auth, charsmax(user_auth));
  get_user_info(id, info_name, user_name, charsmax(user_name));
  get_user_ip(id, user_ip, charsmax(user_ip));

  log_amx("'%s' <%s> (%s) entered the server.", user_name, user_auth, user_ip);

  new bool:found = false;
  new i, j;
  for (i = 0; i < STAFF; ++i)
  {
    for (j = 0; j < 30; ++j)
    {
      if (!clan_auths[i][j][0])
      {
        break;
      }

      // server_print("AUTH: %s, clan_auths[%d][%d]: %s", user_auth, i, j, clan_auths[i][j]);
      if (equali(user_auth, clan_auths[i][j]))
      {
        found = true;
        break;
      }
    }
    
    if (found)
    {
      break;
    }
  }
  
  if (!found)
  {
    // event_ClientUserInfoChanged(id);
    return;
  }
  
  // server_print("[client_authorized] id: %d, i: %d, j: %d, clan_prefix: %s", id, i, j, clan_prefixes[i]);

  formatex(nick_formated[id], 31, "%s%s", clan_prefixes[i], clan_nicks[i][j]);

  // server_print(nick_formated[id]);
  // server_print("AUTH: name_old: %s, name_new: %s", name_old, nick_formated[id]);
  if (!equal(user_name, nick_formated[id]))
  {
    // server_print("AUTH: setting name: %s", nick_formated[id]);
    set_user_info(id, info_name, nick_formated[id]);
  }

  // set_user_info(id, info_name, "mnbmnbmnb");

}

public event_ClientUserInfoChanged(id) 
{ 
  if (!is_user_connected(id))
  {
    return FMRES_HANDLED;
  }

  // server_print("ClientUserInfoChanged: buffer: %c", buffer);

  static name_old[32];
  static name_new[32];

  entity_get_string(id, EV_SZ_netname, name_old, charsmax(name_old));
  get_user_info(id, info_name, name_new, charsmax(name_new)) 
    
  // server_print("ClientUserInfoChanged: name_old: %s, name_new: %s", name_old, name_new);
  
  if (nick_formated[id][0])
  { 
    if (!equal(name_new, nick_formated[id])) 
    { 
      // server_print("ClientUserInfoChanged: setting name: %s", nick_formated[id]);
      set_user_info(id, info_name, nick_formated[id]);
      return FMRES_SUPERCEDE;
    }

    return FMRES_IGNORED;
  }

  if (!equali(prefix_unauth, name_new, charsmax(prefix_unauth)))
  {
    format(name_new, charsmax(name_new), "%s%s", prefix_unauth, name_new);

    if (!equal(name_new, name_old))
    {
      // server_print("ClientUserInfoChanged: setting name: %s", name_new);
      set_user_info(id, info_name, name_new);
      return FMRES_SUPERCEDE;
    }
  }

  return FMRES_IGNORED;
} 
