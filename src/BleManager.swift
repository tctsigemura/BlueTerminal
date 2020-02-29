//  centralManager.swift
import Foundation
import CoreBluetooth

// BLEを管理するクラス
class BleManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    // MLDPのサービスのUUID
    private let target_service_uuid =              // MLDP Service
        CBUUID(string:"00035B03-58E6-07DD-021A-08123A000300")
    private let target_charactaristic_uuid =       // Read/Write/Notify 用
        CBUUID(string: "00035B03-58E6-07DD-021A-08123A000301")
//  privatelet target_charactaristic_uuid2 =       // Read/Write 用
//      CBUUID(string: "00035B03-58E6-07DD-021A-08123A0003FF")

    private var centralManager: CBCentralManager!  // BLE セントラル
    private var peripherals = [CBPeripheral]()     // 発見したデバイス一覧
    private var peripheral: CBPeripheral?          // 選択したデバイス
    private var characteristic: CBCharacteristic?  // データの出力先
    private var readData: Data?                    // 受信したデータ
    private var timer: Timer?                      // 接続待ちタイムアウト用

    enum State {                                   // BleManager の状態
        case initializing                          //   初期化中
        case ready                                 //   電源ON確認
        case scanning                              //   スキャン中
        case trying                                //   接続処理中
        case failed                                //   接続失敗
        case inOperation                           //   通信中
        case canceling                             //   切断待ち
	case closed                                //   切断完了
	case error                                 //   エラー発生
    }
    var state: State = .initializing               //   初期化中から始める

    // BleManager のコンストラクタ
    override init() {
        super.init()
        centralManager = CBCentralManager(         // BLE セントラルを作る
            delegate:self, queue:nil, options:nil) // main thread を使用
    }

    // セントラルマネージャの状態が変化すると呼ばれる
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
	    state = .ready
        default:
            NSLog("BleManager: unexpected state")
	    state = .error
        }
    }

    // ペリフェラルを発見すると呼ばれる
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        if !peripherals.contains(peripheral) {
            peripherals.append(peripheral)
        }
    }

    // ペリフェラルへの接続が成功すると呼ばれる
    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([target_service_uuid])
        timer?.invalidate()
    }

    // ペリフェラルとの接続が切断されると呼ばれる
    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
	state = .closed
    }

    // サービス発見時に呼ばれる
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        guard error == nil else {
            NSLog("BleManager: %@", error.debugDescription)
	    state = .error
            return
        }
        for service in peripheral.services! {
            peripheral.discoverCharacteristics(nil, for:service)
        }
    }

    // キャラクタリスティック発見時に呼ばれる
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard error == nil else {
            NSLog("BleManager: %@", error.debugDescription)
	    state = .error
            return
        }
        for characteristic in service.characteristics!
            where characteristic.uuid.isEqual(target_charactaristic_uuid) {
            self.characteristic = characteristic
            peripheral.setNotifyValue(true, for:characteristic)
            break
        }
	state = .inOperation
    }

    // Notify開始／停止時に呼ばれる
    func peripheral(_ peripheral: CBPeripheral,
              didUpdateNotificationStateFor characteristic: CBCharacteristic,
              error: Error?) {
        guard error == nil else {
            NSLog("BleManager: %@", error.debugDescription)
	    state = .error
            return
        }
    }

    // peripheralからデータが届いたときのイベント
    func peripheral( _ peripheral: CBPeripheral,
              didUpdateValueFor characteristic: CBCharacteristic,
              error: Error?) {
        guard error == nil else {
            NSLog("BleManager: %@", error.debugDescription)
	    state = .error
            return
        }
        if let data = characteristic.value {
	    if readData != nil {
                readData!.append(data)
	    } else {
	        readData = data
            }
        }
    }

    // データ書き込みが完了すると呼ばれる
    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard error == nil else {
            NSLog("BleManager: %@", error.debugDescription)
	    state = .error
	    return
        }
    }

    // BLEデバイスの検出を開始
    func startScan() {
        centralManager.scanForPeripherals(
                        withServices:[target_service_uuid], options:nil)
	state = .scanning
    }

    // 接続可能なデバイスの一覧表を返す
    func getDeviceList() -> [String] {
        var names = [String]()
        for peripheral in peripherals {
            names.append(peripheral.name!)
        }
        return names
    }

    // デバイスに接続する関数
    func connect(_ row : Int) {                // row 番目のデバイスに接続する
        guard 0 <= row && row < peripherals.count else {
	    return                             // 番号間違えなら無視
	}
        peripheral = peripherals[row]          // 選択したデバイスを記録
        centralManager.stopScan()              // デバイスの検出を終了
        centralManager.connect(peripheral!, options:nil)  // 接続開始
        peripheral!.delegate = self
	timer = Timer.scheduledTimer(timeInterval:3.0, target:self,
                       selector:#selector(BleManager.timeOut),
		       userInfo:nil, repeats:false)
	state = .trying
    }

    // デバイスにデータを送信する
    func write(_ data : Data) {
            peripheral?.writeValue(data, for:characteristic!,
                type: CBCharacteristicWriteType.withResponse)
    }

    // 受信データを取り出す
    func read()-> Data? {
      let copy = readData
      readData = nil
      return copy
    }

    // 接続を切断する
    func close() {
        peripheral?.setNotifyValue(false, for:characteristic!)
        centralManager.cancelPeripheralConnection(peripheral!)
	timer = Timer.scheduledTimer(timeInterval:3.0, target:self,
                       selector:#selector(BleManager.timeOut),
		       userInfo:nil, repeats:false)
	state = .canceling
    }

    // タイマーから呼ばれれる
    @objc func timeOut() {                     // @objc: Objective-C が呼ぶ
        state = .failed                        // runLoop は終わらない（仕様）
    }
} // BleManager
