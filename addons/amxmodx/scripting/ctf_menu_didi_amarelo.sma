#include <amxmodx>
#include <engine>
#include <xs>

#define PLUGIN  "ctf-menu-n"
#define VERSION "0.1"
#define AUTHOR  "lonewolf"

#define PREFIX_CHAT "^4[COPA DO DIDI]^1"
#define PREFIX_MENU "\yCOPA DO DIDI"

public plugin_init()
{
  register_plugin(PLUGIN, VERSION, AUTHOR)
  
  register_clcmd("say /menu", "cmd_menu");
  register_clcmd("say .menu", "cmd_menu");
  register_clcmd("say_team /menu", "cmd_menu");
  register_clcmd("say_team .menu", "cmd_menu");

  register_clcmd("nightvision", "cmd_menu");
}


public cmd_menu(id)
{
  if (is_user_connected(id))
  {
    menu_n(id);
  }

  return PLUGIN_HANDLED;
}


public menu_n(id)
{
  new menu = menu_create(fmt("%s - Menu Principal", PREFIX_MENU), "menu_n_handler");

  menu_additem(menu, "Menu de Armas \d(say /armas)");
  menu_additem(menu, "Dropar bandeira \d(say /dropflag)");
  //menu_additem(menu, "Botar Dispenser \d(say /disp)");
  menu_additem(menu, "Destruir Dispenser \d(say /destroy)");
  menu_additem(menu, "Menu de Adrenalina \d(say /adrenaline)");
  //menu_additem(menu, "Seu Rank e Top 15");
  menu_addblank2(menu);
  menu_additem(menu, "\rMenu de admin \d(say /admin)", _, ADMIN_CFG);

  menu_display(id, menu);
}


public menu_n_handler(id, menu, item)
{
  if (!is_user_connected(id) || item == MENU_EXIT)
  {
    menu_destroy(menu);
    return PLUGIN_HANDLED;
  }

  switch (item)
  {
    case 0: client_cmd(id, "say /armas");
    case 1: client_cmd(id, "say /dropflag");
    // case 1: client_cmd(id, "say /disp");
    case 2: client_cmd(id, "say /destroy");
    case 3: client_cmd(id, "say /adrenaline");
    case 4: menu_n_rank(id);
    case 5: client_cmd(id, "amxmodmenu");
  }

  menu_destroy(menu);
  return PLUGIN_HANDLED;
}


public menu_n_rank(id)
{
  new menu = menu_create(fmt("%s - Menu Ranks", PREFIX_MENU), "menu_n_rank_handler");

  menu_additem(menu, "Seu rank \d(say /rank)");
  menu_additem(menu, "Top15 \d(say /top15)", _, ADMIN_CFG);

  menu_setprop(menu, MPROP_EXITNAME, "Voltar");
  menu_display(id, menu);
}


public menu_n_rank_handler(id, menu, item)
{
  if (!is_user_connected(id))
  {
    menu_destroy(menu);
    return PLUGIN_HANDLED;
  }

  if (item == MENU_EXIT)
  {
    menu_destroy(menu);
    menu_n(id);
    return PLUGIN_HANDLED;
  }

  switch (item)
  {
    case 0: client_cmd(id, "say /rank");
    case 1: client_cmd(id, "say /top15");
  }

  menu_destroy(menu);
  return PLUGIN_HANDLED;
}

