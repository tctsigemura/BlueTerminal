//
//  main.swift
//  BlueTerminal
//
//  Created by 津森智己 on 2018/10/11.
//  Copyright © 2018年 津森智己. All rights reserved.
//  Copyright © 2019年 重村哲至. All rights reserved.
//

// 使用可能コマンド一覧
//  ~.              : プログラム終了
//
// 問題点
// FileHandle.standardOutput は main スレッドから
// FileHandle.standardInput はキー入力用スレッドから使用している．
// この使い方は許されるのか調査が不足！

import Foundation
import CoreBluetooth

// MLDPのサービスのUUID
let target_service_uuid =
        CBUUID(string:"00035B03-58E6-07DD-021A-08123A000300")
let target_charactaristic_uuid =
         CBUUID(string: "00035B03-58E6-07DD-021A-08123A000301")
//  let target_charactaristic_uuid2 =
//    CBUUID(string: "00035B03-58E6-07DD-021A-08123A0003FF")

// 文字列をターミナルから入力する
func readFromTerminal() -> String {
    return String(data: FileHandle.standardInput.availableData,
                  encoding: String.Encoding.utf8) ?? ""
}

// Dataをターミナルへ出力する
func writeDataToTerminal(_ dat:Data) {
    FileHandle.standardOutput.write(dat)
}

// 文字列をターミナルへ出力する
func writeToTerminal(_ str:String) {
    writeDataToTerminal(str.data(using: .utf8)!)
}

// メッセージをターミナルに出力する
func writeMessage(_ str:String) {
    writeToTerminal("\u{1b}[36m")              // 空色に変更
    writeToTerminal("\(str)\r\n")              // メッセージ出力
    writeToTerminal("\u{1b}[0m")               // 普通の色に変更
}

// BLE の状態
enum BleState {
    case powerOff                              // 初期状態
    case powerOn                               // BLE の電源が ON になっている
    case inSearch                              // デバイスを探索中
    case found                                 // 目的のデバイスが見つかった
    case trying                                // 接続作業中
    case established                           // 接続完了
    case inOperation                           // 入出力処理中
    case closed                                // 接続が終了した
}
var bleState = BleState.powerOff               // 初期状態

// セントラルマネージャーを管理するクラス
class CentralManager: NSObject, CBCentralManagerDelegate {
    var bleManager: CBCentralManager!          // BLE のセントラルマネージャ
    var bleDevices = [CBPeripheral]()          // 発見したデバイスの一覧
    var bleDevice: CBPeripheral?               // 選択されたデバイス
    var deviceName: String?                    // 自動的に選択するデバイス名
    
    // 初期化
    override init() {
        super.init()                           // NSObjectのinit
        bleManager = CBCentralManager(         // セントラルマネージャを作る
            delegate: self as CBCentralManagerDelegate,
            queue: nil,                        // main thread のqueueを使用する
            options: nil)
    }
    
    // セントラルマネージャの状態が変化すると呼ばれる
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOff:
            writeMessage("Bluetooth powered OFF")
            exit(1)
        case .poweredOn:
        //  writeMessage("Bluetooth powered ON")
            bleState = .powerOn
        case .resetting:
            writeMessage("Resetting")
            exit(1)
        case .unauthorized:
            writeMessage("Unauthenticated")
            exit(1)
        case .unknown:
            writeMessage("Unknown")
            exit(1)
        case .unsupported:
            writeMessage("Unsupported")
            exit(1)
        default:
            writeMessage("Unknown status")
            exit(1)
        }
    }

    // ペリフェラルを発見すると呼ばれる
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        if deviceName != nil && bleDevice == nil {        // 指名ありの場合
            if deviceName == peripheral.name {
                bleDevice = peripheral
                bleState = .found                         // デバイス決定
            }
        } else if deviceName == nil {                     // 指名なしの場合
            if peripheral.name != nil && !bleDevices.contains(peripheral) {
                bleDevices.append(peripheral)
                writeMessage("\(bleDevices.count) : \(peripheral.name!)")
            }
        }
    }

    // ペリフェラルへの接続が成功すると呼ばれる
    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        if let name = peripheral.name {
            writeMessage("\"\(name)\"へ接続しました．")
        }
        bleState = .established                           // 接続が確立した
    }
    
    // ペリフェラルとの接続が切断されると呼ばれる
    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        writeMessage("")
        writeMessage("接続が切断されました．")
        bleState = .closed                               // 接続が切断された
    }

    // BLEデバイスの検出を開始
    func startScan() {
        bleManager.scanForPeripherals(
                        withServices:[target_service_uuid], options: nil)
    }
    
    // BLEデバイスの検出を終了
    func stopScan() {
        bleManager.stopScan()
    }

    // デバイスに接続する関数
    func connect() {
        bleManager.connect(bleDevice!, options: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {  // ３秒後に
            if bleState != .inOperation {                      // 接続が完了し
                writeMessage("接続が完了しませんでした．")     //  たかチェック
                bleState = .closed
            }
        }
    }
}

// 選択されたデバイスを管理するクラス
class DeviceManager: NSObject, CBPeripheralDelegate {
    var bleDevice: CBPeripheral!               // デバイス
    var outputCharacteristic:CBCharacteristic! // キャラクタリスティック

    // サービス発見時に呼ばれる
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        
        guard error == nil else {
            print(error.debugDescription)
            return
        }
        
        guard let services = peripheral.services, services.count > 0 else {
            writeMessage("No Services")
            return
        }
        
        for service in services {          // キャラクタリスティックを探索開始
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    // キャラクタリスティック発見時に呼ばれる
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard error == nil else {
            writeMessage(error.debugDescription)
            return
        }
        
        guard let characteristics = service.characteristics,
                                    characteristics.count > 0 else {
            writeMessage("No Characteristics")
            return
        }
        
        for characteristic in characteristics
            where characteristic.uuid.isEqual(target_charactaristic_uuid) {
            outputCharacteristic = characteristic      // 使用するもの
            peripheral.readValue(for: characteristic)
            
            // 更新通知受け取りを開始する
            peripheral.setNotifyValue(true, for: characteristic)
            
            // 接続完了をTeCに知らせる
            let str = "MLDP\r\nApp:on\r\n"
            let data = str.data(using: String.Encoding.utf8)
            peripheral.writeValue(data!, for: outputCharacteristic,
                                  type: CBCharacteristicWriteType.withResponse)
            break
        }
    }
    
    // Notify開始／停止時に呼ばれる
    func peripheral(_ peripheral: CBPeripheral,
              didUpdateNotificationStateFor characteristic: CBCharacteristic,
              error: Error?) {
        guard error == nil else {
            writeMessage(error.debugDescription)
            return
        }
    }
    
    // データ更新時に呼ばれる
    func peripheral( _ peripheral: CBPeripheral,
              didUpdateValueFor characteristic: CBCharacteristic,
              error: Error?) {
        guard error == nil else {
            if characteristic.value != nil {           // このifは，なぜか必要
                writeMessage("\(error.debugDescription)")
            }
            return
        }
        if let data = characteristic.value {           // 受信データを取り出し
            writeDataToTerminal(data)                  // ターミナルに表示する
        }
    }
    
    // データ書き込みが完了すると呼ばれる
    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if error != nil {
            writeMessage("""
               Write failed...error: \(error.debugDescription), \
               characteristic uuid: \(characteristic.uuid)
               """
            )
            bleState = .closed
        }
    }

    // サービス開始
    func activate() {
        bleDevice.discoverServices([target_service_uuid])
    }

    // デバイスにデータを送信する
    func write(_ inputCharacter : Character) {
        bleDevice.writeValue(
            String(inputCharacter).data(using: String.Encoding.utf8)!,
            for: outputCharacteristic,
            type: CBCharacteristicWriteType.withResponse
        )
    }

    // TeCに切断を知らせす
    func close() {
        let str = "ERR\r\nERR\r\n"
        let data = str.data(using: String.Encoding.utf8)
        bleDevice.writeValue(data!, for: outputCharacteristic,
                              type: CBCharacteristicWriteType.withResponse)
    }
}

// ~. ~: ~? を見つけるステートマシン
var stat: Int = 0
func findEscape(_ char : Character) -> Int {
    switch stat {
    case 0:
        if char=="~" {                                 // ~ だ．
            stat = 1                                   // 用心する
            return -1                                  // 表示はちょっと待って
        }
    case 1:
        stat = 0
        if char=="." { return 2 }                      // ~. 発見
        if char==":" { return 3 }                      // ~: 発見
        if char=="?" { return 4 }                      // ~? 発見
        return 1                                       // ただの ~ だった
    default:
        stat = 0
    }
    return 0;
}

// キー入力でデバイスを選択する（キーボード用のスレッドで実行される）
func selectDevice(_ centralManager: CentralManager) -> CBPeripheral? {
    var number = 0                                     // 入力された数値
    while true {
        let inputString = readFromTerminal()           // 標準入力から読む
        for inputCharacter in inputString {            // 各文字について
            if findEscape(inputCharacter) == 2 {       // ~. だ
                DispatchQueue.main.async {             // mainスレッドで
                    writeMessage("")                   // ターミナル画面を改行
                }
                return nil                             // 選択されていないが
            }                                          //   終了する
            if let digit = Int(String(inputCharacter)) { // 数字なら
                writeToTerminal(String(digit))
                number = number * 10 + digit
            } else if inputCharacter == "\r" {         // [Enter]が押された
                DispatchQueue.main.async {             // mainスレッドで
                    writeMessage("")
                }
                if 0 < number && number <= centralManager.bleDevices.count {
                    return centralManager.bleDevices[number - 1]  // 決定！！
                } else {
                    DispatchQueue.main.async {         // mainスレッドで
                        writeMessage("\"\(number)\"は選択できません．")
                    }
                    number = 0
                }
            } else if inputCharacter == "\u{7f}" {     // deleteのとき
                number = number / 10
                DispatchQueue.main.async {             // mainスレッドで
                    writeToTerminal("\u{08} \u{08}")   // 表示を一字消す
                }
            }
        }
    }
}

// キー入力を BLE に書き込む（キーボード用のスレッドで実行される）
func writeProcess(_ deviceManager: DeviceManager) {
    while true {
        let inputString = readFromTerminal()           // 標準入力から読む
        for inputCharacter in inputString {            // 各文字について
            switch findEscape(inputCharacter) {        // エスケープをチェック
            case -1:                                   // ~ だ．
                break                                  // ちょっと待て
            case 0:                                    // 普通の文字だ．
                if bleState == .inOperation {          // 接続中なら
                  DispatchQueue.main.async {           // mainスレッドで
                    deviceManager.write(inputCharacter)// BLEに書き込む
                  }
                }
            case 2:                                    // ~. だ．
                if bleState == .inOperation {          // 接続中なら
                   DispatchQueue.main.async {          // mainスレッドで
                       deviceManager.close()           // TeCに切断を知らせる
                   }
                }
                return
            default:                                   // 興味のない ~ だった
                if bleState == .inOperation {          // 接続中なら
                   DispatchQueue.main.async {          // mainスレッドで
                       deviceManager.write("~")        // BLEに書き込む
                       deviceManager.write(inputCharacter)
                   }
                }
            }
        }
    }
}

/* main関数 */
// インスタンス生成
let centralManager = CentralManager()            // CentralManagerの管理用
let deviceManager = DeviceManager()              // DeviceManagerの管理用

// コマンド行引数
let argv = ProcessInfo.processInfo.arguments
switch argv.count {
case 1:                                           // 引数無しで起動された
    break
case 2:                                           // 名前付きで起動された
    centralManager.deviceName = argv[1]
default:                                          // 使い方が間違っている
    writeMessage("Usage: blueTerminal [devicename]")
    exit(1)
}

// キーボードの面倒を見るスレッドを起こす
writeMessage("~. : プログラム終了")               // スレッド終了の操作方法
DispatchQueue.global().async {
    if centralManager.deviceName == nil {         // 手動でデバイスを選択する
        if let device = selectDevice(centralManager) {
            centralManager.bleDevice = device
            bleState = .found
            DispatchQueue.main.async { }          // mainスレッドを起こす
            writeProcess(deviceManager)           // キーボードとBLEの通信送信
        }
    } else {
        writeProcess(deviceManager)               // キーボードとBLEの通信送信
    }
    bleState = .closed
    DispatchQueue.main.async { }                  // mainスレッドを起こす
}

// メインスレッドの RunLoop（RunLoop.main と RunLoop.currentは同じ）
let runLoop = RunLoop.main

// BLEの変化を待つループ
while runLoop.run(mode: RunLoop.Mode.default, before: Date.distantFuture) {
    switch bleState {
    case .powerOn:                                // 起動した（初期状態）
        centralManager.startScan()                // スキャン開始
        bleState = .inSearch
    case .found:                                  // 目的のデバイスが見つかった
        centralManager.stopScan()                 // スキャン終了
        centralManager.bleDevice!.delegate =
                        deviceManager as CBPeripheralDelegate
	deviceManager.bleDevice = centralManager.bleDevice
        centralManager.connect()                  // デバイスと接続を開始する
        bleState = .trying
    case .established:                            // デバイスと接続された
        deviceManager.activate()                  // 通信を開始する
	bleState = .inOperation
    case .closed:                                 // 接続が切断された
        writeMessage("")                          // ターミナルの画面を改行し
        exit(0)                                   // 終了する
    default:
        break                                     // その他の状態には興味がない
    }
}
