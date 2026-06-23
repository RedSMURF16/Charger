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
*       v2.2: added FLAG_ACTIVE_DURATION, improved round-start logic.
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

new const PLUGIN_VERSION[]          = "2.2"
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
    DTYPE_FLOAT,
    DTYPE_FLOAT_RANGE,
    DTYPE_INT,
    DTYPE_BOOL,
    DTYPE_FLAGS,
    DTYPE_VECTOR,
    DTYPE_VECTOR_FLOAT,
    DTYPE_ARRAY_SOUND,
    DTYPE_STRING_MODEL,
    DTYPE_STRING_SOUND,
    DTYPE_STRING_SPRITE
}

enum
{
    CLASS_HEALTH,
    CLASS_HEV,
    CLASS_CIV
}

enum
{
    FLAG_BREAK              = (1 << 0),
    FLAG_EXPLODE            = (1 << 1),
    FLAG_WEAR               = (1 << 2),
    FLAG_REFILL             = (1 << 3),
    FLAG_ACTIVE_DELAY       = (1 << 4),
    FLAG_ACTIVE_DURATION    = (1 << 5),

    FLAG_SHOW               = (1 << 6),
    FLAG_DEAD               = (1 << 7),
    FLAG_GHOST              = (1 << 8),
    FLAG_VALID              = (1 << 9),
    FLAG_SELECT             = (1 << 10),
    FLAG_ACTIVE             = (1 << 11)
}

enum
{
    STATUS_DEFAULT,
    STATUS_FORCE_ENABLE,
    STATUS_FORCE_DISABLE
}

enum
{
    SHOW_DEFAULT,
    SHOW_FORCE_SHOW,
    SHOW_FORCE_HIDE
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

    Float:SETTING_DEFAULT_LIMIT,
    Float:SETTING_DEFAULT_CAPACITY,
    Float:SETTING_DEFAULT_RATE[2],
    Float:SETTING_DEFAULT_REFILL[2],
    Float:SETTING_DEFAULT_COOLDOWN[2],

    SETTING_DEFAULT_SPAWN_MODE,
    Float:SETTING_DEFAULT_SPAWN[2],
    Float:SETTING_DEFAULT_SPAWN_CHANCE,

    Float:SETTING_DEFAULT_ACTIVE_DELAY[2],
    Float:SETTING_DEFAULT_ACTIVE_DURATION[2],
    Float:SETTING_DEFAULT_ACTIVE_COOLDOWN[2],

    Float:SETTING_DEFAULT_HEALTH[2],
    Float:SETTING_DEFAULT_EXPLODE_DAMAGE[2],
    Float:SETTING_DEFAULT_EXPLODE_RADIUS[2],
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
    CHARGER_STATUS,
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

    Float:CHARGER_LIMIT,
    Float:CHARGER_CAPACITY,
    Float:CHARGER_CAPACITY_MAX,
    Float:CHARGER_RATE[2],
    Float:CHARGER_REFILL[2],
    Float:CHARGER_COOLDOWN[2],

    CHARGER_SPAWN_MODE,
    Float:CHARGER_SPAWN[2],
    Float:CHARGER_SPAWN_CHANCE,
    Float:CHARGER_NEXT_SPAWN,

    Float:CHARGER_ACTIVE_DELAY[2],
    Float:CHARGER_ACTIVE_DURATION[2],
    Float:CHARGER_ACTIVE_COOLDOWN[2],

    Float:CHARGER_HEALTH[2],
    Float:CHARGER_OVERLOAD,
    Float:CHARGER_BREAK_RATIO,
    Float:CHARGER_BREAK_THRESHOLD,
    Float:CHARGER_BREAK_CHANCE,
    Float:CHARGER_EXPLODE_DAMAGE[2],
    Float:CHARGER_EXPLODE_RADIUS[2],

    Float:CHARGER_NEXT_USE,
    Float:CHARGER_NEXT_EMPTY,
    Float:CHARGER_NEXT_REFILL,
    Float:CHARGER_NEXT_FLICKER,
    Float:CHARGER_NEXT_ENABLE,
    Float:CHARGER_NEXT_DISABLE
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
    MENU_STATUS,
    MENU_REMOVE,
    MENU_ROTATE
}

enum
{
    ROOT_CREATE,
    ROOT_STATUS,
    ROOT_REMOVE,
    ROOT_SAVE,

    ROOT_NOCLIP = 5,
    ROOT_GODMODE
}

enum
{
    STATUS_NEXT,
    STATUS_BACK,

    STATUS_CURRENT = 3,
    STATUS_ALL_ENABLE,
    STATUS_ALL_DISABLE,
    STATUS_ALL_DEFAULT
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
    "menuHandlerStatus",
    "menuHandlerRemove",
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

new g_szStatus[][] = {"CHARGER_DEFAULT", "CHARGER_ENABLED", "CHARGER_DISABLED"}
new g_szStatusChat[][] = {"CHARGER_CHAT_DEFAULT", "CHARGER_CHAT_ENABLED", "CHARGER_CHAT_DISABLED"}
new g_szStatusColor[][] = {"\d", "\y", "\r"}

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
        chargerReset(eCharger)

        if ( eCharger[CHARGER_SHOW] != SHOW_DEFAULT
        || eCharger[CHARGER_SPAWN_MODE] != SPAWN_ROUND_START )
        {
            ArraySetArray(g_aCharger, i, eCharger)
            continue
        }

        if ( eCharger[CHARGER_SPAWN_CHANCE] >= random_float(0.0, 1.0) )
        {
            eCharger[CHARGER_FLAGS] |= (FLAG_SHOW | FLAG_ACTIVE)
            chargerState(eCharger, true, true)
        }
        else
        {
            eCharger[CHARGER_FLAGS] &= ~(FLAG_SHOW | FLAG_ACTIVE)
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
                        eCharger[CHARGER_CLASS]                 = g_eSettings[SETTING_DEFAULT_CLASS]
                        eCharger[CHARGER_FLAGS]                 = g_eSettings[SETTING_DEFAULT_FLAGS]
                        eCharger[CHARGER_TEAM]                  = g_eSettings[SETTING_DEFAULT_TEAM]
                        eCharger[CHARGER_SOUND]                 = g_eSettings[SETTING_DEFAULT_SOUND]
                        eCharger[CHARGER_MODE]                  = g_eSettings[SETTING_DEFAULT_MODE]

                        eCharger[CHARGER_LIMIT]                 = g_eSettings[SETTING_DEFAULT_LIMIT]
                        eCharger[CHARGER_CAPACITY]              = g_eSettings[SETTING_DEFAULT_CAPACITY]
                        eCharger[CHARGER_CAPACITY_MAX]          = g_eSettings[SETTING_DEFAULT_CAPACITY]
                        eCharger[CHARGER_RATE][0]               = g_eSettings[SETTING_DEFAULT_RATE][0]
                        eCharger[CHARGER_RATE][1]               = g_eSettings[SETTING_DEFAULT_RATE][1]
                        eCharger[CHARGER_REFILL][0]             = g_eSettings[SETTING_DEFAULT_REFILL][0]
                        eCharger[CHARGER_REFILL][1]             = g_eSettings[SETTING_DEFAULT_REFILL][1]
                        eCharger[CHARGER_COOLDOWN][0]           = g_eSettings[SETTING_DEFAULT_COOLDOWN][0]
                        eCharger[CHARGER_COOLDOWN][1]           = g_eSettings[SETTING_DEFAULT_COOLDOWN][1]

                        eCharger[CHARGER_SPAWN_MODE]            = g_eSettings[SETTING_DEFAULT_SPAWN_MODE]
                        eCharger[CHARGER_SPAWN][0]              = g_eSettings[SETTING_DEFAULT_SPAWN][0]
                        eCharger[CHARGER_SPAWN][1]              = g_eSettings[SETTING_DEFAULT_SPAWN][1]
                        eCharger[CHARGER_SPAWN_CHANCE]          = g_eSettings[SETTING_DEFAULT_SPAWN_CHANCE]

                        eCharger[CHARGER_ACTIVE_DELAY][0]       = g_eSettings[SETTING_DEFAULT_ACTIVE_DELAY][0]
                        eCharger[CHARGER_ACTIVE_DELAY][1]       = g_eSettings[SETTING_DEFAULT_ACTIVE_DELAY][1]
                        eCharger[CHARGER_ACTIVE_DURATION][0]    = g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION][0]
                        eCharger[CHARGER_ACTIVE_DURATION][1]    = g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION][1]
                        eCharger[CHARGER_ACTIVE_COOLDOWN][0]    = g_eSettings[SETTING_DEFAULT_ACTIVE_COOLDOWN][0]
                        eCharger[CHARGER_ACTIVE_COOLDOWN][1]    = g_eSettings[SETTING_DEFAULT_ACTIVE_COOLDOWN][1]

                        eCharger[CHARGER_HEALTH][0]             = g_eSettings[SETTING_DEFAULT_HEALTH][0]
                        eCharger[CHARGER_HEALTH][1]             = g_eSettings[SETTING_DEFAULT_HEALTH][1]
                        eCharger[CHARGER_EXPLODE_DAMAGE][0]     = g_eSettings[SETTING_DEFAULT_EXPLODE_DAMAGE][0]
                        eCharger[CHARGER_EXPLODE_DAMAGE][1]     = g_eSettings[SETTING_DEFAULT_EXPLODE_DAMAGE][1]
                        eCharger[CHARGER_EXPLODE_RADIUS][0]     = g_eSettings[SETTING_DEFAULT_EXPLODE_RADIUS][0]
                        eCharger[CHARGER_EXPLODE_RADIUS][1]     = g_eSettings[SETTING_DEFAULT_EXPLODE_RADIUS][1]
                        eCharger[CHARGER_BREAK_RATIO]           = g_eSettings[SETTING_DEFAULT_BREAK_RATIO]
                        eCharger[CHARGER_BREAK_THRESHOLD]       = g_eSettings[SETTING_DEFAULT_BREAK_THRESHOLD]
                        eCharger[CHARGER_BREAK_CHANCE]          = g_eSettings[SETTING_DEFAULT_BREAK_CHANCE]

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
                            parseSetting(DTYPE_STRING_MODEL, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_MODEL], charsmax(g_eSettings[SETTING_DEFAULT_MODEL]))
                        else if ( equali(szKey, "SETTING_DEFAULT_GIB") )
                            parseSetting(DTYPE_STRING_MODEL, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_GIB], charsmax(g_eSettings[SETTING_DEFAULT_GIB]))
                        else if ( equali(szKey, "SETTING_DEFAULT_CLASS") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_CLASS], charsmax(g_eSettings[SETTING_DEFAULT_CLASS]))
                        else if ( equali(szKey, "SETTING_DEFAULT_FLAGS") )
                            parseSetting(DTYPE_FLAGS, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_FLAGS], charsmax(g_eSettings[SETTING_DEFAULT_FLAGS]))
                        else if ( equali(szKey, "SETTING_DEFAULT_TEAM") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_TEAM], charsmax(g_eSettings[SETTING_DEFAULT_TEAM]))
                        else if ( equali(szKey, "SETTING_DEFAULT_SOUND") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_SOUND], charsmax(g_eSettings[SETTING_DEFAULT_SOUND]))
                        else if ( equali(szKey, "SETTING_DEFAULT_MODE") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_MODE], charsmax(g_eSettings[SETTING_DEFAULT_MODE]))
                        else if ( equali(szKey, "SETTING_DEFAULT_LIMIT") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_LIMIT], charsmax(g_eSettings[SETTING_DEFAULT_LIMIT]))
                        else if ( equali(szKey, "SETTING_DEFAULT_CAPACITY") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_CAPACITY], charsmax(g_eSettings[SETTING_DEFAULT_CAPACITY]))
                        else if ( equali(szKey, "SETTING_DEFAULT_RATE") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_RATE], charsmax(g_eSettings[SETTING_DEFAULT_RATE]))
                        else if ( equali(szKey, "SETTING_DEFAULT_REFILL") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_REFILL], charsmax(g_eSettings[SETTING_DEFAULT_REFILL]))
                        else if ( equali(szKey, "SETTING_DEFAULT_COOLDOWN") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_COOLDOWN], charsmax(g_eSettings[SETTING_DEFAULT_COOLDOWN]))
                        else if ( equali(szKey, "SETTING_DEFAULT_SPAWN_MODE") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_SPAWN_MODE], charsmax(g_eSettings[SETTING_DEFAULT_SPAWN_MODE]))
                        else if ( equali(szKey, "SETTING_DEFAULT_SPAWN") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_SPAWN], charsmax(g_eSettings[SETTING_DEFAULT_SPAWN]))
                        else if ( equali(szKey, "SETTING_DEFAULT_SPAWN_CHANCE") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_SPAWN_CHANCE], charsmax(g_eSettings[SETTING_DEFAULT_SPAWN_CHANCE]))
                        else if ( equali(szKey, "SETTING_DEFAULT_ACTIVE_DELAY") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_ACTIVE_DELAY], charsmax(g_eSettings[SETTING_DEFAULT_ACTIVE_DELAY]))
                        else if ( equali(szKey, "SETTING_DEFAULT_ACTIVE_DURATION") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION], charsmax(g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION]))
                        else if ( equali(szKey, "SETTING_DEFAULT_ACTIVE_COOLDOWN") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_ACTIVE_COOLDOWN], charsmax(g_eSettings[SETTING_DEFAULT_ACTIVE_COOLDOWN]))
                        else if ( equali(szKey, "SETTING_DEFAULT_HEALTH") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_HEALTH], charsmax(g_eSettings[SETTING_DEFAULT_HEALTH]))
                        else if ( equali(szKey, "SETTING_DEFAULT_EXPLODE_DAMAGE") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_EXPLODE_DAMAGE], charsmax(g_eSettings[SETTING_DEFAULT_EXPLODE_DAMAGE]))
                        else if ( equali(szKey, "SETTING_DEFAULT_EXPLODE_RADIUS") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_EXPLODE_RADIUS], charsmax(g_eSettings[SETTING_DEFAULT_EXPLODE_RADIUS]))
                        else if ( equali(szKey, "SETTING_DEFAULT_BREAK_RATIO") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_BREAK_RATIO], charsmax(g_eSettings[SETTING_DEFAULT_BREAK_RATIO]))
                        else if ( equali(szKey, "SETTING_DEFAULT_BREAK_THRESHOLD") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_BREAK_THRESHOLD], charsmax(g_eSettings[SETTING_DEFAULT_BREAK_THRESHOLD]))
                        else if ( equali(szKey, "SETTING_DEFAULT_BREAK_CHANCE") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_BREAK_CHANCE], charsmax(g_eSettings[SETTING_DEFAULT_BREAK_CHANCE]))
                        else if ( equali(szKey, "SETTING_MINS_STANDARD") )
                            parseSetting(DTYPE_VECTOR_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_MINS_STANDARD], charsmax(g_eSettings[SETTING_MINS_STANDARD]))
                        else if ( equali(szKey, "SETTING_MAXS_STANDARD") )
                            parseSetting(DTYPE_VECTOR_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_MAXS_STANDARD], charsmax(g_eSettings[SETTING_MAXS_STANDARD]))
                        else if ( equali(szKey, "SETTING_MINS_CIVILIAN") )
                            parseSetting(DTYPE_VECTOR_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_MINS_CIVILIAN], charsmax(g_eSettings[SETTING_MINS_CIVILIAN]))
                        else if ( equali(szKey, "SETTING_MAXS_CIVILIAN") )
                            parseSetting(DTYPE_VECTOR_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_MAXS_CIVILIAN], charsmax(g_eSettings[SETTING_MAXS_CIVILIAN]))
                        else if ( equali(szKey, "SETTING_CHARGER_LOAD") )
                            parseSetting(DTYPE_BOOL, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_CHARGER_LOAD], charsmax(g_eSettings[SETTING_CHARGER_LOAD]))
                        else if ( equali(szKey, "SETTING_CHARGER_RANGE") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_CHARGER_RANGE], charsmax(g_eSettings[SETTING_CHARGER_RANGE]))
                        else if ( equali(szKey, "SETTING_OFFSET_BASE") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_OFFSET_BASE], charsmax(g_eSettings[SETTING_OFFSET_BASE]))
                        else if ( equali(szKey, "SETTING_OFFSET") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_OFFSET], charsmax(g_eSettings[SETTING_OFFSET]))
                        else if ( equali(szKey, "SETTING_OFFSET_STEP") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_OFFSET_STEP], charsmax(g_eSettings[SETTING_OFFSET_STEP]))
                        else if ( equali(szKey, "SETTING_OFFSET_FREQ") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_OFFSET_FREQ], charsmax(g_eSettings[SETTING_OFFSET_FREQ]))
                        else if ( equali(szKey, "SETTING_GHOST_FREQ") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_GHOST_FREQ], charsmax(g_eSettings[SETTING_GHOST_FREQ]))
                        else if ( equali(szKey, "SETTING_GHOST_ALPHA") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_GHOST_ALPHA], charsmax(g_eSettings[SETTING_GHOST_ALPHA]))
                        else if ( equali(szKey, "SETTING_BREAK_VELO_Z") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_BREAK_VELO_Z], charsmax(g_eSettings[SETTING_BREAK_VELO_Z]))
                        else if ( equali(szKey, "SETTING_BREAK_VELO_RANDOM") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_BREAK_VELO_RANDOM], charsmax(g_eSettings[SETTING_BREAK_VELO_RANDOM]))
                        else if ( equali(szKey, "SETTING_BREAK_COUNT") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_BREAK_COUNT], charsmax(g_eSettings[SETTING_BREAK_COUNT]))
                        else if ( equali(szKey, "SETTING_BREAK_LIFE") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_BREAK_LIFE], charsmax(g_eSettings[SETTING_BREAK_LIFE]))
                        else if ( equali(szKey, "SETTING_SPRITE_ZEROGXPLODE") )
                            parseSetting(DTYPE_STRING_SPRITE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SPRITE_ZEROGXPLODE], charsmax(g_eSettings[SETTING_SPRITE_ZEROGXPLODE]))
                        else if ( equali(szKey, "SETTING_SOUND_MENU_NAV") )
                            parseSetting(DTYPE_STRING_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SOUND_MENU_NAV], charsmax(g_eSettings[SETTING_SOUND_MENU_NAV]))
                        else if ( equali(szKey, "SETTING_SOUND_MENU_REMOVE") )
                            parseSetting(DTYPE_STRING_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SOUND_MENU_REMOVE], charsmax(g_eSettings[SETTING_SOUND_MENU_REMOVE]))
                        else if ( equali(szKey, "SETTING_SOUND_MENU_ALERT") )
                            parseSetting(DTYPE_STRING_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SOUND_MENU_ALERT], charsmax(g_eSettings[SETTING_SOUND_MENU_ALERT]))
                        else if ( equali(szKey, "SETTING_SOUND_FLICKER") )
                            parseSetting(DTYPE_ARRAY_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SOUND_FLICKER], charsmax(g_eSettings[SETTING_SOUND_FLICKER]))
                        else if ( equali(szKey, "SETTING_SOUND_METAL") )
                            parseSetting(DTYPE_ARRAY_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SOUND_METAL], charsmax(g_eSettings[SETTING_SOUND_METAL]))
                        else if ( equali(szKey, "SETTING_SOUND_HEALTH_SHOT") )
                            parseSetting(DTYPE_STRING_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SOUND_HEALTH_SHOT], charsmax(g_eSettings[SETTING_SOUND_HEALTH_SHOT]))
                        else if ( equali(szKey, "SETTING_SOUND_HEALTH_NO") )
                            parseSetting(DTYPE_STRING_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SOUND_HEALTH_NO], charsmax(g_eSettings[SETTING_SOUND_HEALTH_NO]))
                        else if ( equali(szKey, "SETTING_SOUND_HEALTH_CHARGE") )
                            parseSetting(DTYPE_STRING_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SOUND_HEALTH_CHARGE], charsmax(g_eSettings[SETTING_SOUND_HEALTH_CHARGE]))
                        else if ( equali(szKey, "SETTING_SOUND_HEV_SHOT") )
                            parseSetting(DTYPE_STRING_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SOUND_HEV_SHOT], charsmax(g_eSettings[SETTING_SOUND_HEV_SHOT]))
                        else if ( equali(szKey, "SETTING_SOUND_HEV_NO") )
                            parseSetting(DTYPE_STRING_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SOUND_HEV_NO], charsmax(g_eSettings[SETTING_SOUND_HEV_NO]))
                        else if ( equali(szKey, "SETTING_SOUND_HEV_CHARGE") )
                            parseSetting(DTYPE_STRING_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SOUND_HEV_CHARGE], charsmax(g_eSettings[SETTING_SOUND_HEV_CHARGE]))
                        else if ( equali(szKey, "SETTING_COLOR_ACTIVE") )
                            parseSetting(DTYPE_VECTOR, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_COLOR_ACTIVE], charsmax(g_eSettings[SETTING_COLOR_ACTIVE]))
                        else if ( equali(szKey, "SETTING_COLOR_INACTIVE") )
                            parseSetting(DTYPE_VECTOR, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_COLOR_INACTIVE], charsmax(g_eSettings[SETTING_COLOR_INACTIVE]))
                    }
                    case SECTION_CHARGER:
                    {
                        if ( equali(szKey, "CHARGER_MODEL") )
                            parseSetting(DTYPE_STRING_MODEL, szKey, charsmax(szKey), szValue, charsmax(szValue), eCharger[CHARGER_MODEL], charsmax(eCharger[CHARGER_MODEL]), g_eSettings[SETTING_DEFAULT_MODEL])
                        else if ( equali(szKey, "CHARGER_CLASS") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), eCharger[CHARGER_CLASS], charsmax(eCharger[CHARGER_CLASS]), g_eSettings[SETTING_DEFAULT_CLASS])
                        else if ( equali(szKey, "CHARGER_FLAGS") )
                            parseSetting(DTYPE_FLAGS, szKey, charsmax(szKey), szValue, charsmax(szValue), eCharger[CHARGER_FLAGS], charsmax(eCharger[CHARGER_FLAGS]), g_eSettings[SETTING_DEFAULT_FLAGS])
                        else if ( equali(szKey, "CHARGER_TEAM") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), eCharger[CHARGER_TEAM], charsmax(eCharger[CHARGER_TEAM]), g_eSettings[SETTING_DEFAULT_TEAM])
                        else if ( equali(szKey, "CHARGER_SOUND") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), eCharger[CHARGER_SOUND], charsmax(eCharger[CHARGER_SOUND]), g_eSettings[SETTING_DEFAULT_SOUND])
                        else if ( equali(szKey, "CHARGER_MODE") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), eCharger[CHARGER_MODE], charsmax(eCharger[CHARGER_MODE]), g_eSettings[SETTING_DEFAULT_MODE])
                        else if ( equali(szKey, "CHARGER_LIMIT") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), eCharger[CHARGER_LIMIT], charsmax(eCharger[CHARGER_LIMIT]), g_eSettings[SETTING_DEFAULT_LIMIT])
                        else if ( equali(szKey, "CHARGER_CAPACITY") )
                        {
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), eCharger[CHARGER_CAPACITY], charsmax(eCharger[CHARGER_CAPACITY]), g_eSettings[SETTING_DEFAULT_CAPACITY])
                            eCharger[CHARGER_CAPACITY_MAX] = eCharger[CHARGER_CAPACITY]
                        }
                        else if ( equali(szKey, "CHARGER_RATE") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), eCharger[CHARGER_RATE], charsmax(eCharger[CHARGER_RATE]), g_eSettings[SETTING_DEFAULT_RATE])
                        else if ( equali(szKey, "CHARGER_REFILL") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), eCharger[CHARGER_REFILL], charsmax(eCharger[CHARGER_REFILL]), g_eSettings[SETTING_DEFAULT_REFILL])
                        else if ( equali(szKey, "CHARGER_COOLDOWN") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), eCharger[CHARGER_COOLDOWN], charsmax(eCharger[CHARGER_COOLDOWN]), g_eSettings[SETTING_DEFAULT_COOLDOWN])
                        else if ( equali(szKey, "CHARGER_SPAWN_MODE") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), eCharger[CHARGER_SPAWN_MODE], charsmax(eCharger[CHARGER_SPAWN_MODE]), g_eSettings[SETTING_DEFAULT_SPAWN_MODE])
                        else if ( equali(szKey, "CHARGER_SPAWN") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), eCharger[CHARGER_SPAWN], charsmax(eCharger[CHARGER_SPAWN]), g_eSettings[SETTING_DEFAULT_SPAWN])
                        else if ( equali(szKey, "CHARGER_SPAWN_CHANCE") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), eCharger[CHARGER_SPAWN_CHANCE], charsmax(eCharger[CHARGER_SPAWN_CHANCE]), g_eSettings[SETTING_DEFAULT_SPAWN_CHANCE])
                        else if ( equali(szKey, "CHARGER_ACTIVE_DELAY") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), eCharger[CHARGER_ACTIVE_DELAY], charsmax(eCharger[CHARGER_ACTIVE_DELAY]), g_eSettings[SETTING_DEFAULT_ACTIVE_DELAY])
                        else if ( equali(szKey, "CHARGER_ACTIVE_DURATION") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), eCharger[CHARGER_ACTIVE_DURATION], charsmax(eCharger[CHARGER_ACTIVE_DURATION]), g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION])
                        else if ( equali(szKey, "CHARGER_ACTIVE_COOLDOWN") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), eCharger[CHARGER_ACTIVE_COOLDOWN], charsmax(eCharger[CHARGER_ACTIVE_COOLDOWN]), g_eSettings[SETTING_DEFAULT_ACTIVE_COOLDOWN])
                        else if ( equali(szKey, "CHARGER_HEALTH") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), eCharger[CHARGER_HEALTH], charsmax(eCharger[CHARGER_HEALTH]), g_eSettings[SETTING_DEFAULT_HEALTH])
                        else if ( equali(szKey, "CHARGER_EXPLODE_DAMAGE") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), eCharger[CHARGER_EXPLODE_DAMAGE], charsmax(eCharger[CHARGER_EXPLODE_DAMAGE]), g_eSettings[SETTING_DEFAULT_EXPLODE_DAMAGE])
                        else if ( equali(szKey, "CHARGER_EXPLODE_RADIUS") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), eCharger[CHARGER_EXPLODE_RADIUS], charsmax(eCharger[CHARGER_EXPLODE_RADIUS]), g_eSettings[SETTING_DEFAULT_EXPLODE_RADIUS])
                        else if ( equali(szKey, "CHARGER_BREAK_RATIO") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), eCharger[CHARGER_BREAK_RATIO], charsmax(eCharger[CHARGER_BREAK_RATIO]), g_eSettings[SETTING_DEFAULT_BREAK_RATIO])
                        else if ( equali(szKey, "CHARGER_BREAK_THRESHOLD") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), eCharger[CHARGER_BREAK_THRESHOLD], charsmax(eCharger[CHARGER_BREAK_THRESHOLD]), g_eSettings[SETTING_DEFAULT_BREAK_THRESHOLD])
                        else if ( equali(szKey, "CHARGER_BREAK_CHANCE") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), eCharger[CHARGER_BREAK_CHANCE], charsmax(eCharger[CHARGER_BREAK_CHANCE]), g_eSettings[SETTING_DEFAULT_BREAK_CHANCE])
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
        case MENU_STATUS: { menuStatus(id, iMenu);  format(szData, charsmax(szData), "%s^n%L", szData, id, "CHARGER_ROOT_STATUS"); }
        case MENU_REMOVE: { menuRemove(id, iMenu);  format(szData, charsmax(szData), "%s^n%L", szData, id, "CHARGER_ROOT_REMOVE"); }
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

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_ROOT_STATUS")
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
        case ROOT_STATUS:
        {
            if ( !g_iCharger )
            {
                client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_NO_CHARGER")
                chargerSound(id, SOUND_MENU_REMOVE)
            }
            else
            {
                chargerSound(id, SOUND_MENU_NAV)
                chargerMenu(id, MENU_STATUS)
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

public menuStatus(id, iMenu)
{
    new szItem[64], eCharger[CHARGER]

    menuNav(id, iMenu)
    ArrayGetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_STATUS_CURRENT",
    g_szStatusColor[eCharger[CHARGER_STATUS]], eCharger[CHARGER_NAME], id, g_szStatus[eCharger[CHARGER_STATUS]])
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_STATUS_ALL_ENABLE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_STATUS_ALL_DISABLE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_STATUS_ALL_DEFAULT")
    menu_additem(iMenu, szItem)

    g_ePlayerData[id][PDATA_CHARGER_ACTION] = true
    eCharger[CHARGER_FLAGS] |= FLAG_SELECT
    ArraySetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)
}

public menuHandlerStatus(id, menu, item)
{
    new eCharger[CHARGER]
    ArrayGetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)
    eCharger[CHARGER_FLAGS] &= ~FLAG_SELECT
    ArraySetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)

    switch( item )
    {
        case STATUS_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_CHARGER_MENU] >= g_iCharger - 1 )
                g_ePlayerData[id][PDATA_CHARGER_MENU] = 0
            else
                g_ePlayerData[id][PDATA_CHARGER_MENU] ++

            chargerSound(id, SOUND_MENU_NAV)
            chargerMenu(id, MENU_STATUS)
        }
        case STATUS_BACK:
        {
            if ( g_ePlayerData[id][PDATA_CHARGER_MENU] <= 0 )
                g_ePlayerData[id][PDATA_CHARGER_MENU] = g_iCharger - 1
            else
                g_ePlayerData[id][PDATA_CHARGER_MENU] --

            chargerSound(id, SOUND_MENU_NAV)
            chargerMenu(id, MENU_STATUS)
        }
        case STATUS_CURRENT:
        {
            if ( ++ eCharger[CHARGER_STATUS] > STATUS_FORCE_DISABLE )
                eCharger[CHARGER_STATUS] = STATUS_DEFAULT

            if ( eCharger[CHARGER_STATUS] == STATUS_FORCE_ENABLE
            || eCharger[CHARGER_STATUS] == STATUS_DEFAULT )
            {
                chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_IDLE)
                eCharger[CHARGER_FLAGS] |= FLAG_ACTIVE
            }
            else if ( eCharger[CHARGER_STATUS] == STATUS_FORCE_DISABLE )
            {
                chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_OFF)
                eCharger[CHARGER_FLAGS] &= ~FLAG_ACTIVE
            }

            client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_STATUS_CURRENT",
            eCharger[CHARGER_NAME], id, g_szStatusChat[eCharger[CHARGER_STATUS]])
            ArraySetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)

            chargerSound(id, SOUND_MENU_NAV)
            chargerMenu(id, MENU_STATUS)
        }
        case STATUS_ALL_ENABLE:
        {
            for ( new i = 0; i < g_iCharger; i ++ )
            {
                ArrayGetArray(g_aCharger, i, eCharger)
                eCharger[CHARGER_FLAGS] |= FLAG_ACTIVE
                eCharger[CHARGER_STATUS] = STATUS_FORCE_ENABLE
                chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_IDLE)

                ArraySetArray(g_aCharger, i, eCharger)
            }

            client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_STATUS_ALL_ENABLED")
            chargerSound(id, SOUND_MENU_ALERT)
            chargerMenu(id, MENU_STATUS)
        }
        case STATUS_ALL_DISABLE:
        {
            for ( new i = 0; i < g_iCharger; i ++ )
            {
                ArrayGetArray(g_aCharger, i, eCharger)
                eCharger[CHARGER_FLAGS] &= ~FLAG_ACTIVE
                eCharger[CHARGER_STATUS] = STATUS_FORCE_DISABLE
                chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_OFF)

                ArraySetArray(g_aCharger, i, eCharger)
            }

            client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_STATUS_ALL_DISABLED")
            chargerSound(id, SOUND_MENU_ALERT)
            chargerMenu(id, MENU_STATUS)
        }
        case STATUS_ALL_DEFAULT:
        {
            for ( new i = 0; i < g_iCharger; i ++ )
            {
                ArrayGetArray(g_aCharger, i, eCharger)
                eCharger[CHARGER_FLAGS] |= FLAG_ACTIVE
                eCharger[CHARGER_STATUS] = STATUS_DEFAULT
                chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_IDLE)
                ArraySetArray(g_aCharger, i, eCharger)
            }

            client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_STATUS_ALL_DEFAULT")
            chargerSound(id, SOUND_MENU_ALERT)
            chargerMenu(id, MENU_STATUS)
        }
        default:
        {
            g_ePlayerData[id][PDATA_CHARGER_ACTION] = false
            g_ePlayerData[id][PDATA_CHARGER_MENU] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuRemove(id, iMenu)
{
    new szItem[64], eCharger[CHARGER]

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
                eCharger[CHARGER_FLAGS] |= (FLAG_SHOW | FLAG_ACTIVE)
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
        if ( !is_user_alive(id)
        || !g_ePlayerData[id][PDATA_CHARGER_GHOST]
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
            if ( eCharger[CHARGER_FLAGS] & FLAG_ACTIVE )
            {
                if ( eCharger[CHARGER_NEXT_FLICKER]
                && fCurrentTime >= eCharger[CHARGER_NEXT_FLICKER] )
                {
                    chargerFlicker(eCharger[CHARGER_ID])
                    eCharger[CHARGER_NEXT_FLICKER] = fCurrentTime + random_float(4.0, 8.0)

                    bModified = true
                }

                if ( eCharger[CHARGER_NEXT_DISABLE] > 0.0
                && fCurrentTime >= eCharger[CHARGER_NEXT_DISABLE] )
                {
                    chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_OFF)
                    eCharger[CHARGER_FLAGS] &= ~FLAG_ACTIVE
                    eCharger[CHARGER_NEXT_DISABLE] = 0.0
                    eCharger[CHARGER_NEXT_ENABLE] = fCurrentTime + random_float(eCharger[CHARGER_ACTIVE_COOLDOWN][0], eCharger[CHARGER_ACTIVE_COOLDOWN][1])

                    chargerSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND] == SOUND_HEALTH ? SOUND_HEALTH_NO : SOUND_HEV_NO, CHAN_ITEM, false)
                    bModified = true
                }
            }
            else
            {
                if ( eCharger[CHARGER_NEXT_REFILL]
                && fCurrentTime >= eCharger[CHARGER_NEXT_REFILL] )
                {
                    chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_IDLE)
                    eCharger[CHARGER_FLAGS] |= FLAG_ACTIVE
                    eCharger[CHARGER_CAPACITY] = eCharger[CHARGER_CAPACITY_MAX]
                    eCharger[CHARGER_NEXT_REFILL] = 0.0
                    eCharger[CHARGER_NEXT_USE] = fCurrentTime + 0.1

                    if ( eCharger[CHARGER_NEXT_FLICKER] )
                        eCharger[CHARGER_NEXT_FLICKER] = fCurrentTime + random_float(4.0, 8.0)

                    chargerSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND] == SOUND_HEALTH ? SOUND_HEALTH_SHOT : SOUND_HEV_SHOT, CHAN_ITEM, false)
                    bModified = true
                }

                if ( eCharger[CHARGER_NEXT_ENABLE] > 0.0
                && fCurrentTime >= eCharger[CHARGER_NEXT_ENABLE] )
                {
                    chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_IDLE)
                    eCharger[CHARGER_FLAGS] |= FLAG_ACTIVE
                    eCharger[CHARGER_NEXT_ENABLE] = 0.0

                    if ( eCharger[CHARGER_FLAGS] & FLAG_ACTIVE_DURATION )
                        eCharger[CHARGER_NEXT_DISABLE] = fCurrentTime + random_float(eCharger[CHARGER_ACTIVE_DURATION][0], eCharger[CHARGER_ACTIVE_DURATION][1])

                    chargerSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND] == SOUND_HEALTH ? SOUND_HEALTH_SHOT : SOUND_HEV_SHOT, CHAN_ITEM, false)
                    bModified = true
                }
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

        formatex(szData, charsmax(szData), "status = %d^n", eCharger[CHARGER_STATUS])
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
        iStatus, iShow, iFlags, iTeam, iSpawn, iCount = -1

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
                loadDataCharger(fOrigin, fAngles, iStatus, iShow, iFlags, iTeam, iSpawn, iItem, iCount)

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
            else if ( equal(szKey, "status") )
            {
                iStatus = str_to_num(szValue)
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
        loadDataCharger(fOrigin, fAngles, iStatus, iShow, iFlags, iTeam, iSpawn, iItem, iCount)

    fclose(iFile)
    return PLUGIN_HANDLED
}

stock loadDataCharger(Float:fOrigin[3], Float:fAngles[3], iStatus, iShow, iFlags, iTeam, iSpawnMode, iItem, iCount)
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
    eCharger[CHARGER_STATUS]     = iStatus
    eCharger[CHARGER_SHOW]       = iShow
    eCharger[CHARGER_FLAGS]      = iFlags
    eCharger[CHARGER_TEAM]       = iTeam
    eCharger[CHARGER_SPAWN_MODE] = iSpawnMode

    if ( eCharger[CHARGER_SHOW] == SHOW_DEFAULT
    && eCharger[CHARGER_SPAWN_MODE] == SPAWN_DELAY
    && eCharger[CHARGER_FLAGS] & FLAG_DEAD )
        eCharger[CHARGER_NEXT_SPAWN] = fCurrentTime + random_float(eCharger[CHARGER_SPAWN][0], eCharger[CHARGER_SPAWN][1])

    chargerSetBox(eCharger)
    chargerSetAnim(eCharger, false)
    if ( eCharger[CHARGER_FLAGS] & FLAG_SHOW )
        chargerSetSolid(eCharger)

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
        if ( eCharger[CHARGER_FLAGS] & FLAG_ACTIVE )    set_es(es, ES_RenderColor, g_eSettings[SETTING_COLOR_ACTIVE])
        else                                            set_es(es, ES_RenderColor, g_eSettings[SETTING_COLOR_INACTIVE])

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
        if ( chargerGet(eCharger, g_ePlayerData[id][PDATA_CHARGER_USE]) != -1 )
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

public chargerSupply(id, eCharger[CHARGER], iItem, Float:fCurrentTime)
{
    if ( eCharger[CHARGER_FLAGS] & FLAG_ACTIVE
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

            eCharger[CHARGER_FLAGS] &= ~FLAG_ACTIVE
            eCharger[CHARGER_NEXT_EMPTY] = fCurrentTime + 1.0
            eCharger[CHARGER_NEXT_ENABLE] = 0.0
            g_ePlayerData[id][PDATA_CHARGER_USE] = 0

            if ( eCharger[CHARGER_FLAGS] & FLAG_REFILL )
                eCharger[CHARGER_NEXT_REFILL] = fCurrentTime + random_float(eCharger[CHARGER_REFILL][0], eCharger[CHARGER_REFILL][1])
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
    new Float:fHealth, Float:fBoost

    pev(id, pev_health, fHealth)
    fBoost = random_float(eCharger[CHARGER_RATE][0], eCharger[CHARGER_RATE][1])
    fBoost = floatclamp(fBoost, 0.0, eCharger[CHARGER_CAPACITY])
    if ( eCharger[CHARGER_LIMIT] > 0.0 )
    {
        if ( fHealth >= eCharger[CHARGER_LIMIT] )
            fBoost = 0.0
        else if ( fBoost + fHealth > eCharger[CHARGER_LIMIT] )
            fBoost = eCharger[CHARGER_LIMIT] - fHealth
    }

    set_pev(id, pev_health, fHealth + fBoost)
    eCharger[CHARGER_CAPACITY] -= fBoost
    eCharger[CHARGER_NEXT_USE] = fCurrentTime + random_float(eCharger[CHARGER_COOLDOWN][0], eCharger[CHARGER_COOLDOWN][1])
}

stock supplyArmor(eCharger[CHARGER], id, Float:fCurrentTime)
{
    new Float:fArmor, Float:fBoost

    pev(id, pev_armorvalue, fArmor)
    fBoost = random_float(eCharger[CHARGER_RATE][0], eCharger[CHARGER_RATE][1])
    fBoost = floatclamp(fBoost, 0.0, eCharger[CHARGER_CAPACITY])
    if ( eCharger[CHARGER_LIMIT] > 0.0 )
    {
        if ( fArmor >= eCharger[CHARGER_LIMIT] )
            fBoost = 0.0
        else if ( fBoost + fArmor > eCharger[CHARGER_LIMIT] )
            fBoost = eCharger[CHARGER_LIMIT] - fArmor
    }

    set_pev(id, pev_armorvalue, fArmor + fBoost)
    eCharger[CHARGER_CAPACITY] -= fBoost
    eCharger[CHARGER_NEXT_USE] = fCurrentTime + random_float(eCharger[CHARGER_COOLDOWN][0], eCharger[CHARGER_COOLDOWN][1])
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
    if ( eCharger[CHARGER_FLAGS] & FLAG_ACTIVE )
    {
        if ( eCharger[CHARGER_FLAGS] & FLAG_ACTIVE_DELAY )
        {
            chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_OFF)
            eCharger[CHARGER_FLAGS] &= ~FLAG_ACTIVE
            eCharger[CHARGER_NEXT_ENABLE] = get_gametime() + random_float(eCharger[CHARGER_ACTIVE_DELAY][0], eCharger[CHARGER_ACTIVE_DELAY][1])

            if ( bPlaySound )
                chargerSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND] == SOUND_HEALTH ? SOUND_HEALTH_NO : SOUND_HEV_NO, CHAN_ITEM, false)
        }
        else
        {
            chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_IDLE)
            if ( eCharger[CHARGER_FLAGS] & FLAG_ACTIVE_DURATION )
                eCharger[CHARGER_NEXT_DISABLE] = get_gametime() + random_float(eCharger[CHARGER_ACTIVE_DURATION][0], eCharger[CHARGER_ACTIVE_DURATION][1])

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
    set_pev(eCharger[CHARGER_ID], pev_health, random_float(eCharger[CHARGER_HEALTH][0], eCharger[CHARGER_HEALTH][1]))

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
    new Float:fDistance, Float:fRatio, Float:fDamage, Float:fRadius,
        Float:fVec1[3], Float:fVec2[3], iEnt = -1

    fRadius = random_float(eCharger[CHARGER_EXPLODE_RADIUS][0], eCharger[CHARGER_EXPLODE_RADIUS][1])
    xs_vec_copy(eCharger[CHARGER_ORIGIN], fVec1)
    message_begin_f(MSG_PVS, SVC_TEMPENTITY, fVec1)
    write_byte(TE_EXPLOSION)
    write_coord_f(fVec1[0])
    write_coord_f(fVec1[1])
    write_coord_f(fVec1[2])
    write_short(g_eSettings[SETTING_SPRITE_ZEROGXPLODE])
    write_byte(floatround(fRadius / 15.0))
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

    while ( (iEnt = engfunc(EngFunc_FindEntityInSphere, iEnt, eCharger[CHARGER_ORIGIN], fRadius)) )
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
        if ( fDistance > fRadius )
            continue

        fRatio = 1.0 - (fDistance / fRadius)
        fDamage = random_float(eCharger[CHARGER_EXPLODE_DAMAGE][0], eCharger[CHARGER_EXPLODE_DAMAGE][1]) * fRatio

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
            set_pev(eCharger[CHARGER_ID], pev_health, random_float(eCharger[CHARGER_HEALTH][0], eCharger[CHARGER_HEALTH][1]))
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

stock chargerReset(eCharger[CHARGER])
{
    eCharger[CHARGER_NEXT_USE]      = 0.0
    eCharger[CHARGER_NEXT_EMPTY]    = 0.0
    eCharger[CHARGER_NEXT_REFILL]   = 0.0
    eCharger[CHARGER_NEXT_FLICKER]  = 0.0
    eCharger[CHARGER_NEXT_ENABLE]   = 0.0
    eCharger[CHARGER_NEXT_DISABLE]  = 0.0
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

stock parseSetting(iType, szKey[], iKeyLen, szValue[], iValueLen, any:output[], iOutputLen, const any:fallback[] = {0.0, 0.0})
{
    switch ( iType )
    {
        case DTYPE_FLOAT_RANGE:
        {
            strtok(szValue, szKey, iKeyLen, szValue, iValueLen, ' ')
            output[0] = str_to_float(szKey)
            output[1] = str_to_float(szValue)

            if ( output[0] < 0.0 ) output[0] = fallback[0]
            if ( output[1] < 0.0 ) output[1] = fallback[1]
        }
        case DTYPE_FLOAT:
        {
            output[0] = str_to_float(szValue)
            if ( output[0] < 0.0 ) output[0] = fallback[0]
        }
        case DTYPE_INT:
        {
            output[0] = str_to_num(szValue)
            if ( output[0] < 0 ) output[0] = fallback[0]
        }
        case DTYPE_BOOL:
        {
            output[0] = bool:str_to_num(szValue)
        }
        case DTYPE_FLAGS:
        {
            output[0] = read_flags(szValue)
        }
        case DTYPE_VECTOR:
        {
            strtok(szValue, szKey, iKeyLen, szValue, iValueLen, ' ')
            output[0] = str_to_num(szKey)

            strtok(szValue, szKey, iKeyLen, szValue, iValueLen, ' ')
            output[1] = str_to_num(szKey)
            output[2] = str_to_num(szValue)
        }
        case DTYPE_VECTOR_FLOAT:
        {
            strtok(szValue, szKey, iKeyLen, szValue, iValueLen, ' ')
            output[0] = str_to_float(szKey)

            strtok(szValue, szKey, iKeyLen, szValue, iValueLen, ' ')
            output[1] = str_to_float(szKey)
            output[2] = str_to_float(szValue)
        }
        case DTYPE_ARRAY_SOUND:
        {
            ArrayPushString(output[0], szValue)
            if ( !g_bFileWasRead ) precache_sound(szValue)
        }
        case DTYPE_STRING_MODEL:
        {
            copy(output, iOutputLen, szValue)
            if ( !g_bFileWasRead ) precache_model(szValue)
        }
        case DTYPE_STRING_SOUND:
        {
            copy(output, iOutputLen, szValue)
            if ( !g_bFileWasRead ) precache_sound(szValue)
        }
        case DTYPE_STRING_SPRITE:
        {
            if ( !g_bFileWasRead )
                output[0] = precache_model(szValue)
        }
    }
}

stock LogConfigError(const iLine, const szText[], any:...)
{
    new szError[MAX_PLATFORM_PATH_LENGTH]
    vformat(szError, charsmax(szError), szText, 3)

    log_to_file(ERROR_FILE, "^nLine %d: %s", iLine, szError)
}
