/*
Author: KtOrangeeK
Version: 1
*/

local indentStr = "    ";

local function GetIndentString(depth)
{
    local result = "";
    for (local i = 0; i < depth; i++)
    {
        result += indentStr;
    }
    return result;
}

local function IsPrimitive(valType)
{
    return valType == "integer" || valType == "float" || valType == "bool" || valType == "null";
}

local function SerializePrimitive(val)
{
    return "" + val;
}

local identifierRegexp = regexp(@"^[\a_]\w*$");

local function IsValidIdentifierString(str)
{
    return identifierRegexp.match(str);
}

// local function SerializeArray(val)
// {

// }
local InternalSerializeTable = null;
//return serialized string of table
InternalSerializeTable = function(table, depth)
{
    local result = "";
    local indent1 = GetIndentString(depth - 1);
    local indent2 = GetIndentString(depth);
    result += "{\n";
    foreach (key, val in table)
    {
        local line = indent2;
        local keyType = typeof key;
        if (keyType == "string")
        {
            local keyStr = null;
            if (IsValidIdentifierString(key))
            {
                keyStr = key;
            }
            else
            {
                keyStr = "[" + @"""" + key + @"""" + "]";
            }
            line += keyStr + " = ";
            local valType = typeof val;
            if (IsPrimitive(valType))
            {
                line += SerializePrimitive(val);
            }
            else if (valType == "table")
            {
                line += InternalSerializeTable(val, depth + 1);
            }
            else
            {
                throw "Invalid value type: " + valType;
            }
            line += "\n";
            result += line;
        }
        else
        {
            throw "Invalid key type: " + keyType;
        }
    }
    result += indent1 + "}";
    return result;
}

function SerializeTable(table)
{
    return InternalSerializeTable(table, 1);
}

function DeserializeTable(tableStr)
{
    return compilestring("return " + tableStr)();
}

function TableToFile(table, path)
{
    local old = FileToString(path);
    if (old)
    {
        StringToFile(path + ".backup", old);
    }
    local tableStr = SerializeTable(table);
    StringToFile(path, tableStr);
}

function FileToTable(path)
{
    local tableStr = FileToString(path);
    if (!tableStr)
    {
        return null;
    }
    return DeserializeTable(tableStr);
}