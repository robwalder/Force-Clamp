#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma version=3.1
#include "ForceRamp",version>=2
#include "ConstantForceMotion"
#include "SearchForMolecules"
#include "WaveDimNote"
 
// Version 3.1 notes
// Loading settings waves from external files.  This will replace functions that currently create those waves.  - Done
// Also going to write a more thorough wave note on deflection and zsensor waves using WaveDimNote library. - Done

// Will actually do this scripting now as well. - Still need to do this.

// Going to build in scripting support for further automation.  
// Basic idea: You can setup some settings to run a certain number of times and then switch to some other settings.  
// Example.  Run the force clamp with 30pN target force 50 times. Then change to 40pN target force for 50 times.  Then 50 pN target force for 50 times.  
// The point of all of this to set up an experiment to automatically collect the data we want during an overnight run.  
 
Menu "Force Clamp"
	"Initialize Force Clamp", InitializeForceClamp()
	"Initialize Force Ramp - Force Clamp", InitializeForceClamp(WithForceRamp=1)
	"Show Force Clamp Panel", DisplayFCPanel("ForceClampNoRamp")	
	"Show Expanded Force Clamp Panel", DisplayFCPanel("ForceClampWithRamp")	
	"Show Force Ramp FC Panel", DisplayFCPanel("ForceRampForceClamp")	
End

Function InitializeForceClamp([WithForceRamp])
	Variable WithForceRamp
	If(ParamIsDefault(WithForceRamp))
		WithForceRamp=0
	EndIf
	
	NewDataFolder/O root:ForceClamp
	NewDataFolder/O root:ForceClamp:SavedData
	NewDataFolder/O root:ForceClamp:Scripts
	
	SetDataFolder root:ForceClamp
	
	// Load External Parm waves
	String PathIn=FunctionPath("")
	NewPath/Q/O ForceClampParms ParseFilePath(1, PathIn, ":", 1, 0) +"Parms"
	LoadWave/H/Q/O/P=ForceClampParms "FCSettings.ibw"	
	LoadWave/H/Q/O/P=ForceClampParms "FCWaveNamesCallback.ibw"	

	If(!WithForceRamp)
		DisplayFCPanel("ForceClampNoRamp")	
	EndIf
	
	If(WithForceRamp)
		InitFC_FR()
	EndIf

End

Function DoForceClamp([Callback,FastMode])
	String Callback
	Variable FastMode
	Wave FCSettings=root:ForceClamp:FCSettings
	Wave/T FCWaveNamesCallback=root:ForceClamp:FCWaveNamesCallback
	If(!ParamIsDefault(Callback))
		FCWaveNamesCallback[%Callback]=Callback
	EndIf
	If(ParamIsDefault(FastMode))
		FastMode=0
	EndIf
	Variable Error=td_stop()
	If(Error>0)
		Print "Error in DoForceClamp: "+num2str(Error)
	EndIf
	ForceClamp(FCSettings,FCWaveNamesCallback,FastMode=FastMode)
End

Function TestBeep()
	Print "Beep"
End

Function ForceClamp(FCSettings,FCWaveNamesCallback,[FastMode])
	Wave FCSettings
	Wave/T FCWaveNamesCallback
	Variable FastMode
	If(ParamIsDefault(FastMode))
		FastMode=0
	EndIf
	// Now figure out the decimation factor to give the closest sampling rate possible
	Variable DecimationFactor=Round(50000/FCSettings[%$"SamplingRate_Hz"])
	Variable EffectiveSamplingRate=50000/DecimationFactor
	// How many points should we make these waves
	Variable NumPoints=Floor(FCSettings[%$"MaxTime_s"]*EffectiveSamplingRate)

	// Make all waves and setup the wave references.  
	Make/N=(NumPoints)/O $FCWaveNamesCallback[%ZSensor],$FCWaveNamesCallback[%DefV]
	Wave ZSensor= $FCWaveNamesCallback[%ZSensor]
	Wave DefV= $FCWaveNamesCallback[%DefV]
	
	Variable Error = 0
	Variable Force_Volts = ForceToDeflection(FCSettings[%Force_N],Offset=FCSettings[%DefVOffset])

	//  Setup feedback loops
	Error +=	ir_SetPISLoop(2,"2,Never","Deflection",Force_Volts,FCSettings[%P_Deflection], FCSettings[%I_Deflection], FCSettings[%S_Deflection],"Output.Z",-10,150)	

	// Setup input waves for x,y,z and deflection.  After the motion is done, callback will execute
	Error += td_xSetInWavePair(1, "2,0", "Cypher.LVDT.Z", ZSensor, "Deflection", DefV,"ForceClampFinish()", DecimationFactor)

	DoTipMoleculeMonitor()
	// Execute motion
	If(FastMode==0)
		Error +=td_WriteString("Event.2", "once")
	EndIf

	if (Error>0)
		print "Error in ForceClamp: ", Error
	endif

End



Function StopForceClamp()
	// Here we stop the z feedback loop and reset it.  Without this code, our next force ramp will just be stuck.  
	td_stop()
	ir_StopPISLoop(-2)
	Struct ARFeedbackStruct FB
	ARGetFeedbackParms(FB,"outputZ")
	FB.StartEvent = "2"
	FB.StopEvent = "3"
	String ErrorStr
	ErrorStr += ir_writePIDSloop(FB)
	ARBackground("MonitorTipMoleculeConnection",0,"")

End


Function ForceClampFinish()
	
	StopForceClamp()
	Wave FCSettings=root:ForceClamp:FCSettings
	Wave/T FCWaveNamesCallback=root:ForceClamp:FCWaveNamesCallback
	
	String DeflectionWaveName=FCWaveNamesCallback[%DefV]
	String ZSensorWaveName=FCWaveNamesCallback[%ZSensor]
	String SavedDataDirectory="root:ForceClamp:SavedData:"
	String IterationString=num2str(FCSettings[%Iteration])
	String DeflectionSaveName=SavedDataDirectory+"DefV"+IterationString
	String ZSensorSaveName=SavedDataDirectory+"ZSensor"+IterationString
	String SettingsSaveName=SavedDataDirectory+"FCSettings"+IterationString
	String SettingsStrSaveName=SavedDataDirectory+"FCWaveNamesCallback"+IterationString
	Wave DefV=$DeflectionWaveName
	Wave ZSensor=$ZSensorWaveName
	
	WaveTransform zapNaNs, DefV
	WaveTransform zapNaNs, ZSensor
	
	String NoteForFCWaves=StandardCypherWaveNote()+WaveDimValuesToString(FCSettings)+WaveDimTextToString(FCWaveNamesCallback)
	note/K DefV NoteForFCWaves	
	note/K ZSensor NoteForFCWaves
	
	Duplicate/O $DeflectionWaveName $DeflectionSaveName
	Duplicate/O $ZSensorWaveName $ZSensorSaveName
	Duplicate/O FCSettings $SettingsSaveName
	Duplicate/O FCWaveNamesCallback $SettingsStrSaveName
	FCSettings[%Iteration]+=1
	
	If(FCSettings[%UseSearchGrid])
		FCWaveNamesCallback[%Callback]="SearchForMolecule(Callback=\"DoForceRampForceClamp()\")"
	EndIf
	
	Execute FCWaveNamesCallback[%Callback]
End

Function MonitorTipMoleculeConnection()
	Wave HackMeterWave
	Variable DeflOffset=0
	Variable ZPztOffset=0
	
	String DataFolder = GetDF("Meter")
	Wave UpdateMeterUpdate = $DataFolder+"UpdateMeterUpdate"
	Variable Height_V =UpdateMeterUpdate[%Height]
	
	If (Height_V<0) // Zsensor railed, probably because the tip has disconnected from the molecule.
		td_StopInWaveBank(0)
		ForceClampFinish()
		Return 1  // Forces this background process to stop
	EndIf
	
	Return 0 // Must return 0 to keep background process repeating.

End

Function DoTipMoleculeMonitor()
	ARBackground("MonitorTipMoleculeConnection",10,"")
End


Window ForceClampWithRamp() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel/K=1 /W=(501,69,659,385) as "ForceClamp"
	Button DoForceClamp_Button,pos={5,175},size={98,23},proc=ForceClampButtonProc,title="Do Force Clamp"
	SetVariable TargetForceSV,pos={6,36},size={140,16},title="Target Force"
	SetVariable TargetForceSV,format="%.1W1PN"
	SetVariable TargetForceSV,value= root:ForceClamp:FCSettings[%Force_N]
	SetVariable SampleRateSV,pos={7,59},size={140,16},title="Sample Rate"
	SetVariable SampleRateSV,format="%.1W1PHz"
	SetVariable SampleRateSV,value= root:ForceClamp:FCSettings[%SamplingRate_Hz]
	SetVariable MaxTimeSV,pos={7,83},size={141,16},title="Max Time",format="%.0W1Ps"
	SetVariable MaxTimeSV,value= root:ForceClamp:FCSettings[%MaxTime_s]
	SetVariable DefVSV,pos={7,107},size={115,16},title="Defl Offset"
	SetVariable DefVSV,format="%.0W1PV"
	SetVariable DefVSV,value= root:ForceClamp:FCSettings[%DefVOffset]
	SetVariable IterationSV,pos={7,131},size={141,16},title="Iteration"
	SetVariable IterationSV,value= root:ForceClamp:FCSettings[%Iteration],noedit= 1
	Button StopForceClamp_Button,pos={107,175},size={42,23},proc=ForceClampButtonProc,title="Stop"
	TitleBox ForceClamp_TB,pos={9,7},size={108,21},title="Force Clamp Settings"
	SetVariable CallbackSV,pos={5,156},size={140,16},title="Callback"
	SetVariable CallbackSV,value= root:ForceClamp:FCWaveNamesCallback[%Callback],noedit= 1
	TitleBox ForceRampForceClamp_TB,pos={4,209},size={129,21},title="Force Ramp (FC) Settings"
	SetVariable SaveNameSV,pos={3,239},size={141,16},title="Save Name"
	SetVariable SaveNameSV,value= root:ForceClamp:FCWaveNamesCallback[%SaveName],noedit= 1
	Button DoForceRampForceClamp_Button,pos={2,281},size={109,23},proc=ForceClampButtonProc,title="Do Force Ramp - FC"
	Button StopForceRampForceClamp_Button,pos={113,281},size={40,23},proc=ForceClampButtonProc,title="Stop"
	CheckBox UseSearchGrid_CB,pos={5,261},size={96,14},proc=FCCheckProc,title="Use Search Grid"
	CheckBox UseSearchGrid_CB,value= 0
	Button SetOffset_Button,pos={125,106},size={26,17},proc=ForceClampButtonProc,title="Set"
EndMacro

Window ForceClampNoRamp() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(333,57,517,264) as "ForceClamp"
	Button DoForceClamp_Button,pos={5,175},size={98,23},proc=ForceClampButtonProc,title="Do Force Clamp"
	SetVariable TargetForceSV,pos={6,36},size={140,16},title="Target Force"
	SetVariable TargetForceSV,format="%.1W1PN"
	SetVariable TargetForceSV,limits={0,inf,5e-12},value= root:ForceClamp:FCSettings[%Force_N]
	SetVariable SampleRateSV,pos={7,59},size={140,16},title="Sample Rate"
	SetVariable SampleRateSV,format="%.1W1PHz"
	SetVariable SampleRateSV,value= root:ForceClamp:FCSettings[%SamplingRate_Hz]
	SetVariable MaxTimeSV,pos={7,83},size={141,16},title="Max Time",format="%.0W1Ps"
	SetVariable MaxTimeSV,value= root:ForceClamp:FCSettings[%MaxTime_s]
	SetVariable DefVSV,pos={7,107},size={115,16},title="Defl Offset"
	SetVariable DefVSV,format="%.0W1PV"
	SetVariable DefVSV,value= root:ForceClamp:FCSettings[%DefVOffset]
	SetVariable IterationSV,pos={7,131},size={141,16},title="Iteration"
	SetVariable IterationSV,value= root:ForceClamp:FCSettings[%Iteration],noedit= 1
	Button StopForceClamp_Button,pos={107,175},size={42,23},proc=ForceClampButtonProc,title="Stop"
	TitleBox ForceClamp_TB,pos={9,7},size={108,21},title="Force Clamp Settings"
	SetVariable CallbackSV,pos={5,156},size={140,16},title="Callback"
	SetVariable CallbackSV,value= root:ForceClamp:FCWaveNamesCallback[%Callback],noedit= 1
	Button SetOffset_Button,pos={125,106},size={26,17},proc=ForceClampButtonProc,title="Set"
EndMacro

Function MakeForceClampNoRampPanel(FCSettings,FCWaveNamesCallback,[PanelName,WindowName]):Panel
	Wave FCSettings
	Wave/T FCWaveNamesCallback
	String PanelName,WindowName
	If(ParamIsDefault(WindowName))
		WindowName="Force Clamp"
	EndIf
	If(ParamIsDefault(PanelName))
		PanelName="ForceClampPanel"
	EndIf
	
	String WaveNameList="ClampSettings="+GetWavesDataFolder(FCSettings,2)+";ClampSettingsStr="+GetWavesDataFolder(FCWaveNamesCallback,2)+";"

	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1/N=$PanelName /W=(333,57,517,264) as WindowName
	Button DoForceClamp_Button,pos={5,175},size={98,23},proc=ForceClampButtonProc,title="Do Force Clamp",userdata= WaveNameList
	SetVariable TargetForceSV,pos={6,36},size={140,16},title="Target Force"
	SetVariable TargetForceSV,format="%.1W1PN"
	SetVariable TargetForceSV,limits={0,inf,5e-12},value=FCSettings[%Force_N]
	SetVariable SampleRateSV,pos={7,59},size={140,16},title="Sample Rate"
	SetVariable SampleRateSV,format="%.1W1PHz"
	SetVariable SampleRateSV,value= FCSettings[%SamplingRate_Hz]
	SetVariable MaxTimeSV,pos={7,83},size={141,16},title="Max Time",format="%.0W1Ps"
	SetVariable MaxTimeSV,value= FCSettings[%MaxTime_s]
	SetVariable DefVSV,pos={7,107},size={115,16},title="Defl Offset"
	SetVariable DefVSV,format="%.0W1PV"
	SetVariable DefVSV,value= FCSettings[%DefVOffset]
	SetVariable IterationSV,pos={7,131},size={141,16},title="Iteration"
	SetVariable IterationSV,value= FCSettings[%Iteration],noedit= 1
	Button StopForceClamp_Button,pos={107,175},size={42,23},proc=ForceClampButtonProc,title="Stop"
	TitleBox ForceClamp_TB,pos={9,7},size={108,21},title="Force Clamp Settings"
	SetVariable CallbackSV,pos={5,156},size={140,16},title="Callback"
	SetVariable CallbackSV,value= FCWaveNamesCallback[%Callback],noedit= 1
	Button SetOffset_Button,pos={125,106},size={26,17},proc=ForceClampButtonProc,title="Set"

End

Function ForceClampButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	String ButtonName=ba.CtrlName
	Wave FCSettings=root:ForceClamp:FCSettings

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
				strswitch(ButtonName)
				case "DoForceClamp_Button":
					DoForceClamp()
				break
				case "StopForceClamp_Button":
					td_StopInWaveBank(0)
					ARBackground("MonitorTipMoleculeConnection",0,"")
					ForceClampFinish()
				break 
				case "DoForceRampForceClamp_Button":
					FCSettings[%StopFRFC]=0
					DoForceRampForceClamp()
				break
				case "StopForceRampForceClamp_Button":
					FCSettings[%StopFRFC]=1
				break 
				case "SetOffset_Button":
					DetermineFCOffset()
				break 

			EndSwitch

			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function InitFC_FR()
	MakeForceRampWave(OutputWaveName="root:ForceClamp:RampSettings")
	MakeFRWaveNamesCallback(OutputWaveName="root:ForceClamp:RampStrSettings")
	
	// Initialize ramp settings for force clamp on a protein
	Wave RampSettings=root:ForceClamp:RampSettings
	Wave/T RampStrSettings=root:ForceClamp:RampStrSettings
	RampSettings[%$"Surface Trigger"]=75e-12
	RampSettings[%$"Molecule Trigger"]=15e-12
	RampSettings[%$"Approach Velocity"]=500e-9
	RampSettings[%$"Retract Velocity"]=50e-9
	RampSettings[%$"Surface Dwell Time"]=2
	RampSettings[%$"No Trigger Distance"]=30e-9
	RampSettings[%$"Extension Distance"]=100e-9
	RampSettings[%$"Sampling Rate"]=50000
	RampSettings[%'Engage Second Trigger']=1
	RampSettings[%'UseTriggerFilter']=1

	RampStrSettings[%Deflection]="root:ForceClamp:DefV_Ramp"
	RampStrSettings[%ZSensor]="root:ForceClamp:ZSensor_Ramp"
	RampStrSettings[%$"CTFC Settings"]="root:ForceClamp:TriggerInfo"
	RampStrSettings[%Callback]="FC_FRCallback()"
	
	// Show the clamp and ramp panels
	DisplayFCPanel("ForceRampForceClamp")	
	DisplayFCPanel("ForceClampWithRamp")	

	// Bring up search panel, so we can use search grid program.
	If(WaveExists(root:SearchGrid:SearchSettings))
		Execute "Search_Panel()"
	Else
		InitSearch(ShowUserInterface=1)
	EndIF

End

Function DoForceRampForceClamp()
	Wave FCSettings=root:ForceClamp:FCSettings
	Variable StopFRFC=FCSettings[%StopFRFC]
	If(!StopFRFC)
		DetermineFCOffset(DoRamp=1)
	EndIF
End

Function DetermineFCOffset([DoRamp])
	Variable DoRamp
	If(ParamIsDefault(DoRamp))
		DoRamp=0
	EndIf
	Make/O/N=100 root:ForceClamp:DeflectionOffsetData
	Wave DeflectionOffsetData=root:ForceClamp:DeflectionOffsetData
	Variable Error=0
	String CallbackStr="DetermineFCOffsetCallback("+num2str(DoRamp)+")"
	
	Error+=td_stop()
	Error+= td_xSetInWave(0, "0,0", "Deflection", DeflectionOffsetData, CallbackStr,100)

	// Execute motion
	Error +=td_WriteString("Event.0", "once")

	if (Error>0)
		print "Error in DetermineFCOffset: "+num2str(Error)
	endif
End

Function DetermineFCOffsetCallback(DoRamp)
	Variable DoRamp
	Wave DeflectionOffsetData=root:ForceClamp:DeflectionOffsetData
	WaveStats/Q DeflectionOffsetData 	
	Variable DeflectionOffset=V_avg
	Wave FCSettings=root:ForceClamp:FCSettings
	FCSettings[%DefVOffset]=DeflectionOffset

	If(DoRamp)
		Wave RampSettings=root:ForceClamp:RampSettings
		Wave/T RampStrSettings=root:ForceClamp:RampStrSettings
		RampSettings[%DefVOffset]=DeflectionOffset
		DoForceRampFiltered(RampSettings,RampStrSettings,RampSettings[%TriggerFilterFreq])
	EndIf
End


Function FC_FRCallback()
	Wave/T TriggerInfo=root:ForceClamp:TriggerInfo
	Wave FCSettings=root:ForceClamp:FCSettings
	Wave/T FCWaveNamesCallback=root:ForceClamp:FCWaveNamesCallback
	Wave DefVolts=root:ForceClamp:DefV_Ramp
	Wave ZSensorVolts = root:ForceClamp:ZSensor_Ramp
	variable Error = 0
	variable MoleculeAttached =1 // Default assumption is molecule will attach
	
	// Save initial force ramp with suffix _IFR (stands for initial force ramp)
	String SaveName=FCWaveNamesCallback[%SaveName]+"_FC"
	SaveAsAsylumForceRamp(SaveName,FCSettings[%Iteration],DefVolts,ZSensorVolts)
	
	// Check to see if molecule is attached.  If Triggertime2 is greater than 400,000, then molecule did NOT attach
	Error+=td_ReadGroup("ARC.CTFC",TriggerInfo)
	if (str2num(TriggerInfo[%TriggerTime2])> 400000)
		MoleculeAttached=0
	endif
	
	If (Error>0)
		Print "Error in FC_FRCallback()"
	EndIf
	
	// Just stop if we told FCFR to stop.  Otherwise continue.
	If(!FCSettings[%StopFRFC])

		// Execute force clamp if molecule is attached
		if (MoleculeAttached==1)
			DoForceClamp()
		endif
	
		// If no molecule attached, then do another force ramp
		If (MoleculeAttached==0)
			FCSettings[%Iteration]+=1
			If(FCSettings[%UseSearchGrid])
				SearchForMolecule(Callback="DoForceRampForceClamp()")
			Else
				DoForceRampForceClamp()
			EndIf
		endif
	EndIf

End

Function FCCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	Wave FCSettings=root:ForceClamp:FCSettings		
	Wave/T FCWaveNamesCallback=root:ForceClamp:FCWaveNamesCallback

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			String CheckBoxName=cba.ctrlName
			Strswitch(CheckBoxName)
				case "UseSearchGrid_CB":
					FCSettings[%UseSearchGrid]=checked
					If(!checked)
						FCWaveNamesCallback[%Callback]=""
					EndIf
				break
			EndSwitch
			

			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function DisplayFCPanel(PanelName)
	String PanelName	

	DoWindow/F $PanelName
	If (V_flag==0)		

		StrSwitch(PanelName)
			Case "ForceClampWithRamp":
				Execute/Q "ForceClampWithRamp()"
				MoveWindow/W=ForceClampWithRamp 250,5,388,240
			break
			Case "ForceClampNoRamp":
				Execute/Q "ForceClampNoRamp()"	
				MoveWindow/W=ForceClampNoRamp 250,5,388,160
			break
			Case "ForceRampForceClamp":
				Wave RampSettings=root:ForceClamp:RampSettings
				Wave/T RampStrSettings=root:ForceClamp:RampStrSettings

				MakeForceRampPanel(RampSettings,RampStrSettings,PanelName="ForceRampForceClamp",WindowName="FR_FC")
				MoveWindow/W=ForceRampForceClamp 400,10,550,285
			break
			
		EndSwitch
		
	EndIf

End
