local rt = getroottable();
if (!("KtScript" in rt))
{
    ::KtScript <- {};
    IncludeScript("ktscript/base/task_system/init");
    IncludeScript("ktscript/base/event_callback_system/init");
    IncludeScript("ktscript/base/utils/init");
    IncludeScript("ktscript/base/serialization_system/init");
    IncludeScript("ktscript/base/chatcmd_system/init");
}
::KtScript._TryCollectEventCallbacks();
::KtScript._TaskSystemOnImport();
