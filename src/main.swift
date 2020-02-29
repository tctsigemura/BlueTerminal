// main.swift
import Foundation

class BleTerminal {
    private let stdioManager = StdioManager()       // 標準入出力管理
    private let bleManager = BleManager()           // rn4020との通信管理
    private var deviceList = [String]()             // デバイスの一覧
    private var deviceName: String?                 // 接続するデバイスの名前
    private let comFSM = ComFSM()                   // '~'コマンドを検出するFSM
    private let numFSM = NumFSM()                   // 数値入力用のFSM

    // メッセージをターミナルに出力する
    private func writeMessage(_ str:String) {
        stdioManager.write("\u{1b}[36m".data(using:.utf8)!) // 空色に変更
        stdioManager.write("\(str)\r\n".data(using:.utf8)!) // メッセージ出力
        stdioManager.write("\u{1b}[0m".data(using:.utf8)!)  // 元の色に戻す
    }

    // デバイスの一覧を表示する
    private func printDeviceList(from start:Int, to end:Int) {
        if start <= end {
            for count in start ... end {
                writeMessage("\(count + 1) : \(deviceList[count])")
            }
        }
    }

    // 新しいデバイスがあれば deviceList を更新し添字範囲で返す
    private func checkNewDevices() -> (Int, Int)? {
        let newDeviceList = bleManager.getDeviceList()
        if deviceList.count != newDeviceList.count {    // 新デバイス発見
            let start = deviceList.count
            deviceList = newDeviceList
            return (start, deviceList.count-1)
        }
        return nil
    }

    // デバイス選択ステージに実行されキーボード入力でデバイスを選択する
    private func select() -> Bool {
        if let (start, end) = checkNewDevices() {
            printDeviceList(from:start, to:end)
        }
        if let data = stdioManager.read() {
            for char in data {
                if comFSM.feedChar(char) == .close {        // "~."
                    return false
                }
                switch numFSM.feedChar(char) {
                case .numeric:
                    stdioManager.write(Data([char]))
                case .delete:
                    stdioManager.write("\u{08} \u{08}".data(using:.utf8)!)
                case .enter:
                    stdioManager.write("\r\n".data(using:.utf8)!)
                    if 1<=numFSM.number && numFSM.number<=deviceList.count {
                        deviceName = deviceList[numFSM.number-1]
                        bleManager.connect(numFSM.number-1)
                    } else {
                        writeMessage("TeCの番号が不正です．")
                        printDeviceList(from:0, to:deviceList.count-1)
                    }
                default:
                    break
                }
            }
        }
        return true
    }

    // デバイス選択ステージでデバイス名が指定済みの場合に実行される
    private func search(for device:String) -> Bool {
        if let (start, end) = checkNewDevices() {
            for i in start ... end {
                if deviceList[i] == device {
                    bleManager.connect(i)
                }
            }
        }
        if let data = stdioManager.read() {
            for char in data {
                if comFSM.feedChar(char) == .close {        // "~."
                    return false
                }
            }
        }
        return true
    }

    // 通信ステージに実行される
    private func communicate() -> Bool {
        if let data=bleManager.read() {
            stdioManager.write(data)
        }
        if stdioManager.isEof() {
          return false
        } else if let data = stdioManager.read() {
            for char in data {
                switch comFSM.feedChar(char) {
                case .close:                                // "~."
                    return false
                case .cancel, .help, .command:
                    bleManager.write("~".data(using:.utf8)!)
                    bleManager.write(Data([char]))
                case .character:
                    bleManager.write(Data([char]))
                case .candidate:
                    break
                }
            }
        }
        return true
    }

    // アプリの状態
    private enum State {
        case opening                                       // 接続準備中
        case established                                   // 通信中
        case closing                                       // 切断処理中
    }
    private var state = State.opening

    // 入出力イベントの発生を待つ，イベントが発生なしでも１秒に1度はループする
    // （Timer は runLoop.run() を終了させないので1秒でタイムアウトさせる）
    private func mainLoop() {
        let runLoop = RunLoop.main
        loop: while runLoop.run(mode:RunLoop.Mode.default, before:Date()+1.0) {
            let bleState = bleManager.state
            if bleState == .ready {
                bleManager.startScan()
            } else if bleState == .inOperation && state != .established {
                bleManager.write("MLDP\r\nApp:on\r\n".data(using:.utf8)!)
                writeMessage("\"\(deviceName!)\"に接続しました．")
                state = .established
            }
            switch state {
            case .established:
                if bleState != .inOperation {
                    writeMessage("\r\n通信中にエラーが発生しました．")
                    break loop
                } else if !communicate() {
                    // キーボードで終了の操作がされた
                    bleManager.write("ERR\r\nERR\r\n".data(using:.utf8)!)
                    bleManager.close()
                    state = .closing
                }
            case .opening:
                if bleState == .failed || bleState == .error {
                    writeMessage("エラーが発生しました．")
                    break loop
                }
                if deviceName != nil {             // 接続相手が指定されている
                    if !search(for:deviceName!) {  // 自動的に選択
                        writeMessage("プログラムを中止します．")
                        break loop                 // キーボードで終了操作
                    }
                } else if !select() {              // キー操作で選択
                    writeMessage("プログラムを中止します．")
                    break loop                     // キーボードで終了操作
                }
            case .closing:
                if bleState == .closed {
                    writeMessage("\r\n切断が完了しました．")
                    break loop
                } else if bleState == .failed || bleState == .error {
                    writeMessage("\r\n切断が失敗が失敗しました．")
                    break loop
                }
            }  // switch
        } // loop
    }  // mainLoop

    // 起動時の処理を行ったあと mainLoop を呼び出す．
    func run(_ name:String?) {
        deviceName = name
        writeMessage("終了する時は「~.」を入力します．")
        if deviceName == nil {
            writeMessage("接続するTeCの番号を入力してください．")
        } else {
            writeMessage("\"\(deviceName!)\"を探します．")
        }
        mainLoop()
    }
} // BleTerminal

// ここから実行が開始される
let bleTerminal = BleTerminal()
let argv = ProcessInfo.processInfo.arguments      // コマンド行引数
switch argv.count {
case 1:                                           // 引数無しで起動された
    bleTerminal.run(nil)
case 2:                                           // 名前付きで起動された
    bleTerminal.run(argv[1])
default:                                          // 使い方が間違っている
    print("Usage: blueTerminal [devicename]\r\n")
    exit(1)
}
