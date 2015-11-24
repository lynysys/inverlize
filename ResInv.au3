#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.12.0
 Author:         Luke Anderson with Supporting Code from AutoIT Forum

 Script Function:
	Invert the colour of ICONS and other resources within EXE files within
	a certain directory

#ce ----------------------------------------------------------------------------

; Script Start - Add your code below here

#include <FileListToArrayEx.au3>
#include <AutoItConstants.au3>
#include <File.au3>
#include <SendEx.au3>

Global const $sContainerFiles = "dll|exe|scr|mui|lnk"
Global const $sNonContainers = "ani|cur|bmp"
Global const $sIgnoreContents = "bin|avi|wav"

Opt ( "MustDeclareVars", 1 )

Global Const $sRHWinTitle = "Resource Hacker"
Global Const $sRH_SaveRes = "Save resources to ..."
Global Const $sRH_ReplICO = "Replace icon in"
Global Const $sResHackPath = "C:\Program Files (x86)\Resource Hacker\ResourceHacker.exe"
Global Const $sICOFXPath = "C:\Program Files (x86)\IcoFX 2\IcoFX2.exe"
Global Const $sCertUtilPath = "C:\Windows\system32\certutil.EXE"

EnsureFileExists ( $sResHackPath )
EnsureFileExists ( $sICOFXPath )
EnsureFileExists ( $sCertUtilPath )

Func EnsureFileExists ( $sPath )
	If Not FileExists ( $sPath ) Then
		MsgBox ( 0, 'File Not Found', $sPath )
		Exit
	EndIf
EndFunc

;Local $Path = "C:\Program Files (x86)"
;Local $Path = "C:\Program Files\SMPlayer"
Local $Path = "C:\Program Files\SMPlayer\mplayer"
Local $Path = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs"
Local $aArray = _FileListToArrayEx($Path, "\.(" & $sContainerFiles & "|" & $sNonContainers & ")$", 64 + 32 + 1 + 4 )

_ArrayDisplay ( $aArray )

MsgBox ( 0, "", "There are " & UBound($aArray) - 1 & " eligable files in total" )

For $i = 88 To 88 ; UBound($aArray) - 1
	Local $sResourceFile = $Path & "\" & $aArray[$i];
	If StringRegExp ( $sResourceFile, "\.lnk$" ) Then		; Dereference Shortcuts
		ConsoleWrite ( "LNK: " & $sResourceFile & @CRLF )
		ProcessIcon ( FileGetShortcut ( $sResourceFile ) [0] )
	Else
		ConsoleWrite ( "EXE: " & $sResourceFile & @CRLF )
		ProcessIcon ( $sResourceFile )
	EndIf

	;ConsoleWrite( $sResourceFile & @CRLF )
Next

Func ProcessIcon ( $sResourceFile )
	ConsoleWrite ( "Processing this Icon: " & $sResourceFile & @CRLF)

	Local $sDrive, $sDir, $sFileName, $sExtension
	_PathSplit ( $sResourceFile, $sDrive, $sDir, $sFileName, $sExtension )
	Local $sTempDir = $sDrive & "\ICO" & $sDir & $sFileName & $sExtension

	ConsoleWrite ( "TempDir = " & $sTempDir & @CRLF )

 	If FileExists ( $sTempDir & "/AllIconsInverted.txt" ) Then
 		ConsoleWrite ( "All Icons have already been inverted here" )
 		Return
 	EndIf

	DirCreate ( $sTempDir )

	ExtractIcons ( $sResourceFile, $sTempDir, $sFileName, $sExtension )
	Dim $iIcons = InvertColors ( $sTempDir )
	If $iIcons > 0 Then
		MD5Sum ( $sResourceFile )
		ReplaceIcons ( $sResourceFile, $sTempDir, $sFileName, $sExtension )
	EndIf

	RunAndClose ( "ie4uinit -ClearIconCache" )
EndFunc

Func MD5Sum ( $sResourceFile )
	Local $sCMD = "certUtil -hashfile " & $sResourceFile & " MD5"
	RunAndClose ( $sCMD )
EndFunc

Func ExtractIcons ( $sResourceFile, $sTempDir, $sFileName, $sExtension )

	FileDelete ( $sTempDir & "/*.ico" )
	FileDelete ( $sTempDir & "/res.rc" )

	Local $sLinkName = $sFileName & $sExtension
	FileChangeDir ( $sTempDir )

;~ 	ConsoleWrite ( "RESOURCE: " & $sResourceFile & @CRLF )
;~ 	ConsoleWrite ( "TEMPDIR : " & $sTempDir & @CRLF )
;~ 	ConsoleWrite ( "LINKNAME: " & $sLinkName & @CRLF )
;~ 	ConsoleWrite ( "CURR_DIR: " & @WorkingDir & @CRLF )
	ConsoleWrite ( @CRLF )

	FileCopy ( $sResourceFile, @WorkingDir & "/" & $sLinkName )

	ConsoleWrite ( "Copy this: " & $sResourceFile & @CRLF )
	ConsoleWrite ( "To this:   " & @WorkingDir & "\" & $sLinkName & @CRLF )

	If Not FileExists ( @WorkingDir & "\" & $sLinkName ) Then
		Local $hFile = FileOpen(@WorkingDir & "\" & $sLinkName, 2);; handles are best here
		FileWrite($hFile, "")
		FileClose($hFile)
	EndIf

	;FileCreateNTFSLink ( $sResourceFile, $sLinkName )

	;_ExtractIcons_via_CommandLine ( $sResourceFile, $sLinkName )

	If StringRegExp ( $sContainerFiles, "\b" & $sExtension & "\b" ) Then
		_ExtractIcons_via_GUI ( $sResourceFile, $sLinkName )
	ElseIf StringRegExp ( $sNonContainers, "\b" & $sExtension & "\b" ) Then
		FileCopy ( $sResourceFile, $sLinkName )
	EndIf

	DirCreate ( @WorkingDir & "/OutOfWay" )
	FileSetAttrib ( @WorkingDir & "/OutOfWay", "+H" )
	FileSetAttrib ( @WorkingDir & "/" & "res.rc", "+H" )

	For $ext in StringSplit ( $sIgnoreContents, "|" )
		FileSetAttrib ( @WorkingDir & "/" & "*."&$ext, "+H" )
		FileMove ( @WorkingDir & "/" & "*."&$ext, @WorkingDir & "/OutOfWay", 1 ) ; OverWrite
	Next

	FileMove ( @WorkingDir & "/" & "res.rc", @WorkingDir & "/OutOfWay", 1 ) ; OverWrite
	FileMove ( @WorkingDir & "/" & $sLinkName, @WorkingDir & "/OutOfWay", 1 ) ; OverWrite

	; FileDelete ( $sLinkName )
EndFunc

Func _ExtractIcons_via_CommandLine ( $sResourceFile, $sLinkName )
	Dim $sRHCommand = '"' & $sResHackPath & '"	 -extract "' & $sLinkName & '", Icons.rc, icongroup,,'

	RunAndClose ( $sRHCommand )
EndFunc

Func LoadAndWaitForResHacker ( $sLinkName )

	Dim $sRHCommand = '"' & $sResHackPath & '" "' & @WorkingDir & "\" & $sLinkName & '"'
	ConsoleWrite ( "Running Command: " & $sRHCommand & @CRLF )
	Run ( $sRHCommand )			; Build and Run ResHacker

	Dim $sWinTitle = $sRHWinTitle & " - " & $sLinkName
	ConsoleWrite ("Loading and waiting for " & $sWinTitle & @CRLF )
	WinWaitActive ( $sWinTitle, "", 10  )
	ConsoleWrite ( $sWinTitle & " Active" & @CRLF )

	Return $sWinTitle

EndFunc

Func ReplaceIcons ( $sResourceFile, $sTempDir, $sFileName, $sExtension )

	Local $sLinkName = $sFileName & $sExtension
	FileMove ( @WorkingDir & "/OutOfWay/" & $sLinkName, @WorkingDir , 1 ) ; OverWrite

	Dim $sWinTitle = LoadAndWaitForResHacker ( $sLinkName )
	Dim $sReplaceIconTitle = $sRH_ReplICO & " - " & $sLinkName

	For $i = 1 To CountExt ( $sTempDir, "ico" )
		If ( Not WinMenuSelectItem ( $sWinTitle, "", "&Action", "&Replace Icon ..." )) Then
			;MsgBox ( 0,'',"Cannot extract icons, please click on Icon or Icon Group", 1 )

			While ( Not WinMenuSelectItem ( $sWinTitle, "", "&Action", "&Replace Icon ..." ))
				_SendEx ( "{DOWN}" )
				Sleep ( 250 )
			WEnd
		EndIf

		WinWaitActive ( $sReplaceIconTitle )
		_SendEx ( "{TAB}" )
		_ReplaceIcon ( $sTempDir, $i )
		WinWaitActive ($sReplaceIconTitle)
		Send ( "!r" )
	Next

	WinMenuSelectItem ( $sWinTitle, "", "&File", "&Save" )
	WinClose ( $sWinTitle )

	ConsoleWrite ( @WorkingDir & "/" & $sFileName & "_original" & $sExtension & " -> " & @WorkingDir & "/OutOfWay" & @CRLF )
	ConsoleWrite ( @WorkingDir & "/" & $sLinkName & " -> " & $sResourceFile & @CRLF )

	FileMove ( @WorkingDir & "/" & $sFileName & "_original" & $sExtension, @WorkingDir & "/OutOfWay" , 1 )
	FileMove ( @WorkingDir & "/" & $sLinkName, $sResourceFile, 1)

	; Here arrow down however many icons

EndFunc

Func _ReplaceIcon ( $sTempDir, $i )
	Print ( "Replacing Icon " & $i )
	If $i > 1 Then
		_SendEx ( "{DOWN}" )
	EndIf

	_SendEx ( "!o" )
	WinWaitActive ( "Open" )
	ControlSetText ( "Open", "", "[CLASS:Edit; INSTANCE:1]", "Icon_" & $i & ".ico" )
	ControlClick ( "Open", "", "[CLASS:Button; INSTANCE:1]" )
EndFunc


Func _ExtractIcons_via_GUI ( $sResourceFile, $sLinkName )

	Dim $sWinTitle = LoadAndWaitForResHacker( $sLinkName)

	WinMenuSelectItem ( $sWinTitle, "", "&Action", "Save All Resources to a *.rc file" )

	If WinWaitActive ( $sRH_SaveRes, "", 1 ) Then		; Some files have no resources at all, make sure we didn't time out
		ControlSetText ( $sRH_SaveRes, "", "[CLASS:Edit; INSTANCE:1]", @WorkingDir & "\res.rc" )
		ControlClick ( $sRH_SaveRes, "", "[CLASS:Button; INSTANCE:1]" )
	EndIf

	WinWaitActive ( $sWinTitle )
	WinClose ( $sWinTitle )

;~ 	Local $hCtrl = ControlGetHandle ( $sWinTitle, "", $sRHTreeView )
;~ 	ConsoleWrite ( "HCTRL = " & $hCtrl & @CRLF )
;~ 	Local $hIconGroup=_GUICtrlTreeview_FindItem ( $hCtrl, "Icon", True )
;~ 	;_GUICtrlTreeView_ExpandOneLevel ( $hCtrl  )

;~ 	ConsoleWrite ( "icongroup = " & $hIconGroup & @CRLF )

EndFunc

Func RunAndClose ( $sCMDLINE )
	Local $iPID = Run ( $sCMDLINE )
	ProcessWaitClose ( $iPID )
	Local $sOutput = StdoutRead ( $iPID )

	ConsoleWrite ( $sCMDLINE & @CRLF )
	ConsoleWrite ( $sOutput & @CRLF )
EndFunc

Func InvertColors ( $sTempDir )

	Dim $iIcons = 	CountExt ( $sTempDir, "ico" )
	Dim $iCursors = CountExt ( $sTempDir, "cur" )
	Dim $iBMP = CountExt ( $sTempDir, "bmp" )
	Dim $iANI = CountExt ( $sTempDir, "ani" )

	;Dim $iAVI = CountExt ( $sTempDir, "avi" )		; Let's leave AVIs for now, eh...

	print ( "Number of Icons   = " & $iIcons )
	print ( "Number of Cursors = " & $iCursors )
	print ( "Number of Bitmaps = " & $iBMP )
	print ( "Number of AniCur  = " & $iANI )

	; File This Logic in Reverse Alphabetical order of extension
	If 		$iIcons > 0 Then
		Local $sFinalTitle = "Icon_" & $iIcons & ".ico"		; I
	ElseIf	$iIcons > 30 Then
		Return			; Include IcoFX Batching Logic
	Else
		Return
	EndIf

	If $iCursors + $iBMP + $iANI > 100 Then
		Return				; Avoid Overloading poor IcoFX
	EndIf

	;ElseIf	$iCursors > 0 Then
	;	Local $sFinalTitle = "Cursor_" & $iCursors & ".cur"	; C
	;ElseIf	$iBMP > 0 Then
	;	Local $sFinalTitle = "Bitmap_" & $iBMP & ".bmp"		; B
	;ElseIf	$iANI > 0 Then
	;	Local $sFinalTitle = "Cursor_" & $iANI & ".ani"		; A
	;Else
	;	FileWrite ( $sTempDir & "/AllIconsInverted.txt", "Written" )
	;	Return
	;EndIf

	$sFinalTitle = $sFinalTitle & " - IcoFX"
		; File This Logic in Reverse Alphabetical order of extension

	; If you change Mask here change it in File Viewer Below Also

	Opt ( "WinTitleMatchMode", 3 )
	If WinExists ( "IcoFX" ) Then
		Local $hICOFX = WinActivate ( "IcoFX" )
	Else
		Run ( $sIcoFXPath )
		Local $hICOFX = WinWaitActive ( "IcoFX" )
	EndIf

	_SendEx ( "^o" )
	WinWaitActive ( "Open" )
	ControlSetText ( "Open", "", "[CLASS:Edit; INSTANCE:1]", $sTempDir )
	ControlClick ( "Open", "", "[CLASS:Button; INSTANCE:1]" )
	_SendEx ( "!n" )		; Filename field
	_SendEx ( "+{TAB}" )	; File Chooser
	Sleep (50)
	_SendEx ( "^a" )		; Select All
	ControlClick ( "Open", "", "[CLASS:Button; INSTANCE:1]" )

	;_SendEx ( "{ENTER}" )

	Print ( "Awaiting FinalTitle: " & $sFinalTitle )

	Dim $i=0
	While Not WinExists ( $sFinalTitle )
		Sleep ( 50 )
		$i = $i + 1
		If $i >= 20 And WinActive ( "Open" ) Then
			_SendEx ( "{ENTER}" )
			$i = 0
		EndIf
	WEnd
	;MsgBox ( 0, '', "All icons loaded" )

	WinActivate ( $sFinalTitle )
	Dim $sOldTitle = $sFinalTitle
	Dim $sNewTitle = $sOldTitle

	While Not WinActive ( "IcoFX" )
		Send ( "^i^s^w" )
		While Not StringCompare ( $sOldTitle, $sNewTitle )
			$sOldTitle = $sNewTitle
			$sNewTitle = WinGetTitle ( "[ACTIVE]" )
			sleep ( 30 )
		WEnd
	WEnd

	FileWrite ( $sTempDir & "/AllIconsInverted.txt", "Written" )

	Return $iIcons

	;ControlClick ( "Open", "", "[CLASS:Button; INSTANCE:1]" )

;~ 	Local $aArray = _FileListToArrayEx($sTempDir, "\.(ico|bmp|png)$", 64 + 32 + 1 + 4 )

;~ 	For $i = 0 To UBound($aArray) - 1
;~ 		Local $sIMGFile = $sTempDir & "\" & $aArray[$i];
;~ 		Dim $sIcoFXCMD = '"' & $sICOFXPath & '" "' & $sIMGFile & '"'
;~ 		ConsoleWrite ( $sIcoFXCMD & @CRLF )
;~ 		RunAndClose ( $sIcoFXCMD )
;~ 		;Run ( $sIcoFXCMD )
;~ 	Next

EndFunc

Func CountExt ( $sDir, $sExt )
	Return UBound ( _FileListToArrayEx($sDir, "\.(" & $sExt & ")$", 64 + 32 + 1 + 4 ) )
EndFunc

Func Print ( $sString )
	ConsoleWrite ( $sString & @CRLF )
EndFunc