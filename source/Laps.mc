using Toybox.Activity;
using Toybox.Lang;
using Toybox.AntPlus;

module ActiveLook {

    module Laps {

        function hasValue(object as Lang.Object, symbol as Lang.Symbol) as Lang.Boolean {
            return object has symbol && object[symbol] != null;
        }

        var lapNumber as Lang.Number = 0;

        var lapStartTotalHeartRate as Lang.Number = 0;
        var lapStartTotalPower as Lang.Number = 0;
        var lapStartTotalSpeed as Lang.Float = 0.0;
        var lapStartTotalCadence as Lang.Number = 0;
        var lapStartTimerTime as Lang.Number = 0;
        var lapStartElapsedDistance as Lang.Float = 0.0;
        var lapStartTotalAscent as Lang.Number = 0;
        var lapStartTotalDescent as Lang.Number = 0;
        var lapStartCalories as Lang.Number = 0;

        var lapAverageHeartRate as Lang.Number or Null = null;
        var lapAveragePower as Lang.Number or Null = null;
        var lapAveragePace as Lang.Float or Null = null;
        var lapAverageSpeed as Lang.Float or Null = null;
        var lapAverageCadence as Lang.Number or Null = null;
        var lapAverageAscentSpeed as Lang.Float or Null = null;
        var lapTimerTime as Lang.Number or Null = null;
        var lapChrono as Lang.Array<Lang.Number> or Null = null;
        var lapElapsedDistance as Lang.Float or Null = null;
        var lapTotalAscent as Lang.Number or Null = null;
        var lapTotalDescent as Lang.Number or Null = null;
        var lapCalories as Lang.Number or Null = null;

        var __nbGroundContactTime as Lang.Number = 0;
        var __totalGroundContactTime as Lang.Number = 0;
        var lapAverageGroundContactTime as Lang.Float?;

        var __nbVerticalOscillation as Lang.Number = 0;
        var __totalVerticalOscillation as Lang.Float = 0.0;
        var lapAverageVerticalOscillation as Lang.Float?;

        var __nbStepLength as Lang.Number = 0;
        var __totalStepLength as Lang.Number = 0;
        var lapAverageStepLength as Lang.Float?;

        function addLap(activityInfo as Activity.Info) as Void {
            lapNumber += 1;
            lapStartTimerTime = hasValue(activityInfo, :timerTime) ? activityInfo.timerTime : 0;
            lapStartElapsedDistance = hasValue(activityInfo, :elapsedDistance) ? activityInfo.elapsedDistance : 0.0;
            lapStartTotalAscent = hasValue(activityInfo, :totalAscent) ? activityInfo.totalAscent : 0;
            lapStartTotalDescent = hasValue(activityInfo, :totalDescent) ? activityInfo.totalDescent : 0;
            lapStartCalories = hasValue(activityInfo, :calories) ? activityInfo.calories : 0;
            lapStartTotalHeartRate = lapStartTimerTime * (hasValue(activityInfo, :averageHeartRate) ? activityInfo.averageHeartRate : 0);
            lapStartTotalPower = lapStartTimerTime * ( AugmentedActivityInfo.averagePower != null  ? AugmentedActivityInfo.averagePower : 0);
            lapStartTotalSpeed = lapStartTimerTime * (hasValue(activityInfo, :averageSpeed) ? activityInfo.averageSpeed : 0.0);
            lapStartTotalCadence = lapStartTimerTime * (hasValue(activityInfo, :averageCadence) ? activityInfo.averageCadence : 0);
            __nbGroundContactTime = 0;
            __totalGroundContactTime = 0;
            __nbVerticalOscillation = 0;
            __totalVerticalOscillation = 0.0;
            __nbStepLength = 0;
            __totalStepLength = 0;
        }

        function onSessionStart() as Void {
            lapNumber = 0;
            lapStartTimerTime = 0;
            lapStartElapsedDistance = 0.0;
            lapStartTotalAscent = 0;
            lapStartTotalDescent = 0;
            lapStartCalories = 0;
            lapStartTotalHeartRate = 0;
            lapStartTotalPower = 0;
            lapStartTotalSpeed = 0.0;
            lapStartTotalCadence = 0;
            __nbGroundContactTime = 0;
            __totalGroundContactTime = 0;
            __nbVerticalOscillation = 0;
            __totalVerticalOscillation = 0.0;
            __nbStepLength = 0;
            __totalStepLength = 0;
        }

        function accumulateRunningDynamics(runningDynamicsData as AntPlus.RunningDynamicsData?) as Void{
            if (runningDynamicsData == null) {
                return;
            }
            if (runningDynamicsData has :groundContactTime && runningDynamicsData.groundContactTime != null) {
                __totalGroundContactTime += runningDynamicsData.groundContactTime;
                __nbGroundContactTime ++;
            }
            if (runningDynamicsData has :verticalOscillation && runningDynamicsData.verticalOscillation != null) {
                __totalVerticalOscillation += runningDynamicsData.verticalOscillation;
                __nbVerticalOscillation ++;
            }
            if (runningDynamicsData has :stepLength && runningDynamicsData.stepLength != null) {
                __totalStepLength += runningDynamicsData.stepLength;
                __nbStepLength ++;
            }
        }

        function computeRunningDynamics(runningDynamicsData as AntPlus.RunningDynamicsData) as Void{
            if (__nbGroundContactTime > 0) {
                lapAverageGroundContactTime = __totalGroundContactTime / __nbGroundContactTime;
            }
            if (__nbVerticalOscillation > 0) {
                lapAverageVerticalOscillation = __totalVerticalOscillation / __nbVerticalOscillation;
            }
            if (__nbStepLength > 0) {
                lapAverageStepLength = __totalStepLength / __nbStepLength;
            }
        }

        function compute(activityInfo as Activity.Info) as Void {
            lapElapsedDistance = hasValue(activityInfo, :elapsedDistance) ? activityInfo.elapsedDistance - lapStartElapsedDistance : null;
            lapTotalAscent = hasValue(activityInfo, :totalAscent) ? activityInfo.totalAscent - lapStartTotalAscent : null;
            lapTotalDescent = hasValue(activityInfo, :totalDescent) ? activityInfo.totalDescent - lapStartTotalDescent : null;
            lapCalories = hasValue(activityInfo, :calories) ? activityInfo.calories - lapStartCalories : null;
            var sessionTimerTime = hasValue(activityInfo, :timerTime) ? activityInfo.timerTime : null;
            if (sessionTimerTime != null && sessionTimerTime > lapStartTimerTime) {
                lapTimerTime = sessionTimerTime - lapStartTimerTime;
                var sec = lapTimerTime / 1000;
                var mn = sec / 60;
                lapChrono = [mn / 60, mn % 60, sec % 60, lapTimerTime % 1000];
                if (lapTotalAscent != null) {
                    lapAverageAscentSpeed = lapTotalAscent / lapTimerTime;
                } else {
                    lapAverageAscentSpeed = null;
                }
                if (hasValue(activityInfo, :averageHeartRate)) {
                    lapAverageHeartRate = (sessionTimerTime * activityInfo.averageHeartRate - lapStartTotalHeartRate) / lapTimerTime;
                } else {
                    lapAverageHeartRate = null;
                }
                if (AugmentedActivityInfo.averagePower != null) {
                    lapAveragePower = (sessionTimerTime * AugmentedActivityInfo.averagePower - lapStartTotalPower) / lapTimerTime;
                } else {
                    lapAveragePower = null;
                }
                if (hasValue(activityInfo, :averageSpeed)) {
                    lapAverageSpeed = (sessionTimerTime * activityInfo.averageSpeed - lapStartTotalSpeed) / lapTimerTime;
                    if (lapAverageSpeed > 0.0) {
                        lapAveragePace = 1.0 / lapAverageSpeed;
                    } else {
                        lapAveragePace = null;
                    }
                } else {
                    lapAverageSpeed = null;
                    lapAveragePace = null;
                }
                if (hasValue(activityInfo, :averageCadence)) {
                    lapAverageCadence = (sessionTimerTime * activityInfo.averageCadence - lapStartTotalCadence) / lapTimerTime;
                } else {
                    lapAverageCadence = null;
                }
            } else {
                lapAverageHeartRate = null;
                lapAveragePower = null;
                lapAveragePace = null;
                lapAverageSpeed = null;
                lapAverageCadence = null;
                lapAverageAscentSpeed = null;
                lapTimerTime = null;
                lapChrono = null;
            }
        }
    }

}
