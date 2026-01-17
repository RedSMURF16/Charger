/*
*
*	Charger by RedSMURF
*
*
*	Description:
*   This plugin adds a dynamic charger system with a menu to select different charger types.
*   Each charger has its own model and configurable properties such as health, capacity, team, flags, activation delay, sounds, visibility, and more.
*   Chargers are fully manageable during gameplay, supporting respawn, visibility settings, and state transitions.
*
*	Cvars:
*		None
*
*	Commands:
*       say /charger                "Opens the charger menu."
*       say_team /charger           "Opens the charger menu."
*       charger_reload              "Reloads the configuration file."
*
*	Changelog:
*       v1.0: Initial release.
*       v1.1: Simplified BBox.
*       v1.2: Manual rotation (No floor placement),
*             Improved readability.
*       v1.3: Refills after a certain duration,
*             Used by a single player at a time,
*             All charger sounds are emitted from charger entities.
*       v1.4: Bug fixes,
*             Chargers can be placed against any surface,
*             Supports ROLL rotation.
*       v1.5: Optimized code with fixed bugs,
*             Added activation delay after round start,
*             Chargers can break or explode from damage,
*             Charger might break or explode after a certain amount of uses when it starts flickering.
*       v1.6: Improved Charger placement logic for natural alignment with ground and walls.
*       v2.0: Redesigned charger architecture for full dynamic control.
*             Chargers now support runtime management of visibility, team and spawn settings.
*
*/

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <xs>

#if !defined MAX_PLAYERS
    #define MAX_PLAYERS 32
#endif

#if !defined MAX_VALUE_LENGTH
    #define MAX_VALUE_LENGTH 64
#endif

#if !defined MAX_AUTHID_LENGTH
    #define MAX_AUTHID_LENGTH 64
#endif

#if !defined MAX_RESOURCE_PATH_LENGTH
    #define MAX_RESOURCE_PATH_LENGTH 128
#endif

#if !defined MAX_FILE_CELL_SIZE
    #define MAX_FILE_CELL_SIZE 192
#endif

#if !defined MAX_PLATFORM_PATH_LENGTH
    #define MAX_PLATFORM_PATH_LENGTH 256
#endif

#define MAX_ENT             32
#define TASK_ACTION         1248

#define BREAK_VELO_Z_MIN    7.0
#define BREAK_VELO_Z_MAX    12.0
#define BREAK_RANDOM_MIN    7
#define BREAK_RANDOM_MAX    12
#define BREAK_COUNT_MIN     4
#define BREAK_COUNT_MAX     7
#define BREAK_LIFE_MIN      10
#define BREAK_LIFE_MAX      15

#define BREAK_GLASS         1
#define BREAK_METAL         2
#define BREAK_FLESH         4
#define BREAK_WOOD          8
#define BREAK_CONCRETE      64
#define BREAK_MASK          (BREAK_GLASS | 0BREAK_METAL | BREAK_FLESH | BREAK_WOOD | BREAK_CONCRETE)

/**
 *  Charger animation sequences.
 */
#define CHARGER_SEQ_IDLE    0
#define CHARGER_SEQ_OFF     1

new const PLUGIN_VERSION[]          = "2.0"
new const Float:DELAY_ON_CONNECT    = 1.0
new const ERROR_FILE[]              = "Charger_ERRORS.log"

enum
{
    SECTION_NONE,
    SECTION_MAIN_SETTINGS,
    SECTION_CHARGER
}

enum
{
    CLASS_HEALTH,
    CLASS_HEV,
    CLASS_CIV
}

enum
{
    FLAG_BREAK          = (1 << 0),
    FLAG_EXPLODE        = (1 << 1),
    FLAG_WEAR           = (1 << 2),
    FLAG_SPARK          = (1 << 3),
    FLAG_SOUND          = (1 << 4),
    FLAG_GIB            = (1 << 5),

    FLAG_SHOW           = (1 << 6),
    FLAG_DEAD           = (1 << 7),
    FLAG_GHOST          = (1 << 8),
    FLAG_VALID          = (1 << 9),
    FLAG_SELECT         = (1 << 10)
}

enum
{
    SHOW_DEFAULT,
    SHOW_FORCE_HIDE,
    SHOW_FORCE_SHOW
}

enum
{
    TEAM_NONE,
    TEAM_T,
    TEAM_CT,
    TEAM_BOTH
}

enum
{
    SPAWN_NEVER,
    SPAWN_DELAY,
    SPAWN_ROUND_START
}

enum
{
    SOUND_HEALTH,
    SOUND_HEV
}

enum
{
    GIB_ALIEN,
    GIB_BIGMOM,
    GIB_BONE,
    GIB_BOOK,
    GIB_CINDER,
    GIB_COMPUTER,
    GIB_CONCRETE,
    GIB_FLESH,
    GIB_GARBAGE,
    GIB_GLASS,
    GIB_METALPLATE,
    GIB_MILCRATE,
    GIB_ROCK
}

enum
{
    MODE_HEALTH,
    MODE_ARMOR
}

enum _:MAIN_SETTINGS
{
    SETTING_DEFAULT_MODEL[MAX_RESOURCE_PATH_LENGTH],
    Float:SETTING_MINS_STANDARD[3],
    Float:SETTING_MAXS_STANDARD[3],
    Float:SETTING_MINS_CIVILIAN[3],
    Float:SETTING_MAXS_CIVILIAN[3],

    bool:SETTING_CHARGER_LOAD,
    bool:SETTING_CHARGER_ACTION,
    Float:SETTING_CHARGER_RANGE,
    Float:SETTING_OFFSET_BASE,
    Float:SETTING_OFFSET_MIN,
    Float:SETTING_OFFSET_MAX,
    Float:SETTING_OFFSET_STEP,
    Float:SETTING_OFFSET_FREQ,
    Float:SETTING_GHOST_FREQ,
    SETTING_GHOST_ALPHA,

    SETTING_GIB_ALIEN,
    SETTING_GIB_BIGMOM,
    SETTING_GIB_BONE,
    SETTING_GIB_BOOK,
    SETTING_GIB_CINDER,
    SETTING_GIB_COMPUTER,
    SETTING_GIB_CONCRETE,
    SETTING_GIB_FLESH,
    SETTING_GIB_GARBAGE,
    SETTING_GIB_GLASS,
    SETTING_GIB_METALPLATE,
    SETTING_GIB_MILCRATE,
    SETTING_GIB_ROCK,
    SETTING_SPRITE_ZEROGXPLODE,
    SETTING_SOUND_HEALTH_PLACE[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_HEALTH_USE[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_HEALTH_EMPTY[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_HEALTH_REMOVE[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_HEALTH_REFILL[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_HEV_PLACE[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_HEV_USE[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_HEV_EMPTY[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_HEV_REMOVE[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_HEV_REFILL[MAX_RESOURCE_PATH_LENGTH],
    Array:SETTING_SOUND_FLICKER,
    Array:SETTING_SOUND_BUST_CONCRETE,
    Array:SETTING_SOUND_BUST_CRATE,
    Array:SETTING_SOUND_BUST_FLESH,
    Array:SETTING_SOUND_BUST_GLASS,
    Array:SETTING_SOUND_BUST_METAL,

    SETTING_SOUND_MENU_NAV[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_MENU_REMOVE[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_MENU_ALERT[MAX_RESOURCE_PATH_LENGTH],

    SETTING_COLOR_ACTIVE[3],
    SETTING_COLOR_INACTIVE[3]
}

enum _:CHARGER
{
    CHARGER_ID,
    CHARGER_ITEM,
    CHARGER_SHOW,
    CHARGER_CLASS,
    CHARGER_FLAGS,
    CHARGER_TEAM,
    CHARGER_SOUND,
    CHARGER_MODE,
    CHARGER_BREAK_FLAG,
    CHARGER_GIB,
    CHARGER_BUST_SOUND,
    CHARGER_NAME[MAX_VALUE_LENGTH],
    CHARGER_MODEL[MAX_RESOURCE_PATH_LENGTH],

    Float:CHARGER_ORIGIN[3],
    Float:CHARGER_ANGLES[3],
    Float:CHARGER_MINS[3],
    Float:CHARGER_MAXS[3],

    Float:CHARGER_RATE,
    Float:CHARGER_DELAY,
    Float:CHARGER_CAPACITY,
    Float:CHARGER_CAPACITY_MAX,
    Float:CHARGER_LIMIT,
    Float:CHARGER_REFILL,
    Float:CHARGER_DELAY_ACTIVE,

    CHARGER_SPAWN_MODE,
    Float:CHARGER_SPAWN_MIN,
    Float:CHARGER_SPAWN_MAX,
    Float:CHARGER_SPAWN_CHANCE,
    Float:CHARGER_NEXT_SPAWN,

    Float:CHARGER_HEALTH,
    Float:CHARGER_OVERLOAD,
    Float:CHARGER_BREAK_RATIO,
    Float:CHARGER_BREAK_THRESHOLD,
    Float:CHARGER_BREAK_CHANCE,
    Float:CHARGER_EXPLODE_DAMAGE,
    Float:CHARGER_EXPLODE_RADIUS,

    Float:CHARGER_NEXT_USE,
    Float:CHARGER_NEXT_EMPTY,
    Float:CHARGER_NEXT_REFILL,
    Float:CHARGER_NEXT_FLICKER
}

enum _:PLAYER_DATA
{
    PDATA_NAME[MAX_VALUE_LENGTH],
    PDATA_AUTHID[MAX_AUTHID_LENGTH],
    PDATA_ADMIN_FLAGS,
    PDATA_CHARGER_GHOST,
    PDATA_CHARGER_MENU,
    PDATA_CHARGER_USE,
    bool:PDATA_CHARGER_ACTION,
    Float:PDATA_OFFSET,
    Float:PDATA_NEXT_OFFSET,
    Float:PDATA_ROLL_OFFSET
}

enum
{
    SOUND_MENU_NAV,
    SOUND_MENU_REMOVE,
    SOUND_MENU_ALERT,

    SOUND_HEALTH_PLACE,
    SOUND_HEALTH_USE,
    SOUND_HEALTH_EMPTY,
    SOUND_HEALTH_REMOVE,
    SOUND_HEALTH_REFILL,
    SOUND_HEV_PLACE,
    SOUND_HEV_USE,
    SOUND_HEV_EMPTY,
    SOUND_HEV_REMOVE,
    SOUND_HEV_REFILL,
    SOUND_FLICKER,
    SOUND_BUST_CONCRETE,
    SOUND_BUST_CRATE,
    SOUND_BUST_FLESH,
    SOUND_BUST_GLASS,
    SOUND_BUST_METAL
}

enum
{
    MENU_ROOT,
    MENU_CREATE,
    MENU_REMOVE,
    MENU_SHOW,
    MENU_TEAM,
    MENU_SPAWN,
    MENU_ROTATE
}

enum
{
    ROOT_CREATE,
    ROOT_REMOVE,
    ROOT_SAVE,

    ROOT_NOCLIP = 4,
    ROOT_GODMODE,

    ROOT_SHOW = 7,
    ROOT_TEAM,
    ROOT_SPAWN
}

enum
{
    REMOVE_NEXT,
    REMOVE_BACK,

    REMOVE_CURRENT = 3,
    REMOVE_ALL
}

enum
{
    SHOW_NEXT,
    SHOW_BACK,

    SHOW_CURRENT = 3,
    SHOW_ALL_HIDE,
    SHOW_ALL_SHOW,
    SHOW_ALL_DEFAULT
}

enum
{
    TEAM_NEXT,
    TEAM_BACK,

    TEAM_CURRENT = 3,
    TEAM_ALL_NONE,
    TEAM_ALL_T,
    TEAM_ALL_CT,
    TEAM_ALL_BOTH
}

enum
{
    SPAWN_NEXT,
    SPAWN_BACK,

    SPAWN_CURRENT = 3,
    SPAWN_ALL_NEVER,
    SPAWN_ALL_DELAY,
    SPAWN_ALL_ROUND_START
}

enum
{
    ROTATE_RIGHT,
    ROTATE_LEFT,
    ROTATE_PLACE
}

new Float:g_fDirections[][] =
{
    {-1.0, 0.0, 0.0},
    {1.0, 0.0, 0.0},
    {0.0, -1.0, 0.0},
    {0.0, 1.0, 0.0},
    {0.0, 0.0, -1.0},
    {0.0, 0.0, 1.0}
}

new g_szMenuHandler[][] =
{
    "menuHandlerRoot",
    "menuHandlerCreate",
    "menuHandlerRemove",
    "menuHandlerShow",
    "menuHandlerTeam",
    "menuHandlerSpawn",
    "menuHandlerRotate"
}

new g_szCN[][32] =
{
    "Charger_HealthCharger",
    "Charger_HEVCharger",
    "Charger_CIVCharger"
}

new Array:g_aCharger,
    Array:g_aChargerConfig,
    g_eSettings[MAIN_SETTINGS],
    g_ePlayerData[MAX_PLAYERS + 1][PLAYER_DATA],
    g_szFileName[MAX_RESOURCE_PATH_LENGTH],
    bool:g_bFileWasRead = false,
    g_iCharger,
    g_iChargerConfig

new g_szShow[][] = {"CHARGER_DEFAULT", "CHARGER_HIDDEN", "CHARGER_SHOWN"}
new g_szShowChat[][] = {"CHARGER_CHAT_DEFAULT", "CHARGER_CHAT_HIDDEN", "CHARGER_CHAT_SHOWN"}
new g_szShowColor[][] = {"\d", "\r", "\y"}
new g_szTeam[][] = {"CHARGER_NONE", "CHARGER_T", "CHARGER_CT", "CHARGER_BOTH"}
new g_szTeamChat[][] = {"CHARGER_CHAT_NONE", "CHARGER_CHAT_T", "CHARGER_CHAT_CT", "CHARGER_CHAT_BOTH"}
new g_szSpawn[][] = {"CHARGER_NEVER", "CHARGER_DELAY", "CHARGER_ROUND_START"}
new g_szSpawnChat[][] = {"CHARGER_CHAT_NEVER", "CHARGER_CHAT_DELAY", "CHARGER_CHAT_ROUND_START"}

public plugin_init()
{
    register_plugin("Charger", PLUGIN_VERSION, "RedSMURF")

    register_clcmd("say /charger",      "cmdMenu", ADMIN_RCON)
    register_clcmd("say_team /charger", "cmdMenu", ADMIN_RCON)
    register_concmd("charger_reload",   "cmdReload", ADMIN_RCON, "-- Reload the configuration file")

    register_dictionary("Charger.txt")

    register_forward(FM_UpdateClientData, "fwdUpdateClientData", 1)
    register_forward(FM_AddToFullPack, "fwdAddToFullPack", 1)
    RegisterHam(Ham_Spawn, "info_target", "fwdSpawn", 1)
    RegisterHam(Ham_TakeDamage, "info_target", "fwdTakeDamage", 0)
    RegisterHam(Ham_TraceAttack, "info_target", "fwdTraceAttack", 1)
    RegisterHam(Ham_Player_PreThink, "player", "fwdPreThink", 0)
    RegisterHam(Ham_Killed, "player", "fwdKilled", 1)

    register_logevent("eventRoundStart", 2, "1=Round_Start")

    if ( g_eSettings[SETTING_CHARGER_ACTION] )
        set_task(g_eSettings[SETTING_GHOST_FREQ], "chargerTask", TASK_ACTION, .flags = "b")

    chargerInit()
}

public plugin_precache()
{
    g_aCharger = ArrayCreate(CHARGER)
    g_aChargerConfig = ArrayCreate(CHARGER)
    g_eSettings[SETTING_SOUND_FLICKER] = ArrayCreate(MAX_RESOURCE_PATH_LENGTH)
    g_eSettings[SETTING_SOUND_BUST_CONCRETE] = ArrayCreate(MAX_RESOURCE_PATH_LENGTH)
    g_eSettings[SETTING_SOUND_BUST_CRATE] = ArrayCreate(MAX_RESOURCE_PATH_LENGTH)
    g_eSettings[SETTING_SOUND_BUST_FLESH] = ArrayCreate(MAX_RESOURCE_PATH_LENGTH)
    g_eSettings[SETTING_SOUND_BUST_GLASS] = ArrayCreate(MAX_RESOURCE_PATH_LENGTH)
    g_eSettings[SETTING_SOUND_BUST_METAL] = ArrayCreate(MAX_RESOURCE_PATH_LENGTH)

    ReadFile()
}

public plugin_end()
{
    ArrayDestroy(g_aCharger)
    ArrayDestroy(g_aChargerConfig)
    ArrayDestroy(g_eSettings[SETTING_SOUND_FLICKER])
    ArrayDestroy(g_eSettings[SETTING_SOUND_BUST_CONCRETE])
    ArrayDestroy(g_eSettings[SETTING_SOUND_BUST_CRATE])
    ArrayDestroy(g_eSettings[SETTING_SOUND_BUST_FLESH])
    ArrayDestroy(g_eSettings[SETTING_SOUND_BUST_GLASS])
    ArrayDestroy(g_eSettings[SETTING_SOUND_BUST_METAL])
}

public cmdMenu(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1)
    || !is_user_alive(id) )
        return PLUGIN_HANDLED

    if ( !g_eSettings[SETTING_CHARGER_ACTION] )
    {
        client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_NO_ACTION")
        return PLUGIN_HANDLED
    }

    chargerSound(id, SOUND_MENU_NAV)
    chargerMenu(id, MENU_ROOT)

    return PLUGIN_HANDLED
}

public cmdReload(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1) )
        return PLUGIN_HANDLED

    ReadFile()
    console_print(id, "The configuration file has been reloaded successfully !")

    return PLUGIN_HANDLED
}

public client_command(id)
{
    if ( !g_ePlayerData[id][PDATA_CHARGER_GHOST] )
        return PLUGIN_CONTINUE

    new szCmd[16]
    read_argv(0, szCmd, charsmax(szCmd))

    if ( contain(szCmd, "weapon_") != -1 ||
    equal(szCmd, "invnext") ||
    equal(szCmd, "invprev") ||
    equal(szCmd, "lastinv") )
        return PLUGIN_HANDLED

    return PLUGIN_CONTINUE
}

public eventRoundStart()
{
    if ( !g_iCharger )
        return PLUGIN_HANDLED

    new eCharger[CHARGER]

    for ( new i = 0; i < g_iCharger; i ++ )
    {
        ArrayGetArray(g_aCharger, i, eCharger)

        if ( eCharger[CHARGER_FLAGS] & FLAG_SHOW
        || eCharger[CHARGER_SHOW] != SHOW_DEFAULT
        || eCharger[CHARGER_SPAWN_MODE] != SPAWN_ROUND_START )
            continue

        if ( eCharger[CHARGER_SPAWN_CHANCE] >= random_float(0.0, 1.0) )
        {
            eCharger[CHARGER_FLAGS] |= FLAG_SHOW
            chargerState(eCharger, true, true)
        }
        else
        {
            eCharger[CHARGER_FLAGS] &= ~FLAG_SHOW
            chargerState(eCharger, false, false)
        }

        ArraySetArray(g_aCharger, i, eCharger)
    }

    return PLUGIN_HANDLED
}

ReadFile()
{
    if ( g_bFileWasRead )
    {
        new iPlayers[MAX_PLAYERS], iNum
        get_players(iPlayers, iNum, "ch")

        for ( new i = 0; i < iNum; i ++ )
            UpdateData(iPlayers[i])

        ArrayClear(g_eSettings[SETTING_SOUND_FLICKER])
        ArrayClear(g_eSettings[SETTING_SOUND_BUST_CONCRETE])
        ArrayClear(g_eSettings[SETTING_SOUND_BUST_CRATE])
        ArrayClear(g_eSettings[SETTING_SOUND_BUST_FLESH])
        ArrayClear(g_eSettings[SETTING_SOUND_BUST_GLASS])
        ArrayClear(g_eSettings[SETTING_SOUND_BUST_METAL])
        ArrayClear(g_aChargerConfig)
        g_iChargerConfig = 0
    }

    get_configsdir(g_szFileName, charsmax(g_szFileName))
    add(g_szFileName, charsmax(g_szFileName), "/Charger.ini")

    new iFile
    iFile = fopen(g_szFileName, "rt")

    if ( !iFile )
    {
        set_fail_state("An error occured during the opening of the configuration file !")
    }

    new szData[MAX_FILE_CELL_SIZE],
        szKey[MAX_VALUE_LENGTH],
        szValue[MAX_RESOURCE_PATH_LENGTH],
        eCharger[CHARGER], iSection = SECTION_NONE, iLine

    while( !feof(iFile) )
    {
        iLine ++
        fgets(iFile, szData, charsmax(szData))
        trim(szData)

        switch( szData[0] )
        {
            case EOS, ';', '#':
            {
                continue
            }
            case '[':
            {
                if ( szData[strlen(szData) - 1] == ']' )
                {
                    replace(szData, charsmax( szData ), "[", "")
                    replace(szData, charsmax( szData ), "]", "")
                    trim(szData)

                    if ( equali(szData, "Main Settings") )
                    {
                        iSection = SECTION_MAIN_SETTINGS
                    }
                    else
                    {
                        if ( g_iChargerConfig )
                            ArrayPushArray(g_aChargerConfig, eCharger)

                        copy(eCharger[CHARGER_NAME], charsmax(eCharger[CHARGER_NAME]), szData)
                        copy(eCharger[CHARGER_MODEL], charsmax(eCharger[CHARGER_MODEL]), g_eSettings[SETTING_DEFAULT_MODEL])
                        eCharger[CHARGER_CLASS]             = CLASS_HEALTH
                        eCharger[CHARGER_FLAGS]             = FLAG_SPARK | FLAG_SOUND | FLAG_GIB
                        eCharger[CHARGER_TEAM]              = TEAM_BOTH
                        eCharger[CHARGER_SOUND]             = SOUND_HEALTH
                        eCharger[CHARGER_MODE]              = MODE_HEALTH
                        eCharger[CHARGER_BREAK_FLAG]        = BREAK_METAL
                        eCharger[CHARGER_GIB]               = g_eSettings[SETTING_GIB_METALPLATE]
                        eCharger[CHARGER_BUST_SOUND]        = SOUND_BUST_METAL

                        eCharger[CHARGER_SPAWN_MODE]        = SPAWN_DELAY
                        eCharger[CHARGER_SPAWN_MIN]         = 10.0
                        eCharger[CHARGER_SPAWN_MAX]         = 25.0
                        eCharger[CHARGER_SPAWN_CHANCE]      = 1.0

                        eCharger[CHARGER_RATE]              = 1.0
                        eCharger[CHARGER_DELAY]             = 0.1
                        eCharger[CHARGER_CAPACITY]          = 100.0
                        eCharger[CHARGER_CAPACITY_MAX]      = 100.0
                        eCharger[CHARGER_LIMIT]             = 0.0
                        eCharger[CHARGER_REFILL]            = 0.0
                        eCharger[CHARGER_DELAY_ACTIVE]      = 0.0

                        eCharger[CHARGER_HEALTH]            = 125.0
                        eCharger[CHARGER_EXPLODE_DAMAGE]    = 100.0
                        eCharger[CHARGER_EXPLODE_RADIUS]    = 150.0
                        eCharger[CHARGER_BREAK_RATIO]       = 7.5
                        eCharger[CHARGER_BREAK_THRESHOLD]   = 70.0
                        eCharger[CHARGER_BREAK_CHANCE]      = 0.4

                        iSection = SECTION_CHARGER
                        g_iChargerConfig ++
                    }
                }
                else
                {
                    LogConfigError(iLine, "Unclosed section name: %s", szData)
                    iSection = SECTION_NONE
                }
            }
            default:
            {
                strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
                trim(szKey)
                trim(szValue)

                switch( iSection )
                {
                    case SECTION_NONE:
                    {
                        LogConfigError(iLine, "Data is not in any defined section: %s", szData)
                    }
                    case SECTION_MAIN_SETTINGS:
                    {
                        if ( equali(szKey, "SETTING_DEFAULT_MODEL") )
                        {
                            copy(g_eSettings[SETTING_DEFAULT_MODEL], charsmax(g_eSettings[SETTING_DEFAULT_MODEL]), szValue)
                            if ( !g_bFileWasRead ) precache_model(g_eSettings[SETTING_DEFAULT_MODEL])
                        }
                        else if ( equali(szKey, "SETTING_MINS_STANDARD") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_MINS_STANDARD][0] = str_to_float(szKey)

                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_MINS_STANDARD][1] = str_to_float(szKey)
                            g_eSettings[SETTING_MINS_STANDARD][2] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_MAXS_STANDARD") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_MAXS_STANDARD][0] = str_to_float(szKey)

                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_MAXS_STANDARD][1] = str_to_float(szKey)
                            g_eSettings[SETTING_MAXS_STANDARD][2] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_MINS_CIVILIAN") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_MINS_CIVILIAN][0] = str_to_float(szKey)

                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_MINS_CIVILIAN][1] = str_to_float(szKey)
                            g_eSettings[SETTING_MINS_CIVILIAN][2] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_MAXS_CIVILIAN") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_MAXS_CIVILIAN][0] = str_to_float(szKey)

                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_MAXS_CIVILIAN][1] = str_to_float(szKey)
                            g_eSettings[SETTING_MAXS_CIVILIAN][2] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_CHARGER_LOAD") )
                        {
                            g_eSettings[SETTING_CHARGER_LOAD] = bool:str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_CHARGER_ACTION") )
                        {
                            g_eSettings[SETTING_CHARGER_ACTION] = bool:str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_CHARGER_RANGE") )
                        {
                            g_eSettings[SETTING_CHARGER_RANGE] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_BASE") )
                        {
                            g_eSettings[SETTING_OFFSET_BASE] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_MIN") )
                        {
                            g_eSettings[SETTING_OFFSET_MIN] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_MAX") )
                        {
                            g_eSettings[SETTING_OFFSET_MAX] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_STEP") )
                        {
                            g_eSettings[SETTING_OFFSET_STEP] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_FREQ") )
                        {
                            g_eSettings[SETTING_OFFSET_FREQ] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_GHOST_FREQ") )
                        {
                            g_eSettings[SETTING_GHOST_FREQ] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_GHOST_ALPHA") )
                        {
                            g_eSettings[SETTING_GHOST_ALPHA] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_GIB_ALIEN") )
                        {
                            if ( !g_bFileWasRead )
                                g_eSettings[SETTING_GIB_ALIEN] = precache_model(szValue)
                        }
                        else if ( equali(szKey, "SETTING_GIB_BIGMOM") )
                        {
                            if ( !g_bFileWasRead )
                                g_eSettings[SETTING_GIB_BIGMOM] = precache_model(szValue)
                        }
                        else if ( equali(szKey, "SETTING_GIB_BONE") )
                        {
                            if ( !g_bFileWasRead )
                                g_eSettings[SETTING_GIB_BONE] = precache_model(szValue)
                        }
                        else if ( equali(szKey, "SETTING_GIB_BOOK") )
                        {
                            if ( !g_bFileWasRead )
                                g_eSettings[SETTING_GIB_BOOK] = precache_model(szValue)
                        }
                        else if ( equali(szKey, "SETTING_GIB_CINDER") )
                        {
                            if ( !g_bFileWasRead )
                                g_eSettings[SETTING_GIB_CINDER] = precache_model(szValue)
                        }
                        else if ( equali(szKey, "SETTING_GIB_COMPUTER") )
                        {
                            if ( !g_bFileWasRead )
                                g_eSettings[SETTING_GIB_COMPUTER] = precache_model(szValue)
                        }
                        else if ( equali(szKey, "SETTING_GIB_CONCRETE") )
                        {
                            if ( !g_bFileWasRead )
                                g_eSettings[SETTING_GIB_CONCRETE] = precache_model(szValue)
                        }
                        else if ( equali(szKey, "SETTING_GIB_FLESH") )
                        {
                            if ( !g_bFileWasRead )
                                g_eSettings[SETTING_GIB_FLESH] = precache_model(szValue)
                        }
                        else if ( equali(szKey, "SETTING_GIB_GARBAGE") )
                        {
                            if ( !g_bFileWasRead )
                                g_eSettings[SETTING_GIB_GARBAGE] = precache_model(szValue)
                        }
                        else if ( equali(szKey, "SETTING_GIB_GLASS") )
                        {
                            if ( !g_bFileWasRead )
                                g_eSettings[SETTING_GIB_GLASS] = precache_model(szValue)
                        }
                        else if ( equali(szKey, "SETTING_GIB_METALPLATE") )
                        {
                            if ( !g_bFileWasRead )
                                g_eSettings[SETTING_GIB_METALPLATE] = precache_model(szValue)
                        }
                        else if ( equali(szKey, "SETTING_GIB_MILCRATE") )
                        {
                            if ( !g_bFileWasRead )
                                g_eSettings[SETTING_GIB_MILCRATE] = precache_model(szValue)
                        }
                        else if ( equali(szKey, "SETTING_GIB_ROCK") )
                        {
                            if ( !g_bFileWasRead )
                                g_eSettings[SETTING_GIB_ROCK] = precache_model(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SPRITE_ZEROGXPLODE") )
                        {
                            if ( !g_bFileWasRead )
                                g_eSettings[SETTING_SPRITE_ZEROGXPLODE] = precache_model(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SOUND_HEALTH_PLACE") )
                        {
                            copy(g_eSettings[SETTING_SOUND_HEALTH_PLACE], charsmax(g_eSettings[SETTING_SOUND_HEALTH_PLACE]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_HEALTH_PLACE])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_HEALTH_USE") )
                        {
                            copy(g_eSettings[SETTING_SOUND_HEALTH_USE], charsmax(g_eSettings[SETTING_SOUND_HEALTH_USE]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_HEALTH_USE])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_HEALTH_EMPTY") )
                        {
                            copy(g_eSettings[SETTING_SOUND_HEALTH_EMPTY], charsmax(g_eSettings[SETTING_SOUND_HEALTH_EMPTY]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_HEALTH_EMPTY])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_HEALTH_REMOVE") )
                        {
                            copy(g_eSettings[SETTING_SOUND_HEALTH_REMOVE], charsmax(g_eSettings[SETTING_SOUND_HEALTH_REMOVE]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_HEALTH_REMOVE])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_HEALTH_REFILL") )
                        {
                            copy(g_eSettings[SETTING_SOUND_HEALTH_REFILL], charsmax(g_eSettings[SETTING_SOUND_HEALTH_REFILL]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_HEALTH_REFILL])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_HEV_PLACE") )
                        {
                            copy(g_eSettings[SETTING_SOUND_HEV_PLACE], charsmax(g_eSettings[SETTING_SOUND_HEV_PLACE]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_HEV_PLACE])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_HEV_USE") )
                        {
                            copy(g_eSettings[SETTING_SOUND_HEV_USE], charsmax(g_eSettings[SETTING_SOUND_HEV_USE]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_HEV_USE])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_HEV_EMPTY") )
                        {
                            copy(g_eSettings[SETTING_SOUND_HEV_EMPTY], charsmax(g_eSettings[SETTING_SOUND_HEV_EMPTY]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_HEV_EMPTY])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_HEV_REMOVE") )
                        {
                            copy(g_eSettings[SETTING_SOUND_HEV_REMOVE], charsmax(g_eSettings[SETTING_SOUND_HEV_REMOVE]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_HEV_REMOVE])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_HEV_REFILL") )
                        {
                            copy(g_eSettings[SETTING_SOUND_HEV_REFILL], charsmax(g_eSettings[SETTING_SOUND_HEV_REFILL]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_HEV_REFILL])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_FLICKER") )
                        {
                            ArrayPushString(g_eSettings[SETTING_SOUND_FLICKER], szValue)
                            if ( !g_bFileWasRead ) precache_sound(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SOUND_BUST_CONCRETE") )
                        {
                            ArrayPushString(g_eSettings[SETTING_SOUND_BUST_CONCRETE], szValue)
                            if ( !g_bFileWasRead ) precache_sound(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SOUND_BUST_CRATE") )
                        {
                            ArrayPushString(g_eSettings[SETTING_SOUND_BUST_CRATE], szValue)
                            if ( !g_bFileWasRead ) precache_sound(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SOUND_BUST_FLESH") )
                        {
                            ArrayPushString(g_eSettings[SETTING_SOUND_BUST_FLESH], szValue)
                            if ( !g_bFileWasRead ) precache_sound(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SOUND_BUST_GLASS") )
                        {
                            ArrayPushString(g_eSettings[SETTING_SOUND_BUST_GLASS], szValue)
                            if ( !g_bFileWasRead ) precache_sound(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SOUND_BUST_METAL") )
                        {
                            ArrayPushString(g_eSettings[SETTING_SOUND_BUST_METAL], szValue)
                            if ( !g_bFileWasRead ) precache_sound(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SOUND_MENU_NAV") )
                        {
                            copy(g_eSettings[SETTING_SOUND_MENU_NAV], charsmax(g_eSettings[SETTING_SOUND_MENU_NAV]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SOUND_MENU_REMOVE") )
                        {
                            copy(g_eSettings[SETTING_SOUND_MENU_REMOVE], charsmax(g_eSettings[SETTING_SOUND_MENU_REMOVE]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SOUND_MENU_ALERT") )
                        {
                            copy(g_eSettings[SETTING_SOUND_MENU_ALERT], charsmax(g_eSettings[SETTING_SOUND_MENU_ALERT]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(szValue)
                        }
                        else if ( equali(szKey, "SETTING_COLOR_ACTIVE") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_COLOR_ACTIVE][0] = str_to_num(szKey)

                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_COLOR_ACTIVE][1] = str_to_num(szKey)
                            g_eSettings[SETTING_COLOR_ACTIVE][2] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_COLOR_INACTIVE") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_COLOR_INACTIVE][0] = str_to_num(szKey)

                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_COLOR_INACTIVE][1] = str_to_num(szKey)
                            g_eSettings[SETTING_COLOR_INACTIVE][2] = str_to_num(szValue)
                        }
                    }
                    case SECTION_CHARGER:
                    {
                        if ( equali(szKey, "CHARGER_MODEL") )
                        {
                            copy(eCharger[CHARGER_MODEL], charsmax(eCharger[CHARGER_MODEL]), szValue)
                            if ( !g_bFileWasRead )
                                precache_model(szValue)
                        }
                        else if ( equali(szKey, "CHARGER_CLASS") )
                        {
                            eCharger[CHARGER_CLASS] = str_to_num(szValue)
                            eCharger[CHARGER_CLASS] = clamp(eCharger[CHARGER_CLASS], CLASS_HEALTH, CLASS_CIV)
                        }
                        else if ( equali(szKey, "CHARGER_FLAGS") )
                        {
                            eCharger[CHARGER_FLAGS] = read_flags(szValue)
                            eCharger[CHARGER_FLAGS] &= 63
                        }
                        else if ( equali(szKey, "CHARGER_TEAM") )
                        {
                            eCharger[CHARGER_TEAM] = str_to_num(szValue)
                            eCharger[CHARGER_TEAM] = clamp(eCharger[CHARGER_TEAM], TEAM_NONE, TEAM_BOTH)
                        }
                        else if ( equali(szKey, "CHARGER_SOUND") )
                        {
                            eCharger[CHARGER_SOUND] = str_to_num(szValue)
                            eCharger[CHARGER_SOUND] = clamp(eCharger[CHARGER_SOUND], SOUND_HEALTH, SOUND_HEV)
                        }
                        else if ( equali(szKey, "CHARGER_MODE") )
                        {
                            eCharger[CHARGER_MODE] = str_to_num(szValue)
                            eCharger[CHARGER_MODE] = clamp(eCharger[CHARGER_MODE], MODE_HEALTH, MODE_ARMOR)
                        }
                        else if ( equali(szKey, "CHARGER_BREAK_FLAG") )
                        {
                            eCharger[CHARGER_BREAK_FLAG] = str_to_num(szValue) & BREAK_MASK
                        }
                        else if ( equali(szKey, "CHARGER_GIB") )
                        {
                            switch ( str_to_num(szValue) )
                            {
                                case GIB_ALIEN:      eCharger[CHARGER_GIB] = g_eSettings[SETTING_GIB_BIGMOM]
                                case GIB_BIGMOM:     eCharger[CHARGER_GIB] = g_eSettings[SETTING_GIB_BIGMOM]
                                case GIB_BONE:       eCharger[CHARGER_GIB] = g_eSettings[SETTING_GIB_BONE]
                                case GIB_CINDER:     eCharger[CHARGER_GIB] = g_eSettings[SETTING_GIB_CINDER]
                                case GIB_COMPUTER:   eCharger[CHARGER_GIB] = g_eSettings[SETTING_GIB_COMPUTER]
                                case GIB_CONCRETE:   eCharger[CHARGER_GIB] = g_eSettings[SETTING_GIB_CONCRETE]
                                case GIB_FLESH:      eCharger[CHARGER_GIB] = g_eSettings[SETTING_GIB_FLESH]
                                case GIB_GARBAGE:    eCharger[CHARGER_GIB] = g_eSettings[SETTING_GIB_GARBAGE]
                                case GIB_GLASS:      eCharger[CHARGER_GIB] = g_eSettings[SETTING_GIB_GLASS]
                                case GIB_METALPLATE: eCharger[CHARGER_GIB] = g_eSettings[SETTING_GIB_METALPLATE]
                                case GIB_MILCRATE:   eCharger[CHARGER_GIB] = g_eSettings[SETTING_GIB_MILCRATE]
                                case GIB_ROCK:       eCharger[CHARGER_GIB] = g_eSettings[SETTING_GIB_ROCK]
                                default:             eCharger[CHARGER_GIB] = g_eSettings[SETTING_GIB_COMPUTER]
                            }
                        }
                        else if ( equali(szKey, "CHARGER_BUST_SOUND") )
                        {
                            eCharger[CHARGER_BUST_SOUND] = str_to_num(szValue)
                            eCharger[CHARGER_BUST_SOUND] = clamp(eCharger[CHARGER_BUST_SOUND], SOUND_BUST_CONCRETE, SOUND_BUST_METAL)
                        }
                        else if ( equali(szKey, "CHARGER_SPAWN_MODE") )
                        {
                            eCharger[CHARGER_SPAWN_MODE] = str_to_num(szValue)
                            eCharger[CHARGER_SPAWN_MODE] = clamp(eCharger[CHARGER_SPAWN_MODE], SPAWN_NEVER, SPAWN_DELAY)
                        }
                        else if ( equali(szKey, "CHARGER_SPAWN_MIN") )
                        {
                            eCharger[CHARGER_SPAWN_MIN] = str_to_float(szValue)
                            if ( eCharger[CHARGER_SPAWN_MIN] < 0.0 ) eCharger[CHARGER_SPAWN_MIN] = 0.0
                        }
                        else if ( equali(szKey, "CHARGER_SPAWN_MAX") )
                        {
                            eCharger[CHARGER_SPAWN_MAX] = str_to_float(szValue)
                            if ( eCharger[CHARGER_SPAWN_MAX] < eCharger[CHARGER_SPAWN_MIN] ) eCharger[CHARGER_SPAWN_MIN] = 0.0
                        }
                        else if ( equali(szKey, "CHARGER_SPAWN_CHANCE") )
                        {
                            eCharger[CHARGER_SPAWN_CHANCE] = str_to_float(szValue)
                            eCharger[CHARGER_SPAWN_CHANCE] = floatclamp(eCharger[CHARGER_SPAWN_CHANCE], 0.0, 1.0)
                        }
                        else if ( equali(szKey, "CHARGER_RATE") )
                        {
                            eCharger[CHARGER_RATE] = str_to_float(szValue)
                            if ( eCharger[CHARGER_RATE] < 0.0 ) eCharger[CHARGER_RATE] = 1.0
                        }
                        else if ( equali(szKey, "CHARGER_DELAY") )
                        {
                            eCharger[CHARGER_DELAY] = str_to_float(szValue)
                            if ( eCharger[CHARGER_DELAY] < 0.0 ) eCharger[CHARGER_DELAY] = 0.1
                        }
                        else if ( equali(szKey, "CHARGER_CAPACITY") )
                        {
                            eCharger[CHARGER_CAPACITY] = str_to_float(szValue)
                            if ( eCharger[CHARGER_CAPACITY] < 0.0 ) eCharger[CHARGER_CAPACITY] = 100.0

                            eCharger[CHARGER_CAPACITY_MAX] = eCharger[CHARGER_CAPACITY]
                        }
                        else if ( equali(szKey, "CHARGER_LIMIT") )
                        {
                            eCharger[CHARGER_LIMIT] = str_to_float(szValue)
                            if ( eCharger[CHARGER_LIMIT] < 0.0 ) eCharger[CHARGER_LIMIT] = 0.0
                        }
                        else if ( equali(szKey, "CHARGER_REFILL") )
                        {
                            eCharger[CHARGER_REFILL] = str_to_float(szValue)
                            if ( eCharger[CHARGER_REFILL] < 0.0 ) eCharger[CHARGER_REFILL] = 0.0
                        }
                        else if ( equali(szKey, "CHARGER_DELAY_ACTIVE") )
                        {
                            eCharger[CHARGER_DELAY_ACTIVE] = str_to_float(szValue)
                            if ( eCharger[CHARGER_DELAY_ACTIVE] < 0.0 ) eCharger[CHARGER_DELAY_ACTIVE] = 0.0
                        }
                        else if ( equali(szKey, "CHARGER_HEALTH") )
                        {
                            eCharger[CHARGER_HEALTH] = str_to_float(szValue)
                            if ( eCharger[CHARGER_HEALTH] < 0.0 ) eCharger[CHARGER_HEALTH] = 250.0
                        }
                        else if ( equali(szKey, "CHARGER_EXPLODE_DAMAGE") )
                        {
                            eCharger[CHARGER_EXPLODE_DAMAGE] = str_to_float(szValue)
                            if ( eCharger[CHARGER_EXPLODE_DAMAGE] < 0.0 ) eCharger[CHARGER_EXPLODE_DAMAGE] = 100.0
                        }
                        else if ( equali(szKey, "CHARGER_EXPLODE_RADIUS") )
                        {
                            eCharger[CHARGER_EXPLODE_RADIUS] = str_to_float(szValue)
                            if ( eCharger[CHARGER_EXPLODE_RADIUS] < 0.0 ) eCharger[CHARGER_EXPLODE_RADIUS] = 150.0
                        }
                        else if ( equali(szKey, "CHARGER_BREAK_RATIO") )
                        {
                            eCharger[CHARGER_BREAK_RATIO] = str_to_float(szValue)
                            if ( eCharger[CHARGER_BREAK_RATIO] < 0.0 || eCharger[CHARGER_BREAK_RATIO] > 100.0 ) eCharger[CHARGER_BREAK_RATIO] = 2.5
                        }
                        else if ( equali(szKey, "CHARGER_BREAK_THRESHOLD") )
                        {
                            eCharger[CHARGER_BREAK_THRESHOLD] = str_to_float(szValue)
                            if ( eCharger[CHARGER_BREAK_THRESHOLD] < 0.0 || eCharger[CHARGER_BREAK_THRESHOLD] > 100.0 ) eCharger[CHARGER_BREAK_THRESHOLD] = 70.0
                        }
                        else if ( equali(szKey, "CHARGER_BREAK_CHANCE") )
                        {
                            eCharger[CHARGER_BREAK_CHANCE] = str_to_float(szValue)
                            if ( eCharger[CHARGER_BREAK_CHANCE] < 0.0 || eCharger[CHARGER_BREAK_CHANCE] > 100.0 ) eCharger[CHARGER_BREAK_CHANCE] = 0.4
                        }
                    }
                }
            }
        }
    }

    if ( g_iChargerConfig )
        ArrayPushArray(g_aChargerConfig, eCharger)
    else
        set_fail_state("No chargers were found in the configuration file.")

    if ( g_bFileWasRead )
    {
        if ( g_eSettings[SETTING_CHARGER_ACTION] )
        {
            if ( !task_exists(TASK_ACTION) )
                set_task(g_eSettings[SETTING_GHOST_FREQ], "corpseTask", TASK_ACTION, .flags = "b")
        }
        else
            remove_task(TASK_ACTION)
    }

    g_bFileWasRead = true
    fclose(iFile)
}

public client_authorized(id)
{
    get_user_name(id, g_ePlayerData[id][PDATA_NAME], charsmax(g_ePlayerData[][PDATA_NAME]))
    get_user_authid(id, g_ePlayerData[id][PDATA_AUTHID], charsmax(g_ePlayerData[][PDATA_AUTHID]))

    set_task(DELAY_ON_CONNECT, "UpdateData", id)
}

public UpdateData(id)
{
    get_user_name(id, g_ePlayerData[id][PDATA_NAME], charsmax(g_ePlayerData[][PDATA_NAME]))
    g_ePlayerData[id][PDATA_ADMIN_FLAGS] = get_user_flags(id)
    g_ePlayerData[id][PDATA_OFFSET] = g_eSettings[SETTING_OFFSET_BASE]
}

public chargerInit()
{
    if ( g_eSettings[SETTING_CHARGER_LOAD] )
        loadData()
}

public chargerMenu(id, iType)
{
    new szTitle[64],
        iMenu

    formatex(szTitle,charsmax(szTitle), "%L", id, "CHARGER_MENU_TITLE")
    iMenu = menu_create(szTitle, g_szMenuHandler[iType])

    switch( iType )
    {
        case MENU_ROOT:   { menuRoot(id, iMenu); }
        case MENU_CREATE: { menuCreate(id, iMenu);  format(szTitle, charsmax(szTitle), "%s^n%L", szTitle, id, "CHARGER_ROOT_CREATE"); }
        case MENU_REMOVE: { menuRemove(id, iMenu);  format(szTitle, charsmax(szTitle), "%s^n%L", szTitle, id, "CHARGER_ROOT_REMOVE"); }
        case MENU_SHOW:   { menuShow(id, iMenu);    format(szTitle, charsmax(szTitle), "%s^n%L", szTitle, id, "CHARGER_ROOT_SHOW"); }
        case MENU_TEAM:   { menuTeam(id, iMenu);    format(szTitle, charsmax(szTitle), "%s^n%L", szTitle, id, "CHARGER_ROOT_TEAM"); }
        case MENU_SPAWN:  { menuSpawn(id, iMenu);   format(szTitle, charsmax(szTitle), "%s^n%L", szTitle, id, "CHARGER_ROOT_SPAWN"); }
        case MENU_ROTATE: { menuRotate(id, iMenu);  format(szTitle, charsmax(szTitle), "%s^n%L", szTitle, id, "CHARGER_ROOT_ROTATE"); }
    }

    if ( menu_pages(iMenu) > 1 )
        format(szTitle, charsmax(szTitle), "%s^n%L", szTitle, id, "CHARGER_MENU_TITLE_PAGE")

    menu_setprop(iMenu, MPROP_TITLE, szTitle)
    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL)
    menu_setprop(iMenu, MPROP_NUMBER_COLOR, "\r")

    menu_display(id, iMenu)
    return PLUGIN_HANDLED
}

stock menuNav(id, iMenu)
{
    new szItem[64]

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_NAV_NEXT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_NAV_BACK")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)
}

public menuRoot(id, iMenu)
{
    new szItem[64]

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_ROOT_CREATE")
    menu_additem(iMenu, szItem )

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_ROOT_REMOVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_ROOT_SAVE")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_ROOT_NOCLIP", id, get_user_noclip(id) ? "CHARGER_ON" : "CHARGER_OFF")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_ROOT_GODMODE", id, get_user_godmode(id) ? "CHARGER_ON" : "CHARGER_OFF")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_ROOT_SHOW")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_ROOT_TEAM")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_ROOT_SPAWN")
    menu_additem(iMenu, szItem)
}

public menuHandlerRoot(id, menu, item)
{
    if ( item == MENU_EXIT )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    switch( item )
    {
        case ROOT_CREATE:
        {
            if ( g_iCharger >= MAX_ENT )
            {
                client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_LIMIT")
            }
            else
            {
                chargerSound(id, SOUND_MENU_NAV)
                chargerMenu(id, MENU_CREATE)
            }
        }
        case ROOT_REMOVE:
        {
            if ( !g_iCharger )
            {
                client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_NO_CHARGER")
            }
            else
            {
                chargerSound(id, SOUND_MENU_REMOVE)
                chargerMenu(id, MENU_REMOVE)
            }
        }
        case ROOT_SAVE:
        {
            saveData(id)
        }
        case ROOT_NOCLIP:
        {
            chargerNoClip(id)
        }
        case ROOT_GODMODE:
        {
            chargerGodMode(id)
        }
        case ROOT_SHOW:
        {
            if ( !g_iCharger )
            {
                client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_NO_CHARGER")
            }
            else
            {
                chargerSound(id, SOUND_MENU_NAV)
                chargerMenu(id, MENU_SHOW)
            }
        }
        case ROOT_TEAM:
        {
            if ( !g_iCharger )
            {
                client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_NO_CHARGER")
            }
            else
            {
                chargerSound(id, SOUND_MENU_NAV)
                chargerMenu(id, MENU_TEAM)
            }
        }
        case ROOT_SPAWN:
        {
            if ( !g_iCharger )
            {
                client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_NO_CHARGER")
            }
            else
            {
                chargerSound(id, SOUND_MENU_NAV)
                chargerMenu(id, MENU_SPAWN)
            }
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuCreate(id, iMenu)
{
    new eCharger[CHARGER],
        szItem[64]

    for ( new i = 0; i < g_iChargerConfig; i ++ )
    {
        ArrayGetArray(g_aChargerConfig, i, eCharger)

        copy(szItem, charsmax(szItem), eCharger[CHARGER_NAME])
        menu_additem(iMenu, szItem)
    }
}

public menuHandlerCreate(id, menu, item)
{
    if ( item == MENU_EXIT
    || !is_user_alive(id) )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    chargerCreate(id, item)
    chargerSound(id, SOUND_MENU_NAV)
    chargerMenu(id, MENU_ROTATE)

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuRemove(id, iMenu)
{
    new szItem[64],
        eCharger[CHARGER]

    menuNav(id, iMenu)
    ArrayGetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_REMOVE_CURRENT", eCharger[CHARGER_NAME])
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_REMOVE_ALL")
    menu_additem(iMenu, szItem)

    g_ePlayerData[id][PDATA_CHARGER_ACTION] = true
    eCharger[CHARGER_FLAGS] |= FLAG_SELECT
    ArraySetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)
}

public menuHandlerRemove(id, menu, item)
{
    new eCharger[CHARGER]

    ArrayGetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)
    eCharger[CHARGER_FLAGS] &= ~FLAG_SELECT
    ArraySetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)

    switch( item )
    {
        case REMOVE_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_CHARGER_MENU] >= g_iCharger - 1 )
                g_ePlayerData[id][PDATA_CHARGER_MENU] = 0
            else
                g_ePlayerData[id][PDATA_CHARGER_MENU] ++

            chargerSound(id, SOUND_MENU_NAV)
            chargerMenu(id, MENU_REMOVE)
        }
        case REMOVE_BACK:
        {
            if ( g_ePlayerData[id][PDATA_CHARGER_MENU] <= 0 )
                g_ePlayerData[id][PDATA_CHARGER_MENU] = g_iCharger - 1
            else
                g_ePlayerData[id][PDATA_CHARGER_MENU] --

            chargerSound(id, SOUND_MENU_NAV)
            chargerMenu(id, MENU_REMOVE)
        }
        case REMOVE_CURRENT:
        {
            chargerKill(eCharger[CHARGER_ID])
            chargerRemove(g_ePlayerData[id][PDATA_CHARGER_MENU])

            client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_REMOVE_CURRENT", eCharger[CHARGER_NAME])
            g_ePlayerData[id][PDATA_CHARGER_MENU] = 0

            chargerSound(id, g_iCharger > 0 ? SOUND_MENU_REMOVE : SOUND_MENU_NAV)
            chargerMenu(id, g_iCharger > 0 ? MENU_REMOVE : MENU_ROOT)
        }
        case REMOVE_ALL:
        {
            while( g_iCharger )
            {
                ArrayGetArray(g_aCharger, 0, eCharger)

                chargerKill(eCharger[CHARGER_ID])
                chargerRemove(0)
            }

            client_print_color(0, 0, "%L %L", 0, "CHARGER_CHAT_TAG", 0, "CHARGER_CHAT_REMOVE_ALL")
            g_ePlayerData[id][PDATA_CHARGER_MENU] = 0

            chargerSound(0, SOUND_MENU_ALERT)
            chargerMenu(id, MENU_ROOT)
        }
        default:
        {
            g_ePlayerData[id][PDATA_CHARGER_MENU] = 0
            g_ePlayerData[id][PDATA_CHARGER_ACTION] = false
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuShow(id, iMenu)
{
    new szItem[64],
        eCharger[CHARGER]

    menuNav(id, iMenu)
    ArrayGetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_SHOW_CURRENT",
    g_szShowColor[eCharger[CHARGER_SHOW]], eCharger[CHARGER_NAME], id, g_szShow[eCharger[CHARGER_SHOW]])
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_SHOW_ALL_HIDE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_SHOW_ALL_SHOW")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_SHOW_ALL_DEFAULT")
    menu_additem(iMenu, szItem)

    g_ePlayerData[id][PDATA_CHARGER_ACTION] = true
    eCharger[CHARGER_FLAGS] |= FLAG_SELECT
    ArraySetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)
}

public menuHandlerShow(id, menu, item)
{
    new eCharger[CHARGER]

    ArrayGetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)
    eCharger[CHARGER_FLAGS] &= ~FLAG_SELECT
    ArraySetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)

    switch( item )
    {
        case SHOW_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_CHARGER_MENU] >= g_iCharger - 1 )
                g_ePlayerData[id][PDATA_CHARGER_MENU] = 0
            else
                g_ePlayerData[id][PDATA_CHARGER_MENU] ++

            chargerSound(id, SOUND_MENU_NAV)
            chargerMenu(id, MENU_SHOW)
        }
        case SHOW_BACK:
        {
            if ( g_ePlayerData[id][PDATA_CHARGER_MENU] <= 0 )
                g_ePlayerData[id][PDATA_CHARGER_MENU] = g_iCharger - 1
            else
                g_ePlayerData[id][PDATA_CHARGER_MENU] --

            chargerSound(id, SOUND_MENU_NAV)
            chargerMenu(id, MENU_SHOW)
        }
        case SHOW_CURRENT:
        {
            if ( ++ eCharger[CHARGER_SHOW] > SHOW_FORCE_SHOW )
                eCharger[CHARGER_SHOW] = SHOW_DEFAULT

            if ( eCharger[CHARGER_SHOW] == SHOW_FORCE_SHOW )
                eCharger[CHARGER_FLAGS] |= FLAG_SHOW
            else if ( eCharger[CHARGER_SHOW] == SHOW_FORCE_HIDE )
                eCharger[CHARGER_FLAGS] &= ~FLAG_SHOW
            else if ( eCharger[CHARGER_SHOW] == SHOW_DEFAULT
            && eCharger[CHARGER_SPAWN_MODE] == SPAWN_DELAY
            && eCharger[CHARGER_FLAGS] & FLAG_DEAD )
                eCharger[CHARGER_NEXT_SPAWN] = get_gametime() + random_float(eCharger[CHARGER_SPAWN_MIN], eCharger[CHARGER_SPAWN_MAX])

            client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_SHOW_CURRENT",
            eCharger[CHARGER_NAME], id, g_szShowChat[eCharger[CHARGER_SHOW]])
            chargerState(eCharger, eCharger[CHARGER_FLAGS] & FLAG_SHOW ? true : false, eCharger[CHARGER_FLAGS] & FLAG_DEAD ? true : false)
            ArraySetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)

            chargerSound(id, SOUND_MENU_NAV)
            chargerMenu(id, MENU_SHOW)
        }
        case SHOW_ALL_HIDE:
        {
            for ( new i = 0; i < g_iCharger; i ++ )
            {
                ArrayGetArray(g_aCharger, i, eCharger)
                eCharger[CHARGER_SHOW] = SHOW_FORCE_HIDE
                eCharger[CHARGER_FLAGS] &= ~FLAG_SHOW
                chargerState(eCharger, false, false)

                ArraySetArray(g_aCharger, i, eCharger)
            }

            client_print_color(0, 0, "%L %L", 0, "CHARGER_CHAT_TAG", 0, "CHARGER_CHAT_SHOW_ALL_HIDDEN")

            chargerSound(0, SOUND_MENU_ALERT)
            chargerMenu(id, MENU_SHOW)
        }
        case SHOW_ALL_SHOW:
        {
            for ( new i = 0; i < g_iCharger; i ++ )
            {
                ArrayGetArray(g_aCharger, i, eCharger)
                eCharger[CHARGER_SHOW] = SHOW_FORCE_SHOW
                eCharger[CHARGER_FLAGS] |= FLAG_SHOW
                chargerState(eCharger, true, eCharger[CHARGER_FLAGS] & FLAG_DEAD ? true : false)

                ArraySetArray(g_aCharger, i, eCharger)
            }

            client_print_color(0, 0, "%L %L", 0, "CHARGER_CHAT_TAG", 0, "CHARGER_CHAT_SHOW_ALL_SHOWN")

            chargerSound(0, SOUND_MENU_ALERT)
            chargerMenu(id, MENU_SHOW)
        }
        case SHOW_ALL_DEFAULT:
        {
            for ( new i = 0; i < g_iCharger; i ++ )
            {
                ArrayGetArray(g_aCharger, i, eCharger)

                eCharger[CHARGER_SHOW] = SHOW_DEFAULT
                if ( eCharger[CHARGER_SPAWN_MODE] == SPAWN_DELAY
                && eCharger[CHARGER_FLAGS] & FLAG_DEAD )
                    eCharger[CHARGER_NEXT_SPAWN] = get_gametime() + random_float(eCharger[CHARGER_SPAWN_MIN], eCharger[CHARGER_SPAWN_MAX])

                ArraySetArray(g_aCharger, i, eCharger)
            }

            client_print_color(0, 0, "%L %L", 0, "CHARGER_CHAT_TAG", 0, "CHARGER_CHAT_SHOW_ALL_DEFAULT")

            chargerSound(0, SOUND_MENU_ALERT)
            chargerMenu(id, MENU_SHOW)
        }
        default:
        {
            g_ePlayerData[id][PDATA_CHARGER_MENU] = 0
            g_ePlayerData[id][PDATA_CHARGER_ACTION] = false
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuTeam(id, iMenu)
{
    new szItem[64],
        eCharger[CHARGER]

    menuNav(id, iMenu)
    ArrayGetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_TEAM_CURRENT",
    eCharger[CHARGER_NAME], id, g_szTeam[eCharger[CHARGER_TEAM]])
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_TEAM_ALL_NONE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_TEAM_ALL_T")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_TEAM_ALL_CT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_TEAM_ALL_BOTH")
    menu_additem(iMenu, szItem)

    g_ePlayerData[id][PDATA_CHARGER_ACTION] = true
    eCharger[CHARGER_FLAGS] |= FLAG_SELECT
    ArraySetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)
}

public menuHandlerTeam(id, menu, item)
{
    new eCharger[CHARGER]

    ArrayGetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)
    eCharger[CHARGER_FLAGS] &= ~FLAG_SELECT
    ArraySetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)

    switch( item )
    {
        case TEAM_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_CHARGER_MENU] >= g_iCharger - 1 )
                g_ePlayerData[id][PDATA_CHARGER_MENU] = 0
            else
                g_ePlayerData[id][PDATA_CHARGER_MENU] ++

            chargerSound(id, SOUND_MENU_NAV)
            chargerMenu(id, MENU_TEAM)
        }
        case TEAM_BACK:
        {
            if ( g_ePlayerData[id][PDATA_CHARGER_MENU] <= 0 )
                g_ePlayerData[id][PDATA_CHARGER_MENU] = g_iCharger - 1
            else
                g_ePlayerData[id][PDATA_CHARGER_MENU] --

            chargerSound(id, SOUND_MENU_NAV)
            chargerMenu(id, MENU_TEAM)
        }
        case TEAM_CURRENT:
        {
            if ( ++ eCharger[CHARGER_TEAM] > TEAM_BOTH )
                eCharger[CHARGER_TEAM] = TEAM_NONE

            client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_TEAM_CURRENT",
            eCharger[CHARGER_NAME], id, g_szTeamChat[eCharger[CHARGER_TEAM]])
            ArraySetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)

            chargerSound(id, SOUND_MENU_NAV)
            chargerMenu(id, MENU_TEAM)
        }
        case TEAM_ALL_NONE:
        {
            for ( new i = 0; i < g_iCharger; i ++ )
            {
                ArrayGetArray(g_aCharger, i, eCharger)
                eCharger[CHARGER_TEAM] = TEAM_NONE
                ArraySetArray(g_aCharger, i, eCharger)
            }

            client_print_color(0, 0, "%L %L", 0, "CHARGER_CHAT_TAG", 0, "CHARGER_CHAT_TEAM_ALL_NONE")

            chargerSound(0, SOUND_MENU_ALERT)
            chargerMenu(id, MENU_TEAM)
        }
        case TEAM_ALL_T:
        {
            for ( new i = 0; i < g_iCharger; i ++ )
            {
                ArrayGetArray(g_aCharger, i, eCharger)
                eCharger[CHARGER_TEAM] = TEAM_T
                ArraySetArray(g_aCharger, i, eCharger)
            }

            client_print_color(0, 0, "%L %L", 0, "CHARGER_CHAT_TAG", 0, "CHARGER_CHAT_TEAM_ALL_T")

            chargerSound(0, SOUND_MENU_ALERT)
            chargerMenu(id, MENU_TEAM)
        }
        case TEAM_ALL_CT:
        {
            for ( new i = 0; i < g_iCharger; i ++ )
            {
                ArrayGetArray(g_aCharger, i, eCharger)
                eCharger[CHARGER_TEAM] = TEAM_CT
                ArraySetArray(g_aCharger, i, eCharger)
            }

            client_print_color(0, 0, "%L %L", 0, "CHARGER_CHAT_TAG", 0, "CHARGER_CHAT_TEAM_ALL_CT")

            chargerSound(0, SOUND_MENU_ALERT)
            chargerMenu(id, MENU_TEAM)
        }
        case TEAM_ALL_BOTH:
        {
            for ( new i = 0; i < g_iCharger; i ++ )
            {
                ArrayGetArray(g_aCharger, i, eCharger)
                eCharger[CHARGER_TEAM] = TEAM_BOTH
                ArraySetArray(g_aCharger, i, eCharger)
            }

            client_print_color(0, 0, "%L %L", 0, "CHARGER_CHAT_TAG", 0, "CHARGER_CHAT_TEAM_ALL_BOTH")

            chargerSound(0, SOUND_MENU_ALERT)
            chargerMenu(id, MENU_TEAM)
        }
        default:
        {
            g_ePlayerData[id][PDATA_CHARGER_MENU] = 0
            g_ePlayerData[id][PDATA_CHARGER_ACTION] = false
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuSpawn(id, iMenu)
{
    new szItem[64],
        eCharger[CHARGER]

    menuNav(id, iMenu)
    ArrayGetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_SPAWN_CURRENT",
    eCharger[CHARGER_NAME], id, g_szSpawn[eCharger[CHARGER_SPAWN_MODE]])
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_SPAWN_ALL_NEVER")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_SPAWN_ALL_DELAY")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_SPAWN_ALL_ROUND_START")
    menu_additem(iMenu, szItem)

    g_ePlayerData[id][PDATA_CHARGER_ACTION] = true
    eCharger[CHARGER_FLAGS] |= FLAG_SELECT
    ArraySetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)
}

public menuHandlerSpawn(id, menu, item)
{
    new eCharger[CHARGER]

    ArrayGetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)
    eCharger[CHARGER_FLAGS] &= ~FLAG_SELECT
    ArraySetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)

    switch( item )
    {
        case SPAWN_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_CHARGER_MENU] >= g_iCharger - 1 )
                g_ePlayerData[id][PDATA_CHARGER_MENU] = 0
            else
                g_ePlayerData[id][PDATA_CHARGER_MENU] ++

            chargerSound(id, SOUND_MENU_NAV)
            chargerMenu(id, MENU_SPAWN)
        }
        case SPAWN_BACK:
        {
            if ( g_ePlayerData[id][PDATA_CHARGER_MENU] <= 0 )
                g_ePlayerData[id][PDATA_CHARGER_MENU] = g_iCharger - 1
            else
                g_ePlayerData[id][PDATA_CHARGER_MENU] --

            chargerSound(id, SOUND_MENU_NAV)
            chargerMenu(id, MENU_SPAWN)
        }
        case SPAWN_CURRENT:
        {
            if ( ++ eCharger[CHARGER_SPAWN_MODE] > SPAWN_ROUND_START )
                eCharger[CHARGER_SPAWN_MODE] = SPAWN_NEVER

            if ( eCharger[CHARGER_SHOW] == SHOW_DEFAULT
            && eCharger[CHARGER_SPAWN_MODE] == SPAWN_DELAY
            && eCharger[CHARGER_FLAGS] & FLAG_DEAD )
                eCharger[CHARGER_NEXT_SPAWN] = get_gametime() + random_float(eCharger[CHARGER_SPAWN_MIN], eCharger[CHARGER_SPAWN_MAX])

            client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_SPAWN_CURRENT",
            eCharger[CHARGER_NAME], id, g_szSpawnChat[eCharger[CHARGER_SPAWN_MODE]])
            ArraySetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)

            chargerSound(id, SOUND_MENU_NAV)
            chargerMenu(id, MENU_SPAWN)
        }
        case SPAWN_ALL_NEVER:
        {
            for ( new i = 0; i < g_iCharger; i ++ )
            {
                ArrayGetArray(g_aCharger, i, eCharger)
                eCharger[CHARGER_SPAWN_MODE] = SPAWN_NEVER
                ArraySetArray(g_aCharger, i, eCharger)
            }

            client_print_color(0, 0, "%L %L", 0, "CHARGER_CHAT_TAG", 0, "CHARGER_CHAT_SPAWN_ALL_NEVER")

            chargerSound(0, SOUND_MENU_ALERT)
            chargerMenu(id, MENU_SPAWN)
        }
        case SPAWN_ALL_DELAY:
        {
            for ( new i = 0; i < g_iCharger; i ++ )
            {
                ArrayGetArray(g_aCharger, i, eCharger)

                eCharger[CHARGER_SPAWN_MODE] = SPAWN_DELAY
                if ( eCharger[CHARGER_SHOW] == SHOW_DEFAULT
                && eCharger[CHARGER_FLAGS] & FLAG_DEAD )
                    eCharger[CHARGER_NEXT_SPAWN] = get_gametime() + random_float(eCharger[CHARGER_SPAWN_MIN], eCharger[CHARGER_SPAWN_MAX])

                ArraySetArray(g_aCharger, i, eCharger)
            }

            client_print_color(0, 0, "%L %L", 0, "CHARGER_CHAT_TAG", 0, "CHARGER_CHAT_SPAWN_ALL_DELAY")

            chargerSound(0, SOUND_MENU_ALERT)
            chargerMenu(id, MENU_SPAWN)
        }
        case SPAWN_ALL_ROUND_START:
        {
            for ( new i = 0; i < g_iCharger; i ++ )
            {
                ArrayGetArray(g_aCharger, i, eCharger)
                eCharger[CHARGER_SPAWN_MODE] = SPAWN_ROUND_START
                ArraySetArray(g_aCharger, i, eCharger)
            }

            client_print_color(0, 0, "%L %L", 0, "CHARGER_CHAT_TAG", 0, "CHARGER_CHAT_SPAWN_ALL_ROUND_START")

            chargerSound(0, SOUND_MENU_ALERT)
            chargerMenu(id, MENU_SPAWN)
        }
        default:
        {
            g_ePlayerData[id][PDATA_CHARGER_MENU] = 0
            g_ePlayerData[id][PDATA_CHARGER_ACTION] = false
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuRotate(id, iMenu)
{
    new szItem[64]

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_ROTATE_RIGHT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_ROTATE_LEFT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_ROTATE_PLACE")
    menu_additem(iMenu, szItem)
}

public menuHandlerRotate(id, menu, item)
{
    new eCharger[CHARGER],
        iItem

    iItem = chargerFind(g_ePlayerData[id][PDATA_CHARGER_GHOST], eCharger)

    switch( item )
    {
        case ROTATE_RIGHT:
        {
            g_ePlayerData[id][PDATA_ROLL_OFFSET] -= 22.5
            if ( g_ePlayerData[id][PDATA_ROLL_OFFSET] < 180.0 ) g_ePlayerData[id][PDATA_ROLL_OFFSET] += 360.0

            chargerSound(id, SOUND_MENU_NAV)
            chargerMenu(id, MENU_ROTATE)
        }
        case ROTATE_LEFT:
        {
            g_ePlayerData[id][PDATA_ROLL_OFFSET] += 22.5
            if ( g_ePlayerData[id][PDATA_ROLL_OFFSET] > 180.0 ) g_ePlayerData[id][PDATA_ROLL_OFFSET] -= 360.0

            chargerSound(id, SOUND_MENU_NAV)
            chargerMenu(id, MENU_ROTATE)
        }
        case ROTATE_PLACE:
        {
            if ( iItem != -1 && chargerTrace(eCharger, iItem, id) )
            {
                g_ePlayerData[id][PDATA_CHARGER_GHOST] = 0
                g_ePlayerData[id][PDATA_CHARGER_ACTION] = false

                eCharger[CHARGER_NEXT_USE] = get_gametime() + 0.25
                eCharger[CHARGER_FLAGS] |= FLAG_SHOW
                eCharger[CHARGER_FLAGS] &= ~FLAG_GHOST

                chargerSetAnim(eCharger)
                chargerSetSolid(eCharger)
                ArraySetArray(g_aCharger, iItem, eCharger)

                client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_CREATE_NEW", eCharger[CHARGER_NAME])
                chargerSound(id, SOUND_MENU_NAV)
                chargerMenu(id, MENU_ROOT)
            }
            else
            {
                chargerSound(id, SOUND_MENU_NAV)
                chargerMenu(id, MENU_ROTATE)
            }
        }
        default:
        {
            chargerKill(eCharger[CHARGER_ID])
            chargerRemove(iItem)
            g_ePlayerData[id][PDATA_CHARGER_GHOST] = 0
            g_ePlayerData[id][PDATA_CHARGER_ACTION] = false
        }
    }

    menu_destroy( menu )
    return PLUGIN_HANDLED
}

public chargerTask()
{
    new iPlayers[MAX_PLAYERS], iNum, id,
        eCharger[CHARGER], iItem, iEnt, bool:bModified

    get_players(iPlayers, iNum, "ach")
    for ( new i = 0; i < iNum; i ++ )
    {
        id = iPlayers[i]

        if ( is_user_alive(id) )
        {
            iEnt = g_ePlayerData[id][PDATA_CHARGER_GHOST]
            if ( !iEnt || (iItem = chargerFind(iEnt, eCharger)) == -1 )
                continue

            chargerTrace(eCharger, iItem, id)
        }
    }

    for ( new i = 0; i < g_iCharger; i ++ )
    {
        ArrayGetArray(g_aCharger, i, eCharger)
        bModified = false

        if ( eCharger[CHARGER_FLAGS] & FLAG_SHOW
        && eCharger[CHARGER_NEXT_REFILL]
        && get_gametime() >= eCharger[CHARGER_NEXT_REFILL] )
        {
            chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_IDLE)
            eCharger[CHARGER_CAPACITY] = eCharger[CHARGER_CAPACITY_MAX]
            eCharger[CHARGER_NEXT_REFILL] = 0.0
            eCharger[CHARGER_NEXT_USE] = get_gametime() + 0.1

            if ( eCharger[CHARGER_NEXT_FLICKER] )
                eCharger[CHARGER_NEXT_FLICKER] = get_gametime() + random_float(4.0, 8.0)
            if ( eCharger[CHARGER_FLAGS] & FLAG_SOUND )
                chargerSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND] == SOUND_HEALTH ? SOUND_HEALTH_REFILL : SOUND_HEV_REFILL, CHAN_ITEM, false)

            bModified = true
        }
        else if ( eCharger[CHARGER_FLAGS] & FLAG_SHOW
        && eCharger[CHARGER_NEXT_FLICKER]
        && get_gametime() >= eCharger[CHARGER_NEXT_FLICKER]
        && eCharger[CHARGER_CAPACITY] )
        {
            chargerFlicker(eCharger[CHARGER_ID])
            eCharger[CHARGER_NEXT_FLICKER] = get_gametime() + random_float(4.0, 8.0)

            bModified = true
        }
        else if ( eCharger[CHARGER_FLAGS] & FLAG_DEAD
        && eCharger[CHARGER_SHOW] == SHOW_DEFAULT
        && eCharger[CHARGER_SPAWN_MODE] == SPAWN_DELAY
        && eCharger[CHARGER_NEXT_SPAWN]
        && get_gametime() >= eCharger[CHARGER_NEXT_SPAWN] )
        {
            if ( eCharger[CHARGER_SPAWN_CHANCE] >= random_float(0.0, 1.0) )
            {
                eCharger[CHARGER_FLAGS] |= FLAG_SHOW
                eCharger[CHARGER_NEXT_SPAWN] = 0.0

                chargerState(eCharger, true, true)
                chargerSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND] == SOUND_HEALTH ? SOUND_HEALTH_PLACE : SOUND_HEV_PLACE, CHAN_ITEM, false)

                bModified = true
            }
            else
            {
                eCharger[CHARGER_NEXT_SPAWN] = get_gametime() + random_float(eCharger[CHARGER_SPAWN_MIN], eCharger[CHARGER_SPAWN_MAX])
            }
        }

        if ( bModified )
            ArraySetArray(g_aCharger, i, eCharger)
    }
}

public chargerCreate(id, iItem)
{
    new iEnt
    iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))

    if ( !pev_valid(iEnt) )
        return

    new eCharger[CHARGER]
    ArrayGetArray(g_aChargerConfig, iItem, eCharger)

    eCharger[CHARGER_ID] = iEnt
    eCharger[CHARGER_ITEM] = iItem
    if ( id )
    {
        g_ePlayerData[id][PDATA_CHARGER_GHOST] = eCharger[CHARGER_ID]
        g_ePlayerData[id][PDATA_CHARGER_ACTION] = true
        g_ePlayerData[id][PDATA_OFFSET] = g_eSettings[SETTING_OFFSET_BASE]
        g_ePlayerData[id][PDATA_ROLL_OFFSET] = 0.0

        eCharger[CHARGER_FLAGS] |= FLAG_GHOST
    }

    set_pev(iEnt, pev_classname, g_szCN[eCharger[CHARGER_CLASS]])
    engfunc(EngFunc_SetModel, iEnt, eCharger[CHARGER_MODEL])

    ArrayPushArray(g_aCharger, eCharger)
    g_iCharger ++

    dllfunc(DLLFunc_Spawn, iEnt)
}

public chargerRemove(iItem)
{
    ArrayDeleteItem(g_aCharger, iItem)
    g_iCharger --
}

public saveData(id)
{
    new eCharger[CHARGER],
        szFile[64], iFile,
        szData[64]

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_Charger.ini", szFile)

    iFile = fopen(szFile, "wt")
    if ( !iFile )
        return PLUGIN_HANDLED

    for ( new i = 0; i < g_iCharger; i ++ )
    {
        ArrayGetArray(g_aCharger, i, eCharger)

        formatex(szData, charsmax(szData), "[%d]^n", i)
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "item = %d^n", eCharger[CHARGER_ITEM])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "origin = %.2f %.2f %.2f^n",
        eCharger[CHARGER_ORIGIN][0], eCharger[CHARGER_ORIGIN][1], eCharger[CHARGER_ORIGIN][2])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "angles = %.2f %.2f %.2f^n",
        eCharger[CHARGER_ANGLES][0], eCharger[CHARGER_ANGLES][1], eCharger[CHARGER_ANGLES][2])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "show = %d^n", eCharger[CHARGER_SHOW])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "flags = %d^n", eCharger[CHARGER_FLAGS])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "team = %d^n", eCharger[CHARGER_TEAM])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "spawn = %d^n", eCharger[CHARGER_SPAWN_MODE])
        fputs(iFile, szData)
    }

    client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_SAVE", szFile)
    fclose(iFile)

    chargerSound(id, SOUND_MENU_NAV)
    chargerMenu(id, MENU_ROOT)

    return PLUGIN_HANDLED
}

public loadData()
{
    new szFile[64], iFile,
        szData[64], szKey[32], szValue[32],
        Float:fOrigin[3], Float:fAngles[3], iItem,
        iShow, iFlags, iTeam, iSpawn,
        eCharger[CHARGER], iCount = -1

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_Charger.ini", szFile)

    iFile = fopen(szFile, "rt")
    if ( !iFile )
    {
        console_print(0, "%L %L", 0, "CHARGER_CHAT_TAG", 0, "CHARGER_CHAT_NO_DATA")
        return PLUGIN_HANDLED
    }

    while( !feof(iFile) )
    {
        fgets(iFile, szData, charsmax(szData))

        if ( szData[0] == '[' )
        {
            if ( iCount != -1 )
            {
                chargerCreate(0, iItem)
                ArrayGetArray(g_aCharger, iCount, eCharger)

                xs_vec_copy(fOrigin, eCharger[CHARGER_ORIGIN])
                xs_vec_copy(fAngles, eCharger[CHARGER_ANGLES])
                set_pev(eCharger[CHARGER_ID], pev_origin, fOrigin)
                set_pev(eCharger[CHARGER_ID], pev_angles, fAngles)
                eCharger[CHARGER_NEXT_USE] = get_gametime() + 0.25
                eCharger[CHARGER_SHOW] = iShow
                eCharger[CHARGER_FLAGS] = iFlags
                eCharger[CHARGER_TEAM] = iTeam
                eCharger[CHARGER_SPAWN_MODE] = iSpawn

                if ( eCharger[CHARGER_SHOW] == SHOW_DEFAULT
                && eCharger[CHARGER_SPAWN_MODE] == SPAWN_DELAY
                && eCharger[CHARGER_FLAGS] & FLAG_DEAD )
                    eCharger[CHARGER_NEXT_SPAWN] = get_gametime() + random_float(eCharger[CHARGER_SPAWN_MIN], eCharger[CHARGER_SPAWN_MAX])

                chargerSetBox(eCharger)
                if ( eCharger[CHARGER_FLAGS] & FLAG_SHOW )
                {
                    chargerSetAnim(eCharger, false)
                    chargerSetSolid(eCharger)
                }

                ArraySetArray(g_aCharger, iCount, eCharger)
            }

            iCount ++
        }
        else
        {
            strtok(szData, szKey, charsmax( szKey ), szValue, charsmax( szValue ), '=')
            trim(szKey)
            trim(szValue)

            if ( equal(szKey, "item") )
            {
                iItem = str_to_num(szValue)
            }
            else if ( equal(szKey, "origin") )
            {
                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fOrigin[0] = str_to_float(szKey)

                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fOrigin[1] = str_to_float(szKey)
                fOrigin[2] = str_to_float(szValue)
            }
            else if ( equal(szKey, "angles") )
            {
                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fAngles[0] = str_to_float(szKey)

                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fAngles[1] = str_to_float(szKey)
                fAngles[2] = str_to_float(szValue)
            }
            else if ( equal(szKey, "show") )
            {
                iShow = str_to_num(szValue)
            }
            else if ( equal(szKey, "flags") )
            {
                iFlags = str_to_num(szValue)
            }
            else if ( equal(szKey, "team") )
            {
                iTeam = str_to_num(szValue)
            }
            else if ( equal(szKey, "spawn") )
            {
                iSpawn = str_to_num(szValue)
            }
        }
    }

    if ( iCount != -1 )
    {
        chargerCreate(0, iItem)
        ArrayGetArray(g_aCharger, iCount, eCharger)

        xs_vec_copy(fOrigin, eCharger[CHARGER_ORIGIN])
        xs_vec_copy(fAngles, eCharger[CHARGER_ANGLES])
        set_pev(eCharger[CHARGER_ID], pev_origin, fOrigin)
        set_pev(eCharger[CHARGER_ID], pev_angles, fAngles)
        eCharger[CHARGER_NEXT_USE] = get_gametime() + 0.25
        eCharger[CHARGER_SHOW] = iShow
        eCharger[CHARGER_FLAGS] = iFlags
        eCharger[CHARGER_TEAM] = iTeam
        eCharger[CHARGER_SPAWN_MODE] = iSpawn

        if ( eCharger[CHARGER_SHOW] == SHOW_DEFAULT
        && eCharger[CHARGER_SPAWN_MODE] == SPAWN_DELAY
        && eCharger[CHARGER_FLAGS] & FLAG_DEAD )
            eCharger[CHARGER_NEXT_SPAWN] = get_gametime() + random_float(eCharger[CHARGER_SPAWN_MIN], eCharger[CHARGER_SPAWN_MAX])

        chargerSetBox(eCharger)
        if ( eCharger[CHARGER_FLAGS] & FLAG_SHOW )
        {
            chargerSetAnim(eCharger, false)
            chargerSetSolid(eCharger)
        }

        ArraySetArray(g_aCharger, iCount, eCharger)
    }

    fclose(iFile)
    return PLUGIN_HANDLED
}

public chargerNoClip(id)
{
    set_user_noclip(id, !get_user_noclip(id))

    chargerSound(id, SOUND_MENU_NAV)
    chargerMenu(id, MENU_ROOT)
}

public chargerGodMode(id)
{
    set_user_godmode(id, !get_user_godmode(id))

    chargerSound(id, SOUND_MENU_NAV)
    chargerMenu(id, MENU_ROOT)
}

public fwdSpawn(iEnt)
{
    if ( !isCharger(iEnt) )
        return HAM_IGNORED

    set_pev(iEnt, pev_solid, SOLID_NOT)
    set_pev(iEnt, pev_movetype, MOVETYPE_FLY)

    return HAM_IGNORED
}

public fwdTakeDamage(iEnt, iInflictor, iAttacker, Float:fDamage, iDamageBits)
{
    new eCharger[CHARGER], iItem

    if ( !isCharger(iEnt)
    || (iItem = chargerFind(iEnt, eCharger)) == -1
    || !(eCharger[CHARGER_FLAGS] & FLAG_SHOW) )
        return HAM_IGNORED

    new Float:fHealth
    pev(iEnt, pev_health, fHealth)

    if ( !(eCharger[CHARGER_FLAGS] & FLAG_BREAK)
    || eCharger[CHARGER_SHOW] == SHOW_FORCE_SHOW )
    {
        SetHamParamFloat(4, 0.0)
    }
    else if ( fDamage >= fHealth )
    {
        eCharger[CHARGER_FLAGS] &= ~FLAG_SHOW
        chargerState(eCharger, false, true)

        if ( eCharger[CHARGER_FLAGS] & FLAG_GIB )
            chargerGib(eCharger[CHARGER_ID], eCharger[CHARGER_GIB], eCharger[CHARGER_BREAK_FLAG])

        if ( eCharger[CHARGER_SHOW] == SHOW_DEFAULT
        && eCharger[CHARGER_SPAWN_MODE] == SPAWN_DELAY )
            eCharger[CHARGER_NEXT_SPAWN] = get_gametime() + random_float(eCharger[CHARGER_SPAWN_MIN], eCharger[CHARGER_SPAWN_MAX])

        if ( eCharger[CHARGER_FLAGS] & FLAG_EXPLODE )
            chargerExplode(eCharger)

        ArraySetArray(g_aCharger, iItem, eCharger)
        SetHamParamFloat(4, 0.0)
    }

    return HAM_IGNORED
}

public fwdTraceAttack(iEnt, iAttacker, Float:fDamage, Float:fDirection[3], iTr, iDamageBits)
{
    if ( !isCharger(iEnt) )
        return HAM_IGNORED

    new eCharger[CHARGER], Float:fEnd[3]
    get_tr2(iTr, TR_vecEndPos, fEnd)

    if ( chargerFind(iEnt, eCharger) != -1 )
    {
        if ( eCharger[CHARGER_FLAGS] & FLAG_SPARK )
        {
            chargerParticles(fEnd)
            chargerSparks(fEnd)
        }

        if ( eCharger[CHARGER_FLAGS] & FLAG_SOUND )
            chargerSound(iEnt, eCharger[CHARGER_BUST_SOUND], CHAN_VOICE, false)
    }

    return HAM_IGNORED
}

public fwdUpdateClientData(id, iSendWeapons, iHandle)
{
    if ( g_ePlayerData[id][PDATA_CHARGER_GHOST] )
    {
        set_cd(iHandle, CD_WeaponAnim, 0)
        set_cd(iHandle, CD_flNextAttack, get_gametime() + 0.1)
    }

    return FMRES_IGNORED
}

public fwdAddToFullPack(es, e, iEnt, iHost, iHostFlags, iPlayer, pSet)
{
    if ( !pev_valid(iEnt)
    || !isCharger(iEnt)
    || !get_orig_retval() )
        return FMRES_IGNORED

    new eCharger[CHARGER],
        bool:bHidden

    chargerFind(iEnt, eCharger)
    bHidden = !(eCharger[CHARGER_FLAGS] & FLAG_SHOW)

    if ( !g_ePlayerData[iHost][PDATA_CHARGER_ACTION] )
    {
        if ( bHidden )
            set_es(es, ES_Effects, EF_NODRAW)
    }
    else if ( eCharger[CHARGER_FLAGS] & FLAG_SELECT )
    {
        if ( eCharger[CHARGER_CAPACITY] > 0.0 ) set_es(es, ES_RenderColor, g_eSettings[SETTING_COLOR_ACTIVE])
        else                                    set_es(es, ES_RenderColor, g_eSettings[SETTING_COLOR_INACTIVE])

        set_es(es, ES_RenderAmt, 32)
        set_es(es, ES_RenderFx, kRenderFxGlowShell)

        if ( bHidden )
            set_es(es, ES_RenderMode, kRenderTransAlpha)
    }
    else if ( bHidden )
    {
        if ( eCharger[CHARGER_FLAGS] & FLAG_GHOST && eCharger[CHARGER_FLAGS] & FLAG_VALID )
            return FMRES_IGNORED

        set_es(es, ES_RenderMode, kRenderTransAlpha)
        set_es(es, ES_RenderAmt, g_eSettings[SETTING_GHOST_ALPHA])
    }

    return FMRES_IGNORED
}

public fwdKilled(id, iAttacker, bGib)
{
    if ( g_ePlayerData[id][PDATA_CHARGER_GHOST] )
    {
        new eCharger[CHARGER], iItem

        if ( (iItem = chargerFind(g_ePlayerData[id][PDATA_CHARGER_GHOST], eCharger)) != -1 )
        {
            chargerKill(g_ePlayerData[id][PDATA_CHARGER_GHOST])
            chargerRemove(iItem)
            g_ePlayerData[id][PDATA_CHARGER_GHOST] = 0
        }
    }
    else if ( g_ePlayerData[id][PDATA_CHARGER_USE] )
    {
        new eCharger[CHARGER]
        if ( chargerFind(g_ePlayerData[id][PDATA_CHARGER_USE], eCharger) != -1 )
        {
            chargerSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND] == SOUND_HEALTH ? SOUND_HEALTH_USE : SOUND_HEV_USE, CHAN_ITEM, false, SND_STOP)
            g_ePlayerData[id][PDATA_CHARGER_USE] = 0
        }
    }

    return HAM_IGNORED
}

public fwdPreThink(id)
{
    if ( !is_user_alive(id) )
        return HAM_IGNORED

    static eCharger[CHARGER], iItem,
    iEnt, iButton

    iButton = pev(id, pev_button)

    if ( g_ePlayerData[id][PDATA_CHARGER_GHOST] )
    {
        if ( get_gametime() > g_ePlayerData[id][PDATA_NEXT_OFFSET] )
        {
            if ( iButton & IN_ATTACK )
            {
                g_ePlayerData[id][PDATA_OFFSET]      += g_eSettings[SETTING_OFFSET_STEP]
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET_MIN], g_eSettings[SETTING_OFFSET_MAX])
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = get_gametime() + g_eSettings[SETTING_OFFSET_FREQ]
            }
            else if ( iButton & IN_ATTACK2 )
            {
                g_ePlayerData[id][PDATA_OFFSET]      -= g_eSettings[SETTING_OFFSET_STEP]
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET_MIN], g_eSettings[SETTING_OFFSET_MAX])
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = get_gametime() + g_eSettings[SETTING_OFFSET_FREQ]
            }
        }

        iButton &= ~(IN_ATTACK | IN_ATTACK2)
        set_pev(id, pev_button, iButton)
    }
    else
    {
        if ( (iEnt = chargerUse(id))
        && (iItem = chargerFind(iEnt, eCharger)) != -1
        && eCharger[CHARGER_FLAGS] & FLAG_SHOW
        && ( !g_ePlayerData[id][PDATA_CHARGER_USE] || g_ePlayerData[id][PDATA_CHARGER_USE] == eCharger[CHARGER_ID] ) )
        {
            if ( get_gametime() >= eCharger[CHARGER_NEXT_USE] )
                chargerSupply(id, eCharger, iItem)

            iButton &= ~IN_USE
            set_pev(id, pev_button, iButton)
        }
        else if ( g_ePlayerData[id][PDATA_CHARGER_USE]
        && chargerFind(g_ePlayerData[id][PDATA_CHARGER_USE], eCharger) != -1 )
        {
            chargerSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND] == SOUND_HEALTH ? SOUND_HEALTH_USE : SOUND_HEV_USE, CHAN_ITEM, false, SND_STOP)
            g_ePlayerData[id][PDATA_CHARGER_USE] = 0
        }
    }

    return HAM_IGNORED
}

public bool:chargerTrace(eCharger[CHARGER], iItem, id)
{
    new Float:fVec1[3], Float:fVec2[3],
        Float:fFraction

    pev(id, pev_origin, eCharger[CHARGER_ORIGIN])
    pev(id, pev_view_ofs, fVec1)
    xs_vec_add(eCharger[CHARGER_ORIGIN], fVec1, eCharger[CHARGER_ORIGIN])

    pev(id, pev_v_angle, fVec1)
    engfunc(EngFunc_MakeVectors, fVec1)
    global_get(glb_v_forward, fVec1)

    xs_vec_mul_scalar(fVec1, g_ePlayerData[id][PDATA_OFFSET], fVec2)
    xs_vec_add(fVec2, eCharger[CHARGER_ORIGIN], fVec2)

    engfunc(EngFunc_TraceLine, eCharger[CHARGER_ORIGIN], fVec2, DONT_IGNORE_MONSTERS, id, 0)
    get_tr2(0, TR_vecEndPos, eCharger[CHARGER_ORIGIN])
    get_tr2(0, TR_flFraction, fFraction)

    if ( fFraction < 1.0 )
    {
        get_tr2(0, TR_vecPlaneNormal, fVec1)
        eCharger[CHARGER_FLAGS] |= FLAG_VALID
    }
    else
    {
        xs_vec_mul_scalar(fVec1, -1.0, fVec1)
        g_ePlayerData[id][PDATA_ROLL_OFFSET] = 0.0
        eCharger[CHARGER_FLAGS] &= ~FLAG_VALID
    }

    engfunc(EngFunc_VecToAngles, fVec1, eCharger[CHARGER_ANGLES])
    eCharger[CHARGER_ANGLES][2] = g_ePlayerData[id][PDATA_ROLL_OFFSET]

    chargerSetBox(eCharger)
    chargerSetOffset(eCharger)
    set_pev(eCharger[CHARGER_ID], pev_origin, eCharger[CHARGER_ORIGIN])
    set_pev(eCharger[CHARGER_ID], pev_angles, eCharger[CHARGER_ANGLES])
    ArraySetArray(g_aCharger, iItem, eCharger)

    return fFraction < 1.0
}

public chargerUse(id)
{
    if ( !(pev(id, pev_button) & IN_USE) )
        return 0

    new Float:fOrigin[3], Float:fVec1[3],
        iEnt = -1

    pev(id, pev_origin, fOrigin)
    pev(id, pev_view_ofs, fVec1)
    xs_vec_add(fOrigin, fVec1, fOrigin)

    pev(id, pev_v_angle, fVec1)
    engfunc(EngFunc_MakeVectors, fVec1)
    global_get(glb_v_forward, fVec1)

    xs_vec_mul_scalar(fVec1, g_eSettings[SETTING_CHARGER_RANGE], fVec1)
    xs_vec_add(fVec1, fOrigin, fVec1)

    engfunc(EngFunc_TraceLine, fOrigin, fVec1, IGNORE_MONSTERS, id, 0)
    get_tr2(0, TR_vecEndPos, fOrigin)

    while( (iEnt = engfunc(EngFunc_FindEntityInSphere, iEnt, fOrigin, 5.0)) )
    {
        if ( !pev_valid(iEnt)
        || !isCharger(iEnt) )
            continue

        return iEnt
    }

    return 0
}

public chargerSupply(id, eCharger[CHARGER], iItem)
{
    if ( eCharger[CHARGER_CAPACITY] > 0.0
    && CsTeams:eCharger[CHARGER_TEAM] & cs_get_user_team(id) )
    {
        if ( !g_ePlayerData[id][PDATA_CHARGER_USE] )
        {
            g_ePlayerData[id][PDATA_CHARGER_USE] = eCharger[CHARGER_ID]

            if ( eCharger[CHARGER_FLAGS] & FLAG_WEAR )
            {
                if ( eCharger[CHARGER_OVERLOAD] >= eCharger[CHARGER_BREAK_THRESHOLD]
                && eCharger[CHARGER_BREAK_CHANCE] >= random_float(0.0, 1.0) )
                {
                    eCharger[CHARGER_FLAGS] &= ~FLAG_SHOW
                    chargerState(eCharger, false, true)

                    if ( eCharger[CHARGER_FLAGS] & FLAG_GIB )
                        chargerGib(eCharger[CHARGER_ID], eCharger[CHARGER_GIB], eCharger[CHARGER_BREAK_FLAG])

                    if ( eCharger[CHARGER_SHOW] == SHOW_DEFAULT
                    && eCharger[CHARGER_SPAWN_MODE] == SPAWN_DELAY )
                        eCharger[CHARGER_NEXT_SPAWN] = get_gametime() + random_float(eCharger[CHARGER_SPAWN_MIN], eCharger[CHARGER_SPAWN_MAX])

                    if ( eCharger[CHARGER_FLAGS] & FLAG_EXPLODE )
                        chargerExplode(eCharger)
                }

                eCharger[CHARGER_OVERLOAD] += eCharger[CHARGER_BREAK_RATIO]

                if ( !eCharger[CHARGER_NEXT_FLICKER]
                && eCharger[CHARGER_OVERLOAD] >= eCharger[CHARGER_BREAK_THRESHOLD] )
                    eCharger[CHARGER_NEXT_FLICKER] = get_gametime() + random_float(4.0, 8.0)
            }

            if ( eCharger[CHARGER_FLAGS] & FLAG_SOUND )
                chargerSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND] == SOUND_HEALTH ? SOUND_HEALTH_USE : SOUND_HEV_USE, CHAN_ITEM, false)
        }

        switch( eCharger[CHARGER_MODE] )
        {
            case MODE_HEALTH:   supplyHealth(id, eCharger)
            case MODE_ARMOR:    supplyArmor(id, eCharger)
        }

        if ( !eCharger[CHARGER_CAPACITY] )
        {
            chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_OFF)
            chargerSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND] == SOUND_HEALTH ? SOUND_HEALTH_EMPTY : SOUND_HEV_EMPTY, CHAN_ITEM, false)
            eCharger[CHARGER_NEXT_EMPTY] = get_gametime() + 1.0
            g_ePlayerData[id][PDATA_CHARGER_USE] = 0

            if ( eCharger[CHARGER_REFILL] > 0.0 )
                eCharger[CHARGER_NEXT_REFILL] = get_gametime() + eCharger[CHARGER_REFILL]
        }

        ArraySetArray(g_aCharger, iItem, eCharger)
    }
    else if ( get_gametime() >= eCharger[CHARGER_NEXT_EMPTY]
    && eCharger[CHARGER_FLAGS] & FLAG_SOUND )
    {
        chargerSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND] == SOUND_HEALTH ? SOUND_HEALTH_EMPTY : SOUND_HEV_EMPTY, CHAN_ITEM, false)
        eCharger[CHARGER_NEXT_EMPTY] = get_gametime() + 1.0

        ArraySetArray(g_aCharger, iItem, eCharger)
    }
}

supplyHealth(id, eCharger[CHARGER])
{
    new Float:fHealth,
        Float:fBoost

    pev(id, pev_health, fHealth)
    fBoost = floatclamp(eCharger[CHARGER_RATE], 0.0, eCharger[CHARGER_CAPACITY])
    if ( eCharger[CHARGER_LIMIT] > 0.0 )
    {
        if ( fHealth >= eCharger[CHARGER_LIMIT] )
            fBoost = 0.0
        else if ( fBoost + fHealth > eCharger[CHARGER_LIMIT] )
            fBoost = eCharger[CHARGER_LIMIT] - fHealth
    }

    set_pev(id, pev_health, fHealth + fBoost)
    eCharger[CHARGER_CAPACITY] -= fBoost
    eCharger[CHARGER_NEXT_USE] = get_gametime() + eCharger[CHARGER_DELAY]
}

supplyArmor(id, eCharger[CHARGER])
{
    new Float:fArmor,
        Float:fBoost

    pev(id, pev_armorvalue, fArmor)
    fBoost = floatclamp(eCharger[CHARGER_RATE], 0.0, eCharger[CHARGER_CAPACITY])
    if ( eCharger[CHARGER_LIMIT] )
    {
        if ( fArmor >= eCharger[CHARGER_LIMIT] )
            fBoost = 0.0
        else if ( fBoost + fArmor > eCharger[CHARGER_LIMIT] )
            fBoost = eCharger[CHARGER_LIMIT] - fArmor
    }

    set_pev(id, pev_armorvalue, fArmor + fBoost)
    eCharger[CHARGER_CAPACITY] -= fBoost
    eCharger[CHARGER_NEXT_USE] = get_gametime() + eCharger[CHARGER_DELAY]
}

stock chargerSetBox(eCharger[CHARGER])
{
    new Float:fMins[3], Float:fMaxs[3],
        Float:fForward[3], Float:fRight[3], Float:fUp[3],
        Float:fCorners[8][3]

    engfunc(EngFunc_AngleVectors, eCharger[CHARGER_ANGLES], fForward, fRight, fUp)

    switch ( eCharger[CHARGER_CLASS] )
    {
        case CLASS_HEALTH, CLASS_HEV: { xs_vec_copy(g_eSettings[SETTING_MINS_STANDARD], fMins); xs_vec_copy(g_eSettings[SETTING_MAXS_STANDARD], fMaxs); }
        case CLASS_CIV              : { xs_vec_copy(g_eSettings[SETTING_MINS_CIVILIAN], fMins); xs_vec_copy(g_eSettings[SETTING_MAXS_CIVILIAN], fMaxs); }
    }

    for ( new i = 0; i < 8; i ++ )
    {
        fCorners[i][0] = (i & 1) ? fMaxs[0] : fMins[0]
        fCorners[i][1] = (i & 2) ? fMaxs[1] : fMins[1]
        fCorners[i][2] = (i & 4) ? fMaxs[2] : fMins[2]

        boxRotate(fCorners[i], fForward, fRight, fUp)
    }

    xs_vec_copy(fCorners[0], fMins)
    xs_vec_copy(fCorners[0], fMaxs)
    for ( new i = 1; i < 8; i ++ )
    {
        fMins[0] = floatmin(fMins[0], fCorners[i][0])
        fMins[1] = floatmin(fMins[1], fCorners[i][1])
        fMins[2] = floatmin(fMins[2], fCorners[i][2])

        fMaxs[0] = floatmax(fMaxs[0], fCorners[i][0])
        fMaxs[1] = floatmax(fMaxs[1], fCorners[i][1])
        fMaxs[2] = floatmax(fMaxs[2], fCorners[i][2])
    }

    xs_vec_copy(fMins, eCharger[CHARGER_MINS])
    xs_vec_copy(fMaxs, eCharger[CHARGER_MAXS])
}

stock boxRotate(Float:fLocal[3], Float:fForward[3], Float:fRight[3], Float:fUp[3])
{
    new Float:fOut[3]
    fOut[0] = fLocal[0] * fForward[0] + fLocal[1] * fRight[0] + fLocal[2] * fUp[0]
    fOut[1] = fLocal[0] * fForward[1] + fLocal[1] * fRight[1] + fLocal[2] * fUp[1]
    fOut[2] = fLocal[0] * fForward[2] + fLocal[1] * fRight[2] + fLocal[2] * fUp[2]

    xs_vec_copy(fOut, fLocal)
}

stock chargerSetOffset(eCharger[CHARGER])
{
    new Float:fGaps[6], Float:fVec1[3],
        Float:fCurrentGap

    fGaps[0] = -eCharger[CHARGER_MINS][0]
    fGaps[1] = eCharger[CHARGER_MAXS][0]
    fGaps[2] = -eCharger[CHARGER_MINS][1]
    fGaps[3] = eCharger[CHARGER_MAXS][1]
    fGaps[4] = -eCharger[CHARGER_MINS][2]
    fGaps[5] = eCharger[CHARGER_MAXS][2]

    for ( new i = 0; i < 6; i ++ )
    {
        xs_vec_mul_scalar(g_fDirections[i], 9999.9, fVec1)
        xs_vec_add(fVec1, eCharger[CHARGER_ORIGIN], fVec1)
        engfunc(EngFunc_TraceLine, eCharger[CHARGER_ORIGIN], fVec1, DONT_IGNORE_MONSTERS, eCharger[CHARGER_ID], 0)
        get_tr2(0, TR_vecEndPos, fVec1)
        fCurrentGap = xs_vec_distance(eCharger[CHARGER_ORIGIN], fVec1)

        if ( fCurrentGap < fGaps[i] )
        {
            get_tr2(0, TR_vecPlaneNormal, fVec1)
            xs_vec_mul_scalar(fVec1, fGaps[i] - fCurrentGap, fVec1)
            xs_vec_add(eCharger[CHARGER_ORIGIN], fVec1, eCharger[CHARGER_ORIGIN])
        }
    }
}

stock chargerSetAnim(eCharger[CHARGER], bool:bPlaySound = true)
{
    if ( eCharger[CHARGER_CAPACITY] > 0.0 )
    {
        if ( eCharger[CHARGER_DELAY_ACTIVE] > 0.0 )
        {
            chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_OFF)
            eCharger[CHARGER_CAPACITY] = 0.0
            eCharger[CHARGER_NEXT_REFILL] = get_gametime() + eCharger[CHARGER_DELAY_ACTIVE]

            if ( bPlaySound && (eCharger[CHARGER_FLAGS] & FLAG_SOUND) )
                chargerSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND] == SOUND_HEALTH ? SOUND_HEALTH_EMPTY : SOUND_HEV_EMPTY, CHAN_ITEM, false)
        }
        else
        {
            chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_IDLE)

            if ( bPlaySound && (eCharger[CHARGER_FLAGS] & FLAG_SOUND) )
                chargerSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND] == SOUND_HEALTH ? SOUND_HEALTH_PLACE : SOUND_HEV_PLACE, CHAN_ITEM, false)
        }
    }
    else
    {
        chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_OFF)

        if ( bPlaySound && (eCharger[CHARGER_FLAGS] & FLAG_SOUND) )
            chargerSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND] == SOUND_HEALTH ? SOUND_HEALTH_EMPTY : SOUND_HEV_EMPTY, CHAN_ITEM, false)
    }
}

stock chargerSetSolid(eCharger[CHARGER])
{
    new Float:fMins[3],
        Float:fMaxs[3]

    set_pev(eCharger[CHARGER_ID], pev_solid, SOLID_BBOX)
    set_pev(eCharger[CHARGER_ID], pev_movetype, MOVETYPE_NONE)
    set_pev(eCharger[CHARGER_ID], pev_takedamage, DAMAGE_AIM)
    set_pev(eCharger[CHARGER_ID], pev_health, eCharger[CHARGER_HEALTH])

    xs_vec_copy(eCharger[CHARGER_MINS], fMins)
    xs_vec_copy(eCharger[CHARGER_MAXS], fMaxs)
    engfunc(EngFunc_SetSize, eCharger[CHARGER_ID], fMins, fMaxs)
    set_rendering(eCharger[CHARGER_ID], kRenderFxNone, 255, 255, 255, kRenderNormal, 255)
}

stock chargerSetSeq(iEnt, iSequence)
{
    set_pev(iEnt, pev_sequence, iSequence)
    set_pev(iEnt, pev_frame, 0.0)
    set_pev(iEnt, pev_framerate, 1.0)
    set_pev(iEnt, pev_animtime, get_gametime())
}

stock chargerParticles(Float:fOrigin[3])
{
    message_begin_f(MSG_PVS, SVC_TEMPENTITY, fOrigin)
    write_byte(TE_GUNSHOTDECAL)
    write_coord_f(fOrigin[0])
    write_coord_f(fOrigin[1])
    write_coord_f(fOrigin[2])
    write_short(0)
    write_byte(random_num(41, 45))
    message_end()
}

stock chargerSparks(Float:fOrigin[3])
{
    message_begin_f(MSG_PVS, SVC_TEMPENTITY, fOrigin)
    write_byte(TE_SPARKS)
    write_coord_f(fOrigin[0])
    write_coord_f(fOrigin[1])
    write_coord_f(fOrigin[2])
    message_end()
}

stock chargerFlicker(iEnt)
{
    new Float:fOrigin[3]
    pev(iEnt, pev_origin, fOrigin)

    chargerSound(iEnt, SOUND_FLICKER, CHAN_VOICE, false)
    chargerSparks(fOrigin)
}

stock chargerExplode(eCharger[CHARGER])
{
    new Float:fDistance, Float:fRatio, Float:fDamage,
        Float:fVec1[3], Float:fVec2[3], iEnt = -1

    xs_vec_copy(eCharger[CHARGER_ORIGIN], fVec1)
    message_begin_f(MSG_PVS, SVC_TEMPENTITY, fVec1)
    write_byte(TE_EXPLOSION)
    write_coord_f(fVec1[0])
    write_coord_f(fVec1[1])
    write_coord_f(fVec1[2])
    write_short(g_eSettings[SETTING_SPRITE_ZEROGXPLODE])
    write_byte(floatround(eCharger[CHARGER_EXPLODE_RADIUS] / 15.0))
    write_byte(15)
    write_byte(TE_EXPLFLAG_NONE)
    message_end()

    engfunc(EngFunc_MakeVectors, eCharger[CHARGER_ANGLES])
    global_get(glb_v_forward, fVec2)
    xs_vec_mul_scalar(fVec2, -9999.9, fVec2)
    fVec2[2] *= -1.0
    engfunc(EngFunc_TraceLine, fVec1, fVec2, IGNORE_MONSTERS, eCharger[CHARGER_ID], 0)
    get_tr2(0, TR_vecEndPos, fVec1)
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_WORLDDECAL)
    write_coord_f(fVec1[0])
    write_coord_f(fVec1[1])
    write_coord_f(fVec1[2])
    write_byte(random_num(46, 48))
    message_end()

    while ( (iEnt = engfunc(EngFunc_FindEntityInSphere, iEnt, eCharger[CHARGER_ORIGIN], eCharger[CHARGER_EXPLODE_RADIUS])) )
    {
        if ( !pev_valid(iEnt)
        || pev(iEnt, pev_takedamage) == DAMAGE_NO
        || iEnt == eCharger[CHARGER_ID] )
            continue

        pev(iEnt, pev_absmin, fVec1)
        pev(iEnt, pev_absmax, fVec2)
        xs_vec_add(fVec1, fVec2, fVec1)
        xs_vec_mul_scalar(fVec1, 0.5, fVec1)

        fDistance = xs_vec_distance(eCharger[CHARGER_ORIGIN], fVec1)
        if ( fDistance > eCharger[CHARGER_EXPLODE_RADIUS] )
            continue

        fRatio = 1.0 - fDistance / eCharger[CHARGER_EXPLODE_RADIUS]
        fDamage = eCharger[CHARGER_EXPLODE_DAMAGE] * fRatio

        fakedamage(iEnt, "weapon_hegrenade", fDamage, DMG_GRENADE)
    }
}

stock chargerGib(iEnt, iGib, iFlag)
{
    new Float:fOrigin[3]
    pev(iEnt, pev_origin, fOrigin)

    message_begin_f(MSG_PVS, SVC_TEMPENTITY, fOrigin)
    write_byte(TE_BREAKMODEL)
    write_coord_f(fOrigin[0])
    write_coord_f(fOrigin[1])
    write_coord_f(fOrigin[2])
    write_coord_f(32.0)
    write_coord_f(32.0)
    write_coord_f(32.0)
    write_coord_f(0.0)
    write_coord_f(0.0)
    write_coord_f(random_float(BREAK_VELO_Z_MIN, BREAK_VELO_Z_MAX))
    write_byte(random_num(BREAK_RANDOM_MIN, BREAK_RANDOM_MAX))
    write_short(iGib)
    write_byte(random_num(BREAK_LIFE_MIN, BREAK_LIFE_MAX))
    write_byte(random_num(BREAK_COUNT_MIN, BREAK_COUNT_MAX))
    write_byte(iFlag)
    message_end()
}

stock chargerState(eCharger[CHARGER], bool:bShow, bool:bFlag)
{
    if ( bShow )
    {
        set_pev(eCharger[CHARGER_ID], pev_solid, SOLID_BBOX)
        set_pev(eCharger[CHARGER_ID], pev_takedamage, DAMAGE_AIM)

        if ( bFlag )
        {
            set_pev(eCharger[CHARGER_ID], pev_health, eCharger[CHARGER_HEALTH])
            eCharger[CHARGER_CAPACITY] = eCharger[CHARGER_CAPACITY_MAX]

            eCharger[CHARGER_FLAGS] &= ~FLAG_DEAD
            chargerSetAnim(eCharger)
        }
    }
    else
    {
        set_pev(eCharger[CHARGER_ID], pev_solid, SOLID_NOT)
        set_pev(eCharger[CHARGER_ID], pev_takedamage, DAMAGE_NO)

        if ( bFlag )
            eCharger[CHARGER_FLAGS] |= FLAG_DEAD
    }
}

stock chargerSound(iEnt, iSound, iChan = CHAN_ITEM, bool:bPlayer = true, iFlags = 0)
{
    new szSample[64]

    switch( iSound )
    {
        case SOUND_MENU_NAV:        copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_MENU_NAV])
        case SOUND_MENU_REMOVE:     copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_MENU_REMOVE])
        case SOUND_MENU_ALERT:      copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_MENU_ALERT])
        case SOUND_HEALTH_PLACE:    copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_HEALTH_PLACE])
        case SOUND_HEALTH_USE:      copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_HEALTH_USE])
        case SOUND_HEALTH_EMPTY:    copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_HEALTH_EMPTY])
        case SOUND_HEALTH_REMOVE:   copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_HEALTH_REMOVE])
        case SOUND_HEALTH_REFILL:   copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_HEALTH_REFILL])
        case SOUND_HEV_PLACE:       copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_HEV_PLACE])
        case SOUND_HEV_USE:         copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_HEV_USE])
        case SOUND_HEV_EMPTY:       copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_HEV_EMPTY])
        case SOUND_HEV_REMOVE:      copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_HEV_REMOVE])
        case SOUND_HEV_REFILL:      copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_HEV_REFILL])
        case SOUND_FLICKER:         ArrayGetString(g_eSettings[SETTING_SOUND_FLICKER], random(ArraySize(g_eSettings[SETTING_SOUND_FLICKER])), szSample, charsmax(szSample))
        case SOUND_BUST_CONCRETE:   ArrayGetString(g_eSettings[SETTING_SOUND_BUST_CONCRETE], random(ArraySize(g_eSettings[SETTING_SOUND_BUST_CONCRETE])), szSample, charsmax(szSample))
        case SOUND_BUST_CRATE:      ArrayGetString(g_eSettings[SETTING_SOUND_BUST_CRATE], random(ArraySize(g_eSettings[SETTING_SOUND_BUST_CRATE])), szSample, charsmax(szSample))
        case SOUND_BUST_FLESH:      ArrayGetString(g_eSettings[SETTING_SOUND_BUST_FLESH], random(ArraySize(g_eSettings[SETTING_SOUND_BUST_FLESH])), szSample, charsmax(szSample))
        case SOUND_BUST_GLASS:      ArrayGetString(g_eSettings[SETTING_SOUND_BUST_GLASS], random(ArraySize(g_eSettings[SETTING_SOUND_BUST_GLASS])), szSample, charsmax(szSample))
        case SOUND_BUST_METAL:      ArrayGetString(g_eSettings[SETTING_SOUND_BUST_METAL], random(ArraySize(g_eSettings[SETTING_SOUND_BUST_METAL])), szSample, charsmax(szSample))
    }

    if ( bPlayer )
        client_cmd(iEnt, "spk %s", szSample)
    else
        engfunc(EngFunc_EmitSound, iEnt, iChan, szSample, VOL_NORM, ATTN_NORM, iFlags, PITCH_NORM)
}

stock bool:isCharger(iEnt)
{
    new szEnt[32]
    pev(iEnt, pev_classname, szEnt, charsmax(szEnt))

    for ( new i = 0; i < sizeof(g_szCN); i ++ )
    {
        if ( equali(szEnt, g_szCN[i]) )
            return true
    }

    return false
}

stock chargerKill(iEnt)
{
    if (pev_valid(iEnt))
        set_pev(iEnt, pev_flags, pev(iEnt, pev_flags) | FL_KILLME)
}

public chargerFind(iEnt, eCharger[CHARGER])
{
    for ( new i = 0; i < g_iCharger; i ++ )
    {
        ArrayGetArray(g_aCharger, i, eCharger)
        if ( eCharger[CHARGER_ID] == iEnt )
            return i
    }

    return -1
}

stock LogConfigError(const iLine, const szText[], any:...)
{
    new szError[MAX_PLATFORM_PATH_LENGTH]
    vformat(szError, charsmax(szError), szText, 3)

    log_to_file(ERROR_FILE, "^nLine %d: %s", iLine, szError)
}