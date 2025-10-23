/*
*
*	Charger by RedSMURF
*
*
*	Description:
*   This plugin adds a menu from where you can choose different chargers,
*   each with it's own behavior, it only uses it's own charger models as it doesn't support custom models animations.
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
*
*/

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <fakemeta>
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
#define MENU_BLINK          0.1
#define MATERIAL_COMPUTER   "6"

/**
 *  Charger animation sequences.
 */
#define CHARGER_SEQ_IDLE    0
#define CHARGER_SEQ_OFF     1

/**
 *  Charger Bitflag sounds.
 */
#define CHARGER_SOUND_PLACE     (1 << 0)
#define CHARGER_SOUND_USE       (1 << 1)
#define CHARGER_SOUND_EMPTY     (1 << 2)
#define CHARGER_SOUND_REMOVE    (1 << 3)
#define CHARGER_SOUND_REFILL    (1 << 4)

new const PLUGIN_VERSION[]          = "1.5"
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
    STATE_ACTIVE,
    STATE_INACTIVE,
    STATE_VALID,
    STATE_INVALID
}

enum
{
    FLAG_BREAK   = (1 << 0),
    FLAG_EXPLODE = (1 << 1),
    FLAG_SELECT  = (1 << 2)
}

enum _:MAIN_SETTINGS
{
    SETTING_DEFAULT_MODEL[MAX_RESOURCE_PATH_LENGTH],

    Float:SETTING_MINS_STANDARD[3],
    Float:SETTING_MAXS_STANDARD[3],
    Float:SETTING_MINS_CIVILIAN[3],
    Float:SETTING_MAXS_CIVILIAN[3],
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

    bool:SETTING_CHARGER_LOAD,
    Float:SETTING_CHARGER_RANGE,
    Float:SETTING_OFFSET_BASE,
    Float:SETTING_OFFSET_MIN,
    Float:SETTING_OFFSET_MAX,
    Float:SETTING_OFFSET_STEP,
    Float:SETTING_OFFSET_FREQ,
    Float:SETTING_GHOST_FREQ,
    SETTING_GHOST_ALPHA
}

enum _:CHARGER
{
    CHARGER_ID,
    CHARGER_ITEM,
    CHARGER_STATE,
    CHARGER_NAME[MAX_VALUE_LENGTH],
    CHARGER_MODEL[MAX_RESOURCE_PATH_LENGTH],
    CHARGER_CLASS,
    CHARGER_MODE,
    CHARGER_FLAGS,
    CHARGER_SOUND,
    CHARGER_SOUND_FLAGS,
    CHARGER_OCCUPIED,
    Float:CHARGER_ORIGIN[3],
    Float:CHARGER_ANGLES[3],
    Float:CHARGER_DECAL[3],
    Float:CHARGER_RATE,
    Float:CHARGER_COOLDOWN,
    Float:CHARGER_CAPACITY,
    Float:CHARGER_CAPACITY_MAX,
    Float:CHARGER_LIMIT,
    Float:CHARGER_REFILL,
    Float:CHARGER_DELAY,
    Float:CHARGER_OVERLOAD,
    Float:CHARGER_HEALTH,
    Float:CHARGER_BREAK_RATIO,
    Float:CHARGER_BREAK_THRESHOLD,
    Float:CHARGER_BREAK_CHANCE,
    Float:CHARGER_EXPLODE_DAMAGE,
    Float:CHARGER_EXPLODE_RADIUS,
    Float:CHARGER_NEXT_USE,
    Float:CHARGER_NEXT_REFILL,
    Float:CHARGER_NEXT_OVERLOAD,
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
    CLASS_HEALTH,
    CLASS_HEV,
    CLASS_CIV
}

enum
{
    MODE_HEALTH,
    MODE_ARMOR
}

enum
{
    SOUND_HEALTH,
    SOUND_HEV,
    SOUND_FLICKER
}

enum
{
    EVENT_PLACE,
    EVENT_USE,
    EVENT_EMPTY,
    EVENT_REMOVE,
    EVENT_REFILL
}

enum
{
    MENU_ROOT,
    MENU_CREATE,
    MENU_REMOVE,
    MENU_ROTATE
}

enum
{
    ROOT_CREATE,
    ROOT_REMOVE,
    ROOT_SAVE
}

enum
{
    DEL_NEXT,
    DEL_BACK,
    DEL_REMOVE
}

enum
{
    ROTATE_RIGHT,
    ROTATE_LEFT,
    ROTATE_PLACE
}

enum _:TASK_MENU
{
    TASK_ID,
    TASK_TYPE
}

new g_szMenuHandler[][] =
{
    "menuHandlerRoot",
    "menuHandlerCreate",
    "menuHandlerRemove",
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

public plugin_init()
{
    register_plugin("Charger", PLUGIN_VERSION, "RedSMURF")

    register_clcmd("say /charger",      "cmdMenu", ADMIN_RCON)
    register_clcmd("say_team /charger", "cmdMenu", ADMIN_RCON)
    register_concmd("charger_reload",   "cmdReload", ADMIN_RCON, "-- Reload the configuration file")

    register_dictionary("Charger.txt")

    register_forward(FM_UpdateClientData, "fwdUpdateClientData", 1)
    register_forward(FM_AddToFullPack, "fwdAddToFullPack", 1)
    RegisterHam(Ham_Spawn, "func_breakable", "fwdSpawn", 1)
    RegisterHam(Ham_TakeDamage, "func_breakable", "fwdTakeDamage", 0)
    RegisterHam(Ham_TraceAttack, "func_breakable", "fwdTraceAttack", 1)
    RegisterHam(Ham_Player_PreThink, "player", "fwdPreThink", 0)
    RegisterHam(Ham_Killed, "player", "fwdKilled", 1)

    register_logevent("eventRoundStart", 2, "1=Round_Start")
    register_event("HLTV", "eventHLTV", "a", "1=0", "2=0")
    set_task(g_eSettings[SETTING_GHOST_FREQ], "chargerTask", .flags = "b")

    if ( g_eSettings[SETTING_CHARGER_LOAD] )
        loadData()
}

public plugin_precache()
{
    g_aCharger = ArrayCreate(CHARGER)
    g_aChargerConfig = ArrayCreate(CHARGER)
    g_eSettings[SETTING_SOUND_FLICKER] = ArrayCreate(MAX_VALUE_LENGTH)

    precache_model("models/computergibs.mdl")
    precache_sound("debris/metal1.wav")
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
}

public plugin_cfg()
{
    if ( !g_iCharger )
        return PLUGIN_CONTINUE

    new eCharger[CHARGER]
    for ( new i = 0; i < g_iCharger; i ++ )
    {
        ArrayGetArray(g_aCharger, i, eCharger)
        chargerKill(eCharger[CHARGER_ID])
    }

    return PLUGIN_CONTINUE
}

public cmdMenu(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1)
    || !is_user_alive(id) )
        return PLUGIN_HANDLED

    new iArg[TASK_MENU]
    iArg[TASK_ID]   = id
    iArg[TASK_TYPE] = MENU_ROOT

    set_task(MENU_BLINK, "chargerMenu", .parameter = iArg, .len = sizeof(iArg))
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

    new eChargerOld[CHARGER], eChargerNew[CHARGER],
        iCharger

    iCharger = g_iCharger
    for ( new i = 0; i < iCharger; i ++ )
    {
        ArrayGetArray(g_aCharger, i, eChargerOld)

        chargerCreate(0, eChargerOld[CHARGER_ITEM])
        ArrayGetArray(g_aCharger, g_iCharger - 1, eChargerNew)

        xs_vec_copy(eChargerOld[CHARGER_ORIGIN], eChargerNew[CHARGER_ORIGIN])
        xs_vec_copy(eChargerOld[CHARGER_ANGLES], eChargerNew[CHARGER_ANGLES])
        xs_vec_copy(eChargerOld[CHARGER_DECAL], eChargerNew[CHARGER_DECAL])
        set_pev(eChargerNew[CHARGER_ID], pev_origin, eChargerNew[CHARGER_ORIGIN])
        set_pev(eChargerNew[CHARGER_ID], pev_angles, eChargerNew[CHARGER_ANGLES])
        eChargerNew[CHARGER_STATE] = STATE_ACTIVE

        chargerSetBox(eChargerNew)
        chargerSetAnim(eChargerNew)
        ArraySetArray(g_aCharger, g_iCharger - 1, eChargerNew)
    }

    for ( new i = 0; i < iCharger; i ++ )
        chargerRemove(0)

    return PLUGIN_HANDLED
}

public eventHLTV()
{
    if ( !g_iCharger )
        return PLUGIN_CONTINUE

    new eCharger[CHARGER]
    for ( new i = 0; i < g_iCharger; i ++ )
    {
        ArrayGetArray(g_aCharger, i, eCharger)
        chargerKill(eCharger[CHARGER_ID])
    }

    return PLUGIN_CONTINUE
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
                        eCharger[CHARGER_CLASS]           = CLASS_HEALTH
                        eCharger[CHARGER_MODE]            = MODE_HEALTH
                        eCharger[CHARGER_FLAGS]           = 0
                        eCharger[CHARGER_SOUND]           = SOUND_HEALTH
                        eCharger[CHARGER_SOUND_FLAGS]     = CHARGER_SOUND_PLACE | CHARGER_SOUND_USE | CHARGER_SOUND_EMPTY | CHARGER_SOUND_REMOVE | CHARGER_SOUND_REFILL
                        eCharger[CHARGER_RATE]            = 1.0
                        eCharger[CHARGER_COOLDOWN]        = 0.1
                        eCharger[CHARGER_CAPACITY]        = 100.0
                        eCharger[CHARGER_LIMIT]           = -1.0
                        eCharger[CHARGER_REFILL]          = -1.0
                        eCharger[CHARGER_DELAY]           = 0.0
                        eCharger[CHARGER_HEALTH]          = 250.0
                        eCharger[CHARGER_EXPLODE_DAMAGE]  = 100.0
                        eCharger[CHARGER_EXPLODE_RADIUS]  = 150.0
                        eCharger[CHARGER_BREAK_RATIO]     = 2.5
                        eCharger[CHARGER_BREAK_THRESHOLD] = 70.0
                        eCharger[CHARGER_BREAK_CHANCE]    = 0.4

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
                switch( iSection )
                {
                    case SECTION_NONE:
                    {
                        LogConfigError(iLine, "Data is not in any defined section: %s", szData)
                    }
                    case SECTION_MAIN_SETTINGS:
                    {
                        strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
                        trim(szKey)
                        trim(szValue)

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
                    }
                    case SECTION_CHARGER:
                    {
                        strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
                        trim(szKey)
                        trim(szValue)

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
                        else if ( equali(szKey, "CHARGER_MODE") )
                        {
                            eCharger[CHARGER_MODE] = str_to_num(szValue)
                            eCharger[CHARGER_MODE] = clamp(eCharger[CHARGER_MODE], MODE_HEALTH, MODE_ARMOR)
                        }
                        else if ( equali(szKey, "CHARGER_FLAGS") )
                        {
                            eCharger[CHARGER_FLAGS] = read_flags(szValue)
                            eCharger[CHARGER_FLAGS] &= 3
                        }
                        else if ( equali(szKey, "CHARGER_SOUND") )
                        {
                            eCharger[CHARGER_SOUND] = str_to_num(szValue)
                            eCharger[CHARGER_SOUND] = clamp(eCharger[CHARGER_SOUND], SOUND_HEALTH, SOUND_HEV)
                        }
                        else if ( equali(szKey, "CHARGER_SOUND_FLAGS") )
                        {
                            eCharger[CHARGER_SOUND_FLAGS] = read_flags(szValue)
                            eCharger[CHARGER_SOUND_FLAGS] &= 31
                        }
                        else if ( equali(szKey, "CHARGER_RATE") )
                        {
                            eCharger[CHARGER_RATE] = str_to_float(szValue)
                            if ( eCharger[CHARGER_RATE] < 0.0 ) eCharger[CHARGER_RATE] = 1.0
                        }
                        else if ( equali(szKey, "CHARGER_COOLDOWN") )
                        {
                            eCharger[CHARGER_COOLDOWN] = str_to_float(szValue)
                            if ( eCharger[CHARGER_COOLDOWN] < 0.0 ) eCharger[CHARGER_COOLDOWN] = 0.1
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
                            if ( eCharger[CHARGER_LIMIT] < 0.0 && eCharger[CHARGER_LIMIT] != -1.0 ) eCharger[CHARGER_LIMIT] = -1.0
                        }
                        else if ( equali(szKey, "CHARGER_REFILL") )
                        {
                            eCharger[CHARGER_REFILL] = str_to_float(szValue)
                            if ( eCharger[CHARGER_REFILL] < 0.0 && eCharger[CHARGER_REFILL] != -1.0 ) eCharger[CHARGER_REFILL] = -1.0
                        }
                        else if ( equali(szKey, "CHARGER_DELAY") )
                        {
                            eCharger[CHARGER_DELAY] = str_to_float(szValue)
                            if ( eCharger[CHARGER_DELAY] < 0.0 ) eCharger[CHARGER_DELAY] = 0.0
                        }
                        else if ( equali(szKey, "CHARGER_HEALTH") )
                        {
                            eCharger[CHARGER_HEALTH] = str_to_float(szValue)
                            if ( eCharger[CHARGER_HEALTH] < 0.0 ) eCharger[CHARGER_HEALTH] = 100.0
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

public chargerMenu(iArg[TASK_MENU])
{
    new szTitle[64],
        id, iType, iMenu

    id = iArg[TASK_ID]
    iType = iArg[TASK_TYPE]
    formatex(szTitle,charsmax(szTitle), "%L", id, "CHARGER_MENU_TITLE")
    iMenu = menu_create(szTitle, g_szMenuHandler[iType])

    switch( iType )
    {
        case MENU_ROOT:   menuRoot(id, iMenu)
        case MENU_CREATE: menuCreate(id, iMenu)
        case MENU_REMOVE: menuRemove(id, iMenu)
        case MENU_ROTATE: menuRotate(id, iMenu)
    }

    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL)
    menu_setprop(iMenu, MPROP_NUMBER_COLOR, "\r")

    menu_display(id, iMenu)
    return PLUGIN_HANDLED
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
}

public menuHandlerRoot(id, menu, item)
{
    if ( item == MENU_EXIT )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    new iArg[TASK_MENU]
    iArg[TASK_ID] = id

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
                iArg[TASK_TYPE] = MENU_CREATE
                set_task(MENU_BLINK, "chargerMenu", .parameter = iArg, .len = sizeof(iArg))
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
                iArg[TASK_TYPE] = MENU_REMOVE
                set_task(MENU_BLINK, "chargerMenu", .parameter = iArg, .len = sizeof(iArg))
            }
        }
        case ROOT_SAVE:
        {
            saveData(id)
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
    new iArg[TASK_MENU]

    iArg[TASK_ID] = id
    iArg[TASK_TYPE] = MENU_ROTATE
    set_task(MENU_BLINK, "chargerMenu", .parameter = iArg, .len = sizeof(iArg))

    chargerCreate(id, item)
    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuRemove(id, iMenu)
{
    new szItem[64],
        eCharger[CHARGER]

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_DEL_NEXT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_DEL_BACK")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_DEL_REMOVE")
    menu_additem(iMenu, szItem)

    g_ePlayerData[id][PDATA_CHARGER_ACTION] = true

    ArrayGetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)
    eCharger[CHARGER_FLAGS] |= FLAG_SELECT
    ArraySetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)
}

public menuHandlerRemove(id, menu, item)
{
    new iArg[TASK_MENU],
        eCharger[CHARGER]

    iArg[TASK_ID] = id

    ArrayGetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)
    eCharger[CHARGER_FLAGS] &= ~FLAG_SELECT
    ArraySetArray(g_aCharger, g_ePlayerData[id][PDATA_CHARGER_MENU], eCharger)

    switch( item )
    {
        case DEL_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_CHARGER_MENU] >= g_iCharger - 1 )
                g_ePlayerData[id][PDATA_CHARGER_MENU] = 0
            else
                g_ePlayerData[id][PDATA_CHARGER_MENU] ++

            iArg[TASK_TYPE] = MENU_REMOVE
            set_task(MENU_BLINK, "chargerMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case DEL_BACK:
        {
            if ( g_ePlayerData[id][PDATA_CHARGER_MENU] <= 0 )
                g_ePlayerData[id][PDATA_CHARGER_MENU] = g_iCharger - 1
            else
                g_ePlayerData[id][PDATA_CHARGER_MENU] --

            iArg[TASK_TYPE] = MENU_REMOVE
            set_task(MENU_BLINK, "chargerMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case DEL_REMOVE:
        {
            chargerKill(eCharger[CHARGER_ID])
            chargerRemove(g_ePlayerData[id][PDATA_CHARGER_MENU])
            g_ePlayerData[id][PDATA_CHARGER_MENU] = 0
            g_ePlayerData[id][PDATA_CHARGER_ACTION] = false

            if ( g_iCharger > 0 )
            {
                iArg[TASK_TYPE] = MENU_ROOT
                set_task(MENU_BLINK, "chargerMenu", .parameter = iArg, .len = sizeof(iArg))
            }

            if ( eCharger[CHARGER_SOUND_FLAGS] & CHARGER_SOUND_REMOVE )
                chargerSetSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND], EVENT_REMOVE, 0)
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
    new eCharger[CHARGER], iItem,
        iArg[TASK_MENU]

    iItem = chargerFind(g_ePlayerData[id][PDATA_CHARGER_GHOST], eCharger)
    iArg[TASK_ID] = id

    switch( item )
    {
        case ROTATE_RIGHT:
        {
            g_ePlayerData[id][PDATA_ROLL_OFFSET] -= 22.5
            if ( g_ePlayerData[id][PDATA_ROLL_OFFSET] < 180.0 ) g_ePlayerData[id][PDATA_ROLL_OFFSET] += 360.0

            iArg[TASK_TYPE] = MENU_ROTATE
            set_task(MENU_BLINK, "chargerMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case ROTATE_LEFT:
        {
            g_ePlayerData[id][PDATA_ROLL_OFFSET] += 22.5
            if ( g_ePlayerData[id][PDATA_ROLL_OFFSET] > 180.0 ) g_ePlayerData[id][PDATA_ROLL_OFFSET] -= 360.0

            iArg[TASK_TYPE] = MENU_ROTATE
            set_task(MENU_BLINK, "chargerMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case ROTATE_PLACE:
        {
            if ( chargerTrace(eCharger, id) && iItem != -1 )
            {
                g_ePlayerData[id][PDATA_CHARGER_GHOST] = 0
                g_ePlayerData[id][PDATA_CHARGER_ACTION] = false

                pev(eCharger[CHARGER_ID], pev_origin, eCharger[CHARGER_ORIGIN])
                pev(eCharger[CHARGER_ID], pev_angles, eCharger[CHARGER_ANGLES])
                eCharger[CHARGER_NEXT_USE] = get_gametime() + 0.25
                eCharger[CHARGER_STATE] = STATE_ACTIVE

                chargerSetBox(eCharger)
                chargerSetAnim(eCharger)
                ArraySetArray(g_aCharger, iItem, eCharger)

                iArg[TASK_TYPE] = MENU_ROOT
                set_task(MENU_BLINK, "chargerMenu", .parameter = iArg, .len = sizeof(iArg))
            }
            else
            {
                iArg[TASK_TYPE] = MENU_ROTATE
                set_task(MENU_BLINK, "chargerMenu", .parameter = iArg, .len = sizeof(iArg))
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
        eCharger[CHARGER], iItem, iEnt

    get_players(iPlayers, iNum, "ch")

    for ( new i = 0; i < iNum; i ++ )
    {
        id = iPlayers[i]

        if ( is_user_alive(id) )
        {
            iEnt = g_ePlayerData[id][PDATA_CHARGER_GHOST]
            if ( !iEnt || (iItem = chargerFind(iEnt, eCharger)) == -1 )
                continue

            if ( chargerTrace(eCharger, id) ) eCharger[CHARGER_STATE] = STATE_VALID
            else                              eCharger[CHARGER_STATE] = STATE_INVALID

            ArraySetArray(g_aCharger, iItem, eCharger)
        }
        else if ( g_ePlayerData[id][PDATA_CHARGER_USE]
        && chargerFind(g_ePlayerData[id][PDATA_CHARGER_USE], eCharger) != -1 )
        {
            chargerSetSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND], EVENT_USE, SND_STOP)
            g_ePlayerData[id][PDATA_CHARGER_USE] = 0
        }
    }

    for ( new i = 0; i < g_iCharger; i ++ )
    {
        ArrayGetArray(g_aCharger, i, eCharger)

        if ( eCharger[CHARGER_STATE] != STATE_ACTIVE )
            continue

        if ( eCharger[CHARGER_NEXT_REFILL]
        && get_gametime() >= eCharger[CHARGER_NEXT_REFILL] )
        {
            chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_IDLE)
            eCharger[CHARGER_CAPACITY] = eCharger[CHARGER_CAPACITY_MAX]
            eCharger[CHARGER_NEXT_REFILL] = 0.0
            eCharger[CHARGER_NEXT_USE] = get_gametime() + 0.1

            if ( eCharger[CHARGER_NEXT_FLICKER] )
                eCharger[CHARGER_NEXT_FLICKER] = get_gametime() + random_float(4.0, 8.0)

            if ( eCharger[CHARGER_SOUND_FLAGS] & CHARGER_SOUND_REFILL )
                chargerSetSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND], EVENT_REFILL, 0)
        }
        else if ( eCharger[CHARGER_OCCUPIED]
        && get_gametime() >= eCharger[CHARGER_NEXT_USE] + 0.1 )
        {
            eCharger[CHARGER_OCCUPIED] = 0
            eCharger[CHARGER_NEXT_USE] = 0.0
        }
        else if ( eCharger[CHARGER_NEXT_FLICKER]
        && get_gametime() >= eCharger[CHARGER_NEXT_FLICKER]
        && eCharger[CHARGER_CAPACITY] )
        {
            chargerFlicker(eCharger[CHARGER_ID])
            eCharger[CHARGER_NEXT_FLICKER] = get_gametime() + random_float(4.0, 8.0)
        }

        ArraySetArray(g_aCharger, i, eCharger)
    }
}

stock chargerDummy(eCharger[CHARGER], iItem, bool:bStopSound = false)
{
    new iEnt
    iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))

    if ( !pev_valid(iEnt) )
        return

    if ( bStopSound )
    {
        chargerSetSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND], EVENT_USE, SND_STOP)
        g_ePlayerData[eCharger[CHARGER_OCCUPIED]][PDATA_CHARGER_USE] = 0
    }
    else
    {
        g_ePlayerData[eCharger[CHARGER_OCCUPIED]][PDATA_CHARGER_USE] = iEnt
    }

    set_pev(iEnt, pev_classname, g_szCN[eCharger[CHARGER_CLASS]])
    set_pev(iEnt, pev_origin, eCharger[CHARGER_ORIGIN])
    set_pev(iEnt, pev_angles, eCharger[CHARGER_ANGLES])

    set_pev(iEnt, pev_solid, SOLID_NOT)
    set_pev(iEnt, pev_movetype, MOVETYPE_FLY)
    set_pev(iEnt, pev_takedamage, DAMAGE_NO)
    engfunc(EngFunc_SetModel, iEnt, eCharger[CHARGER_MODEL])

    eCharger[CHARGER_ID] = iEnt
    ArraySetArray(g_aCharger, iItem, eCharger)

    dllfunc(DLLFunc_Spawn, iEnt)
}

public chargerCreate(id, iItem)
{
    new iEnt
    iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "func_breakable"))

    if ( !pev_valid(iEnt) )
        return

    new eCharger[CHARGER]
    ArrayGetArray(g_aChargerConfig, iItem, eCharger)

    DispatchKeyValue(iEnt, "material", MATERIAL_COMPUTER)
    eCharger[CHARGER_ID] = iEnt
    eCharger[CHARGER_ITEM] = iItem
    if ( id )
    {
        g_ePlayerData[id][PDATA_CHARGER_GHOST] = eCharger[CHARGER_ID]
        g_ePlayerData[id][PDATA_CHARGER_ACTION] = true
        g_ePlayerData[id][PDATA_OFFSET] = g_eSettings[SETTING_OFFSET_BASE]
        g_ePlayerData[id][PDATA_ROLL_OFFSET] = 0.0
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

        formatex(szData, charsmax(szData), "decal origin = %.2f %.2f %.2f^n^n",
        eCharger[CHARGER_DECAL][0], eCharger[CHARGER_DECAL][1], eCharger[CHARGER_DECAL][2])
        fputs(iFile, szData)
    }

    client_print_color(id, id, "%L %L", id, "CHARGER_CHAT_TAG", id, "CHARGER_CHAT_SAVED")
    fclose(iFile)

    return PLUGIN_HANDLED
}

public loadData()
{
    new szFile[64], iFile,
        szData[64], szKey[32], szValue[32],
        Float:fOrigin[3], Float:fAngles[3], Float:fDecal[3], iItem,
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
                xs_vec_copy(fDecal, eCharger[CHARGER_DECAL])
                set_pev(eCharger[CHARGER_ID], pev_origin, fOrigin)
                set_pev(eCharger[CHARGER_ID], pev_angles, fAngles)
                eCharger[CHARGER_STATE] = STATE_ACTIVE

                chargerSetBox(eCharger)
                chargerSetAnim(eCharger, false)
                ArraySetArray(g_aCharger, iCount, eCharger)
            }

            iCount ++
        }
        else
        {
            strtok(szData, szKey, charsmax( szKey ), szValue, charsmax( szValue ), '=')
            trim(szKey)
            trim(szValue)

            switch( szKey[0] )
            {
                case 'i':
                {
                    iItem = str_to_num(szValue)
                }
                case 'o':
                {
                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fOrigin[0] = str_to_float(szKey)

                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fOrigin[1] = str_to_float(szKey)
                    fOrigin[2] = str_to_float(szValue)
                }
                case 'a':
                {
                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fAngles[0] = str_to_float(szKey)

                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fAngles[1] = str_to_float(szKey)
                    fAngles[2] = str_to_float(szValue)
                }
                case 'd':
                {
                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fDecal[0] = str_to_float(szKey)

                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fDecal[1] = str_to_float(szKey)
                    fDecal[2] = str_to_float(szValue)
                }
            }
        }
    }

    if ( iCount != -1 )
    {
        chargerCreate(0, iItem)
        ArrayGetArray(g_aCharger, iCount, eCharger)

        xs_vec_copy(fOrigin, eCharger[CHARGER_ORIGIN])
        xs_vec_copy(fAngles, eCharger[CHARGER_ANGLES])
        xs_vec_copy(fDecal, eCharger[CHARGER_DECAL])
        set_pev(eCharger[CHARGER_ID], pev_origin, fOrigin)
        set_pev(eCharger[CHARGER_ID], pev_angles, fAngles)
        eCharger[CHARGER_STATE] = STATE_ACTIVE

        chargerSetBox(eCharger)
        chargerSetAnim(eCharger, false)
        ArraySetArray(g_aCharger, iCount, eCharger)
    }

    fclose(iFile)
    return PLUGIN_HANDLED
}

public fwdSpawn(iEnt)
{
    if ( !isCharger(iEnt) )
        return HAM_IGNORED

    set_pev(iEnt, pev_solid, SOLID_NOT)
    set_pev(iEnt, pev_movetype, MOVETYPE_FLY)
    set_pev(iEnt, pev_takedamage, DAMAGE_NO)

    return HAM_IGNORED
}

public fwdTakeDamage(iEnt, iInflictor, iAttacker, Float:fDamage, iDamageBits)
{
    if ( !isCharger(iEnt) )
        return HAM_IGNORED

    new eCharger[CHARGER], iItem,
        Float:fHealth

    iItem = chargerFind(iEnt, eCharger)
    pev(iEnt, pev_health, fHealth)

    if ( !(eCharger[CHARGER_FLAGS] & FLAG_BREAK) )
    {
        SetHamParamFloat(4, 0.0)
    }
    else if ( fDamage >= fHealth
    && iItem != -1
    && eCharger[CHARGER_STATE] == STATE_ACTIVE )
    {
        eCharger[CHARGER_STATE] = STATE_INACTIVE
        chargerKill(eCharger[CHARGER_ID])
        chargerDummy(eCharger, iItem, true)

        if ( eCharger[CHARGER_FLAGS] & FLAG_EXPLODE )
            chargerExplode(eCharger)
    }

    return HAM_IGNORED
}

public fwdTraceAttack(iEnt, iAttacker, Float:fDamage, Float:fDirection[3], iTr, iDamageBits)
{
    if ( !isCharger(iEnt) )
        return HAM_IGNORED

    new Float:fEnd[3]
    get_tr2(iTr, TR_vecEndPos, fEnd)

    chargerEmitParticles(fEnd)
    chargerEmitSparks(fEnd)

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

    new eCharger[CHARGER]
    chargerFind(iEnt, eCharger)

    if ( eCharger[CHARGER_STATE] == STATE_ACTIVE )
    {
        if ( g_ePlayerData[iHost][PDATA_CHARGER_ACTION]
        && eCharger[CHARGER_FLAGS] & FLAG_SELECT )
        {
            set_es(es, ES_RenderMode, kRenderTransAlpha)
            set_es(es, ES_RenderAmt, 32)
            set_es(es, ES_RenderColor, {255, 0, 0})
            set_es(es, ES_RenderFx, kRenderFxGlowShell)
        }
    }
    else
    {
        if ( !g_ePlayerData[iHost][PDATA_CHARGER_ACTION] )
        {
            set_es(es, ES_Effects, EF_NODRAW)
        }
        else
        {
            if ( eCharger[CHARGER_FLAGS] & FLAG_SELECT )
            {
                set_es(es, ES_RenderMode, kRenderTransAlpha)
                set_es(es, ES_RenderAmt, 32)
                set_es(es, ES_RenderColor, {255, 0, 0})
                set_es(es, ES_RenderFx, kRenderFxGlowShell)
            }
            else if ( eCharger[CHARGER_STATE] != STATE_VALID )
            {
                set_es(es, ES_RenderMode, kRenderTransAlpha)
                set_es(es, ES_RenderAmt, g_eSettings[SETTING_GHOST_ALPHA])
            }
        }
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
        && eCharger[CHARGER_STATE] == STATE_ACTIVE
        && ( !g_ePlayerData[id][PDATA_CHARGER_USE] || g_ePlayerData[id][PDATA_CHARGER_USE] == eCharger[CHARGER_ID] ) )
        {
            if ( get_gametime() >= eCharger[CHARGER_NEXT_USE]
            && (!eCharger[CHARGER_OCCUPIED] || eCharger[CHARGER_OCCUPIED] == id) )
                chargerSupply(id, eCharger, iItem)

            iButton &= ~IN_USE
            set_pev(id, pev_button, iButton)
        }
        else if ( g_ePlayerData[id][PDATA_CHARGER_USE]
        && chargerFind(g_ePlayerData[id][PDATA_CHARGER_USE], eCharger) != -1 )
        {
            chargerSetSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND], EVENT_USE, SND_STOP)
            g_ePlayerData[id][PDATA_CHARGER_USE] = 0
        }
    }

    return HAM_IGNORED
}

public bool:chargerTrace(eCharger[CHARGER], id)
{
    new Float:fOrigin[3], Float:fAngles[3],
        Float:fVec1[3], Float:fVec2[3],
        Float:fFraction

    pev(id, pev_origin, fOrigin)
    pev(id, pev_view_ofs, fVec1)
    xs_vec_add(fOrigin, fVec1, fOrigin)

    pev(id, pev_v_angle, fVec1)
    engfunc(EngFunc_MakeVectors, fVec1)
    global_get(glb_v_forward, fVec1)

    xs_vec_mul_scalar(fVec1, g_ePlayerData[id][PDATA_OFFSET], fVec2)
    xs_vec_add(fVec2, fOrigin, fVec2)

    engfunc(EngFunc_TraceLine, fOrigin, fVec2, DONT_IGNORE_MONSTERS, id, 0)
    get_tr2(0, TR_vecEndPos, fOrigin)
    get_tr2(0, TR_flFraction, fFraction)

    if ( fFraction < 1.0 )
    {
        get_tr2(0, TR_vecPlaneNormal, fVec1)

        xs_vec_copy(fOrigin, eCharger[CHARGER_DECAL])
        xs_vec_mul_scalar(fVec1, 4.0, fVec2)
        xs_vec_add(fOrigin, fVec2, fOrigin)
    }
    else
    {
        xs_vec_mul_scalar(fVec1, -1.0, fVec1)
        g_ePlayerData[id][PDATA_ROLL_OFFSET] = 0.0
    }

    engfunc(EngFunc_VecToAngles, fVec1, fVec2)
    fAngles[0] = fVec2[0]
    fAngles[1] = fVec2[1]
    fAngles[2] = g_ePlayerData[id][PDATA_ROLL_OFFSET]

    set_pev(g_ePlayerData[id][PDATA_CHARGER_GHOST], pev_origin, fOrigin)
    set_pev(g_ePlayerData[id][PDATA_CHARGER_GHOST], pev_angles, fAngles)

    return fFraction < 1.0 && chargerRadius(fOrigin, g_ePlayerData[id][PDATA_CHARGER_GHOST])
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
    if ( eCharger[CHARGER_CAPACITY] > 0.0 )
    {
        if ( !g_ePlayerData[id][PDATA_CHARGER_USE] )
        {
            g_ePlayerData[id][PDATA_CHARGER_USE] = eCharger[CHARGER_ID]

            if ( !eCharger[CHARGER_OCCUPIED] )
                eCharger[CHARGER_OCCUPIED] = id

            if ( eCharger[CHARGER_FLAGS] & FLAG_BREAK
            && get_gametime() >= eCharger[CHARGER_NEXT_OVERLOAD] )
            {
                if ( eCharger[CHARGER_OVERLOAD] >= eCharger[CHARGER_BREAK_THRESHOLD] )
                {
                    if ( eCharger[CHARGER_BREAK_CHANCE] >= random_float(0.0, 1.0) )
                    {
                        eCharger[CHARGER_STATE] = STATE_INACTIVE
                        chargerKill(eCharger[CHARGER_ID])
                        chargerDummy(eCharger, iItem)

                        if ( eCharger[CHARGER_FLAGS] & FLAG_EXPLODE )
                            chargerExplode(eCharger)
                    }
                }

                eCharger[CHARGER_OVERLOAD] += eCharger[CHARGER_BREAK_RATIO]
                if ( eCharger[CHARGER_COOLDOWN] < 2.0 )
                    eCharger[CHARGER_NEXT_OVERLOAD] = get_gametime() + (2.0 - eCharger[CHARGER_COOLDOWN])

                if ( !eCharger[CHARGER_NEXT_FLICKER]
                && eCharger[CHARGER_OVERLOAD] >= eCharger[CHARGER_BREAK_THRESHOLD] )
                    eCharger[CHARGER_NEXT_FLICKER] = get_gametime() + random_float(4.0, 8.0)
            }

            if ( eCharger[CHARGER_SOUND_FLAGS] & CHARGER_SOUND_USE )
                    chargerSetSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND], EVENT_USE, 0)
        }

        switch( eCharger[CHARGER_MODE] )
        {
            case MODE_HEALTH: supplyHealth(id, eCharger)
            case MODE_ARMOR:  supplyArmor(id, eCharger)
        }

        if ( !eCharger[CHARGER_CAPACITY] )
        {
            chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_OFF)
            chargerSetSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND], EVENT_EMPTY, 0)
            eCharger[CHARGER_NEXT_USE] = get_gametime() + 1.0
            g_ePlayerData[id][PDATA_CHARGER_USE] = 0

            if ( eCharger[CHARGER_REFILL] != -1 )
                eCharger[CHARGER_NEXT_REFILL] = get_gametime() + eCharger[CHARGER_REFILL]
        }

        ArraySetArray(g_aCharger, iItem, eCharger)
    }
    else if ( get_gametime() > eCharger[CHARGER_NEXT_USE]
    && eCharger[CHARGER_SOUND_FLAGS] & CHARGER_SOUND_EMPTY )
    {
        eCharger[CHARGER_NEXT_USE] = get_gametime() + 1.0
        chargerSetSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND], EVENT_EMPTY, 0)

        ArraySetArray(g_aCharger, iItem, eCharger)
    }
}

supplyHealth(id, eCharger[CHARGER])
{
    new Float:fHealth,
        Float:fBoost

    pev(id, pev_health, fHealth)
    fBoost = floatclamp(eCharger[CHARGER_RATE], 0.0, eCharger[CHARGER_CAPACITY])
    if ( eCharger[CHARGER_LIMIT] != -1 )
    {
        if ( fHealth >= eCharger[CHARGER_LIMIT] )
            fBoost = 0.0
        else if ( fBoost + fHealth > eCharger[CHARGER_LIMIT] )
            fBoost = eCharger[CHARGER_LIMIT] - fHealth
    }
    fHealth += fBoost

    set_pev(id, pev_health, fHealth)
    eCharger[CHARGER_CAPACITY] -= fBoost
    eCharger[CHARGER_NEXT_USE] = get_gametime() + eCharger[CHARGER_COOLDOWN]
}

supplyArmor(id, eCharger[CHARGER])
{
    new Float:fArmor,
        Float:fBoost

    pev(id, pev_armorvalue, fArmor)
    fBoost = floatclamp(eCharger[CHARGER_RATE], 0.0, eCharger[CHARGER_CAPACITY])
    if ( eCharger[CHARGER_LIMIT] != -1 )
    {
        if ( fArmor >= eCharger[CHARGER_LIMIT] )
            fBoost = 0.0
        else if ( fBoost + fArmor > eCharger[CHARGER_LIMIT] )
            fBoost = eCharger[CHARGER_LIMIT] - fArmor
    }
    fArmor += fBoost

    set_pev(id, pev_armorvalue, fArmor)
    eCharger[CHARGER_CAPACITY] -= fBoost
    eCharger[CHARGER_NEXT_USE] = get_gametime() + eCharger[CHARGER_COOLDOWN]
}

stock chargerSetBox(eCharger[CHARGER])
{
    new Float:fMins[3], Float:fMaxs[3],
        Float:fForward[3], Float:fRight[3], Float:fUp[3],
        Float:fCorners[8][3]

    set_pev(eCharger[CHARGER_ID], pev_solid, SOLID_BBOX)
    set_pev(eCharger[CHARGER_ID], pev_movetype, MOVETYPE_FLY)
    set_pev(eCharger[CHARGER_ID], pev_takedamage, DAMAGE_AIM)
    set_pev(eCharger[CHARGER_ID], pev_health, eCharger[CHARGER_HEALTH])
    engfunc(EngFunc_AngleVectors, eCharger[CHARGER_ANGLES], fForward, fRight, fUp)

    switch ( eCharger[CHARGER_CLASS] )
    {
        case CLASS_HEALTH, CLASS_HEV: { xs_vec_copy(g_eSettings[SETTING_MINS_STANDARD], fMins); xs_vec_copy(g_eSettings[SETTING_MAXS_STANDARD], fMaxs); }
        case CLASS_CIV              : { xs_vec_copy(g_eSettings[SETTING_MINS_CIVILIAN], fMins); xs_vec_copy(g_eSettings[SETTING_MAXS_CIVILIAN], fMaxs); }
    }

    for ( new i = 0; i < 8; i ++ )
    {
        fCorners[i][0] = (i & 1) ? fMins[0] : fMaxs[0]
        fCorners[i][1] = (i & 2) ? fMins[1] : fMaxs[1]
        fCorners[i][2] = (i & 4) ? fMins[2] : fMaxs[2]

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

    engfunc(EngFunc_SetSize, eCharger[CHARGER_ID], fMins, fMaxs)
    set_rendering(eCharger[CHARGER_ID], kRenderFxNone, 255, 255, 255, kRenderNormal, 255)
}

stock boxRotate(Float:fLocal[3], Float:fForward[3], Float:fRight[3], Float:fUp[3])
{
    new Float:fOut[3]
    fOut[0] = fLocal[0] * fForward[0] + fLocal[1] * fRight[0] + fLocal[2] * fUp[0]
    fOut[1] = fLocal[0] * fForward[1] + fLocal[1] * fRight[1] + fLocal[2] * fUp[1]
    fOut[2] = fLocal[0] * fForward[2] + fLocal[1] * fRight[2] + fLocal[2] * fUp[2]

    xs_vec_copy(fOut, fLocal)
}

stock chargerSetAnim(eCharger[CHARGER], bool:bPlaySound = true)
{
    if ( eCharger[CHARGER_CAPACITY] > 0.0 )
    {
        if ( eCharger[CHARGER_DELAY] > 0.0 )
        {
            chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_OFF)
            eCharger[CHARGER_CAPACITY] = 0.0
            eCharger[CHARGER_NEXT_REFILL] = get_gametime() + eCharger[CHARGER_DELAY]

            if ( bPlaySound && (eCharger[CHARGER_SOUND_FLAGS] & CHARGER_SOUND_EMPTY) )
                chargerSetSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND], EVENT_EMPTY, 0)
        }
        else
        {
            chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_IDLE)

            if ( bPlaySound && (eCharger[CHARGER_SOUND_FLAGS] & CHARGER_SOUND_PLACE) )
                chargerSetSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND], EVENT_PLACE, 0)
        }
    }
    else
    {
        chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_OFF)

        if ( bPlaySound && (eCharger[CHARGER_SOUND_FLAGS] & CHARGER_SOUND_EMPTY) )
            chargerSetSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND], EVENT_EMPTY, 0)
    }
}

stock chargerSetSeq(iEnt, iSequence)
{
    set_pev(iEnt, pev_sequence, iSequence)
    set_pev(iEnt, pev_frame, 0.0)
    set_pev(iEnt, pev_framerate, 1.0)
    set_pev(iEnt, pev_animtime, get_gametime())
}

stock chargerSetSound(iEnt, iSound, iEvent, iFlags)
{
    new szSample[64],
        iChan

    switch( iSound )
    {
        case SOUND_HEALTH:
        {
            switch( iEvent )
            {
                case EVENT_PLACE:  copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_HEALTH_PLACE])
                case EVENT_USE:    copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_HEALTH_USE])
                case EVENT_EMPTY:  copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_HEALTH_EMPTY])
                case EVENT_REMOVE: copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_HEALTH_REMOVE])
                case EVENT_REFILL: copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_HEALTH_REFILL])
            }

            iChan = CHAN_ITEM
        }
        case SOUND_HEV:
        {
            switch( iEvent )
            {
                case EVENT_PLACE:  copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_HEV_PLACE])
                case EVENT_USE:    copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_HEV_USE])
                case EVENT_EMPTY:  copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_HEV_EMPTY])
                case EVENT_REMOVE: copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_HEV_REMOVE])
                case EVENT_REFILL: copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_HEV_REFILL])
            }

            iChan = CHAN_ITEM
        }
        case SOUND_FLICKER:
        {
            ArrayGetString(g_eSettings[SETTING_SOUND_FLICKER], random(ArraySize(g_eSettings[SETTING_SOUND_FLICKER]) - 1), szSample, charsmax(szSample))
            iChan = CHAN_VOICE
        }
    }

    engfunc(EngFunc_EmitSound, iEnt, iChan, szSample, VOL_NORM, ATTN_NORM, iFlags, PITCH_NORM)
}

stock chargerRadius(Float:fOrigin[3], iSkip)
{
    new iEnt = -1

    while ( (iEnt = engfunc(EngFunc_FindEntityInSphere, iEnt, fOrigin, 10.0)) )
    {
        if ( pev_valid(iEnt)
        && iEnt != iSkip
        && (isCharger(iEnt) || pev(iEnt, pev_solid) >= SOLID_BBOX) )
            return false
    }

    return true
}

stock chargerEmitParticles(Float:fOrigin[3])
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

stock chargerEmitSparks(Float:fOrigin[3])
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

    chargerEmitSparks(fOrigin)
    chargerSetSound(iEnt, SOUND_FLICKER, 0, 0)
}

stock chargerExplode(eCharger[CHARGER])
{
    new Float:fOrigin[3]
    xs_vec_copy(eCharger[CHARGER_ORIGIN], fOrigin)

    explodeFireBall(eCharger, fOrigin)
    explodeDamage(eCharger, fOrigin)
}

stock explodeFireBall(eCharger[CHARGER], Float:fOrigin[3])
{
    new iExplosion
    iExplosion = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_explosion"))

    if ( !pev_valid(iExplosion) )
        return;

    new iSpawnFlags,
        szRadius[16], Float:fRadius

    iSpawnFlags = SF_ENVEXPLOSION_NODAMAGE | SF_ENVEXPLOSION_NODECAL
    fRadius = eCharger[CHARGER_EXPLODE_RADIUS] / 2.5
    fRadius = floatclamp(fRadius, 10.0, 150.0)
    formatex(szRadius, charsmax(szRadius), "%.2f", fRadius)
    DispatchKeyValue(iExplosion, "iMagnitude", szRadius)

    set_pev(iExplosion, pev_origin, fOrigin)
    set_pev(iExplosion, pev_spawnflags, iSpawnFlags)
    xs_vec_copy(eCharger[CHARGER_DECAL], fOrigin)

    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_WORLDDECAL)
    write_coord_f(fOrigin[0])
    write_coord_f(fOrigin[1])
    write_coord_f(fOrigin[2])
    write_byte(random_num(46, 48))
    message_end()

    dllfunc(DLLFunc_Spawn, iExplosion)
    dllfunc(DLLFunc_Use, iExplosion, iExplosion)
}

stock explodeDamage(eCharger[CHARGER], Float:fOrigin[3])
{
    new Float:fDistance, Float:fRatio, Float:fDamage,
        Float:fVec1[3], Float:fVec2[3], iEnt = -1

    while ( (iEnt = engfunc(EngFunc_FindEntityInSphere, iEnt, fOrigin, eCharger[CHARGER_EXPLODE_RADIUS])) )
    {
        if ( !pev_valid(iEnt)
        || pev(iEnt, pev_takedamage) == DAMAGE_NO
        || iEnt == eCharger[CHARGER_ID] )
            continue

        pev(iEnt, pev_absmin, fVec1)
        pev(iEnt, pev_absmax, fVec2)
        xs_vec_add(fVec1, fVec2, fVec1)
        xs_vec_mul_scalar(fVec1, 0.5, fVec1)

        fDistance = xs_vec_distance(fOrigin, fVec1)
        if ( fDistance > eCharger[CHARGER_EXPLODE_RADIUS] )
            continue

        fRatio = 1.0 - fDistance / eCharger[CHARGER_EXPLODE_RADIUS]
        fDamage = eCharger[CHARGER_EXPLODE_DAMAGE] * fRatio

        ExecuteHam(Ham_TakeDamage, iEnt, eCharger[CHARGER_ID], eCharger[CHARGER_ID], fDamage, DMG_GRENADE)
    }
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