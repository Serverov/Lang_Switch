#Requires AutoHotkey v2.0
#SingleInstance Force

/*
    Language_Switch v2.7 (reviewed), (c) Serverov 2025 + hardening by ❤Luna❤
    — Для AHK v2
    — Упрощённое переключение языков системными хоткеями Alt+Shift+0/1/2
    — Логирование + безопасные проверки
    — Исправлено: дублирование проверки enPrograms; корректная работа со строкой '"' в TransformText
    
    Nota Bene!
    ~~~~~~~~~~
    
    Для Asus Vivobook и кнопки Copilot F23 необходимо переназначение ее scancode на F13.
    
    Патч для реестра:
    ------------------------------------------------------------------------------
    Windows Registry Editor Version 5.00
    
    [HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Keyboard Layout]
    "Scancode Map"=hex:00,00,00,00,00,00,00,00,02,00,00,00,64,00,6e,00,00,00,00,00
    ------------------------------------------------------------------------------
    
    Необходимо назначить однозначные комбинации для переключения языков:
        Eng = LAlt+LShift+0
        Rus = LAlt+LShift+1
        Ukr = LAlt+LShift+2
   
    
*/

LOG_FILE := A_ScriptDir "\\Language_Switch.log"
 
;Программы, для которых принудительно включается eng при активации нового окна:
enPrograms := ["SecureCRT.exe", "csc_ui.exe"]

DOUBLE_HOTKEY_MS := 400
lastWin := 0
SetTimer(CheckActiveWindow, 1000)   ; v2: вызов функции в скобках

; === БАЗОВЫЕ ЯЗЫКОВЫЕ ВЫЗОВЫ ===
SendLangDigit(d) {
    try {
        Send("!+" d)   ; Alt+Shift+<digit> (top row)
    } catch as err {
        ; fallback — максимально совместимый вариант с явными up/down
        SendEvent("{LAlt down}{LShift down}{" d "}{LShift up}{LAlt up}")
    }
}

ForceLang_ENG() => SendLangDigit("0")
ForceLang_RUS() => SendLangDigit("1")
ForceLang_UKR() => SendLangDigit("2")

; === ЛОГ ===
Log(msg) {
    global LOG_FILE
    time := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    try {
        FileAppend(time " | " msg "`r`n", LOG_FILE)
    } catch as err {
        ; игнорируем ошибки логирования
    }
}

; === SAFE HELPERS ===
SafeWinActive() {
    try {
        hwnd := WinActive("A")
        return hwnd ? hwnd : 0
    } catch as err {
        Log("WinActive failed: " err.Message)
        return 0
    }
}

SafeGetExe(hwnd) {
    if !hwnd
        return ""
    try {
        return WinGetProcessName(hwnd)
    } catch as err {
        Log("WinGetProcessName failed: " err.Message)
        return ""
    }
}

; === ТАЙМЕР: авто-ENG для ряда программ ===
CheckActiveWindow() {
    global lastWin, enPrograms
    hwnd := SafeWinActive()
    if !hwnd || (lastWin = hwnd)
        return

    exe := SafeGetExe(hwnd)
    if (exe = "")
        return

    found := false
    for _, name in enPrograms {
        if (exe = name) {
            found := true
            break
        }
    }

    if found {
        try {
            ForceLang_ENG()
        } catch as err {
            Log("Force English on activate failed: " err.Message)
        }
    }

    lastWin := hwnd
}

; === ГОРЯЧИЕ КЛАВИШИ ===
~LControl:: {
    try {
        ForceLang_ENG()
    } catch as err {
        Log("LControl ENG failed: " err.Message)
    }
    KeyWait("LControl")
}

~RControl:: {
    try {
        ForceLang_RUS()
        if (A_PriorHotkey = "~RControl" && A_TimeSincePriorHotkey <= DOUBLE_HOTKEY_MS)
            ForceLang_UKR()
    } catch as err {
        Log("RControl switch failed: " err.Message)
    }
    KeyWait("RControl")
}

<+<#F13:: {
    try {
        ForceLang_RUS()
        if (A_PriorHotkey = "<+<#F13" && A_TimeSincePriorHotkey <= DOUBLE_HOTKEY_MS)
            ForceLang_UKR()
    } catch as err {
        Log("F13 combo switch failed: " err.Message)
    }
    KeyWait("F13")
}

^+L:: {
    ClipSaved := ClipboardAll()
    A_Clipboard := ""

    class := ""
    try {
        class := WinGetClass("A")
    } catch as err {
        Log("WinGetClass failed: " err.Message)
    }

    copyCombo := (class = "ConsoleWindowClass" || class = "CASCADIA_HOSTING_WINDOW_CLASS") ? "^+c" : "^c"

    ok := false
    try {
        SendInput(copyCombo)
        ok := ClipWait(0.6)
        if !ok {
            Sleep(80)
            SendEvent(copyCombo)
            ok := ClipWait(0.8)
        }
    } catch as err {
        Log("Copy failed: " err.Message)
    }

    if (A_Clipboard = "") {
        A_Clipboard := ClipSaved
        ClipSaved := ""
        try {
            MsgBox("Please select text.")
        } catch as err {
        }
        return
    }

    OriginalText := A_Clipboard
    trans := ""
    try {
        trans := TransformText(OriginalText)
    } catch as err {
        Log("TransformText failed: " err.Message)
        trans := OriginalText
    }

    A_Clipboard := trans
    try {
        Send("^v")
    } catch as err {
        Log("Paste failed: " err.Message)
    }

    Sleep(80)
    A_Clipboard := ClipSaved
    ClipSaved := ""
}

; === ТРАНСФОРМАЦИЯ ТЕКСТА ===
TransformText(Text) {
    EnglishToRussian := Map()
    RussianToEnglish := Map()

    Letters := ["q","w","e","r","t","y","u","i","o","p","a","s","d","f","g","h","j","k","l","z","x","c","v","b","n","m"]
    RussianLetters := ["й","ц","у","к","е","н","г","ш","щ","з","ф","ы","в","а","п","р","о","л","д","я","ч","с","м","и","т","ь"]

    for index, letter in Letters {
        EnglishToRussian.Set(letter, RussianLetters[index])
        EnglishToRussian.Set(StrUpper(letter), StrUpper(RussianLetters[index]))
        RussianToEnglish.Set(RussianLetters[index], letter)
        RussianToEnglish.Set(StrUpper(RussianLetters[index]), StrUpper(letter))
    }

    DQ := Chr(34) ; символ '"'
    EnglishToRussian.Set("[", "х")
    EnglishToRussian.Set("]", "ъ")
    EnglishToRussian.Set(";", "ж")
    EnglishToRussian.Set("'", "э")
    EnglishToRussian.Set(":", "Ж")
    EnglishToRussian.Set(DQ, "Э")
    EnglishToRussian.Set(",", "б")
    EnglishToRussian.Set(".", "ю")
    EnglishToRussian.Set("/", ".")
    EnglishToRussian.Set("<", "Б")
    EnglishToRussian.Set(">", "Ю")
    EnglishToRussian.Set("?", ",")
    EnglishToRussian.Set("{", "Х")
    EnglishToRussian.Set("}", "Ъ")

    RussianToEnglish.Set("х", "[")
    RussianToEnglish.Set("ъ", "]")
    RussianToEnglish.Set("ж", ";")
    RussianToEnglish.Set("э", "'")
    RussianToEnglish.Set("Ж", ":")
    RussianToEnglish.Set("Э", DQ)
    RussianToEnglish.Set("б", ",")
    RussianToEnglish.Set("ю", ".")
    RussianToEnglish.Set(".", "/")
    RussianToEnglish.Set("Б", "<")
    RussianToEnglish.Set("Ю", ">")
    RussianToEnglish.Set(",", "?")
    RussianToEnglish.Set("Х", "{")
    RussianToEnglish.Set("Ъ", "}")

    result := ""
    for _, char in StrSplit(Text, "") {
        if EnglishToRussian.Has(char)
            result .= EnglishToRussian.Get(char)
        else if RussianToEnglish.Has(char)
            result .= RussianToEnglish.Get(char)
        else
            result .= char
    }
    return result
}
