local _ctx = this;

TaskSystemThinkEntityName <- "ktscript_tasksystem_think";

/**
 * task action function return value:
 * return null: no effect
 * >= 0: next delay
 * < 0: kill task
 */
class Task
{
    _action = null;
    _delay = null;
    _repeat = null;
    _dead = false;
    _timer = 0.0;

    constructor(action, delay, repeat = false)
    {
        _action = action;
        _delay = delay;
        _repeat = repeat;
    }

    function GetAction()
    {
        return _action;
    }

    function GetDelay()
    {
        return _delay;
    }
    function SetDelay(delay)
    {
        _delay = delay;
    }

    function IsRepeat()
    {
        return _repeat;
    }

    function IsDead()
    {
        return _dead;
    }

    function Kill()
    {
        _dead = true;
    }

    function Submit()
    {
        local tasks = ::KtScript._taskSystemTasks;
        tasks.append(this);
    }
}

_taskSystemThinkEntity <- null;

_taskSystemTasks <- [];

_taskSystemLastTime <- 0.0;

function _TaskSystemThink()
{
    local currentTime = Time();
    local deltaTime = currentTime - _ctx._taskSystemLastTime;
    _ctx._taskSystemLastTime = currentTime;
    local tasks = _ctx._taskSystemTasks;
    for (local i = 0; i < tasks.len();)
    {
        local task = tasks[i];
        if (task.IsDead())
        {
            tasks.remove(i);
            continue;
        }
        task._timer += deltaTime;
        if (task._timer >= task.GetDelay())
        {
            local result = null;
            try
            {
                result = task.GetAction()();
            }
            catch (e)
            {
                printl(e);
            }
            local taskDead = null;
            if (task.IsRepeat())
            {
                taskDead = false;
                try
                {
                    if (result != null)
                    {
                        if (result < 0)
                        {
                            taskDead = true;
                        }
                        else
                        {
                            task.SetDelay(result);
                        }
                    }
                }
                catch(e)
                {

                }
            }
            else
            {
                taskDead = true;
            }
            if (taskDead)
            {
                task._dead = true;
                tasks.remove(i);
                continue;
            }
            else
            {
                task._timer = 0.0;
            }
        }
        i++;
    }
    return 0.0;
}

function _TaskSystemTryCreateThinkEntity()
{
    if (!("KtScript" in g_RoundState))
    {
        g_RoundState.KtScript <- {};
    }
    local scope = g_RoundState.KtScript;
    local id = "taskSystemThinkEntityCreated";
    if (!(id in scope))
    {
        _taskSystemThinkEntity = SpawnEntityFromTable("info_target", {targetname = TaskSystemThinkEntityName});
        printl("[KtScript] Task system think entity has been created!");
        _taskSystemThinkEntity.ValidateScriptScope();
        local entScope = _taskSystemThinkEntity.GetScriptScope();
        entScope._ThinkFunc <- _TaskSystemThink;
        AddThinkToEnt(_taskSystemThinkEntity, "_ThinkFunc");
        scope[id] <- true;
    }
}

function _TaskSystemOnImport()
{
    _taskSystemTasks.clear();
    _taskSystemLastTime = Time();
    _TaskSystemTryCreateThinkEntity();
}

// function InitTaskSystem()
// {

// }