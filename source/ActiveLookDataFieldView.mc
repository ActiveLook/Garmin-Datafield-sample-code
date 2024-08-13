using Toybox.Application;
using Toybox.Activity;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;
using Toybox.AntPlus;

using ActiveLookSDK;
using ActiveLook.AugmentedActivityInfo;
using ActiveLook.PageSettings;
using ActiveLook.Layouts;
using ActiveLook.Laps;

//! Private logger enabled in debug and disabled in release mode
(:release) function log(msg as Toybox.Lang.String, data as Toybox.Lang.Object or Null) as Void {}
(:release) function arrayToHex(array as Toybox.Lang.ByteArray or Toybox.Lang.Array<Toybox.Lang.Integer>) as Toybox.Lang.String { return ""; }
(:debug)   function arrayToHex(array as Toybox.Lang.ByteArray or Toybox.Lang.Array<Toybox.Lang.Integer>) as Toybox.Lang.String {
    var msg = "[";
    var prefix = "";
    for(var i = 0; i < array.size(); i++) {
        msg = Toybox.Lang.format("$1$$2$0x$3$", [msg, prefix, array[i].format("%02X")]);
        prefix = ", ";
    }
    return Toybox.Lang.format("$1$]", [msg]);
}
(:debug)   function log(msg as Toybox.Lang.String, data as Toybox.Lang.Object or Null) as Void {
    if (data instanceof Toybox.Lang.ByteArray) { data = arrayToHex(data); }
    if (data instanceof Toybox.Lang.Exception) { data.printStackTrace() ; data = data.getErrorMessage(); }
    Toybox.System.println(Toybox.Lang.format("[D]$1$ $2$", [msg, data]));
}

var sdk as ActiveLookSDK.ALSDK = null as ActiveLookSDK.ALSDK;
var pagesSpec as Lang.Array<PageSettings.PageSpec> = [] as Lang.Array<PageSettings.PageSpec>;
var pageIdx as Lang.Number = 0;
var swipe as Lang.Boolean = false;
var battery as Lang.Number or Null = null;
var tempo_off as Lang.Number = -1;
var tempo_pause as Lang.Number = -1;
var tempo_lap_freeze as Lang.Number = -1;
var tempo_congrats as Lang.Number = 1;
var currentLayouts as Lang.Array<Layouts.GeneratorArguments> = [] as Lang.Array<Layouts.GeneratorArguments>;
var runningDynamics as Toybox.AntPlus.RunningDynamics or Null = null;

// ToDo : différence pause stop
// 1) Event onTimerStop  devrait être considéré comme un onTimerPause
// 2) Pour afficher le Congrats : Compute vérifier durée de la session,
//      Si on a onTimerStopEvent et que dans le compute nouvelle Session Timer = 0
//      Alors afficher le Congrats --> onTimerStop mécanique
//      Sinon c'est une pause
// Trois cas : onTimerStop qui est un onTimerPause, onTimerPause et onTimerStop

// ToDo : Laps Warning Mémoir compatibility devices
// 1) Quand lap bouton activer
// 2) Stocker toute la session d'Activity
// 3) Afficher les valeurs avec un différentiel des données sauvegardées et les données de l'Activity

(:typecheck(false))
function resetGlobals() as Void {
    try {
        var _ai = "screens";
        if (Toybox.Activity has :getProfileInfo) {
            var profileInfo = Toybox.Activity.getProfileInfo();
            if (profileInfo has :sport) {
                switch (profileInfo.sport) {
                    case Toybox.Activity.SPORT_RUNNING: { _ai = "run";     break; }
                    case Toybox.Activity.SPORT_CYCLING: { _ai = "bike";    break; }
                    default:                            { _ai = "screens"; break; }
                }
            }
        }
        $.pagesSpec = PageSettings.strToPages(Application.Properties.getValue(_ai), "(1,12,2)(15,4,2)(10,18,22)(0)");
    } catch (e) {
        $.pagesSpec = PageSettings.strToPages("(1,12,2)(15,4,2)(10,18,22)(0)", null);
    }
    // $.pagesSpec = PageSettings.strToPages(
    //     "0, 1,2,3,4,5,6,7,8,9,10,11,(1),(2,3),(4,5,6),(7,8,9,10),(11,12,13,14,15,16),(17,18,19,20,21,22),(23,24,25,27,28,29)",
    // "1,2,3,0");
    // $.pagesSpec = PageSettings.strToPages("1,2,3,0", "1,2,3,0");
    $.pageIdx = 0;
    $.swipe = false;
    $.tempo_off = -1;
    $.tempo_pause = -1;
    $.tempo_lap_freeze = -1;
    $.tempo_congrats = 0;
    $.updateCurrentLayouts(0);
}

function updateCurrentLayouts(incr as Lang.Number) as Void {
    if (incr != 0) {
        var nextPageIdx = ($.pageIdx + incr) % pagesSpec.size();
        if ($.pageIdx != nextPageIdx) {
            $.pageIdx = nextPageIdx;
            incr = 0;
        }
    }
    if (incr == 0) {
        $.currentLayouts = Layouts.pageToGenerator($.pagesSpec[$.pageIdx]);
    }
}

(:typecheck(false))
function updateFields() as Void {
    var after = $.currentLayouts.size();
    if ($.swipe == true) {
        //Todo reset tempo
         if($.tempo_off > 0){
            $.tempo_off = 0;
         }
         if ($.tempo_pause > 0) {
            $.tempo_pause = 0;
         }
         if ($.tempo_congrats > 0) {
            $.tempo_congrats = 1;
         }
    }
    if ($.tempo_off > 0) {
        $.tempo_off -= 1;
        if ($.tempo_off == 0) {
            var fullBuffer = $.sdk.commandBuffer(0x01, []b) as Lang.ByteArray; // Clear Screen
            fullBuffer.addAll($.sdk.commandBuffer(0x00, [0x00]b)); // turn off screen
            $.sdk.sendRawCmd(fullBuffer);
            $.sdk.resetLayouts([]);
        }
        return;
    }
    if ($.tempo_pause > 0) {
        $.tempo_pause -= 1;
        if ($.tempo_pause == 0) {
            var fullBuffer = $.sdk.commandBuffer(0x01, []b) as Lang.ByteArray; // Clear Screen
            fullBuffer.addAll($.sdk.commandBuffer(0x62, [0x49, 0x00]b)); // layout petit pause
            $.sdk.sendRawCmd(fullBuffer);
            $.sdk.resetLayouts([]);
        }
        return;
    }
    if ($.tempo_congrats > 0) {
        $.tempo_congrats -= 1;
        if ($.tempo_congrats == 0) {
            var fullBuffer = $.sdk.commandBuffer(0x01, []b) as Lang.ByteArray; // Clear Screen
            fullBuffer.addAll($.sdk.commandBuffer(0x62, [0x4B, 0x00]b)); // layout ready
            $.sdk.sendRawCmd(fullBuffer);
            $.sdk.resetLayouts([]);
        }
        return;
    }
    if ($.tempo_congrats == 0) {
        return;
    }
    if ($.tempo_lap_freeze >= 0) {
        $.tempo_lap_freeze -= 1;
        if ($.tempo_lap_freeze >= 8) {
            return;
        }
        if ($.tempo_lap_freeze >= 7) {
            $.sdk.clearScreen();
        }
    }
    if ($.swipe == true) {
        var before = after;
        $.swipe = false;
        $.updateCurrentLayouts(1);
        var fullBuffer = $.sdk.commandBuffer(0x01, []b) as Lang.ByteArray; // Clear Screen
        if ($.tempo_pause == 0) {
            fullBuffer.addAll($.sdk.commandBuffer(0x62, [0x49, 0x00]b)); // layout petit pause
        }
        after = $.currentLayouts.size();
        if (before == 0 && after > 0) {
            $.tempo_off = -1;
            fullBuffer.addAll($.sdk.commandBuffer(0x00, [0x01]b)); // turn on screen
        } else if (after == 0) {
            $.tempo_off = 2;
            fullBuffer.addAll($.sdk.commandBuffer(0x62, [0x64, 0x00]b)); // layout screen off
            $.sdk.sendRawCmd(fullBuffer);
            $.sdk.resetLayouts([]);
            return;
        }
        $.sdk.sendRawCmd(fullBuffer);
        $.sdk.resetLayouts([]);
    }
    if ($.tempo_off == 0) {
        return;
    }
    $.sdk.flushCmdStackingIfSup(200);
    $.sdk.holdGraphicEngine();
    for (var i = 0; i < after; i++) {
        var asStr = Layouts.get($.currentLayouts[i]);
        log("updateFields", [i, asStr, $.currentLayouts]);
        $.sdk.updateLayoutValue($.currentLayouts[i][:id], asStr);
    }
    $.sdk.flushGraphicEngine();
}

(:typecheck(false))
class DataFieldDrawable extends WatchUi.Drawable {

    public var bg as Graphics.ColorType = Graphics.COLOR_DK_GRAY;
    public var updateMsg as Lang.String? = null;
    public var updateMsgSecondRow as Lang.String? = null;
    public var updateMsgThirdRow as Lang.String? = null;

    function initialize() {
        Drawable.initialize({ :id => "canvas" });
    }

    function draw(dc as Graphics.Dc) as Void {
        var fg = self.bg == Graphics.COLOR_BLACK ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        var justify = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(fg, self.bg);
        dc.clear();
        var midX = dc.getWidth() / 2d;                // x 50%
        var midY = dc.getHeight() * 3d / 5d;          // y 60%
        if(self.updateMsg != null && self.updateMsgSecondRow != null && self.updateMsgThirdRow != null){
            dc.drawText(midX, midY - 40d, Graphics.FONT_XTINY, self.updateMsg, justify); // (50%, 20%)
            dc.drawText(midX, midY - 20d, Graphics.FONT_XTINY, self.updateMsgSecondRow, justify); // (50%, 40%)
            dc.drawText(midX, midY, Graphics.FONT_XTINY, self.updateMsgThirdRow, justify); // (50%, 60%)
        }else if (self.updateMsg != null) {
            dc.drawText(midX, midY / 4, Graphics.FONT_XTINY, "ActiveLook", justify); // (50%, 15%)
            dc.drawText(midX, midY, Graphics.FONT_XTINY, self.updateMsg, justify); // (50%, 60%)
        }else {
            dc.drawText(midX, midY / 4, Graphics.FONT_XTINY, "ActiveLook", justify); // (50%, 15%)
            var font = WatchUi.loadResource(Rez.Fonts.alfont) as Graphics.FontType;
            if (!ActiveLookSDK.isReady()) {
                // status: 5 = not connected
                dc.drawText(midX, midY, font, "5", justify); // (50%, 60%)
            } else {
                // status: 4 = connected
                dc.drawText(midX / 2, midY, font, "4", justify); // (25%, 60%)
                // page number = pageIdx + 1
                dc.drawText(midX, midY, Graphics.FONT_MEDIUM, ($.pageIdx + 1).format("%d"), justify); // (50%, 60%)
                // battery;
                if ($.battery != null) {
                    var batteryStr =
                          $.battery < 10 ? "0"
                        : $.battery < 50 ? "1"
                        : $.battery < 90 ? "2"
                        : "3";
                    dc.drawText(midX * 3 / 2, midY, font, batteryStr, justify); // (75%, 60%)
                }
            }
        }
    }
}

(:typecheck(false))
class ActiveLookDataFieldView extends WatchUi.DataField {

    hidden var __heart_count = 0;
    hidden var __lastError = null;
  
    var __is_auto_loop = Toybox.Application.Properties.getValue("is_auto_loop") as Toybox.Lang.Boolean or Null;
    var __loop_timer = Toybox.Application.Properties.getValue("loop_timer") as Toybox.Lang.Integer or Null;

    var _currentGestureStatus = Toybox.Application.Properties.getValue("is_gesture_enable") as Toybox.Lang.Boolean;
    var _nextGestureStatus = Toybox.Application.Properties.getValue("is_gesture_enable") as Toybox.Lang.Boolean;
    var _currentAlsStatus = Toybox.Application.Properties.getValue("is_als_enable") as Toybox.Lang.Boolean;
    var _nextAlsStatus = Toybox.Application.Properties.getValue("is_als_enable") as Toybox.Lang.Boolean;
    
    private var canvas as DataFieldDrawable = new DataFieldDrawable();

    function initialize() {
        DataField.initialize();
        $.resetGlobalsNext();
        $.sdk = new ActiveLookSDK.ALSDK(self);
        View.setLayout([self.canvas]);
        if(Toybox.AntPlus has :RunningDynamics) {
    		runningDynamics = new Toybox.AntPlus.RunningDynamics(null);
		}
    }

    function onLayout(dc) {
        self.canvas.bg = self.getBackgroundColor();
        return View.onLayout(dc);
    }

    function compute(info) {
        _nextGestureStatus = Toybox.Application.Properties.getValue("is_gesture_enable");
        _nextAlsStatus = Toybox.Application.Properties.getValue("is_als_enable");
        AugmentedActivityInfo.accumulate(info);
        AugmentedActivityInfo.compute(info);
        var rdd = null;
        if (runningDynamics != null) {
            rdd = runningDynamics.getRunningDynamics();
            ActiveLook.Laps.accumulateRunningDynamics(rdd);
            AugmentedActivityInfo.accumulateRunningDynamics(rdd);
            AugmentedActivityInfo.computeRunningDynamics(rdd);
        }
        if ($.tempo_lap_freeze == -1) {
            ActiveLook.Laps.compute(info);
            if (rdd != null) {
                ActiveLook.Laps.computeRunningDynamics(rdd);
            }
        }
        self.__heart_count += 1;
        if (self.__heart_count < 0) {
            log("compute", [info, self.__heart_count]);
            return null;
        }
		if (ActiveLookSDK.isIdled() && !ActiveLookSDK.isReconnecting && !ActiveLookSDK.isConnected()) {
			$.sdk.startGlassesScan();
		} else if (!ActiveLookSDK.isReady()) {
			if (self.__lastError != null && (self.__heart_count - self.__lastError) > 50) {
				self.__lastError = null;
				$.sdk.disconnect();
			} else if (ActiveLookSDK.isConnected()) {
				return $.sdk.setUpDevice();
			}
		} else {
			self.__lastError = null;
		}
        var ct = System.getClockTime();
        var hour = ct.hour;
        if (System.getDeviceSettings().is24Hour == false && hour > 12) {
            hour = hour - 12;
        }
        if (ActiveLookSDK.isReady()) {
            log("compute::updateFields  ", [self.__heart_count]);
            if(self.__is_auto_loop){
                if(self.__loop_timer.equals(0)){
                    log("onLoopEvent", []);
                    $.swipe = true;
                    self.__loop_timer = Toybox.Application.Properties.getValue("loop_timer");
                }else{
                    self.__loop_timer -= 1;
                }
            }

            $.updateFields();
            if ($.tempo_off < 0 && $.tempo_pause <= 0 && $.tempo_congrats < 0 && $.tempo_lap_freeze <= 7) {
                $.sdk.setTime(hour, ct.min);
                $.sdk.setBattery($.battery);
                $.sdk.resyncGlasses();
            }
            if(_nextGestureStatus != _currentGestureStatus){
                _currentGestureStatus = _nextGestureStatus;
                self.onSettingClickGestureEvent();
            }
            if(_nextAlsStatus != _currentAlsStatus){
                _currentAlsStatus = _nextAlsStatus;
                self.onSettingClickAlsEvent();
            }
        }
        // if (runningDynamics != null) {
		//     var __rd = runningDynamics.getRunningDynamics();
		//     if (__rd != null) {
		//         var stepPerMinutes = __rd.cadence;
		//         var verticalOscillation = __rd.verticalOscillation;
		//         var groundContactTime = __rd.groundContactTime;
		//         var stepLength = __rd.stepLength;

		//         var data = []b;
        //         data.addAll($.sdk.numberToFixedSizeByteArray(250, 2));
        //         data.addAll($.sdk.numberToFixedSizeByteArray(170, 2));
        //         data.addAll([4, 3, 15]b);
        //         data.addAll($.sdk.stringToPadByteArray(
        //             Toybox.Lang.format("$1$", [verticalOscillation]), null, null
        //         ));
        //         var fullBuffer = $.sdk.commandBuffer(0x01, []b) as Lang.ByteArray; // Clear Screen
        //         fullBuffer.addAll($.sdk.commandBuffer(0x37, data)); // Text
        //         $.sdk.sendRawCmd(fullBuffer);
		//     }
		// }
        return null;
    }

    //! The activity timer has started.
    //! This method is called when the activity timer goes from a stopped state to a started state.
    //! If the activity timer is running when the app is loaded, this event will run immediately after startup.
    function onTimerStart() {
        if ($.tempo_pause == -1) { // If not in pause mode, it is a new session
            AugmentedActivityInfo.onSessionStart();
        }
        self.onTimerResume();
    }

    //! The activity timer is paused.
    //! This method is called when the activity timer goes from a running state to a paused state.
    //! The paused state occurs when the auto-pause feature pauses the timer.
    //! If the activity timer is paused when the app is loaded, this event will run immediately after startup.
    function onTimerPause() {
        $.tempo_congrats = -1;
        if ($.tempo_off == -1) {
            $.tempo_pause = 6;
            if (ActiveLookSDK.isReady()) {
                var fullBuffer = $.sdk.commandBuffer(0x01, []b) as Lang.ByteArray; // Clear Screen
                fullBuffer.addAll($.sdk.commandBuffer(0x62, [0x62, 0x00]b)); // layout pause
                $.sdk.sendRawCmd(fullBuffer);
                $.sdk.resetLayouts([]);
            }
        } else {
            $.tempo_pause = 1;
        }
    }

    //! The activity time has resumed.
    //! This method is called when the activity timer goes from a paused state to a running state.
    function onTimerResume() {
        $.tempo_pause = -1;
        $.tempo_congrats = -1;
        if ($.tempo_off == -1) {
            if (ActiveLookSDK.isReady()) {
                $.sdk.clearScreen();
            }
        }
    }

    //! The activity timer has stopped.
    //! This method is called when the activity timer goes from a running state to a stopped state.
    function onTimerStop() {
        self.onTimerPause(); // In fact, it is a pause. The reset event is the real stop.
    }

    //! The current activity has ended.
    //! This method is called when the time has stopped and current activity is ended.
    function onTimerReset() as Void {
        $.tempo_pause = -1;
        if ($.tempo_off == -1) {
            $.tempo_congrats = 6;
            if (ActiveLookSDK.isReady()) {
                var fullBuffer = $.sdk.commandBuffer(0x01, []b) as Lang.ByteArray; // Clear Screen
                fullBuffer.addAll($.sdk.commandBuffer(0x62, [0xB4, 0x00]b)); // layout Session Complete
                $.sdk.sendRawCmd(fullBuffer);
                $.sdk.resetLayouts([]);
                resetGlobals();
            }
        } else {
            $.tempo_congrats = 1;
        }
    }

    function onTimerLap() as Void {
        AugmentedActivityInfo.addLap();
        $.tempo_lap_freeze = 10;
        $.tempo_pause = -1;
        $.tempo_congrats = -1;
        if ($.tempo_off == -1) {
            if (ActiveLookSDK.isReady()) {
                var data = []b;
                data.addAll($.sdk.numberToFixedSizeByteArray(250, 2));
                data.addAll($.sdk.numberToFixedSizeByteArray(170, 2));
                data.addAll([4, 3, 15]b);
                data.addAll($.sdk.stringToPadByteArray(
                    Toybox.Lang.format("Lap #$1$", [ActiveLook.Laps.lapNumber % 100]), null, null
                ));
                var fullBuffer = $.sdk.commandBuffer(0x01, []b) as Lang.ByteArray; // Clear Screen
                fullBuffer.addAll($.sdk.commandBuffer(0x37, data)); // Text lap number
                $.sdk.sendRawCmd(fullBuffer);
                $.sdk.resetLayouts([]);
            }
        }
    }
    function onNextMultisportLeg() as Void {
        self.onTimerLap();
    }
    function onWorkoutStepComplete() as Void {
        self.onTimerLap();
    }

    //////////////////
    // SDK Listener //
    //////////////////
    function onFirmwareEvent(major as Toybox.Lang.Number, minor as Toybox.Lang.Number, patch as Toybox.Lang.Number) as Void {
        $.log("onFirmwareEvent", [major, minor, patch]);
        major -= 4;
        minor -= 6;
        if (major > 0) {
            self.canvas.updateMsg = Application.loadResource(Rez.Strings.update_datafield);
        } else if (major < 0 || minor < 0) {
            self.canvas.updateMsg = Application.loadResource(Rez.Strings.update_glasses);
            self.canvas.updateMsgSecondRow = Application.loadResource(Rez.Strings.update_glasses_second_row);
            self.canvas.updateMsgThirdRow = Application.loadResource(Rez.Strings.update_glasses_third_row);
        } else {
            self.canvas.updateMsg = null;
            self.canvas.updateMsgSecondRow = null;
            self.canvas.updateMsgThirdRow = null;
            var data = $.sdk.stringToPadByteArray("ALooK", null, null);
            var cfgSet = $.sdk.commandBuffer(0xD2, data);
            $.sdk.sendRawCmd(cfgSet);
        }
    }
    function onCfgVersionEvent(cfgVersion as Toybox.Lang.Number) as Void {
        $.log("onCfgVersionEvent", [cfgVersion]);
        cfgVersion -= 12;
        if (cfgVersion < 0 && self.canvas.updateMsg == null) {
            self.canvas.updateMsg = Application.loadResource(Rez.Strings.update_glasses);
            self.canvas.updateMsgSecondRow = Application.loadResource(Rez.Strings.update_glasses_second_row);
            self.canvas.updateMsgThirdRow = Application.loadResource(Rez.Strings.update_glasses_third_row);
        }
    }
    function onGestureEvent() as Void {
        $.log("onGestureEvent", []);
        $.swipe = true;
        if(self.__is_auto_loop){self.__loop_timer = Toybox.Application.Properties.getValue("loop_timer");}
    }
    function onBatteryEvent(batteryLevel as Toybox.Lang.Number) as Void {
        $.log("onBatteryEvent", [batteryLevel]);
        $.battery = batteryLevel;
    }
    function onDeviceReady() as Void {
        $.log("onDeviceReady", []);
        if ($.tempo_off >= 0) {
            $.tempo_off = 2;
            $.tempo_pause = -1;
            $.tempo_congrats = -1;
            return;
        }
        $.tempo_off = -1;
        if ($.tempo_pause >= 0) {
            $.tempo_pause = 1;
            $.tempo_congrats = -1;
            return;
        }
        $.tempo_pause = -1;
        if ($.tempo_congrats >= 0) {
            $.tempo_congrats = 1;
            return;
        }
        $.sdk.clearScreen();
        $.tempo_congrats = -1;
    }
    function onDeviceDisconnected() as Void {
        $.log("onDeviceDisconnected", []);
        $.swipe = false;
        $.battery = null;
    }
    function onBleError(exception as Toybox.Lang.Exception) as Void {
        // $.log("onBleError", exception);
        if (self.__lastError == null) {
            self.__lastError = self.__heart_count;
        }
    }
    function onSettingClickGestureEvent(){
        if (ActiveLookSDK.isReady()) {
            $.log("onSettingClickGestureEvent", []);
            var data = []b;
            if(_currentGestureStatus){data = [0x01]b;}else{data = [0x00]b;}
            var gestureSet = $.sdk.commandBuffer(0x21, data);
            $.sdk.sendRawCmd(gestureSet);
        }
    }
    function onSettingClickAlsEvent(){
        if (ActiveLookSDK.isReady()) {
            $.log("onSettingClickAlsEvent", []);
            var data = []b;
            if(_currentAlsStatus){data = [0x01]b;}else{data = [0x00]b;}
            var alsSet = $.sdk.commandBuffer(0x22, data);
            $.sdk.sendRawCmd(alsSet);
        }
    }
}

//! Global variables.
var glassesName as Toybox.Lang.String = "";

//! Reset global variables.
//! They represent the actual state of the DataField.
function resetGlobalsNext() as Void {
    $.resetGlobals();
    var __glassesName = Toybox.Application.Properties.getValue("glasses_name") as Toybox.Lang.String or Null;
    if (__glassesName == null) { __glassesName = ""; }
    // TODO: >>> Remove deprecated backward compatibility
    if (__glassesName.equals("")) {
        __glassesName = Application.Storage.getValue("glasses");
        if (__glassesName == null) { __glassesName = ""; }
        Toybox.Application.Properties.setValue("glasses_name", __glassesName);
        Toybox.Application.Storage.setValue("glasses", __glassesName);
    }
    // TODO: <<< Remove deprecated backward compatibility
    $.glassesName = __glassesName as Toybox.Lang.String;
}

//! Global ScanRescult handler.
//! Defining it in this scope make it available from anywhere.
function onScanResult(scanResult as Toybox.BluetoothLowEnergy.ScanResult) as Void {
    $.log("onScanResult", [scanResult]);
    var deviceName = scanResult.getDeviceName();
    if (scanResult.getDeviceName() == null) { deviceName = ""; }
    if ($.glassesName.equals("")) {
        Toybox.Application.Properties.setValue("glasses_name", deviceName);
        $.glassesName = deviceName as Toybox.Lang.String;
    } else if (!$.glassesName.equals(deviceName)) { return; }
    $.sdk.connect(scanResult);
}
