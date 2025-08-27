/*
*
*	Charger by RedSMURF
*
*
*	Description:
*		Charger for general purposes.
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
*       v1.2: Manual rotation (No floor placement), Improved readability.
*       v1.3: Refills after a certain duration, Used by a single player at a time, All charger sounds are emitted from charger entities.
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

#define MAX_ENT             30
#define MENU_BLINK          0.1

/**
 *  Charger animation sequences.
 */
#define CHARGER_SEQ_IDLE    0
#define CHARGER_SEQ_OFF     1

/**
 *  Charger Bitflag sounds.
 */
#define CHARGER_SOUND_PLACED    (1 << 0)
#define CHARGER_SOUND_USING     (1 << 1)
#define CHARGER_SOUND_EMPTY     (1 << 2)

new const PLUGIN_VERSION[]          = "1.3"
new const Float:DELAY_ON_CONNECT    = 1.0
new const ERROR_FILE[]              = "Charger_ERRORS.log"

enum
{
    SECTION_NONE,
    SECTION_MAIN_SETTINGS,
    SECTION_CHARGER
}

enum _:MAIN_SETTINGS
{
    SETTING_DEFAULT_MODEL[MAX_RESOURCE_PATH_LENGTH],
    Float:SETTING_DEFAULT_RATE,
    Float:SETTING_DEFAULT_COOLDOWN,
    Float:SETTING_DEFAULT_CAPACITY,
    Float:SETTING_DEFAULT_LIMIT,

    Float:SETTING_MINS_STANDARD[3],
    Float:SETTING_MAXS_STANDARD[3],
    Float:SETTING_MINS_CIVILIAN[3],
    Float:SETTING_MAXS_CIVILIAN[3],
    SETTING_HEALTH_PLACED[MAX_RESOURCE_PATH_LENGTH],
    SETTING_HEALTH_USING[MAX_RESOURCE_PATH_LENGTH],
    SETTING_HEALTH_EMPTY[MAX_RESOURCE_PATH_LENGTH],
    SETTING_HEV_PLACED[MAX_RESOURCE_PATH_LENGTH],
    SETTING_HEV_USING[MAX_RESOURCE_PATH_LENGTH],
    SETTING_HEV_EMPTY[MAX_RESOURCE_PATH_LENGTH],

    bool:SETTING_CHARGER_LOAD,
    Float:SETTING_CHARGER_RANGE,
    Float:SETTING_OFFSET_BASE,
    Float:SETTING_OFFSET_MIN,
    Float:SETTING_OFFSET_MAX,
    Float:SETTING_OFFSET_STEP,
    Float:SETTING_OFFSET_FREQ,
    SETTING_GHOST_ALPHA,
    Float:SETTING_GHOST_FREQ
}

enum _:CHARGER
{
    CHARGER_ID,
    CHARGER_ITEM,
    CHARGER_NAME[MAX_VALUE_LENGTH],
    CHARGER_MODEL[MAX_RESOURCE_PATH_LENGTH],
    CHARGER_CLASS,
    CHARGER_MODE,
    CHARGER_SOUND,
    CHARGER_SOUND_FLAGS,
    CHARGER_OCCUPIED,
    Float:CHARGER_ORIGIN[3],
    Float:CHARGER_ANGLES[3],
    Float:CHARGER_RATE,
    Float:CHARGER_COOLDOWN,
    Float:CHARGER_CAPACITY,
    Float:CHARGER_LIMIT,
    Float:CHARGER_REFILL,
    Float:CHARGER_NEXT_USE,
    Float:CHARGER_NEXT_SOUND,
    Float:CHARGER_NEXT_STOP,
    Float:CHARGER_NEXT_REFILL
}

enum _:PLAYER_DATA
{
    PDATA_NAME[MAX_VALUE_LENGTH],
    PDATA_AUTHID[MAX_AUTHID_LENGTH],
    PDATA_ADMIN_FLAGS,
    PDATA_CHARGER_GHOST,
    PDATA_CHARGER_MENU,
    Float:PDATA_OFFSET,
    Float:PDATA_NEXT_OFFSET
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
    SOUND_HEV
}

enum
{
    EVENT_PLACED,
    EVENT_USING,
    EVENT_EMPTY
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
    "menuHandlerRotate",
}

new g_szCN[][32] =
{
    "HealthCharger",
    "HEVCharger",
    "CIVCharger"
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

    register_clcmd("say /charger", "cmdMenu", ADMIN_RCON)
    register_clcmd("say_team /charger", "cmdMenu", ADMIN_RCON)
    register_concmd("charger_reload", "cmdReload", ADMIN_RCON, "-- Reload the configuration file")

    register_dictionary("Charger.txt")

    register_forward(FM_UpdateClientData, "fwdUpdateClientData", 1)
    RegisterHam(Ham_Spawn, "info_target", "fwdSpawn", 1)
    RegisterHam(Ham_Player_PreThink, "player", "fwdPreThink", 0)
    RegisterHam(Ham_Killed, "player", "fwdKilled", 1)

    register_logevent("eventRoundStart", 2, "1=Round_Start")
    set_task(g_eSettings[SETTING_GHOST_FREQ], "chargerTask", .flags = "b")

    if ( g_eSettings[SETTING_CHARGER_LOAD] )
        loadData()
}

public plugin_precache()
{
    g_aCharger       =  ArrayCreate(CHARGER)
    g_aChargerConfig =  ArrayCreate(CHARGER)

    ReadFile()
}

public plugin_end()
{
    ArrayDestroy(g_aCharger)
    ArrayDestroy(g_aChargerConfig)
}

public cmdMenu(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1) )
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

    new eCharger[CHARGER]
    for ( new i = 0; i < g_iCharger; i ++ )
    {
        ArrayGetArray(g_aCharger, i, eCharger)
        chargerRefill(eCharger)
        eCharger[CHARGER_NEXT_REFILL] = 0.0
        ArraySetArray(g_aCharger, i, eCharger)

        if ( pev(eCharger[CHARGER_ID], pev_sequence) == CHARGER_SEQ_OFF )
            chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_IDLE)
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
                            chargerPush(eCharger)

                        copy(eCharger[CHARGER_NAME], charsmax(eCharger[CHARGER_NAME]), szData)
                        eCharger[CHARGER_MODEL][0]    = EOS
                        eCharger[CHARGER_CLASS]       = 0
                        eCharger[CHARGER_MODE]        = 0
                        eCharger[CHARGER_SOUND]       = 0
                        eCharger[CHARGER_SOUND_FLAGS] = 0
                        eCharger[CHARGER_RATE]        = 0.0
                        eCharger[CHARGER_COOLDOWN]    = 0.0
                        eCharger[CHARGER_CAPACITY]    = 0.0
                        eCharger[CHARGER_LIMIT]       = 0.0
                        eCharger[CHARGER_REFILL]      = -1.0
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
                        else if ( equali(szKey, "SETTING_DEFAULT_RATE") )
                        {
                            g_eSettings[SETTING_DEFAULT_RATE] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_COOLDOWN") )
                        {
                            g_eSettings[SETTING_DEFAULT_COOLDOWN] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_CAPACITY") )
                        {
                            g_eSettings[SETTING_DEFAULT_CAPACITY] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_DEFAULT_LIMIT") )
                        {
                            g_eSettings[SETTING_DEFAULT_LIMIT] = str_to_float(szValue)
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
                        else if ( equali(szKey, "SETTING_HEALTH_PLACED") )
                        {
                            copy(g_eSettings[SETTING_HEALTH_PLACED], charsmax(g_eSettings[SETTING_HEALTH_PLACED]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_HEALTH_PLACED])
                        }
                        else if ( equali(szKey, "SETTING_HEALTH_USING") )
                        {
                            copy(g_eSettings[SETTING_HEALTH_USING], charsmax(g_eSettings[SETTING_HEALTH_USING]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_HEALTH_USING])
                        }
                        else if ( equali(szKey, "SETTING_HEALTH_EMPTY") )
                        {
                            copy(g_eSettings[SETTING_HEALTH_EMPTY], charsmax(g_eSettings[SETTING_HEALTH_EMPTY]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_HEALTH_EMPTY])
                        }
                        else if ( equali(szKey, "SETTING_HEV_PLACED") )
                        {
                            copy(g_eSettings[SETTING_HEV_PLACED], charsmax(g_eSettings[SETTING_HEV_PLACED]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_HEV_PLACED])
                        }
                        else if ( equali(szKey, "SETTING_HEV_USING") )
                        {
                            copy(g_eSettings[SETTING_HEV_USING], charsmax(g_eSettings[SETTING_HEV_USING]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_HEV_USING])
                        }
                        else if ( equali(szKey, "SETTING_HEV_EMPTY") )
                        {
                            copy(g_eSettings[SETTING_HEV_EMPTY], charsmax(g_eSettings[SETTING_HEV_EMPTY]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_HEV_EMPTY])
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
                        else if ( equali(szKey, "SETTING_GHOST_ALPHA") )
                        {
                            g_eSettings[SETTING_GHOST_ALPHA] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_GHOST_FREQ") )
                        {
                            g_eSettings[SETTING_GHOST_FREQ] = str_to_float(szValue)
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
                            if ( !equali(g_eSettings[SETTING_DEFAULT_MODEL], szValue) && !g_bFileWasRead )
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
                        else if ( equali(szKey, "CHARGER_SOUND") )
                        {
                            eCharger[CHARGER_SOUND] = str_to_num(szValue)
                            eCharger[CHARGER_SOUND] = clamp(eCharger[CHARGER_SOUND], SOUND_HEALTH, SOUND_HEV)
                        }
                        else if ( equali(szKey, "CHARGER_SOUND_FLAGS") )
                        {
                            eCharger[CHARGER_SOUND_FLAGS] = read_flags(szValue)
                            eCharger[CHARGER_SOUND_FLAGS] &= 7
                        }
                        else if ( equali(szKey, "CHARGER_RATE") )
                        {
                            eCharger[CHARGER_RATE] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "CHARGER_COOLDOWN") )
                        {
                            eCharger[CHARGER_COOLDOWN] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "CHARGER_CAPACITY") )
                        {
                            eCharger[CHARGER_CAPACITY] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "CHARGER_LIMIT") )
                        {
                            eCharger[CHARGER_LIMIT] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "CHARGER_REFILL") )
                        {
                            eCharger[CHARGER_REFILL] = str_to_float(szValue)
                        }
                    }
                }
            }
        }
    }

    if ( g_iChargerConfig )
        chargerPush(eCharger)
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

    playerReset(id)
}

public chargerMenu(iArg[TASK_MENU])
{
    new szTitle[64],
        id, iType, iMenu

    id    = iArg[TASK_ID]
    iType = iArg[TASK_TYPE]
    formatex(szTitle,charsmax(szTitle), "%L", id, "CHARGER_MENU_TITLE")
    iMenu = menu_create(szTitle, g_szMenuHandler[iType])

    switch( iType )
    {
        case MENU_ROOT:     menuRoot(id, iMenu)
        case MENU_CREATE:   menuCreate(iMenu)
        case MENU_REMOVE:   menuRemove(id, iMenu)
        case MENU_ROTATE:   menuRotate(id, iMenu)
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

public menuCreate(iMenu)
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

    chargerCreate(id, item, true)
    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuRemove(id, iMenu)
{
    new szItem[64],
        eCharger[CHARGER], iIndex

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_DEL_NEXT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_DEL_BACK")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CHARGER_DEL_REMOVE")
    menu_additem(iMenu, szItem)

    iIndex = g_ePlayerData[id][PDATA_CHARGER_MENU]
    ArrayGetArray(g_aCharger, iIndex, eCharger)

    if ( pev_valid(eCharger[CHARGER_ID]) )
        chargerSetGlow(eCharger[CHARGER_ID], true)
}

public menuHandlerRemove(id, menu, item)
{
    new iArg[TASK_MENU],
        eCharger[CHARGER], iIndex

    iIndex = g_ePlayerData[id][PDATA_CHARGER_MENU]
    ArrayGetArray(g_aCharger, iIndex, eCharger)

    iArg[TASK_ID] = id

    if ( pev_valid(eCharger[CHARGER_ID]) )
        chargerSetGlow(eCharger[CHARGER_ID], false)

    switch( item )
    {
        case DEL_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_CHARGER_MENU] >= g_iCharger - 1 )
                g_ePlayerData[id][PDATA_CHARGER_MENU] = 0
            else
                g_ePlayerData[id][PDATA_CHARGER_MENU]++

            iArg[TASK_TYPE] = MENU_REMOVE
            set_task(MENU_BLINK, "chargerMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case DEL_BACK:
        {
            if ( g_ePlayerData[id][PDATA_CHARGER_MENU] <= 0 )
                g_ePlayerData[id][PDATA_CHARGER_MENU] = g_iCharger - 1
            else
                g_ePlayerData[id][PDATA_CHARGER_MENU]--

            iArg[TASK_TYPE] = MENU_REMOVE
            set_task(MENU_BLINK, "chargerMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case DEL_REMOVE:
        {
            chargerRemove(eCharger)
            g_ePlayerData[id][PDATA_CHARGER_MENU] = 0

            iArg[TASK_TYPE] = MENU_ROOT
            set_task(MENU_BLINK, "chargerMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        default:
        {
            g_ePlayerData[id][PDATA_CHARGER_MENU] = 0
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
    new iArg[TASK_MENU],
        eCharger[CHARGER]

    iArg[TASK_ID] = id

    switch( item )
    {
        case ROTATE_RIGHT:
        {
            chargerFind(g_ePlayerData[id][PDATA_CHARGER_GHOST], eCharger)

            eCharger[CHARGER_ANGLES][1] -= 90.0
            if ( eCharger[CHARGER_ANGLES][1] < -180.0 ) eCharger[CHARGER_ANGLES][1] += 360.0

            set_pev(eCharger[CHARGER_ID], pev_angles, eCharger[CHARGER_ANGLES])
            chargerUpdate(eCharger)

            iArg[TASK_TYPE] = MENU_ROTATE
            set_task(MENU_BLINK, "chargerMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case ROTATE_LEFT:
        {
            chargerFind(g_ePlayerData[id][PDATA_CHARGER_GHOST], eCharger)

            eCharger[CHARGER_ANGLES][1] += 90.0
            if ( eCharger[CHARGER_ANGLES][1] > 180.0 ) eCharger[CHARGER_ANGLES][1] -= 360.0

            set_pev(eCharger[CHARGER_ID], pev_angles, eCharger[CHARGER_ANGLES])
            chargerUpdate(eCharger)

            iArg[TASK_TYPE] = MENU_ROTATE
            set_task(MENU_BLINK, "chargerMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case ROTATE_PLACE:
        {
            if ( chargerTrace(id) )
            {
                chargerFind(g_ePlayerData[id][PDATA_CHARGER_GHOST], eCharger)
                chargerSetBox(eCharger)
                chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_IDLE)

                pev(eCharger[CHARGER_ID], pev_origin, eCharger[CHARGER_ORIGIN])

                eCharger[CHARGER_NEXT_USE]             = get_gametime() + 0.25
                g_ePlayerData[id][PDATA_OFFSET]        = g_eSettings[SETTING_OFFSET_BASE]
                g_ePlayerData[id][PDATA_CHARGER_GHOST] = 0

                chargerUpdate(eCharger)

                if ( eCharger[CHARGER_SOUND_FLAGS] & CHARGER_SOUND_PLACED )
                    chargerSetSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND], EVENT_PLACED, 0)
            }
        }
        default:
        {
            chargerKill(g_ePlayerData[id][PDATA_CHARGER_GHOST])
            g_ePlayerData[id][PDATA_CHARGER_GHOST] = 0
        }
    }

    menu_destroy( menu )
    return PLUGIN_HANDLED
}

public chargerTask()
{
    new iPlayers[MAX_PLAYERS], iNum, id,
        eCharger[CHARGER], iEnt

    get_players(iPlayers, iNum, "ach")

    for ( new i = 0; i < iNum; i ++ )
    {
        id = iPlayers[i]

        if ( !g_ePlayerData[id][PDATA_CHARGER_GHOST] )
            continue

        iEnt = g_ePlayerData[id][PDATA_CHARGER_GHOST]

        if ( chargerTrace(id) )
            set_rendering(iEnt, kRenderFxNone, 255, 255, 255, kRenderNormal, 255)
        else
            set_rendering(iEnt, kRenderFxNone, 255, 255, 255, kRenderTransAlpha, g_eSettings[SETTING_GHOST_ALPHA])
    }

    for ( new i = 0; i < g_iCharger; i ++ )
    {
        ArrayGetArray(g_aCharger, i, eCharger)

        if ( eCharger[CHARGER_NEXT_REFILL]
        && get_gametime() > eCharger[CHARGER_NEXT_REFILL] )
        {
            chargerSetSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND], EVENT_PLACED, 0)

            chargerRefill(eCharger)
            eCharger[CHARGER_NEXT_REFILL] = 0.0
            chargerUpdate(eCharger)
            chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_IDLE)
        }
        else if ( eCharger[CHARGER_NEXT_STOP]
        && get_gametime() > eCharger[CHARGER_NEXT_STOP] )
        {
            chargerSetSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND], EVENT_USING, SND_STOP)

            eCharger[CHARGER_OCCUPIED]  = 0
            eCharger[CHARGER_NEXT_STOP] = 0.0
            chargerUpdate(eCharger)
        }
    }
}

public chargerCreate(id, iItem, bool:bPlayer)
{
    new iEnt
    iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))

    if ( !pev_valid(iEnt) )
        return

    new eCharger[CHARGER],
        iClass

    ArrayGetArray(g_aChargerConfig, iItem, eCharger)
    eCharger[CHARGER_ID]   = iEnt
    eCharger[CHARGER_ITEM] = iItem
    if ( bPlayer )
        g_ePlayerData[id][PDATA_CHARGER_GHOST] = eCharger[CHARGER_ID]

    iClass = eCharger[CHARGER_CLASS]
    set_pev(iEnt, pev_classname, g_szCN[iClass])
    engfunc(EngFunc_SetModel, iEnt, eCharger[CHARGER_MODEL])

    ArrayPushArray(g_aCharger, eCharger)
    g_iCharger++

    dllfunc(DLLFunc_Spawn, iEnt)
}

public chargerRemove(eCharger[CHARGER])
{
    new iItem

    chargerSetSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND], EVENT_EMPTY, 0)
    chargerKill(eCharger[CHARGER_ID])

    if ( (iItem = chargerGetItem(eCharger)) != -1 )
        ArrayDeleteItem(g_aCharger, iItem)

    g_iCharger--
}

public saveData(id)
{
    new eCharger[CHARGER],
        szFile[64], iFile,
        szData[64]

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_charger.ini", szFile)

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

        formatex(szData, charsmax(szData), "angles = %.2f %.2f %.2f^n^n",
        eCharger[CHARGER_ANGLES][0], eCharger[CHARGER_ANGLES][1], eCharger[CHARGER_ANGLES][2])
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
        Float:fOrigin[3], Float:fAngles[3], iItem,
        eCharger[CHARGER], iCount = -1

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_charger.ini", szFile)

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
                chargerCreate(0, iItem, false)
                ArrayGetArray(g_aCharger, iCount, eCharger)

                chargerSetBox(eCharger)
                chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_IDLE)

                set_pev(eCharger[CHARGER_ID], pev_origin, fOrigin)
                set_pev(eCharger[CHARGER_ID], pev_angles, fAngles)
                xs_vec_copy(fOrigin, eCharger[CHARGER_ORIGIN])
                xs_vec_copy(fAngles, eCharger[CHARGER_ANGLES])
                ArraySetArray(g_aCharger, iCount, eCharger)
            }

            iCount++
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
            }
        }
    }

    if ( iCount != -1 )
    {
        chargerCreate(0, iItem, false)
        ArrayGetArray(g_aCharger, iCount, eCharger)

        chargerSetBox(eCharger)
        chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_IDLE)

        set_pev(eCharger[CHARGER_ID], pev_origin, fOrigin)
        set_pev(eCharger[CHARGER_ID], pev_angles, fAngles)
        xs_vec_copy(fOrigin, eCharger[CHARGER_ORIGIN])
        xs_vec_copy(fAngles, eCharger[CHARGER_ANGLES])
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

public fwdKilled(id, iAttacker, bGib)
{
    if ( g_ePlayerData[id][PDATA_CHARGER_GHOST] )
    {
        chargerKill(g_ePlayerData[id][PDATA_CHARGER_GHOST])
    }
    else
    {
        new eCharger[CHARGER]

        if ( isOccupied(id, eCharger) )
        {
            chargerSetSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND], EVENT_USING, SND_STOP)

            eCharger[CHARGER_OCCUPIED]  = 0
            eCharger[CHARGER_NEXT_STOP] = 0.0
            chargerUpdate(eCharger)
        }
    }

    playerReset(id)
    return HAM_IGNORED
}

public fwdPreThink(id)
{
    if ( !is_user_alive(id) )
        return HAM_IGNORED

    new iButton
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
        new eCharger[CHARGER],
            iEnt

        iEnt = chargerUse(id)

        if ( iEnt && chargerFind(iEnt, eCharger) )
        {
            if ( get_gametime() > eCharger[CHARGER_NEXT_USE]
            && (!eCharger[CHARGER_OCCUPIED] || eCharger[CHARGER_OCCUPIED] == id) )
                chargerSupply(id, eCharger)

            iButton &= ~IN_USE
            set_pev(id, pev_button, iButton)
        }
        else
        {
            if ( !isOccupied(id, eCharger)
            || eCharger[CHARGER_NEXT_STOP] > 0.0 )
                return HAM_IGNORED

            eCharger[CHARGER_NEXT_STOP] = get_gametime() + 0.1
            chargerUpdate(eCharger)
        }
    }

    return HAM_IGNORED
}

public bool:chargerTrace(id)
{
    new Float:fOrigin[3],
        Float:fViewAngles[3],
        Float:fViewOfs[3],
        Float:fForward[3],
        Float:fEnd[3],
        Float:fNormal[3],
        iTr, Float:fFraction

    pev(id, pev_origin, fOrigin)
    pev(id, pev_v_angle, fViewAngles)
    pev(id, pev_view_ofs, fViewOfs)
    xs_vec_add(fOrigin , fViewOfs, fOrigin)

    engfunc(EngFunc_AngleVectors, fViewAngles, fForward, NULL_VECTOR, NULL_VECTOR)
    xs_vec_mul_scalar(fForward, g_ePlayerData[id][PDATA_OFFSET], fEnd)
    xs_vec_add(fEnd, fOrigin, fEnd)

    engfunc(EngFunc_TraceLine, fOrigin, fEnd, IGNORE_MONSTERS, id, iTr)
    get_tr2(iTr, TR_vecEndPos, fEnd)
    get_tr2(iTr, TR_flFraction, fFraction)
    get_tr2(iTr, TR_vecPlaneNormal, fNormal)

    xs_vec_mul_scalar(fNormal, 5.0, fOrigin)
    xs_vec_add(fOrigin, fEnd, fOrigin)

    set_pev(g_ePlayerData[id][PDATA_CHARGER_GHOST], pev_origin, fOrigin)

    return fFraction < 1.0 && chargerRadius(fOrigin)
}

public chargerUse(id)
{
    if ( !(pev(id, pev_button) & IN_USE) )
        return 0

    new Float:fOrigin[3],
        Float:fViewAngles[3],
        Float:fViewOfs[3],
        Float:fForward[3],
        Float:fEnd[3],
        iTr, iEnt = -1

    pev(id, pev_origin, fOrigin)
    pev(id, pev_v_angle, fViewAngles)
    pev(id, pev_view_ofs, fViewOfs)
    xs_vec_add(fOrigin ,fViewOfs, fOrigin)

    engfunc(EngFunc_AngleVectors, fViewAngles, fForward, NULL_VECTOR, NULL_VECTOR)
    xs_vec_mul_scalar(fForward, g_eSettings[SETTING_CHARGER_RANGE], fEnd)
    xs_vec_add(fEnd, fOrigin, fEnd)

    engfunc(EngFunc_TraceLine, fOrigin, fEnd, IGNORE_MONSTERS, id, iTr)
    get_tr2(iTr, TR_vecEndPos, fEnd)

    while( (iEnt = engfunc(EngFunc_FindEntityInSphere, iEnt, fEnd, 15.0)) )
    {
        if ( !pev_valid(iEnt) )
            continue

        if ( isCharger(iEnt) )
            return iEnt
    }

    return 0
}

public chargerSupply(id, eCharger[CHARGER])
{
    if ( eCharger[CHARGER_CAPACITY] > 0 )
    {

        if ( !eCharger[CHARGER_OCCUPIED] )
        {
            eCharger[CHARGER_OCCUPIED] = id
            eCharger[CHARGER_NEXT_STOP] = 0.0
            chargerUpdate(eCharger)

            if ( eCharger[CHARGER_SOUND_FLAGS] & CHARGER_SOUND_USING )
                chargerSetSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND], EVENT_USING, 0)
        }
        else if ( eCharger[CHARGER_NEXT_STOP] > 0.0 )
        {
            eCharger[CHARGER_NEXT_STOP] = 0.0
            chargerUpdate(eCharger)
        }

        switch( eCharger[CHARGER_MODE] )
        {
            case MODE_HEALTH: chargerSupplyHealth(id, eCharger)
            case MODE_ARMOR:  chargerSupplyArmor(id, eCharger)
        }

        if ( !eCharger[CHARGER_CAPACITY] )
        {
            chargerSetSeq(eCharger[CHARGER_ID], CHARGER_SEQ_OFF)
            chargerSetSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND], EVENT_USING, SND_STOP)

            eCharger[CHARGER_OCCUPIED]  = 0
            eCharger[CHARGER_NEXT_STOP] = 0.0

            if ( eCharger[CHARGER_REFILL] != -1 )
                eCharger[CHARGER_NEXT_REFILL] = get_gametime() + eCharger[CHARGER_REFILL]

            chargerUpdate(eCharger)
        }
    }
    else
    {
        if ( get_gametime() > eCharger[CHARGER_NEXT_SOUND]
        && eCharger[CHARGER_SOUND_FLAGS] & CHARGER_SOUND_EMPTY )
        {
            eCharger[CHARGER_NEXT_SOUND] = get_gametime() + 1.0
            chargerSetSound(eCharger[CHARGER_ID], eCharger[CHARGER_SOUND], EVENT_EMPTY, 0)

            chargerUpdate(eCharger)
        }
    }
}

chargerSupplyHealth(id, eCharger[CHARGER])
{
    new Float:fHealth,
        Float:fBoost

    pev(id, pev_health, fHealth)
    fBoost = floatclamp(eCharger[CHARGER_RATE], 0.0, eCharger[CHARGER_CAPACITY])
    fBoost = floatclamp(fBoost, 0.0, eCharger[CHARGER_LIMIT] - fHealth)
    fHealth += fBoost

    set_pev(id, pev_health, fHealth)
    eCharger[CHARGER_CAPACITY] -= fBoost
    eCharger[CHARGER_NEXT_USE] = get_gametime() + eCharger[CHARGER_COOLDOWN]

    chargerUpdate(eCharger)
}

chargerSupplyArmor(id, eCharger[CHARGER])
{
    new Float:fArmor,
        Float:fBoost

    pev(id, pev_armorvalue, fArmor)
    fBoost = floatclamp(eCharger[CHARGER_RATE], 0.0, eCharger[CHARGER_CAPACITY])
    fBoost = floatclamp(fBoost, 0.0, eCharger[CHARGER_LIMIT] - fArmor)
    fArmor += fBoost

    set_pev(id, pev_armorvalue, fArmor)
    eCharger[CHARGER_CAPACITY] -= fBoost
    eCharger[CHARGER_NEXT_USE] = get_gametime() + eCharger[CHARGER_COOLDOWN]

    chargerUpdate(eCharger)
}

stock chargerPush(eCharger[CHARGER])
{
    if ( !eCharger[CHARGER_MODEL] )    copy( eCharger[CHARGER_MODEL], charsmax(eCharger[CHARGER_MODEL]), g_eSettings[SETTING_DEFAULT_MODEL])
    if ( !eCharger[CHARGER_RATE] )     eCharger[CHARGER_RATE]     = g_eSettings[SETTING_DEFAULT_RATE]
    if ( !eCharger[CHARGER_COOLDOWN] ) eCharger[CHARGER_COOLDOWN] = g_eSettings[SETTING_DEFAULT_COOLDOWN]
    if ( !eCharger[CHARGER_CAPACITY] ) eCharger[CHARGER_CAPACITY] = g_eSettings[SETTING_DEFAULT_CAPACITY]
    if ( !eCharger[CHARGER_LIMIT] )    eCharger[CHARGER_LIMIT]    = g_eSettings[SETTING_DEFAULT_LIMIT]

    ArrayPushArray(g_aChargerConfig, eCharger)
}

stock playerReset(id)
{
    g_ePlayerData[id][PDATA_CHARGER_GHOST] = 0
    g_ePlayerData[id][PDATA_CHARGER_MENU]  = 0
    g_ePlayerData[id][PDATA_OFFSET]        = g_eSettings[SETTING_OFFSET_BASE]
    g_ePlayerData[id][PDATA_NEXT_OFFSET]   = 0.0
}

stock chargerSetBox(eCharger[CHARGER])
{
    new Float:fMins[3],
        Float:fMaxs[3]

    set_pev(eCharger[CHARGER_ID], pev_solid, SOLID_BBOX)
    set_pev(eCharger[CHARGER_ID], pev_movetype, MOVETYPE_FLY)

    switch( eCharger[CHARGER_CLASS] )
    {
        case CLASS_HEALTH, CLASS_HEV: { xs_vec_copy(g_eSettings[SETTING_MINS_STANDARD], fMins); xs_vec_copy(g_eSettings[SETTING_MAXS_STANDARD], fMaxs); }
        case CLASS_CIV:               { xs_vec_copy(g_eSettings[SETTING_MINS_CIVILIAN], fMins); xs_vec_copy(g_eSettings[SETTING_MAXS_CIVILIAN], fMaxs); }
    }

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

stock chargerSetGlow(iEnt, bool:bGlow)
{
    if ( bGlow ) set_rendering(iEnt, kRenderFxGlowShell, 120, 0, 0, kRenderNormal, 32)
    else         set_rendering(iEnt, kRenderFxNone, 255, 255, 255, kRenderNormal, 255)
}

stock chargerSetSound(iEnt, iSound, iEvent, iFlags)
{
    new szSample[64]

    switch( iSound )
    {
        case SOUND_HEALTH:
        {
            switch( iEvent )
            {
                case EVENT_PLACED: copy(szSample, charsmax(szSample), g_eSettings[SETTING_HEALTH_PLACED])
                case EVENT_USING:  copy(szSample, charsmax(szSample), g_eSettings[SETTING_HEALTH_USING])
                case EVENT_EMPTY:  copy(szSample, charsmax(szSample), g_eSettings[SETTING_HEALTH_EMPTY])
            }
        }
        case SOUND_HEV:
        {
            switch( iEvent )
            {
                case EVENT_PLACED: copy(szSample, charsmax(szSample), g_eSettings[SETTING_HEV_PLACED])
                case EVENT_USING:  copy(szSample, charsmax(szSample), g_eSettings[SETTING_HEV_USING])
                case EVENT_EMPTY:  copy(szSample, charsmax(szSample), g_eSettings[SETTING_HEV_EMPTY])
            }
        }
    }

    engfunc(EngFunc_EmitSound, iEnt, CHAN_ITEM, szSample, VOL_NORM, ATTN_NORM, iFlags, PITCH_NORM)
}

stock bool:chargerRadius(Float:fOrigin[3])
{
    new iEnt = -1

    while( (iEnt = engfunc(EngFunc_FindEntityInSphere, iEnt, fOrigin, 15.0)) )
    {
        if ( !pev_valid(iEnt)
        || pev(iEnt, pev_solid) <= SOLID_TRIGGER
        || (pev(iEnt, pev_solid) == SOLID_BSP && pev(iEnt, pev_takedamage) == DAMAGE_NO) )
            continue

        return false
    }

    return true
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

stock bool:isOccupied(id, eCharger[CHARGER])
{
    for ( new i = 0; i < g_iCharger; i ++ )
    {
        ArrayGetArray(g_aCharger, i, eCharger)
        if ( eCharger[CHARGER_OCCUPIED] == id )
            return true
    }

    return false
}

stock chargerRefill(eCharger[CHARGER])
{
    new eChargerConfig[CHARGER]

    ArrayGetArray(g_aChargerConfig, eCharger[CHARGER_ITEM], eChargerConfig)
    eCharger[CHARGER_CAPACITY] = eChargerConfig[CHARGER_CAPACITY]
}

stock chargerKill(iEnt)
{
    if (pev_valid(iEnt))
        set_pev(iEnt, pev_flags, FL_KILLME)
}

stock chargerUpdate(eCharger[CHARGER])
{
    new iItem
    iItem = chargerGetItem(eCharger)

    if ( iItem != -1 )
        ArraySetArray(g_aCharger, iItem, eCharger)
}

public chargerFind(iEnt, eCharger[CHARGER])
{
    for ( new i = 0; i < g_iCharger; i ++ )
    {
        ArrayGetArray(g_aCharger, i, eCharger)
        if ( eCharger[CHARGER_ID] == iEnt )
            return true
    }

    return false
}

public chargerGetItem(eCharger[CHARGER])
{
    new eTemp[CHARGER]
    for ( new i = 0; i < g_iCharger; i ++ )
    {
        ArrayGetArray(g_aCharger, i, eTemp)
        if ( eCharger[CHARGER_ID] == eTemp[CHARGER_ID] )
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