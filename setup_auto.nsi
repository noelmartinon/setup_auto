Name "setup_auto"
Caption "Setup_auto.exe - Installation automatique"
Outfile "setup_auto.exe"

RequestExecutionLevel user

!include "MUI2.nsh"
!include "NSISpcre.nsh"
!include "nsResize.nsh"
!include "StrFunc.nsh"
!include "nsProcess.nsh"
!include "FileFunc.nsh" ; GetParameters, GetOptions
!include "x64.nsh"

!define MUI_CUSTOMFUNCTION_GUIINIT onGUIInit
!insertmacro MUI_LANGUAGE French
;--------------------------------
;Version Information
    VIProductVersion "2.0.0.0"
    VIAddVersionKey  "FileDescription"  "Installateur configurable avec temporisation"
    VIAddVersionKey  "FileVersion"      "2.0.0.0"
    VIAddVersionKey  "ProductName"      "Setup_auto"
    VIAddVersionKey  "ProductVersion"   "2.0.0.0"
    VIAddVersionKey  "LegalCopyright"   "©2017 Noël MARTINON - GPLv3"
    VIAddVersionKey  "OriginalFilename" "setup_auto.exe"
    VIAddVersionKey  "Comments"         "Permet de proposer l'installation d'une application que l'utilisateur peut soit accepter soit refuser. \
    Sans réponse, l'exécution est automatique après un délai défini."
    VIAddVersionKey  "CompanyName"      "Noël MARTINON"
;--------------------------------

var PROGBAR
var INSTDETAIL
var timer_total
var timer_remain
var timer_elapse
var button_text
var detail_text

var _BRANDING_TEXT
var _NAME
var _VERSION
var _COMMAND
var _ABORT_ON_PREINSTALL_ERROR
var _ABORT_INSTALLED_NAME
var _ABORT_INSTALLED_VERSION
var _ABORT_ON_UNINSTALL_ERROR
var _AUTO_SILENT
var _UN_NAME
var _UN_VERSION
var _UN_ARGUMENTS
var _UN_ARGUMENTS_MSIEXEC
var _INFO_INSTALL_START
var _INFO_INSTALL_END_OK
var _INFO_INSTALL_END_ERROR
var _TIMER_INSTALL_START
var _TIMER_INSTALL_END
var _QUIT_PROCESS_RUNNING

var configfile
var errorlevel
var hidetext_cmd
var alwaysok_cmd
var PreInstallErrors
var OtherInstallErrors ;set if errors in LaunchOtherInstall
var IsAlreadyInstalled
var app_installed_name
var app_installed_version
var app_installed_uninstallstring
var app_ignore_list
var registry_uninstall_path
var registry_64done

; Increase the width and height by these units:
!define AddWidth -20u
!define AddHeight -30u

!define DEFAULT_TIMER_INSTALL_START 90
!define DEFAULT_TIMER_INSTALL_END 15

${StrRep}
!insertmacro REMatches

Page Custom custom.page1
Page Custom custom.page2
Page Custom custom.page3

# ----------------------------------------------------------------
# Macro : Append text to richedit (and to $detail_text)
# ----------------------------------------------------------------
!define RichEditAppend `!insertmacro RichEditAppend`
!macro RichEditAppend Handle Text
    # If necessary, set empty text in richedit to remove "Please wait..."
    StrCmp "$detail_text" "" +1 +2
    SendMessage ${Handle} ${WM_SETTEXT} 0 "STR:"
    
    SendMessage ${Handle} ${EM_SETSEL} 0x7fffffff -1
    SendMessage ${Handle} ${EM_REPLACESEL} 0 "STR:${Text}"
    StrCpy $detail_text "$detail_text${Text}"
!macroend

# ----------------------------------------------------------------
# Function : StrContains - Searches for an occurrence of a substring in a string
# ----------------------------------------------------------------
; StrContains
; This function does a case sensitive searches for an occurrence of a substring in a string.
; It returns the substring if it is found.
; Otherwise it returns null("").
; Written by kenglish_hi
; Adapted from StrReplace written by dandaman32

!define StrContains '!insertmacro "_StrContainsConstructor"'
!macro _StrContainsConstructor OUT NEEDLE HAYSTACK
  Push `${HAYSTACK}`
  Push `${NEEDLE}`
  Call StrContains
  Pop `${OUT}`
!macroend

Var STR_HAYSTACK
Var STR_NEEDLE
Var STR_CONTAINS_VAR_1
Var STR_CONTAINS_VAR_2
Var STR_CONTAINS_VAR_3
Var STR_CONTAINS_VAR_4
Var STR_RETURN_VAR

Function StrContains
  Exch $STR_NEEDLE
  Exch 1
  Exch $STR_HAYSTACK
  ; Uncomment to debug
  ;MessageBox MB_OK 'STR_NEEDLE = $STR_NEEDLE STR_HAYSTACK = $STR_HAYSTACK '
    StrCpy $STR_RETURN_VAR ""
    StrCpy $STR_CONTAINS_VAR_1 -1
    StrLen $STR_CONTAINS_VAR_2 $STR_NEEDLE
    StrLen $STR_CONTAINS_VAR_4 $STR_HAYSTACK
    loop:
      IntOp $STR_CONTAINS_VAR_1 $STR_CONTAINS_VAR_1 + 1
      StrCpy $STR_CONTAINS_VAR_3 $STR_HAYSTACK $STR_CONTAINS_VAR_2 $STR_CONTAINS_VAR_1
      StrCmp $STR_CONTAINS_VAR_3 $STR_NEEDLE found
      StrCmp $STR_CONTAINS_VAR_1 $STR_CONTAINS_VAR_4 done
      Goto loop
    found:
      StrCpy $STR_RETURN_VAR $STR_NEEDLE
      Goto done
    done:
   Pop $STR_NEEDLE ;Prevent "invalid opcode" errors and keep the
   Exch $STR_RETURN_VAR
FunctionEnd

# ----------------------------------------------------------------
# Function : Search application in registry (32 and 64bits)
# ----------------------------------------------------------------
; NOTA : <Name> argument can be a Perl Compatible Regular Expressions (pcre)

!define IsAppInstall "!insertmacro IsAppInstall"
!macro IsAppInstall Name Version
  Push "${Version}"
  Push "${Name}"
  Call IsAppInstall
!macroend

Function IsAppInstall
                              ; Stack: <Name> <Version>
    ClearErrors
    ; Notice we are preserving registers $0, $1 ... $5
    Exch $0                     ; Stack: $0 <Version> & $0=<Name>
    Exch                        ; Stack: <Version> $0
    Exch $1                     ; Stack: $1 $0 & $1=<Version>
    Push $2                     ; Stack: $2 $1 $0
    Push $3                     ; Stack: $3 $2 $1 $0
    Push $4                     ; Stack: $4 $3 $2 $1 $0
    Push $5                     ; Stack: $5 $4 $3 $2 $1 $0
    Push $R0                    ; Stack: $R0 $5 $4 $3 $2 $1 $0
    Push $R1                    ; Stack: $R1 $R0 $5 $4 $3 $2 $1 $0
    ; $0 = Name
    ; $1 = Version
    
    StrCpy $R0 $0
    StrCpy $R1 $1

    StrCpy $IsAlreadyInstalled 0
    StrCpy $app_installed_name ""
    StrCpy $app_installed_version ""
    StrCpy $app_installed_uninstallstring ""
    
    SetRegView 32
    StrCpy $registry_64done 0
    StrCpy $registry_uninstall_path "Software\Microsoft\Windows\CurrentVersion\Uninstall"
    StrCpy $0 0
    loop_keys: ;while key != ""
        EnumRegKey $1 HKLM $registry_uninstall_path $0
        StrCmp $1 "" done
        IntOp $0 $0 + 1
        StrCpy $2 0
        loop_values: ;while value != "DisplayName"
            ClearErrors
            EnumRegValue $3 HKLM $registry_uninstall_path\$1 $2
            IfErrors loop_keys
            IntOp $2 $2 + 1
            StrCmp $3 "DisplayName" "" loop_values
            ReadRegStr $4 HKLM $registry_uninstall_path\$1 $3
            ${If} $4 == "$R0" ; verify strings are the same
            ${OrIf} $4 =~ "$R0" ; or verify $4 matches pattern $R0 (pcre regular expression)
                ReadRegStr $5 HKLM $registry_uninstall_path\$1 "DisplayVersion"
                
                ${If} $5 != ""
                    ${StrContains} $6 "+$4 (v$5)" $app_ignore_list
                    StrCmp $6 "" 0 loop_keys
                ${Else}
                    ${StrContains} $6 "+$4" $app_ignore_list
                    StrCmp $6 "" 0 loop_keys
                ${EndIf}

                ; case no version specified then matched by name only
                ${If} "$R1" == ""
                    ReadRegStr $app_installed_uninstallstring HKLM $registry_uninstall_path\$1 "UninstallString"
                    StrCpy $app_installed_name $4
                    StrCpy $app_installed_version $5
                    StrCpy $IsAlreadyInstalled 1
                    goto done
                ${EndIf}

                ; case version not empty
                StrCmp $5 "" loop_values
                ${If} $5 == "$R1"
                    ReadRegStr $app_installed_uninstallstring HKLM $registry_uninstall_path\$1 "UninstallString"
                    StrCpy $app_installed_name $4
                    StrCpy $app_installed_version $5
                    StrCpy $IsAlreadyInstalled 1
                    goto done
                ${EndIf}
            ${EndIf}
        goto loop_keys
    done:
        ${If} ${RunningX64}
        ${AndIf} $IsAlreadyInstalled == 0
        ${AndIf} $registry_64done == 0
        SetRegView 64
            StrCpy $registry_64done 1
            StrCpy $0 0
            goto loop_keys
        ${EndIf}

        ; restore memory
        Pop $R1                    ; Stack: $R0 $5 $4 $3 $2 $1 $0
        Pop $R0                    ; Stack: $5 $4 $3 $2 $1 $0
        Pop $5                     ; Stack: $4 $3 $2 $1 $0
        Pop $4                     ; Stack: $3 $2 $1 $0
        Pop $3                     ; Stack: $2 $1 $0
        Pop $2                     ; Stack: $1 $0
        Pop $1                     ; Stack: $0
        Pop $0                     ; Stack: -empty-
FunctionEnd

# ----------------------------------------------------------------
# Function : Get all entries in section of INI file
# Author: nechai
# http://nsis.sourceforge.net/Get_all_entries_in_section_of_INI_file
# ----------------------------------------------------------------
!define GetSection `!insertmacro GetSectionCall`

!macro GetSectionCall _FILE _SECTION _FUNC
    Push $0
    Push `${_FILE}`
    Push `${_SECTION}`
    GetFunctionAddress $0 `${_FUNC}`
    Push `$0`
    Call GetSection
    Pop $0
!macroend

Function GetSection
    Exch $2
    Exch
    Exch $1
    Exch
    Exch 2
    Exch $0
    Exch 2
    Push $3
    Push $4
    Push $5
    Push $6
    Push $8
    Push $9

    System::Alloc 1024
    Pop $3
        StrCpy $4 $3

        System::Call "kernel32::GetPrivateProfileSectionA(t, i, i, t) i(r1, r4, 1024, r0) .r5"

    enumok:
        System::Call 'kernel32::lstrlenA(t) i(i r4) .r6'
    StrCmp $6 '0' enumex

    System::Call '*$4(&t1024 .r9)'

    Push $0
    Push $1
    Push $2
    Push $3
    Push $4
    Push $5
    Push $6
    Push $8
    Call $2
    Pop $9
    Pop $8
    Pop $6
    Pop $5
    Pop $4
    Pop $3
    Pop $2
    Pop $1
    Pop $0
        StrCmp $9 'StopGetSection' enumex

    IntOp $4 $4 + $6
    IntOp $4 $4 + 1
    goto enumok

    enumex:
    System::Free $3

    Pop $9
    Pop $8
    Pop $6
    Pop $5
    Pop $4
    Pop $3
    Pop $2
    Pop $1
    Pop $0
FunctionEnd

# ----------------------------------------------------------------
# Default install section
# ----------------------------------------------------------------
Section
SectionEnd

# ----------------------------------------------------------------
# Function : .onInit
# ----------------------------------------------------------------
Function .onInit

    call MsgHelp
    StrCpy $configfile "$EXEDIR\setup_auto.ini"
    ${GetParameters} $0
    ClearErrors
    ${GetOptions} $0 "/config" $1
    ${IfNot} ${Errors}
        ${If} $1 != ""
            StrCpy $configfile $1
        ${ElseIf} $1 == ""
            StrCpy $configfile "config_empty_arg"
        ${EndIf}
    ${EndIf}
    
    ${If} $configfile == "config_empty_arg"
        Messagebox MB_OK|MB_ICONSTOP "Erreur !$\nAucun fichier de configuration spécifié"
        SetErrorLevel 2
        Quit
    ${EndIf}

    IfFileExists $configfile +4 0
        Messagebox MB_OK|MB_ICONSTOP "Erreur !$\nImpossible d'ouvrir le fichier de configuration $configfile"
        SetErrorLevel 2
        Quit
    
    StrCpy $errorlevel 0
    StrCpy $PreInstallErrors 0
    StrCpy $OtherInstallErrors 0

    ReadINIStr $_TIMER_INSTALL_START $configfile "Setup" "TIMER_INSTALL_START"
    ReadINIStr $_TIMER_INSTALL_END $configfile "Setup" "TIMER_INSTALL_END"
    ReadINIStr $_BRANDING_TEXT $configfile "Setup" "BRANDING_TEXT"
    ReadINIStr $_INFO_INSTALL_START $configfile "Setup" "INFO_INSTALL_START"
    ReadINIStr $_INFO_INSTALL_END_OK $configfile "Setup" "INFO_INSTALL_END_OK"
    ReadINIStr $_INFO_INSTALL_END_ERROR $configfile "Setup" "INFO_INSTALL_END_ERROR"
    ReadINIStr $_QUIT_PROCESS_RUNNING $configfile "Setup" "QUIT_PROCESS_RUNNING"
    ReadINIStr $_AUTO_SILENT $configfile "Setup" "AUTO_SILENT"

    ReadINIStr $_ABORT_ON_PREINSTALL_ERROR $configfile "PreInstall" "ABORT_INSTALLATION_ON_ERROR"
    
    ReadINIStr $_UN_NAME $configfile "UnInstall" "NAME"
    ReadINIStr $_UN_VERSION $configfile "UnInstall" "VERSION"
    ReadINIStr $_UN_ARGUMENTS $configfile "UnInstall" "ARGUMENTS"
    ReadINIStr $_UN_ARGUMENTS_MSIEXEC $configfile "UnInstall" "ARGUMENTS_MSIEXEC"
    ReadINIStr $_ABORT_ON_UNINSTALL_ERROR $configfile "UnInstall" "ABORT_INSTALLATION_ON_ERROR"

    ReadINIStr $_NAME $configfile "Install" "NAME"
    ReadINIStr $_VERSION $configfile "Install" "VERSION"
    ReadINIStr $_COMMAND $configfile "Install" "COMMAND"
    ReadINIStr $_ABORT_INSTALLED_NAME $configfile "Install" "ABORT_INSTALLED_NAME"
    ReadINIStr $_ABORT_INSTALLED_VERSION $configfile "Install" "ABORT_INSTALLED_VERSION"
    
    # Set current working directory to $EXEDIR (useful in case setup_auto is launched by a windows service)
    SetOutPath $EXEDIR
    ;System::Call "kernel32::GetCurrentDirectory(i ${NSIS_MAX_STRLEN}, t .r0)"
    ;MessageBox MB_OK "$0"

    ${If} $_NAME == ""
    ${OrIf} $_COMMAND == ""
        Quit
    ${EndIf}

    ${If} $_QUIT_PROCESS_RUNNING != ""
        ${nsProcess::FindProcess} "$_QUIT_PROCESS_RUNNING" $R0
	StrCmp $R0 0 0 +2
            Quit
    ${EndIf}

    ${If} $_INFO_INSTALL_START == ""
        StrCpy $_INFO_INSTALL_START "Le logiciel %NAME% va être installé."
    ${EndIf}

    ${If} $_INFO_INSTALL_END_OK == ""
        StrCpy $_INFO_INSTALL_END_OK "Le logiciel %NAME% a été installé avec succès."
    ${EndIf}

    ${If} $_INFO_INSTALL_END_ERROR == ""
        StrCpy $_INFO_INSTALL_END_ERROR "Le logiciel %NAME% n'a pas pu être installé."
    ${EndIf}
    
    # If already installed then abort
    ${If} $_ABORT_INSTALLED_NAME != ""
        ${IsAppInstall} $_ABORT_INSTALLED_NAME $_ABORT_INSTALLED_VERSION
        Strcmp $IsAlreadyInstalled 1 0 +2
            Quit
    ${EndIf}
    
    ; AUTO_SILENT is only running if there no "uninstall" ($_UN_NAME) program to remove
    ${If} $_AUTO_SILENT == 1
    ${AndIf} $_UN_NAME != ""
        ${IsAppInstall} $_UN_NAME $_UN_VERSION
        StrCmp $IsAlreadyInstalled 1 endif_silent 0
        ${GetSection} $configfile "preinstall" LaunchOtherInstall
        ${If} $_ABORT_ON_PREINSTALL_ERROR == 1
        ${AndIf} $OtherInstallErrors == 1
            SetErrorLevel 2
            Quit
        ${EndIf}
        ClearErrors
        ExecWait '$_COMMAND' $errorlevel
        IfErrors errinst_silent
        SetErrorLevel $errorlevel
        ${GetSection} $configfile "postinstall" LaunchOtherInstall
        Quit
        
        errinst_silent:
        Messagebox MB_OK|MB_ICONSTOP "Erreur !$\nImpossible d'exécuter la commande d'installation de l'application $_NAME"
        SetErrorLevel 2
        Quit

        endif_silent:
    ${EndIf}
FunctionEnd

# ----------------------------------------------------------------
# Function : onGUIInit
# ----------------------------------------------------------------
Function onGUIInit
    ${nsResize_Window} ${AddWidth} ${AddHeight}
    call CenterNSISMainWindowOnNearestMonitor
    call SetWindowOnTop
FunctionEnd

# ----------------------------------------------------------------
# Function : custom.page1 - Dialogbox 1/3 - Countdown before automatic installation
# ----------------------------------------------------------------
Function custom.page1
    # Set TOPMOST window
    System::Call "User32::SetWindowPos(i, i, i, i, i, i, i) b ($HWNDPARENT, -1, 0, 0, 0, 0, 0x0001|0x0002)"
    
    SendMessage $HWNDPARENT ${WM_SETTEXT} 0 "STR:Installation de $_NAME"
    !insertmacro MUI_HEADER_TEXT "Installation automatique" "Souhaitez-vous installer le logiciel maintenant ?"

    # Change branding text
    ${If} $_BRANDING_TEXT != ""
        SendMessage $mui.Branding.Text ${WM_SETTEXT} 0 "STR:$_BRANDING_TEXT" ;GetDlgItem $0 $HWNDPARENT 1028 / SendMessage $0...
        SendMessage $mui.Branding.Background ${WM_SETTEXT} 0 "STR:$_BRANDING_TEXT " ;GetDlgItem $0 $HWNDPARENT 1256 / SendMessage $0...
    ${EndIf}

    StrCpy $button_text "&Installer"
    SendMessage $mui.Button.Next ${WM_SETTEXT} 0 "STR:$button_text" ;GetDlgItem $0 $hwndparent 1
    ;FindWindow $R0 `#32770` `` $HWNDPARENT
    ;GetDlgItem $R0 $R0 1006
    nsResize::Add $mui.Button.Next -4u 0 4u 0

    nsDialogs::Create 1018
    Pop $0
    ${If} $0 == error
        Abort
    ${EndIf}

    ${NSD_CreateLabel} 0 0 100% 13u "$_NAME $_VERSION"
    Pop $0
    ${NSD_AddStyle} $0 ${SS_RIGHT}
    CreateFont $1 "$(^Font)" 10 600
    SendMessage $0 ${WM_SETFONT} $1 1

    nsDialogs::CreateControl "RichEdit20A" ${WS_VISIBLE}|${WS_CHILD}|${WS_VSCROLL}|\
    ${ES_MULTILINE}|${ES_WANTRETURN}|${ES_READONLY} ${WS_EX_STATICEDGE} 0 17u 100% -22u ""
    Pop $0
 
    # Convert strings
    ${StrRep} '$1' '$_INFO_INSTALL_START' '\n' '$\n'
    ${StrRep} '$1' '$1' '%name%' '$_NAME'
    ${StrRep} '$1' '$1' '%version%' '$_VERSION'

    # Set text in richedit
    SendMessage $0 ${WM_SETTEXT} 0 "STR:$1"

    # Create timer progressbar
    ${NSD_CreateProgressBar} 0u -5u 100% 2u ""
    Pop $PROGBAR

    # Set timer values
    ${If} $_TIMER_INSTALL_START != ""
        StrCpy $timer_total $_TIMER_INSTALL_START
    ${Else}
        StrCpy $timer_total ${DEFAULT_TIMER_INSTALL_START}
    ${EndIf}
    StrCpy $timer_remain $timer_total
    
    # Create timer
    ${NSD_CreateTimer} Countdown_Timer 1000

    nsDialogs::Show
FunctionEnd

# ----------------------------------------------------------------
# Function : custom.page2 - Dialogbox 2/3 - Progression of the installation
# ----------------------------------------------------------------
Function custom.page2
    # Set NOTOPMOST window
    System::Call "User32::SetWindowPos(i, i, i, i, i, i, i) b ($HWNDPARENT, -2, 0, 0, 0, 0, 0x0001|0x0002)"
    
    SendMessage $HWNDPARENT ${WM_SETTEXT} 0 "STR:Installation de $_NAME"
    !insertmacro MUI_HEADER_TEXT "Installation en cours" "Veuillez patienter pendant le processus d'installation svp"

    nsDialogs::Create 1018
    Pop $0

    # Create bold label "Name version" on top right window
    ${NSD_CreateLabel} 0 0 100% 13u "$_NAME $_VERSION"
    Pop $0
    ${NSD_AddStyle} $0 ${SS_RIGHT}
    CreateFont $1 "$(^Font)" 10 600
    SendMessage $0 ${WM_SETFONT} $1 1

    # Set post-installation text
    nsDialogs::CreateControl "RichEdit20A" ${WS_VISIBLE}|${WS_CHILD}|${WS_VSCROLL}|\
    ${ES_MULTILINE}|${ES_WANTRETURN}|${ES_READONLY} ${WS_EX_STATICEDGE} 0 17u 100% -22u ""
    Pop $INSTDETAIL
    
    # Set initial text in richedit
    SendMessage $INSTDETAIL ${WM_SETTEXT} 0 "STR:Veuillez patienter..."
    
    ${NSD_CreateProgressBar} 0u -5u 100% 2u ""
    Pop $0
    !define PBS_MARQUEE 0x08
    ${NSD_AddStyle} $0 ${PBS_MARQUEE}
    SendMessage $0 ${PBM_SETMARQUEE} 1 50

    # Set buttons states
    ShowWindow $mui.Button.Back 0
    EnableWindow $mui.Button.Back 0
    EnableWindow $mui.Button.Cancel 0
    EnableWindow $mui.Button.Next 0
    
    # Create onShow timer
    ${NSD_CreateTimer} custom.page2_onShow 10

    nsDialogs::Show
FunctionEnd

# ----------------------------------------------------------------
# Function : custom.page2_onShow - Stop countdown and launch installation
# ----------------------------------------------------------------
Function custom.page2_onShow
    ${NSD_KillTimer} custom.page2_onShow
    ${NSD_KillTimer} Countdown_Timer

    GetFunctionAddress $0 LaunchInstall
    BgWorker::CallAndWait
FunctionEnd

# ----------------------------------------------------------------
# Function : custom.page3 - Dialogbox 3/3 - Summary of the installation
# ----------------------------------------------------------------
Function custom.page3
    SendMessage $HWNDPARENT ${WM_SETTEXT} 0 "STR:Installation de $_NAME"
    !insertmacro MUI_HEADER_TEXT "Installation terminée" "Succès"

    ${If} $errorlevel != 0
        !insertmacro MUI_HEADER_TEXT "Echec de l'installation" "Erreur $errorlevel"
    ${ElseIf} $PreInstallErrors == 1
        !insertmacro MUI_HEADER_TEXT "Echec de l'installation" "Des erreurs de tâches préparatoires se sont produites"
    ${ElseIf} $OtherInstallErrors == 1
        !insertmacro MUI_HEADER_TEXT "Installation terminée" "Succès mais des erreurs de tâches secondaires se sont produites"
    ${EndIf}

    nsDialogs::Create 1018
    Pop $0

    # Hide and disable previous button
    ShowWindow $mui.Button.Back 0
    EnableWindow $mui.Button.Back 0

    # Hide cancel button
    ShowWindow $mui.Button.Cancel 0
    EnableWindow $mui.Button.Cancel 0

    # Change close button text
    SendMessage $mui.Button.Next ${WM_SETTEXT} 0 "STR:$(^CloseBtn)"
    ${NSD_GetText} $mui.Button.Next $button_text

    # Move close button to cancel button position
    nsResize::GetPos $mui.Button.Cancel
    Pop $1
    Pop $2
    nsResize::GetSize $mui.Button.Cancel
    Pop $3
    Pop $4
    IntOp $3 $3 - $1
    IntOp $4 $4 - $2
    nsResize::Set $mui.Button.Next $1 $2 $3 $4
    nsResize::Add $mui.Button.Next -4u 0 4u 0

    # Create bold label "Name version" on top right window
    ${NSD_CreateLabel} 0 0 100% 13u "$_NAME $_VERSION"
    Pop $0
    ${NSD_AddStyle} $0 ${SS_RIGHT}
    CreateFont $1 "$(^Font)" 10 600
    SendMessage $0 ${WM_SETFONT} $1 1

    # Set post-installation text
    nsDialogs::CreateControl "RichEdit20A" ${WS_VISIBLE}|${WS_CHILD}|${WS_VSCROLL}|\
    ${ES_MULTILINE}|${ES_WANTRETURN}|${ES_READONLY} ${WS_EX_STATICEDGE} 0 17u 100% -22u ""
    Pop $0

    ${If} $errorlevel == 0
    ${AndIf} $PreInstallErrors == 0
        ${StrRep} '$1' '$_INFO_INSTALL_END_OK' '\n' '$\n'
        ${StrRep} '$1' '$1' '%name%' '$_NAME'
        ${StrRep} '$1' '$1' '%version%' '$_VERSION'
    ${Else}
        ${StrRep} '$1' '$_INFO_INSTALL_END_ERROR' '\n' '$\n'
        ${StrRep} '$1' '$1' '%name%' '$_NAME'
        ${StrRep} '$1' '$1' '%version%' '$_VERSION'
        SendMessage $0 ${WM_SETTEXT} 0 "STR:$1"
    ${EndIf}
    SendMessage $0 ${WM_SETTEXT} 0 "STR:$detail_text$\n$1"

    # Create timer progressbar
    ${NSD_CreateProgressBar} 0u -5u 100% 2u ""
    Pop $PROGBAR

    # Set timer values
    ${If} $_TIMER_INSTALL_END != ""
        StrCpy $timer_total $_TIMER_INSTALL_END
    ${Else}
        StrCpy $timer_total ${DEFAULT_TIMER_INSTALL_END}
    ${EndIf}
    StrCpy $timer_remain $timer_total ; need before new function call Countdown_Timer
    StrCpy $timer_elapse 0

    # Create timer
    ${NSD_CreateTimer} Countdown_Timer 1000

    nsDialogs::Show
FunctionEnd

# ----------------------------------------------------------------
# Function : LaunchInstall - Launch main installation process
# ----------------------------------------------------------------
Function LaunchInstall
    ${GetSection} $configfile "preinstall" LaunchOtherInstall
    ${If} $_ABORT_ON_PREINSTALL_ERROR == 1
    ${AndIf} $OtherInstallErrors == 1
        ${RichEditAppend} $INSTDETAIL  "- Installation du logiciel...ABANDONNÉE$\n"
        SetErrorLevel 2
        StrCpy $PreInstallErrors 1
        goto end
    ${EndIf}

    StrCmp $_UN_NAME "" install

    ; here $app_installed_name $app_installed_version and $app_installed_uninstallstring are set if app is installed :
    ${IsAppInstall} $_UN_NAME $_UN_VERSION
    StrCmp $IsAlreadyInstalled 1 0 install

    uninstall:
    ${If} $app_installed_version != ""
        StrCpy $app_installed_version " (v$app_installed_version)"
    ${EndIf}

    ${RichEditAppend} $INSTDETAIL "- Désinstallation de $app_installed_name$app_installed_version..."
    ; case UninstallString start with 'msiexec' then replace /I with /X and $_UN_ARGUMENTS with specific $_UN_ARGUMENTS_MSIEXEC
    ${If} $app_installed_uninstallstring =~ "(?i)^msiexec.*"
        ${StrRep} '$app_installed_uninstallstring' '$app_installed_uninstallstring' '/I' '/X'
        ${StrRep} '$app_installed_uninstallstring' '$app_installed_uninstallstring' '/i' '/x'
        ${If} $_UN_ARGUMENTS_MSIEXEC != ""
            StrCpy $_UN_ARGUMENTS $_UN_ARGUMENTS_MSIEXEC
        ${EndIf}
    ${EndIf}
    ExecWait '$app_installed_uninstallstring $_UN_ARGUMENTS' $errorlevel
sleep 5000
    ${If} $errorlevel == 0
        ${RichEditAppend} $INSTDETAIL "OK$\n"
    ${Else}
        ${RichEditAppend} $INSTDETAIL "ERREUR $errorlevel$\n"
        ${If} $_ABORT_ON_UNINSTALL_ERROR == 1
            SetErrorLevel 2
            ${RichEditAppend} $INSTDETAIL  "- Installation du logiciel...ABANDONNÉE$\n"
            goto end
        ${EndIf}
    ${EndIf}
    ; Search for other installed software :
    StrCpy $app_ignore_list "$app_ignore_list+$app_installed_name$app_installed_version"
    StrCpy $IsAlreadyInstalled 0
    ${IsAppInstall} $_UN_NAME $_UN_VERSION
    StrCmp $IsAlreadyInstalled 1 uninstall 0

    install:
    ${RichEditAppend} $INSTDETAIL  "- Installation du logiciel..."
    ClearErrors
    ExecWait '$_COMMAND' $errorlevel
    IfErrors errinst_indialog
    SetErrorLevel $errorlevel
    ${If} $errorlevel == 0
        ${RichEditAppend} $INSTDETAIL "OK$\n"
        ${GetSection} $configfile "postinstall" LaunchOtherInstall
    ${Else}
        ${RichEditAppend} $INSTDETAIL "ERREUR $errorlevel$\n"
    ${EndIf}
    goto end

    errinst_indialog:
    ${RichEditAppend} $INSTDETAIL "ERREUR D'EXÉCUTION$\n"
    StrCpy $errorlevel 2
    SetErrorLevel $errorlevel

    end:
    EnableWindow $mui.Button.Next 1
    BringToFront ; Must be set to click button when dialog box is not the front of window
    GetDlgItem $0 $hwndparent 1 ;get handle of the proceed button
    SendMessage $0 ${BM_CLICK} 0 0
FunctionEnd

# ----------------------------------------------------------------
# Function : Launch pre or post installation commands
# ----------------------------------------------------------------
Function LaunchOtherInstall
    StrCpy $hidetext_cmd 0
    StrCpy $alwaysok_cmd 0

    ${RECaptureMatches} $0 "([^=]+)=(.+)" "$9" 1 ; capture command_descr and command_to_launch from ini file in $1 and $2
    StrCmp $0 2 0 endinst
    Pop $1
    Pop $2

    ${If} $_ABORT_ON_PREINSTALL_ERROR == 1
    ${AndIf} $1 == "ABORT_INSTALLATION_ON_ERROR"
        Push $0
        Return
    ${EndIf}

    ${If} $1 =~ "^HIDETEXT_ALWAYSOK_.*"
        StrCpy $hidetext_cmd 1
        StrCpy $alwaysok_cmd 1
        ${StrRep} $1 $1 "HIDETEXT_ALWAYSOK_" ""
    ${ElseIf} $1 =~ "^HIDETEXT_.*"
        StrCpy $hidetext_cmd 1
        ${StrRep} $1 $1 "HIDETEXT_" ""
    ${ElseIf} $1 =~ "^ALWAYSOK_.*"
        StrCpy $alwaysok_cmd 1
        ${StrRep} $1 $1 "ALWAYSOK_" ""
        ; Empty text is implicitly hidetext :
        ${If} $1 == ""
            StrCpy $hidetext_cmd 1
        ${EndIf}
    ${EndIf}

    ${If} $hidetext_cmd != 1
        ${RichEditAppend} $INSTDETAIL "- $1..."
    ${EndIf}
    ClearErrors
    ExecWait '$2' $0
    IfErrors errinst
    ${If} $hidetext_cmd != 1
        ${If} $0 == 0
        ${OrIf} $alwaysok_cmd == 1
            ${RichEditAppend} $INSTDETAIL "OK$\n"
        ${Else}
            StrCpy $OtherInstallErrors 1
            ${RichEditAppend} $INSTDETAIL "ERREUR $0$\n"

            ; if abort on error then return without continue section reading
            ${If} $_ABORT_ON_PREINSTALL_ERROR == 1
                Return
            ${EndIf}
        ${EndIf}
    ${EndIf}
    goto endinst

    errinst:
        ${If} $alwaysok_cmd != 1
            StrCpy $OtherInstallErrors 1
        ${EndIf}
        ${If} $hidetext_cmd != 1
            ${If} $alwaysok_cmd == 1
                ${RichEditAppend} $INSTDETAIL "OK$\n"
            ${Else}
                ${RichEditAppend} $INSTDETAIL "ERREUR D'EXÉCUTION$\n"
            ${EndIf}
        ${EndIf}
    endinst:
    Push $0 ; get next key
FunctionEnd

# ----------------------------------------------------------------
# Function : Countdown_Timer - Progressbar countdown
# ----------------------------------------------------------------
Function Countdown_Timer
    SendMessage $PROGBAR ${PBM_GETPOS} 0 0 $1
    ${If} $1 >= 100
        SendMessage $PROGBAR ${PBM_SETPOS} 0 0
        ${NSD_KillTimer} Countdown_Timer
        BringToFront ; Must be set to click button when dialog box is not the front of window
        GetDlgItem $0 $hwndparent 1 ;get handle of the proceed button
        SendMessage $0 ${BM_CLICK} 0 0
    ${Else}
        SendMessage $PROGBAR ${PBM_SETPOS} $timer_elapse 0
        GetDlgItem $0 $hwndparent 1
        SendMessage $0 ${WM_SETTEXT} 0 "STR:$button_text [$timer_remain]"
    ${EndIf}

    IntOp $timer_remain $timer_remain - 1
    IntOp $timer_elapse $timer_total - $timer_remain
    IntOp $timer_elapse $timer_elapse * 100
    IntOp $timer_elapse $timer_elapse / $timer_total
FunctionEnd

# ----------------------------------------------------------------
# Function : CenterNSISMainWindowOnNearestMonitor - Center dialog to screen
# ----------------------------------------------------------------
Function CenterNSISMainWindowOnNearestMonitor ; NSIS 2.51+
    System::Store S
    !if "${NSIS_PACKEDVERSION}" <= 0x0300003F
    System::Call '*(i,i,i,i,i,i,i,i,i,i)p.r5'
    System::Call "USER32::GetWindowRect(p$HWNDPARENT,ir5)"
    !else
    System::Call "USER32::GetWindowRect(p$HWNDPARENT,@r5)"
    !endif
    System::Call '*$5(i.r6,i.r7,i.r8,i.r9)'
    IntOp $6 $8 - $6
    IntOp $7 $9 - $7
    System::Call 'USER32::SystemParametersInfo(i0x30,i0,pr5,i0)'
    System::Call '*$5(i.r1,i.r2,i.r3,i.r4)'
    System::Call 'USER32::MonitorFromWindow(p$HWNDPARENT,i2)i.r0'
    IntCmpU $0 0 calcAndMove
    System::Call '*$5(i40)'
    System::Call 'USER32::GetMonitorInfo(pr0,pr5)i.r0'
    IntCmpU $0 0 calcAndMove
    System::Call '*$5(i,i,i,i,i,i.r1,i.r2,i.r3,i.r4)'
    calcAndMove:
    IntOp $1 $3 - $1
    IntOp $2 $4 - $2
    IntOp $6 $6 / 2
    IntOp $7 $7 / 2
    IntOp $1 $1 / 2
    IntOp $2 $2 / 2
    IntOp $1 $1 - $6
    IntOp $2 $2 - $7
    System::Call 'USER32::SetWindowPos(p$HWNDPARENT,i,ir1,ir2,i,i,i0x11)'
    !if "${NSIS_PACKEDVERSION}" <= 0x0300003F
    System::Free $5
    !endif
    System::Store L
FunctionEnd

# ----------------------------------------------------------------
# Function : SetWindowOnTop - Set window to HWND_TOP
# ----------------------------------------------------------------
Function SetWindowOnTop
    ;!define HWND_BOTTOM 1
    ;!define HWND_NOTOPMOST -2
    ;!define HWND_TOP 0
    ;!define HWND_TOPMOST -1
    ;!define SWP_NOSIZE 0x0001
    ;!define SWP_NOMOVE 0x0002
    System::Call "User32::SetWindowPos(i, i, i, i, i, i, i) b ($HWNDPARENT, 0, 0, 0, 0, 0, 0x0001|0x0002)"
FunctionEnd

# ----------------------------------------------------------------
# Function MsgHelp
# ----------------------------------------------------------------
Function MsgHelp
    StrCpy $2 0
    ${GetParameters} $0

    ClearErrors
    ${GetOptions} $0 "/help" $1
    ${IfNot} ${Errors}
        StrCpy $2 1
    ${EndIf}

    ClearErrors
    ${GetOptions} $0 "/?" $1
    ${IfNot} ${Errors}
        StrCpy $2 1
    ${EndIf}

    ${If} $2 == 1
        MessageBox MB_OK "Setup_auto - ©2017 Noël MARTINON - GPLv3$\n$\n\
        - Version : 2.0.0.0$\n\
        - Description : Installateur configurable avec temporisation$\n\
        - Commentaires : Permet de proposer l'installation d'une application que l'utilisateur peut soit accepter soit refuser. \
        Sans réponse, l'exécution est automatique après un délai défini.$\n\
        $\n\
        OPTIONS :$\n\
        /config inifile : spécifie l'emplacement du fichier de configuration (par défaut setup_auto.ini où se trouve setup_auto.exe)$\n\
        /help ou /? : afficher cette aide$\n\
        $\n\
        VALEUR DE RETOUR (ERRORLEVEL) :$\n\
        0 - Execution normale (aucune erreur)$\n\
        1 - Installation annuler par l'utilisateur (bouton [Annuler])$\n\
        2 - Installation annuler par Setup_auto (problème d'ouverture du fichier de configuration, erreur de désinstallation, exécution impossible de la commande de préinstallation ou d'installation de l'application)$\n\
        AUTRE - errorlevel retourné par l'application à installer$\n\
        "
        Quit
    ${EndIf}
FunctionEnd
