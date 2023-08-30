local _ctx = this;

enum ErrorType
{
    GameAlreadyActive,
    GameNotActive,
    RoundAlreadyRunning,
    NoPlayer,
    CardNotEnough,
    InvalidCardTimes,
    ChangePlayerDuringGame
}

enum PlayCardResult
{
    Successful,
    Win,
    Invalid,
    NotEnough,
    NotMatch,
    NotHigher
}

enum CardBombLevel
{
    Repeat = 1
}

enum CardCompareResult
{
    NotMatch,
    Equal,
    Lower,
    Higher
}

_debugMode <- false;

BombSoundName <- "GrenadeLauncher.Explode";

_localText <- {
    english = {},
    schinese = {}
};

function LoadLocalText()
{
    IncludeScript("ktscript/runfast_cardgame/i18n/text_english", _localText.english);
    IncludeScript("ktscript/runfast_cardgame/i18n/text_schinese", _localText.schinese);
}

function GetLocalTextByLanguage(language, name)
{
    if (language == null || !(language in _localText))
    {
        language = "english";
    }
    local textTable = _localText[language];
    if (name in textTable)
    {
        return textTable[name];
    }
    else
    {
        return "(" + name + ")";
    }
}

function GetLocalText(name, player)
{
    local language = Convars.GetClientConvarValue("cl_language", player.GetEntityIndex());
    return GetLocalTextByLanguage(language, name);
}

_cardEnum <- [
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13,
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13,
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13,
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
];

_cardCharToNum <- {
    ["3"[0]] = 1,
    ["4"[0]] = 2,
    ["5"[0]] = 3,
    ["6"[0]] = 4,
    ["7"[0]] = 5,
    ["8"[0]] = 6,
    ["9"[0]] = 7,
    ["t"[0]] = 8,
    ["j"[0]] = 9,
    ["q"[0]] = 10,
    ["k"[0]] = 11,
    ["a"[0]] = 12,
    ["2"[0]] = 13,
};

_cardNumToChar <- {};

foreach (key, val in _cardCharToNum)
{
    _cardNumToChar[val] <- key;
}

function GetNextLevelCard(cardNum)
{
    cardNum++;
    if (cardNum > 13)
    {
        cardNum = 1;
    }
    return cardNum;
}

function GetPreviousLevelCard(cardNum)
{
    cardNum--;
    if (cardNum < 1)
    {
        cardNum = 13;
    }
    return cardNum;
}

function IntToCardCompareResult(n)
{
    if (n < 0)
    {
        return CardCompareResult.Lower;
    }
    else if (n > 0)
    {
        return CardCompareResult.Higher;
    }
    else
    {
        return CardCompareResult.Equal;
    }
}

class CardPattern
{
    //NOTE: Bombs can be different pattern but can be always compared.

    function IsSamePattern(pattern)
    {
        return getclass() == pattern.getclass();
    }

    function IsBomb()
    {
        return false;
    }

    function GetBombLevel()
    {
        return null;
    }

    function CompareWhenSamePattern(pattern)
    {
        return 0;
    }

    function CompareWhenBomb(pattern)
    {
        return 0;
    }

    //return CardCompareResult enum
    function Compare(pattern)
    {
        local IntToCardCompareResult = _ctx.IntToCardCompareResult;
        if (IsBomb() && pattern.IsBomb())
        {
            local result = GetBombLevel() <=> pattern.GetBombLevel();
            if (result != 0)
            {
                return IntToCardCompareResult(result);
            }
            return IntToCardCompareResult(CompareWhenBomb(pattern));
        }
        else if (IsBomb() && !pattern.IsBomb())
        {
            return CardCompareResult.Higher;
        }
        else if (!IsBomb() && pattern.IsBomb())
        {
            return CardCompareResult.Lower;
        }
        else
        {
            if (IsSamePattern(pattern))
            {
                return IntToCardCompareResult(CompareWhenSamePattern(pattern));
            }
            else
            {
                return CardCompareResult.NotMatch;
            }
        }
    }

    function GetCards()
    {
        return [];
    }

    function ToString()
    {
        return "";
    }
}

class SingleCardPattern extends CardPattern
{
    _num = null;

    constructor(num)
    {
        _num = num;
    }

    function CompareWhenSamePattern(pattern)
    {
        return _num <=> pattern._num;
    }

    function GetCards()
    {
        return [_num];
    }

    function ToString()
    {
        return format("num = %d", _num);
    }
}

/**
 * example:
 * 33
 * 333
 * 3344
 * 444555
 */
class StraightRepeatCardPattern extends CardPattern
{
    _repeatCount = null;
    _length = null;
    _startNum = null;

    constructor(repeatCount, length, startNum)
    {
        _repeatCount = repeatCount;
        _length = length;
        _startNum = startNum;
    }

    function IsBomb()
    {
        return _repeatCount >= 4;
    }

    function GetBombLevel()
    {
        return CardBombLevel.Repeat;
    }

    function CompareWhenSamePattern(pattern)
    {
        return _startNum <=> pattern._startNum;
    }

    function CompareWhenBomb(pattern)
    {
        local result = _repeatCount <=> pattern._repeatCount;
        if (result != 0)
        {
            return result;
        }
        result = _length <=> pattern._length;
        if (result != 0)
        {
            return result;
        }
        result = _startNum <=> pattern._startNum;
        return result;
    }

    function GetCards()
    {
        local cards = [];
        local nextNum = _startNum;
        for (local i = 0; i < _length; i++)
        {
            for (local j = 0; j < _repeatCount; j++)
            {
                cards.append(nextNum);
            }
            nextNum = GetNextLevelCard(nextNum);
        }
        return cards;
    }

    function IsSamePattern(pattern)
    {
        if (pattern instanceof _ctx.StraightRepeatCardPattern)
        {
            return _repeatCount == pattern._repeatCount && _length == pattern._length;
        }
        return false;
    }

    function ToString()
    {
        return format("repeatCount = %d, length = %d, startNum = %d", _repeatCount, _length, _startNum);
    }
}

class ThreeWithOneOrTwoPattern extends CardPattern
{
    _mainCard = null;
    _extraCard1 = null;
    _extraCard2 = null;

    constructor(mainCard, extraCard1, extraCard2)
    {
        _mainCard = mainCard;
        _extraCard1 = extraCard1;
        _extraCard2 = extraCard2;
    }

    function CompareWhenSamePattern(pattern)
    {
        return _mainCard <=> pattern._mainCard;
    }

    function IsSamePattern(pattern)
    {
        if (pattern instanceof _ctx.ThreeWithOneOrTwoPattern)
        {
            if (_extraCard2 == null)
            {
                return pattern._extraCard2 == null;
            }
            else
            {
                return pattern._extraCard2 != null;
            }
        }
        return false;
    }

    function GetCards()
    {
        local cards = [];
        for (local i = 0; i < 3; i++)
        {
            cards.append(_mainCard);
        }
        cards.append(_extraCard1);
        if (_extraCard2 != null)
        {
            cards.append(_extraCard2);
        }
        return cards;
    }
}

/**
 * A card pattern matcher is a function: CardPattern <- function(array cards)
 */
_cardPatternMatchers <- [
    //single pattern
    function(cards)
    {
        if (cards.len() == 1)
        {
            return SingleCardPattern(cards[0]);
        }
        return null;
    }.bindenv(_ctx),
    //straight pattern
    function(cards)
    {
        local minCard = cards[0];
        foreach (card in cards)
        {
            if (card < minCard)
            {
                minCard = card;
            }
        }

        //The key is card and the value is the occurrence number of the card.
        local cardCounter = {};
        foreach (card in cards)
        {
            if (!(card in cardCounter))
            {
                cardCounter[card] <- 0;
            }
            cardCounter[card]++;
        }

        local repeatCount = null;
        foreach (card, count in cardCounter)
        {
            if (repeatCount == null)
            {
                repeatCount = count;
            }
            else
            {
                if (count != repeatCount)
                {
                    return null;
                }
            }
        }

        local cardTypeNum = cardCounter.len();
        local nextCard = minCard;
        local canMatch = true;
        for (local i = 1; i <= cardTypeNum; i++)
        {
            if (!(nextCard in cardCounter))
            {
                canMatch = false;
                break;
            }
            if (i != cardTypeNum)
            {
                nextCard++;
                if (nextCard > 13)
                {
                    canMatch = false;
                    break;
                }
            }
        }

        local startCard = minCard;
        if (!canMatch)
        {
            local cardA = CardCharToNum("a"[0]);
            nextCard = cardA;
            for (local i = 1; i <= cardTypeNum; i++)
            {
                if (!(nextCard in cardCounter))
                {
                    return null;
                }
                nextCard = GetNextLevelCard(nextCard);
            }
            startCard = cardA;
        }

        if (repeatCount == 1)
        {
            if (cardTypeNum < 5)
            {
                return null;
            }
        }

        return StraightRepeatCardPattern(repeatCount, cardTypeNum, startCard);
    }.bindenv(_ctx),
    //3 with 1 or 2 pattern
    function(cards)
    {
        local count = cards.len();
        if (count != 4 && count != 5)
        {
            return null;
        }

        //The key is card and the value is the occurrence number of the card.
        local cardCounter = {};
        foreach (card in cards)
        {
            if (!(card in cardCounter))
            {
                cardCounter[card] <- 0;
            }
            cardCounter[card]++;
        }

        local mainCard = null;
        foreach (card, count in cardCounter)
        {
            if (count == 3)
            {
                mainCard = card;
                break;
            }
        }
        if (mainCard == null)
        {
            return null;
        }

        local extraCard1 = null;
        local extraCard2 = null;
        foreach (card, count in cardCounter)
        {
            if (card != mainCard)
            {
                if (extraCard1 == null)
                {
                    extraCard1 = card;
                    if (count == 2)
                    {
                        extraCard2 = card;
                    }
                }
                else
                {
                    extraCard2 = card;
                }
            }
        }

        return ThreeWithOneOrTwoPattern(mainCard, extraCard1, extraCard2);
    }.bindenv(_ctx)
];

class CardList
{
    _cardCounter = null;

    constructor()
    {
        _cardCounter = {};
    }

    function AddCard(card)
    {
        if (!(card in _cardCounter))
        {
            _cardCounter[card] <- 0;
        }
        _cardCounter[card]++;
    }

    function RemoveCards(cards)
    {
        foreach (card in cards)
        {
            if (card in _cardCounter)
            {
                _cardCounter[card]--;
                if (_cardCounter[card] <= 0)
                {
                    delete _cardCounter[card];
                }
            }
        }
    }

    function IsEnoughToPlay(cards)
    {
        local cardList = _ctx.CardList();
        foreach (card in cards)
        {
            cardList.AddCard(card);
        }
        local counter = cardList._cardCounter;
        foreach (card, count in counter)
        {
            if (card in _cardCounter)
            {
                if (count <= _cardCounter[card])
                {
                    continue;
                }
            }
            return false;
        }
        return true;
    }

    function GetString()
    {
        local cards = GetCards();
        return _ctx.CardsToString(cards);
    }

    function GetCards()
    {
        local cards = [];
        foreach (card, count in _cardCounter)
        {
            for (local i = 0; i < count; i++)
            {
                cards.append(card);
            }
        }
        return cards;
    }

    function IsEmpty()
    {
        return _cardCounter.len() == 0;
    }

    function GetCount()
    {
        local result = 0;
        foreach (card, count in _cardCounter)
        {
            result += count;
        }
        return result;
    }
}


_isCardgameActive <- false;

_isCardgameRoundRunning <- false;

_roundCount <- 0;

_cardTimes <- null;

_cardgamePlayers <- [];

//The key is player index and the value is CardList instance.
_playerCards <- {};

//The player index that played cards lastly.
_lastPlayerIndex <- null;

_nextTurnIndex <- null;

_lastWinnerIndex <- null;

//CardPattern instance
_lastPlayedCards <- null;

//The key is player and the value is integer of score.
_playerScores <- {};

function MatchCardPattern(cards)
{
    foreach (matcher in _cardPatternMatchers)
    {
        local pattern = matcher(cards);
        if (pattern)
        {
            return pattern;
        }
    }
    return null;
}

function CardCharToNum(c)
{
    return _cardCharToNum[c];
}

function CardNumToChar(num)
{
    return _cardNumToChar[num];
}

function CardsToString(cards)
{
    cards = clone cards;
    cards.sort();
    local str = "";
    foreach (card in cards)
    {
        local cardStr = CardNumToChar(card).tochar();
        str += cardStr;
    }
    return str.toupper();
}

function TryGetCardsFromString(str)
{
    str = str.tolower();
    local l = str.len();
    local cards = [];
    for (local i = 0; i < l; i++)
    {
        local c = str[i];
        if (c in _cardCharToNum)
        {
            cards.append(_cardCharToNum[c]);
        }
        else
        {
            return null;
        }
    }
    return cards;
}

function FindPlayerIndex(player)
{
    return _cardgamePlayers.find(player);
}

function GetRandomPlayerIndex()
{
    return RandomInt(0, _cardgamePlayers.len() - 1);
}

function GetNextPlayerIndex(idx)
{
    idx++;
    if (idx >= _cardgamePlayers.len())
    {
        idx = 0;
    }
    return idx;
}

function ClearInvalidPlayers()
{
    for (local i = 0; i < _cardgamePlayers.len();)
    {
        local player = _cardgamePlayers[i];
        if (!player.IsValid())
        {
            _cardgamePlayers.remove(i);
            continue;
        }
        i++;
    }
}

function CardgameAddPlayer(player)
{
    if (_isCardgameActive)
    {
        throw ErrorType.ChangePlayerDuringGame;
    }
    _cardgamePlayers.append(player);
}

function CardgameRemovePlayer(player)
{
    if (_isCardgameActive)
    {
        throw ErrorType.ChangePlayerDuringGame;
    }
    local idx = _cardgamePlayers.find(player);
    if (idx != null)
    {
        _cardgamePlayers.remove(idx);
    }
}

function StartCardgame(cardTimes = 1)
{
    ClearGameData();
    if (_isCardgameActive)
    {
        throw ErrorType.GameAlreadyActive;
    }
    if (_cardgamePlayers.len() == 0)
    {
        throw ErrorType.NoPlayer;
    }
    if (cardTimes < 1)
    {
        throw ErrorType.InvalidCardTimes;
    }
    _cardTimes = cardTimes;
    _isCardgameActive = true;
    foreach (idx, player in _cardgamePlayers)
    {
        _playerScores[idx] <- 0;
    }
}

function StopCardgame()
{
    if (!_isCardgameActive)
    {
        return;
    }
    ClearGameData();
}

function ClearGameData()
{
    ClearRoundData();
    _isCardgameActive = false;
    ClearInvalidPlayers();
    //_cardgamePlayers.clear();
    _lastWinnerIndex = null;
    _playerScores.clear();
    _roundCount = 0;
}

function StartCardgameRound()
{
    ClearRoundData();
    if (!_isCardgameActive)
    {
        throw ErrorType.GameNotActive;
    }
    if (_isCardgameRoundRunning)
    {
        throw ErrorType.RoundAlreadyRunning;
    }
    _isCardgameRoundRunning = true;

    _nextTurnIndex = _lastWinnerIndex;
    if (_nextTurnIndex == null)
    {
        _nextTurnIndex = GetRandomPlayerIndex();
    }

    local cards = [];
    for (local i = 0; i < _cardTimes; i++)
    {
        cards.extend(_cardEnum);
    }

    local nextPlayerIndex = _nextTurnIndex;
    while (cards.len() > 0)
    {
        local idx = RandomInt(0, cards.len() - 1);
        local card = cards[idx];
        cards.remove(idx);
        if (!(nextPlayerIndex in _playerCards))
        {
            _playerCards[nextPlayerIndex] <- CardList();
        }
        _playerCards[nextPlayerIndex].AddCard(card);
        nextPlayerIndex = GetNextPlayerIndex(nextPlayerIndex);
    }
    if (_playerCards.len() != _cardgamePlayers.len())
    {
        ClearRoundData();
        throw ErrorType.CardNotEnough;
    }
    _roundCount++;
}

function ClearRoundData()
{
    _isCardgameRoundRunning = false;
    _playerCards.clear();
    _nextTurnIndex = null;
    _lastPlayerIndex = null;
    _lastPlayedCards = null;
}

function ForceStopRound()
{
    if (!_isCardgameRoundRunning)
    {
        return;
    }
    ClearRoundData();
}

/**
 * return a table:
 * {
 *      PlayerCardResult resultType;
 *      CardPattern cardPattern;
 * }
 */
function PlayCards(cards)
{
    local result = {
        resultType = null,
        cardPattern = null
    };
    local cardList = _playerCards[_nextTurnIndex];
    if (!cardList.IsEnoughToPlay(cards))
    {
        result.resultType = PlayCardResult.NotEnough;
        return result;
    }
    local cardPattern = MatchCardPattern(cards);
    if (cardPattern == null)
    {
        result.resultType = PlayCardResult.Invalid;
        return result;
    }
    if (_lastPlayerIndex != null && _lastPlayerIndex != _nextTurnIndex)
    {
        local compareResult = cardPattern.Compare(_lastPlayedCards);
        if (compareResult == CardCompareResult.NotMatch)
        {
            result.resultType = PlayCardResult.NotMatch;
            return result;
        }
        else if (compareResult != CardCompareResult.Higher)
        {
            result.resultType = PlayCardResult.NotHigher;
            return result;
        }
    }

    result.cardPattern = cardPattern;
    if (_debugMode)
    {
        printl(format("Played card pattern:\n%s", cardPattern.ToString()));
    }
    cardList.RemoveCards(cards);
    if (cardList.IsEmpty())
    {
        _lastWinnerIndex = _nextTurnIndex;
        local newScore = 0;
        foreach (idx, player in _cardgamePlayers)
        {
            if (idx != _nextTurnIndex)
            {
                local cardCount = _playerCards[idx].GetCount();
                _playerScores[idx] -= cardCount;
                newScore -= _playerScores[idx];
            }
        }
        _playerScores[_nextTurnIndex] = newScore;
        ClearRoundData();
        result.resultType = PlayCardResult.Win;
        return result;
    }
    _lastPlayedCards = cardPattern;
    _lastPlayerIndex = _nextTurnIndex;
    _nextTurnIndex = GetNextPlayerIndex(_nextTurnIndex);
    result.resultType = PlayCardResult.Successful;
    return result;
}

function DiscardTurn()
{
    _nextTurnIndex = GetNextPlayerIndex(_nextTurnIndex);
}

function PrintTurnMessage()
{
    local player = _cardgamePlayers[_nextTurnIndex];
    PrintTalkLocal("player_turn_notice", null, @(s) format(s, player.GetPlayerName()));
    PrintTalkLocal("your_turn_notice", player, @(s) format(s, _playerCards[_nextTurnIndex].GetString()));
}

function PrintScores()
{
    PrintTalkLocal("scores_list_title");
    local scores = [];
    foreach (idx, score in _playerScores)
    {
        local player = _cardgamePlayers[idx];
        scores.append([score, player]);
    }
    scores.sort(@(a, b) -(a[0] <=> b[0]));
    foreach (item in scores)
    {
        PrintTalk(format("%s: %d", item[1].GetPlayerName(), item[0]));
    }
}

function PrintTalk(text, player = null)
{
    ClientPrint(player, DirectorScript.HUD_PRINTTALK, "\x04" + text);
}

function PrintTalkLocal(textName, player = null, postProc = null)
{
    if (player == null)
    {
        local players = ::KtScript.AllPlayers(true);
        foreach (p in players)
        {
            local text = GetLocalText(textName, p);
            PrintTalk(postProc == null ? text : postProc(text), p);
        }
    }
    else
    {
        local text = GetLocalText(textName, player);
        PrintTalk(postProc == null ? text : postProc(text), player);
    }
}

function OnPlayerSay(player, text)
{
    if (_isCardgameRoundRunning)
    {
        local currentTurnPlayer = _cardgamePlayers[_nextTurnIndex];
        if (player == currentTurnPlayer)
        {
            if (text == "x")
            {
                PrintTalkLocal("turn_discard_notice", null, @(s) format(s, player.GetPlayerName()));
                DiscardTurn();
                PrintTurnMessage();
            }
            else
            {
                local cards = TryGetCardsFromString(text);
                if (cards)
                {
                    local playerIndex = _nextTurnIndex;
                    local result = PlayCards(cards);
                    local resultType = result.resultType;
                    local cardPattern = result.cardPattern;
                    if (resultType == PlayCardResult.Successful || resultType == PlayCardResult.Win)
                    {
                        if (cardPattern.IsBomb())
                        {
                            EmitSoundOn(BombSoundName, player);
                        }
                        PrintTalkLocal("play_card_notice", null, @(s) format(s, player.GetPlayerName(), CardsToString(cards), cardPattern.IsBomb() ? "BOMB!" : ""));
                        if (resultType == PlayCardResult.Successful)
                        {
                            local cardList = _playerCards[playerIndex];
                            PrintTalkLocal("your_card_notice", player, @(s) format(s, cardList.GetString()));
                            if (cardList.GetCount() == 1)
                            {
                                PrintTalkLocal("one_card_left_notice", null, @(s) format(s, player.GetPlayerName()));
                            }
                            PrintTurnMessage();
                        }
                        else
                        {
                            PrintTalkLocal("round_win_notice", null, @(s) format(s, player.GetPlayerName()));
                            PrintScores();
                        }
                    }
                    else if (resultType == PlayCardResult.Invalid)
                    {
                        PrintTalkLocal("invalid_play", player);
                    }
                    else if (resultType == PlayCardResult.NotEnough)
                    {
                        PrintTalkLocal("not_enough_to_play", player);
                    }
                    else if (resultType == PlayCardResult.NotMatch)
                    {
                        PrintTalkLocal("not_match_last_play", player);
                    }
                    else if (resultType == PlayCardResult.NotHigher)
                    {
                        PrintTalkLocal("not_higher_last_play", player);
                    }
                }
            }
        }
    }
}

local _eventCallbacks = {
    OnGameEvent_player_say = function(params) {
        local player = GetPlayerFromUserID(params.userid);
        local text = params.text;
        OnPlayerSay(player, text);
    }.bindenv(_ctx)
}

function InitChatCmds()
{
    ::KtScript.AddChatCmd(::KtScript.ChatCmd({
        name = "runfast_start",
        args = [
            ::KtScript.ChatCmdArg({
                name = "cardtimes",
                isOptional = true,
                expectedType = "integer",
                defaultValue = 1
            })
        ],
        action = function(player, argTable) {
            local cardTimes = argTable.cardtimes;
            try
            {
                StartCardgame(cardTimes);
                PrintTalkLocal("game_start_notice");
            }
            catch (exception)
            {
                if (exception == ErrorType.GameAlreadyActive)
                {
                    PrintTalk("The cardgame is already active!");
                }
                else if (exception == ErrorType.NoPlayer)
                {
                    PrintTalk("Couldn't start cardgame Runfast because there is no player!");
                }
                else if (exception == ErrorType.InvalidCardTimes)
                {
                    PrintTalk("Invalid card times!");
                }
                else
                {
                    error(exception);
                }
            }
        }.bindenv(_ctx),
        positionalArgs = ["cardtimes"],
        permissionLevel = 0
    }));

    ::KtScript.AddChatCmd(::KtScript.ChatCmd({
        name = "runfast_stop",
        args = [],
        action = function(player, argTable) {
            try
            {
                StopCardgame();
                PrintTalkLocal("game_stop_notice")
            }
            catch (exception)
            {
                error(exception);
            }
        }.bindenv(_ctx),
        positionalArgs = [],
        permissionLevel = 0
    }));

    ::KtScript.AddChatCmd(::KtScript.ChatCmd({
        name = "runfast_join",
        args = [
            ::KtScript.ChatCmdArg({
                name = "allowsame",
                isOptional = true,
                expectedType = "integer",
                defaultValue = 0
            })
        ],
        action = function(player, argTable) {
            try
            {
                if (argTable.allowsame == 0)
                {
                    if (FindPlayerIndex(player) != null)
                    {
                        PrintTalkLocal("you_already_ingame", player);
                        return;
                    }
                }
                CardgameAddPlayer(player);
                PrintTalkLocal("player_join_notice", null, @(s) format(s, player.GetPlayerName()));
            }
            catch (exception)
            {
                if (exception == ErrorType.ChangePlayerDuringGame)
                {
                    PrintTalkLocal("cant_change_player");
                }
                else
                {
                    error(exception);
                }
            }
        }.bindenv(_ctx),
        positionalArgs = [],
        permissionLevel = 0
    }));

    ::KtScript.AddChatCmd(::KtScript.ChatCmd({
        name = "runfast_leave",
        args = [],
        action = function(player, argTable) {
            try
            {
                CardgameRemovePlayer(player);
                PrintTalkLocal("player_leave_notice", null, @(s) format(s, player.GetPlayerName()));
            }
            catch (exception)
            {
                if (exception == ErrorType.ChangePlayerDuringGame)
                {
                    PrintTalkLocal("cant_change_player");
                }
                else
                {
                    error(exception);
                }
            }
        }.bindenv(_ctx),
        positionalArgs = [],
        permissionLevel = 0
    }));

    ::KtScript.AddChatCmd(::KtScript.ChatCmd({
        name = "runfast_start_round",
        args = [],
        action = function(player, argTable) {
            try
            {
                StartCardgameRound();

                PrintTalkLocal("round_start_notice", null, @(s) format(s, _roundCount));
                foreach (idx, player in _cardgamePlayers)
                {
                    PrintTalkLocal("your_card_notice", player, @(s) format(s, _playerCards[idx].GetString()));
                }

                PrintTurnMessage();
            }
            catch (exception)
            {
                if (exception == ErrorType.RoundAlreadyRunning)
                {
                    PrintTalk("The game round is already running!");
                }
                else if (exception == ErrorType.CardNotEnough)
                {
                    PrintTalk("Not enough cards for all players. Try to change card times!");
                }
                else if (exception == ErrorType.GameNotActive)
                {
                    PrintTalk("The game hasn't started yet! Please type runfast_start");
                }
                else
                {
                    error(exception);
                }
            }
        }.bindenv(_ctx),
        positionalArgs = [],
        permissionLevel = 0
    }));

    ::KtScript.AddChatCmd(::KtScript.ChatCmd({
        name = "runfast_print_scores",
        args = [],
        action = function(player, argTable) {
            if (_isCardgameActive)
            {
                PrintScores();
            }
            else
            {
                PrintTalk("No score because the game isn't active.");
            }
        }.bindenv(_ctx),
        positionalArgs = [],
        permissionLevel = 0
    }));

    ::KtScript.AddChatCmd(::KtScript.ChatCmd({
        name = "runfast_print_cards",
        args = [],
        action = function(player, argTable) {
            if (_isCardgameRoundRunning)
            {
                local playerIndex = FindPlayerIndex(player);
                if (playerIndex != null)
                {
                    local cardList = _playerCards[playerIndex];
                    PrintTalkLocal("your_card_notice", player, @(s) format(s, cardList.GetString()));
                    return;
                }
            }
            PrintTalk("None", player);
        }.bindenv(_ctx),
        positionalArgs = [],
        permissionLevel = 0
    }));

    ::KtScript.AddChatCmd(::KtScript.ChatCmd({
        name = "runfast_print_players",
        args = [],
        action = function(player, argTable) {
            PrintTalkLocal("player_list_title");
            local i = 0;
            foreach (p in _cardgamePlayers)
            {
                if (p.IsValid())
                {
                    i++;
                    PrintTalk(format("%d.%s (%s)", i, p.GetPlayerName(), p.GetNetworkIDString()));
                }
            }
        }.bindenv(_ctx),
        positionalArgs = [],
        permissionLevel = 0
    }));

    ::KtScript.AddChatCmd(::KtScript.ChatCmd({
        name = "runfast_round_force_stop",
        args = [],
        action = function(player, argTable) {
            ForceStopRound();
            PrintTalkLocal("round_force_stop");
        }.bindenv(_ctx),
        positionalArgs = [],
        permissionLevel = 0
    }));

    ::KtScript.AddChatCmd(::KtScript.ChatCmd({
        name = "runfast_clear_players",
        args = [],
        action = function(player, argTable) {
            if (_isCardgameActive)
            {
                PrintTalkLocal("cant_change_player");
                return;
            }
            _cardgamePlayers.clear();
            PrintTalk("Clear cardgame players successfully!");
        }.bindenv(_ctx),
        positionalArgs = [],
        permissionLevel = 0
    }));

    ::KtScript.AddChatCmd(::KtScript.ChatCmd({
        name = "runfast_help",
        args = [
            ::KtScript.ChatCmdArg({
                name = "pub",
                isOptional = true,
                expectedType = "integer",
                defaultValue = 0
            })
        ],
        action = function(player, argTable) {
            PrintTalkLocal("help", argTable.pub != 0 ? null : player);
        }.bindenv(_ctx),
        positionalArgs = [],
        permissionLevel = 0
    }));

    ::KtScript.AddChatCmd(::KtScript.ChatCmd({
        name = "runfast_help_admin",
        args = [
            ::KtScript.ChatCmdArg({
                name = "pub",
                isOptional = true,
                expectedType = "integer",
                defaultValue = 0
            })
        ],
        action = function(player, argTable) {
            PrintTalkLocal("help_admin", argTable.pub != 0 ? null : player);
        }.bindenv(_ctx),
        positionalArgs = [],
        permissionLevel = 0
    }));

    // ::KtScript.AddChatCmd(::KtScript.ChatCmd({
    //     name = "runfast_kick",
    //     args = [
    //         ::KtScript.ChatCmdArg({
    //             name = "netid",
    //             isOptional = false,
    //             expectedType = "string",
    //             defaultValue = ""
    //         })
    //     ],
    //     action = function(player, argTable) {

    //     }.bindenv(_ctx),
    //     positionalArgs = ["netid"],
    //     permissionLevel = 4
    // }));
}

function Init()
{
    LoadLocalText();
    ::KtScript.RegisterEventCallbacks(_ctx, _eventCallbacks);
    InitChatCmds();
}