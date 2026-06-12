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
*       v2.1: Bug fixes and config improvements.
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
#define BREAK_FLAG_METAL    2
#define CHARGER_KEY         1248
#define CHARGER_ARRAY_ITEM  pev_iuser1

/**
 *  Charger animation sequences.
 */
#define CHARGER_SEQ_IDLE    0
#define CHARGER_SEQ_OFF     1

new const PLUGIN_VERSION[]          = "2.1"
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

    FLAG_SHOW           = (1 << 3),
    FLAG_DEAD           = (1 << 4),
    FLAG_GHOST          = (1 << 5),
    FLAG_VALID          = (1 << 6),
    FLAG_SELECT         = (1 << 7)
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
    MODE_HEALTH,
    MODE_ARMOR
}

enum _:MAIN_SETTINGS
{
    SETTING_DEFAULT_MODEL[MAX_RESOURCE_PATH_LENGTH],
    SETTING_DEFAULT_GIB[MAX_RESOURCE_PATH_LENGTH],
    SETTING_DEFAULT_CLASS,
    SETTING_DEFAULT_FLAGS,
    SETTING_DEFAULT_TEAM,
    SETTING_DEFAULT_SOUND,
    SETTING_DEFAULT_MODE,

    Float:SETTING_DEFAULT_RATE,
    Float:SETTING_DEFAULT_LIMIT,
    Float:SETTING_DEFAULT_DELAY,
    Float:SETTING_DEFAULT_REFILL,
    Float:SETTING_DEFAULT_CAPACITY,
    Float:SETTING_DEFAULT_DELAY_ACTIVE,

    SETTING_DEFAULT_SPAWN_MODE,
    Float:SETTING_DEFAULT_SPAWN[2],
    Float:SETTING_DEFAULT_SPAWN_CHANCE,

    Float:SETTING_DEFAULT_HEALTH,
    Float:SETTING_DEFAULT_EXPLODE_DAMAGE,
    Float:SETTING_DEFAULT_EXPLODE_RADIUS,
    Float:SETTING_DEFAULT_BREAK_RATIO,
    Float:SETTING_DEFAULT_BREAK_THRESHOLD,
    Float:SETTING_DEFAULT_BREAK_CHANCE,

    Float:SETTING_MINS_STANDARD[3],
    Float:SETTING_MAXS_STANDARD[3],
    Float:SETTING_MINS_CIVILIAN[3],
    Float:SETTING_MAXS_CIVILIAN[3],

    bool:SETTING_CHARGER_LOAD,
    Float:SETTING_CHARGER_RANGE,
    Float:SETTING_OFFSET_BASE,
    Float:SETTING_OFFSET[2],
    Float:SETTING_OFFSET_STEP,
    Float:SETTING_OFFSET_FREQ,
    Float:SETTING_GHOST_FREQ,
    SETTING_GHOST_ALPHA,

    Float:SETTING_BREAK_VELO_Z[2],
    SETTING_BREAK_VELO_RANDOM[2],
    SETTING_BREAK_COUNT[2],
    SETTING_BREAK_LIFE[2],

    SETTING_SPRITE_ZEROGXPLODE,
    Array:SETTING_SOUND_FLICKER,
    Array:SETTING_SOUND_METAL,
    SETTING_SOUND_HEALTH_SHOT[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_HEALTH_NO[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_HEALTH_CHARGE[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_HEV_SHOT[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_HEV_NO[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_HEV_CHARGE[MAX_RESOURCE_PATH_LENGTH],
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
    CHARGER_CLASS,
    CHARGER_FLAGS,
    CHARGER_SHOW,
    CHARGER_TEAM,
    CHARGER_SOUND,
    CHARGER_MODE,
    CHARGER_NAME[MAX_VALUE_LENGTH],
    CHARGER_MODEL[MAX_RESOURCE_PATH_LENGTH],

    Float:CHARGER_ORIGIN[3],
    Float:CHARGER_ANGLES[3],
    Float:CHARGER_MINS[3],
    Float:CHARGER_MAXS[3],

    Float:CHARGER_RATE,
    Float:CHARGER_LIMIT,
    Float:CHARGER_DELAY,
    Float:CHARGER_REFILL,
    Float:CHARGER_CAPACITY,
    Float:CHARGER_CAPACITY_MAX,
    Float:CHARGER_DELAY_ACTIVE,

    CHARGER_SPAWN_MODE,
    Float:CHARGER_SPAWN[2],
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

    SOUND_HEALTH_SHOT,
    SOUND_HEALTH_NO,
    SOUND_HEALTH_CHARGE,
    SOUND_HEV_SHOT,
    SOUND_HEV_NO,
    SOUND_HEV_CHARGE,
    SOUND_FLICKER,
    SOUND_METAL
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
    "charger_health",
    "charger_hev",
    "charger_civ"
}

new Array:g_aCharger,
    Array:g_aChargerConfig,
    g_eSettings[MAIN_SETTINGS],
    g_ePlayerData[MAX_PLAYERS + 1][PLAYER_DATA],
    bool:g_bFileWasRead = false,
    g_iCharger,
    g_iChargerConfig,
    g_iMaxPlayers

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
    RegisterHam(Ham_TakeDamage, "info_target", "fwdTakeDamage")
    RegisterHam(Ham_TraceAttack, "info_target", "fwdTraceAttack", 1)
    RegisterHam(Ham_Player_PreThink, "player", "fwdPreThink")
    RegisterHam(Ham_Killed, "player", "fwdKilled", 1)

    register_logevent("eventRoundStart", 2, "1=Round_Start")
    set_task(g_eSettings[SETTING_GHOST_FREQ], "chargerTask", .flags = "b")

    chargerInit()
    g_iMaxPlayers = get_maxplayers()
}

public plugin_precache()
{
    g_aCharger = ArrayCreate(CHARGER)
    g_aChargerConfig = ArrayCreate(CHARGER)
    g_eSettings[SETTING_SOUND_FLICKER] = ArrayCreate(MAX_RESOURCE_PATH_LENGTH)
    g_eSettings[SETTING_SOUND_METAL] = ArrayCreate(MAX_RESOURCE_PATH_LENGTH)

    precache_model("models/metalplategibs.mdl")
    precache_sound("debris/metal1.wav")
    precache_sound("debris/metal2.wav")
    precache_sound("debris/metal3.wav")
    precache_sound("debris/bustmetal1.wav")
    precache_sound("debris/bustmetal2.wav")

    ReadFile()
}

public plugin_end()
{
    ArrayDestroy(g_aCharger)
    ArrayDestroy(g_aChargerConfig)
    ArrayDestroy(g_eSettings[SETTING_SOUND_FLICKER])
    ArrayDestroy(g_eSettings[SETTING_SOUND_METAL])
}

public cmdMenu(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1)
    || !is_user_alive(id)
    || g_ePlayerData[id][PDATA_CHARGER_GHOST] )
        return PLUGIN_HANDLED

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

stock ReadFile()
{
    if ( g_bFileWasRead )
    {
        for ( new id = 1; id <= g_iMaxPlayers; id ++ )
            if ( is_user_connected(id))
                UpdateData(id)

        ArrayClear(g_eSettings[SETTING_SOUND_FLICKER])
        ArrayClear(g_eSettings[SETTING_SOUND_METAL])
        ArrayClear(g_aChargerConfig)
        g_iChargerConfig = 0
    }

    new g_szFileName[MAX_RESOURCE_PATH_LENGTH]
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
        eCharger[CHARGER], iSection = SECTION_NONE, iLine, iPos

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
                        eCharger[CHARGER_CLASS]           = g_eSettings[SETTING_DEFAULT_CLASS]
                        eCharger[CHARGER_FLAGS]           = g_eSettings[SETTING_DEFAULT_FLAGS]
                        eCharger[CHARGER_TEAM]            = g_eSettings[SETTING_DEFAULT_TEAM]
                        eCharger[CHARGER_SOUND]           = g_eSettings[SETTING_DEFAULT_SOUND]
                        eCharger[CHARGER_MODE]            = g_eSettings[SETTING_DEFAULT_MODE]

                        eCharger[CHARGER_SPAWN_MODE]      = g_eSettings[SETTING_DEFAULT_SPAWN_MODE]
                        eCharger[CHARGER_SPAWN][0]        = g_eSettings[SETTING_DEFAULT_SPAWN][0]
                        eCharger[CHARGER_SPAWN][1]        = g_eSettings[SETTING_DEFAULT_SPAWN][1]
                        eCharger[CHARGER_SPAWN_CHANCE]    = g_eSettings[SETTING_DEFAULT_SPAWN_CHANCE]

                        eCharger[CHARGER_RATE]            = g_eSettings[SETTING_DEFAULT_RATE]
                        eCharger[CHARGER_LIMIT]           = g_eSettings[SETTING_DEFAULT_LIMIT]
                        eCharger[CHARGER_DELAY]           = g_eSettings[SETTING_DEFAULT_DELAY]
                        eCharger[CHARGER_REFILL]          = g_eSettings[SETTING_DEFAULT_REFILL]
                        eCharger[CHARGER_CAPACITY]        = g_eSettings[SETTING_DEFAULT_CAPACITY]
                        eCharger[CHARGER_DELAY_ACTIVE]    = g_eSettings[SETTING_DEFAULT_DELAY_ACTIVE]

                        eCharger[CHARGER_HEALTH]          = g_eSettings[SETTING_DEFAULT_HEALTH]
                        eCharger[CHARGER_EXPLODE_DAMAGE]  = g_eSettings[SETTING_DEFAULT_EXPLODE_DAMAGE]
                        eCharger[CHARGER_EXPLODE_RADIUS]  = g_eSettings[SETTING_DEFAULT_EXPLODE_RADIUS]
                        eCharger[CHARGER_BREAK_RATIO]     = g_eSettings[SETTING_DEFAULT_BREAK_RATIO]
                        eCharger[CHARGER_BREAK_THRESHOLD] = g_eSettings[SETTING_DEFAULT_BREAK_THRESHOLD]
                        eCharger[CHARGER_BREAK_CHANCE]    = g_eSettings[SETTING_DEFAULT_BREAK_CHANCE]

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
                iPos = contain(szValue, "#")
                if ( iPos != -1 )
                    szValue[iPos] = EOS

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
                        else if ( equali(szKey, "SETTING_DEFAULT_GIB") )
                        {
                            if ( !g_bFileWasRead )
                                g_eSettings[SETTING_DEFAULT_GIB] = precache_model(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_CLASS") )
                        {
                            g_eSettings[SETTING_DEFAULT_CLASS] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_FLAGS") )
                        {
                            g_eSettings[SETTING_DEFAULT_FLAGS] = read_flags(szValue)
                            g_eSettings[SETTING_DEFAULT_FLAGS] &= 7
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_TEAM") )
                        {
                            g_eSettings[SETTING_DEFAULT_TEAM] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_SOUND") )
                        {
                            g_eSettings[SETTING_DEFAULT_SOUND] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_MODE") )
                        {
                            g_eSettings[SETTING_DEFAULT_MODE] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_SPAWN_MODE") )
                        {
                            g_eSettings[SETTING_DEFAULT_SPAWN_MODE] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_SPAWN") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_DEFAULT_SPAWN][0] = str_to_float(szKey)
                            g_eSettings[SETTING_DEFAULT_SPAWN][1] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_SPAWN_CHANCE") )
                        {
                            g_eSettings[SETTING_DEFAULT_SPAWN_CHANCE] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_RATE") )
                        {
                            g_eSettings[SETTING_DEFAULT_RATE] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_LIMIT") )
                        {
                            g_eSettings[SETTING_DEFAULT_LIMIT] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_DELAY") )
                        {
                            g_eSettings[SETTING_DEFAULT_DELAY] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_REFILL") )
                        {
                            g_eSettings[SETTING_DEFAULT_REFILL] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_CAPACITY") )
                        {
                            g_eSettings[SETTING_DEFAULT_CAPACITY] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_DELAY_ACTIVE") )
                        {
                            g_eSettings[SETTING_DEFAULT_DELAY_ACTIVE] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_HEALTH") )
                        {
                            g_eSettings[SETTING_DEFAULT_HEALTH] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_EXPLODE_DAMAGE") )
                        {
                            g_eSettings[SETTING_DEFAULT_EXPLODE_DAMAGE] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_EXPLODE_RADIUS") )
                        {
                            g_eSettings[SETTING_DEFAULT_EXPLODE_RADIUS] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_BREAK_RATIO") )
                        {
                            g_eSettings[SETTING_DEFAULT_BREAK_RATIO] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_BREAK_THRESHOLD") )
                        {
                            g_eSettings[SETTING_DEFAULT_BREAK_THRESHOLD] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_BREAK_CHANCE") )
                        {
                            g_eSettings[SETTING_DEFAULT_BREAK_CHANCE] = str_to_float(szValue)
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
                        else if ( equali(szKey, "SETTING_CHARGER_RANGE") )
                        {
                            g_eSettings[SETTING_CHARGER_RANGE] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_BASE") )
                        {
                            g_eSettings[SETTING_OFFSET_BASE] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_OFFSET][0] = str_to_float(szKey)
                            g_eSettings[SETTING_OFFSET][1] = str_to_float(szValue)
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
                        else if ( equali(szKey, "SETTING_BREAK_VELO_Z") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_BREAK_VELO_Z][0] = str_to_float(szKey)
                            g_eSettings[SETTING_BREAK_VELO_Z][1] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_BREAK_VELO_RANDOM") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_BREAK_VELO_RANDOM][0] = str_to_num(szKey)
                            g_eSettings[SETTING_BREAK_VELO_RANDOM][1] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_BREAK_COUNT") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_BREAK_COUNT][0] = str_to_num(szKey)
                            g_eSettings[SETTING_BREAK_COUNT][1] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_BREAK_LIFE") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_BREAK_LIFE][0] = str_to_num(szKey)
                            g_eSettings[SETTING_BREAK_LIFE][1] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SPRITE_ZEROGXPLODE") )
                        {
                            if ( !g_bFileWasRead )
                                g_eSettings[SETTING_SPRITE_ZEROGXPLODE] = precache_model(szValue)
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
                        else if ( equali(szKey, "SETTING_SOUND_FLICKER") )
                        {
                            ArrayPushString(g_eSettings[SETTING_SOUND_FLICKER], szValue)
                            if ( !g_bFileWasRead ) precache_sound(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SOUND_METAL") )
                        {
                            ArrayPushString(g_eSettings[SETTING_SOUND_METAL], szValue)
                            if ( !g_bFileWasRead ) precache_sound(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SOUND_HEALTH_SHOT") )
                        {
                            copy(g_eSettings[SETTING_SOUND_HEALTH_SHOT], charsmax(g_eSettings[SETTING_SOUND_HEALTH_SHOT]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_HEALTH_SHOT])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_HEALTH_NO") )
                        {
                            copy(g_eSettings[SETTING_SOUND_HEALTH_NO], charsmax(g_eSettings[SETTING_SOUND_HEALTH_NO]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_HEALTH_NO])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_HEALTH_CHARGE") )
                        {
                            copy(g_eSettings[SETTING_SOUND_HEALTH_CHARGE], charsmax(g_eSettings[SETTING_SOUND_HEALTH_CHARGE]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_HEALTH_CHARGE])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_HEV_SHOT") )
                        {
                            copy(g_eSettings[SETTING_SOUND_HEV_SHOT], charsmax(g_eSettings[SETTING_SOUND_HEV_SHOT]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_HEV_SHOT])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_HEV_NO") )
                        {
                            copy(g_eSettings[SETTING_SOUND_HEV_NO], charsmax(g_eSettings[SETTING_SOUND_HEV_NO]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_HEV_NO])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_HEV_CHARGE") )
                        {
                            copy(g_eSettings[SETTING_SOUND_HEV_CHARGE], charsmax(g_eSettings[SETTING_SOUND_HEV_CHARGE]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_HEV_CHARGE])
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
                            eCharger[CHARGER_FLAGS] &= 7
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
                        else if ( equali(szKey, "CHARGER_SPAWN_MODE") )
                        {
                            eCharger[CHARGER_SPAWN_MODE] = str_to_num(szValue)
                            eCharger[CHARGER_SPAWN_MODE] = clamp(eCharger[CHARGER_SPAWN_MODE], SPAWN_NEVER, SPAWN_ROUND_START)
                        }
                        else if ( equali(szKey, "CHARGER_SPAWN") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            eCharger[CHARGER_SPAWN][0] = str_to_float(szKey)
                            eCharger[CHARGER_SPAWN][1] = str_to_float(szValue)

                            if ( eCharger[CHARGER_SPAWN][0] < 0.0 ) eCharger[CHARGER_SPAWN][0] = g_eSettings[SETTING_DEFAULT_SPAWN][0]
                            if ( eCharger[CHARGER_SPAWN][1] < 0.0 ) eCharger[CHARGER_SPAWN][1] = g_eSettings[SETTING_DEFAULT_SPAWN][1]
                        }
                        else if ( equali(szKey, "CHARGER_SPAWN_CHANCE") )
                        {
                            eCharger[CHARGER_SPAWN_CHANCE] = str_to_float(szValue)
                            eCharger[CHARGER_SPAWN_CHANCE] = floatclamp(eCharger[CHARGER_SPAWN_CHANCE], 0.0, 1.0)
                        }
                        else if ( equali(szKey, "CHARGER_RATE") )
                        {
                            eCharger[CHARGER_RATE] = str_to_float(szValue)
                            if ( eCharger[CHARGER_RATE] < 0.0 ) eCharger[CHARGER_RATE] = g_eSettings[SETTING_DEFAULT_RATE]
                        }
                        else if ( equali(szKey, "CHARGER_LIMIT") )
                        {
                            eCharger[CHARGER_LIMIT] = str_to_float(szValue)
                            if ( eCharger[CHARGER_LIMIT] < 0.0 ) eCharger[CHARGER_LIMIT] = g_eSettings[SETTING_DEFAULT_LIMIT]
                        }
                        else if ( equali(szKey, "CHARGER_DELAY") )
                        {
                            eCharger[CHARGER_DELAY] = str_to_float(szValue)
                            if ( eCharger[CHARGER_DELAY] < 0.0 ) eCharger[CHARGER_DELAY] = g_eSettings[SETTING_DEFAULT_DELAY]
                        }
                        else if ( equali(szKey, "CHARGER_REFILL") )
                        {
                            eCharger[CHARGER_REFILL] = str_to_float(szValue)
                            if ( eCharger[CHARGER_REFILL] < 0.0 ) eCharger[CHARGER_REFILL] = g_eSettings[SETTING_DEFAULT_REFILL]
                        }
                        else if ( equali(szKey, "CHARGER_CAPACITY") )
                        {
                            eCharger[CHARGER_CAPACITY] = str_to_float(szValue)
                            if ( eCharger[CHARGER_CAPACITY] < 0.0 ) eCharger[CHARGER_CAPACITY] = g_eSettings[SETTING_DEFAULT_CAPACITY]

                            eCharger[CHARGER_CAPACITY_MAX] = eCharger[CHARGER_CAPACITY]
                        }
                        else if ( equali(szKey, "CHARGER_DELAY_ACTIVE") )
                        {
                            eCharger[CHARGER_DELAY_ACTIVE] = str_to_float(szValue)
                            if ( eCharger[CHARGER_DELAY_ACTIVE] < 0.0 ) eCharger[CHARGER_DELAY_ACTIVE] = g_eSettings[SETTING_DEFAULT_DELAY_ACTIVE]
                        }
                        else if ( equali(szKey, "CHARGER_HEALTH") )
                        {
                            eCharger[CHARGER_HEALTH] = str_to_float(szValue)
                            if ( eCharger[CHARGER_HEALTH] < 0.0 ) eCharger[CHARGER_HEALTH] = g_eSettings[SETTING_DEFAULT_HEALTH]
                        }
                        else if ( equali(szKey, "CHARGER_EXPLODE_DAMAGE") )
                        {
                            eCharger[CHARGER_EXPLODE_DAMAGE] = str_to_float(szValue)
                            if ( eCharger[CHARGER_EXPLODE_DAMAGE] < 0.0 ) eCharger[CHARGER_EXPLODE_DAMAGE] = g_eSettings[SETTING_DEFAULT_EXPLODE_DAMAGE]
                        }
                        else if ( equali(szKey, "CHARGER_EXPLODE_RADIUS") )
                        {
                            eCharger[CHARGER_EXPLODE_RADIUS] = str_to_float(szValue)
                            if ( eCharger[CHARGER_EXPLODE_RADIUS] < 0.0 ) eCharger[CHARGER_EXPLODE_RADIUS] = g_eSettings[SETTING_DEFAULT_EXPLODE_RADIUS]
                        }
                        else if ( equali(szKey, "CHARGER_BREAK_RATIO") )
                        {
                            eCharger[CHARGER_BREAK_RATIO] = str_to_float(szValue)
                            if ( eCharger[CHARGER_BREAK_RATIO] < 0.0 || eCharger[CHARGER_BREAK_RATIO] > 100.0 ) eCharger[CHARGER_BREAK_RATIO] = g_eSettings[SETTING_DEFAULT_BREAK_RATIO]
                        }
                        else if ( equali(szKey, "CHARGER_BREAK_THRESHOLD") )
                        {
                            eCharger[CHARGER_BREAK_THRESHOLD] = str_to_float(szValue)
                            if ( eCharger[CHARGER_BREAK_THRESHOLD] < 0.0 || eCharger[CHARGER_BREAK_THRESHOLD] > 100.0 ) eCharger[CHARGER_BREAK_THRESHOLD] = g_eSettings[SETTING_DEFAULT_BREAK_THRESHOLD]
                        }
                        else if ( equali(szKey, "CHARGER_BREAK_CHANCE") )
                        {
                            eCharger[CHARGER_BREAK_CHANCE] = str_to_float(szValue)
                            eCharger[CHARGER_BREAK_CHANCE] = floatclamp(eCharger[CHARGER_BREAK_CHANCE], 0.0, 1.0)
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

    g_bFileWasRead = true
    fclose(iFile)
}

public client_authorized(id)
{
    set_task(DELAY_ON_CONNECT, "UpdateData", id)
}

public client_disconnected(id)
{
    new iItem
    if ( g_ePlayerData[id][PDATA_CHARGER_GHOST]
    && (iItem = pev(g_ePlayerData[id][PDATA_CHARGER_GHOST], CHARGER_ARRAY_ITEM)) != -1 )
    {
        chargerKill(g_ePlayerData[id][PDATA_CHARGER_GHOST])
        chargerRemove(iItem)
    }

    g_ePlayerData[id][PDATA_CHARGER_GHOST]  = 0
    g_ePlayerData[id][PDATA_CHARGER_USE]    = 0
    g_ePlayerData[id][PDATA_CHARGER_ACTION] = false
    g_ePlayerData[id][PDATA_CHARGER_MENU]   = 0
}

public UpdateData(id)
{
    g_ePlayerData[id][PDATA_OFFSET] = g_eSettings[SETTING_OFFSET_BASE]
}

public chargerInit()
{
    if ( g_eSettings[SETTING_CHARGER_LOAD] )
        loadData()
}

public chargerMenu(id, iType)
{
    new szData[64], iMenu
    formatex(szData, charsmax(szData), "%L", id, "CHARGER_MENU_TITLE", PLUGIN_VERSION)
    iMenu = menu_create(szData, g_szMenuHandler[iType])

    switch( iType )
    {
        case MENU_ROOT:   { menuRoot(id, iMenu); }
        case MENU_CREATE: { menuCreate(id, iMenu);  format(szData, charsmax(szData), "%s^n%L", szData, id, "CHARGER_ROOT_CREATE"); }
        case MENU_REMOVE: { menuRemove(id, iMenu);  format(szData, charsmax(szData), "%s^n%L", szData, id, "CHARGER_ROOT_REMOVE"); }
        case MENU_SHOW:   { menuShow(id, iMenu);    format(szData, charsmax(szData), "%s^n%L", szData, id, "CHARGER_ROOT_SHOW"); }
        case MENU_TEAM:   { menuTeam(id, iMenu);    format(szData, charsmax(szData), "%s^n%L", szData, id, "CHARGER_ROOT_TEAM"); }
        case MENU_SPAWN:  { menuSpawn(id, iMenu);   format(szData, charsmax(szData), "%s^n%L", szData, id, "CHARGER_ROOT_SPAWN"); }
        case MENU_ROTATE: { menuRotate(id, iMenu);  format(szData, charsmax(szData), "%s^n%L", szData, id, "CHARGER_ROOT_ROTATE"); }
    }

    if ( menu_pages(iMenu) > 1 )
        format(szData, charsmax(szData), "%s^n%L", szData, id, "CHARGER_MENU_TITLE_PAGE")

    menu_setprop(iMenu, MPROP_TITLE, szData)
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
                client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_LIMIT", MAX_ENT)
                chargerSound(id, SOUND_MENU_REMOVE)
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
                chargerSound(id, SOUND_MENU_REMOVE)
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
                chargerSound(id, SOUND_MENU_REMOVE)
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
                chargerSound(id, SOUND_MENU_REMOVE)
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
                chargerSound(id, SOUND_MENU_REMOVE)
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
    new eCharger[CHARGER], szItem[64]

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

            client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_REMOVE_ALL")
            g_ePlayerData[id][PDATA_CHARGER_MENU] = 0

            chargerSound(id, SOUND_MENU_ALERT)
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
    new eCharger[CHARGER], Float:fCurrentTime

    ArrayGetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)
    eCharger[CHARGER_FLAGS] &= ~FLAG_SELECT
    ArraySetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)
    fCurrentTime = get_gametime()

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
                eCharger[CHARGER_NEXT_SPAWN] = fCurrentTime + random_float(eCharger[CHARGER_SPAWN][0], eCharger[CHARGER_SPAWN][1])

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

            client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_SHOW_ALL_HIDDEN")
            chargerSound(id, SOUND_MENU_ALERT)
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

            client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_SHOW_ALL_SHOWN")

            chargerSound(id, SOUND_MENU_ALERT)
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
                    eCharger[CHARGER_NEXT_SPAWN] = fCurrentTime + random_float(eCharger[CHARGER_SPAWN][0], eCharger[CHARGER_SPAWN][1])

                ArraySetArray(g_aCharger, i, eCharger)
            }

            client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_SHOW_ALL_DEFAULT")

            chargerSound(id, SOUND_MENU_ALERT)
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

            client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_TEAM_ALL_NONE")

            chargerSound(id, SOUND_MENU_ALERT)
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

            client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_TEAM_ALL_T")

            chargerSound(id, SOUND_MENU_ALERT)
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

            client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_TEAM_ALL_CT")

            chargerSound(id, SOUND_MENU_ALERT)
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

            client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_TEAM_ALL_BOTH")

            chargerSound(id, SOUND_MENU_ALERT)
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
    new eCharger[CHARGER], Float:fCurrentTime

    ArrayGetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)
    eCharger[CHARGER_FLAGS] &= ~FLAG_SELECT
    ArraySetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)
    fCurrentTime = get_gametime()

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
                eCharger[CHARGER_NEXT_SPAWN] = fCurrentTime + random_float(eCharger[CHARGER_SPAWN][0], eCharger[CHARGER_SPAWN][1])

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

            client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_SPAWN_ALL_NEVER")

            chargerSound(id, SOUND_MENU_ALERT)
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
                    eCharger[CHARGER_NEXT_SPAWN] = fCurrentTime + random_float(eCharger[CHARGER_SPAWN][0], eCharger[CHARGER_SPAWN][1])

                ArraySetArray(g_aCharger, i, eCharger)
            }

            client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_SPAWN_ALL_DELAY")

            chargerSound(id, SOUND_MENU_ALERT)
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

            client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_SPAWN_ALL_ROUND_START")

            chargerSound(id, SOUND_MENU_ALERT)
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
    new eCharger[CHARGER], iItem
    if ( (iItem = chargerGet(eCharger, g_ePlayerData[id][PDATA_CHARGER_GHOST])) == -1 )
    {
        menu_destroy( menu )
        return PLUGIN_HANDLED
    }

    new Float:fCurrentTime
    fCurrentTime = get_gametime()

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
            if ( chargerTrace(eCharger, id, iItem) )
            {
                g_ePlayerData[id][PDATA_CHARGER_GHOST] = 0
                g_ePlayerData[id][PDATA_CHARGER_ACTION] = false

                eCharger[CHARGER_NEXT_USE] = fCurrentTime + 0.25
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
    new eCharger[CHARGER], iItem, bool:bModified, Float:fCurrentTime
    fCurrentTime = get_gametime()

    for ( new id = 1; id <= g_iMaxPlayers; id ++ )
    {
        if ( !g_ePlayerData[id][PDATA_CHARGER_GHOST]
        || (iItem = chargerGet(eCharger, g_ePlayerData[id][PDATA_CHARGER_GHOST])) == -1 )
            continue

        chargerTrace(eCharger, id, iItem)
    }

    for ( new i = 0; i < g_iCharger; i ++ )
    {
        ArrayGetArray(g_aCharger, i, eCharger)
        bModified = false

        if ( eCharger[CHARGER_FLAGS] & FLAG_SHOW )
        {
            if ( eCharger[CHARGER_NEXT_REFILL]
            && fCurrentTime >= eCharger[CHARGER_NEXT_REFILL] )
            {
                chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_IDLE)
                eCharger[CHARGER_CAPACITY] = eCharger[CHARGER_CAPACITY_MAX]
                eCharger[CHARGER_NEXT_REFILL] = 0.0
                eCharger[CHARGER_NEXT_USE] = fCurrentTime + 0.1

                if ( eCharger[CHARGER_NEXT_FLICKER] )
                    eCharger[CHARGER_NEXT_FLICKER] = fCurrentTime + random_float(4.0, 8.0)

                chargerSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND] == SOUND_HEALTH ? SOUND_HEALTH_SHOT : SOUND_HEV_SHOT, CHAN_ITEM, false)
                bModified = true
            }
            else if (eCharger[CHARGER_NEXT_FLICKER]
            && fCurrentTime >= eCharger[CHARGER_NEXT_FLICKER]
            && eCharger[CHARGER_CAPACITY] )
            {
                chargerFlicker(eCharger[CHARGER_ID])
                eCharger[CHARGER_NEXT_FLICKER] = fCurrentTime + random_float(4.0, 8.0)

                bModified = true
            }
        }
        else
        {
            if ( eCharger[CHARGER_FLAGS] & FLAG_DEAD
            && eCharger[CHARGER_SHOW] == SHOW_DEFAULT
            && eCharger[CHARGER_SPAWN_MODE] == SPAWN_DELAY
            && eCharger[CHARGER_NEXT_SPAWN]
            && fCurrentTime >= eCharger[CHARGER_NEXT_SPAWN] )
            {
                if ( eCharger[CHARGER_SPAWN_CHANCE] >= random_float(0.0, 1.0) )
                {
                    eCharger[CHARGER_FLAGS] |= FLAG_SHOW
                    eCharger[CHARGER_NEXT_SPAWN] = 0.0

                    chargerState(eCharger, true, true)
                    chargerSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND] == SOUND_HEALTH ? SOUND_HEALTH_SHOT : SOUND_HEV_SHOT, CHAN_ITEM, false)
                    bModified = true
                }
                else
                {
                    eCharger[CHARGER_NEXT_SPAWN] = fCurrentTime + random_float(eCharger[CHARGER_SPAWN][0], eCharger[CHARGER_SPAWN][1])
                }
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

    set_pev(iEnt, CHARGER_ARRAY_ITEM, g_iCharger)
    set_pev(iEnt, pev_impulse, CHARGER_KEY)
    set_pev(iEnt, pev_classname, g_szCN[eCharger[CHARGER_CLASS]])
    engfunc(EngFunc_SetModel, iEnt, eCharger[CHARGER_MODEL])

    ArrayPushArray(g_aCharger, eCharger)
    g_iCharger ++

    dllfunc(DLLFunc_Spawn, iEnt)
}

public chargerRemove(iItem)
{
    new eCharger[CHARGER]
    ArrayDeleteItem(g_aCharger, iItem)
    g_iCharger --

    for ( new i = iItem; i < g_iCharger; i ++ )
    {
        ArrayGetArray(g_aCharger, i, eCharger)
        set_pev(eCharger[CHARGER_ID], CHARGER_ARRAY_ITEM, i)
    }
}

public saveData(id)
{
    new eCharger[CHARGER],
        szFile[128], iFile,
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

        eCharger[CHARGER_FLAGS] &= ~(FLAG_GHOST | FLAG_SELECT | FLAG_VALID)
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
    new szFile[128], iFile,
        szData[64], szKey[32], szValue[32],
        Float:fOrigin[3], Float:fAngles[3], iItem,
        iShow, iFlags, iTeam, iSpawn, iCount = -1

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
                loadDataCharger(fOrigin, fAngles, iShow, iFlags, iTeam, iSpawn, iItem, iCount)

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
        loadDataCharger(fOrigin, fAngles, iShow, iFlags, iTeam, iSpawn, iItem, iCount)

    fclose(iFile)
    return PLUGIN_HANDLED
}

stock loadDataCharger(Float:fOrigin[3], Float:fAngles[3], iShow, iFlags, iTeam, iSpawnMode, iItem, iCount)
{
    new eCharger[CHARGER], Float:fCurrentTime

    fCurrentTime = get_gametime()
    chargerCreate(0, iItem)
    ArrayGetArray(g_aCharger, iCount, eCharger)

    xs_vec_copy(fOrigin, eCharger[CHARGER_ORIGIN])
    xs_vec_copy(fAngles, eCharger[CHARGER_ANGLES])
    set_pev(eCharger[CHARGER_ID], pev_origin, fOrigin)
    set_pev(eCharger[CHARGER_ID], pev_angles, fAngles)

    eCharger[CHARGER_NEXT_USE]   = fCurrentTime + 0.25
    eCharger[CHARGER_SHOW]       = iShow
    eCharger[CHARGER_FLAGS]      = iFlags
    eCharger[CHARGER_TEAM]       = iTeam
    eCharger[CHARGER_SPAWN_MODE] = iSpawnMode

    if ( eCharger[CHARGER_SHOW] == SHOW_DEFAULT
    && eCharger[CHARGER_SPAWN_MODE] == SPAWN_DELAY
    && eCharger[CHARGER_FLAGS] & FLAG_DEAD )
        eCharger[CHARGER_NEXT_SPAWN] = fCurrentTime + random_float(eCharger[CHARGER_SPAWN][0], eCharger[CHARGER_SPAWN][1])

    chargerSetBox(eCharger)
    if ( eCharger[CHARGER_FLAGS] & FLAG_SHOW )
    {
        chargerSetAnim(eCharger, false)
        chargerSetSolid(eCharger)
    }

    ArraySetArray(g_aCharger, iCount, eCharger)
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

    new eCharger[CHARGER]
    if ( chargerGet(eCharger, iEnt) == -1 )
        return FMRES_IGNORED

    new bool:bHidden
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
    if ( !isCharger(iEnt) )
        return HAM_IGNORED

    new eCharger[CHARGER], iItem
    if ( (iItem = chargerGet(eCharger, iEnt)) == -1
    || !(eCharger[CHARGER_FLAGS] & FLAG_SHOW) )
        return HAM_IGNORED

    new Float:fHealth, Float:fCurrentTime
    pev(iEnt, pev_health, fHealth)
    fCurrentTime = get_gametime()

    if ( !(eCharger[CHARGER_FLAGS] & FLAG_BREAK)
    || eCharger[CHARGER_SHOW] == SHOW_FORCE_SHOW )
    {
        SetHamParamFloat(4, 0.0)
    }
    else if ( fDamage >= fHealth )
    {
        eCharger[CHARGER_FLAGS] &= ~FLAG_SHOW
        chargerState(eCharger, false, true)

        chargerGib(eCharger[CHARGER_ID])
        if ( eCharger[CHARGER_SHOW] == SHOW_DEFAULT
        && eCharger[CHARGER_SPAWN_MODE] == SPAWN_DELAY )
            eCharger[CHARGER_NEXT_SPAWN] = fCurrentTime + random_float(eCharger[CHARGER_SPAWN][0], eCharger[CHARGER_SPAWN][1])

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

    new eCharger[CHARGER]
    if ( chargerGet(eCharger, iEnt) == -1 )
        return HAM_IGNORED

    new Float:fEnd[3]
    get_tr2(iTr, TR_vecEndPos, fEnd)

    chargerParticles(fEnd)
    chargerSparks(fEnd)
    chargerSound(iEnt, SOUND_METAL, CHAN_VOICE, false)

    return HAM_IGNORED
}

public fwdPreThink(id)
{
    if ( !is_user_alive(id) )
        return HAM_IGNORED

    static eCharger[CHARGER], iItem,
        iEnt, iButton, Float:fCurrentTime

    iButton = pev(id, pev_button)
    fCurrentTime = get_gametime()

    if ( g_ePlayerData[id][PDATA_CHARGER_GHOST] )
    {
        if ( fCurrentTime > g_ePlayerData[id][PDATA_NEXT_OFFSET] )
        {
            if ( iButton & IN_ATTACK )
            {
                g_ePlayerData[id][PDATA_OFFSET]      += g_eSettings[SETTING_OFFSET_STEP]
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET][0], g_eSettings[SETTING_OFFSET][1])
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = fCurrentTime + g_eSettings[SETTING_OFFSET_FREQ]
            }
            else if ( iButton & IN_ATTACK2 )
            {
                g_ePlayerData[id][PDATA_OFFSET]      -= g_eSettings[SETTING_OFFSET_STEP]
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET][0], g_eSettings[SETTING_OFFSET][1])
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = fCurrentTime + g_eSettings[SETTING_OFFSET_FREQ]
            }
        }

        iButton &= ~(IN_ATTACK | IN_ATTACK2)
        set_pev(id, pev_button, iButton)
    }
    else
    {
        if ( (iEnt = chargerUse(id))
        && ((iItem = chargerGet(eCharger, iEnt)) != -1)
        && eCharger[CHARGER_FLAGS] & FLAG_SHOW
        && ( !g_ePlayerData[id][PDATA_CHARGER_USE] || g_ePlayerData[id][PDATA_CHARGER_USE] == eCharger[CHARGER_ID] ) )
        {
            if ( fCurrentTime >= eCharger[CHARGER_NEXT_USE] )
                chargerSupply(id, eCharger, iItem, fCurrentTime)

            iButton &= ~IN_USE
            set_pev(id, pev_button, iButton)
        }
        else if ( g_ePlayerData[id][PDATA_CHARGER_USE]
        && (chargerGet(eCharger, g_ePlayerData[id][PDATA_CHARGER_USE]) != -1) )
        {
            chargerSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND] == SOUND_HEALTH ? SOUND_HEALTH_CHARGE : SOUND_HEV_CHARGE, CHAN_ITEM, false, SND_STOP)
            g_ePlayerData[id][PDATA_CHARGER_USE] = 0
        }
    }

    return HAM_IGNORED
}

public fwdKilled(id, iAttacker, bGib)
{
    g_ePlayerData[id][PDATA_CHARGER_ACTION] = false
    g_ePlayerData[id][PDATA_CHARGER_MENU]   = 0

    if ( g_ePlayerData[id][PDATA_CHARGER_GHOST] )
    {
        new eCharger[CHARGER], iItem

        if ( (iItem = chargerGet(eCharger, g_ePlayerData[id][PDATA_CHARGER_GHOST])) != -1 )
        {
            chargerKill(g_ePlayerData[id][PDATA_CHARGER_GHOST])
            chargerRemove(iItem)
        }

        g_ePlayerData[id][PDATA_CHARGER_GHOST] = 0
    }
    else if ( g_ePlayerData[id][PDATA_CHARGER_USE] )
    {
        new eCharger[CHARGER]
        if ( chargerGet(eCharger, g_ePlayerData[id][PDATA_CHARGER_GHOST]) != -1 )
            chargerSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND] == SOUND_HEALTH ? SOUND_HEALTH_CHARGE : SOUND_HEV_CHARGE, CHAN_ITEM, false, SND_STOP)

        g_ePlayerData[id][PDATA_CHARGER_USE] = 0
    }

    return HAM_IGNORED
}

public bool:chargerTrace(eCharger[CHARGER], id, iItem)
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

    engfunc(EngFunc_TraceLine, fOrigin, fVec1, DONT_IGNORE_MONSTERS, id, 0)
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

public chargerSupply(id, eCharger[CHARGER], iItem, Float:fCurrentTime)
{
    if ( eCharger[CHARGER_CAPACITY] > 0.0
    && CsTeams:eCharger[CHARGER_TEAM] & cs_get_user_team(id) )
    {
        if ( !g_ePlayerData[id][PDATA_CHARGER_USE] )
        {
            g_ePlayerData[id][PDATA_CHARGER_USE] = eCharger[CHARGER_ID]

            if ( eCharger[CHARGER_FLAGS] & FLAG_WEAR )
            {
                eCharger[CHARGER_OVERLOAD] += eCharger[CHARGER_BREAK_RATIO]

                if ( eCharger[CHARGER_OVERLOAD] >= eCharger[CHARGER_BREAK_THRESHOLD]
                && eCharger[CHARGER_BREAK_CHANCE] >= random_float(0.0, 1.0) )
                {
                    eCharger[CHARGER_FLAGS] &= ~FLAG_SHOW
                    chargerState(eCharger, false, true)

                    chargerGib(eCharger[CHARGER_ID])
                    if ( eCharger[CHARGER_SHOW] == SHOW_DEFAULT
                    && eCharger[CHARGER_SPAWN_MODE] == SPAWN_DELAY )
                        eCharger[CHARGER_NEXT_SPAWN] = fCurrentTime + random_float(eCharger[CHARGER_SPAWN][0], eCharger[CHARGER_SPAWN][1])

                    if ( eCharger[CHARGER_FLAGS] & FLAG_EXPLODE )
                        chargerExplode(eCharger)
                }

                if ( !eCharger[CHARGER_NEXT_FLICKER]
                && eCharger[CHARGER_OVERLOAD] >= eCharger[CHARGER_BREAK_THRESHOLD] )
                    eCharger[CHARGER_NEXT_FLICKER] = fCurrentTime + random_float(4.0, 8.0)
            }

            chargerSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND] == SOUND_HEALTH ? SOUND_HEALTH_CHARGE : SOUND_HEV_CHARGE, CHAN_ITEM, false)
        }

        switch( eCharger[CHARGER_MODE] )
        {
            case MODE_HEALTH:   supplyHealth(eCharger, id, fCurrentTime)
            case MODE_ARMOR:    supplyArmor(eCharger, id, fCurrentTime)
        }

        if ( !eCharger[CHARGER_CAPACITY] )
        {
            chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_OFF)
            chargerSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND] == SOUND_HEALTH ? SOUND_HEALTH_NO : SOUND_HEV_NO, CHAN_ITEM, false)

            eCharger[CHARGER_NEXT_EMPTY] = fCurrentTime + 1.0
            g_ePlayerData[id][PDATA_CHARGER_USE] = 0

            if ( eCharger[CHARGER_REFILL] > 0.0 )
                eCharger[CHARGER_NEXT_REFILL] = fCurrentTime + eCharger[CHARGER_REFILL]
        }

        ArraySetArray(g_aCharger, iItem, eCharger)
    }
    else if ( fCurrentTime >= eCharger[CHARGER_NEXT_EMPTY] )
    {
        chargerSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND] == SOUND_HEALTH ? SOUND_HEALTH_NO : SOUND_HEV_NO, CHAN_ITEM, false)
        eCharger[CHARGER_NEXT_EMPTY] = fCurrentTime + 1.0

        ArraySetArray(g_aCharger, iItem, eCharger)
    }
}

stock supplyHealth(eCharger[CHARGER], id, Float:fCurrentTime)
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
    eCharger[CHARGER_NEXT_USE] = fCurrentTime + eCharger[CHARGER_DELAY]
}

stock supplyArmor(eCharger[CHARGER], id, Float:fCurrentTime)
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
    eCharger[CHARGER_NEXT_USE] = fCurrentTime + eCharger[CHARGER_DELAY]
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

            if ( bPlaySound )
                chargerSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND] == SOUND_HEALTH ? SOUND_HEALTH_NO : SOUND_HEV_NO, CHAN_ITEM, false)
        }
        else
        {
            chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_IDLE)
            if ( bPlaySound )
                chargerSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND] == SOUND_HEALTH ? SOUND_HEALTH_SHOT : SOUND_HEV_SHOT, CHAN_ITEM, false)
        }
    }
    else
    {
        chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_OFF)
        if ( bPlaySound )
            chargerSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND] == SOUND_HEALTH ? SOUND_HEALTH_NO : SOUND_HEV_NO, CHAN_ITEM, false)
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

public chargerSparks(Float:fOrigin[])
{
    message_begin_f(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_SPARKS)
    write_coord_f(fOrigin[0])
    write_coord_f(fOrigin[1])
    write_coord_f(fOrigin[2])
    message_end()
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

stock chargerFlicker(iEnt)
{
    new Float:fOrigin[3]
    pev(iEnt, pev_origin, fOrigin)

    chargerSparks(fOrigin)
    chargerSound(iEnt, SOUND_FLICKER, CHAN_VOICE, false)
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

stock chargerGib(iEnt)
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
    write_coord_f(random_float(g_eSettings[SETTING_BREAK_VELO_Z][0], g_eSettings[SETTING_BREAK_VELO_Z][1]))
    write_byte(random_num(g_eSettings[SETTING_BREAK_VELO_RANDOM][0], g_eSettings[SETTING_BREAK_VELO_RANDOM][1]))
    write_short(g_eSettings[SETTING_DEFAULT_GIB])
    write_byte(random_num(g_eSettings[SETTING_BREAK_COUNT][0], g_eSettings[SETTING_BREAK_COUNT][1]))
    write_byte(random_num(g_eSettings[SETTING_BREAK_LIFE][0], g_eSettings[SETTING_BREAK_LIFE][1]))
    write_byte(BREAK_FLAG_METAL)
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
        case SOUND_HEALTH_SHOT:     copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_HEALTH_SHOT])
        case SOUND_HEALTH_NO:       copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_HEALTH_NO])
        case SOUND_HEALTH_CHARGE:   copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_HEALTH_CHARGE])
        case SOUND_HEV_SHOT:        copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_HEV_SHOT])
        case SOUND_HEV_NO:          copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_HEV_NO])
        case SOUND_HEV_CHARGE:      copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_HEV_CHARGE])
        case SOUND_FLICKER:         ArrayGetString(g_eSettings[SETTING_SOUND_FLICKER],  random(ArraySize(g_eSettings[SETTING_SOUND_FLICKER])),  szSample, charsmax(szSample))
        case SOUND_METAL:           ArrayGetString(g_eSettings[SETTING_SOUND_METAL],    random(ArraySize(g_eSettings[SETTING_SOUND_METAL])),    szSample, charsmax(szSample))
    }

    if ( bPlayer )
        client_cmd(iEnt, "spk %s", szSample)
    else
        engfunc(EngFunc_EmitSound, iEnt, iChan, szSample, VOL_NORM, ATTN_NORM, iFlags, PITCH_NORM)
}

stock chargerGet(eCharger[CHARGER], iEnt)
{
    new iItem
    iItem = pev(iEnt, CHARGER_ARRAY_ITEM)
    if ( iItem < 0 || iItem >= g_iCharger )
        return -1

    ArrayGetArray(g_aCharger, iItem, eCharger)
    return iItem
}

stock bool:isCharger(iEnt)
{
    return pev(iEnt, pev_impulse) == CHARGER_KEY
}

stock chargerKill(iEnt)
{
    if (pev_valid(iEnt))
        set_pev(iEnt, pev_flags, pev(iEnt, pev_flags) | FL_KILLME)
}

stock LogConfigError(const iLine, const szText[], any:...)
{
    new szError[MAX_PLATFORM_PATH_LENGTH]
    vformat(szError, charsmax(szError), szText, 3)

    log_to_file(ERROR_FILE, "^nLine %d: %s", iLine, szError)
}