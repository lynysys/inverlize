#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=ico\NegativeSwitcher.ico
#AutoIt3Wrapper_Compression=4
#AutoIt3Wrapper_UseX64=n
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
;#AutoIt3Wrapper_Outfile=..\..\..\Program Files (x86)\0Apps\NegativeSwitcher.exe
#include <Misc.au3>
#include <Array.au3>
#include <SendEx.au3>
#include "../Helper.au3"

Global $DesktopArea = @DesktopWidth * @DesktopHeight

If Get_Systray_Index("AutoIt - NegativeSwitcher.au3") <> 0 Then
	Print ( "Eeek, NegativeScreen.au3 exists, somehow" )
	Exit
ElseIf ( Not @Compiled And ProcessExists ( "NegativeSwitcher.exe" )) Then
	Print ( "Not Running, NegativeSwitcher.exe is already running" )
	Exit
EndIf

Const $CSIDL_LOCAL_APPDATA = 28

$localappdata = LOCAL_APPDATA()
;MsgBox(262144,'Debug line ~' & @ScriptLineNumber,'Selection:' & @lf & '$localappdata' & @lf & @lf & 'Return:' & @lf & $localappdata & @lf & @lf & '@Error:' & @lf & @Error) ;### Debug MSGBOX
;Exit

Func _SelfRestart() ; restart the app
	;Local $iMsgBoxAnswer = MsgBox(308, "Restarting...", "Are you sure you want to restart?")
	;If $iMsgBoxAnswer <> 6 Then Return ; Not Yes so return
	If @Compiled Then
		Run(FileGetShortName(@ScriptFullPath))
	Else
		Run(FileGetShortName(@AutoItExe) & " " & FileGetShortName(@ScriptFullPath))
	EndIf
	Exit
EndFunc   ;==>_SelfRestart

HotKeySet("+!^w", "WhiteListThisWindow")

;HotKeySet("{ESC}", "_MyExit" )

Func _MyExit ()
	Exit
EndFunc

Local $hDLL = DllOpen("user32.dll")
Opt("WinTitleMatchMode", 3)

$ConfigFile = $localappdata & "\NegativeScreenWhitelist.cfg"
TraySetIcon(@ScriptDir & "/ico/NegativeSwitcher.ico")

Global $sLines = FileReadToArray($ConfigFile) ; Slurp Config

Dim $aTitles[1], $aClasses[1], $aFlagIGNORE[1]
Dim $iLine=0

For $sLine In $sLines
	$iLine=$iLine+1

	If StringRegExp ( $sLine, "^\s*#" ) Or StringRegExp ( $sLine, "^\s*$" ) Then
		;Print ( "Ignoring line " & $sLine )
		ContinueLoop
	EndIf

	$aLine=StringSplit ( $sLine, "," ,2 ) ;2=ZERO BASED
	_ArrayAdd ( $aTitles, $aLine [2] )
	_ArrayAdd ( $aClasses, $aLine [1] )

	If Asc (StringLeft ( $aLine[0], 1 )) = Asc ( "I" ) Then
		Print ($iLine & " is an IGNORE rule")
		_ArrayAdd ( $aFlagIGNORE, 1)
	Else
		_ArrayAdd ( $aFlagIGNORE, 0)
	EndIf

	If	StringRegExp ( $aLine [2], "^\s*$" ) And _
		StringRegExp ( $aLine [1], "^\s*$" ) Then
			Msg ( "Error on Line " & $iLine & " CLASS and TITLE cannot both be blank" )
			Exit
	EndIf

	Print ( "Error in array add is " & @error )
	Print ( $aLine [1] )
Next

$Count = UBound($aTitles)
ConsoleWrite($Count & " Titles in the whitelist" & @CRLF)

For $i = 0 To $Count - 1 ; Subtract 1 to avoid Out of Bounds Error
	ConsoleWrite($aTitles[$i] & @CRLF)
Next

Global $Active = 0
$PollInterval = 25 ; Now we can look less often

Func WA($title)
	Return WinActive($title)
EndFunc   ;==>WA

Print ( "ICT = " &UBound($aFlagIGNORE) &","& UBound($aClasses) &","& UBound($aTitles))

ConsoleWrite ( "Entered Main Loop...." & @CRLF )

While True


	$thisTitle = WinGetTitle("[ACTIVE]")
	$thisClass = _WinGetClass ( $thisTitle )

	Local $Blank=0
	If ( $thisClass == "" ) Then
		$IDXclass = 0
		$Blank=1
	Else
		$IDXclass = _ArraySearch($aClasses, $thisClass )
	EndIf

	If ( $thisTitle == "" ) Then
		$IDXtitle = 0
		$Blank=1			; Do not interpret blank titles as blankness!
	Else
		$IDXtitle = _ArraySearch($aTitles, $thisTitle )
	EndIf

	$iArea = WinGetVisibleArea (WinGetPos ( "[ACTIVE]" ))

	;ConsoleWrite ( "IDX Class=" & $IDXclass & " , " & $IDXtitle & "  , Title=" & $thisTitle & " , class= " & $thisClass & @CRLF)

	Local $IDX = -1
	If	( $IDXtitle >= 0 ) Then $IDX = $IDXtitle		; Prelude to finding out whether
	If  ( $IDXclass >= 0 ) Then $IDX = $IDXclass		; we ignore this IDX or CLASS
	If	( $IDX <> -1 And $aFlagIGNORE [$IDX] <> 1 And $Blank <> 1 And $iArea > $DesktopArea/2 And $iArea < $DesktopArea*$DesktopArea ) Then
		Print ( "T,C,I = " & $IDXTitle &","& $IDXclass & ","& $IDX )
		If ($Active = 0) Then
			ConsoleWrite("**ACTIVE (" & $thisTitle & ") area= " & $iAREA)
			ConsoleWrite(" class='" & $thisClass & "'" & @CRLF)
			$Active = 1
			_SendEx("#s")
		EndIf
	ElseIf ($Active = 1 And ( $IDX == -1 Or $aFlagIGNORE [$IDX] <> 1 ) And $iArea > $DesktopArea/2 And $iArea < $DesktopArea*$DesktopArea ) Then ; If not in the Whitelist but Active
		Print ( "T,C,I = " & $IDXTitle &","& $IDXclass & ","& $IDX )

		;If $iArea > $DesktopArea/2 Then
			ConsoleWrite("inACTIVE (saw: " & $thisTitle & ") area= " & $iAREA)
			ConsoleWrite(" class='" & $thisClass & "'" & @CRLF)
			_SendEx("#s")
			$Active = 0
		;EndIf
	EndIf

	Sleep($PollInterval)

WEnd

Func WinGetVisibleArea ( $aXYWH )
	Return $aXYWH [2] * $aXYWH [3]
EndFunc


Func WhiteListThisWindow()
	;_ArrayDisplay ( $sLines )

	$sWhatToWhiteList=""

	$iWhitelistClass = MsgBox ( $MB_YESNOCANCEL, "Would you like to whitelist the entire class?", _
	"YES = WHITELIST " & $thisClass & " CLASS" & @CRLF & "NO = WHITELIST ON WINDOW TITLE" & @CRLF _
	& "CANCEL = REFRESH PROGRAM AFTER CONFIG FILE CHANGE" )

	If 		( $iWhitelistClass = $IDYES ) Then
		Msg ( "Class WhiteListing is not yet implemented!")
	ElseIf	( $iWhitelistClass = $IDCANCEL ) Then
		_SelfRestart()
	Else
		$IDX = _ArraySearch($aTitles, "^"& $thisTitle &"$",0,0,0,3)
		If $IDX >= 0 Then
			Msg("Already Whitelisted: " & $thisTitle & @CRLF)
			Return
		EndIf

		ConsoleWrite("Entered WHITELISTTHISWINDOW" & @CRLF)
		$thisTitle = WinGetTitle("")

		FileWrite($ConfigFile, @CRLF & ",," & $thisTitle )
	EndIf

	_SelfRestart()


EndFunc   ;==>WhiteListThisWindow

Func LOCAL_APPDATA()
	Return SHGetSpecialFolderPath($CSIDL_LOCAL_APPDATA)
EndFunc   ;==>LOCAL_APPDATA

Func SHGetSpecialFolderPath($csidl)
	;hwndOwner
	;Reserved.

	;lpszPath
	;[out] A pointer to a null-terminated string that receives the drive and path of the
	;specified folder. This buffer must be at least MAX_PATH characters in size.

	;csidlelist
	;[in] A CSIDL that identifies the folder of interest. If a virtual folder is specified
	;, this function will fail.

	;fCreate
	;[in] Indicates whether the folder should be created if it does not already exist. If
	;this value is nonzero, the folder is created. If this value is zero, the folder is
	;not created.
	Local $hwndOwner   = 0, $lpszPath = "", $fCreate = False, $MAX_PATH = 260
	$lpszPath = DllStructCreate("char[" & $MAX_PATH & "]")

	$BOOL = DllCall("shell32.dll", "int", "SHGetSpecialFolderPath", "int", $hwndOwner, "ptr", DllStructGetPtr($lpszPath), "int", $csidl, "int", $fCreate)
	If Not @error Then


		Return SetError($BOOL[0], 0, DllStructGetData($lpszPath, 1))
	Else
		Return SetError(@error, 0, 3)
	EndIf
EndFunc   ;==>SHGetSpecialFolderPath
