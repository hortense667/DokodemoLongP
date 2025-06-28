#Requires AutoHotkey v2.0
#Warn VarUnset, Off
;
;  (c) 2025 Satoshi Endo (hortense)
;
; プロンプトの履歴についての処理（改行対応版）
; 履歴ファイル（プレーンテキストで作られる）のパス設定
global HistoryFile := A_ScriptDir . "\prompt_history.txt"

; 改行を含む文字列をエスケープする関数
EscapeText(text) {
    ; 改行をエスケープシーケンスに変換
    text := StrReplace(text, "`r`n", "\\r\\n")
    text := StrReplace(text, "`n", "\\n")
    text := StrReplace(text, "`r", "\\r")
    ; パイプ文字をエスケープ（区切り文字として使用するため）
    text := StrReplace(text, "|", "\\|")
    return text
}

; エスケープされた文字列を元に戻す関数
UnescapeText(text) {
    ; エスケープシーケンスを実際の改行に戻す
    text := StrReplace(text, "\\r\\n", "`r`n")
    text := StrReplace(text, "\\n", "`n")
    text := StrReplace(text, "\\r", "`r")
    ; パイプ文字を元に戻す
    text := StrReplace(text, "\\|", "|")
    return text
}

; 履歴を読み込む関数
LoadHistory() {
    history := []
    ; ファイルが存在しない場合はデフォルト履歴を作成
    if !FileExist(HistoryFile) {
        default_prompts := ["要約してください：", "以下の文章を校正してください：", "次のトピックについて詳しく説明してください："]
        SaveHistory(default_prompts)
        return default_prompts
    }

    ; ファイルから履歴を読み込み
    try {
        FileObj := FileOpen(HistoryFile, "r")
        file_content := FileObj.Read()
        FileObj.Close()
        
        lines := StrSplit(file_content, "`n", "`r")
        
        for line in lines {
            line := Trim(line)
            if line != "" {
                ; エスケープされたテキストを元に戻す
                unescaped_line := UnescapeText(line)
                history.Push(unescaped_line)
            }
        }
        
        ; 履歴が空の場合はデフォルトを返す
        if history.Length == 0 {
            default_prompts := ["要約してください：", "以下の文章を校正してください：", "次のトピックについて詳しく説明してください："]
            SaveHistory(default_prompts)
            return default_prompts
        }
    } catch Error as e {
        ; 読み込みエラーの場合はデフォルトを返す
        default_prompts := ["要約してください：", "以下の文章を校正してください：", "次のトピックについて詳しく説明してください："]
        SaveHistory(default_prompts)
        return default_prompts
    }
    
    return history
}

; 履歴を保存する関数
SaveHistory(history_array) {
    try {
        FileObj := FileOpen(HistoryFile, "w")
        
        for item in history_array {
            ; 改行を含む場合はエスケープして保存
            escaped_item := EscapeText(item)
            FileObj.Write(escaped_item . "`r`n")
        }
        
        FileObj.Close()
        
    } catch Error as e {
        MsgBox("履歴保存エラー: " . e.Message . "`nパス: " . HistoryFile)
    }
}

; 履歴に新しいアイテムを追加する関数
AddToHistory(new_item) {
    history := LoadHistory()
    trimmed_item := Trim(new_item)
    
    ; 空の場合は追加しない
    if trimmed_item == ""
        return
    
    ; 既に存在する場合は削除してから先頭に追加（最新を上に）
    filtered_history := []
    for item in history {
        if Trim(item) != trimmed_item {
            filtered_history.Push(item)
        }
    }
    
    ; 新しいアイテムを先頭に追加
    filtered_history.InsertAt(1, trimmed_item)
    
    ; 最大256件まで保持
    if filtered_history.Length > 256 {
        filtered_history.RemoveAt(257, filtered_history.Length - 256)
    }
    
    SaveHistory(filtered_history)
}

; 履歴項目を表示用に変換する関数（改行を表示用に変換）
FormatForDisplay(text) {
    ; 改行を " ↵ " に置換して1行で表示
    display_text := StrReplace(text, "`r`n", " ↵ ")
    display_text := StrReplace(display_text, "`n", " ↵ ")
    display_text := StrReplace(display_text, "`r", " ↵ ")
    
    ; 長すぎる場合は切り詰める
    if StrLen(display_text) > 80 {
        display_text := SubStr(display_text, 1, 77) . "..."
    }
    
    return display_text
}

; プロンプト入力ダイアログを表示する関数
ShowPromptDialog() {
    prompt_list := LoadHistory()
    display_list := []
    prompt_text := ""
    dialog_result := false
    gui_finished := false
    selected_index := 0
    
    ; 表示用リストを作成
    for item in prompt_list {
        display_list.Push(FormatForDisplay(item))
    }
    
    MyGui := Gui("+Resize", "DokodemoLongP(Long Prompt) by hortense667")
    MyGui.SetFont("s14", "Yu Gothic UI")

    ; 履歴選択用ComboBox（読み取り専用）

    PromptCombo := myGui.Add("DropDownList","w1000" , display_list)
    myGui.Show()

    ; 入力エリア
    MyGui.Add("Text", "xm w1000", "Enter or edit your prompt (supports multiple lines):")
    PromptEdit := MyGui.Add("Edit", "xm w1000 h300 VScroll +WantReturn")

    ; ボタンの追加
    OkButton := MyGui.Add("Button", "xm Default w80", "OK")
    CancelButton := MyGui.Add("Button", "x+10 w150", "CANCEL")
    ClearButton := MyGui.Add("Button", "x+10 w80", "CLEAR")

    ; --- イベントハンドラの定義 ---

    ; ComboBoxで項目が選択されたときの処理
    ComboChangeHandler(*) {
        selected_index := PromptCombo.Value
        if selected_index > 0 && selected_index <= prompt_list.Length {
            ; 選択された履歴項目をEditに設定
            PromptEdit.Text := prompt_list[selected_index]
        }
    }
    
    PromptCombo.OnEvent("Change", ComboChangeHandler)

    ; OKボタンがクリックされたときの処理
    OkHandler(*) {
        ; Editの値を取得
        prompt_text := PromptEdit.Text
        
        ; 空でない場合は履歴に追加
        if Trim(prompt_text) != "" {
            AddToHistory(prompt_text)
        }
        
        dialog_result := true
        gui_finished := true
        MyGui.Destroy()
    }
    
    OkButton.OnEvent("Click", OkHandler)

    ; クリアボタンの処理
    ClearHandler(*) {
        PromptEdit.Text := ""
        PromptCombo.Choose(0)
    }
    
    ClearButton.OnEvent("Click", ClearHandler)

    ; キャンセルまたはウィンドウが閉じられたときの処理
    GuiClose(*) {
        dialog_result := false
        gui_finished := true
        MyGui.Destroy()
    }

    ; イベントの割り当て
    CancelButton.OnEvent("Click", GuiClose)
    MyGui.OnEvent("Close", GuiClose)

    ; GUIを表示
    MyGui.Show("w1040 h500")
    
    ; GUIが閉じられるまで待つ
    while !gui_finished {
        Sleep 50
    }
    
    ; 結果を返す
    return dialog_result ? prompt_text : ""
}

^#p::
{
    ; 元のアクティブウィンドウを記憶
    hWnd := WinGetID("A")

    ; プロンプト入力ダイアログを表示し、結果を取得
    prompt_text := ShowPromptDialog()
    
    ; キャンセルされた場合は処理を中断
    if prompt_text == "" {
        return
    }

    ; エディタウィンドウを再アクティブ化
    WinActivate("ahk_id " hWnd)
    Sleep 100

    ClipboardBackup := ClipboardAll()
    A_Clipboard := prompt_text
    Sleep 100 ; クリップボードのセットを待つ
    Send "^v" ; Ctrl+Vで貼り付け
    Sleep 100 ; 貼り付け完了を待つ
    A_Clipboard := ClipboardBackup ; 元のクリップボードを復元
    return
}