using Toybox.BluetoothLowEnergy;
using Toybox.Lang;
using Toybox.System;

//! This module provide all the functionalities to handle
//! the ActiveLook SmartGlasses as Bluetooth Low Energy objects.
module ActiveLookBLE {

    //! The BLE Delegate class for ActiveLook. It relies on a single instance which is
    //! build with the <code>setUp</code> static class methods.
    class ActiveLook extends Toybox.BluetoothLowEnergy.BleDelegate {

        //! Private logger enabled in debug and disabled in release mode
        //! Comment and uncomment as needed.
        (:release) private static function _log(msg as Toybox.Lang.String, data as Toybox.Lang.Object or Null) as Void {}
        (:debug)   private static function _log(msg as Toybox.Lang.String, data as Toybox.Lang.Object or Null) as Void {
            // if ($ has :log) { $.log(Toybox.Lang.format("[ActiveLookBLE::ActiveLook] $1$", [msg]), data); }
        }

        //! Interface for delegate
        typedef ActiveLookDelegate as interface {
            function onCharacteristicChanged(characteristic as Toybox.BluetoothLowEnergy.Characteristic, value as Toybox.Lang.ByteArray) as Void;
            function onCharacteristicRead(characteristic as Toybox.BluetoothLowEnergy.Characteristic, status as Toybox.BluetoothLowEnergy.Status, value as Toybox.Lang.ByteArray) as Void;
            function onCharacteristicWrite(characteristic as Toybox.BluetoothLowEnergy.Characteristic, status as Toybox.BluetoothLowEnergy.Status) as Void;
            function onConnectedStateChanged(device as Toybox.BluetoothLowEnergy.Device, state as Toybox.BluetoothLowEnergy.ConnectionState) as Void;
            function onDescriptorRead(descriptor as Toybox.BluetoothLowEnergy.Descriptor, status as Toybox.BluetoothLowEnergy.Status, value as Toybox.Lang.ByteArray) as Void;
            function onDescriptorWrite(descriptor as Toybox.BluetoothLowEnergy.Descriptor, status as Toybox.BluetoothLowEnergy.Status) as Void;
            function onScanResult(scanResult as Toybox.BluetoothLowEnergy.ScanResult) as Void;
            function onScanStateChange(scanState as Toybox.BluetoothLowEnergy.ScanState, status as Toybox.BluetoothLowEnergy.Status) as Void;
            function onBleError(exception as Toybox.Lang.Exception) as Void;
        };

        //! Type for registering profile
        typedef BleProfile as {
            :uuid as Toybox.BluetoothLowEnergy.Uuid,
            :characteristics as Toybox.Lang.Array<{
                :uuid as Toybox.BluetoothLowEnergy.Uuid,
                :descriptors as Toybox.Lang.Array<Toybox.BluetoothLowEnergy.Uuid>
            }>,
        };

        //! Custom Service (ActiveLook® Commands Interface)
        private static const BLE_SERV_ACTIVELOOK               as Toybox.BluetoothLowEnergy.Uuid = Toybox.BluetoothLowEnergy.longToUuid(0x0783B03E8535B5A0l, 0x7140A304D2495CB7l);
        //! Custom Service (ActiveLook® Commands Interface) Characteristics
        private static const BLE_CHAR_ACTIVELOOK_TX            as Toybox.BluetoothLowEnergy.Uuid = Toybox.BluetoothLowEnergy.longToUuid(0x0783B03E8535B5A0l, 0x7140A304D2495CB8l);
        private static const BLE_CHAR_ACTIVELOOK_RX            as Toybox.BluetoothLowEnergy.Uuid = Toybox.BluetoothLowEnergy.longToUuid(0x0783B03E8535B5A0l, 0x7140A304D2495CBAl);
        private static const BLE_CHAR_ACTIVELOOK_FLOW_CONTROL  as Toybox.BluetoothLowEnergy.Uuid = Toybox.BluetoothLowEnergy.longToUuid(0x0783B03E8535B5A0l, 0x7140A304D2495CB9l);
        private static const BLE_CHAR_ACTIVELOOK_GESTURE_EVENT as Toybox.BluetoothLowEnergy.Uuid = Toybox.BluetoothLowEnergy.longToUuid(0x0783B03E8535B5A0l, 0x7140A304D2495CBBl);
        private static const BLE_CHAR_ACTIVELOOK_TOUCH_EVENT   as Toybox.BluetoothLowEnergy.Uuid = Toybox.BluetoothLowEnergy.longToUuid(0x0783B03E8535B5A0l, 0x7140A304D2495CBCl);

        //! Device Information Service
        private static const BLE_SERV_DEVICE_INFORMATION       as Toybox.BluetoothLowEnergy.Uuid = Toybox.BluetoothLowEnergy.longToUuid(0x0000180A00001000l, 0x800000805F9B34FBl);
        //! Device Information Service Characteristics
        private static const BLE_CHAR_MANUFACTURER_NAME        as Toybox.BluetoothLowEnergy.Uuid = Toybox.BluetoothLowEnergy.longToUuid(0x00002A2900001000l, 0x800000805F9B34FBl);
        private static const BLE_CHAR_MODEL_NUMBER             as Toybox.BluetoothLowEnergy.Uuid = Toybox.BluetoothLowEnergy.longToUuid(0x00002A2400001000l, 0x800000805F9B34FBl);
        private static const BLE_CHAR_SERIAL_NUMBER            as Toybox.BluetoothLowEnergy.Uuid = Toybox.BluetoothLowEnergy.longToUuid(0x00002A2500001000l, 0x800000805F9B34FBl);
        private static const BLE_CHAR_HARDWARE_VERSION         as Toybox.BluetoothLowEnergy.Uuid = Toybox.BluetoothLowEnergy.longToUuid(0x00002A2700001000l, 0x800000805F9B34FBl);
        private static const BLE_CHAR_FIRMWARE_VERSION         as Toybox.BluetoothLowEnergy.Uuid = Toybox.BluetoothLowEnergy.longToUuid(0x00002A2600001000l, 0x800000805F9B34FBl);
        private static const BLE_CHAR_SOFTWARE_VERSION         as Toybox.BluetoothLowEnergy.Uuid = Toybox.BluetoothLowEnergy.longToUuid(0x00002A2800001000l, 0x800000805F9B34FBl);

        //! Battery Service
        private static const BLE_SERV_BATTERY                  as Toybox.BluetoothLowEnergy.Uuid = Toybox.BluetoothLowEnergy.longToUuid(0x0000180F00001000l, 0x800000805F9B34FBl);
        //! Battery Service Characteristics
        private static const BLE_CHAR_BATTERY_LEVEL            as Toybox.BluetoothLowEnergy.Uuid = Toybox.BluetoothLowEnergy.longToUuid(0x00002A1900001000l, 0x800000805F9B34FBl);

        //! Private instance variable
        private var _delegate as ActiveLookBLE.ActiveLook.ActiveLookDelegate;

        //! Private constructor to make it impossible to instantiate this class without calling setUp.
        //!
        //! @param delegate The object that will be responsible for handling events.
        private function initialize(delegate as ActiveLookBLE.ActiveLook.ActiveLookDelegate) {
            Toybox.BluetoothLowEnergy.BleDelegate.initialize();
            _log("initialize", []);
            _delegate = delegate;
            Toybox.BluetoothLowEnergy.setDelegate(self);
        }

        //! Private static BLE shared state.
        private static var _activeLook                        as ActiveLookBLE.ActiveLook
                                                              or Null
                                                              = null;
        private static var _registeredProfile                 as Toybox.Lang.Array<Toybox.BluetoothLowEnergy.Uuid>
                                                              = [] as Toybox.Lang.Array<Toybox.BluetoothLowEnergy.Uuid>;
        private static var _currentScanState                  as Toybox.BluetoothLowEnergy.ScanState
                                                              = Toybox.BluetoothLowEnergy.SCAN_STATE_OFF;
        private static var _desiredScanState                  as Toybox.BluetoothLowEnergy.ScanState
                                                              = Toybox.BluetoothLowEnergy.SCAN_STATE_OFF;
        private static var _fixScanStateNbSwitch              as Toybox.Lang.Number
                                                              = 0;
        private static var _autoDevice                        as Toybox.BluetoothLowEnergy.Device
                                                              or Null
                                                              = null;
        private static var _device                            as Toybox.BluetoothLowEnergy.Device
                                                              or Null
                                                              = null;

        //! Static setUp function that must be called at least once for registering the 3 necessary profiles
        //! for playing withthe ActiveLook Smart Glasses. It will register those profiles only once.
        //! All subsequent calls will replace the delegate in the class single instance.
        //!
        //! @param delegate The object that will be responsible for handling events.
        //!
        //! @return         The Active Look object to use for handling Bluetooth operations.
        static function setUp(delegate as ActiveLookBLE.ActiveLook.ActiveLookDelegate) as ActiveLookBLE.ActiveLook {
            _log("setUp", [_activeLook, delegate]);
            var skipRegister = _activeLook != null ? true : false;
            _activeLook = new ActiveLook(delegate);
            if (skipRegister) { return _activeLook as ActiveLookBLE.ActiveLook; }
            // Profile 1
            var profileActiveLook = ({
                :uuid => BLE_SERV_ACTIVELOOK,
                :characteristics => [
                    { :uuid => BLE_CHAR_ACTIVELOOK_RX },
                    { :uuid => BLE_CHAR_ACTIVELOOK_TX, :descriptors => [Toybox.BluetoothLowEnergy.cccdUuid()] },
                    { :uuid => BLE_CHAR_ACTIVELOOK_GESTURE_EVENT, :descriptors => [Toybox.BluetoothLowEnergy.cccdUuid()] },
                ]
            }) as ActiveLookBLE.ActiveLook.BleProfile;
            Toybox.BluetoothLowEnergy.registerProfile(profileActiveLook);
            // Profile 2
            var profileDeviceInfo = ({
                :uuid => BLE_SERV_DEVICE_INFORMATION,
                :characteristics => [
                    { :uuid => BLE_CHAR_MANUFACTURER_NAME },
                    { :uuid => BLE_CHAR_MODEL_NUMBER },
                    { :uuid => BLE_CHAR_SERIAL_NUMBER },
                    { :uuid => BLE_CHAR_HARDWARE_VERSION },
                    { :uuid => BLE_CHAR_FIRMWARE_VERSION },
                    { :uuid => BLE_CHAR_SOFTWARE_VERSION },
                ]
            }) as ActiveLookBLE.ActiveLook.BleProfile;
            Toybox.BluetoothLowEnergy.registerProfile(profileDeviceInfo);
            // Profile 3
            var profileBattery = ({
                :uuid => BLE_SERV_BATTERY,
                :characteristics => [
                    { :uuid => BLE_CHAR_BATTERY_LEVEL, :descriptors => [Toybox.BluetoothLowEnergy.cccdUuid()] },
                ]
            }) as ActiveLookBLE.ActiveLook.BleProfile;
            Toybox.BluetoothLowEnergy.registerProfile(profileBattery);
            // No more profile as specified here:
            // https://developer.garmin.com/connect-iq/api-docs/Toybox/BluetoothLowEnergy.html#registerProfile-instance_function
            // And it is a developer error to break this limit:
            // https://developer.garmin.com/connect-iq/api-docs/Toybox/BluetoothLowEnergy/ProfileRegistrationException.html
            // But you can try to register more profiles...
            // > Registration can fail if too many profiles are registered, the current limit is 3.
            return _activeLook as ActiveLookBLE.ActiveLook;
        }

        //! Request to enter in the desired scan state.
        //! Depending on the current state, it will either switch current scan state
        //! or keep current state.
        //!
        //! @param state The requested scan state. It can be
        //!              <code>false</code> to disable scanning or
        //!              <code>true</code> to enable scanning.
        (:typecheck(false))
        static function requestScanning(state as Toybox.Lang.Boolean) as Void {
            _log("requestScanning", [state]);
            if   (state == false) { _desiredScanState = Toybox.BluetoothLowEnergy.SCAN_STATE_OFF; }
            else                  { _desiredScanState = Toybox.BluetoothLowEnergy.SCAN_STATE_SCANNING; }
            _fixScanStateNbSwitch = 0;
            if (_currentScanState == _desiredScanState) {
                if (_activeLook != null) {
                    // TODO: Improve typing because I want my custom status
                    _activeLook.onScanStateChange(_currentScanState, -1 as Toybox.BluetoothLowEnergy.Status);
                }
            } else {
                Toybox.BluetoothLowEnergy.setScanState(_desiredScanState);
            }
        }

        //! Try to fix the scan state if it was in error.
        //! For example, if the scan state has been set to
        //! Toybox.BluetoothLowEnergy.SCAN_STATE_SCANNING
        //! but the profiles have not been properly registered,
        //! it will try to switch to Toybox.BluetoothLowEnergy.SCAN_STATE_OFF
        //! and a second call will switch back to Toybox.BluetoothLowEnergy.SCAN_STATE_SCANNING
        //!
        //! You should call this function periodically if you didn't get a success in onScanStateChange.
        //! Call it periodically with some interval to let the bluetooth work properly.
        //!
        //! @return True if we tried to fix an error and false if there was no error to fix.
        static function fixScanState() as Toybox.Lang.Boolean {
            _log("fixScanState", [_fixScanStateNbSwitch, _currentScanState, _desiredScanState]);
            if (_fixScanStateNbSwitch > 0) {
                if (_currentScanState == Toybox.BluetoothLowEnergy.SCAN_STATE_SCANNING) {
                    Toybox.BluetoothLowEnergy.setScanState(Toybox.BluetoothLowEnergy.SCAN_STATE_OFF);
                } else {
                    Toybox.BluetoothLowEnergy.setScanState(Toybox.BluetoothLowEnergy.SCAN_STATE_SCANNING);
                }
                return true;
            }
            return false;
        }

        //! Override Toybox.BluetoothLowEnergy.BleDelegate.onCharacteristicChanged
        function onCharacteristicChanged(characteristic as Toybox.BluetoothLowEnergy.Characteristic, value as Toybox.Lang.ByteArray) as Void {
            _log("onCharacteristicChanged", [characteristic, value]);
            _delegate.onCharacteristicChanged(characteristic, value);
        }

        //! Override Toybox.BluetoothLowEnergy.BleDelegate.onCharacteristicRead
        function onCharacteristicRead(characteristic as Toybox.BluetoothLowEnergy.Characteristic, status as Toybox.BluetoothLowEnergy.Status, value as Toybox.Lang.ByteArray) as Void {
            _log("onCharacteristicRead", [characteristic, status, value]);
            _delegate.onCharacteristicRead(characteristic, status, value);
        }

        //! Override Toybox.BluetoothLowEnergy.BleDelegate.onCharacteristicWrite
        function onCharacteristicWrite(characteristic as Toybox.BluetoothLowEnergy.Characteristic, status as Toybox.BluetoothLowEnergy.Status) as Void {
            _log("onCharacteristicWrite", [characteristic, status]);
            _delegate.onCharacteristicWrite(characteristic, status);
        }

        //! Override Toybox.BluetoothLowEnergy.BleDelegate.onConnectedStateChanged
        function onConnectedStateChanged(device as Toybox.BluetoothLowEnergy.Device, state as Toybox.BluetoothLowEnergy.ConnectionState) as Void {
            _log("onConnectedStateChanged", [device, state]);
            if (state == Toybox.BluetoothLowEnergy.CONNECTION_STATE_CONNECTED) {
                _device = device;
            } else {
                _device = null;
            }
            _delegate.onConnectedStateChanged(device, state);
        }

        //! Override Toybox.BluetoothLowEnergy.BleDelegate.onDescriptorRead
        function onDescriptorRead(descriptor as Toybox.BluetoothLowEnergy.Descriptor, status as Toybox.BluetoothLowEnergy.Status, value as Toybox.Lang.ByteArray) as Void {
            _log("onDescriptorRead", [descriptor, status, value]);
            _delegate.onDescriptorRead(descriptor, status, value);
        }

        //! Override Toybox.BluetoothLowEnergy.BleDelegate.onDescriptorWrite
        function onDescriptorWrite(descriptor as Toybox.BluetoothLowEnergy.Descriptor, status as Toybox.BluetoothLowEnergy.Status) as Void {
            _log("onDescriptorWrite", [descriptor, status]);
            _delegate.onDescriptorWrite(descriptor, status);
        }

        //! Override Toybox.BluetoothLowEnergy.BleDelegate.onProfileRegister
        function onProfileRegister(uuid as Toybox.BluetoothLowEnergy.Uuid, status as Toybox.BluetoothLowEnergy.Status) as Void {
            _log("onProfileRegister", [uuid, status, _registeredProfile.size()]);
            if (status == Toybox.BluetoothLowEnergy.STATUS_SUCCESS) {
                if (_registeredProfile.indexOf(uuid) == -1) {
                    _registeredProfile.add(uuid);
                    _log("onProfileRegister", ["+1", uuid, status, _registeredProfile.size()]);
                }
            }
        }

        //! Override Toybox.BluetoothLowEnergy.BleDelegate.onScanResults
        function onScanResults(scanResults as Toybox.BluetoothLowEnergy.Iterator) as Void {
            _log("onScanResults", [scanResults]);
            if (_registeredProfile.size() < 3) {
                _log("onScanResults", ["Profile not registered yet", _registeredProfile.size()]);
                return;
            }
            for (var device = scanResults.next() as Toybox.BluetoothLowEnergy.ScanResult; device != null; device = scanResults.next()) {
                _log("onScanResults", [
                    "rssi",         device.getRssi(),
                    "rawData",      arrayToHex(device.getRawData()),
                    "serviceUuids", device.getServiceUuids(),
                ]);
                if (!(device has :getDeviceName)) {
                    _log("onScanResults", ["No getDeviceName", device]);
                    continue;
                }
                var dataMicrooled = device.getManufacturerSpecificData(0x08F2);
                if (dataMicrooled == null) {
                    var msdIterator = device.getManufacturerSpecificDataIterator();
                    for (var msd = msdIterator.next() as { :data as Toybox.Lang.ByteArray }; msd != null; msd = msdIterator.next()) {
                        if (msd[:data] == null) { continue; }
                        var msdData = msd[:data] as Toybox.Lang.ByteArray;
                        var idx = msdData.size();
                        if (idx >= 2 && msdData.decodeNumber(Toybox.Lang.NUMBER_FORMAT_UINT16, { :offset => 0, :endianness => Toybox.Lang.ENDIAN_BIG }) == 0x08F2) {
                            _log("onScanResults", ["Microoled partner", msd]);
                            dataMicrooled = msdData;
                            break;
                        }
                    }
                    if (dataMicrooled == null) { continue; }
                }
                _log("onScanResults", ["Microoled", device]);
                _delegate.onScanResult(device);
                // TODO: Disabled _log but might be good later to update with advertized services
                /* var servs = device.getServiceUuids();
                for (var serv = servs.next() as Toybox.BluetoothLowEnergy.Uuid; serv != null; serv = servs.next()) {
                    var servData = device.getServiceData(serv);
                    if (servData != null) {
                        servData = arrayToHex(servData);
                    }
                    _log("getServiceUuids - iterate :", [serv, servData]);
                } */
            }
        }

        //! Override Toybox.BluetoothLowEnergy.BleDelegate.onScanStateChange
        function onScanStateChange(scanState as Toybox.BluetoothLowEnergy.ScanState, status as Toybox.BluetoothLowEnergy.Status) as Void {
            _log("onScanStateChange", [scanState, status]);
            _fixScanStateNbSwitch = 0;
            _currentScanState = scanState;
            var profileSize = _registeredProfile.size();
            if (_currentScanState != _desiredScanState) {
                _log("onScanStateChange", [scanState, status, "Could not set desired state", profileSize]);
                if (status == Toybox.BluetoothLowEnergy.STATUS_SUCCESS) {
                    status = Toybox.BluetoothLowEnergy.STATUS_WRITE_FAIL;
                }
                _fixScanStateNbSwitch = 1;
            } else if (profileSize < 3) {
                _log("onScanStateChange", [scanState, "STATUS_NOT_ENOUGH_RESOURCES", profileSize]);
                status = Toybox.BluetoothLowEnergy.STATUS_NOT_ENOUGH_RESOURCES;
                if (_currentScanState == Toybox.BluetoothLowEnergy.SCAN_STATE_SCANNING) {
                    _fixScanStateNbSwitch = 2;
                }
            } else if (profileSize > 3) {
                _log("onScanStateChange", [scanState, status, "Profile registered more than expected", profileSize]);
            }
            _delegate.onScanStateChange(scanState, status);
        }

        //! Try and retry to get a characteristic from a service.
		//! Throw an exception if not possible.
        //!
        //! @param serviceUuid        The service uuid.
        //! @param characteristicUuid The characteristic uuid.
        //! @param nbRetry            The number of retry.
        //!
        //! @return                   The Bluetooth characteristic.
        //! @throws                   Toybox.Lang.InvalidValueException
        //!                           if the characteristic could not be
        //!                           retrieved after the number of retry.
		private function tryGetServiceCharacteristic(
            serviceUuid        as Toybox.BluetoothLowEnergy.Uuid,
            characteristicUuid as Toybox.BluetoothLowEnergy.Uuid,
            nbRetry              as Toybox.Lang.Number
        ) as Toybox.BluetoothLowEnergy.Characteristic {
            if (_device == null) { throw new Toybox.Lang.InvalidValueException("(E) Not connected"); }
            var dev = _device as Toybox.BluetoothLowEnergy.Device;
            var service = dev.getService(serviceUuid);
            for (var i = 0; i < nbRetry; i ++) {
                if (service == null) {
                    service = dev.getService(serviceUuid);
                } else {
                    var characteristic = service.getCharacteristic(characteristicUuid);
                    if (characteristic != null) {
                        _log("tryGetServiceCharacteristic", [serviceUuid, characteristicUuid, nbRetry, i]);
                        return characteristic;
                    }
                }
            }
			if(service == null) {
                throw new Toybox.Lang.InvalidValueException(
                    Toybox.Lang.format("(E) Could not get service $1$", [serviceUuid])
                );
            }
            throw new Toybox.Lang.InvalidValueException(
                Toybox.Lang.format("(E) Could not get characteristic $1$", [characteristicUuid])
            );
		}

        //! Try 5 times to get the <code>BLE_CHAR_ACTIVELOOK_RX</code> characteristic
        //! from the <code>BLE_SERV_ACTIVELOOK</code> service.
        //!
        //! @return The Bluetooth characteristic.
        //! @throws A <code>Toybox.Lang.InvalidValueException</code>
        //!         if the characteristic could not be retrieved after 5 attempts.
        function getBleCharacteristicActiveLookRx() as Toybox.BluetoothLowEnergy.Characteristic {
            _log("getBleCharacteristicActiveLookRx", []);
            return tryGetServiceCharacteristic(BLE_SERV_ACTIVELOOK, BLE_CHAR_ACTIVELOOK_RX, 5);
        }

        //! Try 5 times to get the <code>BLE_CHAR_ACTIVELOOK_TX</code> characteristic
        //! from the <code>BLE_SERV_ACTIVELOOK</code> service.
        //!
        //! @return The Bluetooth characteristic.
        //! @throws A <code>Toybox.Lang.InvalidValueException</code>
        //!         if the characteristic could not be retrieved after 5 attempts.
        function getBleCharacteristicActiveLookTx() as Toybox.BluetoothLowEnergy.Characteristic {
            _log("getBleCharacteristicActiveLookTx", []);
            return tryGetServiceCharacteristic(BLE_SERV_ACTIVELOOK, BLE_CHAR_ACTIVELOOK_TX, 5);
        }

        //! Try 5 times to get the <code>BLE_CHAR_ACTIVELOOK_GESTURE_EVENT</code> characteristic
        //! from the <code>BLE_SERV_ACTIVELOOK</code> service.
        //!
        //! @return The Bluetooth characteristic.
        //! @throws A <code>Toybox.Lang.InvalidValueException</code>
        //!         if the characteristic could not be retrieved after 5 attempts.
        function getBleCharacteristicActiveLookGesture() as Toybox.BluetoothLowEnergy.Characteristic {
            _log("getBleCharacteristicActiveLookGesture", []);
            return tryGetServiceCharacteristic(BLE_SERV_ACTIVELOOK, BLE_CHAR_ACTIVELOOK_GESTURE_EVENT, 5);
        }

        // TODO: Unused... Remove ?
        // function getBleCharacteristicManufacturerName() as Toybox.BluetoothLowEnergy.Characteristic {
        //     _log("getBleCharacteristicManufacturerName", []);
        //     return tryGetServiceCharacteristic(BLE_SERV_DEVICE_INFORMATION, BLE_CHAR_MANUFACTURER_NAME, 5);
        // }

        // TODO: Unused... Remove ?
        // function getBleCharacteristicModelNumber() as Toybox.BluetoothLowEnergy.Characteristic {
        //     _log("getBleCharacteristicModelNumber", []);
        //     return tryGetServiceCharacteristic(BLE_SERV_DEVICE_INFORMATION, BLE_CHAR_MODEL_NUMBER, 5);
        // }

        // TODO: Unused... Remove ?
        // function getBleCharacteristicSerialNumber() as Toybox.BluetoothLowEnergy.Characteristic {
        //     _log("getBleCharacteristicSerialNumber", []);
        //     return tryGetServiceCharacteristic(BLE_SERV_DEVICE_INFORMATION, BLE_CHAR_SERIAL_NUMBER, 5);
        // }

        // TODO: Unused... Remove ?
        // function getBleCharacteristicHardwareVersion() as Toybox.BluetoothLowEnergy.Characteristic {
        //     _log("getBleCharacteristicHardwareVersion", []);
        //     return tryGetServiceCharacteristic(BLE_SERV_DEVICE_INFORMATION, BLE_CHAR_HARDWARE_VERSION, 5);
        // }

        //! Try 5 times to get the <code>BLE_CHAR_FIRMWARE_VERSION</code> characteristic
        //! from the <code>BLE_SERV_DEVICE_INFORMATION</code> service.
        //!
        //! @return The Bluetooth characteristic.
        //! @throws A <code>Toybox.Lang.InvalidValueException</code>
        //!         if the characteristic could not be retrieved after 5 attempts.
        function getBleCharacteristicFirmwareVersion() as Toybox.BluetoothLowEnergy.Characteristic {
            _log("getBleCharacteristicFirmwareVersion", []);
            return tryGetServiceCharacteristic(BLE_SERV_DEVICE_INFORMATION, BLE_CHAR_FIRMWARE_VERSION, 5);
        }

        // TODO: Unused... Remove ?
        // function getBleCharacteristicSoftwareVersion() as Toybox.BluetoothLowEnergy.Characteristic {
        //     _log("getBleCharacteristicSoftwareVersion", []);
        //     return tryGetServiceCharacteristic(BLE_SERV_DEVICE_INFORMATION, BLE_CHAR_SOFTWARE_VERSION, 5);
        // }

        //! Try 5 times to get the <code>BLE_CHAR_BATTERY_LEVEL</code> characteristic
        //! from the <code>BLE_SERV_BATTERY</code> service.
        //!
        //! @return The Bluetooth characteristic.
        //! @throws A <code>Toybox.Lang.InvalidValueException</code>
        //!         if the characteristic could not be retrieved after 5 attempts.
        function getBleCharacteristicBatteryLevel() as Toybox.BluetoothLowEnergy.Characteristic {
            _log("getBleCharacteristicBatteryLevel", []);
            return tryGetServiceCharacteristic(BLE_SERV_BATTERY, BLE_CHAR_BATTERY_LEVEL, 5);
        }

        //! Disconnect and unpair from all paired devices. Normally, there should always be at most one
		//! but to be sure to disconnect from any devices, we unpair every paired devices.
        //!
        //! @return <code>false</code> if there was no device to unpaired, <code>true</code> otherwise.
        function disconnect() as Toybox.Lang.Boolean {
            _log("disconnect", []);
            _autoDevice = null;
            var autoDevices = Toybox.BluetoothLowEnergy.getPairedDevices();
            var count = 0;
            for (var autoDevice = autoDevices.next() as Toybox.BluetoothLowEnergy.Device; autoDevice != null; autoDevice = autoDevices.next()) {
                Toybox.BluetoothLowEnergy.unpairDevice(autoDevice);
                count += 1;
            }
            return count != 0;
        }

        //! Connect and pair to a scanned device. It will first turn off scanning and
		//! disconnect from other device. This is for consistency since we don't allow
		//! multiple device to be connected at once.
		//! Then it tries to pair with the device.
        //! On error, it will call the delegate <code>onError</code> method with
        //! the caught exception from the pairing operation or with a
        //! <code>Toybox.System.PreviousOperationNotCompleteException</code> if the pairing could
        //! not be completed for unknown reason.
        //!
        //! @param scanResult The service uuid.
        //!
        //! @return           <code>true</code> if the operation was successful, <code>false</code> otherwise.
        function connect(scanResult as Toybox.BluetoothLowEnergy.ScanResult) as Toybox.Lang.Boolean {
            _log("connect", [scanResult]);
            requestScanning(false);
            disconnect();
            try {
                _autoDevice = BluetoothLowEnergy.pairDevice(scanResult);
                if (_autoDevice != null) { return true; }
                _delegate.onBleError(new Toybox.System.PreviousOperationNotCompleteException("The device could not be paired."));
            } catch (e) {
                _delegate.onBleError(e);
            }
            return false;
        }

    }

}
