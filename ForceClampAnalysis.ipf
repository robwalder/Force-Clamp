#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Menu "Force Clamp Analysis"
	"Initialize Force Clamp Analysis", InitFCAnalysis()
	
End


Function InitFCAnalysis()
	NewDataFolder/O root:ForceClamp:Analysis
	SetDataFolder root:ForceClamp:Analysis

	Wave LastSettingsWave=root:ForceClamp:FCSettings
	Variable NumForceClamps=LastSettingsWave[%Iteration]
	Make/O/N=(NumForceClamps) StartTimes,StopTimes,TargetForce,UseThisForceClamp
	UseThisForceClamp=1
	
	Variable Counter=0
	For(Counter=0;Counter<NumForceClamps;Counter+=1)
		Wave DefV=$("root:ForceClamp:SavedData:DefV"+num2str(Counter))
		Wave ZSensor=$("root:ForceClamp:SavedData:ZSensor"+num2str(Counter))
		Wave Settings=$("root:ForceClamp:SavedData:FCSettings"+num2str(Counter))
		Wave/T SettingsStr=$("root:ForceClamp:SavedData:FCWaveNamesCallback"+num2str(Counter))
		Duplicate/O EstimateStartAndStopFCTimes(DefV,ZSensor,Settings), StartStopTimes
		StartTimes[Counter]=StartStopTimes[%StartTime]
		StopTimes[Counter]=StartStopTimes[%StopTime]
		TargetForce[Counter]=Settings[%Force_N]
	EndFor
	LifetimeVsForce(LifetimeMethod="DefVThresholds",ForceMethod="WithFRUOffset")
	
	Execute "FCAnalysisPanel()"
	SetVariable FCIndex_SV limits={0,NumForceClamps-1,1}
	
	
	Duplicate/O root:ForceClamp:SavedData:DefV0, root:ForceClamp:Analysis:DefV
	Duplicate/O root:ForceClamp:SavedData:ZSensor0, root:ForceClamp:Analysis:ZSensor
	Display/K=1/N=FCAnalysis_DefV root:ForceClamp:Analysis:DefV
	Display/K=1/N=FCAnalysis_ZSensor root:ForceClamp:Analysis:ZSensor
	Cursor/W=FCAnalysis_DefV A DefV StartTimes[0]
	Cursor/W=FCAnalysis_ZSensor A ZSensor StartTimes[0]
	Cursor/W=FCAnalysis_DefV B DefV StopTimes[0]
	Cursor/W=FCAnalysis_ZSensor B ZSensor StopTimes[0]
	
	Make/D/O/N=3 FCFitGuesses
	
	FCFitGuesses[0]=1e-2
	FCFitGuesses[1]=1e-9
	FCFitGuesses[2]=17

	SetDimLabel 0,0,k0,FCFitGuesses
	SetDimLabel 0,1,BarrierDistance,FCFitGuesses
	SetDimLabel 0,2,EnergyBarrierInKbT,FCFitGuesses
		
	Make/D/O/N=2 SplitLifetimeDataByForce
	
	SplitLifetimeDataByForce[0]=25e-12
	SplitLifetimeDataByForce[1]=5e-12

	SetDimLabel 0,0,StartForce,SplitLifetimeDataByForce
	SetDimLabel 0,1,BinSize,SplitLifetimeDataByForce
	Make/O/N=4 FC_FitParms

	SetDimLabel 0,0,k0,FC_FitParms
	SetDimLabel 0,1,BarrierDistance,FC_FitParms
	SetDimLabel 0,2,EnergyBarrier,FC_FitParms
	SetDimLabel 0,3,EnergyBarrierInKbT,FC_FitParms
	 
	 FC_FitParms[%k0]=1e-2
	 FC_FitParms[%BarrierDistance]=1e-9
	 FC_FitParms[%EnergyBarrier]=1e-19
	 FC_FitParms[%EnergyBarrierInKbT]=17
	


End

Function BuildSelectedWaves()
	Wave LastSettingsWave=root:ForceClamp:FCSettings
	Variable NumForceClamps=LastSettingsWave[%Iteration]
	SetDataFolder root:ForceClamp:Analysis
	
	Duplicate/O root:ForceClamp:Analysis:StartTimes, Selected_Start
	Duplicate/O root:ForceClamp:Analysis:StopTimes, Selected_Stop
	Duplicate/O root:ForceClamp:Analysis:TargetForce, Selected_TF
	Duplicate/O root:ForceClamp:Analysis:FC_Force, Selected_Force
	Duplicate/O root:ForceClamp:Analysis:FC_Lifetime, Selected_Lifetime
	Wave UseThisForceClamp
	Variable Counter=0
	For(Counter=0;Counter<NumForceClamps;Counter+=1)
		If(!UseThisForceClamp[Counter])
			Selected_Start[Counter]=Nan
			Selected_Stop[Counter]=Nan
			Selected_TF[Counter]=Nan
			Selected_Force[Counter]=Nan
			Selected_Lifetime[Counter]=Nan
		EndIf
	EndFor
	WaveTransform ZapNans, Selected_Start
	WaveTransform ZapNans, Selected_Stop
	WaveTransform ZapNans, Selected_TF
	WaveTransform ZapNans, Selected_Force
	WaveTransform ZapNans, Selected_Lifetime
End

Function FCTimeConstant(Lifetimes)
	Variable 	Lifetimes
	
End

Function ExtractLifeTimes(FC_AppliedForce,FC_Lifetime,ForceMin,ForceMax,[OutputWaveName])
	Wave FC_AppliedForce,FC_Lifetime
	Variable ForceMin,ForceMax
	String OutputWaveName

	If(ParamIsDefault(OutputWaveName))
		OutputWaveName="Lifetimes"
	EndIf
	
	Variable NumLifetimes=DimSize(FC_AppliedForce,0)
	Duplicate/O FC_LifeTime $OutputWaveName
	Wave Lifetimes=$OutputWaveName

	Lifetimes=((FC_AppliedForce[p]>=ForceMin)&&(FC_AppliedForce[p]<=ForceMax))==0? Nan : FC_Lifetime[p]
	
	WaveTransform ZapNans,Lifetimes	

End

Function ExtractMeasuredForce(FC_TargetForce,FC_MeasuredForce,ForceMin,ForceMax,[OutputWaveName])
	Wave FC_TargetForce,FC_MeasuredForce
	Variable ForceMin,ForceMax
	String OutputWaveName

	If(ParamIsDefault(OutputWaveName))
		OutputWaveName="MeasuredF"
	EndIf
	
	Variable NumFC=DimSize(FC_TargetForce,0)
	Duplicate/O FC_TargetForce $OutputWaveName
	Wave MeasuredForces=$OutputWaveName

	MeasuredForces=((FC_TargetForce[p]>=ForceMin)&&(FC_TargetForce[p]<=ForceMax))==0? Nan : FC_MeasuredForce[p]
	
	WaveTransform ZapNans,MeasuredForces	

End

Function InForceRange(TargetForce,ForceMin,ForceMax)
	Variable TargetForce,ForceMin,ForceMax
	Variable WithinForceRange=(TargetForce>=ForceMin)&&(TargetForce<=ForceMax)	
	Return WithinForceRange
End


Function LifetimeVsForce([ForceMethod,LifetimeMethod])
	String ForceMethod,LifetimeMethod

	If(ParamIsDefault(ForceMethod))
		ForceMethod="FromSettings"
	EndIf
	If(ParamIsDefault(LifetimeMethod))
		LifetimeMethod="LengthOfWave"
	EndIf
	
	Wave LastSettingsWave=root:ForceClamp:FCSettings
	Variable NumForceClamps=LastSettingsWave[%Iteration]
	Make/O/N=(NumForceClamps) root:ForceClamp:Analysis:FC_Force,root:ForceClamp:Analysis:FC_LifeTime
	Wave FC_Force=root:ForceClamp:Analysis:FC_Force
	Wave FC_LifeTime=root:ForceClamp:Analysis:FC_LifeTime
	Variable Counter=0
	For(Counter=0;Counter<NumForceClamps;Counter+=1)
		Wave DefV=$("root:ForceClamp:SavedData:DefV"+num2str(Counter))
		Wave ZSensor=$("root:ForceClamp:SavedData:ZSensor"+num2str(Counter))
		Wave Settings=$("root:ForceClamp:SavedData:FCSettings"+num2str(Counter))
		Wave/T SettingsStr=$("root:ForceClamp:SavedData:FCWaveNamesCallback"+num2str(Counter))
		FC_Force[Counter]=EstimateAppliedForce(Settings,SettingsStr,DefV,Method=ForceMethod,FCIndex=Counter)
		FC_LifeTime[Counter]=EstimateLifetime(DefV,ZSensor,Settings,Method=LifetimeMethod,FCIndex=Counter)
		
	EndFor

End

Function EstimateAppliedForce(Settings,SettingsStr,DefV,[Method,FCIndex])
	Wave Settings,DefV
	Wave/T SettingsStr
	String Method
	Variable FCIndex
	
	If(ParamIsDefault(Method))
		Method="FromSettings"
	EndIf
	If(ParamIsDefault(FCIndex))
		FCIndex=1
	EndIf
	
	Wave FRUOffsets=root:FRU:preprocessing:Offsets
	String ForceRampName=SettingsStr[%NearestForcePull]
	Variable ForceOffset=FRUOffsets[%$ForceRampName][%Offset_Force]
	String DefVInfo=note(DefV)
	Variable SpringConstant=str2num(StringByKey("K",DefVInfo,"=",";\r"))
	Variable Invols=str2num(StringByKey("\rInvols",DefVInfo,"=",";\r"))
	Wave StartTimes=root:ForceClamp:Analysis:StartTimes
	Wave StopTimes=root:ForceClamp:Analysis:StopTimes

	StrSwitch(Method)
		case "FromSettings":
			Return Settings[%Force_N]
		break
		case "WithFRUOffset":
			Return Settings[%Force_N]+ForceOffset-Settings[%DefVOffset]*SpringConstant*Invols
		break
		case "FromDataWithFRUOffsets":
			WaveStats/Q/R=(StartTimes[FCIndex],StopTimes[FCIndex]) DefV
			Return -1*V_avg*SpringConstant*Invols+ForceOffset
		break
		
	EndSwitch

	
End

Function EstimateLifetime(DefV,ZSensor,FCSettings,[Method,FCIndex])
	Wave DefV,ZSensor,FCSettings
	String Method
	Variable FCIndex
	
	If(ParamIsDefault(Method))
		Method="LengthOfWave"
	EndIf
	If(ParamIsDefault(FCIndex))
		FCIndex=1
	EndIf
	
	StrSwitch(Method)
		case "LengthOfWave":
			Return DimSize(DefV,0)*DimDelta(DefV,0)
		break
		case "DefVThresholds":
			Duplicate/O EstimateStartAndStopFCTimes(DefV,ZSensor,FCSettings), StartStopTimes
			Return StartStopTimes[%StopTime]-StartStopTimes[%StartTime]
		break
		case "FromIndices":
			Wave StartTimes=root:ForceClamp:Analysis:StartTimes
			Wave StopTimes=root:ForceClamp:Analysis:StopTimes

			Return StopTimes[FCIndex]-StartTimes[FCIndex]
		break
		
	EndSwitch

End

Function BuildReportFromSelectedFC()
	Wave Selected_Start=root:ForceClamp:Analysis:Selected_Start
	Wave Selected_Stop=root:ForceClamp:Analysis:Selected_Stop
	Wave Selected_TF=root:ForceClamp:Analysis:Selected_TF
	Wave Selected_Force=root:ForceClamp:Analysis:Selected_Force
	Wave Selected_Lifetime=root:ForceClamp:Analysis:Selected_Lifetime
	
	GetUniqueValues(Selected_TF,OutputWaveName="root:ForceClamp:Analysis:UniqueTF",OutputCountWaveName="root:ForceClamp:Analysis:UniqueTFCount")
	Wave UniqueTF=root:ForceClamp:Analysis:UniqueTF
	Wave UniqueTFCount=root:ForceClamp:Analysis:UniqueTFCount
	
	Variable TFCounter=0
	Variable NumTF=DimSize(UniqueTF,0)
	Make/O/N=(NumTF) TFMeanLifetime,TF_Rate_ML,TF_MeasuredF,TF_Rate_SD,TF_MeasuredF_SD
	For(TFCounter=0;TFCounter<NumTf;TFCounter+=1)
		String LifetimeWaveName="root:ForceClamp:Analysis:Lifetimes_TF_"+num2str(Round(UniqueTF[TFCounter]*1e12))+"pN"
		String MeasuredForceWaveName="root:ForceClamp:Analysis:MeasuredF_TF_"+num2str(Round(UniqueTF[TFCounter]*1e12))+"pN"
		ExtractLifeTimes(Selected_TF,Selected_Lifetime,UniqueTF[TFCounter]-0.5e-12,UniqueTF[TFCounter]+0.5e-12,OutputWaveName=LifetimeWaveName)
		ExtractMeasuredForce(Selected_TF,Selected_Force,UniqueTF[TFCounter]-0.5e-12,UniqueTF[TFCounter]+0.5e-12,OutputWaveName=MeasuredForceWaveName)
		Wave Lifetime=$LifetimeWaveName
		WaveStats/Q Lifetime
		TFMeanLifetime[TFCounter]=V_Avg
		TF_Rate_ML[TFCounter]=1/V_Avg
		TF_Rate_SD[TFCounter]=-(1/V_Avg)^2*V_sem
		Wave MeasuredForce=$MeasuredForceWaveName
		WaveStats/Q MeasuredForce
		TF_MeasuredF[TFCounter]=V_Avg
		TF_MeasuredF_SD=V_sdev

	EndFor
	
	//Display/N=TFvsRate/K=1 TF_Rate_ML vs UniqueTF
	Display/N=TFvsRate/K=1 TF_Rate_ML vs TF_MeasuredF
	ErrorBars TF_Rate_ML, XY wave=(TF_MeasuredF_SD,TF_MeasuredF_SD),wave=(TF_Rate_SD,TF_Rate_SD)
	DoWindow/T TFvsRate, "Rates for each targeted force"
	ModifyGraph log(left)=1
	ModifyGraph mode(TF_Rate_ML)=3
	Label left "k (s\\S-1\\M)"
	Label bottom "Force (pN)"
	//Wave SplitLifetimeDataByForce=root:ForceClamp:Analysis:SplitLifetimeDataByForce
	//LifetimeAnalysis(SplitLifetimeDataByForce[%StartForce],SplitLifetimeDataByForce[%BinSize])

	Wave FCFitGuesses=root:ForceClamp:Analysis:FCFitGuesses
	Variable BarrierGuess=FCFitGuesses[%EnergyBarrierInKbT]*1.3806488e-23*298
	//ForceClampFit(TF_MeasuredF,TF_Rate_ML,k0Guess=FCFitGuesses[%k0],xGuess=FCFitGuesses[%BarrierDistance],DeltaGGuess=BarrierGuess)
	Wave FCRate_Fit
	AppendToGraph/W=TFvsRate FCRate_Fit vs TF_MeasuredF
	ModifyGraph mode[1]=0,rgb[1]=(0,65000,0)
	
	

End

Function LifetimeAnalysis(StartForce,BinSize,[DoFit])
	Variable StartForce,BinSize,DoFit
	Wave Selected_Force=root:ForceClamp:Analysis:Selected_Force
	Wave Selected_Lifetime=root:ForceClamp:Analysis:Selected_Lifetime

	If(ParamIsDefault(DoFit))
		DoFit=1
	EndIf

	Variable EndForce=WaveMax(Selected_Force)
	Variable NumBins=Ceil((EndForce-StartForce)/BinSize)
	Make/N=(NumBins)/O FMeanLifetime,F_Rate_ML,F_Bin
	Variable FCounter=0
	For(FCounter=0;FCounter<NumBins;FCounter+=1)
		String LifetimeWaveName="root:ForceClamp:Analysis:Lifetimes_F_"+num2str(Round((StartForce+FCounter*BinSize)*1e12))+"pN"
		Variable StartBinForce=StartForce+FCounter*BinSize
		Variable EndBinForce=StartForce+(FCounter+1)*BinSize
		F_Bin[FCounter]=StartForce+(FCounter+0.5)*BinSize
		ExtractLifeTimes(Selected_Force,Selected_Lifetime,StartBinForce,EndBinForce,OutputWaveName=LifetimeWaveName)
		Wave Lifetime=$LifetimeWaveName
		WaveStats/Q Lifetime
		FMeanLifetime[FCounter]=V_Avg
		F_Rate_ML[FCounter]=1/V_Avg
	EndFor
	
	DoWindow/F FBinvsRate
	Variable NoGraph=(V_flag==0)
	If(NoGraph)
		Display/N=FBinvsRate/K=1 F_Rate_ML vs F_Bin
		DoWindow/T FBinvsRate, "Rates for each measured force (binned)"
		ModifyGraph mode[0]=3,log(left)=1
		Label left "k (s\\S-1\\M)"
		Label Bottom "Force (N)"
	EndIf

	If(DoFit)
		Wave FCFitGuesses=root:ForceClamp:Analysis:FCFitGuesses
		Variable BarrierGuess=FCFitGuesses[%EnergyBarrierInKbT]*1.3806488e-23*298
		//ForceClampFit(F_Bin,F_Rate_ML,k0Guess=FCFitGuesses[%k0],xGuess=FCFitGuesses[%BarrierDistance],DeltaGGuess=BarrierGuess)
		If(NoGraph)
			Wave FCRate_Fit
			AppendToGraph/W=FBinvsRate FCRate_Fit vs F_Bin
			ModifyGraph mode[1]=0,rgb[1]=(0,65000,0)
			
		EndIf
	EndIf

End
	


Function/Wave EstimateStartAndStopFCTimes(DefV,ZSensor,FCSettings,[Threshold])
	Wave FCSettings,DefV,ZSensor
	Variable Threshold
	
	String DefVInfo=note(DefV)
	Variable SpringConstant=str2num(StringByKey("K",DefVInfo,"=",";\r"))
	Variable Invols=str2num(StringByKey("\rInvols",DefVInfo,"=",";\r"))
	Variable TargetDefV=FCSettings[%DefVOffset]-FCSettings[%Force_N]/SpringConstant/Invols
	If(ParamIsDefault(Threshold))
		Threshold = TargetDefV+0.015
	EndIF
	
	Variable StartTime=0
	Variable StopTime=DimSize(DefV,0)*DimDelta(DefV,0)
	
	Make/N=0/O Levels
	FindLevels/Q/DEST=Levels/EDGE=2 DefV,Threshold
	If(V_flag<2)
		StartTime=Levels[0]
	EndIf
	
	FindLevels/Q/DEST=Levels/EDGE=1 DefV,Threshold
	If(V_flag<2)
		Variable EdgeCounter=0
		Do
			StopTime=Levels[EdgeCounter]
			EdgeCounter+=1
		While(EdgeCounter<V_LevelsFound&&1.3*StartTime>StopTime)
	EndIf
	
	Make/O/N=2 StartStopWave
	SetDimLabel 0,0, StartTime, StartStopWave
	SetDimLabel 0,1, StopTime, StartStopWave
	StartStopWave={StartTime,StopTime}
	
	Return StartStopWave
	
End


Window FCAnalysisPanel() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(838,70,1147,578) as "Force Clamp Analysis"
	SetVariable FCIndex_SV,pos={9,25},size={121,16},proc=FCAnalysisSetVarProc,title="FC Index"
	SetVariable FCIndex_SV,limits={0,262,1},value= _NUM:260
	SetVariable StartTime_SV,pos={9,47},size={121,16},title="Start Time"
	SetVariable StartTime_SV,format="%.3W1Ps"
	SetVariable StartTime_SV,limits={0,inf,0.001},value= root:ForceClamp:Analysis:StartTimes[260]
	SetVariable StopTime_SV,pos={9,70},size={122,16},title="Stop Time"
	SetVariable StopTime_SV,format="%.3W1Ps"
	SetVariable StopTime_SV,limits={0,inf,0.001},value= root:ForceClamp:Analysis:StopTimes[260]
	Button FromCursorA,pos={138,46},size={74,19},proc=FCAnalysisButtonProc,title="From Cursor A"
	Button FromCursorA,fColor=(61440,61440,61440)
	Button FromCursorB,pos={138,69},size={74,19},proc=FCAnalysisButtonProc,title="From Cursor B"
	Button FromCursorB,fColor=(61440,61440,61440)
	TitleBox DetermineLiftime,pos={9,2},size={95,21},title="Determine Lifetime"
	TitleBox DoFCAnalysis,pos={9,141},size={79,21},title="Do FC Analysis"
	CheckBox UseThisFC_CB,pos={9,118},size={124,14},proc=FCAnalysisCheckProc,title="Use this Force Clamp?"
	CheckBox UseThisFC_CB,value= 1
	SetVariable LifeTime_SV,pos={9,94},size={122,16},title="Lifetime"
	SetVariable LifeTime_SV,format="%.3W1Ps"
	SetVariable LifeTime_SV,limits={0,inf,0.001},value= root:ForceClamp:Analysis:FC_LifeTime[260]
	Button BuildSelectedWaves,pos={9,169},size={115,20},proc=FCAnalysisButtonProc,title="Initialize Analysis"
	Button BuildSelectedWaves,fColor=(61440,61440,61440)
	SetVariable K0_SV,pos={9,294},size={158,16},title="K0"
	SetVariable K0_SV,limits={0,inf,0.001},value= root:ForceClamp:Analysis:FCFitGuesses[%k0]
	SetVariable BarrierDistance_SV,pos={9,317},size={158,16},title="x (Barrier Distance)"
	SetVariable BarrierDistance_SV,format="%.2W1Pm"
	SetVariable BarrierDistance_SV,limits={0,1e-07,1e-10},value= root:ForceClamp:Analysis:FCFitGuesses[%BarrierDistance],noedit= 1
	SetVariable EnergyBarrier_SV,pos={9,341},size={157,16},title="Energy Barrier"
	SetVariable EnergyBarrier_SV,format="%.1W1PKbT"
	SetVariable EnergyBarrier_SV,limits={0,inf,0.1},value= root:ForceClamp:Analysis:FCFitGuesses[%EnergyBarrierInKbT]
	SetVariable StartForce_SB,pos={9,197},size={158,16},title="Start Force"
	SetVariable StartForce_SB,format="%.0W1PN"
	SetVariable StartForce_SB,limits={0,inf,1e-12},value= root:ForceClamp:Analysis:SplitLifetimeDataByForce[%StartForce]
	SetVariable BinSize_SV,pos={9,218},size={158,16},title="Bin Size"
	SetVariable BinSize_SV,format="%.0W1PN"
	SetVariable BinSize_SV,limits={1e-12,1e-06,1e-12},value= root:ForceClamp:Analysis:SplitLifetimeDataByForce[%BinSize]
	Button SplitLifetimeByForce_B,pos={9,240},size={115,20},proc=FCAnalysisButtonProc,title="Split Lifetimes By Force"
	Button SplitLifetimeByForce_B,fColor=(61440,61440,61440)
	Button DudkoFit_B,pos={9,366},size={115,20},proc=FCAnalysisButtonProc,title="Do Dudko Fit"
	Button DudkoFit_B,fColor=(61440,61440,61440)
	TitleBox DudkoFit,pos={9,268},size={98,21},title="Dudko Fit Guesses"
	SetVariable K0_SV1,pos={7,427},size={158,16},title="K0"
	SetVariable K0_SV1,limits={0,inf,0.001},value= root:ForceClamp:Analysis:FC_FitParms[%k0]
	SetVariable BarrierDistance_SV1,pos={7,450},size={158,16},title="x (Barrier Distance)"
	SetVariable BarrierDistance_SV1,format="%.3W1Pm"
	SetVariable BarrierDistance_SV1,limits={0,inf,0.001},value= root:ForceClamp:Analysis:FC_FitParms[%BarrierDistance]
	SetVariable EnergyBarrier_SV1,pos={7,474},size={157,16},title="Energy Barrier"
	SetVariable EnergyBarrier_SV1,format="%.1W1PKbT"
	SetVariable EnergyBarrier_SV1,limits={0,inf,0.1},value= root:ForceClamp:Analysis:FC_FitParms[%EnergyBarrierInKbT]
	TitleBox DudkoFit1,pos={9,394},size={92,21},title="Dudko Fit Results"
	CheckBox ShowFvsE_CB,pos={142,119},size={92,14},proc=FCAnalysisCheckProc,title="Show FEC data"
	CheckBox ShowFvsE_CB,value= 1
	CheckBox ShowDvsZ_CB,pos={143,143},size={160,14},proc=FCAnalysisCheckProc,title="Show DefV vs ZSensorV data"
	CheckBox ShowDvsZ_CB,value= 0
EndMacro

Function FCAnalysisButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	String ButtonName=ba.CtrlName
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			Wave StartTimes=root:ForceClamp:Analysis:StartTimes
			Wave StopTimes=root:ForceClamp:Analysis:StopTimes
			Wave FC_LifeTime=root:ForceClamp:Analysis:FC_LifeTime
			ControlInfo/W=FCAnalysisPanel FCIndex_SV
			Variable CurrentIndex=V_value
			
			StrSwitch(ButtonName)
				case "FromCursorA":
					StartTimes[CurrentIndex]=xcsr(A)
					Cursor/W=FCAnalysis_DefV A DefV StartTimes[CurrentIndex]
					Cursor/W=FCAnalysis_ZSensor A ZSensor StartTimes[CurrentIndex]
		
					FC_LifeTime[CurrentIndex]=StopTimes[CurrentIndex]-StartTimes[CurrentIndex]
				break
				case "FromCursorB":
					ControlInfo/W=FCAnalysisPanel FCIndex_SV
					StopTimes[CurrentIndex]=xcsr(B)
					Cursor/W=FCAnalysis_DefV B DefV StopTimes[CurrentIndex]
					Cursor/W=FCAnalysis_ZSensor B ZSensor StopTimes[CurrentIndex]

					FC_LifeTime[CurrentIndex]=StopTimes[CurrentIndex]-StartTimes[CurrentIndex]
				break
				case "BuildSelectedWaves":
					BuildSelectedWaves()
					BuildReportFromSelectedFC()					
				break
				case "SplitLifetimeByForce_B":
					Wave SplitLifetimeDataByForce=root:ForceClamp:Analysis:SplitLifetimeDataByForce
					LifetimeAnalysis(SplitLifetimeDataByForce[%StartForce],SplitLifetimeDataByForce[%BinSize])
					
				break
				case "DudkoFit_B":
					Wave FCFitGuesses=root:ForceClamp:Analysis:FCFitGuesses
					Variable BarrierGuess=FCFitGuesses[%EnergyBarrierInKbT]*1.3806488e-23*298
					Wave F_Bin=root:ForceClamp:Analysis:F_Bin
					Wave F_Rate_ML=root:ForceClamp:Analysis:F_Rate_ML
					//ForceClampFit(F_Bin,F_Rate_ML,k0Guess=FCFitGuesses[%k0],xGuess=FCFitGuesses[%BarrierDistance],DeltaGGuess=BarrierGuess)
					DoWindow/F FBinvsRate
					If(V_flag==0)
						Display/N=FBinvsRate/K=1 F_Rate_ML vs F_Bin
						DoWindow/T FBinvsRate, "Rates for each measured force (binned)"
						ModifyGraph mode[0]=3,log(left)=1
						Label left "k (s\\S-1\\M)"
						Label Bottom "Force (N)"

						Wave FCRate_Fit=root:ForceClamp:Analysis:FCRate_Fit
						AppendToGraph/W=FBinvsRate FCRate_Fit vs F_Bin
						ModifyGraph mode[1]=0,rgb[1]=(0,65000,0)
	
					EndIf
				break
			Endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function FCAnalysisSetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	String SVAName=sva.CtrlName

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			StrSwitch(SVAName)
				case "FCIndex_SV":
				
					Wave StartTimes=root:ForceClamp:Analysis:StartTimes
					Wave StopTimes=root:ForceClamp:Analysis:StopTimes
					Wave FC_LifeTime=root:ForceClamp:Analysis:FC_LifeTime
					Duplicate/O $("root:ForceClamp:SavedData:DefV"+num2str(dval)) root:ForceClamp:Analysis:DefV
					Duplicate/O $("root:ForceClamp:SavedData:ZSensor"+num2str(dval)) root:ForceClamp:Analysis:ZSensor
					SetVariable StartTime_SV value=StartTimes[dval],win=FCAnalysisPanel
					SetVariable StopTime_SV value=StopTimes[dval],win=FCAnalysisPanel
					SetVariable LifeTime_SV value=FC_LifeTime[dval],win=FCAnalysisPanel
					Wave DefV=root:ForceClamp:Analysis:DefV
					Cursor/W=FCAnalysis_DefV A DefV StartTimes[dval]
					Cursor/W=FCAnalysis_ZSensor A ZSensor StartTimes[dval]
					Cursor/W=FCAnalysis_DefV B DefV StopTimes[dval]
					Cursor/W=FCAnalysis_ZSensor B ZSensor StopTimes[dval]
					Wave UseThisForceClamp=root:ForceClamp:Analysis:UseThisForceClamp
					CheckBox UseThisFC_CB,value= UseThisForceClamp[dval],win=FCAnalysisPanel

				
					DoWindow/F FCAnalysis_DefV
					If(V_flag==0)
						Display/K=1/N=FCAnalysis_DefV root:ForceClamp:Analysis:DefV
					EndIf
					DoWindow/F FCAnalysis_ZSensor
					If(V_flag==0)
						Display/K=1/N=FCAnalysis_ZSensor root:ForceClamp:Analysis:ZSensor
					EndIf

					Duplicate/T/O $("root:ForceClamp:SavedData:FCWaveNamesCallback"+num2str(dval)) root:ForceClamp:Analysis:FCWaveNamesCallback
					Duplicate/O $("root:ForceClamp:SavedData:FCSettings"+num2str(dval)) root:ForceClamp:Analysis:FCSettings
					Wave/T FCWaveNamesCallback=root:ForceClamp:Analysis:FCWaveNamesCallback
					String FRName=FCWaveNamesCallback[%NearestForcePull]

					ControlInfo/W=FCAnalysisPanel ShowDvsZ_CB
					Variable ShowDvsZGraph=V_Value
					If(ShowDvsZGraph)
						ApplyFuncsToForceWaves("SaveForceAndSep(DeflV_Ret,RawV_Ret,TargetFolder=\"root:ForceClamp:Analysis:\",NewName=\"Selected\")",FPList=FRName)
						Duplicate/O root:ForceClamp:Analysis:SelectedForce_Ret, SelectedDeflV_Ret
						Duplicate/O root:ForceClamp:Analysis:SelectedSep_Ret, SelectedZSensorV_Ret

						DoWindow/F FCAnalysis_DefVvsZSensor
						If(V_flag==0)
							Display/K=1/N=FCAnalysis_DefVvsZSensor root:ForceClamp:Analysis:DefV vs root:ForceClamp:Analysis:ZSensor
							AppendToGraph SelectedDeflV_Ret vs SelectedZSensorV_Ret
						EndIf
											
					EndIf
					
					ControlInfo/W=FCAnalysisPanel ShowFvsE_CB
					Variable ShowFvsEGraph=V_Value
					If(ShowFvsEGraph)
						ApplyFuncsToForceWaves("SaveForceAndSep(Force_Ret,Sep_Ret,TargetFolder=\"root:ForceClamp:Analysis:\",NewName=\"Selected\")",FPList=FRName)
						Wave SelectedForce_Ret=root:ForceClamp:Analysis:SelectedForce_Ret
						Wave SelectedSep_Ret=root:ForceClamp:Analysis:SelectedSep_Ret
						Duplicate/O root:ForceClamp:Analysis:DefV, root:ForceClamp:Analysis:ClampForce
						Duplicate/O root:ForceClamp:Analysis:ZSensor, root:ForceClamp:Analysis:ClampSep
						Wave ClampForce=root:ForceClamp:Analysis:ClampForce
						Wave ClampSep=root:ForceClamp:Analysis:ClampSep
						String DefVInfo=note(ClampForce)
						Variable SpringConstant=str2num(StringByKey("K",DefVInfo,"=",";\r"))
						Variable Invols=str2num(StringByKey("\rInvols",DefVInfo,"=",";\r"))
						Wave FRUOffsets=root:FRU:preprocessing:Offsets
						Variable ForceOffset=FRUOffsets[%$FRName][%Offset_Force]
						Variable SepOffset=FRUOffsets[%$FRName][%Offset_Sep]
						ClampForce=-1*ClampForce*SpringConstant*Invols+ForceOffset//-ForceOffset
						SelectedForce_Ret=-1*SelectedForce_Ret+ForceOffset
	
						String ZSensorInfo=note(ClampSep)
						Variable ZSens=str2num(StringByKey("ZLVDTSens",ZSensorInfo,"=",";\r"))
						ClampSep=(-ZSens*ClampSep-ClampForce/SpringConstant)-SepOffset
						SelectedSep_Ret=SelectedSep_Ret-SepOffset
						DoWindow/F FCAnalysis_ForceVsSep
						If(V_flag==0)
							Display/K=1/N=FCAnalysis_ForceVsSep ClampForce vs ClampSep
							AppendToGraph SelectedForce_Ret vs SelectedSep_Ret
						EndIf
						
					
					EndIf
					
				break
			EndSwitch
			
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function FCAnalysisCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	String CBName=cba.CtrlName
	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			StrSwitch(CBName)
				case "UseThisFC_CB":
					Wave UseThisForceClamp=root:ForceClamp:Analysis:UseThisForceClamp
					ControlInfo/W=FCAnalysisPanel FCIndex_SV
					UseThisForceClamp[V_value]=checked

				break
			EndSwitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function DefVtoForce(DefV,Settings,SettingsStr,[ForceWaveName])
	Wave DefV,Settings
	Wave/T SettingsStr
	String ForceWaveName
	If(ParamIsDefault(ForceWaveName))
		ForceWaveName = "ForceWave"
	EndIF

	Duplicate/O DefV, $ForceWaveName
	Wave Force=$ForceWaveName
	
	Wave FRUOffsets=root:MyForceData:Offsets
	String ForceRampName=SettingsStr[%NearestForcePull]
	Variable ForceOffset=FRUOffsets[%$ForceRampName][%Offset_Force]
	String DefVInfo=note(DefV)
	Variable SpringConstant=str2num(StringByKey("K",DefVInfo,"=",";\r"))
	Variable Invols=str2num(StringByKey("\rInvols",DefVInfo,"=",";\r"))
	
	Force=-(DefV-Settings[%DefVOffset])*SpringConstant*Invols//-ForceOffset
	
	Force=-DefV*SpringConstant*Invols+ForceOffset//+Settings[%DefVOffset]*SpringConstant*Invols

End