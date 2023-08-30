IncludeScript("ktscript/base/import");
local ctxId = "RunfastCardgame";
local onlineId = ctxId + "Online";
if (!(onlineId in ::KtScript))
{
    ::KtScript[ctxId] <- {};
    IncludeScript("ktscript/runfast_cardgame/runfast_cardgame", ::KtScript[ctxId]);
    ::KtScript[ctxId].Init();
    ::KtScript[onlineId] <- true;
}