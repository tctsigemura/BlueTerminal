// Fsm.swift
import Foundation

// "~.","~:","~?"を見つけるステートマシン
class CommandFSM {
    enum Output {
        case character                             // 普通の文字
        case candidate                             // '~': エスケープの候補
        case cancel                                // エスケープではなかった
        case close                                 // "~.": 終了
        case command                               // "~:": コマンド開始
        case help                                  // "~?": ヘルプ
    }
    private var escape = false                     // エスケープを発見した

    func feedChar(_ character:UInt8) -> Output {
        var retVal = Output.character
        if escape {
            switch character {
            case 0x2e:                             // '.'
                retVal = .close
            case 0x3a:                             // ':'
                retVal = .command
            case 0x3f:                             // '?'
                retVal =  .help
            default:
                retVal = .cancel
            }
            escape = false
        } else if character == 0x7e {              // '~'
            escape = true
            retVal = .candidate
        }
        return retVal
    }
} // CommanFSM

// 数値を入力するステートマシン
class NumberFSM {
    enum Output {
        case nonNumeric                            // 非数字が入力された
        case numeric                               // 数字が入力された
        case delete                                // BS，DELが入力された
        case enter                                 // Enterが入力された
    }
    private var classification = Output.nonNumeric
    var number = 0                                 // 数値

    func feedChar(_ character:UInt8) -> Output {
        let charCode : Int = Int(character)
        if 0x30 <= charCode && charCode <= 0x39 {
            number = number * 10 + charCode - 0x30
            classification = .numeric
        } else if charCode == 0x08 || charCode == 0x7f {
            number = number / 10
            classification = .delete
        } else if charCode == 0x0a || charCode == 0x0d {
            classification = .enter
        } else {
            classification = .nonNumeric
        }
        return classification
    }
} // NumberFSM

// 文字列を入力するステートマシン
class StringFSM {
    enum Output {
        case nonCharacter                          // この文字は無視する
        case character                             // 文字が入力された
        case delete                                // BS，DELが入力された
        case enter                                 // Enterが入力された
    }
    private var previous = Output.nonCharacter
    private var utf8Data = Data()                  // 入力したUTF8データ
    var string = String()                          // 入力した文字列

    func feedChar(_ character:UInt8) -> Output {
        let charCode : Int = Int(character)
        if charCode == 0x08 || charCode == 0x7f {
            utf8Data = Data()
            if !string.isEmpty {
                string.removeLast()
                previous = .delete
            } else {
                previous = .nonCharacter
            }
        } else if charCode == 0x0a || charCode == 0x0d {
            utf8Data = Data()
            previous = .enter
        } else if charCode >= 0x20 {
            utf8Data.append(Data([character]))
            if let str = String(data:utf8Data, encoding:String.Encoding.utf8) {
               string.append(str)
               utf8Data = Data()
               previous = .character
            } else {
                previous = .nonCharacter
            }
        } else {
            utf8Data = Data()
            previous = .nonCharacter
        }
        return previous
    }
} // StringFSM
