# Change log

## 1.0.44

### New Feature

* Add FlushCmdStacking if ByteArray > 200b and before Swipes

### Change

* Rename cmdStacking variable
  
### New Device
* Add fr165 & fr 165m

## 1.0.43

### Change

* To fix Enduro 2 Garmin [issue](https://forums.garmin.com/developer/connect-iq/i/bug-reports/enduro-2-was-not-exported) add line below in this file :

`${HOME}/Library/Application Support/Garmin/ConnectIQ/Devices/fenix7x/compiler.json`
```JSON
partNumbers: [
        ...
        {
            "connectIQVersion": "5.0.0",
            "firmwareVersion": 1723,
            "languages":
            [
            ...
            ],
            "number": "006-B4341-00"
        }
    ]
```

## 1.0.42

### New Feature

* Add Hold & Flush cmd
  
### Improvement

* Improve BLE cmd stacking

### Change

* Add Hold & Flush cmd before displaying data layouts
  
## 1.0.41

### Changes

* Add Edge 1050 compatibility
  
## 1.0.40

### Changes

* Change __heart_count init value at 0 as Garmin advice
* Add Write_With_Response on updateLayoutValue

## 1.0.39

### Changes

* Three seconds power is now calculated with 6 values
* Round 3s, average, lapAverage & normalized power before displaying it
