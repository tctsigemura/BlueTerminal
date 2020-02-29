// Fsm.swift

// "~.","~:","~?"を見つけるステートマシン
class ComFSM {
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
} // ComFSM

// 数値を入力するステートマシン
class NumFSM {
    enum Output {
        case nonNumeric                            // 非数字が入力された
        case numeric                               // 数字が入力された
        case delete                                // BS，DELが入力された
        case enter                                 // Enterが入力された
    }
    private var previous = Output.nonNumeric
    var number = 0                                 // 数値

    func feedChar(_ character:UInt8) -> Output {
        let charCode : Int = Int(character)
        if previous == .enter {
	    number = 0
	}
        if 0x30 <= charCode && charCode <= 0x39 {
	    number = number * 10 + charCode - 0x30
	    previous = .numeric
        } else if charCode == 0x08 || charCode == 0x7f {
	    number = number / 10
	    previous = .delete
	} else if charCode == 0x0a || charCode == 0x0d {
	    previous = .enter
	} else {
	    previous = .nonNumeric
	}
	return previous
    }
} // NumFSM
