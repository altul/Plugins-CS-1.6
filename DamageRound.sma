#include <amxmodx>
#include <reapi>

#if AMXX_VERSION_NUM < 183
#include <colorchat>
#endif

#define PLUGIN "Top Round Damage"
#define VERSION "1.0.4 ReAPI"
#define AUTHOR "Dager* *.* -G-"

#if !defined MAX_PLAYERS
#define MAX_PLAYERS 32
#endif

#if !defined MAX_NAME_LENGTH
#define MAX_NAME_LENGTH 32
#endif

#define IsPlayer(%1)    (1 <= %1 <= g_iMaxPlayers)
#define ClearArr(%1)    arrayset(_:%1, _:0.0, sizeof(%1))
#define MENU_KEYS       (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9)

/* настройки */
#define CHAT_PREFIX     "^4[Сервер]"  // prefix
#define TOP_PLAYERS     5             // the number of players displayed in the top according to the damage [more than 10 it makes no sense to indicate]
#define MIN_PLAYERS     2             // minimum number of players to display the top
#define ROUND_NUMBER    1             // which round to deduce
#define SHOW_TIME       5             // after how many seconds will the menu of the best damage players per round be closed [integer]
#define GIVE_MONEY      500           // how much money to give to the best player
#define GIVE_AWARD                    // comment if you do not want to give an award to the best player

/* не трогать всё что ниже*/

enum _:ePlayerData
{
	PLAYER_ID,
	DAMAGE,
	KILLS
};

new g_arrData[MAX_PLAYERS + 1][ePlayerData];
new g_iPlayerDmg[MAX_PLAYERS + 1];
new g_iPlayerKills[MAX_PLAYERS + 1];
new g_iRoundCounter;
new g_iMaxPlayers;
new bool:g_bIsSwitch[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_clcmd("say /damage", "cmdTopDamageSwitch");
	register_clcmd("say_team /damage", "cmdTopDamageSwitch");
	
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", false);
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "CBasePlayer_TakeDamage", true);
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed", true);
	RegisterHookChain(RG_RoundEnd, "RoundEnd", true);
	
	register_menucmd(register_menuid("TopDmg"), MENU_KEYS, "fnTopDmgHandler");
	
	g_iMaxPlayers = get_member_game(m_nMaxPlayers);
}

public client_putinserver(id)
{
	// initial values ​​to the logged in player
	g_iPlayerDmg[id] = 0;
	g_iPlayerKills[id] = 0;
	g_bIsSwitch[id] = true;
}

public cmdTopDamageSwitch(id)
{
	g_bIsSwitch[id] = !g_bIsSwitch[id];
	
	new szSwitch[20];
	formatex(szSwitch, charsmax(szSwitch), "%s", g_bIsSwitch[id] ? "included" : "disconnected");
	
	client_print_color(id, print_team_default,
		"%s ^1You %s display ^4[top-%d by damage] ^1per round!",
		CHAT_PREFIX, szSwitch, TOP_PLAYERS
	);
	
	return PLUGIN_CONTINUE;
}

public CSGameRules_RestartRound_Pre()
{
	if(get_member_game(m_bCompleteReset))
		g_iRoundCounter = 0;
	
	g_iRoundCounter++;
	
	// cleaning data arrays
	ClearArr(g_iPlayerDmg);
	ClearArr(g_iPlayerKills);
	
	for(new i = 1; i <= g_iMaxPlayers; i++)
		arrayset(g_arrData[i], 0, ePlayerData);
}

public CBasePlayer_TakeDamage(const pevVictim, pevInflictor, const pevAttacker, Float:flDamage, bitsDamageType)
{
	if(pevVictim == pevAttacker || !IsPlayer(pevAttacker) || (bitsDamageType & DMG_BLAST))
		return HC_CONTINUE;
	
	if(rg_is_player_can_takedamage(pevVictim, pevAttacker))
		g_iPlayerDmg[pevAttacker] += floatround(flDamage);
	
	return HC_CONTINUE;
}

public CBasePlayer_Killed(const Victim, Attacker)
{
	if(!is_user_connected(Victim) || Victim == Attacker || !IsPlayer(Attacker) || get_member(Victim, m_iTeam) == get_member(Attacker, m_iTeam))
		return HC_CONTINUE;
	
	g_iPlayerKills[Attacker]++;
	
	return HC_CONTINUE;
}

public fnCompareDamage()
{
	new iPlayers[MAX_PLAYERS], iNum, iPlayer;
#if defined GIVE_AWARD
	new szName[MAX_NAME_LENGTH], pBestPlayerId, pBestPlayerDamage;
#endif
	get_players(iPlayers, iNum, "h");
	
	// info collection cycle for all players
	for(new i; i < iNum; i++)
	{
		iPlayer = iPlayers[i];
		
		g_arrData[i][PLAYER_ID] = iPlayer;
		g_arrData[i][DAMAGE] = _:g_iPlayerDmg[iPlayer];
		g_arrData[i][KILLS] = _:g_iPlayerKills[iPlayer];
	}
	
	// сортировка массива
	SortCustom2D(g_arrData, sizeof(g_arrData), "SortRoundDamage");
	
#if defined GIVE_AWARD
	// getting the id of the best player after sorting (1st element of the array)
	pBestPlayerId = g_arrData[0][PLAYER_ID];
	// also taking damage from the best player
	pBestPlayerDamage = g_arrData[0][DAMAGE];
	
	// checks on the validity of this player and damage (if damage is 0, then do not give a reward)
	if(IsPlayer(pBestPlayerId) && is_user_connected(pBestPlayerId) && pBestPlayerDamage >= 1)
	{
		get_user_name(pBestPlayerId, szName, charsmax(szName));
		rg_add_account(pBestPlayerId, GIVE_MONEY, AS_ADD, true);
		
		client_print_color(0, print_team_default,
			"%s ^3%s ^1dealt the most damage [^4%d^1] and gets [^4%d^3$^1].",
			CHAT_PREFIX, szName, pBestPlayerDamage, GIVE_MONEY
		);
	}
#endif
	
	return PLUGIN_HANDLED;
}

// функция сравнения для сортировки
public SortRoundDamage(const elem1[], const elem2[])
{
	// сравнение дамага
	return (elem1[DAMAGE] < elem2[DAMAGE]) ? 1 : (elem1[DAMAGE] > elem2[DAMAGE]) ? -1 : 0;
}

public RoundEnd()
{
	if(g_iRoundCounter >= ROUND_NUMBER)
	{
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "h");
		
		// если игроков меньше чем выставленное значение MIN_PLAYERS, то прерываем
		if(iNum >= MIN_PLAYERS)
		{
			// таск с задежкой для сравнения урона игроков (без него будет неточность последнего попадания)
			// при игре 1х1 и убийстве противника с одного патрона думаю станет ясно, что это значит и для чего таск
			set_task(0.1, "fnCompareDamage");
			// таск на отображение списка
			set_task(0.2, "fnShowStats");
		}
	}
}

public fnShowStats()
{
	new iPlayers[MAX_PLAYERS], iNum, szMenu[512], szName[MAX_NAME_LENGTH], iLen, iPlayer;
	new bool:bMenuDmgShow;
	get_players(iPlayers, iNum, "h");
	
	iLen = formatex(szMenu, charsmax(szMenu), "\w#. \r[\yDamage\r] [\yFrags\r] \wper round:^n^n");
	
	// проверка если игроков на сервере меньше чем выставлено TOP_PLAYERS
	if(iNum < TOP_PLAYERS)
	{
		// то не делаем лишних итераций до TOP_PLAYERS
		for(new i; i < iNum; i++)
		{
			// для тех, кому надо выводить игроков с 0 уроном, закомментировать 2 строки ниже
			if(g_arrData[i][DAMAGE] <= 0)
				continue;
			
			get_user_name(g_arrData[i][PLAYER_ID], szName, charsmax(szName));
			
			// форматирование красивого меню в столбик
			if(0 <= g_arrData[i][DAMAGE] < 10)
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\w%d. \r[\y00%d\r] [\y%d\r] \w%s^n", i + 1, g_arrData[i][DAMAGE], g_arrData[i][KILLS], szName);
			else if(10 <= g_arrData[i][DAMAGE] < 100)
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\w%d. \r[\y0%d\r] [\y%d\r] \w%s^n", i + 1, g_arrData[i][DAMAGE], g_arrData[i][KILLS], szName);
			else
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\w%d. \r[\y%d\r] [\y%d\r] \w%s^n", i + 1, g_arrData[i][DAMAGE], g_arrData[i][KILLS], szName);
			
			bMenuDmgShow = true;
		}
	}
	else
	{
		// пробегаем лучших игроков до TOP_PLAYERS
		for(new i; i < TOP_PLAYERS; i++)
		{
			// для тех, кому надо выводить игроков с 0 уроном, закомментировать 2 строки ниже
			if(g_arrData[i][DAMAGE] <= 0)
				continue;
			
			get_user_name(g_arrData[i][PLAYER_ID], szName, charsmax(szName));
			
			// форматирование красивого меню в столбик
			if(0 <= g_arrData[i][DAMAGE] < 10)
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\w%d. \r[\y00%d\r] [\y%d\r] \w%s^n", i + 1, g_arrData[i][DAMAGE], g_arrData[i][KILLS], szName);
			else if(10 <= g_arrData[i][DAMAGE] < 100)
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\w%d. \r[\y0%d\r] [\y%d\r] \w%s^n", i + 1, g_arrData[i][DAMAGE], g_arrData[i][KILLS], szName);
			else
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\w%d. \r[\y%d\r] [\y%d\r] \w%s^n", i + 1, g_arrData[i][DAMAGE], g_arrData[i][KILLS], szName);
			
			bMenuDmgShow = true;
		}
	}
	// если есть игроки в раунде с уроном
	if(bMenuDmgShow)
	{
		// показ всем игрокам список лучших игроков
		for(new i; i < iNum; i++)
		{
			iPlayer = iPlayers[i];
			
			// если игрок не выключил показ, то показываем
			if(g_bIsSwitch[iPlayer])
				show_menu(iPlayer, MENU_KEYS, szMenu, SHOW_TIME, "TopDmg");
		}
	}
	
	return PLUGIN_HANDLED;
}

// обработчик нажатия цифр для закрытия меню моментально
public fnTopDmgHandler(id, iKey)
{
	if(iKey >= 0 || iKey <= 9)
		return PLUGIN_CONTINUE;
	
	return PLUGIN_HANDLED;
}
