extends Node2D

var RPM = 0.0
var Comp = 0.0
var Expand = 0.0
var Recov = 0.0
var Power = 0.0
var Output = 0.0
var SetRPM = 0.0
var PrevRPM = 0.0
var PrevRPMTicks = 0.0

var GUI: Node
var GUIRPM: Label
var GUIComp: Label
var GUIExpand: Label
var GUIRecov: Label
var GUIPower: Label
var GUIThrottle: Label
var GUIAutoStart: Button
var GUIOutput: Label
var Throttle: Node
var StarterRPM: AudioStreamPlayer
var RunRPM: AudioStreamPlayer
var ThudRPM: AudioStreamPlayer
var StopRPM: AudioStreamPlayer

const SimTickRate = 30
const PrevRPMTickSteps = 3
const Max_RPM = 10000.0
const Idle_RPM = 1000.0
const Comp_coef = 3.0
const Expand_coef = 1.75
const Recov_effi = 0.85
const StarterTorque = 0.02
const RPMDrag = 0.005
const ThrottleResponse = 0.6
const GearRatio = 100.0

func Round(x: float, y: int) -> float: #improved rounding function
	return round(x * pow(10, y)) / pow(10, y)

func _ready():
	Engine.physics_ticks_per_second = SimTickRate #simulator tick frequency
	GUI = $GUI
	GUIRPM = $GUI/RPM
	GUIComp = $GUI/Compress
	GUIExpand = $GUI/Expand
	GUIRecov = $GUI/Recover
	GUIPower = $GUI/Power
	GUIThrottle = $GUI/Throttle
	GUIAutoStart = $GUI/AutoStart
	GUIOutput = $GUI/Output
	Throttle = $GUI/ThrottleValue
	StarterRPM = $StarterRPM
	RunRPM = $RunRPM
	ThudRPM = $ThudRPM
	StopRPM = $StopRPM

func _process(_delta):
	GUIRPM.text = "RPM: " + str(RPM)
	GUIThrottle.text = "Throttle: " + str(round(Throttle.value * 100)) + "%"
	GUIComp.text = "Compress: " + str(Comp)
	GUIExpand.text = "Expand: " + str(Expand)
	GUIRecov.text = "Recover: " + str(Recov)
	GUIPower.text = "Power: " + str(Power)
	GUIOutput.text = "Output RPM: " + str(Output)

func _physics_process(delta):
	
	########## IDK ##########
	
	# Engine manegment
	PrevRPMTicks += 1 #for engine thud sound control
	RPM = Round(clamp(RPM, 0, Max_RPM), 2) #RPM rounding / clamping
	SetRPM = Throttle.value * Max_RPM # lerp target RPM from 0 to Max_RPM
	Power = Recov - Comp #Power control
	Output = Round((GearRatio * Power), 2) #Engine Power output control
	Comp = Round(((RPM / Max_RPM) * Comp_coef), 2) #compressor control
	var tog = GUIAutoStart.button_pressed #starter toggle variable
	
	if PrevRPMTicks > PrevRPMTickSteps: #for PrevRPMTickSteps clock
		PrevRPMTicks = 0
		PrevRPM = RPM

########## SIMULATION ##########

	# Combustion and expansion stage
	if RPM > Idle_RPM:
		Expand = Round((Comp * Expand_coef), 2)
	else:
		Expand = 0.0

	# Turbine stage
	if Expand > 0:
		Recov = Round((Expand * Recov_effi), 2)
	else:
		Recov = 0.0

########## control ##########

	if tog: #apply acc RPM (starter motor)
		RPM += (Idle_RPM - RPM) * StarterTorque + 1 #starter motor torque logic
	else:
		if RPM < Idle_RPM:
			StopRPM.pitch_scale = 0.125 * (1 - (RPM / Max_RPM)) + (1.25 * (RPM / Max_RPM))
		RPM -= RPM * RPMDrag

	if RPM > Idle_RPM:
		RPM += (SetRPM - RPM) * ThrottleResponse * delta #RPM logic
		RunRPM.pitch_scale = 0.75 * (1 - ((RPM - Idle_RPM) / (Max_RPM - Idle_RPM))) + (1.25 * ((RPM - Idle_RPM) / (Max_RPM - Idle_RPM)))
	else:
		pass

	RPM = Round(clamp(RPM, 0, Max_RPM), 2) #RPM rounding / clamping

########## SOUND ##########

	if RPM > Idle_RPM and !RunRPM.playing:
		RunRPM.play()
		StarterRPM.stop()
		StopRPM.stop()
	elif RPM < Idle_RPM and !StarterRPM.playing and tog:
		RunRPM.stop()
		StarterRPM.play()
		StopRPM.stop()
	elif RPM < Idle_RPM and RPM > 120 and !StopRPM.playing and !tog:
		RunRPM.stop()
		StarterRPM.stop()
		StopRPM.play()
	elif PrevRPM > Idle_RPM and RPM < Idle_RPM and !ThudRPM.playing and !tog:
		ThudRPM.play()
		await get_tree().create_timer(0.2).timeout
	elif tog and RPM > 120 and !StopRPM.playing:
		StopRPM.stop()
