/*
Author: KtOrangeeK
Version: 1
*/
local ctx = this;

class ChatCmdArg
{
    _name = null;
    _isOptional = false;
    _expectedType = null;
    _defaultValue = null;

    /*
    table info:
    {
        string name;
        bool isOptional;
        string expectedType;
        any defaultValue;
    }
    */
    constructor(info)
    {
        _name = info.name;
        _isOptional = info.isOptional;
        if ("expectedType" in info)
        {
            _expectedType = info.expectedType;
        }
        if ("defaultValue" in info)
        {
            _defaultValue = info.defaultValue;
        }
    }

    function GetName()
    {
        return _name;
    }

    function GetDefaultValue()
    {
        return _defaultValue;
    }

    function IsOptional()
    {
        return _isOptional;
    }

    function GetExpectedType()
    {
        return _expectedType;
    }
}

class ChatCmd
{
    _name = null;
    _permissionLevel = null;
    //Positional argument array. The element is the argument name.
    _positionalArgs = null;
    //Argument table. The key is the argument name and the value is a ChatCmdArg instance.
    _args = null;
    _action = null;

    /*
    table info:
    {
        string name;
        array args;
        function action;
        array positionalArgs;
        int permissionLevel;
    }
    action is a function as a callback that implements commmand functions.
    action function signature: function(playerEnt, argTable). argTable is table whose key is argument name and value is argument value.
    */
    constructor(info)
    {
        _name = info.name;
        _args = {};
        _action = info.action;
        if ("args" in info)
        {
            foreach (arg in info.args)
            {
                _args[arg.GetName()] <- arg;
            }
        }
        if ("positionalArgs" in info && info.positionalArgs)
        {
            _positionalArgs = clone info.positionalArgs;
        }
        else
        {
            _positionalArgs = [];
        }
        _permissionLevel = info.permissionLevel;
    }

    function GetPermissionLevel()
    {
        return _permissionLevel;
    }
    function SetPermissionLevel(level)
    {
        _permissionLevel = level;
    }

    function GetName()
    {
        return _name;
    }

    function GetAction()
    {
        return _action;
    }

    function GetPositionalArgCount()
    {
        return _positionalArgs.len();
    }

    //Return argument name(string).
    function GetPositionalArg(index)
    {
        return _positionalArgs[index];
    }

    function GetArgCount()
    {
        return _args.len();
    }

    function GetArg(name)
    {
        if (name in _args)
        {
            return _args[name];
        }
        return null;
    }

    function Args()
    {
        foreach (key, val in _args)
        {
            yield val;
        }
    }
}

local cmdStartChar = "#";
local configPath = "ktscript/chat_cmd_system/config.nut"
local TopPermissionLevel = 5;

//The key is command name and the value is ChatCmd instance.
local cmdTable = {};

//The key is player network id and the value is the permission level.
local permissionTable = null;

//The key is the command name and the value is the permission level.
local cmdPermTable = null;

function AddChatCmd(cmd)
{
    cmdTable[cmd.GetName()] <- cmd;
}

function RemoveChatCmd(name)
{
    delete cmdTable[name];
}

function GetChatCmdCount()
{
    return cmdTable.len();
}

function ChatCmds()
{
    foreach (key, val in cmdTable)
    {
        yield val;
    }
}

function GetChatCmd(name)
{
    if (name in cmdTable)
    {
        return cmdTable[name];
    }
    return null;
}

function GetChatCmdOverridedPermissionLevel(name)
{
    if (name in cmdPermTable)
    {
        return cmdPermTable[name];
    }
    else
    {
        return null;
    }
}

function SetChatCmdOverridedPermissionLevel(name, level)
{
    cmdPermTable[name] <- level;
}

function GetChatCmdActualPermissionLevel(name)
{
    local level = GetChatCmdOverridedPermissionLevel(name);
    if (level != null) return level;
    local cmd = GetChatCmd(name);
    level = cmd.GetPermissionLevel();
    return level;
}

local function IsAlphanumeric(c)
{
    local n = c[0];
    return c == "_" || (n >= "a"[0] && n <= "z"[0]) || (n >= "A"[0] && n <= "Z"[0]) || (n >= "0"[0] && n <= "9"[0]);
}

local function IsBlank(c)
{
    return c == " ";
}

local function IsNamingStartChar(c)
{
    return c == "-";
}

local function IsQuotationChar(c)
{
    return c == @"""";
}

/*
Return a table
{
    string name; (Command name)
    table argTable; (The key is argument name and the value is argument value)
}
*/
function ParseChatCmd(cmdStr)
{
    if (cmdStr[0].tochar() != cmdStartChar)
    {
        return null;
    }
    cmdStr += " ";
    local len = cmdStr.len();
    local i = 1;
    local argStartIndex = null;
    local parsingArgName = false;
    local lastArgName = null;
    local quotationMode = false;
    local positionalArgIndex = 0;
    local StateName = 0;
    local StateBlank = 1;
    local StateArg = 2;
    local state = StateName;
    local cmd = null;
    local argTable = {};
    while (i < len)
    {
        local c = cmdStr[i].tochar();
        if (state == StateName)
        {
            if (IsBlank(c))
            {
                local name = cmdStr.slice(1, i);
                cmd = GetChatCmd(name);
                if (!cmd)
                {
                    throw "Undefined command: " + name;
                }
                state = StateBlank;
            }
            else if (!IsAlphanumeric(c))
            {
                throw "Invalid character: " + c;
            }
        }
        else if (state == StateBlank)
        {
            if (IsAlphanumeric(c))
            {
                state = StateArg;
                argStartIndex = i;
            }
            else if (IsQuotationChar(c))
            {
                state = StateArg;
                argStartIndex = i + 1;
                quotationMode = true;
            }
            else if (IsNamingStartChar(c))
            {
                state = StateArg;
                argStartIndex = i + 1;
                parsingArgName = true;
            }
            else if (!IsBlank(c))
            {
                throw "Invalid character: " + c;
            }
        }
        else if (state == StateArg)
        {
            if ((quotationMode && IsQuotationChar(c)) || (!quotationMode && IsBlank(c)))
            {
                quotationMode = false;
                local val = cmdStr.slice(argStartIndex, i);
                if (parsingArgName)
                {
                    parsingArgName = false;
                    if (!cmd.GetArg(val))
                    {
                        throw "Undefined argument name: " + val;
                    }
                    lastArgName = val;
                }
                else
                {
                    if (lastArgName)
                    {
                        argTable[lastArgName] <- val;
                        lastArgName = null;
                    }
                    else
                    {
                        local argCount = cmd.GetPositionalArgCount();
                        if (positionalArgIndex >= argCount)
                        {
                            throw "Overmuch positional arguments."
                        }
                        local argName = cmd.GetPositionalArg(positionalArgIndex);
                        argTable[argName] <- val;
                        positionalArgIndex++;
                    }
                }
                state = StateBlank;
            }
        }
        i++;
    }
    if (state == StateName)
    {
        local cmdName = cmdStr.slice(1, cmdStr.len());
        cmd = GetChatCmd(cmdName);
        if (!cmd)
        {
            throw "Undefined command name: " + cmdName;
        }
    }

    local cmdAllArgs = cmd.Args();
    foreach (arg in cmdAllArgs)
    {
        local name = arg.GetName();
        if (name in argTable)
        {
            local expectedType = arg.GetExpectedType();
            if (expectedType)
            {
                local errorHint = "The argument " + @"""" + name + @"""" + " should be %s";
                if (expectedType == "integer")
                {
                    try
                    {
                        argTable[name] <- argTable[name].tointeger();
                    }
                    catch (e)
                    {
                        throw format(errorHint, "integer");
                    }
                }
                else if (expectedType == "float")
                {
                    try
                    {
                        argTable[name] <- argTable[name].tofloat();
                    }
                    catch (e)
                    {
                        throw format(errorHint, "float");
                    }
                }
            }
        }
        else
        {
            if (!arg.IsOptional())
            {
                throw "The value of the argument " + @"""" + name + @"""" + " must be assigned";
            }
            argTable[name] <- arg.GetDefaultValue();
        }
    }
    return {
        name = cmd.GetName(),
        argTable = argTable
    };
}

function GetPlayerChatCmdPermissionLevel(networkid)
{
    if (networkid in permissionTable)
    {
        return permissionTable[networkid];
    }
    return 0;
}

function SetPlayerChatCmdPermissionLevel(networkid, level)
{
    permissionTable[networkid] <- level;
}

function AllPlayerChatCmdPermissionLevel()
{
    foreach (key, val in permissionTable)
    {
        yield {
            networkid = key,
            permissionLevel = val
        }
    }
}

//Return a bool value that indicates whether the player has the permission when ignorePermission is false.
//When ignorePermission is true, it will ignore permission check and always return true if the command executes successfully.
function ExecuteCmd(playerEnt, cmdName, argTable, ignorePermission = false)
{
    local cmd = GetChatCmd(cmdName);
    if (cmd)
    {
        if (!ignorePermission)
        {
            local cmdLevel = GetChatCmdActualPermissionLevel(cmdName);
            local playerLevel = GetPlayerChatCmdPermissionLevel(playerEnt.GetNetworkIDString());
            if (playerLevel < cmdLevel)
            {
                return false;
            }
        }
        local action = cmd.GetAction();
        action(playerEnt, argTable);
        return true;
    }
    else
    {
        throw "Undefined command name: " + cmdName;
    }
}

function SaveChatCmdConfig()
{
    local config =
    {
        permissionTable = permissionTable
        overridedCommandPermissionTable = cmdPermTable
    }
    ::KtScript.TableToFile(config, configPath);
}

local function InitConfig()
{
    local config = ::KtScript.FileToTable(configPath);
    if (config)
    {
        permissionTable = config.permissionTable;
        if ("overridedCommandPermissionTable" in config)
        {
            cmdPermTable = config.overridedCommandPermissionTable;
        }
        else
        {
            cmdPermTable = {};
        }
    }
    else
    {
        permissionTable = {};
        cmdPermTable = {};
        //local hostPlayer = GetListenServerHost();
        //SetPlayerChatCmdPermissionLevel(hostPlayer.GetNetworkIDString(), TopPermissionLevel);
        //SaveChatCmdConfig();
    }
}

local function InitBuiltInCmd()
{
    AddChatCmd(
        ChatCmd({
            name = "show_networkid",
            args = [
                ChatCmdArg({
                    name = "a",
                    isOptional = true,
                    expectedType = "integer",
                    defaultValue = 0
                })
            ],
            action = function(playerEnt, argTable)
            {
                if (argTable.a)
                {
                    ClientPrint(playerEnt, DirectorScript.HUD_PRINTTALK, "All Players' Network ID: ");
                    local players = ::KtScript.AllPlayers(true);
                    foreach (player in players)
                    {
                        ClientPrint(playerEnt, DirectorScript.HUD_PRINTTALK, player.GetPlayerName() + ": " + player.GetNetworkIDString());
                    }
                    return;
                }
                ClientPrint(playerEnt, DirectorScript.HUD_PRINTTALK, "Your Network ID is " + playerEnt.GetNetworkIDString());
            }.bindenv(ctx),
            positionalArgs = null,
            permissionLevel = 0
        })
    );

    AddChatCmd(
        ChatCmd({
            name = "chatcmd_cmd_perm",
            args = [
                ChatCmdArg({
                    name = "cmdname",
                    isOptional = true
                }),
                ChatCmdArg({
                    name = "level",
                    isOptional = true,
                    expectedType = "integer"
                })
            ],
            action = function(playerEnt, argTable) {
                local cmdname = argTable.cmdname;
                if (cmdname == null)
                {
                    ClientPrint(playerEnt, DirectorScript.HUD_PRINTTALK, "Permisson levels of all commands: ");
                    foreach (key, val in cmdTable)
                    {
                        local name = key;
                        local level = GetChatCmdActualPermissionLevel(name);
                        ClientPrint(playerEnt, DirectorScript.HUD_PRINTTALK, format("%s: %d", name, level));
                    }
                    return;
                }
                local level = argTable.level;
                local cmd = GetChatCmd(cmdname);
                if (!cmd)
                {
                    ClientPrint(playerEnt, DirectorScript.HUD_PRINTTALK, format("Undefined command name: %s.", cmdname));
                    return;
                }
                if (level == null)
                {
                    level = GetChatCmdActualPermissionLevel(cmdname);
                    ClientPrint(playerEnt, DirectorScript.HUD_PRINTTALK, format("The permission level of command %s is %d.", cmdname, level));
                    return;
                }
                SetChatCmdOverridedPermissionLevel(cmdname, level);
                SaveChatCmdConfig();
                ClientPrint(playerEnt, DirectorScript.HUD_PRINTTALK, format("Set the permission level of %s to %d successfully!", cmdname, level));
            }.bindenv(ctx),
            positionalArgs = ["cmdname", "level"],
            permissionLevel = TopPermissionLevel
        })
    );

    AddChatCmd(
        ChatCmd({
            name = "chatcmd_player_perm",
            args = [
                ChatCmdArg({
                    name = "nid",
                    isOptional = true
                }),
                ChatCmdArg({
                    name = "l",
                    isOptional = true,
                    expectedType = "integer"
                })
            ],
            action = function(playerEnt, argTable)
            {
                local level = argTable.l;
                local networkid = argTable.nid;
                local printPersonal = false;
                if (networkid == null)
                {
                    networkid = playerEnt.GetNetworkIDString();
                    printPersonal = true;
                }
                if (level == null)
                {
                    level = GetPlayerChatCmdPermissionLevel(networkid);
                    if (printPersonal)
                    {
                        ClientPrint(playerEnt, DirectorScript.HUD_PRINTTALK, format("Your permission level is %d.", level));
                    }
                    else
                    {
                        ClientPrint(playerEnt, DirectorScript.HUD_PRINTTALK, format("The permission level is %d.", level));
                    }
                }
                else
                {
                    SetPlayerChatCmdPermissionLevel(networkid, level);
                    ClientPrint(playerEnt, DirectorScript.HUD_PRINTTALK, format("Set the permission level of the player %s to %d.", networkid, level));
                }
                SaveChatCmdConfig();
            }.bindenv(ctx),
            positionalArgs = ["nid", "l"],
            permissionLevel = TopPermissionLevel
        })
    );
}

local eventCallbacks = {
    OnGameEvent_player_say = function(params)
    {
        local playerEnt = null;
        try
        {
            local parsingResult = ParseChatCmd(params.text);
            //test
            //if (parsingResult) __DumpScope(4, parsingResult);
            if (parsingResult)
            {
                playerEnt = GetPlayerFromUserID(params.userid);
                if (playerEnt == GetListenServerHost())
                {
                    local level = GetPlayerChatCmdPermissionLevel(playerEnt);
                    if (level < TopPermissionLevel)
                    {
                        SetPlayerChatCmdPermissionLevel(playerEnt.GetNetworkIDString(), TopPermissionLevel);
                        SaveChatCmdConfig();
                    }
                }
                if (!ExecuteCmd(playerEnt, parsingResult.name, parsingResult.argTable))
                {
                    local plevel = GetPlayerChatCmdPermissionLevel(playerEnt.GetNetworkIDString());
                    local clevel = GetChatCmdActualPermissionLevel(parsingResult.name);
                    ClientPrint(playerEnt, DirectorScript.HUD_PRINTTALK, format("Failure to execute.\nYour permission level(%d) is lower than that of this command(%d).", plevel, clevel));
                }
            }
        }
        catch (e)
        {
            playerEnt = GetPlayerFromUserID(params.userid);
            ClientPrint(playerEnt, DirectorScript.HUD_PRINTTALK, "Error:\n" + e);
        }
    }.bindenv(ctx)
}

local function InitChatListener()
{
    ::KtScript.RegisterEventCallbacks(ctx, eventCallbacks);
}

function InitChatCmdSystem()
{
    InitConfig();
    InitBuiltInCmd();
    InitChatListener();
}

