import CoreBluetooth
import Foundation

private let djiOsmoAction4ManufacturerData = Data([
    0xAA,
    0x08,
    0x14,
    0x00,
    0xFA,
    0xE4,
    0x7A,
    0x2C,
    0x13,
    0x04,
    0x2D,
])

private let pair = Data([
    0x55,
    0x33,
    0x04,
    0xC2,
    0x02,
    0x07,
    0x92,
    0x80,
    0x40,
    0x07,
    0x45,
    0x20,
    0x32,
    0x38,
    0x34,
    0x61,
    0x65,
    0x35,
    0x62,
    0x38,
    0x64,
    0x37,
    0x36,
    0x62,
    0x33,
    0x33,
    0x37,
    0x35,
    0x61,
    0x30,
    0x34,
    0x61,
    0x36,
    0x34,
    0x31,
    0x37,
    0x61,
    0x64,
    0x37,
    0x31,
    0x62,
    0x65,
    0x61,
    0x33,
    0x04,
    0x31,
    0x38,
    0x33,
    0x32,
    0xA3,
    0x20,
])

let enterStreamingModeData = Data([
    0x1A,
])

let setupWiFiData = Data([
    0x05,
    0x51,
    0x76,
    0x69,
    0x73,
    0x74,
    0x08,
    0x6D,
    0x61,
    0x78,
    0x69,
    0x65,
    0x72,
    0x69,
    0x6B,
])

let startStreamingData = Data([
    0x00,
    0x2E,
    0x00,
    0x0A,
    0xB8,
    0x0B,
    0x02,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x23,
    0x00,
    0x72,
    0x74,
    0x6D,
    0x70,
    0x3A,
    0x2F,
    0x2F,
    0x31,
    0x39,
    0x32,
    0x2E,
    0x31,
    0x36,
    0x38,
    0x2E,
    0x35,
    0x30,
    0x2E,
    0x32,
    0x31,
    0x34,
    0x3A,
    0x31,
    0x39,
    0x33,
    0x35,
    0x2F,
    0x6C,
    0x69,
    0x76,
    0x65,
    0x2F,
    0x6F,
    0x61,
    0x34,
])

private let pairId: UInt16 = 0x8092
private let preparingToLivestreamId: UInt16 = 0x8C12
private let setupWiFiId: UInt16 = 0x8C19
private let startStreamingId: UInt16 = 0x8C2C

class DjiController: NSObject {
    private var centralManager: CBCentralManager?
    private var oa4Peripheral: CBPeripheral?
    private var oa4Characteristic: CBCharacteristic?

    func start() {
        // centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
    }

    func stop() {}
}

extension DjiController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            centralManager?.scanForPeripherals(withServices: nil)
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi _: NSNumber)
    {
        guard let data = advertisementData[CBAdvertisementDataManufacturerDataKey] as? NSData else {
            return
        }
        guard Data(bytes: data.bytes, count: data.count) == djiOsmoAction4ManufacturerData else {
            return
        }
        central.stopScan()
        oa4Peripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
    }

    func centralManager(_: CBCentralManager, didFailToConnect _: CBPeripheral, error _: Error?) {}

    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices(nil)
    }

    func centralManager(_: CBCentralManager, didDisconnectPeripheral _: CBPeripheral, error _: Error?) {}
}

extension DjiController: CBPeripheralDelegate {
    func peripheral(_: CBPeripheral, didModifyServices _: [CBService]) {}

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices _: Error?) {
        guard let peripheralServices = peripheral.services else {
            return
        }
        for service in peripheralServices {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error _: Error?
    ) {
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == CBUUID(string: "FFF5") {
                oa4Characteristic = characteristic
            }
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    func peripheral(_: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error _: Error?) {
        guard let value = characteristic.value else {
            return
        }
        guard let message = try? DjiMessage(data: value) else {
            return
        }
        guard let oa4Characteristic, let oa4Peripheral else {
            return
        }
        switch message.id {
        case pairId:
            logger.info("dji-controller: Preparing to livestream")
            let request = DjiMessage(
                target: 0x080266,
                id: preparingToLivestreamId,
                type: 0xE10240,
                payload: enterStreamingModeData
            )
            oa4Peripheral.writeValue(request.encode(), for: oa4Characteristic, type: .withoutResponse)
        case preparingToLivestreamId:
            logger.info("dji-controller: Setuping up WiFi")
            let request = DjiMessage(
                target: 0x07021B,
                id: setupWiFiId,
                type: 0x470740,
                payload: setupWiFiData
            )
            oa4Peripheral.writeValue(request.encode(), for: oa4Characteristic, type: .withoutResponse)
        case setupWiFiId:
            logger.info("dji-controller: Starting to stream")
            let request = DjiMessage(
                target: 0x08024B,
                id: startStreamingId,
                type: 0x780840,
                payload: startStreamingData
            )
            oa4Peripheral.writeValue(request.encode(), for: oa4Characteristic, type: .withoutResponse)
        case startStreamingId:
            logger.info("dji-controller: Streaming, hopefully")
        default:
            break
        }
    }

    func peripheral(
        _: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error _: Error?
    ) {
        guard characteristic.uuid == CBUUID(string: "FFF4") else {
            return
        }
        guard let oa4Characteristic, let oa4Peripheral else {
            return
        }
        logger.info("dji-controller: Pairing")
        oa4Peripheral.writeValue(pair, for: oa4Characteristic, type: .withoutResponse)
    }

    func peripheralIsReady(toSendWriteWithoutResponse _: CBPeripheral) {}
}