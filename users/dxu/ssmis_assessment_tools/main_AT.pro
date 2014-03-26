;---------------------------------------------------------------------------------
; Name: main_AT.pro
;
; Type:  IDL Program
;
; Description: 
;   To read observed radiance data and simulated radiance data,
;   which is generated from GFS 6-h forecast, then do following steps:
;   to access SSMIS data quality. 
;     1. Plot observed radiance
;     2. Plot simulated radiance
;     3. Plot Bias ( observed radiance - simulated radiance )
;
; Author: Deyong Xu (RTI) @ JCSDA, 
;         Deyong.Xu@noaa.gov
; Version: Feb 27, 2014, DXu, Initial coding
;         
;
;---------------------------------------------------------------------------------
; Specify IDL plotting and util code to use.
@paths_idl.pro
; Specify locally-defined util code.
@AT_Util.pro

mark_chooseSensor:
PRINT, 'Choose instrument: '
PRINT,' 1 : NOAA-18/AMSUA&MHS'
PRINT,' 2 : NOAA-19/AMSUA&MHS'
PRINT,' 3 : MetOp-A/AMSUA&MHS'
PRINT,' 4 : MetOp-B/AMSUA/MHS'
PRINT,' 5 : F16/SSMIS'
PRINT,' 6 : F17/SSMIS'
PRINT,' 7 : F18/SSMIS'
PRINT,' 8 : NPP/ATMS'
PRINT,' 9 : AQUA/AMSRE'
PRINT,'10 : GCOMW1/AMSR2'
PRINT,'11 : FY3/MWRI'
PRINT,'12 : FY3/MWHS/MWTS'
PRINT,'13 : TRMM/TMI'
PRINT,'14 : GPM/GMI'
PRINT,'15 : MT/MADRAS'
PRINT,'16 : MT/SAPHIR'
PRINT,'17 : WindSat'

sensorOption = 0S
READ, sensorOption

; Set flag to fill value: 999
optionFlag = 999
; Check to see if a right option is chosen.
FOR i = 1, 17 DO BEGIN 
   IF sensorOption eq i THEN BEGIN
      optionFlag = sensorOption 
      BREAK
   ENDIF
ENDFOR

; None of options is chosen
IF ( optionFlag eq 999 ) THEN BEGIN
   PRINT, "Wrong option, choose again !!!" 
   PRINT, ""
   GOTO, mark_chooseSensor
ENDIF
                        
;-------------------------------------------
; Read config params for the sensor chosen
;-------------------------------------------
configSensorParam, sensorOption, paramStruct 

; Save config parameters 
MIN_LAT = paramStruct.MIN_LAT
MAX_LAT = paramStruct.MAX_LAT
MIN_LON = paramStruct.MIN_LON
MAX_LON = paramStruct.MAX_LON
radListFile1  = paramStruct.radListFile1
radListFile2  = paramStruct.radListFile2
sceneListFile = paramStruct.sceneListFile
MAX_FOV       = paramStruct.MAX_FOV
MAX_CHAN      = paramStruct.MAX_CHAN
INT_FILL_Val = paramStruct.INT_FILL
FLOAT_FILL_Val = paramStruct.FLOAT_FILL
STRING_FILL_Val = paramStruct.STRING_FILL
; Filter out FILL values
indices_1 = WHERE(paramStruct.chanNumArray ne INT_FILL_Val)
chanNumArray  = paramStruct.chanNumArray(indices_1)
indices_2 = WHERE(paramStruct.chanInfoArray ne STRING_FILL_Val)
chanInfoArray = paramStruct.chanInfoArray(indices_2)
indices_3 = WHERE(paramStruct.minBT_Values ne FLOAT_FILL_Val)
minBT_Values  = paramStruct.minBT_Values(indices_3)
indices_4 = WHERE(paramStruct.maxBT_Values ne FLOAT_FILL_Val)
maxBT_Values  = paramStruct.maxBT_Values(indices_4)
indices_5= WHERE(paramStruct.prefixArray ne STRING_FILL_Val)
prefixArray   = paramStruct.prefixArray(indices_5)
indices_6= WHERE(paramStruct.chPlotArray ne INT_FILL_Val)
chPlotArray   = paramStruct.chPlotArray(indices_6)
date          = paramStruct.date

mark_readAgain:
PRINT, 'Read data again?'
PRINT, '1 - YES'
PRINT, '2 - NO, to reform'
PRINT, '3 - NO, to plot radiance'
PRINT, '4 - NO, to plot scatter'
PRINT, '5 - NO, to plot clear sky '
PRINT, '6 - NO, to plot cloudy sky'
PRINT, '7 - NO, to plot precipitation'

READ, readAgain
CASE readAgain OF
   1: GOTO, mark_readMeas
   2: GOTO, mark_reform
   3: GOTO, mark_plotting 
   4: GOTO, mark_plotting_scatter
   5: GOTO, mark_plotting_ClearSky 
   6: GOTO, mark_plotting_CloudySky 
   7: GOTO, mark_plotting_Precip 
   ELSE: BEGIN & print, 'Wrong option!!! Chose again...' & GOTO, mark_readAgain & END
ENDCASE

; None of options is chosen
IF ( optionFlag eq 999 ) THEN BEGIN
   PRINT, "Wrong option, choose again !!!" 
   PRINT, ""
   GOTO, mark_readAgain
ENDIF


mark_readMeas:
;------------------------------------
; step 1: 
;   Read two lists of radiance files
;   and one list of  scene files
;------------------------------------
readlist, radListFile1, radFileList1, nFilesRad1
readlist, radListFile2, radFileList2, nFilesRad2
readlist, sceneListFile, sceneFileList, nFileScene

; Get number of radiance files in each list/array.
nRadFiles1 = n_elements(radFileList1)
nRadFiles2 = n_elements(radFileList2)
nSceneFiles = n_elements(sceneFileList)

; Make sure that numbers of radiance files and 
; scenef files are equal and not 0.
IF ( ( nRadFiles1 NE nRadFiles2 )  || $ 
     ( nRadFiles1 NE nSceneFiles ) || $ 
     ( nRadFiles1 EQ 0 ) ) THEN BEGIN
   PRINT,'Error: Number of Rad files in two list files NOT match'
   STOP
ENDIF

; Save number of rad files (orbits)
nOrbits=nRadFiles1

;-------------------------------------------
; step 2:
;   Define data structures 
;-------------------------------------------
; Radiance data structure
radData={ RadDataType, $
nFOV_Rad1    : lonarr(nOrbits),$         ; total number of FOVs in a file
scanPosRad1  : intarr(MAX_FOV,nOrbits),$  ; pos per file
scanLineRad1 : intarr(MAX_FOV,nOrbits),$  ; line per file
latRad1      : fltarr(MAX_FOV,nOrbits),$  ; lat per file
lonRad1   : fltarr(MAX_FOV,nOrbits),$  ; lon per file
dirRad1   : fltarr(MAX_FOV,nOrbits),$  ; dir per file
angleRad1 : fltarr(MAX_FOV,nOrbits),$  ; ang per file
QC_Rad1   : fltarr(MAX_FOV,nOrbits),$  ; QC  per file
tbRad1    : fltarr(MAX_FOV,nOrbits,MAX_CHAN),$ ; tb per file per channel
nFOV_Rad2 : lonarr(nOrbits),$          ; total number of FOVs in a file
scanPosRad2  : intarr(MAX_FOV,nOrbits),$  ; pos per file
scanLineRad2 : intarr(MAX_FOV,nOrbits),$  ; line per file
latRad2      : fltarr(MAX_FOV,nOrbits),$  ; lat per file
lonRad2      : fltarr(MAX_FOV,nOrbits),$  ; lon per file
dirRad2      : fltarr(MAX_FOV,nOrbits),$  ; dir per file
angleRad2    : fltarr(MAX_FOV,nOrbits),$  ; ang per file
QC_Rad2      : fltarr(MAX_FOV,nOrbits),$  ; QC  per file
tbRad2       : fltarr(MAX_FOV,nOrbits,MAX_CHAN), $ ; tb per file per channel
nChan        : 0L}

; Scene data structure
sceneData={ SceneDataType, $
   tpwVec    : fltarr(MAX_FOV, nOrbits),  $
   clwVec    : fltarr(MAX_FOV, nOrbits),  $
   rwpVec    : fltarr(MAX_FOV, nOrbits),  $
   gwpVec    : fltarr(MAX_FOV, nOrbits),  $
   tSkinVec  : fltarr(MAX_FOV, nOrbits),$
   sfcTypVec : fltarr(MAX_FOV, nOrbits) }

PRINT, "Begin readRadFile  =========="
;-------------------------------------------
; step 3:
;   Read radiances (measurements) from List1
;   Read radiances (simulated) from List2
;   Read scene file (GFS 6-hr forecast)
;-------------------------------------------
print, "****************    ",  sceneFileList
readRadFile, nOrbits, MAX_FOV, MAX_CHAN,      $
   radFileList1, radFileList2, sceneFileList, $
   radData, sceneData

PRINT, "done with readRadFile  =========="

;-------------------------------------------
; step 4:
;   Reform data
;-------------------------------------------
mark_reform:
reformArray, MAX_FOV, nOrbits,  $
   radData, refRadData,         $
   sceneData, refSceneData    

;-----------------------------------------
; step 5: 
;   Plot radiances (observed + simulated)
;-----------------------------------------
mark_plotting:

; Plot radiances and radiance difference
plotRad, chPlotArray, chanNumArray, chanInfoArray, prefixArray[0],   $
    MIN_LAT, MAX_LAT, MIN_LON, MAX_LON, minBT_Values, maxBT_Values,$
    refRadData, date

mark_plotting_scatter:
plotScattering, chPlotArray, chanNumArray, chanInfoArray, prefixArray[1],  $
    MIN_LAT, MAX_LAT, MIN_LON, MAX_LON, $
    refRadData, refSceneData, date

mark_plotting_ClearSky:
mark_plotting_CloudySky:
mark_plotting_Precip:

PRINT,'End of processing...'
END
