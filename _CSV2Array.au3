; #FUNCTION# ===================================================================
; Name ..........: _CSV2Array
; Description ...:
; AutoIt Version : V3.3.0.0
; Syntax ........: _CSV2Array($hFile[, $cSeperator = "auto"[, $bFilterString = True[, $iColumnMode = 0]]])
; Parameter(s): .: $hFile       - Handle for the CSV file to Read
;                  $cSeperator  - Optional: (Default = "auto") : Tries to find the separator char (; or , or TAB or | or space)
;                               | Data-seperator-char
;                               | Empty-string = Opt("GUIDataSeparatorChar")
;                  $bFilterString - Optional: (Default = True) : Removes leading and trailing " or '
;                  $iColumnMode - Optional: (Default = 0) :
;                               | 0: Sets error if lines have different columns and @extended to the csv-line number
;                               | 1: returns lines with different columns numbers comparing to the first line, too
;                               | 2: removing all columns > column numbers in the first line
; Return Value ..: Success      - 2-dim Array
;                  Failure      - 0
;                  @ERROR       - 1: error file read
;                  @ERROR       - 2: different number of columns / @EXTENDED = CSV-line
;                               - 3: parameter error
; Author(s) .....: Thorsten Willert
; Date ..........: Mon Dec 07 18:54:35 CET 2009
; ==============================================================================
Func _CSV2Array($hFile, $cSeperator = "auto", $bFilterString = True, $iColumnMode = 0)
	Local $s = FileRead($hFile)
	If @error Then Return SetError(1)

	If $cSeperator = Default Then $cSeperator = "auto"
	If Not $cSeperator Then $cSeperator = Opt("GUIDataSeparatorChar")

	; searching the line-seperator and splitting the lines into an array
	Local $aLines
	If StringInStr($s, @CRLF) Then
		$aLines = StringSplit($s, @CRLF, 1)
	ElseIf StringInStr($s, @CR) Then
		$aLines = StringSplit($s, @CR)
	Else
		$aLines = StringSplit($s, @LF)
	EndIf

	; searching the delimiter in the first line
	Local $aTMP
	If $cSeperator = "auto" Then
		Local $iMax = 0
		Local $iC[5] = [0, 0, 0, 0, 0]
		Local $sC[5] = [";", ",", @TAB, "|", " "]

		$aTMP = StringRegExp($aLines[1], ";", 3)
		If Not @error Then $iC[0] = UBound($aTMP)
		$aTMP = StringRegExp($aLines[1], ",", 3)
		If Not @error Then $iC[1] = UBound($aTMP)
		$aTMP = StringRegExp($aLines[1], "\t", 3)
		If Not @error Then $iC[2] = UBound($aTMP)
		$aTMP = StringRegExp($aLines[1], "\|", 3)
		If Not @error Then $iC[3] = UBound($aTMP)
		$aTMP = StringRegExp($aLines[1], "[ ]", 3)
		If Not @error Then $iC[4] = UBound($aTMP)

		For $i = 0 To UBound($sC) - 1
			If $iC[$i] > $iMax Then
				$iMax = $iC[$i]
				$cSeperator = $sC[$i]
			EndIf
		Next
	EndIf

	; creating 2-dim array based on the number of data in the first line
	$aTMP = StringSplit($aLines[1], $cSeperator)
	Local $iCol = $aTMP[0]
	Local $aRet[$aLines[0]][$iCol]

	; splitting and filling the lines
	For $i = 1 To $aLines[0]
		$aTMP = StringSplit($aLines[$i], $cSeperator)
		If @error Then ContinueLoop
		If $aTMP[0] > $iCol Then
			Switch $iColumnMode
				Case 0
					Return SetError(2, $i)
				Case 1
					ReDim $aRet[$aLines[0] - 1][$aTMP[0]]
				Case 2
					$aTMP[0] = $iCol
				Case Else
					Return SetError(3)
			EndSwitch
		EndIf
		For $j = 1 To $aTMP[0]
			$aTMP[$j] = StringStripWS($aTMP[$j], 3)
			If $bFilterString Then ; removing leading and trailing " or '
				$aTMP[$j] = StringRegExpReplace($aTMP[$j], '^("|'')(.*?)\1$', '$2')
			EndIf
			$aRet[$i - 1][$j - 1] = $aTMP[$j]
		Next ; /cols
	Next ; /lines

	Return $aRet
EndFunc   ;==>_CSV2Array
