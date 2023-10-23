#Requires AutoHotkey v2.0
#Include CHROME.ahk
#Include UIA.ahk
CoordMode("ToolTip", "Screen")
SendMode("Event")

hour := 0, minute := 0, second := 0

voice := ComObject("SAPI.SpVoice")
voice.volume := 100
voice.voice := voice.GetVoices().Item(1)
voice.WaitUntilDone(-1)

timeout := Map(
    "toggle" ,   true,
    "initial",   0,
    "status" ,   "",
)

deluge := DelugeRPG()
deluge.settings["pokemon"]             := "|RETRO|NEGATIVE|CHROME|DARK|MIRAGE|SHINY|UNIQUEONLY|"
deluge.settings["map"]                 := "Overworld #6"
deluge.settings["trainer"]["url"]      := "/battle/trainer/352/inverse"
deluge.settings["player"]["username"]  := "S-Psychic"
deluge.settings["player"]["url"]       := "/battle/user/u/" . deluge.settings["player"]["username"]

SetTimer(StartTimer, 1000)

Loop {
    try {
        deluge.StartMacro()
        
        ; Sleep(deluge.delay["iteration"])
    } catch as e {
        MsgBox(e.message)
    }
}

StartTimer() {
    try {
        global deluge, hour, minute, second, timeout
        ; DELETE/STOP TIMER
        if (deluge.status = "STOP") {
            hour := 0, second := 0, minute := 0
            ToolTip()
            SetTimer(, 0)
            return
        }
        if not ConnectedToInternet() {
            deluge.status := "No Internet Connection. . ."
            Pause(true)
            Sleep(10000)
            Pause(false)
        }
        if (not A_IsPaused) {
            ; TIMEOUT
            if timeout["toggle"] {
                timeout["toggle"]  := false
                timeout["initial"] := A_TickCount
                timeout["status"]  := deluge.status
            } else if (timeout["status"] = deluge.status) {
                if (A_TickCount - timeout["initial"]) > 120000 {
                    MsgBox("Reloading Application!", "TIMEOUT", "T5 64")
                    Reload()
                }
            } else {
                timeout["toggle"]  := true
                timeout["initial"] := 0
                timeout["status"]  := ""
            }
            ; PROCEED NORMALLY
            if (InStr(deluge.url, "/map")) {
                ToolTip
                (
                    "Running Time: "      Format("{:02}", hour) ":" Format("{:02}", minute) ":" Format("{:02}", second)
                    "`nTotal Captured: "  deluge.count["pokemons"]
                    "`nLegendary Found: " deluge.count["legends"]
                    "`nUnique Found: "    deluge.count["uniques"]
                    "`nStatus: "          deluge.status 
                    , 5, 5
                )
            } else if (InStr(deluge.url, "/trainer") or InStr(deluge.url, "/battle")) {
                text := (InStr(deluge.url, "/trainer") ? "Trainer: " deluge.settings["trainer"]["title"] : "Player: " deluge.settings["player"]["username"])
                ToolTip
                (
                    "Running Time: "    Format("{:02}", hour) ":" Format("{:02}", minute) ":" Format("{:02}", second)
                    "`n"                text
                    "`nMoney Gained: $" deluge.count["money"]
                    "`nExp Gained: +"   deluge.count["exp"]
                    "`nStatus: "        deluge.status
                    , 5, 5
                )
            } else {
                ToolTip
                (
                    "Running Time: "    Format("{:02}", hour) ":" Format("{:02}", minute) ":" Format("{:02}", second)
                    "`nSettings: "      deluge.settings["pokemon"]
                    "`nCatpcha Count: " deluge.count["captcha"]
                    "`nStatus: "        deluge.status
                    , 5, 5
                )
            }
            if (second >= 59) {
                second := 0
                minute++
                if (minute >= 59) {
                    minute := 0
                    hour++
                }
            } else {
                second++
            }
        }
    }
    catch as e
    {
        MsgBox("Failed to start timer." e.message, "Error", 16)
    }
}

class DelugeRPG {
    ; ------------ START
    __New() {
        this.name   := "DelugeRPG"
        this.url    := "https://www.delugerpg.com/"
        this.alt    := "DelugeRPG Macro"
        this.hwnd   := ""
        this.client := ""
        this.size   := ""
        this.status := "Loaded. . ."

        MsgBox("Please close all chrome application before proceding.", , "T5 64")
        try {
            this.browser := Chrome(, "--app=`"" this.url "`"")
            if not WinWait(this.name " ahk_pid " this.browser.PID, , 5) {
                throw
            }
            this.hwnd   := WinGetID(this.name " ahk_pid " this.browser.PID)
            this.client := this.name " ahk_id " this.hwnd
            this.size   := GetWindowSize(this.client)
            this.page   := this.browser.GetPage()
            this.pageEl := UIA.ElementFromHandle(this.client)
            WinSetTitle(this.alt, this.client)
        } catch as e {
            MsgBox("Something went wrong while starting the application." e.message, "Error", 16)
            ExitApp
        }

        this.settings := Map(
            "pokemon", "|RETRO|NEGATIVE|CHROME|MIRAGE|SHADOW|DARK|GHOSTLY|METALLIC|SHINY|DARK|NORMAL|",
            "map"    , "",
            "trainer", Map("url", "", "title", ""),
            "player" , Map("url", "", "username", ""),
        )

        this.count := Map(
            "exp"     , 0,
            "money"   , 0,
            "pokemons", 0,
            "legends" , 0,
            "uniques" , 0,
            "captcha" , 0,
        )

        this.delay := Map(
            "iteration", 10,
            "mouse"    , 10,
            "scroll"   , 200,
        )

        this.pokemon := Map(
            "class"     , "",
            "name"      , "",
            "level"     , 0,
            "hp"        , 0,
            "type"      , ["", ""],
            "legend"    , true,
            "unique"    , true,
            "stats"     , 0,
        )

        this.directions := [
            "#dr-nw.m-move",
            "#dr-n.m-move",
            "#dr-ne.m-move",
            "#dr-w.m-move",
            "#dr-e.m-move",
            "#dr-sw.m-move",
            "#dr-s.m-move",
            "#dr-se.m-move",
        ]

        this.offset := Map(
            "button", 2,
            "y"     , this.size["control"]["y"],
            "top"   , this.size["control"]["y"] + 200,
            "bottom", this.size["client"]["height"] + this.size["control"]["y"] - 200,
        )
    }
    
    StartMacro() {
        this.url := ExecuteJS("document.URL", this.page, "value")
        url := InStr(this.url, "/map") ? "map"
            : InStr(this.url, "/catch") ? "catch"
                : InStr(this.url, "/trainer") ? "trainer"
                    : InStr(this.url, "/battle") ? "battle"
                        : InStr(this.url, "/unlock") ? "captcha"
                            : "default"
                        
        switch (url) {
            case "map":
                this.status := "Finding Pokemon. . ."
                this.delay["scroll"] := Rand(200, 300)
                this.FindPokemon()
            case "catch":
                this.status := "Catching Pokemon. . ."
                this.delay["scroll"] := Rand(200, 300)
                this.CatchPokemon()
            case "trainer":
                if InStr(this.url, "/trainers") {
                    this.status := "Selecting Trainer. . ."
                    this.delay["scroll"] := Rand(300, 400)
                    this.SelectTrainer()
                } else {
                    this.status := "Battling Trainer. . ."
                    this.delay["scroll"] := Rand(200, 300)
                    this.BattleTrainer()
                }
            case "battle":
                this.delay["scroll"] := Rand(200, 300)
                if InStr(this.url, "/battle/user/new") {
                    this.status := "Selecting Player. . ."
                    this.SelectPlayer()
                } else {
                    this.status := "Battling Player. . ."
                    this.BattlePlayer()
                }
            case "captcha":
                this.status := "Captcha Detected. . ."
                this.BypassCaptcha()
            default:
                this.status := "Idle. . ."
        }

        while not (size := GetWindowSize(this.client)) {
            Sleep(100)
        }
        if (WinGetTitle(this.client) != this.alt) {
            WinSetTitle(this.alt, this.client)
        }
        if (size["window"]["y"] != this.size["window"]["y"] or size["window"]["height"] != this.size["window"]["height"]) {

            if (size["window"]["width"] < 800 or size["window"]["height"] < 600)
                ResizeClient(1280, 720, this.client)

            this.offset["y"]      := size["control"]["y"]
            this.offset["top"]    := size["control"]["y"] + 200
            this.offset["bottom"] := size["client"]["height"] + size["control"]["y"] - 200
        }
        this.delay["mouse"]     := Rand(20, 40)
        this.delay["iteration"] := Rand(20, 40)
    }

    Navigate(parent, child) {
        ; HOVER
        script := 
        (
            "try {
                var element  = {selector: `"#" . parent . "`"} // holder
                var selector = document.querySelector(element.selector); // holder
                (async function() {
                    `"use strict`";

                    if (selector) {
                        element[`"location`"] = selector.getBoundingClientRect();
                        if (element.location.y < 1 || element.location.y > " . this.offset["bottom"] . ") {
                            selector.scrollIntoView({behavior: `"smooth`", block: `"center`"});
                            await new Promise(r => setTimeout(r, " . this.delay["scroll"] . ")); // delay
                            element[`"location`"] = selector.getBoundingClientRect();
                        }
                    }
                })();

                JSON.stringify(element); // display
            } catch {}"
        )
        element := JSON.parse(ExecuteJS(script, this.page, "value"))
            
        if (element.Has("location") and (element["location"]["x"] > 0 and element["location"]["x"] < this.size["client"]["width"]) and (element["location"]["y"] > 0 and element["location"]["y"] < this.size["client"]["height"])) {
            RandomBezier
            (
                element["location"]["x"]                    + Rand(this.offset["button"], element["location"]["width"] - this.offset["button"]),
                element["location"]["y"] + this.offset["y"] + Rand(this.offset["button"], element["location"]["height"] - this.offset["button"]),
                "T" this.delay["mouse"] " RO P2-4"
            )
            Sleep(this.delay["mouse"])

            ; CLICK
            script := 
            (
                "try {
                    var element  = {selector: `"#" . child . "`"} // holder
                    var selector = document.querySelector(element.selector); // holder

                    (async function() {
                        `"use strict`";
    
                        if (selector) {
                            element[`"location`"] = selector.getBoundingClientRect();
                            if (element.location.y < 1 || element.location.y > " . this.offset["bottom"] . ") {
                                selector.scrollIntoView({behavior: `"smooth`", block: `"center`"});
                                await new Promise(r => setTimeout(r, " . this.delay["scroll"] . ")); // delay
                                element[`"location`"] = selector.getBoundingClientRect();
                            }
                        }
                    })();

                    JSON.stringify(element); // display
                } catch {}"
            )
            element := JSON.parse(ExecuteJS(script, this.page, "value"))
                
            if (element.Has("location") and (element["location"]["x"] > 0 and element["location"]["x"] < this.size["client"]["width"]) and (element["location"]["y"] > 0 and element["location"]["y"] < this.size["client"]["height"])) {
                RandomBezier
                (
                    element["location"]["x"]                    + Rand(this.offset["button"], element["location"]["width"] - this.offset["button"]),
                    element["location"]["y"] + this.offset["y"] + Rand(this.offset["button"], element["location"]["height"] - this.offset["button"]),
                    "T" this.delay["mouse"] " RO P2-4"
                )
                Sleep(this.delay["mouse"])
                Click()
            }
        }
    }

    FindPokemon() {
        script := 
        (
            "try {
                var element  = {selector: `".btn-catch-action`"}; // holder
                var selector = document.querySelector(element.selector); // holder

                (async function() {
                    `"use strict`";
    
                    if (document.querySelector(`"#showpoke`"))
                        element[`"html`"] = document.querySelector(`"#showpoke`").getInnerHTML();

                    if (selector) {
                        element[`"location`"] = selector.getBoundingClientRect();
                        if (element.location.y < 1) {
                            selector.scrollIntoView({behavior: `"smooth`", block: `"center`"});
                            await new Promise(r => setTimeout(r, 500)); // delay
                            element[`"location`"] = selector.getBoundingClientRect();
                        }
                    }
                })();
                
                JSON.stringify(element); // display;
            } catch {}"
        )
        element := JSON.parse(ExecuteJS(script, this.page, "value"))

        if (element.Has("html") and not InStr(element["html"], "Couldn't find anything")) {
            pattern := "data-class=`"([\w]+)`">(.*?)</a>.*?Level:.*?(\d+).*?HP:.*?(\d+).*?tbtn-([\w]+)"
            if (RegExMatch(element["html"], pattern, &match)) {
                this.pokemon["class"]   := StrTitle(match[1])
                this.pokemon["name"]    := Trim(StrReplace(match[2], this.pokemon["class"]))
                this.pokemon["level"]   := Trim(match[3])
                this.pokemon["hp"]      := Trim(match[4])
                this.pokemon["type"][1] := StrTitle(Trim(match[5]))
                this.pokemon["legend"]  := InStr(element["html"], "This is considered a Legendary Pokemon")    ? true : false
                this.pokemon["unique"]  := InStr(element["html"], "You don't have this pokemon in your box")   ? true : false

                this.status := this.pokemon["class"] " " this.pokemon["name"] " Found!"

                if (RegExMatch(element["html"], "tbtn-([\w]+)", &match, match.Pos + match.Len))
                    this.pokemon["type"][2] .= StrTitle(Trim(match[1]))

                if this.pokemon["legend"]
                    this.count["legends"]++
                if this.pokemon["unique"]
                    this.count["uniques"]++
    
                catchIt := true
                if (InStr(this.settings["pokemon"], "|UNIQUEONLY|", true)) {
                    if not this.pokemon["unique"]
                        catchIt := false
                }

                if (RegExMatch(this.settings["pokemon"], "\|MINLEVEL-(\d+)\|", &match)) {
                    if (match[1] != "") {
                        if (Integer(this.pokemon["level"]) < Integer(match[1]))
                            catchIt := false 
                    }
                }
                
                if (RegExMatch(this.settings["pokemon"], "\|TYPE-([A-Z_]+)\|", &match)) {
                    if (match[1] != "") {
                        targetType := StrSplit(match[1], "_")
                        pType := this.pokemon["type"][1] "-" this.pokemon["type"][2]
                        if not InStr(pType, targetType[1])
                            catchIt := false
                        if (pType.Length > 1) {
                            if not InStr(pType, targetType[2])
                                catchIt := false
                        }
                    }
                }
                
                if (InStr(this.settings["pokemon"], "|LEGENDONLY|", true)) {
                    if not this.pokemon["legend"]
                        catchIt := false
                }
                
                if ((InStr(this.settings["pokemon"], StrUpper(this.pokemon["class"]), true) and catchIt) or this.pokemon["legend"]) {
                    if (element.Has("location") and (element["location"]["x"] > 0 and element["location"]["x"] < this.size["client"]["width"]) and (element["location"]["y"] > 0 and element["location"]["y"] < this.size["client"]["height"])) {
                        RandomBezier
                        (
                            element["location"]["x"]                    + Rand(this.offset["button"], element["location"]["width"] - this.offset["button"]),
                            element["location"]["y"] + this.offset["y"] + Rand(this.offset["button"], element["location"]["height"] - this.offset["button"]),
                            "T" this.delay["mouse"] " RO P2-4"
                        )
                        Sleep(this.delay["mouse"])
                        Click()
                        voice.speak(
                            (this.pokemon["unique"] ? "Unique " : "") 
                            (this.pokemon["legend"] ? "Legendary " : "") 
                            this.pokemon["class"] " " this.pokemon["name"] " has been found!", 1
                        )
                        return
                    }
                }
            }
        }

        for i, v in ShuffleArray(this.directions) {
            if ExecuteJS("document.querySelector('" v "');", this.page) {
                switch v {
                    case "#dr-nw.m-move":
                        Send("{q}")
                    case "#dr-n.m-move":
                        Send("{w}")
                    case "#dr-ne.m-move":
                        Send("{e}")
                    case "#dr-w.m-move":
                        Send("{a}")
                    case "#dr-e.m-move":
                        Send("{d}")
                    case "#dr-sw.m-move":
                        Send("{z}")
                    case "#dr-s.m-move":
                        Send("{s}")
                    case "#dr-se.m-move":
                        Send("{c}")
                }
                break
            }
        }
    }

    CatchPokemon() {
        this.status := (
            (this.pokemon["unique"] ? "Unique " : "") 
            (this.pokemon["legend"] ? "Legendary " : "") 
            this.pokemon["class"] " " this.pokemon["name"] " has been found!"
        )

        pokeball := (this.pokemon["legend"] ? "item-masterball" : "item-ultraball")

        script := 
        (
            "try {
                var element  = {}; // holder
                var selector = {}; // holder

                (async function() {
                    `"use strict`";

                    selector[`"throw`"]    = document.querySelector(`"[value='Throw Pokeball']:not([style])`");
                    selector[`"btn`"]      = document.querySelector(`"input.btn-battle-action:not([style])`");
                    selector[`"done`"]     = document.querySelector(`"[href='/map']`");
                    selector[`"pokeball`"] = document.querySelector(`"#" pokeball "`");
                    selector[`"text`"]     = document.querySelector(`".infobox`");

                    if (selector.throw && selector.throw.getBoundingClientRect().y) {
                        if (selector.pokeball && selector.pokeball.parentNode.parentNode.classList.contains('batsel'))
                            element[`"selector`"] = selector.throw;
                        else
                            element[`"selector`"] = selector.pokeball;
                    } else if (selector.btn) {
                        element[`"selector`"] = selector.btn;
                    } else if (selector.done) {
                        element[`"selector`"] = selector.done;
                        if (selector.text)
                            element[`"html`"] = selector.text.getInnerHTML();
                    }

                    if (`"selector`" in element) {
                        element[`"location`"] = element.selector.getBoundingClientRect();
                        if (element.location.y < 1 || element.location.y > " . this.offset["bottom"] . ") {
                            element.selector.scrollIntoView({behavior: `"smooth`", block: `"center`"});
                            await new Promise(r => setTimeout(r, " . this.delay["scroll"] . ")); // delay
                            element.location = element.selector.getBoundingClientRect();
                        }
                    }
                })();

                JSON.stringify(element); // display
            } catch {}"
        ),
        element := JSON.parse(ExecuteJS(script, this.page, "value"))

            if (element.Has("html")) {
                this.count["pokemons"]++

                if (InStr(element["html"], "sbtn-atk"))
                    this.pokemon["stats"]++
                if (InStr(element["html"], "sbtn-def"))
                    this.pokemon["stats"]++
                if (InStr(element["html"], "sbtn-spe"))
                    this.pokemon["stats"]++

                if (this.pokemon["stats"] > 1) {
                    voice.speak("Congratulations! You caught a " this.pokemon["stats"] " stats pokemon.", 1)
                }
                this.pokemon["stats"] := 0
            }

            if (element.Has("location") and (element["location"]["x"] > 0 and element["location"]["x"] < this.size["client"]["width"]) and (element["location"]["y"] > 0 and element["location"]["y"] < this.size["client"]["height"])) {
                RandomBezier
                (
                    element["location"]["x"]                    + Rand(this.offset["button"], element["location"]["width"] - this.offset["button"]),
                    element["location"]["y"] + this.offset["y"] + Rand(this.offset["button"], element["location"]["height"] - this.offset["button"]),
                    "T" this.delay["mouse"] " RO P2-4"
                )
                Sleep(this.delay["mouse"])
                Click()
            }
    }

    SelectTrainer() {
        script := 
        (
            "try {
                var element  = {}; // holder
                var selector = {}; // holder

                (async function() {
                    `"use strict`";

                    selector[`"trainer`"] = document.querySelector(`"[href='" . this.settings["trainer"]["url"] . "']`");
                    selector[`"tab`"]     = selector.trainer.parentNode.parentNode.getAttribute(`"id`").replace(`"ab`", `"`");
                    selector[`"tab`"]     = document.querySelector(`"#`" + selector.tab + `"`");

                    if (selector.tab && selector.tab.classList.contains(`"glselect`"))
                        element[`"selector`"] = selector.trainer;
                    else
                        element[`"selector`"] = selector.tab;

                    if (selector.trainer)
                        element[`"title`"] = selector.trainer.getAttribute(`"title`");

                    if (`"selector`" in element) {
                        element[`"location`"] = element.selector.getBoundingClientRect();
                        if (element.location.y < 1 || element.location.y > " . this.offset["bottom"] . ") {
                            element.selector.scrollIntoView({behavior: `"smooth`", block: `"center`"});
                            await new Promise(r => setTimeout(r, " . this.delay["scroll"] . ")); // delay
                            element.location = element.selector.getBoundingClientRect();
                        }
                    }
                })();

                JSON.stringify(element); // display
            } catch {}"
        )
        element := JSON.parse(ExecuteJS(script, this.page, "value"))

        if (element.Has("title"))
            this.settings["trainer"]["title"] := element["title"]

        if (element.Has("location") and (element["location"]["x"] > 0 and element["location"]["x"] < this.size["client"]["width"]) and (element["location"]["y"] > 0 and element["location"]["y"] < this.size["client"]["height"])) {
            RandomBezier
            (
                element["location"]["x"]                    + Rand(this.offset["button"], element["location"]["width"] - this.offset["button"]),
                element["location"]["y"] + this.offset["y"] + Rand(this.offset["button"], element["location"]["height"] - this.offset["button"]),
                "T" this.delay["mouse"] " RO P2-4"
            )
            Sleep(this.delay["mouse"])
            Click()
            voice.speak(this.settings["trainer"]["title"])
        }
    }

    BattleTrainer() {
        script := 
        (
            "try {
                var element  = {}; // holder
                var selector = {}; // holder

                (async function() {
                    `"use strict`";

                    selector[`"skip`"] = document.querySelector(`"[value=' Skip Pokemon Selection ']:not([style])`");
                    selector[`"btn`"]  = document.querySelector(`"input.btn-battle-action:not([style])`");
                    selector[`"done`"] = document.querySelector(`"[href='" . this.settings["trainer"]["url"] . "']:not([style])`");
                    selector[`"text`"] = document.querySelector(`".notify_done`");

                    if (selector.skip && selector.skip.getBoundingClientRect().y) {
                        element[`"selector`"] = selector.skip;
                    } else if (selector.btn) {
                        element[`"selector`"] = selector.btn;
                    } else if (selector.done) {
                        element[`"selector`"] = selector.done;
                        if (selector.text)
                            element[`"text`"] = selector.text.innerText;
                    }

                    if (document.querySelector(`"#teamleft h2`"))
                        element[`"title`"] = document.querySelector(`"#teamleft h2`").innerText;

                    if (`"selector`" in element) {
                        element[`"location`"] = element.selector.getBoundingClientRect();
                        if (element.location.y < 1 || element.location.y > " . this.offset["bottom"] . ") {
                            element.selector.scrollIntoView({behavior: `"smooth`", block: `"center`"});
                            await new Promise(r => setTimeout(r, " . this.delay["scroll"] . ")); // delay
                            element.location = element.selector.getBoundingClientRect();
                        }
                    }
                })();

                JSON.stringify(element); // display
            } catch {}"
        )
        element := JSON.parse(ExecuteJS(script, this.page, "value"))

        if (element.Has("title"))
            this.settings["trainer"]["title"] := (InStr(this.settings["trainer"]["url"], "inverse") ? "Inverse " : "Normal ") . element["title"]
        
        if (element.Has("text")) {
            pattern := "You also won (\d+(?:,\d+)*).*?(\d+(?:,\d+)*) exp."
            if (RegExMatch(element["text"], pattern, &match)) {
                this.count["money"] := RegExReplace(StrReplace(match[1], ",") + StrReplace(this.count["money"], ","), "(\d)(?=(?:\d{3})+(?:\.|$))", "$0,")
                this.count["exp"]   := RegExReplace(StrReplace(match[2], ",") + StrReplace(this.count["exp"], ","), "(\d)(?=(?:\d{3})+(?:\.|$))", "$0,")
            }
            this.status := "Rebattlling Trainer. . ."
        }

        if (element.Has("location") and (element["location"]["x"] > 0 and element["location"]["x"] < this.size["client"]["width"]) and (element["location"]["y"] > 0 and element["location"]["y"] < this.size["client"]["height"])) {
            RandomBezier
            (
                element["location"]["x"]                    + Rand(this.offset["button"], element["location"]["width"] - this.offset["button"]),
                element["location"]["y"] + this.offset["y"] + Rand(this.offset["button"], element["location"]["height"] - this.offset["button"]),
                "T" this.delay["mouse"] " RO P2-4"
            )
            Sleep(this.delay["mouse"])
            Click()
        }
    }

    SelectPlayer() {
        script := 
        (
            "try {
                var element  = {}; // holder
                var selector = {}; // holder

                (async function() {
                    `"use strict`";

                    selector[`"input`"]  = document.querySelector(`"#cpbattuser`");
                    selector[`"battle`"] = document.querySelector(`".btn-primary`");

                    if (selector.input && selector.input.value !== `"" this.settings["player"]["username"] "`") {
                        element[`"selector`"] = selector.input;
                        element[`"value`"]    = selector.input.value;
                    } else if (selector.battle) {
                        element[`"selector`"] = selector.battle;
                    }

                    if (`"selector`" in element) {
                        element[`"location`"] = element.selector.getBoundingClientRect();
                        if (element.location.y < 1 || element.location.y > " . this.offset["bottom"] . ") {
                            element.selector.scrollIntoView({behavior: `"smooth`", block: `"center`"});
                            await new Promise(r => setTimeout(r, " . this.delay["scroll"] . ")); // delay
                            element.location = element.selector.getBoundingClientRect();
                        }
                    }
                })();

                JSON.stringify(element); // display
            } catch {}"
        )
        element := JSON.parse(ExecuteJS(script, this.page, "value"))

        if (element.Has("location") and (element["location"]["x"] > 0 and element["location"]["x"] < this.size["client"]["width"]) and (element["location"]["y"] > 0 and element["location"]["y"] < this.size["client"]["height"])) {
            RandomBezier
            (
                element["location"]["x"]                    + Rand(this.offset["button"], element["location"]["width"] - this.offset["button"]),
                element["location"]["y"] + this.offset["y"] + Rand(this.offset["button"], element["location"]["height"] - this.offset["button"]),
                "T" this.delay["mouse"] " RO P2-4"
            )
            Sleep(this.delay["mouse"])
            Click()

            SetKeyDelay(Rand(20, 40), Rand(20, 40))

            if (element.Has("value") and element["value"] != "")
                Send("^a{Backspace}")

            Send(this.settings["player"]["username"])
            SetKeyDelay(Rand(10, 20), Rand(10, 20))
        }
    }

    BattlePlayer() {
        script := 
        (
            "try {
                var element = {}; // holder
                var selector = {}; // holder

                (async function() {
                    `"use strict`";
            
                    selector[`"team`"] = document.querySelector(`"#teamright`");
                    selector[`"skip`"] = document.querySelector(`"[value=' Skip Pokemon Selection ']:not([style])`");
                    selector[`"btn`"]  = document.querySelector(`"input.btn-battle-action:not([style])`");
                    selector[`"done`"] = document.querySelector(`"[href='" this.settings["player"]["url"] "']:not([style])`");
                    selector[`"text`"] = document.querySelector(`".notify_done`");
                    
                    if (selector.team) {
                        selector[`"pokemons`"] = selector.team.querySelectorAll(`".battlelistitem`");
                        if (selector.pokemons) {
                            for (var i = 0; i < selector.pokemons.length; i++) {
                                selector[`"pokemon`"] = selector.pokemons[i];
                                selector[`"level`"] = selector.pokemon.querySelector(`".battlelistlvlhp span`").innerText;
                                if (selector.level) {
                                    element[`"level`"] = parseInt(selector.level.substring(7));

                                    if (element.level < 100)
                                        break;
                                }
                            }
                        }
                    }

                    if (`"pokemon`" in selector && selector.pokemon && !selector.pokemon.classList.contains(`"batsel`")) {
                        element[`"selector`"] = selector.pokemon;
                    } else if (selector.skip && selector.skip.getBoundingClientRect().y) {
                        element[`"selector`"] = selector.skip;
                    } else if (selector.btn) {
                        element[`"selector`"] = selector.btn;
                    } else if (selector.done) {
                        element[`"selector`"] = selector.done;
                        if (selector.text) 
                            element[`"text`"] = selector.text.innerText;
                    }
                        
                    if (`"selector`" in element) {
                        element[`"location`"] = element.selector.getBoundingClientRect();
                        if (element.location.y < 1 || element.location.y > " . this.offset["bottom"] . ") {
                            element.selector.scrollIntoView({behavior: `"smooth`", block: `"center`"});
                            await new Promise(r => setTimeout(r, " . this.delay["scroll"] . ")); // delay
                            element.location = element.selector.getBoundingClientRect();
                        }
                    }
                })();

                JSON.stringify(element); // display
            } catch {}"
        )
        element := JSON.parse(ExecuteJS(script, this.page, "value"))

        if (element.Has("level") && element["level"] >= 100) {
            voice.Speak("Pokemons have already reached level 100", 1)
        } 

        if (element.Has("text")) {
            pattern := "You also won (\d+(?:,\d+)*).*?(\d+(?:,\d+)*) exp."
            if (RegExMatch(element["text"], pattern, &match)) {
                this.count["money"] := RegExReplace(StrReplace(match[1], ",") + StrReplace(this.count["money"], ","), "(\d)(?=(?:\d{3})+(?:\.|$))", "$0,")
                this.count["exp"]   := RegExReplace(StrReplace(match[2], ",") + StrReplace(this.count["exp"], ","), "(\d)(?=(?:\d{3})+(?:\.|$))", "$0,")
            }
            this.status := "Rebattlling Player. . ."
        }

        if (element.Has("location") and (element["location"]["x"] > 0 and element["location"]["x"] < this.size["client"]["width"]) and (element["location"]["y"] > 0 and element["location"]["y"] < this.size["client"]["height"])) {
            RandomBezier
            (
                element["location"]["x"]                    + Rand(this.offset["button"], element["location"]["width"] - this.offset["button"]),
                element["location"]["y"] + this.offset["y"] + Rand(this.offset["button"], element["location"]["height"] - this.offset["button"]),
                "T" this.delay["mouse"] " RO P2-4"
            )
            Sleep(this.delay["mouse"])
            Click()
        }
    }

    BypassCaptcha() {
        static timeout := true, setTime := 0
        if timeout {
            timeout := false
            setTime := A_TickCount
            voice.Speak(deluge.status, 1)
        } else if (A_TickCount - setTime > 60000) {
            this.status := "Reloading. . ."
            this.page.Evaluate("location.reload()")
            Sleep(1000)
            timeout := true
            setTime := 0
        }

        if (not captchaEl := UIA.ElementFromHandle(this.client).WaitElement({ AutomationId: "solver-button" }, 1000)) {
            if (captchaEl := UIA.ElementFromHandle(this.client).WaitElement({ AutomationId: "recaptcha-anchor" }, 1000)) {
                if (captchaEl.ToggleState) {
                    captchaEl := UIA.ElementFromHandle(this.client).WaitElement({ Name: "Return to Game" }, 1000)
                    this.count["captcha"]++
                    timeout := true
                }
            }
        }

        if (captchaEl.HasProp("location")) {
            RandomBezier
            (
                (captchaEl.location.x - this.size["client"]["x"]) + Rand(this.offset["button"], captchaEl.location.w - this.offset["button"]),
                (captchaEl.location.y - this.size["client"]["y"]) + Rand(this.offset["button"], captchaEl.location.h - this.offset["button"]),
                "T" this.delay["mouse"] " RO P2-4"
            )
            Sleep(this.delay["mouse"])
            Click()
            if InStr(captchaEl.name, "Solve the challenge") {
                Sleep(5000)
            }
        }
        Sleep(this.delay["iteration"])
    }
    ; ------------ END
}

; ------------ HOTKEYS
Esc:: ExitApp
PgUp:: {
    global deluge
    deluge.status := "Paused. . ."
    Sleep(1000)
    Pause(-1)
}
!h:: {
    static toggle := false
    if (not toggle)
        WinSetTransparent(10, deluge.client)
    else
        WinSetTransparent(255, deluge.client)
    toggle := not toggle
}

; ------------ FUNCTIONS
GetWindowSize(client) {
    try {
        FocusOnClient(client)
        WinGetPos(&x1, &y1, &w1, &h1, client)
        WinGetClientPos(&x2, &y2, &w2, &h2, client)
        ControlGetPos(&x3, &y3, &w3, &h3, WinGetControls(client)[1], client)
        windowSize := Map(
            "window",  Map("x", x1, "y", y1, "width", w1, "height", h1),
            "client",  Map("x", x2, "y", y2, "width", w2, "height", h2),
            "control", Map("x", x3, "y", y3, "width", w3, "height", h3),
        )
        return windowSize
    } catch as e {
        return 0
    }
}

ResizeClient(width, height, client) {
    if (WinExist(client)) {
        windowSize   := GetWindowSize(client)
        resizeWidth  := width + (windowSize["window"]["width"] - windowSize["client"]["width"])
        resizeHeight := height + (windowSize["window"]["height"] - windowSize["client"]["height"])
        WinRestore(client)
        WinMove(, , resizeWidth, resizeHeight, client)
        WinMinimize(client)
        Sleep(500)
        WinRestore(client)
    }
}

FocusOnClient(client) {
    if (WinExist(client)) {
        WinActivate(client)
        WinWaitActive(client, , 5)
    }
}

ExecuteJS(script, page, stdin := "description", display_value := false) {
    stdout := page.Evaluate(script)
    Sleep(200)
    if display_value {
        result := ""
        for key, value in stdout {
            result .= key ": " value "`n"
        }
        MsgBox(result)
    }
    return stdout.Has(stdin) ? stdout[stdin] : 0
}

ShuffleArray(arrayIn) {
    ; Shuffle an array. Supports array of objects.
    if (Type(arrayIn) != "Array")
        throw TypeError("Parameter should be of Array type.", -1, arrayIn)
    arrayClone := arrayIn.Clone()  ; Let original array untouched.
    arrayOut := []
    loop arrayClone.Length {
        randIndex := Random(1, arrayClone.Length)
        randItem := arrayClone[randIndex]
        arrayClone.RemoveAt(randIndex)
        arrayOut.Push(randItem)
    }
    return arrayOut
}

Rand(min, max, range := "MR") {
    pi := 4 * ATan(1)
    min += 0.0
    max += 0.0
    z := max - min
    x := Random(0, z) + 0.0
    y := ""
    if (range = "QHR")
        y := -x ** 2 / (z / 4.0) + 4.0 * x + min  ; Quadratic High Range
    else if (range = "QLR")
        y := (x - z) ** 2 / (z / 4.0) + 4.0 * x - 3 * z + min ; Quadratic Low Range
    else if (range = "AHR")
        y := Sqrt(z * x) + min ; Algebraic High range
    else if (range = "ALR")
        y := -Sqrt(z * x) + z + min ; Algebraic Low range
    else
        y := -cos(x / (z / pi)) ** 3 * (z / 2.0) + (z / 2.0) + min ; Mid Range
    return round(y) ; Round will cause non-uniform results with min and max numbers. Just expect your lowest and highest numbers to be represented more or less than one might expect.
}

RandomBezier(Xf, Yf, O := "", X0 := 0, Y0 := 0) {
    Time := (RegExMatch(O, "i)T(\d+)", &M) && (M[1] > 0) ? M[1] : 200)
    RO := InStr(O, "RO", 0)
    RD := InStr(O, "RD", 0)
    N := ( not RegExMatch(O, "i)P(\d+)(-(\d+))?", &M) || (M[1] < 2) ? 2 : ((M[1] > 19) ? 19 : M[1]))
    if (M and (M := (M[3] != "") ? ((M[3] < 2) ? 2 : ((M[3] > 19) ? 19 : M[3])) : ((M[1] == "") ? 5 : "")) != "")
        N := Random(N, M)
    OfT := (RegExMatch(O, "i)OT(-?\d+)", &M) ? M[1] : 100)
    OfB := (RegExMatch(O, "i)OB(-?\d+)", &M) ? M[1] : 100)
    OfL := (RegExMatch(O, "i)OL(-?\d+)", &M) ? M[1] : 100)
    OfR := (RegExMatch(O, "i)OR(-?\d+)", &M) ? M[1] : 100)
    MouseGetPos(&XM, &YM)
    if (RO)
        X0 += XM, Y0 += YM
    if (RD)
        Xf += XM, Yf += YM
    if (X0 < Xf) {
        sX := X0 - OfL
        bX := Xf + OfR
    } else {
        sX := Xf - OfL, bX := X0 + OfR
    }
    if (Y0 < Yf)
        sY := Y0 - OfT, bY := Yf + OfB
    else
        sY := Yf - OfT, bY := Y0 + OfB
    X := Map(), Y := Map()
    Loop ((--N) - 1) {
        X[A_Index] := Random(sX, bX)
        Y[A_Index] := Random(sY, bY)
    }
    X[N] := Xf
    Y[N] := Yf
    E := (I := A_TickCount) + Time
    While (A_TickCount < E) {
        U := 1 - (T := (A_TickCount - I) / Time)
        Loop (N + 1 + (xPos := yPos := 0)) {
            Loop (Idx := A_Index - (F1 := F2 := F3 := 1)) {
                F2 *= A_Index, F1 *= A_Index
            }
            Loop (D := N - Idx) {
                F3 *= A_Index, F1 *= A_Index + Idx
            }
            M := (F1 / (F2 * F3)) * ((T + 0.000001) ** Idx) * ((U - 0.000001) ** D)
            xPos += (M * (X.Has(Idx) ? X[Idx] : XM))
            yPos += (M * (Y.Has(Idx) ? Y[Idx] : YM))
        }
        MouseMove(xPos, yPos, 0)
        Sleep(1)
    }
    MouseMove(X[N], Y[N], 0)
}

ConnectedToInternet(url := "https://www.amazon.com") {
   return DllCall("Wininet\InternetCheckConnection", "Str", url, "UInt", 1, "Ptr", 0)
}


/*
// Create an object to store the grouped data
const groupedData = {};

// Get all the td elements with the specified classes
const tdElements = document.querySelectorAll('td.mu-zero, td.mu-half, td.mu-one, td.mu-two');

// Define key names for each index
const keyNames = {
    0: 'Normal',
    1: 'Fire',
    2: 'Water',
    3: 'Electric',
    4: 'Grass',
    5: 'Ice',
    6: 'Fighting',
    7: 'Poison',
    8: 'Ground',
    9: 'Fly',
    10: 'Psychic',
    11: 'Bug',
    12: 'Rock',
    13: 'Ghost',
    14: 'Dragon',
    15: 'Dark',
    16: 'Steel',
    17: 'Fairy',
    // ... Define more key names as needed
};

// Group the td elements in sets of 18
for (let i = 0; i < tdElements.length; i += 18) {
    const keyIndex = i / 18 + 1;
    const keyName = keyNames[keyIndex - 1];
    groupedData[keyName] = Array.from(tdElements)
        .slice(i, i + 18)
        .reduce((result, tdElement, index) => {
            result[keyNames[index]] = tdElement.textContent;
            return result;
        }, {});
}

// Output the grouped data
JSON.stringify(groupedData)
*/

typeChart := Map()
typeChart.CaseSense := false
typeChart["Normal"] := Map(
    "Normal", "1",
    "Fire", "1",
    "Water", "1",
    "Electric", "1",
    "Grass", "1",
    "Ice", "1",
    "Fighting", "2",
    "Poison", "1",
    "Ground", "1",
    "Fly", "1",
    "Psychic", "1",
    "Bug", "1",
    "Rock", "1",
    "Ghost", "0",
    "Dragon", "1",
    "Dark", "1",
    "Steel", "1",
    "Fairy", "1",
)
typeChart["Fire"] := Map(
    "Normal", "1",
    "Fire", "0.5",
    "Water", "2",
    "Electric", "1",
    "Grass", "0.5",
    "Ice", "0.5",
    "Fighting", "1",
    "Poison", "1",
    "Ground", "2",
    "Fly", "1",
    "Psychic", "1",
    "Bug", "0.5",
    "Rock", "2",
    "Ghost", "1",
    "Dragon", "1",
    "Dark", "1",
    "Steel", "0.5",
    "Fairy", "0.5",
)
typeChart["Water"] := Map(
    "Normal", "1",
    "Fire", "0.5",
    "Water", "0.5",
    "Electric", "2",
    "Grass", "2",
    "Ice", "0.5",
    "Fighting", "1",
    "Poison", "1",
    "Ground", "1",
    "Fly", "1",
    "Psychic", "1",
    "Bug", "1",
    "Rock", "1",
    "Ghost", "1",
    "Dragon", "1",
    "Dark", "1",
    "Steel", "0.5",
    "Fairy", "1",
)
typeChart["Electric"] := Map(
    "Normal", "1",
    "Fire", "1",
    "Water", "1",
    "Electric", "0.5",
    "Grass", "1",
    "Ice", "1",
    "Fighting", "1",
    "Poison", "1",
    "Ground", "2",
    "Fly", "0.5",
    "Psychic", "1",
    "Bug", "1",
    "Rock", "1",
    "Ghost", "1",
    "Dragon", "1",
    "Dark", "1",
    "Steel", "0.5",
    "Fairy", "1",
)
typeChart["Grass"] := Map(
    "Normal", "1",
    "Fire", "2",
    "Water", "0.5",
    "Electric", "0.5",
    "Grass", "0.5",
    "Ice", "2",
    "Fighting", "1",
    "Poison", "2",
    "Ground", "0.5",
    "Fly", "2",
    "Psychic", "1",
    "Bug", "2",
    "Rock", "1",
    "Ghost", "1",
    "Dragon", "1",
    "Dark", "1",
    "Steel", "1",
    "Fairy", "1",
)
typeChart["Ice"] := Map(
    "Normal", "1",
    "Fire", "2",
    "Water", "1",
    "Electric", "1",
    "Grass", "1",
    "Ice", "0.5",
    "Fighting", "2",
    "Poison", "1",
    "Ground", "1",
    "Fly", "1",
    "Psychic", "1",
    "Bug", "1",
    "Rock", "2",
    "Ghost", "1",
    "Dragon", "1",
    "Dark", "1",
    "Steel", "2",
    "Fairy", "1",
)
typeChart["Fighting"] := Map(
    "Normal", "1",
    "Fire", "1",
    "Water", "1",
    "Electric", "1",
    "Grass", "1",
    "Ice", "1",
    "Fighting", "1",
    "Poison", "1",
    "Ground", "1",
    "Fly", "2",
    "Psychic", "2",
    "Bug", "0.5",
    "Rock", "0.5",
    "Ghost", "1",
    "Dragon", "1",
    "Dark", "0.5",
    "Steel", "1",
    "Fairy", "2",
)
typeChart["Poison"] := Map(
    "Normal", "1",
    "Fire", "1",
    "Water", "1",
    "Electric", "1",
    "Grass", "0.5",
    "Ice", "1",
    "Fighting", "0.5",
    "Poison", "0.5",
    "Ground", "2",
    "Fly", "1",
    "Psychic", "2",
    "Bug", "0.5",
    "Rock", "1",
    "Ghost", "1",
    "Dragon", "1",
    "Dark", "1",
    "Steel", "1",
    "Fairy", "0.5",
)
typeChart["Ground"] := Map(
    "Normal", "1",
    "Fire", "1",
    "Water", "2",
    "Electric", "0",
    "Grass", "2",
    "Ice", "2",
    "Fighting", "1",
    "Poison", "0.5",
    "Ground", "1",
    "Fly", "1",
    "Psychic", "1",
    "Bug", "1",
    "Rock", "0.5",
    "Ghost", "1",
    "Dragon", "1",
    "Dark", "1",
    "Steel", "1",
    "Fairy", "1",
)
typeChart["Fly"] := Map(
    "Normal", "1",
    "Fire", "1",
    "Water", "1",
    "Electric", "2",
    "Grass", "0.5",
    "Ice", "2",
    "Fighting", "0.5",
    "Poison", "1",
    "Ground", "0",
    "Fly", "1",
    "Psychic", "1",
    "Bug", "0.5",
    "Rock", "2",
    "Ghost", "1",
    "Dragon", "1",
    "Dark", "1",
    "Steel", "1",
    "Fairy", "1",
)
typeChart["Psychic"] := Map(
    "Normal", "1",
    "Fire", "1",
    "Water", "1",
    "Electric", "1",
    "Grass", "1",
    "Ice", "1",
    "Fighting", "0.5",
    "Poison", "1",
    "Ground", "1",
    "Fly", "1",
    "Psychic", "0.5",
    "Bug", "2",
    "Rock", "1",
    "Ghost", "2",
    "Dragon", "1",
    "Dark", "2",
    "Steel", "1",
    "Fairy", "1",
)
typeChart["Bug"] := Map(
    "Normal", "1",
    "Fire", "2",
    "Water", "1",
    "Electric", "1",
    "Grass", "0.5",
    "Ice", "1",
    "Fighting", "0.5",
    "Poison", "1",
    "Ground", "0.5",
    "Fly", "2",
    "Psychic", "1",
    "Bug", "1",
    "Rock", "2",
    "Ghost", "1",
    "Dragon", "1",
    "Dark", "1",
    "Steel", "1",
    "Fairy", "1",
)
typeChart["Rock"] := Map(
    "Normal", "0.5",
    "Fire", "0.5",
    "Water", "2",
    "Electric", "1",
    "Grass", "2",
    "Ice", "1",
    "Fighting", "2",
    "Poison", "0.5",
    "Ground", "2",
    "Fly", "0.5",
    "Psychic", "1",
    "Bug", "1",
    "Rock", "1",
    "Ghost", "1",
    "Dragon", "1",
    "Dark", "1",
    "Steel", "2",
    "Fairy", "1",
)
typeChart["Ghost"]:= Map(
    "Normal", "0",
    "Fire", "1",
    "Water", "1",
    "Electric", "1",
    "Grass", "1",
    "Ice", "1",
    "Fighting", "0",
    "Poison", "0.5",
    "Ground", "1",
    "Fly", "1",
    "Psychic", "1",
    "Bug", "0.5",
    "Rock", "1",
    "Ghost", "2",
    "Dragon", "1",
    "Dark", "2",
    "Steel", "1",
    "Fairy", "1",
)
typeChart["Dragon"] := Map(
    "Normal", "1",
    "Fire", "0.5",
    "Water", "0.5",
    "Electric", "0.5",
    "Grass", "0.5",
    "Ice", "2",
    "Fighting", "1",
    "Poison", "1",
    "Ground", "1",
    "Fly", "1",
    "Psychic", "1",
    "Bug", "1",
    "Rock", "1",
    "Ghost", "1",
    "Dragon", "2",
    "Dark", "1",
    "Steel", "1",
    "Fairy", "2",
)
typeChart["Dark"] := Map(
    "Normal", "1",
    "Fire", "1",
    "Water", "1",
    "Electric", "1",
    "Grass", "1",
    "Ice", "1",
    "Fighting", "2",
    "Poison", "1",
    "Ground", "1",
    "Fly", "1",
    "Psychic", "0",
    "Bug", "2",
    "Rock", "1",
    "Ghost", "0.5",
    "Dragon", "1",
    "Dark", "0.5",
    "Steel", "1",
    "Fairy", "2",
)
typeChart["Steel"] := Map(
    "Normal", "0.5",
    "Fire", "2",
    "Water", "1",
    "Electric", "1",
    "Grass", "0.5",
    "Ice", "0.5",
    "Fighting", "2",
    "Poison", "0",
    "Ground", "2",
    "Fly", "0.5",
    "Psychic", "0.5",
    "Bug", "0.5",
    "Rock", "0.5",
    "Ghost", "1",
    "Dragon", "0.5",
    "Dark", "1",
    "Steel", "0.5",
    "Fairy", "0.5",
)
typeChart["Fairy"] := Map(
    "Normal", "1",
    "Fire", "1",
    "Water", "1",
    "Electric", "1",
    "Grass", "1",
    "Ice", "1",
    "Fighting", "0.5",
    "Poison", "2",
    "Ground", "1",
    "Fly", "1",
    "Psychic", "1",
    "Bug", "0.5",
    "Rock", "1",
    "Ghost", "1",
    "Dragon", "0",
    "Dark", "0.5",
    "Steel", "2",
    "Fairy", "1",
)

/*
try {
    var element  = {}; // holder
    var selector = {}; // holder

    (async function () {
        "user strict";
        
        selector["pokemonList"] = document.querySelector(".container");
        if (selector.pokemonList) {
            selector["pokemons"] = selector.pokemonList.querySelectorAll("[data-pktype]");
            if (selector.pokemons && selector.pokemons.length > 0) {
                for (var i = 0; i < selector.pokemons.length; i++) {
                    selector["pokemon"] = selector.pokemons[i];
                    selector["level"]   = selector.pokemon.querySelector(".info div");
                    selector["moves"]   = selector.pokemon.querySelector(".attk");
        
                    if (selector.moves) {
                        if (selector.level && selector.moves.innerHTML.indexOf("hoverclr-normal")) {
                            element["level"] = parseInt(selector.level.innerText.substring(7));
                            
                            if (element.level < 100)
                                break;
                        }
                    }
                }
            }
        }
        if ("pokemon" in selector && "level" in element) {
            element["location"] = selector.pokemon.getBoundingClientRect();
            if (element.location.y < 1) {
                selector.pokemon.scrollIntoView({behavior: "smooth", block: "center"});
                await new Promise(r => setTimeout(r, 500)); // delay
                element.location = selector.pokemon.getBoundingClientRect();
            }
        }
    })();

    JSON.stringify(element); // display
} catch {}
*/