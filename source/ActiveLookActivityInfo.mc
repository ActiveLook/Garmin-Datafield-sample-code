using Toybox.Activity;
using Toybox.Lang;
using Toybox.Math;
using Toybox.StringUtil;
using Toybox.System;
using ActiveLook.Laps;
using Toybox.AntPlus;

function mapToBounds(v as Lang.Number or Null, lo as Lang.Number, hi as Lang.Number) as Lang.Number {
    if (v == null) { return lo; }
    if (v <= lo)   { return lo; }
    if (v >= hi)   { return hi; }
    return v;
}

(:typecheck(false))
module ActiveLook {

    module AugmentedActivityInfo {

        var __ai as Activity.Info?;
        var __rdd as AntPlus.RunningDynamicsData?;

        var chrono as Lang.Array<Lang.Number>?;

        var currentPace as Lang.Float?;
        var fastestPace as Lang.Float?;
        var averagePace as Lang.Float?;

        var __pSamples as Lang.Array<Lang.Float> = [];
        var __pAccu as Lang.Float = 0.0;
        var __pAccuNb as Lang.Number = 0;
        var threeSecPower as Lang.Float?;
        var normalizedPower as Lang.Float?;
        var maxPower as Lang.Float?;
        var averagePower as Lang.Float?;
        var __pavgAccuNb as Lang.Float = 0.0;

        var __nbGroundContactTime as Lang.Number = 0;
        var __totalGroundContactTime as Lang.Number = 0;
        var averageGroundContactTime as Lang.Float?;

        var __nbVerticalOscillation as Lang.Number = 0;
        var __totalVerticalOscillation as Lang.Float = 0.0;
        var averageVerticalOscillation as Lang.Float?;

        var __nbStepLength as Lang.Number = 0;
        var __totalStepLength as Lang.Number = 0;
        var averageStepLength as Lang.Float?;

        var __asSamples as Lang.Array<Lang.Number> = [];
        var averageAscentSpeed as Lang.Float?;

        function onSessionStart() {
            __ai = null;
            __rdd = null;
            chrono  = null;
            currentPace = null;
            fastestPace = null;
            averagePace = null;
            __pSamples = [];
            __pAccu = 0.0;
            __pAccuNb = 0;
            threeSecPower = null;
            normalizedPower = null;
            maxPower = null;
            averagePower = null;
            __pavgAccuNb = 0.0;
            __nbGroundContactTime = 0;
            __totalGroundContactTime = 0;
            averageGroundContactTime = null;
            __nbVerticalOscillation = 0;
            __totalVerticalOscillation = 0.0;
            averageVerticalOscillation = null;
            __nbStepLength = 0;
            __totalStepLength = 0;
            averageStepLength = null;
            __asSamples = [];
            averageAscentSpeed = null;
            ActiveLook.Laps.onSessionStart();
        }

        function get(sym as Lang.Symbol) as Lang.Number or Lang.Float or Lang.Boolean or Null {
            if (AugmentedActivityInfo has sym) {
                return AugmentedActivityInfo[sym];
            }
            if (__ai != null && __ai has sym) {
                return __ai[sym];
            }
            if (__rdd != null && __rdd has sym) {
                return __rdd[sym];
            }
            return false;
        }

        function addLap() as Void {
            ActiveLook.Laps.addLap(__ai);
        }

        function accumulate(info as Activity.Info?) as Void {
            if (info == null) {
                return;
            }
            // Three seconds power & Normalized power
            if (info has :currentPower && info.currentPower != null) {
                __pSamples.add(info.currentPower);
                if (__pSamples.size() >= 30) {
                    __pSamples = __pSamples.slice(-30, null);
                    var tmp = 0;
                    for(var i = 0; i < 30; i++) {
                        tmp += __pSamples[i];
                    }
                    __pAccu += Math.pow(tmp / 30.0, 4);
                    __pAccuNb ++;
                }
            }
            // Average ascent speed
            if (info has :totalAscent && info.totalAscent != null) {
                __asSamples.add(info.totalAscent);
                if (__asSamples.size() > 20) {
                    __asSamples = __asSamples.slice(-20, null);
                }
            }
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

        function computeRunningDynamics(runningDynamicsData as AntPlus.RunningDynamicsData?) as Void {
            if (runningDynamicsData == null) {
                return;
            }

            __rdd = runningDynamicsData;

            if (__nbGroundContactTime > 0) {
                averageGroundContactTime = __totalGroundContactTime / __nbGroundContactTime;
            }
            if (__nbVerticalOscillation > 0) {
                averageVerticalOscillation = __totalVerticalOscillation / __nbVerticalOscillation;
            }
            if (__nbStepLength > 0) {
                averageStepLength = __totalStepLength / __nbStepLength;
            }
        }

        function compute(info as Activity.Info?) as Void {
            __ai = info;

            // Chrono
            var tmp = get(:timerTime);
            var tmpValid = tmp != null && tmp != false;
            if (tmpValid) {
                var sec = tmp / 1000;
                var mn = sec / 60;
                chrono = [mn / 60, mn % 60, sec % 60, tmp % 1000];
            } else {
                chrono = null;
            }

            // Current pace
            tmp = get(:currentSpeed);
            tmpValid = tmp != null && tmp != false && tmp > 0.0;
            currentPace = tmpValid ? 1.0 / tmp : null;

            // Fastest pace
            tmp = get(:maxSpeed);
            tmpValid = tmp != null && tmp != false && tmp > 0.0;
            fastestPace = tmpValid ? 1.0 / tmp : null;

            // Average pace
            tmp = get(:averageSpeed);
            tmpValid = tmp != null && tmp != false && tmp > 0.0;
            averagePace = tmpValid ? 1.0 / tmp : null;

            // Three seconds power
            if (__pSamples.size() >= 6) {
                tmp = __pSamples.slice(-6, null);
                threeSecPower = (tmp[0] + tmp[1] + tmp[2] + tmp[3] + tmp[4] + tmp[5]) / 6.0;
            } else {
                threeSecPower = null;
            }
            // Normalized power
            if (__pAccuNb > 0) {
                normalizedPower = Math.pow(__pAccu / __pAccuNb, 0.25);
            } else {
                normalizedPower = null;
            }
            // Workaround : Some devices don't have averagePower & maxPower in Activity.info so we calculated them
            // Max power
            tmp = get(:currentPower);
            tmpValid = tmp != null && tmp != false && tmp > 0.0;
            if(tmpValid){
                 maxPower = maxPower == null ? tmp : tmp > maxPower ? tmp : maxPower;
            }
            // Average power
            if (__ai != null && __ai has :averagePower) {
                tmp = __ai.averagePower;
                tmpValid = tmp != null && tmp != false && tmp > 0.0;
                if(tmpValid){
                    averagePower = tmp;
                }else{
                    tmp = get(:currentPower);
                    tmpValid = tmp != null && tmp != false && tmp > 0.0;
                    if(tmpValid){
                        if(averagePower != null){
                            averagePower = ((averagePower * __pavgAccuNb) + tmp) / (__pavgAccuNb + 1);
                        } else{
                            averagePower = tmp;
                        }
                        __pavgAccuNb+=1;
                    }
                }
            }
        
            // Average ascent speed
            tmpValid = __asSamples.size();
            if (tmpValid > 1) {
                tmp = tmpValid - 1;
                averageAscentSpeed = (__asSamples[tmp] - __asSamples[0]).toFloat() / tmp;
            } else if (tmpValid == 1) {
                averageAscentSpeed = __asSamples[0].toFloat();
            }
        }

    }

    module PageSettings {

        typedef PageSpec as Lang.Array<Lang.Symbol>;
        typedef PagePositions as Lang.Array<Lang.Number>;

        const PAGES as Lang.Array<PageSpec> = [
            [],
            [        :chrono,     :currentSpeed, :elapsedDistance ],
            [   :currentPace, :currentHeartRate, :elapsedDistance ],
            [ :threeSecPower,   :currentCadence,     :totalAscent ],
            [        :chrono,    :threeSecPower,    :averagePower ],
            [        :chrono,  :elapsedDistance,    :averageSpeed ],
            [   :currentPace,      :averagePace ],
            [ :threeSecPower,  :normalizedPower ],
            [   :totalAscent,         :altitude ],
            [   :averagePace, :averageHeartRate,  :averageCadence ],
            [ :threeSecPower,  :normalizedPower,  :currentCadence, :currentHeartRate,   :chrono, :currentSpeed ],
            [        :chrono,  :elapsedDistance,     :currentPace,      :totalAscent, :altitude ],
        ];

        const LAYOUTS as Lang.Array<Lang.Symbol> = [
            :chrono,           :elapsedDistance,   :distanceToDestination,
            :currentHeartRate, :maxHeartRate,      :averageHeartRate,
            :currentPower,     :maxPower,          :averagePower,          :threeSecPower, :normalizedPower,
            :currentSpeed,     :maxSpeed,          :averageSpeed,
            :currentPace,      :fastestPace,       :averagePace,
            :currentCadence,   :maxCadence,        :averageCadence,
            :altitude,         :totalAscent,       :totalDescent,          :averageAscentSpeed,
            :calories,         :energyExpenditure,
            :groundContactTime,                    :averageGroundContactTime,
            :verticalOscillation,                  :averageVerticalOscillation,
            :stepLength,                           :averageStepLength,
            :lapChrono,        :lapElapsedDistance,
            :lapAverageHeartRate, :lapAveragePower,
            :lapAverageSpeed,     :lapAveragePace,
            :lapAverageCadence,
            :lapTotalAscent, :lapTotalDescent, :lapAverageAscentSpeed,
            :lapCalories,
            :lapAverageGroundContactTime, :lapAverageVerticalOscillation, :lapAverageStepLength,
        ];

        const POSITIONS as Lang.Array<PagePositions> = [
            [],
            [ 0x00001E59 ],
            [ 0x00001E77, 0x00001E23 ],
            [ 0x00001E99, 0x00001E59, 0x00001E19 ],
            [ 0x00001E99, 0x00001E59, 0x00019A22, 0x00011E22 ],
            [ 0x00001E99, 0x00019D5F, 0x00011E5F, 0x00019A22, 0x00011E22 ],
            [ 0x00019D9D, 0x00011E9D, 0x00019D5F, 0x00011E5F, 0x00019A22, 0x00011E22 ],
        ];

        function strToPages(spec as Lang.String?, onError as Lang.String?) as Lang.Array<PageSpec> {
            if (spec == null) { spec = ""; }
            var pages = [] as Lang.Array<PageSpec>;
            try {
                while (spec.length() > 0) {
                    if (spec.find("(0)") == 0) {
                        pages.add(PAGES[0]);
                        spec = spec.substring(3, spec.length());
                    } else if (spec.find("(") == 0) {
                        var closing = spec.find(")")
                            as Lang.Number or Null;
                        var pSpec = spec.substring(1, closing) as Lang.String ;
                        var page = [] as PageSpec;
                        while (pSpec.length() > 0) {
                            page.add(LAYOUTS[mapToBounds(pSpec.toNumber(), 1, LAYOUTS.size()) - 1]);
                            var splitPoint = pSpec.find(",")
                                as Lang.Number or Null;
                            pSpec = splitPoint == null ? "" : pSpec.substring(splitPoint + 1, pSpec.length());
                        }
                        pages.add(page);
                        spec = spec.substring(closing + 1, spec.length());
                    } else if (spec.find(",") == 0) {
                        spec = spec.substring(1, spec.length());
                    } else {
                        pages.add(PAGES[mapToBounds(spec.toNumber(), 0, PAGES.size() - 1)]);
                        var nIdx = spec.length();
                        var tIdx = null
                            as Lang.Number or Null;
                        tIdx = spec.find("("); if (tIdx != null && tIdx < nIdx) { nIdx = tIdx; }
                        tIdx = spec.find(","); if (tIdx != null && tIdx < nIdx) { nIdx = tIdx + 1; }
                        spec = spec.substring(nIdx, spec.length());
                    }
                }
            } catch (e) {
                e.printStackTrace();
            }
            if (pages.size() == 0) {
                if (onError == null) {
                    return PAGES;
                }
                return strToPages(onError, null);
            }
            return pages;
        }

    }

    module Layouts {

        typedef GeneratorArguments as {
            :id as Lang.Number,
            :sym as Lang.Symbol,
            :converter as Lang.Float?,
            :toStr as Method(value as Lang.Numeric or Lang.Array<Lang.Numeric> or Null) as Lang.String,
        };

        /*
         * For IDS, 0xAABBCCDD
         *            AA       Full metric
         *              BB     Full imperial
         *                CC   Half metric
         *                  DD Half imperial
         *
         *  Data                            | Symbol                 | U Garmin  | Metric | Statute | python converter: a = ""
         * ---------------------------------|------------------------|-----------|--------|---------|------------------------------------------
         *  Chrono                          | :chrono                |           |        |         | a += "%0.2X%0.2X%0.2X%0.2X\n" % (11, 11, 43, 43)
         *  Heart Rate                      | :currentHeartRate      |     bpm   |       bpm        | a += "%0.2X%0.2X%0.2X%0.2X\n" % (21, 21, 49, 49)
         *  Max HeartRate                   | :maxHeartRate          |     bpm   |       bpm        | a += "%0.2X%0.2X%0.2X%0.2X\n" % (29, 29, 61, 61)
         *  Average Heart Rate              | :averageHeartRate      |     bpm   |       bpm        | a += "%0.2X%0.2X%0.2X%0.2X\n" % (24, 24, 52, 52)
         *  Power                           | :currentPower          |      W    |        W         | a += "%0.2X%0.2X%0.2X%0.2X\n" % (22, 22, 56, 56)
         *  Max Power                       | :maxPower              |      W    |        W         | a += "%0.2X%0.2X%0.2X%0.2X\n" % (30, 30, 62, 62)
         *  Average Power                   | :averagePower          |      W    |        W         | a += "%0.2X%0.2X%0.2X%0.2X\n" % (25, 25, 53, 53)
         *  Power 3s                        | :threeSecPower         |      W    |        W         | a += "%0.2X%0.2X%0.2X%0.2X\n" % (42, 42, 65, 65)
         *  Power Normalized                | :normalizedPower       |      W    |        W         | a += "%0.2X%0.2X%0.2X%0.2X\n" % (69, 69, 70, 70)
         *  Cadence                         | :currentCadence        |     rpm   |       rpm        | a += "%0.2X%0.2X%0.2X%0.2X\n" % (16, 16, 55, 55)
         *  Max Cadence                     | :maxCadence            |     rpm   |       rpm        | a += "%0.2X%0.2X%0.2X%0.2X\n" % (28, 28, 60, 60)
         *  Average Cadence                 | :averageCadence        |     rpm   |       rpm        | a += "%0.2X%0.2X%0.2X%0.2X\n" % (23, 23, 51, 51)
         *  Total Calories                  | :calories              |    kcal   |       kCal       | a += "%0.2X%0.2X%0.2X%0.2X\n" % (17, 17, 54, 54)
         *  Energy Expenditure              | :energyExpenditure     | kcals/min |       Kcal/min   | a += "%0.2X%0.2X%0.2X%0.2X\n" % (27, 27, 58, 58)
         * ---------------------------------|------------------------|-----------|--------|---------|------------------------------------------
         *  Running Data                    | Symbol                 | U Garmin  | Metric | Statute | python converter: a = ""
         * ---------------------------------|------------------------|-----------|--------|---------|------------------------------------------
         *  Ground Contact Time             | :groundContactTime     |      ms   |        ms        | a += "%0.2X%0.2X%0.2X%0.2X\n" % (189, 189, 190, 190)
         *  Average Ground Contact Time     | :averageGroundContactTime |   ms   |        ms        | a += "%0.2X%0.2X%0.2X%0.2X\n" % (189, 189, 190, 190)
         * ---------------------------------|------------------------|-----------|--------|---------|------------------------------------------
         *  Lap Data                        | Symbol                 | U Garmin  | Metric | Statute | python converter: a = ""
         * ---------------------------------|------------------------|-----------|--------|---------|------------------------------------------
         *  Lap Chrono                      | :lapChrono             |           |                  | a += "%0.2X%0.2X%0.2X%0.2X\n" % (11, 11, 43, 43)
         *  Lap Average Heart Rate          | :lapAverageHeartRate   |     bpm   |       bpm        | a += "%0.2X%0.2X%0.2X%0.2X\n" % (24, 24, 52, 52)
         *  Lap Average Power               | :lapAveragePower       |      W    |        W         | a += "%0.2X%0.2X%0.2X%0.2X\n" % (25, 25, 53, 53)
         *  Lap Average Cadence             | :lapAverageCadence     |     rpm   |       rpm        | a += "%0.2X%0.2X%0.2X%0.2X\n" % (23, 23, 51, 51)
         *  Lap Calories                    | :lapCalories           |    kCal   |      kCal        | a += "%0.2X%0.2X%0.2X%0.2X\n" % (17, 17, 54, 54)
         * ---------------------------------|------------------------|-----------|--------|---------|------------------------------------------
         *  Lap Running Data                | Symbol                 | U Garmin  | Metric | Statute | python converter: a = ""
         * ---------------------------------|------------------------|-----------|--------|---------|------------------------------------------
         *  Lap Average Ground Contact Time | :lapAverageGroundContactTime | ms  |        ms        | a += "%0.2X%0.2X%0.2X%0.2X\n" % (189, 189, 190, 190)
         * ---------------------------------|------------------------|-----------|--------|---------|------------------------------------------
         */
        const IDS_NO_CONVERT as Lang.Dictionary<Lang.Symbol, Lang.Number> = {
            :chrono                => 0x0B0B2B2B,
            :currentHeartRate      => 0x15153131,
            :maxHeartRate          => 0x1D1D3D3D,
            :averageHeartRate      => 0x18183434,
            :currentPower          => 0x16163838,
            :maxPower              => 0x1E1E3E3E,
            :averagePower          => 0x19193535,
            :threeSecPower         => 0x2A2A4141,
            :normalizedPower       => 0x45454646,
            :currentCadence        => 0x10103737,
            :maxCadence            => 0x1C1C3C3C,
            :averageCadence        => 0x17173333,
            :calories              => 0x11113636,
            :energyExpenditure     => 0x1B1B3A3A,
            :groundContactTime           => 0xBDBDBEBE,
            :averageGroundContactTime    => 0xBDBDBEBE,
            :lapChrono                   => 0x0B0B2B2B,
            :lapAverageHeartRate         => 0x18183434,
            :lapAveragePower             => 0x19193535,
            :lapAverageCadence           => 0x17173333,
            :lapCalories                 => 0x11113636,
            :lapAverageGroundContactTime => 0xBDBDBEBE,
        };

        /*
         * For IDS, 0xAABBCCDD
         *            AA       Full metric
         *              BB     Full imperial
         *                CC   Half metric
         *                  DD Half imperial
         *
         *  Data                            | Symbol                 | U Garmin  | Metric | Statute | python converter: a = ""
         * ---------------------------------|------------------------|-----------|--------|---------|------------------------------------------
         *  Running Cadence                 | :currentCadence        |   spm     |       spm        | a += "%0.2X%0.2X%0.2X%0.2X\n" % (129, 129, 132, 132)
         *  Max Running Cadence             | :maxCadence            |   spm     |       spm        | a += "%0.2X%0.2X%0.2X%0.2X\n" % (130, 130, 133, 133)
         *  Average Running Cadence         | :averageCadence        |   spm     |       spm        | a += "%0.2X%0.2X%0.2X%0.2X\n" % (131, 131, 134, 134)
         * ---------------------------------|------------------------|-----------|--------|---------|------------------------------------------
         *  Lap Data                        | Symbol                 | U Garmin  | Metric | Statute | python converter: a = ""
         * ---------------------------------|------------------------|-----------|--------|---------|------------------------------------------
         *  Lap Average Running Cadence     | :lapAverageCadence     |     spm   |       spm        | a += "%0.2X%0.2X%0.2X%0.2X\n" % (131, 131, 134, 134)
         * ---------------------------------|------------------------|-----------|--------|---------|------------------------------------------
         */
        const IDS_NO_CONVERT_RUNNING_OVERRIDE as Lang.Dictionary<Lang.Symbol, Lang.Number> = {
            :currentCadence           => 0x81818484,
            :maxCadence               => 0x82828585,
            :averageCadence           => 0x83838686,
            :lapAverageCadence        => 0x83838686,
        };

        /*
         *  Data                            | Symbol                 | U Garmin  | Metric | Statute | python converter: a = ""
         * ---------------------------------|------------------------|-----------|--------|---------|-----------------------------------------------------
         *  Distance                        | :elapsedDistance       |      m    |   km   |   mi    | a += "%0.2X%0.2X%0.2X%0.2X\n" % ( 12,  35,  46,  46)
         *  Distance To Destination         | :distanceToDestination |      m    |   km   |   mi    | a += "%0.2X%0.2X%0.2X%0.2X\n" % (101, 102, 103, 103)
         *  Speed                           | :currentSpeed          |     mps   |  km/h  |   mi/h  | a += "%0.2X%0.2X%0.2X%0.2X\n" % ( 13,  33,  44,  44)
         *  Max Speed                       | :maxSpeed              |     mps   |  km/h  |   mi/h  | a += "%0.2X%0.2X%0.2X%0.2X\n" % ( 31,  41,  63,  63)
         *  Average Speed                   | :averageSpeed          |     mps   |  km/h  |   mi/h  | a += "%0.2X%0.2X%0.2X%0.2X\n" % ( 14,  34,  45,  45)
         *  Pace                            | :currentPace           | sec/meter | sec/km |  sec/mi | a += "%0.2X%0.2X%0.2X%0.2X\n" % ( 15,  37,  48,  48)
         *  Fastest Pace                    | :fastestPace           | sec/meter | sec/km |  sec/mi | a += "%0.2X%0.2X%0.2X%0.2X\n" % (104, 105, 106, 106)
         *  Average Pace                    | :averagePace           | sec/meter | sec/km |  sec/mi | a += "%0.2X%0.2X%0.2X%0.2X\n" % ( 66,  67,  68,  68)
         *  Altitude                        | :altitude              |      m    |   m    |   ft    | a += "%0.2X%0.2X%0.2X%0.2X\n" % ( 18,  38,  50,  50)
         *  Total Ascent                    | :totalAscent           |      m    |   m    |   ft    | a += "%0.2X%0.2X%0.2X%0.2X\n" % ( 19,  36,  47,  47)
         *  Total Descent                   | :totalDescent          |      m    |   m    |   ft    | a += "%0.2X%0.2X%0.2X%0.2X\n" % ( 26,  39,  57,  57)
         *  Average  Ascent Speed           | :averageAscentSpeed    |     m/s   |  m/h   |   ft/h  | a += "%0.2X%0.2X%0.2X%0.2X\n" % ( 20,  40,  59,  59)
         * ---------------------------------|------------------------|-----------|--------|---------|------------------------------------------
         *  Running Data                    | Symbol                 | U Garmin  | Metric | Statute | python converter: a = ""
         * ---------------------------------|------------------------|-----------|--------|---------|------------------------------------------
         *  Vertical Oscillation            | :verticalOscillation   |      mm   |   cm   |   in    | a += "%0.2X%0.2X%0.2X%0.2X\n" % (200, 201, 202, 202)
         *  Average Vertical Oscillation    | :averageVerticalOscillation | mm   |   cm   |   in    | a += "%0.2X%0.2X%0.2X%0.2X\n" % (200, 201, 202, 202)
         *  Step Length                     | :stepLength            |      mm   |   m    |   ft    | a += "%0.2X%0.2X%0.2X%0.2X\n" % (194, 195, 196, 196)
         *  Average Step Length             | :averageStepLength     |      mm   |   m    |   ft    | a += "%0.2X%0.2X%0.2X%0.2X\n" % (194, 195, 196, 196)
         * ---------------------------------|------------------------|-----------|--------|---------|------------------------------------------
         *  Lap Data                        | Symbol                 | U Garmin  | Metric | Statute | python converter: a = ""
         * ---------------------------------|------------------------|-----------|--------|---------|------------------------------------------
         *  Lap Elapsed Distance            | :lapElapsedDistance    |      m    |   km   |   mi    | a += "%0.2X%0.2X%0.2X%0.2X\n" % ( 12,  35,  46,  46)
         *  Lap Average Speed               | :lapAverageSpeed       |     mps   |  km/h  |   mi/h  | a += "%0.2X%0.2X%0.2X%0.2X\n" % ( 14,  34,  45,  45)
         *  Lap Average Pace                | :lapAveragePace        | sec/meter | sec/km |  sec/mi | a += "%0.2X%0.2X%0.2X%0.2X\n" % ( 66,  67,  68,  68)
         *  Lap Total Ascent                | :lapTotalAscent        |      m    |   m    |   ft    | a += "%0.2X%0.2X%0.2X%0.2X\n" % ( 19,  36,  47,  47)
         *  Lap Total Descent               | :lapTotalDescent       |      m    |   m    |   ft    | a += "%0.2X%0.2X%0.2X%0.2X\n" % ( 26,  39,  57,  57)
         *  Lap Average Ascent Speed        | :lapAverageAscentSpeed |     m/s   |  m/h   |   ft/h  | a += "%0.2X%0.2X%0.2X%0.2X\n" % ( 20,  40,  59,  59)
         * ---------------------------------|------------------------|-----------|--------|---------|------------------------------------------
         *  Lap Running Data                | Symbol                 | U Garmin  | Metric | Statute | python converter: a = ""
         * ---------------------------------|------------------------|-----------|--------|---------|------------------------------------------
         *  Lap Average Vertical Oscillation | :lapAverageVerticalOscillation | mm |  cm  |   in    | a += "%0.2X%0.2X%0.2X%0.2X\n" % (200, 201, 202, 202)
         *  Lap Average Step Length         | :lapAverageStepLength  |      mm   |   m    |   ft    | a += "%0.2X%0.2X%0.2X%0.2X\n" % (194, 195, 196, 196)
         */
        const IDS_CONVERT as Lang.Dictionary<Lang.Symbol, { :id as Lang.Number, :statuteSwitch as Lang.Symbol, :toMetric as Lang.Float?, :toStatute as Lang.Float? }> = {
            :elapsedDistance       => { :id => 0x0C232E2E, :statuteSwitch => :distanceUnits,  :toMetric => 0.001,  :toStatute => 0.000621371 },
            :distanceToDestination => { :id => 0x65666767, :statuteSwitch => :distanceUnits,  :toMetric => 0.001,  :toStatute => 0.000621371 },
            :currentSpeed          => { :id => 0x0D212C2C, :statuteSwitch => :paceUnits,      :toMetric => 3.6,    :toStatute => 2.236936    },
            :maxSpeed              => { :id => 0x1F293F3F, :statuteSwitch => :paceUnits,      :toMetric => 3.6,    :toStatute => 2.236936    },
            :averageSpeed          => { :id => 0x0E222D2D, :statuteSwitch => :paceUnits,      :toMetric => 3.6,    :toStatute => 2.236936    },
            :currentPace           => { :id => 0x0F253030, :statuteSwitch => :paceUnits,      :toMetric => 1000.0, :toStatute => 1609.344    },
            :fastestPace           => { :id => 0x68696A6A, :statuteSwitch => :paceUnits,      :toMetric => 1000.0, :toStatute => 1609.344    },
            :averagePace           => { :id => 0x42434444, :statuteSwitch => :paceUnits,      :toMetric => 1000.0, :toStatute => 1609.344    },
            :altitude              => { :id => 0x12263232, :statuteSwitch => :heightUnits,                         :toStatute => 3.28084     },
            :totalAscent           => { :id => 0x13242F2F, :statuteSwitch => :elevationUnits,                      :toStatute => 3.28084     },
            :totalDescent          => { :id => 0x1A273939, :statuteSwitch => :elevationUnits,                      :toStatute => 3.28084     },
            :averageAscentSpeed    => { :id => 0x14283B3B, :statuteSwitch => :paceUnits,      :toMetric => 3600.0, :toStatute => 11811.024   },
            :verticalOscillation        => { :id => 0xC8C9CACA, :statuteSwitch => :heightUnits, :toMetric => 0.1,   :toStatute => 0.0393701  },
            :averageVerticalOscillation => { :id => 0xC8C9CACA, :statuteSwitch => :heightUnits, :toMetric => 0.1,   :toStatute => 0.0393701  },
            :stepLength                 => { :id => 0xC2C3C4C4, :statuteSwitch => :heightUnits, :toMetric => 0.001, :toStatute => 0.00328084 },
            :averageStepLength          => { :id => 0xC2C3C4C4, :statuteSwitch => :heightUnits, :toMetric => 0.001, :toStatute => 0.00328084 }, 
            :lapElapsedDistance    => { :id => 0x0C232E2E, :statuteSwitch => :distanceUnits,  :toMetric => 0.001,  :toStatute => 0.000621371 },
            :lapAverageSpeed       => { :id => 0x0E222D2D, :statuteSwitch => :paceUnits,      :toMetric => 3.6,    :toStatute => 2.236936    },
            :lapAveragePace        => { :id => 0x42434444, :statuteSwitch => :paceUnits,      :toMetric => 1000.0, :toStatute => 1609.344    },
            :lapTotalAscent        => { :id => 0x13242F2F, :statuteSwitch => :elevationUnits,                      :toStatute => 3.28084     },
            :lapTotalDescent       => { :id => 0x1A273939, :statuteSwitch => :elevationUnits,                      :toStatute => 3.28084     },
            :lapAverageAscentSpeed => { :id => 0x14283B3B, :statuteSwitch => :paceUnits,      :toMetric => 3600.0, :toStatute => 11811.024   },
            :lapAverageVerticalOscillation => { :id => 0xC8C9CACA, :statuteSwitch => :heightUnits, :toMetric => 0.1,   :toStatute => 0.0393701  },
            :lapAverageStepLength          => { :id => 0xC2C3C4C4, :statuteSwitch => :heightUnits, :toMetric => 0.001, :toStatute => 0.00328084 },
        };

        const CUSTOM_TO_STR as Lang.Dictionary<Lang.Symbol, {
            :full as Method(value as Lang.Numeric or Lang.Array<Lang.Numeric> or Null) as Lang.String,
            :half as Method(value as Lang.Numeric or Lang.Array<Lang.Numeric> or Null) as Lang.String
        }> = {
            :chrono      			=> { :full => :toFullChronoStr, :half => :toHalfChronoStr },
            :currentPace 			=> { :full => :currentPaceFullFormat,  :half => :currentPaceHalfFormat  },
            :fastestPace			=> { :full => :paceFullFormat,  :half => :paceHalfFormat  },
            :averagePace 			=> { :full => :paceFullFormat,  :half => :paceHalfFormat  },
            :lapChrono      		=> { :full => :toFullChronoStr, :half => :toHalfChronoStr },
            :lapAveragePace 		=> { :full => :paceFullFormat,  :half => :paceHalfFormat  },
            :averagePower 		    => { :full => :averagePowerFullFormat,  :half => :averagePowerHalfFormat  },
            :lapAveragePower 		=> { :full => :averagePowerFullFormat,  :half => :averagePowerHalfFormat  },
            :normalizedPower 		=> { :full => :averagePowerFullFormat,  :half => :averagePowerHalfFormat  },
            :threeSecPower 		    => { :full => :averagePowerFullFormat,  :half => :averagePowerHalfFormat  },
        };

        function toFullChronoStr(value as Lang.Array<Lang.Number> or Null) as Lang.String {
            if (value == null) {
                return "--:--:--";
            }
            return Lang.format("$1$:$2$:$3$", [ value[0].format("%02d"), value[1].format("%02d"), value[2].format("%02d") ]);
        }

        function toHalfChronoStr(value as Lang.Array<Lang.Number> or Null) as Lang.String {
            if (value == null) {
                return "--:--";
            }
            if(value[0] >= 1) {
                return Lang.format("$1$:$2$", [ value[0].format("%02d"), value[1].format("%02d") ]);
            }
            return Lang.format("$1$:$2$", [ value[1].format("%02d"), value[2].format("%02d") ]);
        }
		function currentPaceFullFormat(value as Lang.Number or Lang.Float or Null) as Lang.String {
            if (value != null) {
	            value = Math.round(value).toLong() > 300 ? round5(Math.round(value).toLong()) : Math.round(value).toLong();
            }
            return paceFullFormat(value);
        }
		function currentPaceHalfFormat(value as Lang.Number or Lang.Float or Null) as Lang.String {
            if (value != null) {
	            value = Math.round(value).toLong() > 300 ? round5(Math.round(value).toLong()) : Math.round(value).toLong();
            }
            return paceHalfFormat(value);
        }

        function paceFullFormat(value as Lang.Number or Lang.Float or Null) as Lang.String {
            if (value == null) {
                 if(ActiveLookSDK.cfgVersion >= 10){
                    return "$--:--";
                }else{
                    return "--:--";
                }
            }
            value = Math.round(value).toLong();
            return Lang.format("$1$:$2$", [ (value / 60).format("%02d"), (value % 60).format("%02d") ]);
        }
        function paceHalfFormat(value as Lang.Number or Lang.Float or Null) as Lang.String {
	        if(ActiveLookSDK.cfgVersion >= 10){
				return paceFullFormat(value);
	        }
            if (value == null) {
                return "-:--";
            }
            value = Math.round(value).toLong();
            if(value < 600) {
                return Lang.format("$1$:$2$", [ (value / 60).format("%1d"), (value % 60).format("%02d") ]);
            } else {
                return Lang.format("$1$:$2$", [ (value / 60).format("%02d"), ((value % 60) / 6).format("%1d") ]);
            }
        }
        
        function averagePowerFullFormat(value as Lang.Number or Lang.Float or Null) as Lang.String {
            if (value == null) {
                return toFullStr("-");
            }
            return toFullStr(Math.round(value).format("%.0f"));
        }
        
        function averagePowerHalfFormat(value as Lang.Number or Lang.Float or Null) as Lang.String {
            if (value == null) {
                return toHalfStr("-");
            }
            return toHalfStr(Math.round(value).format("%.0f"));
        }

        function toSizedStringDeprecated(value as Lang.Number or Lang.Float or Null, size as Lang.Number) as Lang.String {
            var tmp = "-";
            if (value != null) {
                tmp = value.toString();
                var sep = tmp.find(".");
                if (sep != null) {
                    if (sep >= size) {
                        return value.format("%.0f");
                    } else {
                        return value.format(Lang.format("%.$1$f", [size - sep]));
                    }
                }
            }
            size += 1;
            if (tmp.length() >= size) {
                return tmp;
            }
            tmp = Lang.format("    $1$", [tmp]);
            return tmp.substring(tmp.length() - size, tmp.length());
        }


        function toSizedString(value as Lang.Number or Lang.Float or Null, size as Lang.Number, textAlignRight as Lang.Boolean) as Lang.String {
            var tmp = "-";
            var sep = null;

            if (value != null) {
                tmp = value.toString();
                sep = tmp.find(".");
                if (sep != null) {
		            if(sep == 1) {
		                tmp = value.format("%.2f");
		            }else if(sep == 2){
						tmp = value.format("%.1f");
		            }else{
		            	tmp = value.format("%.0f");
		            }
                }
            }
            size += 1;
            if (tmp.length() >= size) {
                return tmp;
            }

            if(textAlignRight){
                sep = tmp.find(".");
	            if(sep != null){
					if(sep == 1 || sep == 2) {
		                tmp = "$" + tmp;
		            }
	            }
            	tmp = "$$$&"+ tmp;
            	tmp = tmp.substring(tmp.length() - size, tmp.length());
            }else{
            	if(sep != null){
					if(sep == 1){
						tmp = tmp + "$$";
					}else if(sep == 2){
						tmp = tmp + "$";
					}
            	}else{
            		tmp = tmp + "&$$$";
            	}
            	tmp = tmp.substring(0, size);
            }
      		return tmp;
        }

        function toFullStr(value as Lang.Number or Lang.Float or Null) as Lang.String {
			if(ActiveLookSDK.cfgVersion >= 10){
				return toSizedString(value, 4, true);
			}
            return toSizedStringDeprecated(value, 4);
        }

        function toHalfStr(value as Lang.Number or Lang.Float or Null) as Lang.String {
			if(ActiveLookSDK.cfgVersion >= 10){
				return toSizedString(value, 4, false);
			}
            return toSizedStringDeprecated(value, 3);
        }

        function get(args as GeneratorArguments) as Lang.ByteArray {
            var tmp = ActiveLook.Laps has args[:sym] ? ActiveLook.Laps[args[:sym]] : AugmentedActivityInfo.get(args[:sym]);
            if (tmp != null && tmp != false) {
                if (args.hasKey(:converter)) {
                    tmp = tmp * args[:converter];
                }
            } else {
                tmp = null;
            }
            tmp = args[:toStr].invoke(tmp);
            tmp = StringUtil.convertEncodedString(tmp, {
                :fromRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
                :toRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
                :encoding => StringUtil.CHAR_ENCODING_UTF8
			});
            if (tmp.size() > 0 && tmp[0] == 0x20) {
                var i = 1;
                while (i < tmp.size() && tmp[i] == 0x20) { // replace all space by mu, keep first space.
                    tmp[i] = 0xE6; // mu => 230 => E6
                    i ++;
                }
            }
            tmp.add(0x00);
            return tmp;
        }

        function pageToGenerator(page as PageSettings.PageSpec) as Lang.Array<GeneratorArguments> {
            var result = [];
            var devSettings = System.getDeviceSettings();
            var nb = page.size();
            if (nb >= PageSettings.POSITIONS.size()) {
                nb = PageSettings.POSITIONS.size() - 1;
            }
            var positions = PageSettings.POSITIONS[nb];
            while (nb > 0) {
                nb -= 1;
                var newElem = {
                    :id => 0x00000000,
                    :sym => page[nb],
                }
                    as GeneratorArguments;
                var pos = positions[nb];
                var mode = (pos & 0x00010000) >> 12; // (pos & 0x00FF0000 != 0) ? 16 : 0;
                if (IDS_NO_CONVERT.hasKey(newElem[:sym])) {
                    newElem[:id] = IDS_NO_CONVERT[newElem[:sym]];
                    if (Toybox.Activity has :getProfileInfo) {
                        if ( Toybox.Activity.getProfileInfo().sport == Toybox.Activity.SPORT_RUNNING) {
                            if (IDS_NO_CONVERT_RUNNING_OVERRIDE.hasKey(newElem[:sym])) {
                                newElem[:id] = IDS_NO_CONVERT_RUNNING_OVERRIDE[newElem[:sym]];
                            }
                        }
                    }
                } else {
                    var spec = IDS_CONVERT[newElem[:sym]]
                        as { :id as Lang.Number, :statuteSwitch as Lang.Symbol, :toMetric as Lang.Float, :toStatute as Lang.Float };
                    newElem[:id] = spec[:id];
                    if (devSettings[spec[:statuteSwitch]] == System.UNIT_STATUTE) {
                        mode += 8;
                        if (spec.hasKey(:toStatute)) {
                            newElem.put(:converter, spec[:toStatute]);
                        }
                    } else if (spec.hasKey(:toMetric)) {
                        newElem.put(:converter, spec[:toMetric]);
                    }
                }
                newElem[:id] = ((newElem[:id] << mode) & 0xFF000000) | (pos & 0x0000FFFF);
                //System.println("layout id = " + ((newElem[:id] >> 24) &  0x000000FF).toString());
                //System.println("layout id = " + newElem[:id].format("%04X"));
                if (CUSTOM_TO_STR.hasKey(newElem[:sym])) {
                    newElem.put(:toStr, new Lang.Method(Layouts, CUSTOM_TO_STR[newElem[:sym]][mode < 16 ? :full : :half]));
                } else {
                    newElem.put(:toStr, new Lang.Method(Layouts, mode < 16 ? :toFullStr : :toHalfStr));
                }
                result.add(newElem);
            }
            return result.reverse();
        }

        function round5(value as Lang.Number or Lang.Float) as Lang.Number or Lang.Float{
            return (value % 5 ) >= 2.5 ? (value/5) * 5 + 5 : (value/5)*5;
        }

    }

}
