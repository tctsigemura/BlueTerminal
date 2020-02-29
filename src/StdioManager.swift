// StdioManager.swift
import Foundation

class StdioManager : NSObject, StreamDelegate {
  private let bufferSize = 100
  private var inputStream : InputStream!
  private var outputStream : OutputStream!
  private var buffer : UnsafeMutablePointer<UInt8>!
  private var readData : Data?
  private var eof:Bool = false

  override init() {
    super.init()
    inputStream  = InputStream(fileAtPath:"/dev/stdin")
    inputStream.delegate = self
    outputStream = OutputStream(toFileAtPath:"/dev/stdout", append:false)
    buffer = UnsafeMutablePointer<UInt8>.allocate(capacity:bufferSize)
    inputStream!.open()
    inputStream.schedule(in:RunLoop.main, forMode:RunLoop.Mode.default)
    outputStream!.open()
  }

  func stream(_ aStream:Stream, handle eventCode:Stream.Event) {
    var code = eventCode
    if code.contains(.hasBytesAvailable) {  // 一度に読めなくても OK
      let length = inputStream.read(buffer, maxLength:bufferSize)
      let data = Data(bytes:buffer, count:length)
      if readData != nil {
          readData!.append(data)
      } else {
          readData = data
      }
      code = code.subtracting(.hasBytesAvailable)
    }
    if code.contains(.endEncountered) {
      eof = true;
      code = code.subtracting(.endEncountered)
    }
    if code.rawValue != 0 {
      NSLog("Inputstream: eventCode: %d", code.rawValue)
    }
  }

  func read() -> Data? {
    let copy = readData
    readData = nil
    return copy
  }

  func write(_ data:Data) {
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity:data.count)
    data.copyBytes(to:buffer, count:data.count)
    let outCount = outputStream.write(buffer, maxLength:data.count)
    if outCount != data.count {
      NSLog("OutputStream: write error")
    }
    buffer.deallocate()
  }

  func isEof() -> Bool {
    return eof;
  }
} // StdioManager
