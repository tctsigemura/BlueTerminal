// main.swift
import Foundation
import CoreBluetooth

class BleTerminal {
    private let stdioManager = StdioManager()       // 標準入出力管理
    private let bleManager = BleManager()           // rn4020との通信管理
    private var deviceList = [String]()             // デバイスの一覧
    private var deviceName: String?                 // 接続するデバイスの名前
    private let commandFSM = CommandFSM()           // '~'コマンドを検出するFSM
    private let numberFSM = NumberFSM()             // 数値入力用のFSM
    private let stringFSM = StringFSM()             // 文字列入力用のFSM
    private var fileHandle: FileHandle?             // TWRITE中の入力ファイル
    private var oldTec7: Bool=false                 // TeC7bc の場合

    // アプリの状態
    private enum State {
        case opening                                // 接続準備中
        case established                            // 通信中
        case prompting                              // ファイル名入力中
        case sending                                // TeCへフィアル転送中
        case closing                                // 切断処理中
    }
    private var state = State.opening

    // ターミナルにStringを出力する
    private func writeToTerminal(_ str:String) {
        stdioManager.write(str.data(using:.utf8)!)  // Dataに変換して出力
    }

    // メッセージをターミナルに出力する
    private func writeMessage(_ str:String) {
        writeToTerminal("\u{1b}[36m")               // 空色に変更
        writeToTerminal("\(str)\r\n")               // メッセージ出力
        writeToTerminal("\u{1b}[0m")                // 元の色に戻す
    }

    // メッセージをターミナルに出力する
    private func writeError(_ str:String) {
        writeToTerminal("\u{1b}[31m")               // 赤色に変更
        writeToTerminal("\(str)\r\n")               // メッセージ出力
        writeToTerminal("\u{1b}[0m")                // 元の色に戻す
    }

    // デバイスの一覧を表示する
    private func printDeviceList(from start:Int, to end:Int) {
        if start <= end {
            for count in start ... end {
                writeMessage("\r\u{1b}[J\(count + 1) : \(deviceList[count])")
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

    // 番号で指定してTeCに接続する
    private func connect(to num:Int) {
        writeToTerminal("\r\n")
        if 1 <= num && num <= deviceList.count {
            deviceName = deviceList[num - 1]
            bleManager.connect(num - 1)
        } else {
            writeError("TeCの番号が不正です．")
            printDeviceList(from:0, to:deviceList.count - 1)
        }
    }

    // キーボードから終了の操作 "~." がされた
    private func isEof(_ data:Data) -> Bool {
        for char in data {
            if commandFSM.feedChar(char) == .close {            // "~."
                return true
            }
        }
        return false
    }

    // デバイス選択ステージに実行されキーボード入力でデバイスを選択する
    private func select() -> Bool {
        if let (start, end) = checkNewDevices() {
            printDeviceList(from:start, to:end)
        }
        if stdioManager.isEof() {
          return false
        } else if let data = stdioManager.read() {
            if isEof(data) {
                return false
            }
            for char in data {
                switch numberFSM.feedChar(char) {
                case .enter:
                    let num = numberFSM.number
            numberFSM.number = 0
            connect(to: num)
                default:   // numeric, delete
                    break
                }
            }
        }
        if case .scanning = bleManager.state {
            writeToTerminal("\r\u{1b}[J")                       // 行を消す
            writeToTerminal("TeC No: ")
            if numberFSM.number > 0 {
                writeToTerminal("\(numberFSM.number)")
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
                    break
                }
            }
        }
        if let data = stdioManager.read()  {
            return !isEof(data)
        }
        return true
    }

    // デバイス選択ステージで実行される
    private func opening() -> Bool {
        if case .idle = bleManager.state {
        if (oldTec7) {
                bleManager.write("MLDP\r\nApp:on\r\n".data(using:.utf8)!)
            }
            writeMessage("\"\(deviceName!)\"に接続しました．")
            state = .established
        } else if case .scanning = bleManager.state {
            if deviceName == nil {
                return select()
            } else {
                return search(for:deviceName!)
            }
        } else if let data = stdioManager.read() {
            return !isEof(data)
        }
        return true
    }

    // ファイルの送信を開始する
    private func startSending() {
        fileHandle=FileHandle(forReadingAtPath:stringFSM.string)
        if let file = fileHandle {
            let data = file.readDataToEndOfFile()
            file.closeFile()
            if data.count < 3 || 256 < data.count ||
               data.count != data[1] + 2 {
                writeError("\".bin\"ファイル形式エラー")
                state = .established
            } else {
                let header = "\u{1b}TWRITE\r\n".data(using:.utf8)!
                bleManager.write(header)
                bleManager.write(data)
                writeMessage("ファイル転送開始")
                state = .sending
            }
        } else {
            let str = stringFSM.string
            writeError("\"\(str)\"を開くことができませんでした．")
            state = .established
        }
    }

    // プロンプトとファイル名を表示
    private func printPrompt() {
        writeToTerminal("\r\u{1b}[J")                           // 行を消す
        writeToTerminal("BIN file: \(stringFSM.string)")
    }

    // 接続中に'~.'が入力されて接続を切断する
    private func close() {
        writeMessage("\r\n切断を開始します．")
        if oldTec7 {
            bleManager.write("ERR\r\nERR\r\n".data(using:.utf8)!)
        }
        bleManager.close()
        state = .closing
    }

    // ファイル名入力ステージに実行される
    private func prompting() {
        if stdioManager.isEof() {
          close()
        } else if let data = stdioManager.read() {
            for char in data {
                switch stringFSM.feedChar(char) {
                case .delete, .character:
                    printPrompt()                       // 表示を更新する
                case .enter:
                    writeToTerminal("\r\n")
                    if !stringFSM.string.hasSuffix(".bin") {
                        stringFSM.string.append(".bin")
                    }
                    startSending()
                case .nonCharacter:
                    break
                }
            }
        }
    }

    // 通信ステージに実行される
    private func communicate() {
        if let data=bleManager.read() {
            stdioManager.write(data)
        }
        if stdioManager.isEof() {
            close()
        } else if let data = stdioManager.read() {
            for char in data {
                switch commandFSM.feedChar(char) {
                case .close:                                // "~."
                    close()
                case .command:                              // "~:"
                    writeToTerminal("\r\n")
                    printPrompt()
                    state = .prompting
                case .cancel, .help:
                    bleManager.write("~".data(using:.utf8)!)
                    bleManager.write(Data([char]))
                case .character:
                    bleManager.write(Data([char]))
                case .candidate:
                    break
                }
            }
        }
    }

    // 通信が切れていないかチェックする
    private func connectionError() -> Bool {
        switch bleManager.state {
        case .idle, .busy:
            return false
        default:
            writeError("\r\n通信エラーが発生しました．")
            return true
        }
    }

    // BelManager でエラーが発生した際にエラーメッセージを表示する
    private func bleError(_ state:CBManagerState?) {
        switch state {
        case .poweredOff:
            writeError("""
                       \r\nBluetoothの電源がOFFになっています．\r
                       環境設定アプリでBluetoothをONにしてください．
                       """)
        case .unauthorized:
            writeError("""
                       \r\nBluetoothにアクセスする権限がありません．\r
                       環境設定アプリの「プライバシーとセキュリティ」で\r
                       「ターミナル」に権限を与えてください．
                       """)
        default:
            writeError("\r\n原因不明のエラーが発生しました．")
        }
    }

    // 入出力イベントの発生を待つ，イベントが発生なしでも１秒に1度はループする
    // （Timer は runLoop.run() を終了させないので1秒でタイムアウトさせる）
    private func mainLoop() {
        let runLoop = RunLoop.main
        loop: while runLoop.run(mode:RunLoop.Mode.default, before:Date()+1.0) {
            let bleState = bleManager.state
            switch bleState {
            case .ready:
                bleManager.startScan()
            case let .error(substate):
                bleError(substate)
                exit(1)
            default:
                break // やることなし
            }

            switch state {
            case .opening:
                if !opening() {
                    writeMessage("\r\nプログラムを中止します．")
                    break loop
                }
            case .established:
                if connectionError() {
                  exit(1)
                }
                communicate()
            case .prompting:
                if connectionError() {
                  exit(1)
                }
                prompting()
            case .sending:
                if connectionError() {
                  exit(1)
                }
                if case .idle = bleState {
                    writeMessage("ファイル送信完了")
                    state = .established
                }
            case .closing:
                if case .closed = bleState {
                    writeMessage("切断が完了しました．")
                    break loop
                }
            }
        }
    }

    // 起動時の処理を行ったあと mainLoop を呼び出す．
    func run(_ name:String?, oldTec7 bcSwitch:Bool) {
        deviceName = name
        oldTec7 = bcSwitch
        writeMessage("終了する時は「~.」を入力します．")
        writeMessage("TeCに.BINファイルを書き込む時は「~:」を入力します．")
        if deviceName == nil {
            writeMessage("接続するTeCの番号を入力してください．")
        } else {
            writeMessage("\"\(deviceName!)\"を探します．")
        }
        mainLoop()
    }
}

// ここから実行が開始される
let bleTerminal = BleTerminal()
let argv = ProcessInfo.processInfo.arguments      // コマンド行引数
var bcSwitch = false                              // TeC7b,c
var count = argv.count
var index = 1
if ( count == 2 || count == 3 ) && argv[index] == "-b" {
  bcSwitch = true
  index = index + 1
  count = count - 1
}

switch count {
case 1:                                           // 引数無しで起動された
    bleTerminal.run(nil, oldTec7:bcSwitch)
case 2:                                           // 名前付きで起動された
    bleTerminal.run(argv[index], oldTec7:bcSwitch)
default:                                          // 使い方が間違っている
    print("Usage: blueTerminal [-b] [devicename]\r\n")
    exit(1)
}
