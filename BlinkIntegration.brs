'BlinkIntegration Brightsign plug-in

' Initialisation
Function BlinkIntegration_Initialize(msgPort As Object, userVariables As Object, bsp as Object) as Object
    BlinkIntegration = newBlinkIntegration(msgPort, userVariables, bsp)
    return BlinkIntegration
End Function

' Création de l'objet plugin
Function newBlinkIntegration(msgPort As Object, userVariables As Object, bsp as Object)
	s = {}

	' Variables
	s.ipServer = "192.168.120.1"

	' Recopie
	s.msgPort = msgPort
	s.userVariables = userVariables
	s.bsp = bsp
	s.dlog = dlog

	' Fonctions génériques
	s.ProcessEvent = BlinkIntegration_ProcessEvent
	s.FindWidget = BlinkIntegration_FindWidget
	s.widgetFounded = invalid
	s.sendCEC = sendCEC

	' Fonctions HTML
	s.handleHtmlEventPlugin = handleHtmlEventPlugin
	
	' Fonctions de veille
	s.videoMode = CreateObject("roVideoMode")
	s.low_energy = "false"

	' Device Infos
	s.deviceInfos = CreateObject("roDeviceInfo")

	' Fonctions de récéption UDP
	s.handleUdpEventPlugin = handleUdpEventPlugin
	s.udpReceiverPort = 5555
	s.udpReceiver = CreateObject("roDatagramReceiver", s.udpReceiverPort)
	s.udpReceiver.SetPort(msgPort)

	' Fonctions d’envoi UDP
	s.udpSender = CreateObject("roDatagramSender")
	s.sendMonitoring = sendMonitoring
	
	return s
End Function



' Réception d’infos depuis le JavaScript
Function handleHtmlEventPlugin(event as Object, obj as Object) as boolean
	retval = false
	
	payload = event.GetData()
	if payload.reason = "message" then
		if payload.message.action <> invalid then
			msg$ = LCase(payload.message.action)
			obj.dlog("Réception du message JavaScript " + msg$)
	
			if      msg$ = "reboot" then
				RebootSystem()
			else if msg$ = "restart" then
				print "Restart is made in web"
			else if msg$ = "poweroff" then
				ShutdownSystem()
			else if msg$ = "sleep" then
				obj.sendCEC("4036", obj)
				obj.videoMode.SetPowerSaveMode(true)
				obj.low_energy = "true"
			else if msg$ = "shutdown" then
				obj.videoMode.SetPowerSaveMode(true)
			else if msg$ = "wake" then
				obj.sendCEC("400D", obj)
				obj.videoMode.SetPowerSaveMode(false)
				obj.low_energy = "false"
			else if msg$ = "monitoring" then
				obj.sendMonitoring(obj.ipServer, obj)
			else if msg$ = "noudp" then
				obj.ipServer = ""
			end if
		end if
	end if
	
	return retval
End Function



' Réception d’infos en UDP
Function handleUdpEventPlugin(event As Object, obj as Object) as boolean
	retval = false
	
	msg$ = LCase(event)
	obj.dlog("Réception du datagramme " + msg$)
	
	if      left(msg$, 6) = "reboot" then
		RebootSystem()
	else if left(msg$, 7) = "restart" then
		RestartApplication()
	else if left(msg$, 8) = "poweroff" then
		ShutdownSystem()
	else if left(msg$, 8) = "shutdown" then
		obj.videoMode.SetPowerSaveMode(true)
	else if left(msg$, 5) = "sleep" then
		obj.sendCEC("4036", obj)
		obj.videoMode.SetPowerSaveMode(true)
		obj.low_energy = "true"
	else if left(msg$, 4) = "wake" then
		obj.videoMode.SetPowerSaveMode(false)
		obj.sendCEC("400D", obj)
		obj.low_energy = "false"
	else if left(msg$, 10) = "monitoring" then
		obj.sendMonitoring(obj.ipServer, obj)
	else if left(msg$, 5) = "noudp" then
		obj.ipServer = ""
	end if

	return retval
End Function


' Envoie le monitoring
Sub sendMonitoring(ip$ as String, obj as Object)
	unitName$ = "BrightSign" + " " + obj.deviceInfos.GetModel()
	unitDescription$ = ""

	obj.dlog("Extraction des informations de sync")
	localCurrentSync = CreateObject("roSyncSpec")
    if localCurrentSync.ReadFromFile("local-sync.xml") or localCurrentSync.ReadFromFile("localSetupToStandalone-sync.xml") then
		unitName$        = localCurrentSync.LookupMetadata("client", "unitName")
		unitDescription$ = localCurrentSync.LookupMetadata("client", "unitDescription")
	endif
	

	obj.dlog("Création du monitoring")
	message = "{"
	message = message + Chr(34) + "os"           + Chr(34) + ": {"
	message = message + Chr(34) + "lifetime"     + Chr(34) + ": " + StrI(obj.deviceInfos.GetDeviceLifetime())  + ","
	message = message + Chr(34) + "uptime"       + Chr(34) + ": " + StrI(obj.deviceInfos.GetDeviceUptime())    + ","
	message = message + Chr(34) + "bootCount"    + Chr(34) + ": " + StrI(obj.deviceInfos.GetDeviceBootCount()) + ","
	message = message + Chr(34) + "platform"     + Chr(34) + ": " + Chr(34) + obj.deviceInfos.GetFamily() + Chr(34) + ","
	message = message + Chr(34) + "version"      + Chr(34) + ": " + Chr(34) + obj.deviceInfos.GetBootVersion() + " / " + obj.deviceInfos.GetVersion() + Chr(34) + "}, "

	message = message + Chr(34) + "device"       + Chr(34) + ": {"
	message = message + Chr(34) + "model"        + Chr(34) + ": " + Chr(34) + obj.deviceInfos.GetModel()          + Chr(34) + ","
	message = message + Chr(34) + "manufacturer" + Chr(34) + ": " + Chr(34) + "BrightSign"                        + Chr(34) + ","
	message = message + Chr(34) + "uuid"         + Chr(34) + ": " + Chr(34) + obj.deviceInfos.GetDeviceUniqueId() + Chr(34) + ","
	message = message + Chr(34) + "name"         + Chr(34) + ": " + Chr(34) + unitName$        + Chr(34) + ","
	message = message + Chr(34) + "description"  + Chr(34) + ": " + Chr(34) + unitDescription$ + Chr(34) + "}, "

	message = message + Chr(34) + "energy"       + Chr(34) + ": {"
	message = message + Chr(34) + "low"          + Chr(34) + ": " + obj.low_energy + ","
	message = message + Chr(34) + "force"        + Chr(34) + ": " + "false" + "}, "

	message = message + Chr(34) + "screen"       + Chr(34) + ": {" + Chr(34) + "size" + Chr(34) + ": {"
	message = message + Chr(34) + "width"        + Chr(34) + ": " + StrI(obj.videoMode.GetOutputResX()) + ","
	message = message + Chr(34) + "height"       + Chr(34) + ": " + StrI(obj.videoMode.GetOutputResY()) + "}}"

	message = message + "}"

	
	if ip$ <> "" then
		obj.dlog("Envoi en UDP à " + ip$)
		obj.udpSender.SetDestination(ip$, 5555)
		obj.udpSender.Send(message)
	end if
	
	
	obj.dlog("Envoi au JavaScript")
	if obj.widgetFounded = invalid
		obj.FindWidget("roHtmlWidget", obj)
		
		if obj.widgetFounded = invalid
			obj.dlog("Widget trouvé")
		else
			obj.dlog("Widget introuvable")
		end if
	end if
	if obj.widgetFounded <> invalid
		obj.dlog("Envoi au widget roHtmlWidget")
		obj.widgetFounded.PostJSMessage({infos: message})
	end if
End Sub



' Événements levés par le gestionnaires d’événements interne
Function BlinkIntegration_ProcessEvent(event As Object) as boolean
	retval = false
	
	m.dlog("Réception d'un événément " + type(event))
	if type(event) = "roHtmlWidgetEvent" then
		retval = handleHtmlEventPlugin(event, m)
	else if type(event) = "roDatagramEvent" then
		retval = handleUdpEventPlugin(event, m)
	end if

	return retval
End Function



' Recherche un widget par son type
Sub BlinkIntegration_FindWidget(widgetType$ as String, obj as Object)
	obj.dlog("Recherche d'un widget de type " + widgetType$)
	for each zone in m.bsp.sign.zonesHSM
		if zone.displayedHtmlWidget <> invalid then
			' Widget direct
			' obj.dlog("-> displayedHtmlWidget " + type(zone.displayedHtmlWidget))
			obj.widgetFounded = zone.displayedHtmlWidget			
		else if zone.widget <> invalid then
			' Recherche dans les widgets
			' obj.dlog("-> widget " + type(zone.widget))
			if type(zone.widget) = widgetType$ then
				obj.widgetFounded = zone.widget
			end if
		end if
	next	
End Sub


' Envoie une commande CEC
Sub sendCEC(cecCommand$ As String, obj as Object)
	obj.dlog("Envoi de la commande CEC " + cecCommand$)

	cec = CreateObject("roCecInterface")
	if type(cec) = "roCecInterface" then
		b = CreateObject("roByteArray")
		b.fromhexstring(cecCommand$)
		cec.SendRawMessage(b)
		cec = invalid
	endif
End Sub


' Log dans la console Web
Sub dlog(message$ as string)
	slog = createobject("roSystemLog")
	slog.sendline(message$)
End Sub